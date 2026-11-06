#!/usr/bin/env bash
# test-validate-task-creation-audit.sh - Fixture suite for
# hooks/validate-task-creation-audit.sh, the Bash-matcher structural backstop against bypassing
# scripts/state-write.sh's audit-evidence gate.
#
# Structural model: test-lint-state-writer-boundary.sh (common_test_repo_root, the explicit
# mode-selectable subject resolver in lib/common.sh, common_test_workdir_init,
# common_test_pass/fail/info, PASSED/FAILED counters), adapted for a PreToolUse hook: each case
# feeds a synthetic {"tool_name": ..., "tool_input": {"command": ...}} JSON document on stdin and asserts the
# hook's exit code.
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"
HOOK_SCRIPT="$(common_test_resolve_subject "validate-task-creation-audit.sh" "deploy-tree-first" \
  "$REPO_ROOT/.claude/hooks/validate-task-creation-audit.sh" \
  "$SCRIPT_DIR/../../hooks/validate-task-creation-audit.sh")" || exit 2
common_test_declare_subject "$HOOK_SCRIPT"

PASSED=0
FAILED=0
common_test_workdir_init

run_hook() {
  # run_hook <tool_name> <command>
  jq -nc --arg tn "$1" --arg cmd "$2" '{tool_name: $tn, tool_input: {command: $cmd}}' \
    | bash "$HOOK_SCRIPT" > "$WORKDIR/out.txt" 2>"$WORKDIR/err.txt"
  echo $?
}

# =====================================================================
# Case 1: a raw jq active_projects write (stage-then-mv shape) -- refused with exit 2.
# =====================================================================
common_test_info "=== Case 1: raw jq active_projects write refused ==="
rc="$(run_hook "Bash" 'jq ".active_projects += [{\"project_number\":99}]" specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json')"
if [ "$rc" = "2" ]; then
  common_test_pass "raw jq active_projects stage-then-mv write refused with exit 2"
else
  common_test_fail "raw jq active_projects write exited $rc (expected 2): $(cat "$WORKDIR/err.txt" 2>/dev/null)"
fi
if grep -q "state-write.sh" "$WORKDIR/err.txt" 2>/dev/null; then
  common_test_pass "refusal message names state-write.sh as the remedy"
else
  common_test_fail "refusal message did not name state-write.sh: $(cat "$WORKDIR/err.txt" 2>/dev/null)"
fi

# Direct-overwrite variant (no staging file, same target as source and destination of the
# redirect) -- same refusal.
rc="$(run_hook "Bash" 'jq ".active_projects += [{\"project_number\":99}]" specs/state.json > specs/state.json')"
if [ "$rc" = "2" ]; then
  common_test_pass "raw jq active_projects direct-overwrite write refused with exit 2"
else
  common_test_fail "raw jq active_projects direct-overwrite exited $rc (expected 2): $(cat "$WORKDIR/err.txt" 2>/dev/null)"
fi

# =====================================================================
# Case 2: a state-write.sh call -- allowed.
# =====================================================================
common_test_info "=== Case 2: state-write.sh call allowed ==="
rc="$(run_hook "Bash" 'bash .claude/scripts/state-write.sh ".active_projects += [{\"project_number\":99}]" --allocate-into new_num --session-id sess_x')"
if [ "$rc" = "0" ]; then
  common_test_pass "a state-write.sh call is allowed (exit 0)"
else
  common_test_fail "a state-write.sh call exited $rc (expected 0): $(cat "$WORKDIR/err.txt" 2>/dev/null)"
fi

# =====================================================================
# Case 3: a read-only jq query against state.json (no write at all) -- allowed.
# =====================================================================
common_test_info "=== Case 3: read-only jq query allowed ==="
rc="$(run_hook "Bash" 'jq ".active_projects[] | .project_number" specs/state.json')"
if [ "$rc" = "0" ]; then
  common_test_pass "a read-only jq query (no redirect) is allowed (exit 0)"
else
  common_test_fail "a read-only jq query exited $rc (expected 0): $(cat "$WORKDIR/err.txt" 2>/dev/null)"
fi

rc="$(run_hook "Bash" 'jq -e ".active_projects[] | select(.project_number==99)" specs/state.json > /dev/null')"
if [ "$rc" = "0" ]; then
  common_test_pass "a read-only jq existence check (redirect to /dev/null) is allowed (exit 0)"
else
  common_test_fail "a read-only jq existence check exited $rc (expected 0): $(cat "$WORKDIR/err.txt" 2>/dev/null)"
fi

# =====================================================================
# Case 4: a write to an unrelated file -- allowed.
# =====================================================================
common_test_info "=== Case 4: write to an unrelated file allowed ==="
rc="$(run_hook "Bash" 'echo hello > /tmp/some-other-file.txt')"
if [ "$rc" = "0" ]; then
  common_test_pass "a write to an unrelated file is allowed (exit 0)"
else
  common_test_fail "a write to an unrelated file exited $rc (expected 0): $(cat "$WORKDIR/err.txt" 2>/dev/null)"
fi

# A write-shape targeting state.json that never mentions active_projects -- outside this hook's
# declared scope, allowed (left to the state-writer-boundary lint / Phase 5's gate).
rc="$(run_hook "Bash" 'jq ".next_project_number = 5" specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json')"
if [ "$rc" = "0" ]; then
  common_test_pass "a state.json write-shape that never mentions active_projects is outside this hook's scope (exit 0)"
else
  common_test_fail "a non-active_projects state.json write exited $rc (expected 0): $(cat "$WORKDIR/err.txt" 2>/dev/null)"
fi

# =====================================================================
# Case 5: non-Bash tool invocations are ignored entirely.
# =====================================================================
common_test_info "=== Case 5: non-Bash tool ignored ==="
rc="$(jq -nc '{tool_name: "Write", tool_input: {file_path: "specs/state.json"}}' | bash "$HOOK_SCRIPT" > "$WORKDIR/out.txt" 2>"$WORKDIR/err.txt"; echo $?)"
if [ "$rc" = "0" ]; then
  common_test_pass "a Write tool_name is ignored entirely (exit 0, this hook is Bash-matcher only)"
else
  common_test_fail "a Write tool_name was not ignored: exited $rc"
fi

# =====================================================================
# Summary
# =====================================================================
echo ""
echo "Results: $PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
