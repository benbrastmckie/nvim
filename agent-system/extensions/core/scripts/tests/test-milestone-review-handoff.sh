#!/usr/bin/env bash
# test-milestone-review-handoff.sh - Fixture-driven regression suite for
# milestone-review-handoff.sh: asserts the fires-once-on-transition behaviour, the per-task
# listing read from landing proofs (and its fallback for a task with no proof), the shared-paths
# flag, integration-branch resolution, the review field writes, the untouched progress.status,
# the literal-command output, and the absence of every push-shaped call.
#
# Follows the deployed-shape sandbox convention: deploy-root-guard.sh's default structural check
# requires the script's own directory to end in /.claude or /.opencode, so fixtures copy the
# script under test into a tree shaped that way.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
HANDOFF="$SCRIPT_DIR/../milestone-review-handoff.sh"
TASKLOCK="$SCRIPT_DIR/../task-lock.sh"
STATEWRITE="$SCRIPT_DIR/../state-write.sh"
GUARD="$SCRIPT_DIR/../deploy-root-guard.sh"
RSP="$SCRIPT_DIR/../review-stack-prepare.sh"

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
BRANCH="trunk"

# task-ref-ok:begin category 6-adjacent: the "931"/"932" fixture numbers and the numbered commit
# subjects from here to the matching end marker are synthetic fixture data. The script under
# test reads the literal commit-subject convention, so the fixtures must carry concrete digits.

# install_scripts <repo> -- the deployed-shape copies the script under test needs.
install_scripts() {
  local d="$1"
  mkdir -p "$d/specs" "$d/.claude/scripts/lib"
  cp -r "$SCRIPT_DIR/../lib/." "$d/.claude/scripts/lib/"
  cp "$TASKLOCK" "$d/.claude/scripts/task-lock.sh"
  cp "$GUARD" "$d/.claude/scripts/deploy-root-guard.sh"
  cp "$STATEWRITE" "$d/.claude/scripts/state-write.sh"
  cp "$HANDOFF" "$d/.claude/scripts/milestone-review-handoff.sh"
  cp "$RSP" "$d/.claude/scripts/review-stack-prepare.sh"
  chmod +x "$d"/.claude/scripts/*.sh
}

# make_fixture_repo <done:yes|no> [shared_paths_json] -- a sandbox on $BRANCH with one milestone
# "M1" holding one batch of two tasks. The first task has two attributed commits, a completion
# commit and a landing proof in a batch record; the second has one attributed commit, a
# completion commit, a created time and no proof. "yes" marks both completed (b_done == b);
# "no" leaves the first implementing. The first task's end commit is its second phase commit.
make_fixture_repo() {
  local done="$1" shared="${2:-[]}"
  local d status_val c1 c2
  d="$(mktemp -d -p "$WORKDIR")"
  git -C "$d" init -q -b "$BRANCH"
  git -C "$d" config user.email "test@example.com"
  git -C "$d" config user.name "Test Suite"
  install_scripts "$d"

  if [ "$done" = "yes" ]; then
    status_val="completed"
  else
    status_val="implementing"
  fi

  cat > "$d/specs/state.json" << EOF
{
  "version": "1.0",
  "next_project_number": 933,
  "active_projects": [
    {"project_number": 931, "project_name": "fixture", "title": "Fixture task", "status": "${status_val}", "task_type": "meta", "created": "2020-01-01T00:00:00Z", "file_scope": []},
    {"project_number": 932, "project_name": "second", "title": "Second fixture task", "status": "completed", "task_type": "meta", "created": "2020-01-01T00:00:00Z", "file_scope": []}
  ],
  "roadmap_milestones": [
    {"id": "M1", "title": "Fixture milestone", "progress": {"status": "active"}, "review": {"state": "none"}, "batches": [{"task_ids": [931, 932], "description": "fixture batch"}]}
  ]
}
EOF
  printf '.claude/\n' > "$d/.gitignore"
  echo "seed" > "$d/README.md"
  git -C "$d" add .gitignore README.md specs/state.json >/dev/null 2>&1
  git -C "$d" commit -q -m "seed" >/dev/null 2>&1
  echo a1 > "$d/a.txt"; git -C "$d" add a.txt; git -C "$d" commit -q -m "task 931 phase 1: a"
  c1="$(git -C "$d" rev-parse HEAD)"
  echo b1 > "$d/b.txt"; git -C "$d" add b.txt; git -C "$d" commit -q -m "task 932 phase 1: b"
  echo a2 > "$d/a.txt"; git -C "$d" add a.txt; git -C "$d" commit -q -m "task 931 phase 2: a again"
  c2="$(git -C "$d" rev-parse HEAD)"
  git -C "$d" commit -q --allow-empty -m "task 931: complete implementation"
  git -C "$d" commit -q --allow-empty -m "task 932: complete implementation"

  mkdir -p "$d/specs/.orchestration/batch"
  jq -n --arg b "$BRANCH" --arg c1 "$c1" --arg c2 "$c2" --argjson shared "$shared" \
    '{schema: 1, session_id: "sess_batch", task_numbers: [931], admitted_at: "2026-01-01T00:00:00Z",
      integration_branch: $b, integration_branch_declared: false,
      landing_proofs: [{task_number: 931, session_id: "sess_batch", integration_branch: $b,
        commits: [$c1, $c2], end_commit: $c2, tip_at_verification: $c2, paths: ["a.txt"],
        shared_paths: $shared, phases: [{phase: "1", name: "Only phase"}],
        source_store_commits: []}]}' \
    > "$d/specs/.orchestration/batch/sess_batch.json"
  echo "$d"
}

# make_success_fixture_repo -- wraps make_fixture_repo "yes" with a declared review_base and a
# file:// remote whose path embeds github.com/..., so review-stack-prepare.sh's resolver chain
# (review_base/remote/platform) and `cut --milestone M1` can succeed, following
# test-review-stack-prepare.sh's own make_fixture_repo (lines 49-75): tags the root ("seed")
# commit "basepoint", declares {"review_base": "basepoint"} in .claude-extensions.json, and adds
# a bare remote reachable over file:// at a path containing "github.com/...". Leaves
# make_fixture_repo itself declaring no review_base, so every other case keeps the refusal arm.
make_success_fixture_repo() {
  local d bare root
  d="$(make_fixture_repo "yes")"
  root="$(git -C "$d" rev-list --max-parents=0 HEAD)"
  git -C "$d" tag basepoint "$root"
  bare="$(mktemp -d -p "$WORKDIR")/github.com/fixture/repo.git"
  mkdir -p "$(dirname "$bare")"
  git init -q --bare "$bare"
  git -C "$d" remote add origin "file://${bare}"
  printf '{"review_base": "basepoint"}' > "$d/.claude-extensions.json"
  printf '%s' "$d"
}

LAST_OUTPUT=""
LAST_CODE=0
run_handoff() {
  local repo="$1"
  shift
  LAST_OUTPUT="$(cd "$repo" && bash .claude/scripts/milestone-review-handoff.sh --session "$SESSION_ID" "$@" 2>&1)"
  LAST_CODE=$?
}
review_of() { jq -c '.roadmap_milestones[0].review' "$1/specs/state.json"; }
summary_of() { cat "$1/specs/milestones/M1-review-handoff.md" 2>/dev/null; }

# =====================================================================
# Case 1: fires-once-on-transition -- a fully-done milestone transitions none -> prepared
# exactly once, with review.ref naming the integration branch; a second invocation is a no-op.
# =====================================================================
fire_repo="$(make_fixture_repo "yes")"
fire_end="$(git -C "$fire_repo" log -1 --format=%H --grep='^task 931 phase 2')"
refs_before="$(git -C "$fire_repo" for-each-ref)"
run_handoff "$fire_repo"
first_code="$LAST_CODE"
first_output="$LAST_OUTPUT"
first_review="$(review_of "$fire_repo")"
first_summary="$(summary_of "$fire_repo")"
refs_after="$(git -C "$fire_repo" for-each-ref)"
echo "more" >> "$fire_repo/README.md"
git -C "$fire_repo" add README.md >/dev/null 2>&1
git -C "$fire_repo" commit -q -m "unrelated" >/dev/null 2>&1
run_handoff "$fire_repo"
second_code="$LAST_CODE"
second_review="$(review_of "$fire_repo")"
progress_status_after="$(jq -r '.roadmap_milestones[0].progress.status' "$fire_repo/specs/state.json")"
rm -rf "$fire_repo"
if [ "$first_code" -eq 0 ] && [ "$(echo "$first_review" | jq -r '.state')" = "prepared" ] \
   && [ "$(echo "$first_review" | jq -r '.ref')" = "refs/heads/${BRANCH}" ]; then
  common_test_pass "fires-once (1st call): review.state transitions none -> prepared with review.ref naming the integration branch"
else
  common_test_fail "fires-once (1st call): expected review.state=prepared, review.ref=refs/heads/${BRANCH} -- got code=$first_code review=$first_review output=$first_output"
fi
if [ "$second_code" -eq 0 ] && [ "$second_review" = "$first_review" ]; then
  common_test_pass "fires-once (2nd call): a second invocation leaves the already-prepared review untouched (no re-fire)"
else
  common_test_fail "fires-once (2nd call): expected the review to remain unchanged -- got code=$second_code review=$second_review"
fi
if [ "$refs_before" = "$refs_after" ]; then
  common_test_pass "no ref is created, moved or deleted by the handoff"
else
  common_test_fail "the handoff changed the repository's refs: before=[$refs_before] after=[$refs_after]"
fi
if [ "$progress_status_after" = "active" ]; then
  common_test_pass "progress.status: left untouched by the handoff (stays 'active')"
else
  common_test_fail "progress.status: expected 'active' (untouched), got '$progress_status_after'"
fi

# =====================================================================
# Case 2: the per-task listing -- a task with a landing proof is listed from the proof; a task
# with no proof is attributed by commit subject, bounded by its created time.
# =====================================================================
if grep -qF -- "- task 931: complete implementation -- 2 attributed commit(s), end commit \`${fire_end}\`" <<< "$first_summary"; then
  common_test_pass "listing: a task with a landing proof shows its completion subject, commit count and end commit"
else
  common_test_fail "listing: expected the proof-backed line for the first task -- got: $first_summary"
fi
if grep -q -- "- task 932: complete implementation -- 2 attributed commit(s), last commit .* (no landing proof; attributed by commit subject since 2020-01-01T00:00:00Z)" <<< "$first_summary"; then
  common_test_pass "listing: a task with no proof is attributed by commit subject, with the created bound named"
else
  common_test_fail "listing: expected the no-proof fallback line for the second task -- got: $first_summary"
fi
if grep -q "It is not one commit per task" <<< "$first_summary" \
   && ! grep -q "SHARED PATHS" <<< "$first_summary"; then
  common_test_pass "listing: the summary states the review unit and flags no shared paths when there are none"
else
  common_test_fail "listing: expected the review-unit statement and no shared-paths flag -- got: $first_summary"
fi

# =====================================================================
# Case 3: refusal-arm output -- the default fixture declares no review_base, so cut refuses
# review_base_undeclared: a REFUSED: review-stack-prepare.sh: review_base_undeclared: ... reason
# line is printed, the /please push request for the integration branch is printed alone, the
# HEAD-binding line is printed, the system states it will not run any of these on its own, and
# no bare /merge line appears anywhere in the output.
# =====================================================================
if grep -qE "^REFUSED: review-stack-prepare\.sh: review_base_undeclared: " <<< "$first_output" \
   && grep -q "^  /please push ${BRANCH}$" <<< "$first_output" \
   && grep -qi "bound to the commit at HEAD" <<< "$first_output" \
   && grep -qi "will not run" <<< "$first_output" \
   && ! grep -qE "^  ?/merge( |$)" <<< "$first_output"; then
  common_test_pass "refusal-arm output: REFUSED review_base_undeclared reason, /please push alone, HEAD-binding line, will-not-run statement, and no /merge line"
else
  common_test_fail "refusal-arm output: expected a REFUSED: review-stack-prepare.sh: review_base_undeclared: line, /please push ${BRANCH} alone, the HEAD-binding line, a will-not-run statement, and no /merge line -- got: $first_output"
fi

# =====================================================================
# Case 3b: success-arm output -- a milestone fixture with a declared review_base and a
# github-shaped remote lets `cut --milestone M1` succeed; `show`'s per-entry stack (observed:
# two independent units, one per task, since 931/932 share no path and no dependency edge)
# lands in both the summary file and on stderr, with the HEAD-binding line, and neither the old
# bare `/merge` line nor the old no-remote `/please push ${BRANCH}` pair appears.
# =====================================================================
success_repo="$(make_success_fixture_repo)"
run_handoff "$success_repo"
success_output="$LAST_OUTPUT"
success_summary="$(summary_of "$success_repo")"
rm -rf "$success_repo"
success_pr_count="$(grep -cE '^PR [0-9]+: branch=.* base=.* title=.* body_path=' <<< "$success_output")"
if [ "$success_pr_count" -eq 2 ] \
   && grep -qE '^  /please push origin review/M1/01-' <<< "$success_output" \
   && grep -qE '^  /please push origin review/M1/02-' <<< "$success_output" \
   && grep -q '^/merge --stack M1$' <<< "$success_output" \
   && grep -qi "bound to the commit at HEAD" <<< "$success_output" \
   && grep -q "## Review Stack" <<< "$success_summary" \
   && grep -qE '^PR [0-9]+: branch=' <<< "$success_summary" \
   && ! grep -qE '^  ?/merge$' <<< "$success_output" \
   && ! grep -q "/please push ${BRANCH}\$" <<< "$success_output"; then
  common_test_pass "success-arm output: show's per-entry stack (2 PR entries) in the summary and on stderr, with the HEAD-binding line and no stale /merge or no-remote /please line"
else
  common_test_fail "success-arm output: expected 2 PR entries, two /please push origin lines, one /merge --stack M1 line, the HEAD-binding line, and a ## Review Stack summary section -- got output: $success_output -- summary: $success_summary"
fi

# =====================================================================
# Case 4: a task whose proof has shared paths is flagged, in the summary and on output.
# =====================================================================
shared_repo="$(make_fixture_repo "yes" '["a.txt"]')"
run_handoff "$shared_repo"
shared_summary="$(summary_of "$shared_repo")"
shared_output="$LAST_OUTPUT"
rm -rf "$shared_repo"
if grep -q "SHARED PATHS: a.txt" <<< "$shared_summary" \
   && grep -q "Task(s) 931 share one or more files with another writer" <<< "$shared_summary" \
   && grep -q "NOTE: task(s) 931 share files with another writer" <<< "$shared_output"; then
  common_test_pass "shared paths: the task is flagged in its line, in the review-unit section and on output"
else
  common_test_fail "shared paths: expected the flag in three places -- summary: $shared_summary output: $shared_output"
fi

# =====================================================================
# Case 5: a task with neither a proof nor a created time is listed as unattributed.
# =====================================================================
bare_repo="$(make_fixture_repo "yes")"
jq '(.active_projects[] | select(.project_number == 932)) |= del(.created)' \
  "$bare_repo/specs/state.json" > "$bare_repo/specs/state.json.new" \
  && mv "$bare_repo/specs/state.json.new" "$bare_repo/specs/state.json"
run_handoff "$bare_repo"
bare_summary="$(summary_of "$bare_repo")"
rm -rf "$bare_repo"
if grep -q -- "- task 932: complete implementation -- unattributed: no landing proof, and no created time to bound attribution by" <<< "$bare_summary"; then
  common_test_pass "no proof and no created time: the task is listed as unattributed, never matched without a bound"
else
  common_test_fail "no proof and no created time: expected the unattributed line -- got: $bare_summary"
fi

# =====================================================================
# Case 6: integration-branch resolution -- the batch record's branch wins over the checked-out
# branch; with no record the declared branch is used; with nothing to resolve from, a named
# warning fires and nothing is prepared.
# =====================================================================
record_repo="$(make_fixture_repo "yes")"
git -C "$record_repo" switch -q -c elsewhere
run_handoff "$record_repo"
record_ref="$(review_of "$record_repo" | jq -r '.ref')"
rm -rf "$record_repo"
if [ "$record_ref" = "refs/heads/${BRANCH}" ]; then
  common_test_pass "branch resolution: the batch record's integration branch wins over the checked-out branch"
else
  common_test_fail "branch resolution: expected refs/heads/${BRANCH} from the batch record, got '$record_ref'"
fi

declared_repo="$(make_fixture_repo "yes")"
rm -rf "$declared_repo/specs/.orchestration"
echo "{\"version\":\"1.0.0\",\"extensions\":{},\"integration_branch\":\"${BRANCH}\"}" > "$declared_repo/.claude-extensions.json"
git -C "$declared_repo" switch -q -c elsewhere
run_handoff "$declared_repo"
declared_ref="$(review_of "$declared_repo" | jq -r '.ref')"
rm -rf "$declared_repo"
if [ "$declared_ref" = "refs/heads/${BRANCH}" ]; then
  common_test_pass "branch resolution: with no batch record, the declared integration_branch is used"
else
  common_test_fail "branch resolution: expected refs/heads/${BRANCH} from the declaration, got '$declared_ref'"
fi

detached_repo="$(make_fixture_repo "yes")"
rm -rf "$detached_repo/specs/.orchestration"
git -C "$detached_repo" checkout -q --detach
run_handoff "$detached_repo"
detached_code="$LAST_CODE"
detached_state="$(review_of "$detached_repo" | jq -r '.state')"
rm -rf "$detached_repo"
if [ "$detached_code" -eq 0 ] && [ "$detached_state" = "none" ] \
   && grep -q "WARNING:.*integration branch cannot be resolved" <<< "$LAST_OUTPUT"; then
  common_test_pass "branch resolution: a detached HEAD with no record and no declaration warns and prepares nothing"
else
  common_test_fail "branch resolution: expected code=0, review.state=none and a named warning -- got code=$detached_code state=$detached_state output=$LAST_OUTPUT"
fi

# =====================================================================
# Case 7: --dry-run writes no review fields.
# =====================================================================
dry_repo="$(make_fixture_repo "yes")"
run_handoff "$dry_repo" --dry-run
dry_state="$(review_of "$dry_repo" | jq -r '.state')"
rm -rf "$dry_repo"
if [ "$dry_state" = "none" ] && grep -q "\[dry-run\] would write review.state=prepared, review.ref=refs/heads/${BRANCH}" <<< "$LAST_OUTPUT"; then
  common_test_pass "--dry-run: reports the write it would make and leaves review.state none"
else
  common_test_fail "--dry-run: expected review.state=none and a would-write line -- got state=$dry_state output=$LAST_OUTPUT"
fi

# =====================================================================
# Case 8: not-yet-done milestone (b_done < b) prepares nothing.
# =====================================================================
notdone_repo="$(make_fixture_repo "no")"
run_handoff "$notdone_repo"
notdone_code="$LAST_CODE"
notdone_review_state="$(review_of "$notdone_repo" | jq -r '.state')"
notdone_summary_exists="no"
[ -e "$notdone_repo/specs/milestones/M1-review-handoff.md" ] && notdone_summary_exists="yes"
rm -rf "$notdone_repo"
if [ "$notdone_code" -eq 0 ] && [ "$notdone_review_state" = "none" ] && [ "$notdone_summary_exists" = "no" ]; then
  common_test_pass "not-yet-done milestone: prepares nothing, review.state stays none"
else
  common_test_fail "not-yet-done milestone: expected code=0, review.state=none, no summary -- got code=$notdone_code state=$notdone_review_state summary=$notdone_summary_exists"
fi
# task-ref-ok:end

# =====================================================================
# Case 9: no roadmap_milestones entries -- a clean no-op.
# =====================================================================
nomilestone_repo="$(mktemp -d -p "$WORKDIR")"
git -C "$nomilestone_repo" init -q -b "$BRANCH"
git -C "$nomilestone_repo" config user.email "test@example.com"
git -C "$nomilestone_repo" config user.name "Test Suite"
install_scripts "$nomilestone_repo"
echo '{"version":"1.0","next_project_number":2,"active_projects":[]}' > "$nomilestone_repo/specs/state.json"
git -C "$nomilestone_repo" add specs/state.json >/dev/null 2>&1
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
# Case 10: the script never invokes git push, git-push-granted.sh, gh, glab, or /merge, never
# writes the push-grant store, and never writes a ref.
# =====================================================================
forbidden_hits="$(grep -nE '\bgit[[:space:]]+push\b|git-push-granted\.sh|\bgh[[:space:]]+(pr|api)\b|\bglab[[:space:]]+mr\b' "$HANDOFF" | grep -v '^[0-9]*:#' | grep -v "NEVER CALLS" || true)"
if [ -z "$forbidden_hits" ]; then
  common_test_pass "static check: milestone-review-handoff.sh contains no git push/git-push-granted.sh/gh pr/glab mr invocation"
else
  common_test_fail "static check: found forbidden invocation(s): $forbidden_hits"
fi
ref_write_hits="$(grep -nE '\bgit[[:space:]]+(update-ref|commit-tree|branch|tag|checkout|switch)\b' "$HANDOFF" | grep -v '^[0-9]*:#' || true)"
if [ -z "$ref_write_hits" ]; then
  common_test_pass "static check: milestone-review-handoff.sh contains no ref-writing or branch-switching git call"
else
  common_test_fail "static check: found ref-writing call(s): $ref_write_hits"
fi

echo ""
echo "Results: ${PASSED} passed, ${FAILED} failed"

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
