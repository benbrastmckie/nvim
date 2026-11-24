#!/usr/bin/env bash
# milestone-review-handoff.sh - Prepares, and only prepares, the push and review request for a
# milestone whose derived batch-done count reaches its batch count. It records
# review.state="prepared" plus review.ref, drafts a review summary, and calls
# review-stack-prepare.sh to cut and show the milestone's review stack: on success it prints
# that stack as the final output; on refusal (including a missing or non-executable
# review-stack-prepare.sh) it prints the refusal reason and the literal /please push-request
# command for the integration branch alone, with no /merge line -- it NEVER pushes, NEVER
# creates a PR/MR, and NEVER mints a push grant. See
# specs/decisions/branch-topology-and-landing-strategy.md, ruling R8, for the ruling this
# implements, and rules/pr-prohibition.md for the prohibition it honors.
#
# THIS SCRIPT NEVER CALLS: git push, git-push-granted.sh, gh, glab, or /merge, and never writes
# the push-grant store. Grepping this file for any of those (outside this header and this
# assertion's own strings) should return nothing; the test suite asserts it. It shells out to
# review-stack-prepare.sh to cut and show the stack, which likewise never pushes, never calls a
# forge, and never touches HEAD, the index or the working tree.
#
# WHAT IT REVIEWS
# ---------------
# The integration branch. A task's phase commits stay on it as they are made, interleaved with
# other tasks' commits and with bookkeeping commits, so a milestone is not a commit range and a
# task is not one commit there. The reviewable unit of a task is its LANDING PROOF: the record
# scripts/task-landing-verify.sh appends to the batch record when the task's completion status
# is written (context/standards/orchestrator-runtime-files.md, "The batch record"). This script
# reads those proofs; it builds no ref and squashes nothing.
#
# WHAT IT DOES, PER MILESTONE
# ----------------------------
# 1. Derives b_done/b the same way roadmap-integration.sh's MS_RENDER_JQ does: a batch's
#    task_ids member is "done" when it is terminal in active_projects, or absent from
#    active_projects and present in the sibling archive/state.json; a batch is done when every
#    member is done; a milestone's b_done/b is its done-batch count over its total batch count.
# 2. Acts ONLY on the none -> prepared transition: a milestone whose review.state is already
#    something other than "none" is left alone (this is also what makes "the milestone whose
#    completion became true during this invocation" require no separate bookkeeping -- the
#    transition is monotonic and fires at most once per milestone).
# 3. Resolves the integration branch: the newest batch record listing one of the milestone's
#    tasks, else the declared `integration_branch`, else the branch HEAD names. With none of the
#    three (a detached HEAD and nothing declared) it emits a named warning and prepares nothing.
# 4. Lists, per done task: the subject of its completion commit, its attributed commit count and
#    its end commit, read from its landing proof. A task with no proof is attributed by the
#    commit-subject convention, bounded below by the task's `created` time (the bound keeps an
#    earlier holder of a reused task number out); a task with neither is listed as unattributed.
#    A task whose proof has a non-empty `shared_paths` is flagged: its work in those files
#    cannot be separated from another writer's by path.
# 5. Drafts specs/milestones/<id>-review-handoff.md from that list and writes
#    review.state="prepared", review.ref="refs/heads/<integration branch>",
#    review.updated=<YYYY-MM-DD> via state-write.sh. Leaves review.request empty (no PR exists
#    yet) and leaves progress.status untouched.
# 6. Calls review-stack-prepare.sh to cut and show the milestone's review stack. On success,
#    prints that stack as the final output. On refusal (including a missing or non-executable
#    review-stack-prepare.sh), prints the refusal reason and the /please push-request command
#    for the integration branch alone, with no /merge line. Both arms print a line stating that
#    a push grant is bound to HEAD at mint time, so a commit by another session in between means
#    typing the grant again, and that this system will not run any of these on its own.
#
# USAGE
# -----
#   milestone-review-handoff.sh --session SID [--dry-run]
#
# Exit codes: 0 always (this is an advisory, non-fatal step; a per-milestone problem is a named
# warning, never a fatal exit, so a caller invoking this non-fatally never needs special exit-
# code handling beyond "did it run").

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
# shellcheck source=deploy-root-guard.sh disable=SC1091
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
[ -n "${REPO_ROOT:-}" ] && PROJECT_ROOT="$REPO_ROOT"
cd "$PROJECT_ROOT" || exit 1

STATE_FILE="specs/state.json"
ARCHIVE_STATE_FILE="specs/archive/state.json"
SPECS_DIR="${PROJECT_ROOT}/specs"
STATE_WRITE="${SCRIPT_DIR}/state-write.sh"
rsp_script="${SCRIPT_DIR}/review-stack-prepare.sh"

session_id=""
dry_run="false"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --session) session_id="${2:-}"; shift 2 ;;
    --dry-run) dry_run="true"; shift ;;
    *) echo "Usage: $0 --session SID [--dry-run]" >&2; exit 0 ;;
  esac
done
if [ -z "$session_id" ]; then
  echo "Usage: $0 --session SID [--dry-run]" >&2
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "WARNING: [milestone-review-handoff] jq is required and is not on PATH; nothing prepared." >&2
  exit 0
fi

for lib in task-lookup-lib.sh runtime-file-patterns.sh batch-admission-lib.sh; do
  if [ ! -f "${SCRIPT_DIR}/lib/${lib}" ]; then
    echo "WARNING: [milestone-review-handoff] required library lib/${lib} is missing; nothing prepared." >&2
    exit 0
  fi
done
# shellcheck source=lib/task-lookup-lib.sh disable=SC1091
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"
# shellcheck source=lib/runtime-file-patterns.sh disable=SC1091
source "${SCRIPT_DIR}/lib/runtime-file-patterns.sh"
# shellcheck source=lib/batch-admission-lib.sh disable=SC1091
source "${SCRIPT_DIR}/lib/batch-admission-lib.sh"

archive_arg="specs/archive/state.json"
[ -f "$ARCHIVE_STATE_FILE" ] || archive_arg="/dev/null"

# DERIVE_JQ: the same "done" definition roadmap-integration.sh's MS_RENDER_JQ uses, restricted to
# the fields this script needs (milestone id, review.state, and each batch's done/open split).
DERIVE_JQ='
def terminal: ["completed","abandoned","expanded"];
($arch[0] // {}) as $a
| (.active_projects // []) as $ap
| [ ($a.archived_projects // [])[], ($a.completed_projects // [])[], ($a.abandoned_projects // [])[] ] as $archived
| [$ap[].project_number] as $apnums
| ( [$ap[] | select(.status | IN(terminal[])) | .project_number]
    + [$archived[].project_number | select(IN($apnums[]) | not)] | unique ) as $done
| [ (.roadmap_milestones // [])[]
    | . as $m
    | [ ($m.batches // [])[] | (.task_ids // []) as $ids
        | { ids: $ids, open: [$ids[] | select(IN($done[]) | not)] } ] as $bs
    | { id: ($m.id | tostring),
        review_state: ($m.review.state // "none"),
        b: ($bs | length),
        b_done: ([$bs[] | select((.open | length) == 0)] | length),
        t_ids: ([$bs[].ids[]] | unique) } ]
'

milestones_json="$(jq -c --slurpfile arch "$archive_arg" "$DERIVE_JQ" "$STATE_FILE" 2>/dev/null)"
if [ -z "$milestones_json" ] || [ "$milestones_json" = "null" ]; then
  echo "NOTE: [milestone-review-handoff] no roadmap_milestones entries; nothing to prepare." >&2
  exit 0
fi

# proof_for_task <task_number> -- stdout: the newest landing proof recorded for the task across
# every batch record listing it (compact JSON), or nothing.
proof_for_task() {
  local task="$1" rec
  while IFS= read -r rec; do
    [ -n "$rec" ] && [ -f "$rec" ] || continue
    jq -c --argjson n "$task" \
      '[(.landing_proofs // [])[] | select(.task_number == $n)] | last // empty' \
      "$rec" 2>/dev/null || true
  done < <(batch_admission_record_for_task "$SPECS_DIR" "$task" all) | head -n 1
}

# resolve_integration_branch <task_ids...> -- stdout: the branch name, or nothing.
resolve_integration_branch() {
  local task rec newest="" newest_at="" at branch=""
  for task in "$@"; do
    rec="$(batch_admission_record_for_task "$SPECS_DIR" "$task")"
    [ -n "$rec" ] || continue
    at="$(jq -r '.admitted_at // ""' "$rec" 2>/dev/null || true)"
    if [ -z "$newest" ] || [[ "$at" > "$newest_at" ]]; then
      newest="$rec"
      newest_at="$at"
    fi
  done
  [ -n "$newest" ] && branch="$(jq -r '.integration_branch // empty' "$newest" 2>/dev/null || true)"
  [ -n "$branch" ] || branch="$(batch_admission_integration_branch "$PROJECT_ROOT")"
  [ -n "$branch" ] || branch="$(git symbolic-ref -q --short HEAD 2>/dev/null || true)"
  printf '%s' "$branch"
}

# task_review_line <task_number> <branch> -- stdout: one markdown bullet for the task.
# shellcheck disable=SC2016  # the backticks in the printf formats below are markdown, not shell
task_review_line() {
  local task="$1" branch="$2" proof subject count end shared entry created created_epoch
  local subject_re sha ct subj
  local -a own=()
  subject="$(git log -1 --format=%s -E --grep="^task ${task}: complete implementation" "$branch" 2>/dev/null || true)"
  [ -n "$subject" ] || subject="task ${task} (no completion commit found on ${branch})"
  proof="$(proof_for_task "$task")"
  if [ -n "$proof" ]; then
    count="$(printf '%s' "$proof" | jq -r '(.commits // []) | length')"
    end="$(printf '%s' "$proof" | jq -r '.end_commit // ""')"
    shared="$(printf '%s' "$proof" | jq -r '(.shared_paths // []) | join(", ")')"
    printf -- '- %s -- %s attributed commit(s), end commit `%s`' "$subject" "$count" "$end"
    [ -n "$shared" ] && printf ' -- SHARED PATHS: %s' "$shared"
    printf '\n'
    return 0
  fi
  entry="$(task_lookup_entry "$task" "$STATE_FILE" 2>/dev/null || true)"
  created="$(printf '%s' "$entry" | jq -r '.created // empty' 2>/dev/null || true)"
  created_epoch=""
  [ -n "$created" ] && created_epoch="$(date -u -d "$created" +%s 2>/dev/null || true)"
  if [ -z "$created_epoch" ]; then
    printf -- '- %s -- unattributed: no landing proof, and no created time to bound attribution by\n' "$subject"
    return 0
  fi
  subject_re="^task ${task}(:| phase )"
  while read -r sha ct subj; do
    [ -n "$sha" ] || continue
    [[ "$subj" =~ $subject_re ]] || continue
    [ "$ct" -ge "$created_epoch" ] 2>/dev/null && own+=("$sha")
  done < <(git log --no-merges --reverse --format='%H %ct %s' -E --grep="$subject_re" "$branch" 2>/dev/null)
  if [ "${#own[@]}" -eq 0 ]; then
    printf -- '- %s -- no landing proof and no commit attributable since %s\n' "$subject" "$created"
  else
    printf -- '- %s -- %s attributed commit(s), last commit `%s` (no landing proof; attributed by commit subject since %s)\n' \
      "$subject" "${#own[@]}" "${own[-1]}" "$created"
  fi
  return 0
}

mkdir -p specs/milestones

count="$(echo "$milestones_json" | jq 'length')"
i=0
while [ "$i" -lt "$count" ]; do
  m="$(echo "$milestones_json" | jq -c ".[$i]")"
  i=$((i + 1))
  mid="$(echo "$m" | jq -r '.id')"
  review_state="$(echo "$m" | jq -r '.review_state')"
  b="$(echo "$m" | jq -r '.b')"
  b_done="$(echo "$m" | jq -r '.b_done')"

  if [ "$b" -eq 0 ] || [ "$b_done" -ne "$b" ]; then
    continue
  fi
  if [ "$review_state" != "none" ]; then
    continue
  fi

  mapfile -t task_ids < <(echo "$m" | jq -r '.t_ids[]')
  integration_branch="$(resolve_integration_branch "${task_ids[@]}")"
  if [ -z "$integration_branch" ] \
     || ! git rev-parse --verify --quiet "refs/heads/${integration_branch}^{commit}" >/dev/null; then
    echo "WARNING: [milestone-review-handoff] milestone ${mid} reports all batches done but its integration branch cannot be resolved to a commit (resolved name: '${integration_branch:-none}'); preparing nothing for this milestone." >&2
    continue
  fi
  review_ref="refs/heads/${integration_branch}"

  task_lines=""
  shared_tasks=""
  for task in "${task_ids[@]}"; do
    task_lines+="$(task_review_line "$task" "$integration_branch")"$'\n'
    if [ -n "$(proof_for_task "$task" | jq -r '(.shared_paths // []) | join(",")' 2>/dev/null)" ]; then
      shared_tasks="${shared_tasks:+${shared_tasks}, }${task}"
    fi
  done

  # Cut and show the milestone's review stack, non-fatally. Never threads this script's own
  # --dry-run into either call (cut --dry-run writes no manifest, so a following show would
  # refuse manifest_missing even though cut exited 0). rsp_show_output is only ever show's own
  # stdout -- cut's own "UNIT NN: ..." lines are captured for their exit code alone and never
  # surfaced.
  rsp_ok="false"
  rsp_reason_line=""
  rsp_show_output=""
  if [ ! -x "$rsp_script" ]; then
    rsp_reason_line="REFUSED: review-stack-prepare.sh: script_missing: ${rsp_script} not found or not executable beside milestone-review-handoff.sh"
  else
    rsp_cut_output="$(bash "$rsp_script" cut --milestone "$mid" 2>&1)"
    rsp_cut_code=$?
    if [ "$rsp_cut_code" -ne 0 ]; then
      rsp_reason_line="$(printf '%s\n' "$rsp_cut_output" | grep '^REFUSED:' | head -n 1)"
      [ -n "$rsp_reason_line" ] || rsp_reason_line="REFUSED: review-stack-prepare.sh: cut_failed: exited ${rsp_cut_code} with no REFUSED: line"
    else
      rsp_show_err="$(mktemp)"
      rsp_show_output="$(bash "$rsp_script" show --stack-id "$mid" 2>"$rsp_show_err")"
      rsp_show_code=$?
      rsp_show_stderr="$(cat "$rsp_show_err" 2>/dev/null)"
      rm -f "$rsp_show_err"
      if [ "$rsp_show_code" -ne 0 ]; then
        rsp_reason_line="$(printf '%s\n' "$rsp_show_stderr" | grep '^REFUSED:' | head -n 1)"
        [ -n "$rsp_reason_line" ] || rsp_reason_line="REFUSED: review-stack-prepare.sh: show_failed: exited ${rsp_show_code} with no REFUSED: line"
        rsp_show_output=""
      else
        rsp_ok="true"
      fi
    fi
  fi
  head_bind_line="A /please push grant is bound to the commit at HEAD when it is typed; a commit by another session in between means typing the grant again."

  summary_path="specs/milestones/${mid}-review-handoff.md"
  {
    echo "# Milestone ${mid} Review Handoff"
    echo ""
    echo "Prepared $(common_timestamp_date) for review of \`${integration_branch}\`."
    echo ""
    echo "## Tasks"
    echo ""
    printf '%s' "$task_lines"
    echo ""
    echo "## Review Unit"
    echo ""
    echo "\`${integration_branch}\` carries each task's phase commits as they were made, interleaved"
    echo "with other tasks and with bookkeeping commits. It is not one commit per task. Each task's"
    echo "reviewable unit is the commit list of its landing proof, recorded in the batch record"
    echo "under \`specs/.orchestration/batch/\`."
    if [ -n "$shared_tasks" ]; then
      echo ""
      echo "Task(s) ${shared_tasks} share one or more files with another writer between their first"
      echo "and end commits (SHARED PATHS above). Their work in those files cannot be separated by"
      echo "path: accept the co-landed lines, name them in the review, or review those tasks as one"
      echo "unit."
    fi
    echo ""
    if [ "$rsp_ok" = "true" ]; then
      echo "## Review Stack"
      echo ""
      echo "This handoff was PREPARED only -- nothing was pushed and no PR/MR was opened. The"
      echo "review stack below was cut by review-stack-prepare.sh; push and open each entry"
      echo "yourself when ready:"
      echo ""
      echo '```'
      printf '%s\n' "$rsp_show_output"
      echo '```'
      echo ""
      echo "$head_bind_line"
    else
      echo "## Next Step"
      echo ""
      echo "This handoff was PREPARED only -- nothing was pushed and no PR/MR was opened."
      echo "${rsp_reason_line}"
      echo ""
      echo "Run the command below yourself when ready:"
      echo ""
      echo '```'
      echo "/please push ${integration_branch}"
      echo '```'
      echo ""
      echo "$head_bind_line"
    fi
  } > "$summary_path"

  if [ "$dry_run" = "true" ]; then
    echo "NOTE: [milestone-review-handoff] [dry-run] would write review.state=prepared, review.ref=${review_ref} for milestone ${mid}; would write ${summary_path}." >&2
  else
    today="$(common_timestamp_date)"
    bash "$STATE_WRITE" \
      '(.roadmap_milestones[] | select(.id == $mid)).review = {"state": "prepared", "ref": $ref, "updated": $today}' \
      --session-id "$session_id" \
      --arg mid "$mid" --arg ref "$review_ref" --arg today "$today" \
      >/dev/null 2>&1 || echo "WARNING: [milestone-review-handoff] state-write.sh failed for milestone ${mid}; review fields not persisted this invocation." >&2
  fi

  echo "" >&2
  echo "MILESTONE REVIEW READY: milestone ${mid} -- all ${b} batch(es) done. Prepared, not pushed." >&2
  if [ -n "$shared_tasks" ]; then
    echo "NOTE: task(s) ${shared_tasks} share files with another writer; see ${summary_path}." >&2
  fi
  if [ "$rsp_ok" = "true" ]; then
    echo "Review stack (push and open each entry yourself when ready):" >&2
    printf '%s\n' "$rsp_show_output" >&2
  else
    echo "${rsp_reason_line}" >&2
    echo "To push, run:" >&2
    echo "  /please push ${integration_branch}" >&2
  fi
  echo "$head_bind_line" >&2
  echo "This system will not run any of these on its own." >&2
done

exit 0
