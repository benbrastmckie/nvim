#!/usr/bin/env bash
# backfill-file-scope.sh - One-shot, idempotent backfill of `file_scope` for existing plan-bearing
# tasks in any repo's specs/state.json, reusing plan-file-scope-harvest.sh (never re-implementing
# path extraction) and never overwriting a task that already has a non-empty file_scope.
#
# WHY THIS EXISTS (absorbed from a former sibling task -- see this task's own plan/report for the
# full history): most tasks in this and sibling repos predate the plan-time harvest wired in
# Phases 1-4, so their file_scope is absent even though a plan already exists to harvest from.
# This script closes that historical gap once; going forward, plan-time harvest keeps it closed.
#
# Interface:
#   backfill-file-scope.sh [--dry-run] [--state-file PATH]
#
#   --dry-run       Prints the proposed per-task diff (task number, resolved plan path, paths that
#                   would be added) and writes NOTHING -- no state-write.sh invocation at all.
#   --state-file    Path to a target specs/state.json other than this repo's own (e.g.
#                   ~/Projects/BimodalLogic/specs/state.json). The repo root for resolving plan
#                   paths is derived from this path (the parent of the state file's own directory,
#                   i.e. --state-file .../REPO/specs/state.json -> repo root .../REPO), not from
#                   the invoking CWD (Decision 7: this is what makes the tool cross-repo capable,
#                   since the measured need is mostly in a sibling repo, not this one). Absent,
#                   defaults to the invoking repo's own specs/state.json, with repo root derived
#                   the same way (parent of the default state file's directory).
#
# Population and disposition (Decision 6, restated here so it travels with the code): a task
# whose file_scope is already non-empty is SKIPPED untouched (never overwritten -- a hand-declared
# or previously-harvested scope is never second-guessed). A task with NO resolvable plan artifact
# is also SKIPPED, but counted and reported SEPARATELY as "plan-less (left absent)" -- this
# script deliberately does NOT infer a provisional file_scope from the task description (a WRONG
# guess is worse than an honest gap, since it gives the collision guard false confidence) and does
# NOT write an `[]` sentinel (which would read as "touches nothing" to a consumer and suppress the
# very absent-scope warning that should stay lit). A plan-less task acquires a real file_scope the
# moment it is eventually planned, via the Phase 1-4 plan-time harvest -- this script only reaches
# the population that ALREADY has a plan to harvest from.
#
# Write path: every write goes through state-write.sh (the single mutex-guarded writer), using the
# SAME additive `((.file_scope // []) + $add | unique)` merge shape update-task-status.sh's own
# --file-scope-add uses. Never a hand-rolled `jq ... > tmp && mv` sequence.
#
# Batching choice: a SINGLE state-write.sh invocation carries every task's update in one jq filter
# (an --argjson map of project_number -> harvested-array, applied via `.active_projects |= map(...)`
# ), rather than one invocation per task. This is chosen over per-task looping because the merge
# for every task is structurally identical (the same additive-union clause, keyed only by
# project_number) and a single filter can express "apply this clause to every matching entry"
# without per-task shelling out to state-write.sh N times -- fewer mutex acquisitions, fewer
# processes, and one atomic transform. If a future caller needs true per-task independent
# atomicity (partial success on a batch where one task's write must not block another's), split
# this into a loop instead; nothing in this script's shape prevents that later change.
#
# Idempotence: a second run over an already-backfilled state.json is a byte-for-byte no-op --
# every task whose file_scope is already non-empty is skipped up front, and jq's `unique` makes
# even a forced re-add of the same paths change nothing.
#
# Exit codes: 0 on success (including a dry-run, or a real run that finds nothing to backfill);
# non-zero is reserved for genuine usage/environment errors (bad flag, unreadable state file,
# missing dependency), never for "nothing to backfill".

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
HARVESTER="$SCRIPT_DIR/plan-file-scope-harvest.sh"
STATE_WRITE="$SCRIPT_DIR/state-write.sh"

if [[ ! -f "$HARVESTER" ]]; then
  echo "ERROR: plan-file-scope-harvest.sh not found at $HARVESTER" >&2
  exit 1
fi
if [[ ! -f "$STATE_WRITE" ]]; then
  echo "ERROR: state-write.sh not found at $STATE_WRITE" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required and is not on PATH" >&2
  exit 1
fi

DRY_RUN="false"
STATE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --state-file)
      if [[ $# -lt 2 ]]; then
        echo "ERROR: --state-file requires a PATH argument" >&2
        exit 1
      fi
      STATE_FILE="$2"
      shift 2
      ;;
    --state-file=*)
      STATE_FILE="${1#--state-file=}"
      shift
      ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--dry-run] [--state-file PATH]" >&2
      exit 0
      ;;
    *)
      echo "ERROR: unrecognized argument: $1" >&2
      echo "Usage: $(basename "$0") [--dry-run] [--state-file PATH]" >&2
      exit 1
      ;;
  esac
done

# Default target: this repo's own specs/state.json. Repo root for the default case is this
# script's own repo (two levels up from a deployed .claude/scripts/, or the source-store
# equivalent) -- resolved the same depth-independent way several sibling test suites already use
# (git worktree root first, since this script itself may run from either a deployed tree or the
# source store, and unlike those test suites it has no fixed-depth fallback need: it never
# hand-derives REPO_ROOT for its own sake, only to resolve a --state-file's repo root below).
if [[ -z "$STATE_FILE" ]]; then
  DEFAULT_REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -z "$DEFAULT_REPO_ROOT" ]]; then
    DEFAULT_REPO_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
  fi
  STATE_FILE="$DEFAULT_REPO_ROOT/specs/state.json"
fi

if [[ ! -f "$STATE_FILE" ]]; then
  echo "ERROR: state file not found: $STATE_FILE" >&2
  exit 1
fi

# Repo root is the parent of the state file's own directory (i.e. .../REPO/specs/state.json ->
# .../REPO), per Decision 7 -- derived from the --state-file path itself, never from CWD, so a
# cross-repo target resolves its plan paths against the RIGHT tree regardless of where this
# script is invoked from.
STATE_FILE_DIR="$(cd "$(dirname "$STATE_FILE")" && pwd)"
REPO_ROOT="$(cd "$STATE_FILE_DIR/.." && pwd)"

echo "[backfill-file-scope] state file: $STATE_FILE"
echo "[backfill-file-scope] repo root:  $REPO_ROOT"
[[ "$DRY_RUN" == "true" ]] && echo "[backfill-file-scope] mode: DRY-RUN (writes nothing)"

# --- Resolve each candidate task's latest plan file -------------------------------------------
# Prefer an artifacts[] entry of type=="plan" (the task's own recorded pointer); fall back to the
# lexicographically last specs/{NNN}_*/plans/*.md under the task's directory. Same two-tier
# precedence update-task-status.sh's resolve_plan_file_for_phase_check() and
# reconcile-task-status.sh's find_latest_artifact() already use elsewhere in this codebase.
resolve_plan_file() {
  local project_number="$1" project_name="$2" artifacts_json="$3"
  local from_artifacts
  from_artifacts=$(echo "$artifacts_json" | jq -r '[.[]? | select(.type == "plan")] | sort_by(.path) | last | .path // empty' 2>/dev/null)
  if [[ -n "$from_artifacts" ]]; then
    local candidate="$REPO_ROOT/$from_artifacts"
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  fi
  local padded_num
  padded_num=$(printf "%03d" "$project_number")
  local plan_dir="$REPO_ROOT/specs/${padded_num}_${project_name}/plans"
  if [[ ! -d "$plan_dir" ]]; then
    plan_dir="$REPO_ROOT/specs/${project_number}_${project_name}/plans"
  fi
  [[ -d "$plan_dir" ]] || return 0
  local plan_file
  plan_file=$(ls -1 "$plan_dir"/[0-9][0-9]_*.md 2>/dev/null | sort -V | tail -1 || true)
  if [[ -z "$plan_file" ]]; then
    plan_file=$(ls -1 "$plan_dir"/*.md 2>/dev/null | sort -V | tail -1 || true)
  fi
  [[ -n "$plan_file" && -f "$plan_file" ]] && echo "$plan_file"
}

# --- Build the candidate task list: file_scope absent or [] -----------------------------------
CANDIDATES_JSON=$(jq -c '[.active_projects[] | select((.file_scope == null) or (.file_scope == []))
  | {project_number, project_name, artifacts: (.artifacts // [])}]' "$STATE_FILE")
CANDIDATE_COUNT=$(echo "$CANDIDATES_JSON" | jq 'length')

BACKFILLED_COUNT=0
SKIPPED_PLANLESS_COUNT=0
UPDATES_JSON="{}"

if [[ "$CANDIDATE_COUNT" -gt 0 ]]; then
  while IFS= read -r task_row; do
    project_number=$(echo "$task_row" | jq -r '.project_number')
    project_name=$(echo "$task_row" | jq -r '.project_name')
    artifacts_json=$(echo "$task_row" | jq -c '.artifacts')

    plan_file=$(resolve_plan_file "$project_number" "$project_name" "$artifacts_json" || true)
    if [[ -z "$plan_file" ]]; then
      echo "[backfill-file-scope] task $project_number ($project_name): SKIP -- no resolvable plan file (plan-less, left absent)"
      SKIPPED_PLANLESS_COUNT=$((SKIPPED_PLANLESS_COUNT + 1))
      continue
    fi

    harvested=$(bash "$HARVESTER" "$plan_file" 2>/dev/null) || {
      echo "[backfill-file-scope] task $project_number ($project_name): WARNING -- plan-file-scope-harvest.sh failed for $plan_file, skipping (non-blocking)" >&2
      SKIPPED_PLANLESS_COUNT=$((SKIPPED_PLANLESS_COUNT + 1))
      continue
    }
    if [[ -z "$harvested" || "$harvested" == "[]" || "$harvested" == "null" ]]; then
      echo "[backfill-file-scope] task $project_number ($project_name): plan found ($plan_file) but harvested nothing -- SKIP"
      SKIPPED_PLANLESS_COUNT=$((SKIPPED_PLANLESS_COUNT + 1))
      continue
    fi

    echo "[backfill-file-scope] task $project_number ($project_name): plan=$plan_file -> would add $harvested"
    UPDATES_JSON=$(jq -c --arg num "$project_number" --argjson add "$harvested" '. + {($num): $add}' <<<"$UPDATES_JSON")
    BACKFILLED_COUNT=$((BACKFILLED_COUNT + 1))
  done < <(echo "$CANDIDATES_JSON" | jq -c '.[]')
fi

ALREADY_COVERED_COUNT=$(jq '[.active_projects[] | select((.file_scope != null) and (.file_scope != []))] | length' "$STATE_FILE")

echo ""
echo "=== Summary ==="
echo "Tasks backfilled:              $BACKFILLED_COUNT"
echo "Tasks already covered (skipped): $ALREADY_COVERED_COUNT"
echo "Plan-less tasks (left absent):  $SKIPPED_PLANLESS_COUNT"

if [[ "$BACKFILLED_COUNT" -eq 0 ]]; then
  echo "[backfill-file-scope] nothing to backfill -- no state.json write"
  exit 0
fi

if [[ "$DRY_RUN" == "true" ]]; then
  echo "[backfill-file-scope] --dry-run: no write performed"
  exit 0
fi

SESSION_ID="$(common_session_id)"
# `. as $item | ...`: a jq function argument (the `has(...)`/index expression here) is evaluated
# against the SAME input as the function call itself ($updates), not the outer `.` -- binding the
# task entry to $item first is what lets `$item.project_number` reach the entry's own field
# instead of silently probing $updates for a nonexistent `.project_number` key.
STATE_WRITE_ARGS=(
  '(.active_projects) |= map(. as $item | if ($updates | has($item.project_number|tostring)) then .file_scope = ((.file_scope // []) + ($updates[($item.project_number|tostring)]) | unique) else . end)'
  --session-id "$SESSION_ID"
  --argjson updates "$UPDATES_JSON"
)
# Always pass --state-file explicitly (even for the default target) so this call is unambiguous
# regardless of the invoking CWD -- state-write.sh resolves a relative --state-file against the
# CALLER's CWD, not this script's own location, so an absolute path is used here.
STATE_WRITE_ARGS+=(--state-file "$STATE_FILE_DIR/$(basename "$STATE_FILE")")

bash "$STATE_WRITE" "${STATE_WRITE_ARGS[@]}"

echo "[backfill-file-scope] real run complete: $BACKFILLED_COUNT task(s) backfilled"
