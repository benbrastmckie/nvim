#!/usr/bin/env bash
# test-orchestrate-close-status-bind.sh - Fixture-driven coverage for
# orchestrate-close-status-bind.sh, the script that binds a red close battery's verdict to the
# attributed task(s) it covers. See that script's own header for the full contract this suite
# exercises.
#
# Coverage: an attributed-cause completed task is demoted (status writer called with the right
# arguments); an unattributed-only task (absent from close_red_roster) is not touched; a clean
# close (empty close_red_roster) demotes nothing; a --dry-run demotes nothing (status writer
# never called); a task present in close_red_roster but NOT in completed_tasks is left untouched
# (the fourth conjunct).
#
# The real skill-base.sh (and its update-task-status.sh/state.json dependency chain) is
# deliberately NOT exercised here -- this suite stubs `skill_postflight_update` itself, the same
# way sibling suites stub the verify-deploy gate battery rather than running the real thing, so
# this suite is a fast, hermetic test of the gating conjunction and call shape, not of
# update-task-status.sh's own behavior (which has its own dedicated suite).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (the SUT
# was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
CORE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SUT_SRC="$CORE_DIR/orchestrate-close-status-bind.sh"

if [[ ! -f "$SUT_SRC" ]]; then
  echo "ERROR: expected $SUT_SRC" >&2
  exit 2
fi

PASSED=0
FAILED=0

common_test_workdir_init

# ─── Sandbox: a deployed-shaped scripts/ tree ($WORKDIR/.claude/scripts/) so deploy-root-guard.sh
# (sourced by the SUT) does not refuse the invocation. skill-base.sh is a STUB here, not the real
# file -- it defines only skill_postflight_update, logging every call to $CALL_LOG rather than
# touching specs/state.json, mirroring sibling suites' own verify-deploy gate-battery stubbing. ──
setup_sandbox() {
  rm -rf "$WORKDIR/sandbox"
  mkdir -p "$WORKDIR/sandbox/.claude/scripts/lib" "$WORKDIR/sandbox/specs/.orchestration"
  cp "$SUT_SRC" "$WORKDIR/sandbox/.claude/scripts/orchestrate-close-status-bind.sh"
  cp "$CORE_DIR/deploy-root-guard.sh" "$WORKDIR/sandbox/.claude/scripts/deploy-root-guard.sh"
  cp "$CORE_DIR/lib/common.sh" "$WORKDIR/sandbox/.claude/scripts/lib/common.sh"
  chmod +x "$WORKDIR/sandbox/.claude/scripts/orchestrate-close-status-bind.sh"
  SUT="$WORKDIR/sandbox/.claude/scripts/orchestrate-close-status-bind.sh"
  STATE_FILE="$WORKDIR/sandbox/specs/.orchestration/.orchestrator-multi-state-sess_test.json"
  CALL_LOG="$WORKDIR/sandbox/call.log"
  rm -f "$CALL_LOG"
  cat > "$WORKDIR/sandbox/.claude/scripts/skill-base.sh" <<EOF
#!/usr/bin/env bash
skill_postflight_update() {
  echo "\$1|\$2|\$3|\$4|\$5|\$6|\$7" >> "$CALL_LOG"
  return 0
}
EOF
}

run_sut() {
  # Usage: run_sut [extra args...]
  local stdout_file stderr_file
  stdout_file="$(mktemp)"; stderr_file="$(mktemp)"
  bash "$SUT" "$@" >"$stdout_file" 2>"$stderr_file"
  LAST_EXIT=$?
  # shellcheck disable=SC2034 # captured for run_sut helper parity with sibling suites
  # (test-orchestrate-batch-gate.sh's own run_sut); this suite's own cases assert on exit code
  # and stderr only, never stdout, but the field stays available for a future case.
  LAST_STDOUT="$(cat "$stdout_file")"
  LAST_STDERR="$(cat "$stderr_file")"
  rm -f "$stdout_file" "$stderr_file"
}

write_state() {
  # Usage: write_state <<'EOF' ... EOF
  cat > "$STATE_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 1: usage errors -- no arguments, and missing --state-file target.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 1: usage-error/degenerate paths"
setup_sandbox
run_sut
if [ "$LAST_EXIT" -eq 2 ] && echo "$LAST_STDERR" | grep -qi "usage"; then
  common_test_pass "Case 1: no arguments exits 2 with a usage message"
else
  common_test_fail "Case 1: expected exit 2 + usage message with no arguments, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi

run_sut --session sess_test --state-file "$WORKDIR/sandbox/specs/.orchestration/does-not-exist.json"
if [ "$LAST_EXIT" -eq 2 ] && echo "$LAST_STDERR" | grep -qi "not found"; then
  common_test_pass "Case 1: a missing --state-file target exits 2 with a clear error"
else
  common_test_fail "Case 1: expected exit 2 for a missing --state-file target, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 2: an attributed-cause completed candidate is demoted -- skill_postflight_update is called
# with status "partial" for that candidate.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 2: an attributed-cause completed candidate is demoted"
setup_sandbox
mkdir -p "$WORKDIR/sandbox/specs/930_alpha"
write_state <<'EOF'
{
  "completed_tasks": [930],
  "batch_gate": {
    "gate_exit_code": 1,
    "close_red_recorded_count": 1,
    "close_red_roster": [
      {"task": "930", "path": "specs/930_alpha/records/close-battery-red.jsonl", "finding_count": 1}
    ]
  }
}
EOF
run_sut --session sess_test --state-file "$STATE_FILE"
if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "Case 2: exits 0"
else
  common_test_fail "Case 2: expected exit 0, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
if grep -q "^930|implement|sess_test|partial|" "$CALL_LOG" 2>/dev/null; then
  common_test_pass "Case 2: skill_postflight_update called for candidate #930 with status=partial"
else
  common_test_fail "Case 2: expected a skill_postflight_update call for candidate #930 with status=partial, got: $(cat "$CALL_LOG" 2>/dev/null || echo MISSING)"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 3: a candidate absent from close_red_roster (unattributed-only, or simply not implicated)
# is never touched -- no skill_postflight_update call at all.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 3: an unattributed-only candidate is not touched"
setup_sandbox
write_state <<'EOF'
{
  "completed_tasks": [931],
  "batch_gate": {
    "gate_exit_code": 1,
    "close_red_recorded_count": 0,
    "close_red_roster": []
  }
}
EOF
run_sut --session sess_test --state-file "$STATE_FILE"
if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "Case 3: exits 0 (no-op)"
else
  common_test_fail "Case 3: expected exit 0, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
if [ ! -s "$CALL_LOG" ]; then
  common_test_pass "Case 3: no skill_postflight_update call for an empty close_red_roster"
else
  common_test_fail "Case 3: unexpected skill_postflight_update call(s): $(cat "$CALL_LOG")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 4: a clean close (no batch_gate.close_red_roster key at all, as orchestrate-batch-gate.sh
# never writes it with entries on a clean run) demotes nothing.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 4: a clean close demotes nothing"
setup_sandbox
write_state <<'EOF'
{
  "completed_tasks": [932],
  "batch_gate": {
    "gate_exit_code": 0,
    "close_red_recorded_count": 0,
    "close_red_roster": []
  }
}
EOF
run_sut --session sess_test --state-file "$STATE_FILE"
if [ ! -s "$CALL_LOG" ]; then
  common_test_pass "Case 4: no skill_postflight_update call on a clean close"
else
  common_test_fail "Case 4: unexpected skill_postflight_update call(s) on a clean close: $(cat "$CALL_LOG")"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 5: --dry-run never calls skill_postflight_update even when the roster would otherwise
# demote a candidate.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 5: --dry-run demotes nothing"
setup_sandbox
mkdir -p "$WORKDIR/sandbox/specs/933_beta"
write_state <<'EOF'
{
  "completed_tasks": [933],
  "batch_gate": {
    "gate_exit_code": 1,
    "close_red_recorded_count": 1,
    "close_red_roster": [
      {"task": "933", "path": "specs/933_beta/records/close-battery-red.jsonl", "finding_count": 1}
    ]
  }
}
EOF
run_sut --session sess_test --state-file "$STATE_FILE" --dry-run
if [ "$LAST_EXIT" -eq 0 ]; then
  common_test_pass "Case 5: exits 0"
else
  common_test_fail "Case 5: expected exit 0, got exit=$LAST_EXIT stderr=$LAST_STDERR"
fi
if [ ! -s "$CALL_LOG" ]; then
  common_test_pass "Case 5: no skill_postflight_update call under --dry-run"
else
  common_test_fail "Case 5: unexpected skill_postflight_update call(s) under --dry-run: $(cat "$CALL_LOG")"
fi
if echo "$LAST_STDERR" | grep -qi "dry-run"; then
  common_test_pass "Case 5: a dry-run notice is printed"
else
  common_test_fail "Case 5: expected a dry-run notice on stderr, got: $LAST_STDERR"
fi

# ═══════════════════════════════════════════════════════════════════════════════════════════════
# Case 6: a candidate present in close_red_roster but NOT in this invocation's completed_tasks
# (the fourth conjunct) is left untouched -- no skill_postflight_update call.
# ═══════════════════════════════════════════════════════════════════════════════════════════════
common_test_info "Case 6: a candidate not in completed_tasks is left untouched"
setup_sandbox
mkdir -p "$WORKDIR/sandbox/specs/934_gamma"
write_state <<'EOF'
{
  "completed_tasks": [],
  "batch_gate": {
    "gate_exit_code": 1,
    "close_red_recorded_count": 1,
    "close_red_roster": [
      {"task": "934", "path": "specs/934_gamma/records/close-battery-red.jsonl", "finding_count": 1}
    ]
  }
}
EOF
run_sut --session sess_test --state-file "$STATE_FILE"
if [ ! -s "$CALL_LOG" ]; then
  common_test_pass "Case 6: no skill_postflight_update call for a candidate absent from completed_tasks"
else
  common_test_fail "Case 6: unexpected skill_postflight_update call(s): $(cat "$CALL_LOG")"
fi
if echo "$LAST_STDERR" | grep -qi "not demoted"; then
  common_test_pass "Case 6: a not-demoted notice is printed"
else
  common_test_fail "Case 6: expected a not-demoted notice on stderr, got: $LAST_STDERR"
fi

echo ""
echo "========================================"
echo "test-orchestrate-close-status-bind.sh Summary"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
