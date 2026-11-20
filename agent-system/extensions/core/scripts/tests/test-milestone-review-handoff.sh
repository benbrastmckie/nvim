#!/usr/bin/env bash
# test-milestone-review-handoff.sh - Fixture-driven regression suite for
# milestone-review-handoff.sh: asserts the fires-once-on-transition behaviour, the ref-mismatch
# warning path, the review field writes and their enum conformance, the untouched
# progress.status, the literal-command output, and the absence of every push-shaped call.
#
# Follows the deployed-shape sandbox convention established by test-milestone-ref-land.sh
# (deploy-root-guard.sh's default structural check requires the script's own directory to end
# in /.claude or /.opencode).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
HANDOFF="$SCRIPT_DIR/../milestone-review-handoff.sh"
TASKLOCK="$SCRIPT_DIR/../task-lock.sh"
STATEWRITE="$SCRIPT_DIR/../state-write.sh"
GUARD="$SCRIPT_DIR/../deploy-root-guard.sh"

PASSED=0
FAILED=0

if [ ! -f "$HANDOFF" ]; then
  echo "ERROR: expected milestone-review-handoff.sh at $HANDOFF" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 1
fi

common_test_workdir_init

SESSION_ID="sess_test_milestone_review_handoff"

# make_fixture_repo <done:yes|no> -- a deployed-shape sandbox with one milestone "M1" holding one
# batch of one task. "yes" marks the task completed (b_done == b); "no" leaves it implementing.
make_fixture_repo() {
  local done="$1"
  local d status_val
  d="$(mktemp -d -p "$WORKDIR")"
  git -C "$d" init -q -b main
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"

  mkdir -p "$d/specs" "$d/.claude/scripts/lib"
  cp -r "$SCRIPT_DIR/../lib/." "$d/.claude/scripts/lib/"
  cp "$TASKLOCK" "$d/.claude/scripts/task-lock.sh"
  cp "$GUARD" "$d/.claude/scripts/deploy-root-guard.sh"
  cp "$STATEWRITE" "$d/.claude/scripts/state-write.sh"
  cp "$HANDOFF" "$d/.claude/scripts/milestone-review-handoff.sh"
  chmod +x "$d"/.claude/scripts/*.sh

  if [ "$done" = "yes" ]; then
    status_val="completed"
  else
    status_val="implementing"
  fi

  cat > "$d/specs/state.json" << EOF
{
  "version": "1.0",
  "next_project_number": 932,
  "active_projects": [
    {"project_number": 931, "project_name": "fixture", "title": "Fixture task", "status": "${status_val}", "task_type": "meta", "file_scope": []}
  ],
  "roadmap_milestones": [
    {"id": "M1", "title": "Fixture milestone", "progress": {"status": "active"}, "review": {"state": "none"}, "batches": [{"task_ids": [931], "description": "fixture batch"}]}
  ]
}
EOF
  echo "seed" > "$d/README.md"
  git -C "$d" add README.md specs/state.json .claude/ >/dev/null 2>&1
  git -C "$d" commit -q -m "seed" >/dev/null 2>&1
  echo "$d"
}

# land_one_commit <repo> -- creates refs/heads/milestone/M1 one commit ahead of main, matching
# one done task (the shape milestone-ref-land.sh itself produces).
land_one_commit() {
  local repo="$1"
  local tree sha land
  tree="$(git -C "$repo" rev-parse HEAD^'{tree}')"
  sha="$(git -C "$repo" rev-parse HEAD)"
  land="$(git -C "$repo" commit-tree "$tree" -p "$sha" -m "candidate 931: fixture task")"
  git -C "$repo" update-ref refs/heads/milestone/M1 "$land" ""
}

LAST_OUTPUT=""
LAST_CODE=0
run_handoff() {
  local repo="$1"
  shift
  LAST_OUTPUT="$(cd "$repo" && bash .claude/scripts/milestone-review-handoff.sh --session "$SESSION_ID" "$@" 2>&1)"
  LAST_CODE=$?
}

# =====================================================================
# Case 1: fires-once-on-transition -- a fully-done milestone with a matching ref transitions
# none -> prepared exactly once; a second invocation is a no-op (review.state is no longer none).
# =====================================================================
fire_repo="$(make_fixture_repo "yes")"
land_one_commit "$fire_repo"
run_handoff "$fire_repo"
first_code="$LAST_CODE"
first_review_state="$(jq -r '.roadmap_milestones[0].review.state' "$fire_repo/specs/state.json")"
first_ref="$(jq -r '.roadmap_milestones[0].review.ref' "$fire_repo/specs/state.json")"
# Second invocation: add one more unrelated commit on main, re-run -- must NOT re-fire.
echo "more" >> "$fire_repo/README.md"
git -C "$fire_repo" add README.md >/dev/null 2>&1
git -C "$fire_repo" commit -q -m "unrelated" >/dev/null 2>&1
run_handoff "$fire_repo"
second_code="$LAST_CODE"
second_review="$(jq -c '.roadmap_milestones[0].review' "$fire_repo/specs/state.json")"
rm -rf "$fire_repo"
if [ "$first_code" -eq 0 ] && [ "$first_review_state" = "prepared" ] && [ "$first_ref" = "refs/heads/milestone/M1" ]; then
  common_test_pass "fires-once (1st call): review.state transitions none -> prepared with review.ref set"
else
  common_test_fail "fires-once (1st call): expected review.state=prepared, review.ref=refs/heads/milestone/M1 -- got code=$first_code state=$first_review_state ref=$first_ref"
fi
if [ "$second_code" -eq 0 ] && [ "$(echo "$second_review" | jq -r '.state')" = "prepared" ] && [ "$(echo "$second_review" | jq -r '.ref')" = "refs/heads/milestone/M1" ]; then
  common_test_pass "fires-once (2nd call): a second invocation leaves the already-prepared review untouched (no re-fire)"
else
  common_test_fail "fires-once (2nd call): expected the review to remain unchanged -- got code=$second_code review=$second_review"
fi

# =====================================================================
# Case 2: ref-mismatch warning path -- the milestone ref exists but its commit count does not
# match the derived done-task count; nothing is prepared for that milestone.
# =====================================================================
mismatch_repo="$(make_fixture_repo "yes")"
# Create the ref TWO commits ahead of main (mismatch: 1 done task expects exactly 1 commit).
tree="$(git -C "$mismatch_repo" rev-parse HEAD^'{tree}')"
sha="$(git -C "$mismatch_repo" rev-parse HEAD)"
land1="$(git -C "$mismatch_repo" commit-tree "$tree" -p "$sha" -m "candidate 931: fixture task part 1")"
land2="$(git -C "$mismatch_repo" commit-tree "$tree" -p "$land1" -m "candidate 931: fixture task part 2")"
git -C "$mismatch_repo" update-ref refs/heads/milestone/M1 "$land2" ""
run_handoff "$mismatch_repo"
mismatch_code="$LAST_CODE"
mismatch_review_state="$(jq -r '.roadmap_milestones[0].review.state' "$mismatch_repo/specs/state.json")"
rm -rf "$mismatch_repo"
if [ "$mismatch_code" -eq 0 ] && [ "$mismatch_review_state" = "none" ] && grep -q "WARNING:.*mismatch\|WARNING:.*commit(s) ahead" <<< "$LAST_OUTPUT"; then
  common_test_pass "ref-mismatch: a named warning fires and nothing is prepared (review.state stays none)"
else
  common_test_fail "ref-mismatch: expected code=0, review.state=none, and a named warning -- got code=$mismatch_code state=$mismatch_review_state output=$LAST_OUTPUT"
fi

# =====================================================================
# Case 3: progress.status is untouched by the handoff.
# =====================================================================
progress_repo="$(make_fixture_repo "yes")"
land_one_commit "$progress_repo"
run_handoff "$progress_repo"
progress_status_after="$(jq -r '.roadmap_milestones[0].progress.status' "$progress_repo/specs/state.json")"
rm -rf "$progress_repo"
if [ "$progress_status_after" = "active" ]; then
  common_test_pass "progress.status: left untouched by the handoff (stays 'active')"
else
  common_test_fail "progress.status: expected 'active' (untouched), got '$progress_status_after'"
fi

# =====================================================================
# Case 4: literal-command output -- the exact /please and /merge commands appear, with a
# statement that the system will not run them.
# =====================================================================
cmd_repo="$(make_fixture_repo "yes")"
land_one_commit "$cmd_repo"
run_handoff "$cmd_repo"
cmd_output="$LAST_OUTPUT"
rm -rf "$cmd_repo"
if grep -q "^  /please push refs/heads/milestone/M1$" <<< "$cmd_output" \
   && grep -q "^  /merge$" <<< "$cmd_output" \
   && grep -qi "will not run" <<< "$cmd_output"; then
  common_test_pass "literal-command output: /please and /merge commands printed, with a will-not-run statement"
else
  common_test_fail "literal-command output: expected literal /please + /merge lines and a will-not-run statement -- got: $cmd_output"
fi

# =====================================================================
# Case 5: not-yet-done milestone (b_done < b) prepares nothing.
# =====================================================================
notdone_repo="$(make_fixture_repo "no")"
run_handoff "$notdone_repo"
notdone_code="$LAST_CODE"
notdone_review_state="$(jq -r '.roadmap_milestones[0].review.state' "$notdone_repo/specs/state.json")"
notdone_ref_exists="$(git -C "$notdone_repo" rev-parse --verify --quiet refs/heads/milestone/M1 2>/dev/null || echo "")"
rm -rf "$notdone_repo"
if [ "$notdone_code" -eq 0 ] && [ "$notdone_review_state" = "none" ] && [ -z "$notdone_ref_exists" ]; then
  common_test_pass "not-yet-done milestone: prepares nothing, review.state stays none"
else
  common_test_fail "not-yet-done milestone: expected code=0, review.state=none, no ref -- got code=$notdone_code state=$notdone_review_state ref='$notdone_ref_exists'"
fi

# =====================================================================
# Case 6: no roadmap_milestones entries -- a clean no-op.
# =====================================================================
nomilestone_repo="$(mktemp -d -p "$WORKDIR")"
git -C "$nomilestone_repo" init -q -b main
git -C "$nomilestone_repo" config user.email "test@example.com"
git -C "$nomilestone_repo" config user.name "Test Suite"
mkdir -p "$nomilestone_repo/specs" "$nomilestone_repo/.claude/scripts/lib"
cp -r "$SCRIPT_DIR/../lib/." "$nomilestone_repo/.claude/scripts/lib/"
cp "$TASKLOCK" "$nomilestone_repo/.claude/scripts/task-lock.sh"
cp "$GUARD" "$nomilestone_repo/.claude/scripts/deploy-root-guard.sh"
cp "$STATEWRITE" "$nomilestone_repo/.claude/scripts/state-write.sh"
cp "$HANDOFF" "$nomilestone_repo/.claude/scripts/milestone-review-handoff.sh"
chmod +x "$nomilestone_repo"/.claude/scripts/*.sh
echo '{"version":"1.0","next_project_number":2,"active_projects":[]}' > "$nomilestone_repo/specs/state.json"
git -C "$nomilestone_repo" add specs/state.json .claude/ >/dev/null 2>&1
git -C "$nomilestone_repo" commit -q -m seed >/dev/null 2>&1
run_handoff "$nomilestone_repo"
nomilestone_code="$LAST_CODE"
rm -rf "$nomilestone_repo"
if [ "$nomilestone_code" -eq 0 ]; then
  common_test_pass "no roadmap_milestones: clean no-op (exit 0)"
else
  common_test_fail "no roadmap_milestones: expected exit 0, got $nomilestone_code"
fi

# =====================================================================
# Case 7: the script never invokes git push, git-push-granted.sh, gh, glab, or /merge, and
# never writes the push-grant store.
# =====================================================================
forbidden_hits="$(grep -nE '\bgit[[:space:]]+push\b|git-push-granted\.sh|\bgh[[:space:]]+(pr|api)\b|\bglab[[:space:]]+mr\b' "$HANDOFF" | grep -v '^[0-9]*:#' | grep -v "NEVER CALLS" || true)"
if [ -z "$forbidden_hits" ]; then
  common_test_pass "static check: milestone-review-handoff.sh contains no git push/git-push-granted.sh/gh pr/glab mr invocation"
else
  common_test_fail "static check: found forbidden invocation(s): $forbidden_hits"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
