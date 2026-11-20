#!/usr/bin/env bash
# milestone-ref-land.sh - Ref-plumbing landing: appends one squash commit per completed task onto
# its milestone's review ref, without ever touching the working tree, the index, or HEAD.
#
# WHY REF PLUMBING, NOT checkout OR git merge --squash
# ------------------------------------------------------
# Every dispatch in this repository runs in the one shared working tree
# (specs/decisions/worktree-isolation-removal-verdict.md,
# specs/decisions/worktree-isolation-removal-reaffirmation.md). A landing mechanism built from
# `git checkout`/`git switch`/`git merge` would repoint that shared tree's HEAD out from under
# any concurrent sibling dispatch. `git commit-tree` and `git update-ref` do neither: the former
# writes a new, immutable commit object straight into the object database from an already-
# computed tree, and the latter moves one ref pointer. Neither reads nor writes the working
# tree, the index, or HEAD. See specs/decisions/branch-topology-and-landing-strategy.md, rulings
# R2 and R5, for the full ruling this implements.
#
# THIS SCRIPT NEVER CALLS: git checkout, git switch, git merge, git push, git reset, or any
# forced/non-compare-and-swap form of git update-ref. Grepping this file for any of those
# strings (outside this header) should return nothing; the test suite asserts it.
#
# USAGE
# -----
#   milestone-ref-land.sh <task_number> <session_id> [--verify]
#
# Default (land) mode: resolves the task's milestone; if none, exits 0 as a clean no-op (the
# task is not in any batch). Otherwise computes HEAD's tree, builds a new commit on top of the
# milestone ref's current tip (or the integration branch's tip for the milestone's first
# landing), and advances refs/heads/milestone/<id> via a three-argument compare-and-swap
# `git update-ref`, retrying under the existing specs/.commit-lock mutex (task-lock.sh
# commit-acquire/commit-release) on a lost race -- never a new lock, never a forced update.
#
# Landing a tree the ref's tip already carries creates NO commit and exits 0 with a NOTE. A
# re-run after a successful landing therefore converges on the same tip instead of extending
# the chain with empty commits.
#
# Each landed commit carries a `Landed-From: <sha>` trailer naming the work-branch commit whose
# tree it landed. The trailer is diagnostic only: --verify reads it to explain a failure, never
# to decide one.
#
# --verify mode: asserts TREE EQUALITY -- the milestone ref exists and
# `git rev-parse <ref>^{tree}` equals `git rev-parse HEAD^{tree}`. Exits 0 if it holds (or the
# task has no milestone -- nothing to verify), exits 1 otherwise. This is the check
# orchestrate-cycle-postflight.sh runs immediately before writing a task's completion status,
# closing the non-landing-under-"completed" defect
# worktree-isolation-removal-reaffirmation.md records.
#
# Why tree equality and not ancestry: a landed commit is parented on the milestone ref's own
# chain, not on the work branch, so the work branch's HEAD is an ancestor of the ref only for
# the milestone's first landing. Ancestry would report every later, correct landing as missing.
# Tree equality asks the question that matters -- does the ref carry the work branch's current
# content -- and it still fails when it should: any commit made on the work branch after the
# last landing changes HEAD's tree and the check exits 1 until that tree is landed. A --verify
# failure is therefore always repaired by one landing of the current tree.
#
# INTEGRATION-BRANCH RESOLUTION
# ------------------------------
# Reads the `integration_branch` top-level string key from .claude-extensions.json (ruling R4
# fixes this key's name and shape; this script is a consumer, not the schema's owner -- that
# belongs to branch_aware_orchestration_and_squash_landing). Falls back to the currently
# checked-out branch with a loud, named advisory when the key is absent, empty, or unreadable.
#
# EXIT CODES
# ----------
#   0  landed (or no-op: no milestone membership, the ref's tip already carries HEAD's tree,
#      or --verify confirms tree equality/no milestone)
#   1  --verify: the milestone ref is missing, or its tip tree differs from HEAD's tree
#   2  usage error
#   3  CAS retries exhausted (persistent contention; caller should re-run)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
[ -n "${REPO_ROOT:-}" ] && PROJECT_ROOT="$REPO_ROOT"
cd "$PROJECT_ROOT"

STATE_FILE="specs/state.json"
EXT_FILE=".claude-extensions.json"
MAX_CAS_RETRIES=5

usage() {
  echo "Usage: $0 <task_number> <session_id> [--verify]" >&2
  exit 2
}

task_number="${1:-}"
session_id="${2:-}"
verify_mode="false"
if [ "${3:-}" = "--verify" ]; then
  verify_mode="true"
fi
[ -z "$task_number" ] && usage
[ -z "$session_id" ] && usage

# --- Resolve the task's milestone, if any --------------------------------------------------
milestone_id="$(jq -r --argjson n "$task_number" \
  '[.roadmap_milestones[]? | select(.batches[]?.task_ids[]? == $n) | .id] | first // ""' \
  "$STATE_FILE" 2>/dev/null || echo "")"

if [ -z "$milestone_id" ]; then
  echo "NOTE: [milestone-ref-land] task ${task_number} is not a member of any roadmap_milestones batch -- clean no-op." >&2
  exit 0
fi

milestone_ref="refs/heads/milestone/${milestone_id}"

# --- --verify mode ---------------------------------------------------------------------------
if [ "$verify_mode" = "true" ]; then
  if ! git rev-parse --verify --quiet "$milestone_ref" >/dev/null; then
    echo "ERROR: [milestone-ref-land] --verify: ${milestone_ref} does not exist; task ${task_number}'s work has not landed." >&2
    exit 1
  fi
  verify_ref_tree="$(git rev-parse "${milestone_ref}^{tree}")"
  verify_head_tree="$(git rev-parse 'HEAD^{tree}')"
  if [ "$verify_ref_tree" = "$verify_head_tree" ]; then
    echo "NOTE: [milestone-ref-land] --verify: ${milestone_ref}'s tip tree equals HEAD's tree (${verify_head_tree}); task ${task_number}'s work has landed." >&2
    exit 0
  fi
  # Diagnostic only from here on: the decision above is the tree comparison and nothing else.
  # Explain the mismatch by reading the last landing's recorded source commit.
  verify_head_sha="$(git rev-parse HEAD)"
  verify_last_src="$(git log -1 --format=%B "$milestone_ref" 2>/dev/null \
    | sed -n 's/^Landed-From: \([0-9a-f]\{7,\}\)$/\1/p' | tail -1 || true)"
  if [ -z "$verify_last_src" ]; then
    verify_advance="the last landing recorded no source commit, so whether HEAD has advanced since is unknown"
  elif ! git cat-file -e "${verify_last_src}^{commit}" 2>/dev/null; then
    verify_advance="the last landing's recorded source commit ${verify_last_src} is not in this repository"
  elif [ "$verify_last_src" = "$verify_head_sha" ]; then
    verify_advance="HEAD has NOT advanced since the last landing (same commit ${verify_last_src}), so the ref's tip was not built from it"
  else
    verify_ahead="$(git rev-list --count "${verify_last_src}..HEAD" 2>/dev/null || echo "?")"
    verify_behind="$(git rev-list --count "HEAD..${verify_last_src}" 2>/dev/null || echo "?")"
    if [ "$verify_behind" = "0" ]; then
      verify_advance="HEAD has advanced ${verify_ahead} commit(s) since the last landing (from ${verify_last_src})"
    else
      verify_advance="the last landing's source commit ${verify_last_src} is not in HEAD's history (HEAD is ${verify_ahead} ahead, ${verify_behind} behind it)"
    fi
  fi
  echo "ERROR: [milestone-ref-land] --verify: ${milestone_ref}'s tip tree (${verify_ref_tree}) differs from HEAD's tree (${verify_head_tree}); task ${task_number}'s work has not landed. ${verify_advance}. Landing the current tree repairs this." >&2
  exit 1
fi

# --- Resolve the integration branch, with a loud advisory fallback ---------------------------
integration_branch="$(jq -r '.integration_branch // ""' "$EXT_FILE" 2>/dev/null || echo "")"
if [ -z "$integration_branch" ]; then
  integration_branch="$(git rev-parse --abbrev-ref HEAD)"
  echo "ADVISORY: [milestone-ref-land] no .integration_branch declared in ${EXT_FILE}; falling back to the currently checked-out branch ('${integration_branch}'). See context/standards/repo-level-declarations.md." >&2
fi

# --- Resolve the task's title for the commit subject ------------------------------------------
task_title="$(jq -r --argjson n "$task_number" \
  '(.active_projects[]? | select(.project_number == $n) | .title) // ""' "$STATE_FILE" 2>/dev/null || echo "")"
[ -z "$task_title" ] && task_title="task ${task_number}"

# --- Resolve the completed-phase list for the commit body (best-effort, never fatal) ----------
phase_body=""
plan_path="$(jq -r --argjson n "$task_number" \
  '(.active_projects[]? | select(.project_number == $n) | .artifacts[]? | select(.type == "plan") | .path) // ""' \
  "$STATE_FILE" 2>/dev/null | tail -1 || echo "")"
if [ -n "$plan_path" ] && [ -f "$plan_path" ]; then
  phase_body="$(grep -E '^### Phase [0-9]+: .*\[COMPLETED' "$plan_path" 2>/dev/null | sed -E 's/^### //; s/ \[[A-Z ]+\]$//' || true)"
fi

# The work-branch commit whose tree is being landed, and that tree. Both are resolved once, here,
# so the tree landed and the source commit recorded in the trailer always describe one commit.
source_commit="$(git rev-parse HEAD)"
tree="$(git rev-parse "${source_commit}^{tree}")"

commit_subject="task ${task_number}: ${task_title}"
if [ -n "$phase_body" ]; then
  commit_message="$(printf '%s\n\n%s\n\nLanded-From: %s\n' "$commit_subject" "$phase_body" "$source_commit")"
else
  commit_message="$(printf '%s\n\nLanded-From: %s\n' "$commit_subject" "$source_commit")"
fi

# --- Serialize the compare-and-swap retry under the existing commit mutex, never a new lock ---
commit_token=""
commit_mutex_owned="false"
if [ -z "${COMMIT_MUTEX_HELD:-}" ]; then
  if commit_token="$(bash "$SCRIPT_DIR/task-lock.sh" commit-acquire "$session_id")"; then
    commit_mutex_owned="true"
  else
    echo "WARNING: [milestone-ref-land] failed to acquire specs/.commit-lock mutex (session=${session_id}); proceeding unserialized (non-blocking, fail-open)." >&2
  fi
fi
release_land_mutex() {
  if [ "$commit_mutex_owned" = "true" ]; then
    bash "$SCRIPT_DIR/task-lock.sh" commit-release "$commit_token" >&2 || true
    commit_mutex_owned="false"
  fi
}
trap release_land_mutex EXIT

attempt=0
landed="false"
while [ "$attempt" -lt "$MAX_CAS_RETRIES" ]; do
  attempt=$((attempt + 1))
  if git rev-parse --verify --quiet "$milestone_ref" >/dev/null; then
    old_tip="$(git rev-parse "$milestone_ref")"
    parent="$old_tip"
    # Unchanged tree: the ref's tip already carries exactly what would be landed. Create no
    # commit, so a re-run converges on this tip instead of extending the chain.
    if [ "$(git rev-parse "${old_tip}^{tree}")" = "$tree" ]; then
      echo "NOTE: [milestone-ref-land] ${milestone_ref}'s tip $(git rev-parse --short "$old_tip") already carries HEAD's tree (${tree}); nothing to land for task ${task_number} -- no commit created." >&2
      exit 0
    fi
  else
    old_tip=""
    parent="$(git rev-parse "$integration_branch")"
  fi

  new_commit="$(git commit-tree "$tree" -p "$parent" <<<"$commit_message")"

  if [ -z "$old_tip" ]; then
    # Assert non-existence: an empty oldvalue tells update-ref the ref must not already exist.
    if git update-ref "$milestone_ref" "$new_commit" ""; then
      landed="true"
      break
    fi
  else
    if git update-ref "$milestone_ref" "$new_commit" "$old_tip"; then
      landed="true"
      break
    fi
  fi
  echo "NOTE: [milestone-ref-land] compare-and-swap lost the race on ${milestone_ref} (attempt ${attempt}/${MAX_CAS_RETRIES}); re-reading tip and retrying." >&2
done

if [ "$landed" != "true" ]; then
  echo "ERROR: [milestone-ref-land] exhausted ${MAX_CAS_RETRIES} compare-and-swap retries on ${milestone_ref}; persistent contention. Re-run." >&2
  exit 3
fi

echo "NOTE: [milestone-ref-land] task ${task_number} landed onto ${milestone_ref} as $(git rev-parse --short "$new_commit")." >&2
exit 0
