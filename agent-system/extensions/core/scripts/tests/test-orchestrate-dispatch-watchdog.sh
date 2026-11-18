#!/usr/bin/env bash
# test-orchestrate-dispatch-watchdog.sh - Fixture-driven suite for
# orchestrate-dispatch-watchdog.sh: the bounded poll loop over dispatch-strand-probe.sh's
# verdict, launched beside a cycle's own dispatches rather than after them.
#
# STUBBED COLLABORATOR, DELIBERATELY: dispatch-strand-probe.sh's own correctness (the
# three-signal conjunction, the fail-closed `unknown` handling) is already proven by
# test-dispatch-strand-probe.sh. This suite substitutes a stub `dispatch-strand-probe.sh` that
# emits a canned verdict on demand, so it tests the WATCHDOG's own logic (sweep/poll cadence,
# alert write, idempotency, outer bound, exit codes) in isolation from the probe's own fixture
# machinery -- the standard "stub an already-proven collaborator" boundary, not a shortcut.
#
# Isolated mktemp -d root satisfying deploy-root-guard.sh's ".claude/scripts/, two levels under
# root" shape (mirrors test-dispatch-strand-probe.sh's own fixture layout).
#
# Six cases: stranded verdict yields one alert row and exit 1; live verdict yields no alert and
# a clean exit 0 at the outer bound; unknown verdict likewise yields no alert; the outer bound
# itself terminates the loop within a bounded wall-clock (measured, not merely asserted exit0);
# a {task, dispatch_seq} pair already alerted is never re-alerted (idempotency); and the real
# script source contains neither `ps | grep` nor `pgrep -f` in executable code.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0

for req in orchestrate-dispatch-watchdog.sh deploy-root-guard.sh lib/common.sh; do
  if [ ! -f "$SRC_DIR/$req" ]; then
    echo "ERROR: expected $req alongside this suite's sibling scripts dir ($SRC_DIR)" >&2
    exit 2
  fi
done

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/orchestrate-dispatch-watchdog-test.XXXXXX")"
cleanup() { [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"; }
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib" "$TMPROOT/specs/.orchestration"
for f in orchestrate-dispatch-watchdog.sh deploy-root-guard.sh lib/common.sh; do
  mkdir -p "$TMPROOT/.claude/scripts/$(dirname "$f")"
  cp "$SRC_DIR/$f" "$TMPROOT/.claude/scripts/$f"
done
chmod +x "$TMPROOT/.claude/scripts/orchestrate-dispatch-watchdog.sh"

# Stub probe: emits a canned verdict for every task, controlled by $STUB_VERDICT (default
# "live"). Mirrors dispatch-strand-probe.sh's own one-compact-JSON-line-per-call contract so the
# watchdog's jq parsing is exercised against the real shape.
cat > "$TMPROOT/.claude/scripts/dispatch-strand-probe.sh" <<'PROBE_EOF'
#!/usr/bin/env bash
tnum="${1:-0}"
verdict="${STUB_VERDICT:-live}"
echo "{\"task\": ${tnum}, \"verdict\": \"${verdict}\", \"heartbeat_age_min\": 45, \"evidence\": [\"stub\"]}"
exit 0
PROBE_EOF
chmod +x "$TMPROOT/.claude/scripts/dispatch-strand-probe.sh"

WATCHDOG="$TMPROOT/.claude/scripts/orchestrate-dispatch-watchdog.sh"
ALERT_FILE="$TMPROOT/specs/.orchestration/alerts.jsonl"

run_watchdog() {
  # run_watchdog <verdict> <poll_interval> <outer_bound> <task:seq>...
  local verdict="$1" poll="$2" bound="$3"
  shift 3
  STUB_VERDICT="$verdict" bash "$WATCHDOG" --session sess_test --alert-file "$ALERT_FILE" \
    --poll-interval "$poll" --outer-bound "$bound" --repo-root "$TMPROOT" "$@"
}

# --- Case 1: stranded verdict -> one alert row, exit 1 -------------------------------------
rm -f "$ALERT_FILE"
out="$(run_watchdog stranded 1 30 601:1 2>&1)"
rc=$?
if [ "$rc" -eq 1 ]; then
  common_test_pass "stranded verdict: watchdog exits 1"
else
  common_test_fail "stranded verdict: expected exit 1, got $rc" "$out"
fi
if [ -f "$ALERT_FILE" ] && [ "$(jq -c 'select(.task == 601 and .dispatch_seq == 1 and .verdict == "stranded")' "$ALERT_FILE" | wc -l)" -eq 1 ]; then
  common_test_pass "stranded verdict: exactly one matching alert row written"
else
  common_test_fail "stranded verdict: alert row missing or malformed" "$(cat "$ALERT_FILE" 2>/dev/null)"
fi

# --- Case 2: live verdict -> no alert, clean exit 0 at the outer bound ---------------------
rm -f "$ALERT_FILE"
start_epoch="$(date -u +%s)"
out="$(run_watchdog live 1 3 602:1 2>&1)"
rc=$?
end_epoch="$(date -u +%s)"
elapsed=$(( end_epoch - start_epoch ))
if [ "$rc" -eq 0 ]; then
  common_test_pass "live verdict: watchdog exits 0 (no alert)"
else
  common_test_fail "live verdict: expected exit 0, got $rc" "$out"
fi
if [ ! -f "$ALERT_FILE" ] || [ "$(wc -l < "$ALERT_FILE" 2>/dev/null || echo 0)" -eq 0 ]; then
  common_test_pass "live verdict: no alert row written"
else
  common_test_fail "live verdict: unexpected alert row written" "$(cat "$ALERT_FILE")"
fi

# --- Case 3: unknown verdict -> no alert, clean exit 0 -------------------------------------
rm -f "$ALERT_FILE"
out="$(run_watchdog unknown 1 3 603:1 2>&1)"
rc=$?
if [ "$rc" -eq 0 ] && { [ ! -f "$ALERT_FILE" ] || [ "$(wc -l < "$ALERT_FILE" 2>/dev/null || echo 0)" -eq 0 ]; }; then
  common_test_pass "unknown verdict: exit 0, no alert row written"
else
  common_test_fail "unknown verdict: expected exit 0 with no alert, got rc=$rc" "$out"
fi

# --- Case 4: the outer bound itself terminates the loop within a bounded wall-clock -------
rm -f "$ALERT_FILE"
start_epoch="$(date -u +%s)"
run_watchdog live 1 4 604:1 >/dev/null 2>&1
end_epoch="$(date -u +%s)"
elapsed=$(( end_epoch - start_epoch ))
# Generous upper margin (bound + 10s) absorbs this host's own scheduling jitter under
# concurrent load without turning the assertion into a no-op -- it still fails a watchdog that
# never terminates (elapsed would be unbounded, not merely slow).
if [ "$elapsed" -le 14 ]; then
  common_test_pass "outer bound: watchdog terminated within ${elapsed}s of its 4s bound"
else
  common_test_fail "outer bound: watchdog ran ${elapsed}s, expected termination near its 4s bound"
fi

# --- Case 5: idempotency -- an already-alerted {task, dispatch_seq} is never re-alerted ---
rm -f "$ALERT_FILE"
run_watchdog stranded 1 30 605:2 >/dev/null 2>&1
first_count="$(wc -l < "$ALERT_FILE" 2>/dev/null || echo 0)"
run_watchdog stranded 1 3 605:2 >/dev/null 2>&1
second_rc=$?
second_count="$(wc -l < "$ALERT_FILE" 2>/dev/null || echo 0)"
if [ "$first_count" -eq 1 ] && [ "$second_count" -eq 1 ] && [ "$second_rc" -eq 0 ]; then
  common_test_pass "idempotency: a second run against an already-alerted pair writes no duplicate row and exits 0 (clean outer-bound, not a re-alert)"
else
  common_test_fail "idempotency: expected one row after both runs (first=$first_count, second=$second_count, second_rc=$second_rc)" "$(cat "$ALERT_FILE" 2>/dev/null)"
fi

# --- Case 6: forbidden process-lookup shapes absent from executable code -------------------
# Strip comment lines (leading '#') and the usage() heredoc body (prose, including the phrases
# this very check looks for, framed as a description of what is forbidden) before checking real
# executable lines only.
code_only="$(sed '/^[[:space:]]*cat <<.EOF.$/,/^EOF$/d' "$SRC_DIR/orchestrate-dispatch-watchdog.sh" | grep -vE '^\s*#')"
if echo "$code_only" | grep -qE 'ps[[:space:]]*\|[[:space:]]*grep|pgrep[[:space:]]+-f'; then
  common_test_fail "forbidden-shape check: found 'ps | grep' or 'pgrep -f' in executable code"
else
  common_test_pass "forbidden-shape check: no 'ps | grep' or 'pgrep -f' in executable code"
fi

# --- Case 7: usage errors ---------------------------------------------------------------
if bash "$WATCHDOG" >/dev/null 2>&1; then
  common_test_fail "usage: no arguments should exit nonzero"
else
  rc=$?
  [ "$rc" -eq 2 ] && common_test_pass "usage: no arguments exits 2" || common_test_fail "usage: no arguments exited $rc, expected 2"
fi
if bash "$WATCHDOG" --session s --alert-file "$ALERT_FILE" --repo-root "$TMPROOT" notapair >/dev/null 2>&1; then
  common_test_fail "usage: malformed TASK:DISPATCH_SEQ should exit nonzero"
else
  rc=$?
  [ "$rc" -eq 2 ] && common_test_pass "usage: malformed TASK:DISPATCH_SEQ exits 2" || common_test_fail "usage: malformed pair exited $rc, expected 2"
fi

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
