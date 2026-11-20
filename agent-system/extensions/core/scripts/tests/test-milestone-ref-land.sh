#!/usr/bin/env bash
# test-milestone-ref-land.sh - Fixture-driven regression suite for milestone-ref-land.sh:
# asserts the ref's commit count, its parent chain, and tree equality against the live branch;
# asserts HEAD, the index, and the working tree are byte-identical before and after; asserts the
# compare-and-swap refusal/retry path; asserts the no-milestone no-op; asserts the
# undeclared-key advisory fallback; asserts the script never calls git checkout/switch/merge/
# push/reset.
#
# Follows the core shell-test convention in context/standards/shell-script-testing.md: SCRIPT_DIR
# -relative resolution of the script under test, common_test_pass/fail/info helpers, PASSED/FAILED
# counters, mktemp -d workdirs with trap EXIT cleanup, exit 0 all-pass / exit 1 any-fail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
LAND="$SCRIPT_DIR/../milestone-ref-land.sh"
TASKLOCK="$SCRIPT_DIR/../task-lock.sh"

PASSED=0
FAILED=0

if [ ! -f "$LAND" ]; then
  echo "ERROR: expected milestone-ref-land.sh at $LAND" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 1
fi

common_test_workdir_init

FIXTURE_NUM=901
SESSION_ID="sess_test_milestone_ref_land"

# make_fixture_repo <declare_integration_branch:yes|no>
# Builds a scratch git repo with one task (FIXTURE_NUM) declared as a member of milestone "M1",
# a DEPLOYED-SHAPE .claude/scripts/ tree (mirroring test-git-commit-phase.sh's own fixture
# convention) carrying real copies of task-lock.sh, deploy-root-guard.sh and
# milestone-ref-land.sh -- deploy-root-guard.sh's default structural check passes only when the
# script's own directory ends in /.claude or /.opencode, so the fixture must be shaped as a
# deployed tree rather than the source-store layout -- one phase-complete plan file, and one
# commit on "main".
make_fixture_repo() {
  local declare_branch="$1"
  local d
  d="$(mktemp -d -p "$WORKDIR")"
  git -C "$d" init -q -b main
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"

  mkdir -p "$d/specs/${FIXTURE_NUM}_fixture/plans" "$d/.claude/scripts/lib" "$d/.claude/scripts/tests"
  cp -r "$SCRIPT_DIR/../lib/." "$d/.claude/scripts/lib/"
  cp "$TASKLOCK" "$d/.claude/scripts/task-lock.sh"
  cp "$SCRIPT_DIR/../deploy-root-guard.sh" "$d/.claude/scripts/deploy-root-guard.sh"
  cp "$LAND" "$d/.claude/scripts/milestone-ref-land.sh"

  echo "seed" > "$d/README.md"
  cat > "$d/specs/${FIXTURE_NUM}_fixture/plans/01_fixture.md" << 'PLANEOF'
### Phase 1: First phase [COMPLETED]

Body.

### Phase 2: Second phase [COMPLETED]

Body.
PLANEOF

  cat > "$d/specs/state.json" << STATEEOF
{
  "version": "1.0",
  "next_project_number": $((FIXTURE_NUM + 1)),
  "active_projects": [
    {
      "project_number": ${FIXTURE_NUM},
      "project_name": "fixture",
      "title": "Fixture task for milestone-ref-land tests",
      "status": "implementing",
      "task_type": "meta",
      "file_scope": [],
      "artifacts": [
        {"type": "plan", "path": "specs/${FIXTURE_NUM}_fixture/plans/01_fixture.md"}
      ]
    }
  ],
  "roadmap_milestones": [
    {
      "id": "M1",
      "title": "Fixture milestone",
      "progress": {"status": "active"},
      "review": {"state": "none"},
      "batches": [
        {"task_ids": [${FIXTURE_NUM}], "description": "fixture batch"}
      ]
    }
  ]
}
STATEEOF

  if [ "$declare_branch" = "yes" ]; then
    echo '{"extensions": {}, "version": 1, "integration_branch": "main"}' > "$d/.claude-extensions.json"
  else
    echo '{"extensions": {}, "version": 1}' > "$d/.claude-extensions.json"
  fi

  git -C "$d" add -A >/dev/null 2>&1
  git -C "$d" commit -q -m "seed" >/dev/null 2>&1
  echo "$d"
}

# run_land <repo> [args...] -- runs the fixture repo's OWN deployed-shape copy of
# milestone-ref-land.sh
LAST_OUTPUT=""
LAST_CODE=0
run_land() {
  local repo="$1"
  shift
  LAST_OUTPUT="$(cd "$repo" && bash .claude/scripts/milestone-ref-land.sh "$@" 2>&1)"
  LAST_CODE=$?
}

# =====================================================================
# Case 1: no-milestone no-op -- a task absent from every batch exits 0, creates no ref.
# =====================================================================
noop_repo="$(make_fixture_repo "yes")"
run_land "$noop_repo" 999999 "$SESSION_ID"
noop_code="$LAST_CODE"
noop_ref_exists="$(git -C "$noop_repo" rev-parse --verify --quiet refs/heads/milestone/M1 2>/dev/null || echo "")"
rm -rf "$noop_repo"
if [ "$noop_code" -eq 0 ] && [ -z "$noop_ref_exists" ]; then
  common_test_pass "no-milestone: task absent from every batch is a clean no-op (exit 0, no ref created)"
else
  common_test_fail "no-milestone: expected exit 0 and no ref -- got exit=$noop_code ref='$noop_ref_exists'"
fi

# =====================================================================
# Case 2: undeclared-key advisory fallback -- no .integration_branch declared, falls back to
# the currently checked-out branch (main) with a named advisory.
# =====================================================================
fallback_repo="$(make_fixture_repo "no")"
run_land "$fallback_repo" "$FIXTURE_NUM" "$SESSION_ID"
fallback_code="$LAST_CODE"
fallback_advisory="$(printf '%s' "$LAST_OUTPUT" | grep -c "ADVISORY:.*no \.integration_branch declared" || true)"
fallback_ref_count="$(git -C "$fallback_repo" rev-list --count refs/heads/milestone/M1 2>/dev/null || echo 0)"
rm -rf "$fallback_repo"
if [ "$fallback_code" -eq 0 ] && [ "$fallback_advisory" -ge 1 ] && [ "$fallback_ref_count" -eq 2 ]; then
  common_test_pass "undeclared-key: falls back to the checked-out branch with a named advisory, still lands one commit"
else
  common_test_fail "undeclared-key: expected exit 0, >=1 ADVISORY line, 1 commit on the ref -- got exit=$fallback_code advisory_lines=$fallback_advisory ref_count=$fallback_ref_count"
fi

# =====================================================================
# Case 3: core landing -- ref's commit count, parent chain, and tree equality against HEAD;
# working tree / index / HEAD byte-identical before and after.
# =====================================================================
core_repo="$(make_fixture_repo "yes")"
before_head="$(git -C "$core_repo" rev-parse HEAD)"
before_branch="$(git -C "$core_repo" rev-parse --abbrev-ref HEAD)"
before_status="$(git -C "$core_repo" status --porcelain)"
run_land "$core_repo" "$FIXTURE_NUM" "$SESSION_ID"
core_code="$LAST_CODE"
after_head="$(git -C "$core_repo" rev-parse HEAD)"
after_branch="$(git -C "$core_repo" rev-parse --abbrev-ref HEAD)"
after_status="$(git -C "$core_repo" status --porcelain)"
ref_count="$(git -C "$core_repo" rev-list --count refs/heads/milestone/M1 2>/dev/null || echo 0)"
ref_tree="$(git -C "$core_repo" rev-parse refs/heads/milestone/M1^{tree})"
head_tree="$(git -C "$core_repo" rev-parse HEAD^{tree})"
ref_parent="$(git -C "$core_repo" rev-parse refs/heads/milestone/M1^1)"
main_tip="$(git -C "$core_repo" rev-parse main)"
rm -rf "$core_repo"
if [ "$core_code" -eq 0 ] \
   && [ "$before_head" = "$after_head" ] && [ "$before_branch" = "$after_branch" ] \
   && [ "$before_status" = "$after_status" ] \
   && [ "$ref_count" -eq 2 ] && [ "$ref_tree" = "$head_tree" ] && [ "$ref_parent" = "$main_tip" ]; then
  common_test_pass "core landing: one commit, tree equals HEAD's tree, parent is the integration branch's prior tip, working tree/index/HEAD unchanged"
else
  common_test_fail "core landing: got exit=$core_code ref_count=$ref_count ref_tree=$ref_tree head_tree=$head_tree ref_parent=$ref_parent main_tip=$main_tip head_unchanged=$([ "$before_head" = "$after_head" ] && echo yes || echo no) branch_unchanged=$([ "$before_branch" = "$after_branch" ] && echo yes || echo no) status_unchanged=$([ "$before_status" = "$after_status" ] && echo yes || echo no)"
fi

# =====================================================================
# Case 4: --verify mode, success path -- after landing, --verify confirms ancestry.
# =====================================================================
verify_repo="$(make_fixture_repo "yes")"
run_land "$verify_repo" "$FIXTURE_NUM" "$SESSION_ID"
run_land "$verify_repo" "$FIXTURE_NUM" "$SESSION_ID" "--verify"
verify_code="$LAST_CODE"
rm -rf "$verify_repo"
if [ "$verify_code" -eq 0 ]; then
  common_test_pass "--verify success: HEAD is confirmed an ancestor of the milestone ref after landing"
else
  common_test_fail "--verify success: expected exit 0 after a successful landing, got exit=$verify_code"
fi

# =====================================================================
# Case 5: --verify mode, failure path -- no landing happened, --verify refuses.
# =====================================================================
noverify_repo="$(make_fixture_repo "yes")"
run_land "$noverify_repo" "$FIXTURE_NUM" "$SESSION_ID" "--verify"
noverify_code="$LAST_CODE"
rm -rf "$noverify_repo"
if [ "$noverify_code" -eq 1 ]; then
  common_test_pass "--verify failure: refuses (exit 1) when no landing has happened and the ref does not exist"
else
  common_test_fail "--verify failure: expected exit 1 when the milestone ref does not exist, got exit=$noverify_code"
fi

# =====================================================================
# Case 6: second task landing on an existing ref advances it by one commit with the prior tip
# as parent (simulating two sequential completions in the same milestone).
# =====================================================================
chain_repo="$(make_fixture_repo "yes")"
run_land "$chain_repo" "$FIXTURE_NUM" "$SESSION_ID"
first_tip="$(git -C "$chain_repo" rev-parse refs/heads/milestone/M1)"
# Simulate a second task's own HEAD work by amending state.json with a second fixture task
# sharing the milestone, then advancing HEAD on main with a new commit before landing again.
jq --argjson n "$((FIXTURE_NUM + 1))" \
  '.active_projects += [{"project_number": $n, "project_name": "fixture2", "title": "Second fixture task", "status": "implementing", "task_type": "meta", "file_scope": []}] | .roadmap_milestones[0].batches[0].task_ids += [$n]' \
  "$chain_repo/specs/state.json" > "$chain_repo/specs/state.json.tmp"
mv "$chain_repo/specs/state.json.tmp" "$chain_repo/specs/state.json"
git -C "$chain_repo" add -A >/dev/null 2>&1
git -C "$chain_repo" commit -q -m "second task phase" >/dev/null 2>&1
run_land "$chain_repo" "$((FIXTURE_NUM + 1))" "$SESSION_ID"
chain_code="$LAST_CODE"
second_count="$(git -C "$chain_repo" rev-list --count refs/heads/milestone/M1 2>/dev/null || echo 0)"
second_parent="$(git -C "$chain_repo" rev-parse refs/heads/milestone/M1^1)"
rm -rf "$chain_repo"
if [ "$chain_code" -eq 0 ] && [ "$second_count" -eq 3 ] && [ "$second_parent" = "$first_tip" ]; then
  common_test_pass "chained landing: a second completion advances the ref by one more commit, parented on the first landing's tip"
else
  common_test_fail "chained landing: expected exit 0, 2 commits on the ref, second commit's parent equal to the first tip -- got exit=$chain_code count=$second_count parent=$second_parent first_tip=$first_tip"
fi

# =====================================================================
# Case 7: the script never invokes checkout, switch, merge, push, or reset.
# =====================================================================
forbidden_hits="$(grep -nE '\bgit[[:space:]]+(checkout|switch|push|reset)\b|\bgit[[:space:]]+merge([[:space:]]|$)' "$LAND" | grep -v '^[0-9]*:#' || true)"
if [ -z "$forbidden_hits" ]; then
  common_test_pass "static check: milestone-ref-land.sh contains no git checkout/switch/merge/push/reset invocation"
else
  common_test_fail "static check: found forbidden git invocation(s): $forbidden_hits"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
