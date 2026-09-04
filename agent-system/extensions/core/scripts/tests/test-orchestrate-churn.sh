#!/usr/bin/env bash
# test-orchestrate-churn.sh - Fixture suite for orchestrate-churn.sh: fresh init, cross-session
# resume, the three-strikes threshold and its counter reset, the first-cycle
# phases_completed_last skip, the burnout counter write, and the non-churn signature leaving
# churn counters untouched.
#
# Structural model: test-orchestrate-cycle-plan.sh's sandbox shape (copy real collaborator
# scripts into a synthetic $WORKDIR/.claude/scripts/ tree so deploy-root-guard.sh's `*/.claude`
# parent-directory check passes for task-lock.sh, which orchestrate-churn.sh shells out to for
# its atomic init-marker primitive).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required collaborator script was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PASSED=0
FAILED=0

pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }
info() { echo "[INFO] $1"; }

require_file() {
  if [ ! -f "$1" ]; then
    echo "ERROR: expected $1" >&2
    exit 2
  fi
}

SUT_SRC="$CORE_DIR/orchestrate-churn.sh"
require_file "$SUT_SRC"
for f in task-lock.sh deploy-root-guard.sh lib/common.sh; do
  require_file "$CORE_DIR/$f"
done

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 2
fi

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

mkdir -p "$WORKDIR/.claude/scripts/lib"
cp "$CORE_DIR/orchestrate-churn.sh" "$WORKDIR/.claude/scripts/orchestrate-churn.sh"
cp "$CORE_DIR/task-lock.sh" "$WORKDIR/.claude/scripts/task-lock.sh"
cp "$CORE_DIR/deploy-root-guard.sh" "$WORKDIR/.claude/scripts/deploy-root-guard.sh"
cp "$CORE_DIR/lib/common.sh" "$WORKDIR/.claude/scripts/lib/common.sh"
chmod +x "$WORKDIR"/.claude/scripts/*.sh
mkdir -p "$WORKDIR/specs"

SUT="$WORKDIR/.claude/scripts/orchestrate-churn.sh"

run_sut() {
  # Usage: run_sut <args...>
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  bash "$SUT" "$@" >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

jqf() { echo "$LAST_STDOUT" | jq -r "$1" 2>/dev/null; }

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 1: Fresh init + first-cycle skip (absent phases_completed_last)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 1: fresh init and first-cycle phases_completed_last skip"
TASK1="$WORKDIR/specs/901_g1_fresh"
run_sut --task-dir "$TASK1" --dispatch-status partial --blockers '[{"target":"foo","verbatim_goal":"do foo"}]' --phases-completed 2 --session sessA
if [ "$LAST_EXIT" -eq 0 ]; then
  pass "fresh-init: SUT exits 0"
else
  fail "fresh-init: SUT exited $LAST_EXIT ($LAST_STDERR)"
fi
if [ -f "$TASK1/.orchestrator-churn-state.json" ]; then
  pass "fresh-init: churn-state file created via init-marker"
else
  fail "fresh-init: churn-state file was not created"
fi
if [ "$(jqf '.churn_detected')" = "false" ] && [ "$(jqf '.audit_requested')" = "false" ]; then
  pass "fresh-init: first cycle (no prior phases_completed_last) skips the churn check"
else
  fail "fresh-init: first cycle unexpectedly detected churn (stdout: $LAST_STDOUT)"
fi
if [ "$(jq -r '.phases_completed_last' "$TASK1/.orchestrator-churn-state.json")" = "2" ]; then
  pass "fresh-init: phases_completed_last is seeded for the next invocation"
else
  fail "fresh-init: phases_completed_last was not seeded"
fi
if [ "$(jq -r '.total_churn' "$TASK1/.orchestrator-churn-state.json")" = "0" ]; then
  pass "fresh-init: total_churn stays 0 on the skipped first cycle"
else
  fail "fresh-init: total_churn was incremented on the skipped first cycle"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 2: Cross-session resume (a different session_id, same task dir, one churn-state file)
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 2: resume across two different session_ids against one task dir"
run_sut --task-dir "$TASK1" --dispatch-status partial --blockers '[{"target":"foo","verbatim_goal":"do foo"}]' --phases-completed 2 --session sessB
if [ "$(jqf '.churn_detected')" = "true" ] && [ "$(jqf '.target')" = "foo" ] && [ "$(jqf '.count')" = "1" ]; then
  pass "resume: a foreign session_id still accumulates onto the SAME churn state (count=1)"
else
  fail "resume: cross-session churn accumulation failed (stdout: $LAST_STDOUT)"
fi
if echo "$LAST_STDERR" | grep -q "different session_id"; then
  pass "resume: session_id mismatch is an INFO log line, never a gate"
else
  fail "resume: expected an INFO session_id-mismatch log line (stderr: $LAST_STDERR)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 3: Three-strikes threshold and its counter reset
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 3: three-strikes threshold and counter reset"
run_sut --task-dir "$TASK1" --dispatch-status partial --blockers '[{"target":"foo","verbatim_goal":"do foo"}]' --phases-completed 2 --session sessB
if [ "$(jqf '.count')" = "2" ] && [ "$(jqf '.audit_requested')" = "false" ]; then
  pass "three-strikes: second consecutive churn on the same target reaches count=2, not yet requested"
else
  fail "three-strikes: expected count=2, audit_requested=false (stdout: $LAST_STDOUT)"
fi
run_sut --task-dir "$TASK1" --dispatch-status partial --blockers '[{"target":"foo","verbatim_goal":"do foo"}]' --phases-completed 2 --session sessB
if [ "$(jqf '.count')" = "3" ] && [ "$(jqf '.audit_requested')" = "true" ] && [ "$(jqf '.target')" = "foo" ] \
   && [ "$(jqf '.verbatim_goal')" = "do foo" ]; then
  pass "three-strikes: third consecutive churn reaches the threshold and requests an audit"
else
  fail "three-strikes: expected count=3, audit_requested=true at the threshold (stdout: $LAST_STDOUT)"
fi
if [ "$(jq -r '.target_churn.foo' "$TASK1/.orchestrator-churn-state.json")" = "0" ]; then
  pass "three-strikes: the target's counter is reset to 0 after the audit request"
else
  fail "three-strikes: target counter was not reset after the audit request"
fi
if [ "$(jq -r '.audit_dispatches' "$TASK1/.orchestrator-churn-state.json")" = "1" ]; then
  pass "three-strikes: audit_dispatches incremented"
else
  fail "three-strikes: audit_dispatches was not incremented"
fi
if [ "$(jq -r '.total_churn' "$TASK1/.orchestrator-churn-state.json")" = "3" ]; then
  pass "three-strikes: total_churn accumulates across all three strikes (never reset)"
else
  fail "three-strikes: total_churn is wrong after three strikes (got $(jq -r '.total_churn' "$TASK1/.orchestrator-churn-state.json"))"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 4: Non-churn signatures leave churn counters untouched
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 4: non-churn signature (progress made, or no blockers) leaves counters untouched"
before_total=$(jq -r '.total_churn' "$TASK1/.orchestrator-churn-state.json")
run_sut --task-dir "$TASK1" --dispatch-status partial --blockers '[{"target":"foo","verbatim_goal":"do foo"}]' --phases-completed 3 --session sessB
if [ "$(jqf '.churn_detected')" = "false" ]; then
  pass "non-churn: progress made (phases_delta > 0) does not register as churn"
else
  fail "non-churn: progress-made cycle was incorrectly flagged as churn"
fi
after_total=$(jq -r '.total_churn' "$TASK1/.orchestrator-churn-state.json")
if [ "$before_total" = "$after_total" ]; then
  pass "non-churn: total_churn is untouched when progress was made"
else
  fail "non-churn: total_churn changed on a progress-made cycle ($before_total -> $after_total)"
fi

run_sut --task-dir "$TASK1" --dispatch-status partial --blockers '[]' --phases-completed 3 --session sessB
if [ "$(jqf '.churn_detected')" = "false" ]; then
  pass "non-churn: an empty blockers array does not register as churn"
else
  fail "non-churn: empty-blockers cycle was incorrectly flagged as churn"
fi
after_total2=$(jq -r '.total_churn' "$TASK1/.orchestrator-churn-state.json")
if [ "$after_total" = "$after_total2" ]; then
  pass "non-churn: total_churn is untouched when blockers is empty"
else
  fail "non-churn: total_churn changed on an empty-blockers cycle"
fi

run_sut --task-dir "$TASK1" --dispatch-status implemented --blockers '[{"target":"foo"}]' --phases-completed 3 --session sessB
if [ "$(jqf '.churn_detected')" = "false" ]; then
  pass "non-churn: a non-partial dispatch_status does not register as churn"
else
  fail "non-churn: non-partial dispatch_status was incorrectly flagged as churn"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 5: Burnout counter write
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 5: burnout signal counter"
TASK2="$WORKDIR/specs/902_g5_burnout"
run_sut --burnout-signal "$TASK2"
if [ "$(jqf '.burnout_signals_this_session')" = "1" ]; then
  pass "burnout: first signal writes burnout_signals_this_session=1"
else
  fail "burnout: first signal did not write 1 (stdout: $LAST_STDOUT)"
fi
if echo "$LAST_STDERR" | grep -q "H-orch: burnout signal detected (session total: 1)"; then
  pass "burnout: the existing H-orch message is emitted verbatim"
else
  fail "burnout: H-orch message missing or wrong (stderr: $LAST_STDERR)"
fi
run_sut --burnout-signal "$TASK2"
if [ "$(jqf '.burnout_signals_this_session')" = "2" ]; then
  pass "burnout: second signal accumulates to 2"
else
  fail "burnout: second signal did not accumulate (stdout: $LAST_STDOUT)"
fi
if [ -f "$TASK2/.orchestrator-loop-guard" ] && [ "$(jq -r '.burnout_signals_this_session' "$TASK2/.orchestrator-loop-guard")" = "2" ]; then
  pass "burnout: counter lives in the pre-existing .orchestrator-loop-guard file, not a new one"
else
  fail "burnout: counter not found in .orchestrator-loop-guard"
fi

# Burnout counter must never touch the churn-state file (different mechanism, different file).
if [ ! -f "$TASK2/.orchestrator-churn-state.json" ]; then
  pass "burnout: no churn-state file is created by --burnout-signal"
else
  fail "burnout: --burnout-signal unexpectedly created a churn-state file"
fi

# Burnout counter preserves other loop-guard fields already present.
jq -n '{cycle_count: 4, dispatch_seq_counter: 9}' > "$TASK2/.orchestrator-loop-guard"
run_sut --burnout-signal "$TASK2"
if [ "$(jq -r '.cycle_count' "$TASK2/.orchestrator-loop-guard")" = "4" ] && \
   [ "$(jq -r '.dispatch_seq_counter' "$TASK2/.orchestrator-loop-guard")" = "9" ] && \
   [ "$(jq -r '.burnout_signals_this_session' "$TASK2/.orchestrator-loop-guard")" = "1" ]; then
  pass "burnout: pre-existing loop-guard fields (cycle_count, dispatch_seq_counter) are preserved"
else
  fail "burnout: burnout write clobbered pre-existing loop-guard fields (got: $(cat "$TASK2/.orchestrator-loop-guard"))"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Group 6: Usage errors
# ═══════════════════════════════════════════════════════════════════════════════════════════════
info "Group 6: usage errors"
run_sut --task-dir "$WORKDIR/specs/903_missing"
if [ "$LAST_EXIT" -eq 2 ]; then
  pass "usage: missing required flags exits 2"
else
  fail "usage: missing required flags did not exit 2 (got $LAST_EXIT)"
fi
run_sut --task-dir "$WORKDIR/specs/903_missing" --dispatch-status partial --phases-completed notanumber
if [ "$LAST_EXIT" -eq 2 ]; then
  pass "usage: non-integer --phases-completed exits 2"
else
  fail "usage: non-integer --phases-completed did not exit 2 (got $LAST_EXIT)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
echo ""
echo "Results: $PASSED passed, $FAILED failed"
if [ "$FAILED" -eq 0 ]; then
  exit 0
else
  exit 1
fi
