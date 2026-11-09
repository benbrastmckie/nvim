#!/usr/bin/env bash
# test-dispatch-strand-probe.sh - Fixture-driven suite proving dispatch-strand-probe.sh fires on
# the stranded shape AND stays silent on the measured healthy-but-slow shape, with no real
# sleeping and no contact with the real specs/ tree.
#
# Modeled structurally on test-task-lock-liveness.sh: isolated mktemp -d root satisfying
# deploy-root-guard.sh's ".claude/scripts/, two levels under root" shape, the real task-lock.sh
# and dispatch-strand-probe.sh plus their sibling dependencies copied in, pass()/fail()/info()
# helpers, a cleanup trap, and controlled-epoch timestamp helpers -- same live-pid ($$) and
# session-fixture technique, reused verbatim rather than re-derived.
#
# Six cases: stranded (all three conjunction terms silent); healthy-but-slow (the measured
# false-positive regression -- same stale lock, but an artifact touched inside the window);
# held-fresh (heartbeat not stale at all, no quiescence probe needed); unknown/fail-closed (a
# task number that resolves to no directory, never "stranded"); no-side-effects (a before/after
# fixture-root manifest is byte-identical across a full run); and the negative control recorded
# in this header per the suite's own "a suite that cannot be made to fail is not evidence"
# requirement.
#
# NEGATIVE CONTROL (captured manually at implementation time, not re-derived by this suite on
# every run, mirroring test-task-lock-liveness.sh's own acceptance-evidence paragraph): inverting
# the probe's conjunction to a bare staleness test (treating `held-live`/`held-stale` alone as
# sufficient for `stranded`, without consulting artifact/commit quiescence) flips Case 2
# (healthy-but-slow) from `live` to `stranded` -- the exact false-positive the conjunction exists
# to prevent. Reproduce by hand: comment out the artifact/commit-quiescence block in
# dispatch-strand-probe.sh and resolve `stranded` on `heartbeat_stale` alone; Case 2 goes red.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
SRC_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0

for req in task-lock.sh dispatch-strand-probe.sh deploy-root-guard.sh lib/common.sh \
           lib/task-lookup-lib.sh lib/file-scope-overlap.sh; do
  if [ ! -f "$SRC_DIR/$req" ]; then
    echo "ERROR: expected $req alongside this suite's sibling scripts dir ($SRC_DIR)" >&2
    exit 2
  fi
done

TMPROOT="$(mktemp -d "${TMPDIR:-/tmp}/dispatch-strand-probe-test.XXXXXX")"
cleanup() { [ -n "${TMPROOT:-}" ] && [ -d "$TMPROOT" ] && rm -rf "$TMPROOT"; }
trap cleanup EXIT

mkdir -p "$TMPROOT/.claude/scripts/lib"
mkdir -p "$TMPROOT/specs/.sessions"
for f in task-lock.sh dispatch-strand-probe.sh deploy-root-guard.sh lib/common.sh \
         lib/task-lookup-lib.sh lib/file-scope-overlap.sh; do
  mkdir -p "$TMPROOT/.claude/scripts/$(dirname "$f")"
  cp "$SRC_DIR/$f" "$TMPROOT/.claude/scripts/$f"
done
chmod +x "$TMPROOT/.claude/scripts/task-lock.sh" "$TMPROOT/.claude/scripts/dispatch-strand-probe.sh"

PROBE="$TMPROOT/.claude/scripts/dispatch-strand-probe.sh"

(cd "$TMPROOT" && git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)

# --- Timestamp helpers (no sleeping -- controlled epoch arithmetic) ---
now_epoch() { date -u +%s; }
iso_at() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
minutes_ago_iso() { iso_at "$(( $(now_epoch) - ($1 * 60) ))"; }

write_holder_fixture() {
  # write_holder_fixture <lock_dir> <task_number> <session_id> <heartbeat_minutes_ago>
  local lock_dir="$1" task_number="$2" session_id="$3" mins_ago="$4"
  local ts
  ts=$(minutes_ago_iso "$mins_ago")
  mkdir -p "$lock_dir"
  jq -n \
    --arg session_id "$session_id" \
    --argjson task_number "$task_number" \
    --arg operation "implement" \
    --arg ts "$ts" \
    --arg command "/revise $task_number" \
    '{session_id: $session_id, task_number: $task_number, operation: $operation, acquired_at: $ts, heartbeat_at: $ts, command: $command}' \
    > "$lock_dir/holder.json"
}

write_session_fixture() {
  # write_session_fixture <sessions_dir> <session_id> <pid> <task_numbers_json> <file_scope_json> <heartbeat_minutes_ago>
  local sessions_dir="$1" session_id="$2" pid="$3" task_numbers_json="$4" file_scope_json="$5" mins_ago="$6"
  local ts
  ts=$(minutes_ago_iso "$mins_ago")
  mkdir -p "$sessions_dir"
  jq -n \
    --arg session_id "$session_id" \
    --argjson pid "$pid" \
    --arg pid_source "test-fixture" \
    --arg command "/test $session_id" \
    --argjson task_numbers "$task_numbers_json" \
    --argjson file_scope "$file_scope_json" \
    --arg ts "$ts" \
    '{session_id: $session_id, pid: $pid, pid_source: $pid_source, command: $command, task_numbers: $task_numbers, file_scope: $file_scope, started_at: $ts, heartbeat_at: $ts}' \
    > "$sessions_dir/${session_id}.json"
}

SESSIONS_DIR="$TMPROOT/specs/.sessions"
OWN_PID="$$"

common_test_info "Fixture built at $TMPROOT (own pid=$OWN_PID)"

# ═══════════════════════════════════════════════════════════════════════
# Case 1: stranded -- live holder pid, heartbeat well past threshold, session registry entry
# resolving pid-alive, task directory quiescent, no commit in the window.
# ═══════════════════════════════════════════════════════════════════════
common_test_info "=== Case 1: stranded (all three conjunction terms silent) -> verdict=stranded ==="
TASK_DIR_1="$TMPROOT/specs/901_stranded_case"
mkdir -p "$TASK_DIR_1"
write_holder_fixture "$TASK_DIR_1/.lock" 901 "sess_strand1" 120
write_session_fixture "$SESSIONS_DIR" "sess_strand1" "$OWN_PID" "[901]" "[]" 120
echo "old content, never touched since" > "$TASK_DIR_1/old.md"
touch -d "$(minutes_ago_iso 120)" "$TASK_DIR_1/old.md"

out1=$("$PROBE" 901 --task-dir "$TASK_DIR_1" --repo-root "$TMPROOT" 2>&1); rc1=$?
if [ "$rc1" -eq 0 ]; then
  common_test_pass "(1a) exits 0 (a verdict is data, not an error)"
else
  common_test_fail "(1a) expected exit 0, got $rc1: $out1"
fi
if echo "$out1" | jq -e '.verdict == "stranded"' >/dev/null 2>&1; then
  common_test_pass "(1b) verdict is stranded"
else
  common_test_fail "(1b) expected verdict=stranded, got: $out1"
fi
if echo "$out1" | jq -e '(.evidence | index("heartbeat_stale")) != null and (.evidence | index("artifact_quiescent")) != null and (.evidence | index("commit_quiescent")) != null' >/dev/null 2>&1; then
  common_test_pass "(1c) evidence names all three conjunction terms"
else
  common_test_fail "(1c) expected all three evidence terms, got: $out1"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 2: healthy-but-slow (the measured false-positive regression) -- identical lock/session
# fixture past the threshold, but one artifact file touched inside the window. Must be `live`.
# ═══════════════════════════════════════════════════════════════════════
common_test_info "=== Case 2: healthy-but-slow (measured false-positive regression) -> verdict=live ==="
TASK_DIR_2="$TMPROOT/specs/902_healthy_slow_case"
mkdir -p "$TASK_DIR_2"
write_holder_fixture "$TASK_DIR_2/.lock" 902 "sess_strand2" 41
write_session_fixture "$SESSIONS_DIR" "sess_strand2" "$OWN_PID" "[902]" "[]" 41
echo "recently rewritten" > "$TASK_DIR_2/report.md"
# Deliberately NOT backdated -- this file's mtime is "now", inside the stale window, reproducing
# the measured incident: a long final phase legitimately crosses the heartbeat threshold while
# the agent is still actively writing.

out2=$("$PROBE" 902 --task-dir "$TASK_DIR_2" --repo-root "$TMPROOT" 2>&1); rc2=$?
if [ "$rc2" -eq 0 ] && echo "$out2" | jq -e '.verdict == "live"' >/dev/null 2>&1; then
  common_test_pass "(2a) healthy-but-slow (heartbeat 41 min past a 30-min threshold, artifact moved) classifies live -- NOT stranded"
else
  common_test_fail "(2a) expected exit 0 and verdict=live, got rc=$rc2: $out2"
fi
if echo "$out2" | jq -e '.evidence | index("artifact_moved") != null' >/dev/null 2>&1; then
  common_test_pass "(2b) evidence names artifact_moved (the discriminating signal)"
else
  common_test_fail "(2b) expected artifact_moved in evidence, got: $out2"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 3: held-fresh -- heartbeat inside the threshold. Must be live with no quiescence probe.
# ═══════════════════════════════════════════════════════════════════════
common_test_info "=== Case 3: held-fresh -> verdict=live, no quiescence probe needed ==="
TASK_DIR_3="$TMPROOT/specs/903_fresh_case"
mkdir -p "$TASK_DIR_3"
write_holder_fixture "$TASK_DIR_3/.lock" 903 "sess_strand3" 2

out3=$("$PROBE" 903 --task-dir "$TASK_DIR_3" --repo-root "$TMPROOT" 2>&1); rc3=$?
if [ "$rc3" -eq 0 ] && echo "$out3" | jq -e '.verdict == "live" and .lock_state == "held-fresh"' >/dev/null 2>&1; then
  common_test_pass "(3a) held-fresh classifies live"
else
  common_test_fail "(3a) expected verdict=live, lock_state=held-fresh, got rc=$rc3: $out3"
fi
if echo "$out3" | jq -e '(has("artifact_age_min") | not) and (has("commits_in_window") | not)' >/dev/null 2>&1; then
  common_test_pass "(3b) no artifact_age_min/commits_in_window fields emitted (quiescence probe never ran)"
else
  common_test_fail "(3b) expected no quiescence fields on a held-fresh verdict, got: $out3"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 4: unknown/fail-closed -- a task number that resolves to no directory at all.
# ═══════════════════════════════════════════════════════════════════════
common_test_info "=== Case 4: unresolvable task -> verdict=unknown, never stranded ==="
echo '{"next_project_number":1000,"active_projects":[]}' > "$TMPROOT/specs/state.json"
out4=$("$PROBE" 904 --repo-root "$TMPROOT" 2>&1); rc4=$?
if [ "$rc4" -eq 0 ] && echo "$out4" | jq -e '.verdict == "unknown"' >/dev/null 2>&1; then
  common_test_pass "(4a) unresolvable task classifies unknown, exit 0"
else
  common_test_fail "(4a) expected exit 0 and verdict=unknown, got rc=$rc4: $out4"
fi
if ! echo "$out4" | jq -e '.verdict == "stranded"' >/dev/null 2>&1; then
  common_test_pass "(4b) explicitly NOT stranded"
else
  common_test_fail "(4b) an unresolvable task must never classify stranded"
fi

# ═══════════════════════════════════════════════════════════════════════
# Case 5: no side effects -- a before/after find-based manifest of the whole fixture root is
# byte-identical across a full run (the probe is read-only).
# ═══════════════════════════════════════════════════════════════════════
common_test_info "=== Case 5: no side effects -- probe writes nothing ==="
manifest_before="$(find "$TMPROOT" -type f -printf '%p %s\n' 2>/dev/null | sort)"
"$PROBE" 901 --task-dir "$TASK_DIR_1" --repo-root "$TMPROOT" >/dev/null 2>&1
"$PROBE" 902 --task-dir "$TASK_DIR_2" --repo-root "$TMPROOT" >/dev/null 2>&1
"$PROBE" 903 --task-dir "$TASK_DIR_3" --repo-root "$TMPROOT" >/dev/null 2>&1
"$PROBE" 904 --repo-root "$TMPROOT" >/dev/null 2>&1
manifest_after="$(find "$TMPROOT" -type f -printf '%p %s\n' 2>/dev/null | sort)"
if [ "$manifest_before" = "$manifest_after" ]; then
  common_test_pass "(5) fixture-root file manifest byte-identical before/after four probe runs"
else
  common_test_fail "(5) fixture root changed across probe runs -- the probe is documented read-only"
  diff <(echo "$manifest_before") <(echo "$manifest_after") || true
fi

# ═══════════════════════════════════════════════════════════════════════
echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"
[ "$FAILED" -eq 0 ] && exit 0 || exit 1
