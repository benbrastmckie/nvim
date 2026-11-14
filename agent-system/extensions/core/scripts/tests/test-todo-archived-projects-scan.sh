#!/usr/bin/env bash
# test-todo-archived-projects-scan.sh - Regression suite for the /todo orphan/misplaced-
# directory detection defect: all three read-back scans in commands/todo.md (orphans-in-specs,
# orphans-in-archive, the misplaced-directory scan) used to query ONLY
# `.completed_projects[]` in specs/archive/state.json. Abandoned tasks route to the sibling
# `.archived_projects[]` array, so every directory belonging to an abandoned-then-archived task
# read as an untracked orphan that was not one. The archive WRITE path was already correct
# (it populates both arrays); only the read-back was blind. See the three sites' own
# `(.completed_projects + .archived_projects)[]` selector for the fix this suite pins.
#
# WHAT THIS SUITE CAN AND CANNOT COVER (stated plainly, not hidden): commands/todo.md is
# agent-executed markdown, not a script, so this suite cannot invoke it directly. The
# BEHAVIORAL half below reproduces the exact jq filter shape (fixed vs. pre-fix) against a
# throwaway specs/archive/state.json fixture, proving the filter itself behaves as expected in
# both directions. The STATIC half separately asserts that commands/todo.md's actual text uses
# the fixed filter at all three read-back sites and has zero remaining bare
# `.completed_projects[]` read-back filters. Neither half alone is the regression net -- the
# behavioral half cannot see whether the recipe USES the fixed filter, and the static half
# cannot see whether the filter itself WORKS. Together they pin the defect.
#
# Cases:
#   Behavioral (positive + negative control):
#     - Fixed filter `(.completed_projects + .archived_projects)[] | select(...)` against a
#       fixture holding one entry in each array: BOTH entries are found (neither reads as an
#       orphan).
#     - Negative control: the pre-fix filter `.completed_projects[] | select(...)` against the
#       SAME fixture: the completed entry is found but the archived entry is MISSED -- a
#       negative control that passes as positive (i.e. does not detect the broken shape) is
#       itself a suite failure, since it would mean this suite could not have caught the live
#       defect.
#   Static, over the real recipe text (not a fixture):
#     - commands/todo.md contains zero remaining bare
#       `.completed_projects[] | select(.project_number` read-back filters.
#     - All three surviving read-back sites (orphans-in-specs, orphans-in-archive, the
#       misplaced-directory scan) name both arrays via
#       `(.completed_projects + .archived_projects)[]`.
#
# Structural model: scripts/tests/test-todo-move-pair-staging.sh (pass()/fail()/info() helpers,
# PASSED/FAILED integer counters, deploy-tree-first/source-store-fallback subject resolution via
# the shared declared-subject helper pair, common_test_workdir_init for the throwaway fixture
# directory).
#
# Exit codes: 0 -- all cases PASS; 1 -- at least one case FAILED; 2 -- environment error (a
# required file or tool was not found at any candidate path).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
REPO_ROOT="$(common_test_repo_root "$SCRIPT_DIR")"

# Source-store copy preferred over the deployed copy: this suite's static half exists to verify
# the task's own source-store edits, which lag the deployed `.claude/` tree until the next
# redeploy. Once redeployed the two copies are byte-identical, so this order is harmless
# post-deploy and necessary pre-deploy -- a hard correctness requirement (mode=source-store).
TODO_MD="$(common_test_resolve_subject "commands/todo.md" "source-store" \
  "$REPO_ROOT/.claude/commands/todo.md" \
  "$SCRIPT_DIR/../../commands/todo.md")" || exit 2
common_test_declare_subject "$TODO_MD"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not available; this suite's behavioral half requires it" >&2
  exit 2
fi

PASSED=0
FAILED=0

common_test_workdir_init

# =====================================================================
# Behavioral half
# =====================================================================

FIXTURE="$WORKDIR/archive-state.json"
cat > "$FIXTURE" <<'EOF'
{
  "completed_projects": [
    {"project_number": 42, "project_name": "fixture_completed_task", "status": "completed"}
  ],
  "archived_projects": [
    {"project_number": 99, "project_name": "fixture_abandoned_task", "status": "abandoned"}
  ]
}
EOF

common_test_info "Behavioral half: fixed filter against a fixture holding one entry in each array."

fixed_completed="$(jq -r --arg n "42" \
  '(.completed_projects + .archived_projects)[] | select(.project_number == ($n | tonumber)) | .project_number' \
  "$FIXTURE" 2>/dev/null)"
fixed_archived="$(jq -r --arg n "99" \
  '(.completed_projects + .archived_projects)[] | select(.project_number == ($n | tonumber)) | .project_number' \
  "$FIXTURE" 2>/dev/null)"

if [ "$fixed_completed" = "42" ]; then
  common_test_pass "fixed filter: completed_projects entry (42) found"
else
  common_test_fail "fixed filter: completed_projects entry (42) NOT found (got: '$fixed_completed')"
fi
if [ "$fixed_archived" = "99" ]; then
  common_test_pass "fixed filter: archived_projects entry (99) found -- an abandoned-then-archived task directory is no longer reported as an orphan"
else
  common_test_fail "fixed filter: archived_projects entry (99) NOT found (got: '$fixed_archived') -- the fix did not reach this fixture"
fi

common_test_info "Behavioral half, negative control: pre-fix filter against the SAME fixture must MISS the archived_projects entry."

prefix_completed="$(jq -r --arg n "42" \
  '.completed_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
  "$FIXTURE" 2>/dev/null)"
prefix_archived="$(jq -r --arg n "99" \
  '.completed_projects[] | select(.project_number == ($n | tonumber)) | .project_number' \
  "$FIXTURE" 2>/dev/null)"

if [ "$prefix_completed" = "42" ]; then
  common_test_pass "negative control: pre-fix filter still finds completed_projects entry (42), as expected"
else
  common_test_fail "negative control: pre-fix filter unexpectedly missed completed_projects entry (42) (got: '$prefix_completed')"
fi
if [ -z "$prefix_archived" ]; then
  common_test_pass "negative control: pre-fix filter correctly MISSES archived_projects entry (99) -- this fixture would have caught the live defect"
else
  common_test_fail "negative control: pre-fix filter unexpectedly found archived_projects entry (99) (got: '$prefix_archived') -- this fixture could NOT have caught the live defect"
fi

# =====================================================================
# Static half: assert the real recipe text actually uses the fixed filter at all three sites
# and carries zero remaining bare read-back filters.
# =====================================================================

bare_count="$(grep -cE '\.completed_projects\[\] \| select\(\.project_number' "$TODO_MD" || true)"
if [ "$bare_count" -eq 0 ]; then
  common_test_pass "commands/todo.md: zero remaining bare '.completed_projects[] | select(.project_number' read-back filters"
else
  common_test_fail "commands/todo.md: found $bare_count remaining bare read-back filter(s) -- the fix did not reach every site"
fi

fixed_count="$(grep -cE '\(\.completed_projects \+ \.archived_projects\)\[\] \| select\(\.project_number' "$TODO_MD" || true)"
if [ "$fixed_count" -eq 3 ]; then
  common_test_pass "commands/todo.md: all three read-back sites name both arrays via '(.completed_projects + .archived_projects)[]'"
else
  common_test_fail "commands/todo.md: expected exactly 3 fixed read-back sites, found $fixed_count"
fi

echo ""
echo "$PASSED passed, $FAILED failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
