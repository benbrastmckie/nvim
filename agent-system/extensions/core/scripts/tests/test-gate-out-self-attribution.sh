#!/usr/bin/env bash
# test-gate-out-self-attribution.sh - Focused SIBLING suite to test-gate-out-repair-reporting.sh,
# covering command-gate-out.sh's rc==6 branch (c) self-attribution screen (the "this task caused
# it" escape this task closes -- see context/patterns/batch-orchestration-guardrails.md's "### The
# Inter-Cycle Redeploy Checkpoint" subsection and deploy-baseline-lib.sh's own header).
#
# NOT added to test-gate-out-repair-reporting.sh directly: that suite's declared scope is the
# skill_validate_task_artifacts repair-reporting instrumentation, and its build_fixture_repo
# copies the REAL deployed update-task-status.sh (plus its full state-write.sh/task-lock.sh/
# generate-todo.sh/update-plan-status.sh/update-phase-status.sh/events-append.sh dependency
# chain) to exercise that instrumentation end to end. Reaching rc==6 through the REAL
# update-task-status.sh needs genuine deploy-staleness + modified_files-overlap state, which is
# exactly what this suite replaces with a minimal, call-counting STUB -- a materially different
# fixture shape, not an incremental addition to that file's existing cases.
#
# Fixture shape: command-gate-out.sh (source-store, under test) + skill-base.sh (source-store,
# sourced) + lib/deploy-baseline-lib.sh (source-store, sourced -- the one with
# deploy_baseline_self_attributable_findings, NOT the stale deployed copy) are the only real
# code under test. update-task-status.sh, deploy-headless.sh, and verify-deploy.sh are all
# STUBS: update-task-status.sh is call-counting (1st call simulates the completion-deploy gate's
# rc==6 refusal; 2nd+ call simulates a clean postflight retry), and verify-deploy.sh follows
# test-orchestrate-cycle-plan.sh's Group 11 write_g11_verify_stub contract (1st call = PRE
# findings only, 2nd call = PRE + POST findings) so branch (c) (every post-redeploy finding
# already present pre-redeploy) is the reachable branch, exactly as real deploy-headless.sh's
# universal exit 3 makes it in production. No plans/reports/summaries artifacts are created in
# the fixture's own task directory, so skill_validate_task_artifacts's per-file loop never
# iterates (an empty glob is skipped by its own `[ -e "$f" ] || continue` guard) -- validate-
# artifact.sh is therefore never invoked and does not need to be present.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required source-store script was not found).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
if [[ -z "$REPO_ROOT" ]]; then
  REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
fi

resolve_candidate() {
  local desc="$1"; shift
  local candidate
  for candidate in "$@"; do
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  echo "ERROR: $desc not found at any of:" >&2
  for candidate in "$@"; do
    echo "  $candidate" >&2
  done
  return 1
}

SKILL_BASE_SRC="$(resolve_candidate "skill-base.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/skill-base.sh" \
  "$REPO_ROOT/.claude/scripts/skill-base.sh")" || exit 2
GATE_OUT_SRC="$(resolve_candidate "command-gate-out.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/command-gate-out.sh" \
  "$REPO_ROOT/.claude/scripts/command-gate-out.sh")" || exit 2
BASELINE_LIB_SRC="$(resolve_candidate "deploy-baseline-lib.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh" \
  "$REPO_ROOT/.claude/scripts/lib/deploy-baseline-lib.sh")" || exit 2
# command-gate-out.sh now also sources this library unconditionally at its own top (the new
# derived-artifact staleness probe gate) -- added here as the same kind of required sourced
# collaborator as BASELINE_LIB_SRC immediately above, since this suite's fixture carries its own
# minimal, hand-picked set of libraries rather than a deployed-tree glob copy.
PROBE_LIB_SRC="$(resolve_candidate "derived-artifact-probe-lib.sh (source store)" \
  "$REPO_ROOT/agent-system/extensions/core/scripts/lib/derived-artifact-probe-lib.sh" \
  "$REPO_ROOT/.claude/scripts/lib/derived-artifact-probe-lib.sh")" || exit 2

if ! grep -q 'deploy_baseline_self_attributable_findings' "$BASELINE_LIB_SRC"; then
  echo "ERROR: resolved deploy-baseline-lib.sh ($BASELINE_LIB_SRC) does not define" >&2
  echo "       deploy_baseline_self_attributable_findings -- this is a STALE copy that" >&2
  echo "       predates the self-attribution screen." >&2
  exit 2
fi

PASSED=0
FAILED=0
pass() { echo "[PASS] $1"; PASSED=$((PASSED + 1)); }
fail() { echo "[FAIL] $1"; FAILED=$((FAILED + 1)); }

WORKDIR="$(mktemp -d)"
cleanup() { [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ] && rm -rf "$WORKDIR"; }
trap cleanup EXIT

BASELINE_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"

# write_utas_stub <root> <first_call_exit> <later_calls_exit>
#   Call-counting stub for update-task-status.sh. Marker file lives OUTSIDE $root/specs so a
#   fixture's own specs/ tree stays a faithful minimal snapshot.
write_utas_stub() {
  local root="$1" first_exit="$2" later_exit="$3"
  local marker="$root/.utas_call_count"
  cat > "$root/.claude/scripts/update-task-status.sh" <<EOF
#!/usr/bin/env bash
marker="$marker"
count=0
[ -f "\$marker" ] && count=\$(cat "\$marker")
count=\$((count + 1))
echo "\$count" > "\$marker"
if [ "\$count" -eq 1 ]; then
  echo "[stub update-task-status.sh] call #1 (postflight) -> simulated rc=$first_exit" >&2
  exit $first_exit
else
  echo "[stub update-task-status.sh] call #\$count (postflight retry) -> simulated rc=$later_exit" >&2
  exit $later_exit
fi
EOF
  chmod +x "$root/.claude/scripts/update-task-status.sh"
}

# write_deploy_headless_stub <root> <exit_code>
write_deploy_headless_stub() {
  local root="$1" rc="$2"
  cat > "$root/.claude/scripts/deploy-headless.sh" <<EOF
#!/usr/bin/env bash
echo "[stub deploy-headless.sh] simulated run, exit $rc" >&2
exit $rc
EOF
  chmod +x "$root/.claude/scripts/deploy-headless.sh"
}

# write_verify_deploy_stub <root> <pre_line_or_empty> <post_line_or_empty> <exit_code>
# Same call-counting contract as test-orchestrate-cycle-plan.sh's Group 11
# write_g11_verify_stub: 1st invocation prints PRE only; 2nd+ invocation prints PRE + POST --
# matching command-gate-out.sh's own call order (gate_out_pre_findings, then deploy-headless.sh,
# then gate_out_post_findings).
write_verify_deploy_stub() {
  local root="$1" pre="$2" post="$3" rc="$4"
  local marker="$root/.verify_call_count"
  cat > "$root/.claude/scripts/verify-deploy.sh" <<EOF
#!/usr/bin/env bash
marker="$marker"
count=0
[ -f "\$marker" ] && count=\$(cat "\$marker")
count=\$((count + 1))
echo "\$count" > "\$marker"
if [ -n "$pre" ]; then echo "$pre"; fi
if [ "\$count" -ge 2 ] && [ -n "$post" ]; then echo "$post"; fi
exit $rc
EOF
  chmod +x "$root/.claude/scripts/verify-deploy.sh"
}

# build_fixture_repo <root> <modified_files_json>: a minimal fixture repo carrying only what
# command-gate-out.sh's rc==6 branch actually needs -- NOT the full
# test-gate-out-repair-reporting.sh dependency chain (see this file's header for why).
build_fixture_repo() {
  local root="$1" mf="$2"
  mkdir -p "$root/.claude/scripts/lib" "$root/specs/001_fixture_task"
  cp "$SKILL_BASE_SRC" "$root/.claude/scripts/skill-base.sh"
  cp "$GATE_OUT_SRC" "$root/.claude/scripts/command-gate-out.sh"
  cp "$BASELINE_LIB_SRC" "$root/.claude/scripts/lib/deploy-baseline-lib.sh"
  cp "$PROBE_LIB_SRC" "$root/.claude/scripts/lib/derived-artifact-probe-lib.sh"
  chmod +x "$root/.claude/scripts/skill-base.sh" "$root/.claude/scripts/command-gate-out.sh"
  # task-lock.sh is called via `bash .claude/scripts/task-lock.sh ... || true` (tolerant of a
  # missing file already), but a trivial no-op stub keeps stderr free of "No such file" noise
  # this suite's assertions would otherwise have to filter around.
  cat > "$root/.claude/scripts/task-lock.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$root/.claude/scripts/task-lock.sh"
  cat > "$root/specs/state.json" <<'EOF'
{
  "next_project_number": 2,
  "active_projects": [
    {
      "project_number": 1,
      "project_name": "fixture_task",
      "status": "implementing",
      "task_type": "general",
      "next_artifact_number": 2
    }
  ]
}
EOF
  cat > "$root/specs/001_fixture_task/.return-meta.json" <<EOF
{"status": "implemented", "modified_files": ${mf}}
EOF
}

RULEQ_LINE='FINDING gate3 [core] FAIL: script file on disk NOT in provides.scripts: scripts/tests/test-gate-self-attr.sh'

# =====================================================================
# Case 1: self-attributed fixture -- the postflight retry is WITHHELD and the fixture's own
# status marker stays unchanged.
# =====================================================================
CASE1_ROOT="$WORKDIR/case1"
build_fixture_repo "$CASE1_ROOT" '["agent-system/extensions/core/scripts/tests/test-gate-self-attr.sh"]'
write_utas_stub "$CASE1_ROOT" 6 0
write_deploy_headless_stub "$CASE1_ROOT" 3
write_verify_deploy_stub "$CASE1_ROOT" "$RULEQ_LINE" "" 1
CASE1_OUT="$(cd "$CASE1_ROOT" && bash .claude/scripts/command-gate-out.sh 1 implement sess_case1 2>&1)"
CASE1_UTAS_CALLS="$(cat "$CASE1_ROOT/.utas_call_count" 2>/dev/null || echo 0)"
if [ "$CASE1_UTAS_CALLS" = "1" ]; then
  pass "Case 1 (self-attributed fixture): update-task-status.sh is called exactly ONCE -- the postflight retry is withheld"
else
  fail "Case 1 (self-attributed fixture): expected exactly 1 update-task-status.sh call, got $CASE1_UTAS_CALLS"
fi
if grep -qF "Withholding completion for task 1 (self-attributed finding" <<< "$CASE1_OUT"; then  # task-ref-ok literal fixture stderr wording from command-gate-out.sh, fixture task number is 1
  pass "Case 1 (self-attributed fixture): the withholding notice names the fixture task"
else
  fail "Case 1 (self-attributed fixture): withholding notice missing. Output:
$CASE1_OUT"
fi
if grep -qF "$RULEQ_LINE" <<< "$CASE1_OUT"; then
  pass "Case 1 (self-attributed fixture): the attributing finding is printed"
else
  fail "Case 1 (self-attributed fixture): the attributing finding was not printed"
fi
if grep -qF "Re-attempting postflight for task 1" <<< "$CASE1_OUT"; then  # task-ref-ok literal fixture stderr wording, fixture task number is 1
  fail "Case 1 (self-attributed fixture): the re-attempt line fired despite withholding"
else
  pass "Case 1 (self-attributed fixture): the ordinary re-attempt line does NOT fire"
fi

# =====================================================================
# Case 2: NOT self-attributed -- the postflight retry proceeds exactly as before this screen.
# =====================================================================
CASE2_ROOT="$WORKDIR/case2"
build_fixture_repo "$CASE2_ROOT" '["lua/neotex/core/options.lua"]'
write_utas_stub "$CASE2_ROOT" 6 0
write_deploy_headless_stub "$CASE2_ROOT" 3
write_verify_deploy_stub "$CASE2_ROOT" "$RULEQ_LINE" "" 1
CASE2_OUT="$(cd "$CASE2_ROOT" && bash .claude/scripts/command-gate-out.sh 1 implement sess_case2 2>&1)"
CASE2_UTAS_CALLS="$(cat "$CASE2_ROOT/.utas_call_count" 2>/dev/null || echo 0)"
if [ "$CASE2_UTAS_CALLS" = "2" ]; then
  pass "Case 2 (not self-attributed): update-task-status.sh is called twice -- the postflight retry proceeds"
else
  fail "Case 2 (not self-attributed): expected exactly 2 update-task-status.sh calls, got $CASE2_UTAS_CALLS"
fi
if grep -qF "Re-attempting postflight for task 1" <<< "$CASE2_OUT"; then  # task-ref-ok literal fixture stderr wording, fixture task number is 1
  pass "Case 2 (not self-attributed): the ordinary re-attempt line fires"
else
  fail "Case 2 (not self-attributed): the re-attempt line did not fire. Output:
$CASE2_OUT"
fi
if grep -qF "transition succeeded after redeploy" <<< "$CASE2_OUT"; then
  pass "Case 2 (not self-attributed): the transition-succeeded line fires"
else
  fail "Case 2 (not self-attributed): the transition-succeeded line did not fire"
fi
if grep -qF "Withholding completion" <<< "$CASE2_OUT"; then
  fail "Case 2 (not self-attributed): withholding notice fired despite an unrelated modified_files set"
else
  pass "Case 2 (not self-attributed): no withholding notice fires"
fi

# =====================================================================
# Case 3: SELF_ATTRIBUTION_GATE_MODE=off -- restores the pre-screen behavior even when
# self-attributed (the live rollback escape hatch this task's plan names).
# =====================================================================
CASE3_ROOT="$WORKDIR/case3"
build_fixture_repo "$CASE3_ROOT" '["agent-system/extensions/core/scripts/tests/test-gate-self-attr.sh"]'
write_utas_stub "$CASE3_ROOT" 6 0
write_deploy_headless_stub "$CASE3_ROOT" 3
write_verify_deploy_stub "$CASE3_ROOT" "$RULEQ_LINE" "" 1
CASE3_OUT="$(cd "$CASE3_ROOT" && SELF_ATTRIBUTION_GATE_MODE=off bash .claude/scripts/command-gate-out.sh 1 implement sess_case3 2>&1)"
CASE3_UTAS_CALLS="$(cat "$CASE3_ROOT/.utas_call_count" 2>/dev/null || echo 0)"
if [ "$CASE3_UTAS_CALLS" = "2" ]; then
  pass "Case 3 (mode=off): the postflight retry proceeds despite self-attribution"
else
  fail "Case 3 (mode=off): expected exactly 2 update-task-status.sh calls, got $CASE3_UTAS_CALLS"
fi
if grep -qF "transition succeeded after redeploy" <<< "$CASE3_OUT"; then
  pass "Case 3 (mode=off): the transition-succeeded line fires"
else
  fail "Case 3 (mode=off): the transition-succeeded line did not fire. Output:
$CASE3_OUT"
fi

# =====================================================================
# Contamination guard: no case ever touches the real specs/ tree.
# =====================================================================
AFTER_SPECS_STATUS="$(cd "$REPO_ROOT" && git status --short specs/ 2>/dev/null)"
if [ "$BASELINE_SPECS_STATUS" = "$AFTER_SPECS_STATUS" ]; then
  pass "real specs/ tree status is unchanged relative to this suite's pre-run baseline"
else
  fail "real specs/ tree status CHANGED during this suite's run -- contamination (before: '$BASELINE_SPECS_STATUS' after: '$AFTER_SPECS_STATUS')"
fi

echo ""
echo "====================================="
echo "Results: $PASSED passed, $FAILED failed"
echo "====================================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
