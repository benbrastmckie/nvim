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
# --verify mode: asserts `git merge-base --is-ancestor HEAD refs/heads/milestone/<id>`. Exits 0
# if HEAD's work has landed on the milestone ref (or the task has no milestone -- nothing to
# verify), exits 1 otherwise. This is the check orchestrate-cycle-postflight.sh runs immediately
# before writing a task's completion status (Phase 4), closing the non-landing-under-"completed"
# defect worktree-isolation-removal-reaffirmation.md records.
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
#   0  landed (or no-op: no milestone membership, or --verify confirms ancestry/no milestone)
#   1  --verify: HEAD's work has not landed on the milestone ref
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
  if git merge-base --is-ancestor HEAD "$milestone_ref"; then
    echo "NOTE: [milestone-ref-land] --verify: HEAD is an ancestor of ${milestone_ref}; task ${task_number}'s work has landed." >&2
    exit 0
  else
    echo "ERROR: [milestone-ref-land] --verify: HEAD is NOT an ancestor of ${milestone_ref}; task ${task_number}'s work has not landed." >&2
    exit 1
  fi
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

commit_subject="task ${task_number}: ${task_title}"
if [ -n "$phase_body" ]; then
  commit_message="$(printf '%s\n\n%s\n' "$commit_subject" "$phase_body")"
else
  commit_message="$commit_subject"
fi

tree="$(git rev-parse HEAD^{tree})"

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
