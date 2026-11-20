#!/usr/bin/env bash
# milestone-review-handoff.sh - Prepares, and only prepares, the push and review request for a
# milestone whose derived batch-done count reaches its batch count. It records
# review.state="prepared" plus review.ref, drafts a review summary, and prints the literal
# /please + /merge commands for the user to run -- it NEVER pushes, NEVER creates a PR/MR, and
# NEVER mints a push grant. See specs/decisions/branch-topology-and-landing-strategy.md, ruling
# R8, for the ruling this implements, and rules/pr-prohibition.md for the prohibition it honors.
#
# THIS SCRIPT NEVER CALLS: git push, git-push-granted.sh, gh, glab, or /merge, and never writes
# the push-grant store. Grepping this file for any of those (outside this header and this
# assertion's own strings) should return nothing; the test suite asserts it.
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
# 3. Confirms refs/heads/milestone/<id> exists and its commit count against the integration
#    branch matches the milestone's derived done-task count; on a mismatch, emits a named
#    warning and prepares nothing for that milestone (continues to the next one).
# 4. Computes the commit range against the integration branch's current tip and drafts
#    specs/milestones/<id>-review-handoff.md: one bullet per landed task's squash-commit subject.
# 5. Writes review.state="prepared", review.ref="refs/heads/milestone/<id>",
#    review.updated=<YYYY-MM-DD> via state-write.sh. Leaves review.request empty (no PR exists
#    yet) and leaves progress.status untouched.
# 6. Prints the literal /please push-request command for the milestone ref, then /merge, as the
#    final output, stating explicitly that this script will not run them.
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
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
[ -n "${REPO_ROOT:-}" ] && PROJECT_ROOT="$REPO_ROOT"
cd "$PROJECT_ROOT" || exit 1

STATE_FILE="specs/state.json"
ARCHIVE_STATE_FILE="specs/archive/state.json"
EXT_FILE=".claude-extensions.json"
STATE_WRITE="${SCRIPT_DIR}/state-write.sh"

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

integration_branch="$(jq -r '.integration_branch // ""' "$EXT_FILE" 2>/dev/null || echo "")"
if [ -z "$integration_branch" ]; then
  integration_branch="$(git rev-parse --abbrev-ref HEAD)"
  echo "ADVISORY: [milestone-review-handoff] no .integration_branch declared in ${EXT_FILE}; falling back to the currently checked-out branch ('${integration_branch}')." >&2
fi

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

  milestone_ref="refs/heads/milestone/${mid}"
  if ! git rev-parse --verify --quiet "$milestone_ref" >/dev/null; then
    echo "WARNING: [milestone-review-handoff] milestone ${mid} reports all batches done but ${milestone_ref} does not exist; preparing nothing for this milestone." >&2
    continue
  fi

  done_task_count="$(echo "$m" | jq -r '.t_ids | length')"
  ref_commit_count="$(git rev-list --count "${integration_branch}..${milestone_ref}" 2>/dev/null || echo -1)"
  if [ "$ref_commit_count" != "$done_task_count" ]; then
    echo "WARNING: [milestone-review-handoff] milestone ${mid}: ${milestone_ref} carries ${ref_commit_count} commit(s) ahead of ${integration_branch}, expected ${done_task_count} (one per done task); preparing nothing for this milestone." >&2
    continue
  fi

  summary_path="specs/milestones/${mid}-review-handoff.md"
  {
    echo "# Milestone ${mid} Review Handoff"
    echo ""
    echo "Prepared $(common_timestamp_date) for review on \`${milestone_ref}\` against \`${integration_branch}\`."
    echo ""
    echo "## Landed Commits"
    echo ""
    git log "${integration_branch}..${milestone_ref}" --format='- %s' 2>/dev/null
    echo ""
    echo "## Next Step"
    echo ""
    echo "This handoff was PREPARED only -- nothing was pushed and no PR/MR was opened. Run the"
    echo "commands below yourself when ready:"
    echo ""
    echo '```'
    echo "/please push ${milestone_ref}"
    echo "/merge"
    echo '```'
  } > "$summary_path"

  if [ "$dry_run" = "true" ]; then
    echo "NOTE: [milestone-review-handoff] [dry-run] would write review.state=prepared, review.ref=${milestone_ref} for milestone ${mid}; would write ${summary_path}." >&2
  else
    today="$(common_timestamp_date)"
    bash "$STATE_WRITE" \
      '(.roadmap_milestones[] | select(.id == $mid)).review = {"state": "prepared", "ref": $ref, "updated": $today}' \
      --session-id "$session_id" \
      --arg mid "$mid" --arg ref "$milestone_ref" --arg today "$today" \
      >/dev/null 2>&1 || echo "WARNING: [milestone-review-handoff] state-write.sh failed for milestone ${mid}; review fields not persisted this invocation." >&2
  fi

  echo "" >&2
  echo "MILESTONE REVIEW READY: milestone ${mid} -- all ${b} batch(es) done. Prepared, not pushed." >&2
  echo "To push and open the review yourself, run:" >&2
  echo "  /please push ${milestone_ref}" >&2
  echo "  /merge" >&2
  echo "This system will not run either command on its own." >&2
done

exit 0
