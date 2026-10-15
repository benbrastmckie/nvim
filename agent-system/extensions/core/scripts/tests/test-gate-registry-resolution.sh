#!/usr/bin/env bash
# test-gate-registry-resolution.sh - Regression suite for scripts/lib/gate-registry-lib.sh, the
# thin interpreter over scripts/gate-registry.data. See that library's own header for the full
# contract (deliberately thin: look up a function name, call it -- no generic guard/output fold).
#
# Coverage:
#   - gate_registry_load parses the REAL gate-registry.data into the documented 7 fields per id.
#   - gate_registry_ids returns the loaded ids, space-separated, ascending.
#   - gate_registry_execute calls the registered function directly (in-process, not a subshell --
#     confirmed by having the called function mutate a caller-scope variable and observing the
#     mutation survive the call).
#   - gate_registry_field returns empty (not an error) for an unknown id or field.
#   - The "-" empty-dependency placeholder normalizes to a truly empty string, not the literal
#     "-" -- this is the regression pin for the TSV-empty-field-collapse defect found and fixed
#     during this task's own Phase 4 (IFS=$'\t' read silently shifts every later column when a
#     field between two tabs is genuinely empty, because bash classifies tab as IFS-whitespace
#     even as IFS's sole member).
#   - A synthetic registry with a genuinely malformed id (non-numeric) is skipped, not aborted.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the
# library was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LIB="$CORE_DIR/lib/gate-registry-lib.sh"
REAL_DATA="$CORE_DIR/gate-registry.data"

if [ ! -f "$LIB" ]; then
  echo "ERROR: expected $LIB" >&2
  exit 2
fi
if [ ! -f "$REAL_DATA" ]; then
  echo "ERROR: expected $REAL_DATA" >&2
  exit 2
fi

# shellcheck source=/dev/null
source "$LIB"

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); [ -n "${2:-}" ] && echo "$2"; }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

# ─── Case 1-7: load the REAL registry and confirm the documented shape ──────────────────────────
gate_registry_load "$REAL_DATA"

ids="$(gate_registry_ids)"
expected_ids="$(seq 1 23 | tr '\n' ' ' | sed 's/ $//')"
if [ "$ids" = "$expected_ids " ] || [ "$ids" = "$expected_ids" ]; then
  pass "case1: gate_registry_ids returns the real registry's 23 migrated ids, ascending (1-23, Phase 5 completed the migration)"
else
  fail "case1: unexpected ids from the real registry (got: '$ids')"
fi

if [ "$(gate_registry_field 3 invoke)" = "gate3_run" ]; then
  pass "case2: gate_registry_field resolves gate 3's invoke function correctly"
else
  fail "case2: gate 3 invoke mismatch (got: '$(gate_registry_field 3 invoke)')"
fi

if [ "$(gate_registry_field 8 serialized)" = "true" ] && [ "$(gate_registry_field 1 serialized)" = "false" ]; then
  pass "case3: gate_registry_field resolves the serialized flag correctly (gate8=true, gate1=false)"
else
  fail "case3: serialized flag mismatch (gate8='$(gate_registry_field 8 serialized)' gate1='$(gate_registry_field 1 serialized)')"
fi

if [ "$(gate_registry_field 3 requires_source_store)" = "true" ] && [ "$(gate_registry_field 1 requires_source_store)" = "false" ]; then
  pass "case4: gate_registry_field resolves requires_source_store correctly (gate3=true, gate1=false)"
else
  fail "case4: requires_source_store mismatch"
fi

timeout8="$(gate_registry_field 8 timeout_s)"
case "$timeout8" in
  ''|*[!0-9]*) fail "case5: gate 8's timeout_s is not a positive integer (got: '$timeout8')" ;;
  *)
    if [ "$timeout8" -gt 0 ]; then
      pass "case5: gate 8's timeout_s is a positive integer ($timeout8)"
    else
      fail "case5: gate 8's timeout_s is not > 0 (got: $timeout8)"
    fi
    ;;
esac

# Case 6 -- the TSV-empty-field-collapse regression pin: every gate's dependencies field must
# normalize to a truly empty string, never the literal on-disk "-" placeholder leaking through,
# and (indirectly) every LATER field must still resolve to its own correct value rather than a
# neighboring field's value shifted into it by a collapsed empty-field delimiter.
deps_leaked=false
fields_shifted=false
for id in $(gate_registry_ids); do
  d="$(gate_registry_field "$id" dependencies)"
  if [ "$d" = "-" ]; then
    deps_leaked=true
  fi
  class="$(gate_registry_field "$id" cost_class)"
  case "$class" in
    free|moderate|slow) : ;;
    *) fields_shifted=true ;;
  esac
done
if ! $deps_leaked && ! $fields_shifted; then
  pass "case6: the '-' empty-dependency placeholder normalizes to empty, and no field shifted into cost_class's slot (TSV-collapse regression pin)"
else
  fail "case6: TSV-collapse regression -- deps_leaked=$deps_leaked fields_shifted=$fields_shifted"
fi

# Case 7 -- gate_registry_field returns empty (not an error, no abort) for an unknown id/field.
unk_id="$(gate_registry_field 9999 invoke)"
unk_field="$(gate_registry_field 1 not_a_real_field)"
if [ -z "$unk_id" ] && [ -z "$unk_field" ]; then
  pass "case7: an unknown id or field resolves to empty, not an error"
else
  fail "case7: expected empty for unknown id/field (got id='$unk_id' field='$unk_field')"
fi

# ─── Case 8: gate_registry_execute calls the function directly (in-process, not a subshell) ────
TEST_MUTATION_PROBE=""
test_probe_fn() { TEST_MUTATION_PROBE="mutated"; }
SYNTH1="$WORKDIR/synth1.data"
printf '1\tprobe gate\ttest_probe_fn\t-\tfalse\t30\tfree\tfalse\n' > "$SYNTH1"
gate_registry_load "$SYNTH1"
gate_registry_execute 1
if [ "$TEST_MUTATION_PROBE" = "mutated" ]; then
  pass "case8: gate_registry_execute calls the registered function in-process (mutation observed by caller)"
else
  fail "case8: gate_registry_execute did not call the function in-process (TEST_MUTATION_PROBE='$TEST_MUTATION_PROBE')"
fi

# ─── Case 9: an id with no registered function (or a registry that was never loaded for that id)
# is a silent no-op, never an error / abort. ─────────────────────────────────────────────────────
gate_registry_execute 9999
if [ $? -eq 0 ]; then
  pass "case9: gate_registry_execute on an unregistered id is a silent no-op (no abort)"
else
  fail "case9: gate_registry_execute on an unregistered id did not return 0"
fi

# ─── Case 10: a malformed (non-numeric) id row is skipped during load, not aborted, and does not
# poison the ids array. ──────────────────────────────────────────────────────────────────────────
SYNTH2="$WORKDIR/synth2.data"
printf 'abc\tbad row\tsomefn\t-\tfalse\t30\tfree\tfalse\n2\tgood row\ttest_probe_fn\t-\tfalse\t30\tfree\tfalse\n' > "$SYNTH2"
gate_registry_load "$SYNTH2"
ids2="$(gate_registry_ids)"
if [ "$ids2" = "2" ] || [ "$ids2" = "2 " ]; then
  pass "case10: a malformed (non-numeric) id row is skipped during load, leaving only the valid row"
else
  fail "case10: expected only id 2 after skipping the malformed row (got: '$ids2')"
fi

# ─── Case 11-14: gate_registry_exec_bounded (Phase 6, "Uniform Bounded Timeouts Per Gate and
# Per Suite") -- the enforcement mechanism for the timeout_s field cases 5/6 above already
# confirm is well-formed data. See that function's own header for the full contract. ────────────

# Case 11: a fast function under a generous bound finishes normally (rc=0), and its mutations to
# caller-named globals -- including an ARRAY, mirroring verify-deploy.sh's real FINDINGS_LIST --
# are correctly reconciled back across the subshell boundary the bound requires.
TEST_CHECKS=3
TEST_FINDINGS=("FINDING gate1 preexisting")
fast_gate_fn() {
  TEST_CHECKS=$((TEST_CHECKS + 1))
  TEST_FINDINGS+=("FINDING gate2 something broke")
  echo "fast gate stdout"
  echo "fast gate stderr" >&2
}
OUT11="$WORKDIR/out11"; ERR11="$WORKDIR/err11"; STATE11="$WORKDIR/state11"
gate_registry_exec_bounded fast_gate_fn 10 "$OUT11" "$ERR11" "$STATE11" TEST_CHECKS TEST_FINDINGS
rc11=$?
# shellcheck source=/dev/null
[ -s "$STATE11" ] && source "$STATE11"
if [ "$rc11" -eq 0 ] && [ "$TEST_CHECKS" -eq 4 ] && [ "${#TEST_FINDINGS[@]}" -eq 2 ] \
   && [ "$(cat "$OUT11")" = "fast gate stdout" ] && [ "$(cat "$ERR11")" = "fast gate stderr" ]; then
  pass "case11: gate_registry_exec_bounded reconciles scalar + array mutations across the subshell boundary on a clean finish (rc=$rc11, CHECKS=$TEST_CHECKS, findings=${#TEST_FINDINGS[@]})"
else
  fail "case11: reconciliation after a clean finish was wrong (rc=$rc11 CHECKS=$TEST_CHECKS findings=${#TEST_FINDINGS[@]} out='$(cat "$OUT11" 2>/dev/null)' err='$(cat "$ERR11" 2>/dev/null)')"
fi

# Case 12: an empty (undeclared) timeout_s calls the function DIRECTLY, same process, no
# capture -- byte-identical to every pre-Phase-6 call site, and the correct degrade-safe default.
DIRECT_PROBE=0
direct_gate_fn() { DIRECT_PROBE=9; echo "direct gate stdout"; }
OUT12="$WORKDIR/out12"; ERR12="$WORKDIR/err12"; STATE12="$WORKDIR/state12"
DIRECT_STDOUT_CAPTURE="$WORKDIR/direct-stdout-capture.txt"
# Deliberately NOT `direct_out="$(...)"` -- command substitution itself forks a subshell in
# bash, which would strand DIRECT_PROBE's mutation exactly the way this case exists to prove
# does NOT happen on the empty-timeout direct-call path. Redirect real stdout to a file instead
# so the call stays a genuine plain statement in THIS shell.
gate_registry_exec_bounded direct_gate_fn "" "$OUT12" "$ERR12" "$STATE12" DIRECT_PROBE > "$DIRECT_STDOUT_CAPTURE"
rc12=$?
if [ "$rc12" -eq 0 ] && [ "$DIRECT_PROBE" -eq 9 ] && [ "$(cat "$DIRECT_STDOUT_CAPTURE")" = "direct gate stdout" ] \
   && [ ! -s "$OUT12" ]; then
  pass "case12: an empty timeout_s runs the function directly in-process (no fork, no capture file written)"
else
  fail "case12: empty-timeout direct-call path regressed (rc=$rc12 DIRECT_PROBE=$DIRECT_PROBE stdout='$(cat "$DIRECT_STDOUT_CAPTURE" 2>/dev/null)')"
fi

# Case 13: a stalling function under a short bound times out (rc=124), finishes within the
# bound plus a small margin (never the full 30s sleep), and leaves no orphaned descendant
# process -- proving the process-GROUP kill (not merely the wrapping subshell) actually fires.
# The stalled descendant's OWN pid is written to a dedicated file so this case can check that
# EXACT pid's liveness via `kill -0`, rather than a `pgrep -f "sleep 30"`-style pattern match --
# this suite can run concurrently with sibling suites (including its own repo's other suites,
# under a real parallel `run-all.sh` battery) that legitimately run an unrelated `sleep 30` of
# their own at the same moment, which a broad pattern match would misattribute as a leftover.
STALL_PIDFILE13="$WORKDIR/stall-pid13.txt"
stall_gate_fn() { sleep 30 & echo "$!" > "$STALL_PIDFILE13"; wait; }
OUT13="$WORKDIR/out13"; ERR13="$WORKDIR/err13"; STATE13="$WORKDIR/state13"
t0=$(date +%s%3N)
gate_registry_exec_bounded stall_gate_fn 2 "$OUT13" "$ERR13" "$STATE13"
rc13=$?
t1=$(date +%s%3N)
ms13=$((t1 - t0))
sleep 0.5
stalled_pid13="$(cat "$STALL_PIDFILE13" 2>/dev/null || true)"
leftover13=""
if [ -n "$stalled_pid13" ] && kill -0 "$stalled_pid13" 2>/dev/null; then
  leftover13="pid $stalled_pid13 still alive"
fi
if [ "$rc13" -eq 124 ] && [ "$ms13" -lt 6000 ] && [ -n "$stalled_pid13" ] && [ -z "$leftover13" ]; then
  pass "case13: a stalling function times out (rc=124) within margin (${ms13}ms) with no leftover descendant process (checked exact pid $stalled_pid13)"
else
  fail "case13: stalled-gate timeout did not behave as expected (rc=$rc13, elapsed=${ms13}ms, stalled_pid='$stalled_pid13', leftover='$leftover13')"
fi

# Case 14: the REAL migrated registry's own declared timeout_s values are all enforced-ready
# (positive integers) -- a direct pin that Phase 6 did not leave any migrated gate's bound at
# an empty/zero placeholder that would silently fall back to the unbounded direct-call path.
gate_registry_load "$REAL_DATA"
all_bounded=true
unbounded_ids=""
for id in $(gate_registry_ids); do
  t="$(gate_registry_field "$id" timeout_s)"
  case "$t" in
    ''|0|*[!0-9]*) all_bounded=false; unbounded_ids="$unbounded_ids $id" ;;
  esac
done
if $all_bounded; then
  pass "case14: every one of the real registry's 23 migrated gates declares a positive timeout_s (enforced, not a silent unbounded fallback)"
else
  fail "case14: gate id(s)$unbounded_ids have no enforceable timeout_s"
fi

# Restore the real registry for any downstream consumer of this same shell (defensive; this
# suite's own process exits right after, but mirrors good hygiene).
gate_registry_load "$REAL_DATA"

echo ""
echo "Results: $PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
