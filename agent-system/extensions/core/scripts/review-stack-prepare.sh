#!/usr/bin/env bash
# review-stack-prepare.sh - Prepares, and only prepares, a stack of review branches and PR
# descriptions cut from this repository's landed work, entirely by git plumbing. It never
# pushes, never calls a forge, and never touches HEAD, the index or the working tree.
#
# THIS SCRIPT NEVER CALLS: git push, git checkout, git switch, git merge, git rebase, git
# replay, gh, or glab. Grepping this file for any of those strings (outside this header)
# returns nothing; the test suite asserts it over the script's non-comment lines.
#
# SUBCOMMANDS
# -----------
#   cut              Selects a set of tasks, groups them into review units, orders the units,
#                     assigns each one a branch name and a base, then builds each unit's review
#                     commit by git plumbing alone (never touching HEAD, the index or the
#                     working tree), moves its branch ref by compare-and-swap, writes a PR body
#                     file per entry, and writes the stack's manifest. `--dry-run` resolves and
#                     prints the same "UNIT NN: ..." lines without writing any ref, body or
#                     manifest.
#                       Selection (exactly one): --milestone ID | --batch SESSION | --tasks N,N,...
#                       --stack-id NAME      required for --batch/--tasks; defaults to the
#                                            milestone id for --milestone.
#                       --merge N+M          force two selected tasks into one unit, repeatable.
#                       --order N,N,...      an operator-supplied total order over the selected
#                                            units (named by any one member task number each),
#                                            overriding the automatic dependency/landing order.
#                       --prefix NAME        branch-name prefix; default "review".
#
# CUT: BUILDING THE REVIEW COMMITS AND THE MANIFEST (decisions PD4, PD6)
# -------------------------------------------------------------------------
# Each unit's commit is built by overlaying its path set's blobs at its end commit onto its
# base's tree, using a private temporary index (GIT_INDEX_FILE) -- never the shared working
# tree, index or HEAD. The bottom unit of each component overlays onto
# merge-base(review base, integration branch), then, if the review base's tip is past that
# merge base, the overlaid commit is moved onto the tip with the three-way
# `git merge-tree --write-tree --merge-base=<old parent> <new parent> <commit>` (a conflict
# refuses and names the path); every unit above the bottom overlays directly onto the unit
# below it, which this script just built, so no move is needed there. A unit whose branch
# already carries the same tree on the same parent is left alone (a re-cut with unchanged
# inputs is a no-op); otherwise the branch is moved by compare-and-swap `git update-ref`. A
# branch whose remote-tracking ref holds a commit this stack's manifest does not record is
# refused rather than silently superseded. The manifest and one PR body file per entry are
# written under `specs/.orchestration/reviews/<stack id>/` (gitignored, machine-local; see
# `context/standards/orchestrator-runtime-files.md`).
#
#   restack           Move a stack's descendants onto a merged parent's new base. Body added by
#                     a later plan phase; this phase resolves and stops.
#   show              Print a stack's manifest with its literal commands (`--stack-id NAME`
#                     required to read one; `--json` emits the manifest verbatim). With no
#                     `--stack-id`, resolves and stops (unchanged from earlier phases).
#   record-request    `record-request NN URL --stack-id NAME` fills entry NN's request field
#                     with URL in that stack's manifest.
#
# RESOLUTION (every subcommand, before any of the above runs)
# -------------------------------------------------------------
# 1. Integration branch: the newest batch record naming one of the selected tasks (a cut's own
#    selection; none are selectable for restack/show/record-request yet), else the declared
#    `integration_branch` (batch_admission_integration_branch), else the branch HEAD names.
#    Never refused: absence only narrows what "the bottom of the stack" can mean.
# 2. Review base (decision PD1 of the implementation plan): the top-level string key
#    `review_base` in .claude-extensions.json, or --review-base for one invocation. Refused,
#    with a distinct exit code and a named reason on standard error, when the resolved value is
#    absent, empty, not a string, unresolvable to a commit, or names the integration branch.
# 3. Remote: --remote, else the integration branch's configured remote
#    (`git config branch.<name>.remote`), else the repository's only remote, else a refusal
#    asking for --remote.
# 4. Platform (decision PD9): GitHub only, head and base behind the same URL. A GitLab remote,
#    an unrecognised host, or a remote whose push URL differs from its fetch URL are each
#    refused by name.
#
# CUT: SELECTION, UNITS AND ORDER (decisions PD3, PD5, PD10)
# ------------------------------------------------------------
# Each selected task is attributed to a landing proof (batch_admission_record_for_task, PD10),
# or, absent one, to its non-merge commits on the integration branch whose subject matches
# "task N:"/"task N phase", bounded below by the task's `created` time. A task with neither is
# refused by name. Tasks merge into one unit when either's proof names the other's path in its
# `shared_paths`, or the operator passes --merge. A task elsewhere in the batch records that is
# not selected, shares a path with the selection, and is not yet an ancestor of the review base
# is pulled in. Units are grouped into connected components over dependency edges
# (`specs/state.json` `dependencies`, restricted to selected tasks) and raw path overlap, then
# ordered topologically within each component (dependency edges), ties broken by end-commit
# ancestry. A dependency edge between two path-overlapping units whose landed commit order
# disagrees with that edge's direction is refused by name, naming both units.
#
# USAGE
# -----
#   review-stack-prepare.sh cut [--dry-run] [--review-base REF] [--remote NAME]
#       (--milestone ID | --batch SESSION | --tasks N,N,...) [--stack-id NAME]
#       [--merge N+M]... [--order N,N,...] [--prefix NAME]
#   review-stack-prepare.sh restack --stack-id NAME [--dry-run] [--review-base REF] [--remote NAME]
#   review-stack-prepare.sh show --stack-id NAME [--json] [--review-base REF] [--remote NAME]
#   review-stack-prepare.sh record-request NN URL --stack-id NAME [--dry-run]
#       [--review-base REF] [--remote NAME]
#
# EXIT CODES
# ----------
#   0   resolved (and, once a later phase fills restack/show/record-request, that body's result)
#   2   usage error
#  10   review_base_undeclared
#  11   review_base_invalid
#  12   review_base_unresolvable
#  13   review_base_is_integration_branch
#  20   remote_unresolvable
#  30   platform_gitlab_unsupported
#  31   platform_unrecognized_host
#  32   platform_push_url_mismatch
#  40   selection_missing       cut given none of --milestone/--batch/--tasks
#  41   stack_id_required       --batch/--tasks given with no --stack-id
#  42   selection_empty         the selection resolved to zero valid task numbers
#  43   task_unattributable     a selected (or pulled-in) task has no proof and no fallback
#  44   order_cycle             the dependency edges among a component's units form a cycle
#  45   order_contradiction     a dependency edge disagrees with landed order on an overlapping path
#  46   order_flag_invalid      --order does not name exactly the selected units, once each
#  47   merge_flag_invalid      --merge names a task outside the selection
#  48   ref_conflict            moving a unit's commit onto its parent conflicted on a path
#  49   unknown_remote_commit   a branch's remote-tracking ref holds a commit the manifest does
#                               not record
#  50   manifest_missing       show/record-request given a --stack-id with no manifest on disk
#  51   record_request_args_invalid   record-request was not given both NN and URL
#  52   record_request_entry_not_found   NN does not name an entry in the stack's manifest

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
# shellcheck source=deploy-root-guard.sh disable=SC1091
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
[ -n "${REPO_ROOT:-}" ] && PROJECT_ROOT="$REPO_ROOT"
cd "$PROJECT_ROOT" || exit 1

# shellcheck source=lib/batch-admission-lib.sh disable=SC1091
source "${SCRIPT_DIR}/lib/batch-admission-lib.sh"
# shellcheck source=lib/task-lookup-lib.sh disable=SC1091
source "${SCRIPT_DIR}/lib/task-lookup-lib.sh"

SPECS_DIR="${PROJECT_ROOT}/specs"
STATE_FILE="${SPECS_DIR}/state.json"

rsp_usage() {
  echo "Usage: $0 {cut|restack|show|record-request} [--dry-run] [--review-base REF] [--remote NAME] [--stack-id NAME] [...]" >&2
  exit 2
}

# rsp_refuse <exit_code> <reason> <message> -- the one refusal path every resolver below uses.
rsp_refuse() {
  local code="$1" reason="$2" message="$3"
  echo "REFUSED: review-stack-prepare.sh: ${reason}: ${message}" >&2
  exit "$code"
}

# Resolvers below set these globals rather than printing for capture in "$(...)": a refusal
# calls `exit` directly (see rsp_refuse), and `exit` inside a command-substitution subshell
# would only terminate that subshell, silently losing the refusal's exit code. Every resolver
# below is therefore called as a plain statement, never wrapped in "$(...)".
RSP_INTEGRATION_BRANCH=""
RSP_REVIEW_BASE=""
RSP_REMOTE=""
RSP_PLATFORM=""

# rsp_resolve_integration_branch [task_number...] -- sets RSP_INTEGRATION_BRANCH, or leaves it
# empty. Same chain milestone-review-handoff.sh's resolve_integration_branch() uses.
rsp_resolve_integration_branch() {
  local task rec newest="" newest_at="" at branch=""
  for task in "$@"; do
    rec="$(batch_admission_record_for_task "$SPECS_DIR" "$task" 2>/dev/null || true)"
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
  RSP_INTEGRATION_BRANCH="$branch"
}

# _rsp_declared_review_base <project_root> -- stdout, one of:
#   absent            no .claude-extensions.json, no jq, no object, or no `review_base` key
#   s:<value>         the key is a string, value follows the prefix
#   x:<json_type>     the key is present but not a string (its JSON type follows the prefix)
_rsp_declared_review_base() {
  local root="${1:-.}" file
  file="${root}/.claude-extensions.json"
  [ -f "$file" ] || { echo "absent"; return 0; }
  command -v jq >/dev/null 2>&1 || { echo "absent"; return 0; }
  jq -r '
    if (type == "object") and has("review_base") and (.review_base != null)
    then (.review_base | if type == "string" then "s:" + . else "x:" + type end)
    else "absent" end' "$file" 2>/dev/null || echo "absent"
}

# rsp_resolve_review_base <flag_set:true|false> <flag_value> <integration_branch> -- sets
# RSP_REVIEW_BASE, or refuses per decision PD1.
rsp_resolve_review_base() {
  local flag_set="${1:-false}" flag_value="${2:-}" integration_branch="${3:-}" raw value=""
  if [ "$flag_set" = "true" ]; then
    value="$flag_value"
  else
    raw="$(_rsp_declared_review_base "$PROJECT_ROOT")"
    case "$raw" in
      s:*)
        value="${raw#s:}"
        ;;
      x:*)
        rsp_refuse 11 review_base_invalid "the declared 'review_base' key in .claude-extensions.json is a ${raw#x:}, not a string"
        ;;
      *)
        rsp_refuse 10 review_base_undeclared "no 'review_base' key in .claude-extensions.json and no --review-base given; declare review_base beside integration_branch, or pass --review-base"
        ;;
    esac
  fi
  if [ -z "$value" ]; then
    rsp_refuse 11 review_base_invalid "review_base resolved to an empty string"
  fi
  if ! git rev-parse -q --verify "${value}^{commit}" >/dev/null 2>&1; then
    rsp_refuse 12 review_base_unresolvable "review_base '${value}' does not resolve to a commit"
  fi
  if [ -n "$integration_branch" ] && [ "$value" = "$integration_branch" ]; then
    rsp_refuse 13 review_base_is_integration_branch "review_base '${value}' names the integration branch; declare a review base distinct from it"
  fi
  RSP_REVIEW_BASE="$value"
}

# rsp_resolve_remote <flag_value> <integration_branch> -- sets RSP_REMOTE, or refuses.
rsp_resolve_remote() {
  local override="${1:-}" integration_branch="${2:-}" remote="" count
  if [ -n "$override" ]; then
    RSP_REMOTE="$override"
    return 0
  fi
  if [ -n "$integration_branch" ]; then
    remote="$(git config --get "branch.${integration_branch}.remote" 2>/dev/null || true)"
  fi
  if [ -z "$remote" ]; then
    count="$(git remote 2>/dev/null | wc -l | tr -d ' ')"
    if [ "$count" = "1" ]; then
      remote="$(git remote 2>/dev/null)"
    fi
  fi
  if [ -z "$remote" ]; then
    rsp_refuse 20 remote_unresolvable "no remote is configured for the integration branch and this repository does not have exactly one remote; pass --remote"
  fi
  RSP_REMOTE="$remote"
}

# rsp_detect_platform <remote> -- sets RSP_PLATFORM to "github", or refuses per decision PD9.
rsp_detect_platform() {
  local remote="${1:-}" fetch_url="" push_url=""
  fetch_url="$(git remote get-url "$remote" 2>/dev/null || true)"
  push_url="$(git remote get-url --push "$remote" 2>/dev/null || true)"
  if [ -z "$fetch_url" ]; then
    rsp_refuse 31 platform_unrecognized_host "remote '${remote}' has no resolvable fetch URL"
  fi
  if [ "$fetch_url" != "$push_url" ]; then
    rsp_refuse 32 platform_push_url_mismatch "remote '${remote}' has different fetch (${fetch_url}) and push (${push_url}) URLs; a stack needs head and base behind the same URL"
  fi
  case "$fetch_url" in
    *github.com*)
      RSP_PLATFORM="github"
      ;;
    *gitlab*)
      rsp_refuse 30 platform_gitlab_unsupported "remote '${remote}' (${fetch_url}) is a GitLab remote; this script supports GitHub only"
      ;;
    *)
      rsp_refuse 31 platform_unrecognized_host "remote '${remote}' (${fetch_url}) is not a recognised GitHub host"
      ;;
  esac
}

# ---------------------------------------------------------------------------------------------
# CUT: selection, attribution, units and order (Phase 2)
# ---------------------------------------------------------------------------------------------

SEL_TASKS=()
# TASK_PROOF and TASK_COMMITS are populated here for a later plan phase's ref-writing body
# (the overlay in decision PD6 needs the commit list) and are not yet read by this phase's own
# unit-building/ordering, which only needs TASK_END/TASK_PATHS/TASK_SHARED/TASK_SLUG/TASK_DEPS.
# shellcheck disable=SC2034
declare -A TASK_PROOF TASK_COMMITS TASK_END TASK_PATHS TASK_SHARED TASK_NOPROOF TASK_SLUG TASK_DEPS

# rsp_contains_task <n> -- exit 0 iff <n> is already in SEL_TASKS.
rsp_contains_task() {
  local needle="$1" x
  for x in "${SEL_TASKS[@]}"; do [ "$x" = "$needle" ] && return 0; done
  return 1
}

# rsp_milestone_task_ids <milestone_id> -- stdout: one task number per line (unique), the union
# of every batch's `task_ids` on the milestone, or nothing when the id is not found.
rsp_milestone_task_ids() {
  local mid="$1"
  jq -r --arg mid "$mid" '
    (.roadmap_milestones // [])[] | select((.id|tostring) == $mid) |
    [(.batches // [])[].task_ids[]?] | unique | .[]?
  ' "$STATE_FILE" 2>/dev/null
}

# rsp_batch_task_ids <session_id> -- stdout: one task number per line from the batch record's
# `task_numbers`, or nothing when the record is absent or unreadable.
rsp_batch_task_ids() {
  local session="$1" file
  file="$(batch_admission_record_path "$SPECS_DIR" "$session")"
  [ -f "$file" ] || return 0
  jq -r '(.task_numbers // [])[]?' "$file" 2>/dev/null
}

# rsp_gather_selection -- reads milestone_flag/batch_flag/tasks_flag and sets SEL_TASKS (sorted,
# unique, numeric) and, when unset, stack_id (defaulted from a milestone selection). Never
# refuses, even when no selection flag is given at all or the result is empty: the earlier
# resolution stages (integration branch, review base, remote, platform) must stay reachable
# exactly as before this flag existed, since Phase 1's suite exercises `cut --dry-run` with no
# selection at all. The 40/41/42 selection refusals are applied separately by
# rsp_validate_selection, after those earlier stages run.
rsp_gather_selection() {
  local -a raw=()
  if [ -n "$milestone_flag" ]; then
    mapfile -t raw < <(rsp_milestone_task_ids "$milestone_flag")
    [ -n "$stack_id" ] || stack_id="$milestone_flag"
  elif [ -n "$batch_flag" ]; then
    mapfile -t raw < <(rsp_batch_task_ids "$batch_flag")
  elif [ -n "$tasks_flag" ]; then
    IFS=',' read -ra raw <<< "$tasks_flag"
  fi
  mapfile -t SEL_TASKS < <(printf '%s\n' "${raw[@]}" | grep -E '^[0-9]+$' | LC_ALL=C sort -n -u)
}

# rsp_validate_selection -- refuses 40/41/42 when cut's selection is missing, needs a stack id it
# was not given, or resolved to zero valid task numbers. Called after review base, remote and
# platform are resolved, so those refusals stay reachable with no selection flag at all.
rsp_validate_selection() {
  if [ -z "$milestone_flag" ] && [ -z "$batch_flag" ] && [ -z "$tasks_flag" ]; then
    rsp_refuse 40 selection_missing "cut needs exactly one of --milestone ID, --batch SESSION, or --tasks N,N,..."
  fi
  if [ -z "$stack_id" ]; then
    rsp_refuse 41 stack_id_required "a --batch or --tasks selection needs --stack-id NAME (a --milestone selection defaults its stack id to the milestone id)"
  fi
  if [ "${#SEL_TASKS[@]}" -eq 0 ]; then
    rsp_refuse 42 selection_empty "the selection resolved to zero valid task numbers"
  fi
}

# rsp_proof_for_task <task_number> -- stdout: the newest landing proof (compact JSON) across
# every batch record listing the task, or nothing.
rsp_proof_for_task() {
  local task="$1" rec
  while IFS= read -r rec; do
    [ -n "$rec" ] && [ -f "$rec" ] || continue
    jq -c --argjson n "$task" \
      '[(.landing_proofs // [])[] | select(.task_number == $n)] | last // empty' \
      "$rec" 2>/dev/null || true
  done < <(batch_admission_record_for_task "$SPECS_DIR" "$task" all) | head -n 1
}

RSP_FB_OK=""
RSP_FB_COMMITS=""
RSP_FB_END=""
RSP_FB_PATHS=""

# rsp_fallback_attribution <task_number> <integration_branch> -- sets RSP_FB_OK/COMMITS/END/
# PATHS for a task with no landing proof: its non-merge "task N:"/"task N phase" commits on
# <integration_branch>, bounded below by the task's `created` time (the same convention
# milestone-review-handoff.sh's task_review_line uses). RSP_FB_OK stays "false" when the task has
# no `created` time or no matching commit.
rsp_fallback_attribution() {
  local task="$1" branch="$2" entry created created_epoch subject_re sha ct subj
  local -a own=() paths=() spec=(".") member
  RSP_FB_OK="false"
  RSP_FB_COMMITS=""
  RSP_FB_END=""
  RSP_FB_PATHS=""
  entry="$(task_lookup_entry "$task" "$STATE_FILE" 2>/dev/null || true)"
  created="$(printf '%s' "$entry" | jq -r '.created // empty' 2>/dev/null || true)"
  [ -n "$created" ] || return 0
  created_epoch="$(date -u -d "$created" +%s 2>/dev/null || true)"
  [ -n "$created_epoch" ] || return 0
  subject_re="^task ${task}(:| phase )"
  while read -r sha ct subj; do
    [ -n "$sha" ] || continue
    [[ "$subj" =~ $subject_re ]] || continue
    [ "$ct" -ge "$created_epoch" ] 2>/dev/null && own+=("$sha")
  done < <(git log --no-merges --reverse --format='%H %ct %s' -E --grep="$subject_re" "$branch" 2>/dev/null)
  [ "${#own[@]}" -gt 0 ] || return 0
  for member in "${BATCH_ADMISSION_STATE_TERRITORY[@]}"; do
    spec+=(":(exclude)${member}")
  done
  for sha in "${own[@]}"; do
    while IFS= read -r p; do
      [ -n "$p" ] && paths+=("$p")
    done < <(git diff-tree --no-commit-id --name-only -r "$sha" -- "${spec[@]}" 2>/dev/null)
  done
  RSP_FB_END="${own[-1]}"
  RSP_FB_COMMITS="$(printf '%s\n' "${own[@]}")"
  if [ "${#paths[@]}" -gt 0 ]; then
    RSP_FB_PATHS="$(printf '%s\n' "${paths[@]}" | LC_ALL=C sort -u)"
  fi
  RSP_FB_OK="true"
}

# rsp_attribute_task <task_number> <integration_branch> -- populates the TASK_* globals for the
# task from its landing proof, or from rsp_fallback_attribution; refuses (43) when neither
# yields an end commit.
rsp_attribute_task() {
  local t="$1" branch="$2" proof entry
  proof="$(rsp_proof_for_task "$t")"
  if [ -n "$proof" ]; then
    TASK_PROOF[$t]="$proof"
    TASK_COMMITS[$t]="$(printf '%s' "$proof" | jq -r '(.commits // [])[]?')"
    TASK_END[$t]="$(printf '%s' "$proof" | jq -r '.end_commit // empty')"
    TASK_PATHS[$t]="$(printf '%s' "$proof" | jq -r '(.paths // [])[]?' | LC_ALL=C sort -u)"
    TASK_SHARED[$t]="$(printf '%s' "$proof" | jq -r '(.shared_paths // [])[]?')"
    TASK_NOPROOF[$t]="false"
  else
    rsp_fallback_attribution "$t" "$branch"
    if [ "$RSP_FB_OK" != "true" ]; then
      rsp_refuse 43 task_unattributable "task ${t} has no landing proof and no attributable commit on '${branch}' bounded by its created time"
    fi
    # shellcheck disable=SC2034  # read by a later plan phase's ref-writing body, not this one
    TASK_PROOF[$t]=""
    # shellcheck disable=SC2034  # read by a later plan phase's ref-writing body, not this one
    TASK_COMMITS[$t]="$RSP_FB_COMMITS"
    TASK_END[$t]="$RSP_FB_END"
    TASK_PATHS[$t]="$RSP_FB_PATHS"
    TASK_SHARED[$t]=""
    TASK_NOPROOF[$t]="true"
  fi
  if [ -z "${TASK_END[$t]:-}" ]; then
    rsp_refuse 43 task_unattributable "task ${t}'s landing proof has no end_commit"
  fi
  entry="$(task_lookup_entry "$t" "$STATE_FILE" 2>/dev/null || true)"
  TASK_SLUG[$t]="$(printf '%s' "$entry" | jq -r '.project_name // empty' 2>/dev/null || true)"
  [ -n "${TASK_SLUG[$t]}" ] || TASK_SLUG[$t]="task-${t}"
  TASK_DEPS[$t]="$(printf '%s' "$entry" | jq -r '(.dependencies // [])[]?' 2>/dev/null || true)"
}

# rsp_detect_pulled_in <review_base_commit> <integration_branch> -- scans every batch record's
# landing proofs for a task not already in SEL_TASKS whose path set intersects the combined
# selected path set and whose end_commit is not yet an ancestor of <review_base_commit>; adds it
# to SEL_TASKS and attributes it. Repeats until nothing new is pulled in.
rsp_detect_pulled_in() {
  local base="$1" branch="$2" dir combined_file cand_file json t end hit added
  dir="${SPECS_DIR}/.orchestration/batch"
  [ -d "$dir" ] || return 0
  combined_file="$(mktemp)"
  for t in "${SEL_TASKS[@]}"; do printf '%s\n' "${TASK_PATHS[$t]}"; done \
    | grep -v '^$' | LC_ALL=C sort -u > "$combined_file"
  if [ ! -s "$combined_file" ]; then
    rm -f "$combined_file"
    return 0
  fi
  added="true"
  while [ "$added" = "true" ]; do
    added="false"
    while IFS= read -r json; do
      [ -n "$json" ] || continue
      t="$(printf '%s' "$json" | jq -r '.task_number // empty' 2>/dev/null || true)"
      case "$t" in '' | *[!0-9]*) continue ;; esac
      rsp_contains_task "$t" && continue
      end="$(printf '%s' "$json" | jq -r '.end_commit // empty' 2>/dev/null || true)"
      [ -n "$end" ] || continue
      if git merge-base --is-ancestor "$end" "$base" 2>/dev/null; then
        continue
      fi
      cand_file="$(mktemp)"
      printf '%s' "$json" | jq -r '(.paths // [])[]?' 2>/dev/null | LC_ALL=C sort -u > "$cand_file"
      hit="$(comm -12 "$combined_file" "$cand_file" 2>/dev/null | head -n 1)"
      rm -f "$cand_file"
      [ -n "$hit" ] || continue
      SEL_TASKS+=("$t")
      rsp_attribute_task "$t" "$branch"
      printf '%s\n' "${TASK_PATHS[$t]}" >> "$combined_file"
      LC_ALL=C sort -u -o "$combined_file" "$combined_file"
      echo "NOTE: review-stack-prepare.sh: pulled in task ${t} (shares path '${hit}' with the selection and its end commit is not yet an ancestor of the review base)" >&2
      added="true"
    done < <(
      local f
      for f in "$dir"/*.json; do
        [ -f "$f" ] || continue
        jq -c '(.landing_proofs // [])[]?' "$f" 2>/dev/null
      done
    )
  done
  mapfile -t SEL_TASKS < <(printf '%s\n' "${SEL_TASKS[@]}" | LC_ALL=C sort -n -u)
  rm -f "$combined_file"
}

# --- union-find over task numbers, for shared_paths/--merge grouping into units -------------
declare -A UF_PARENT
uf_find() {
  local x="$1"
  [ -n "${UF_PARENT[$x]:-}" ] || UF_PARENT[$x]="$x"
  if [ "${UF_PARENT[$x]}" != "$x" ]; then
    UF_PARENT[$x]="$(uf_find "${UF_PARENT[$x]}")"
  fi
  printf '%s' "${UF_PARENT[$x]}"
}
uf_union() {
  local ra rb
  ra="$(uf_find "$1")"
  rb="$(uf_find "$2")"
  [ "$ra" = "$rb" ] && return 0
  UF_PARENT[$ra]="$rb"
}

# _rsp_shared_hits_other <owner> <other> -- exit 0 iff <owner>'s proof shared_paths names a path
# that is in <other>'s path set.
_rsp_shared_hits_other() {
  local owner="$1" other="$2" p
  [ -n "${TASK_SHARED[$owner]:-}" ] || return 1
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    printf '%s\n' "${TASK_PATHS[$other]}" | grep -qxF "$p" && return 0
  done <<< "${TASK_SHARED[$owner]}"
  return 1
}

MERGE_PAIRS=()

# rsp_build_task_merges -- unions SEL_TASKS pairs per PD3 (shared_paths naming the other's
# files, or an explicit --merge pair). Refuses (47) when a --merge pair names a task outside the
# selection.
rsp_build_task_merges() {
  local a b i j pair pa pb
  for a in "${SEL_TASKS[@]}"; do uf_find "$a" >/dev/null; done
  for i in "${!SEL_TASKS[@]}"; do
    a="${SEL_TASKS[$i]}"
    for j in "${!SEL_TASKS[@]}"; do
      [ "$j" -le "$i" ] && continue
      b="${SEL_TASKS[$j]}"
      if _rsp_shared_hits_other "$a" "$b" || _rsp_shared_hits_other "$b" "$a"; then
        uf_union "$a" "$b"
      fi
    done
  done
  for pair in "${MERGE_PAIRS[@]}"; do
    pa="${pair%%+*}"
    pb="${pair#*+}"
    if ! rsp_contains_task "$pa" || ! rsp_contains_task "$pb"; then
      rsp_refuse 47 merge_flag_invalid "--merge ${pair} names a task that is not in the selection"
    fi
    uf_union "$pa" "$pb"
  done
}

UNIT_ROOTS=()
declare -A UNIT_TASKS UNIT_PATHS UNIT_END UNIT_NOPROOF UNIT_SLUG

# rsp_build_units -- groups SEL_TASKS by union-find root into UNIT_* arrays: members (ascending,
# space-separated), combined path set, the member end commit every other member's end commit is
# an ancestor of, the no-proof flag, and the branch slug (the lowest member's).
rsp_build_units() {
  local t root u combined m end candidate np m2
  for t in "${SEL_TASKS[@]}"; do
    root="$(uf_find "$t")"
    if [ -z "${UNIT_TASKS[$root]:-}" ]; then
      UNIT_ROOTS+=("$root")
    fi
    UNIT_TASKS[$root]="${UNIT_TASKS[$root]:-}${UNIT_TASKS[$root]:+ }${t}"
  done
  for u in "${UNIT_ROOTS[@]}"; do
    local -a members=()
    mapfile -t members < <(printf '%s\n' ${UNIT_TASKS[$u]} | LC_ALL=C sort -n)
    UNIT_TASKS[$u]="${members[*]}"
    combined=""
    for m in "${members[@]}"; do
      combined="${combined}${TASK_PATHS[$m]}"$'\n'
    done
    UNIT_PATHS[$u]="$(printf '%s' "$combined" | grep -v '^$' | LC_ALL=C sort -u)"
    end="${TASK_END[${members[0]}]}"
    for m in "${members[@]:1}"; do
      candidate="${TASK_END[$m]}"
      if git merge-base --is-ancestor "$end" "$candidate" 2>/dev/null; then
        end="$candidate"
      fi
    done
    UNIT_END[$u]="$end"
    np="false"
    for m2 in "${members[@]}"; do [ "${TASK_NOPROOF[$m2]}" = "true" ] && np="true"; done
    UNIT_NOPROOF[$u]="$np"
    UNIT_SLUG[$u]="${TASK_SLUG[${members[0]}]}"
  done
}

# rsp_unit_of_task <task_number> -- stdout: the unit root the task belongs to.
rsp_unit_of_task() {
  uf_find "$1"
}

# _rsp_unit_paths_overlap <unit_a> <unit_b> -- exit 0 iff the two units' combined path sets
# intersect.
_rsp_unit_paths_overlap() {
  local a="$1" b="$2" fa fb hit
  fa="$(mktemp)"
  fb="$(mktemp)"
  printf '%s\n' "${UNIT_PATHS[$a]}" > "$fa"
  printf '%s\n' "${UNIT_PATHS[$b]}" > "$fb"
  hit="$(comm -12 "$fa" "$fb" 2>/dev/null | grep -v '^$' | head -n 1)"
  rm -f "$fa" "$fb"
  [ -n "$hit" ]
}

declare -A UNIT_BASE_OF COMP_PARENT

comp_find() {
  local x="$1"
  [ -n "${COMP_PARENT[$x]:-}" ] || COMP_PARENT[$x]="$x"
  if [ "${COMP_PARENT[$x]}" != "$x" ]; then
    COMP_PARENT[$x]="$(comp_find "${COMP_PARENT[$x]}")"
  fi
  printf '%s' "${COMP_PARENT[$x]}"
}
comp_union() {
  local ra rb
  ra="$(comp_find "$1")"
  rb="$(comp_find "$2")"
  [ "$ra" = "$rb" ] && return 0
  COMP_PARENT[$ra]="$rb"
}

# rsp_build_dependency_edges_and_components -- for every selected task's `dependencies` that
# names another selected task in a different unit, records a base-of edge (UNIT_BASE_OF[dependent]
# gains the base unit) and connects the two units into one component. Then connects every
# remaining pair of units with overlapping paths into one component too (PD5: components are
# dependency edges UNION path overlap).
rsp_build_dependency_edges_and_components() {
  local u t dep dep_unit i j a b
  for u in "${UNIT_ROOTS[@]}"; do comp_find "$u" >/dev/null; done
  for u in "${UNIT_ROOTS[@]}"; do
    for t in ${UNIT_TASKS[$u]}; do
      for dep in ${TASK_DEPS[$t]:-}; do
        rsp_contains_task "$dep" || continue
        dep_unit="$(rsp_unit_of_task "$dep")"
        [ "$dep_unit" = "$u" ] && continue
        case " ${UNIT_BASE_OF[$u]:-} " in
          *" ${dep_unit} "*) ;;
          *) UNIT_BASE_OF[$u]="${UNIT_BASE_OF[$u]:-}${UNIT_BASE_OF[$u]:+ }${dep_unit}" ;;
        esac
        comp_union "$u" "$dep_unit"
      done
    done
  done
  for i in "${!UNIT_ROOTS[@]}"; do
    a="${UNIT_ROOTS[$i]}"
    for j in "${!UNIT_ROOTS[@]}"; do
      [ "$j" -le "$i" ] && continue
      b="${UNIT_ROOTS[$j]}"
      if _rsp_unit_paths_overlap "$a" "$b"; then
        comp_union "$a" "$b"
      fi
    done
  done
}

# rsp_check_order_contradictions -- refuses (45) when a dependency edge's two units overlap in
# path and the base unit's end commit is not an ancestor of the dependent unit's end commit (the
# dependency wants the base below, but it did not land first).
rsp_check_order_contradictions() {
  local u base
  for u in "${UNIT_ROOTS[@]}"; do
    for base in ${UNIT_BASE_OF[$u]:-}; do
      if _rsp_unit_paths_overlap "$u" "$base"; then
        if ! git merge-base --is-ancestor "${UNIT_END[$base]}" "${UNIT_END[$u]}" 2>/dev/null; then
          rsp_refuse 45 order_contradiction "task(s) ${UNIT_TASKS[$base]} and task(s) ${UNIT_TASKS[$u]} share a path, and their dependency order disagrees with their landed commit order; pass --merge to combine them into one unit, or --order to state the stack order yourself"
        fi
      fi
    done
  done
}

# rsp_topo_sort_component <members...> -- stdout: the member unit roots in dependency order
# (base before dependent), ties among units with no dependency edge between them broken by
# end-commit ancestry (the ancestor first), then by lowest member task number. Refuses (44) on a
# cycle.
rsp_topo_sort_component() {
  local -a members=("$@")
  local -A indeg=() dependents=()
  local u b pu pick pick_first pu_first
  local -a ready=() order=()
  for u in "${members[@]}"; do
    indeg[$u]=0
    dependents[$u]=""
  done
  for u in "${members[@]}"; do
    for b in ${UNIT_BASE_OF[$u]:-}; do
      case " ${members[*]} " in *" ${b} "*) ;; *) continue ;; esac
      dependents[$b]="${dependents[$b]:-}${dependents[$b]:+ }${u}"
      indeg[$u]=$(( indeg[$u] + 1 ))
    done
  done
  for u in "${members[@]}"; do [ "${indeg[$u]}" -eq 0 ] && ready+=("$u"); done
  while [ "${#ready[@]}" -gt 0 ]; do
    pick=""
    for pu in "${ready[@]}"; do
      if [ -z "$pick" ]; then
        pick="$pu"
        continue
      fi
      if git merge-base --is-ancestor "${UNIT_END[$pu]}" "${UNIT_END[$pick]}" 2>/dev/null; then
        pick="$pu"
      elif ! git merge-base --is-ancestor "${UNIT_END[$pick]}" "${UNIT_END[$pu]}" 2>/dev/null; then
        pick_first="${UNIT_TASKS[$pick]%% *}"
        pu_first="${UNIT_TASKS[$pu]%% *}"
        [ "$pu_first" -lt "$pick_first" ] && pick="$pu"
      fi
    done
    order+=("$pick")
    local -a newready=()
    for pu in "${ready[@]}"; do [ "$pu" != "$pick" ] && newready+=("$pu"); done
    ready=("${newready[@]}")
    for u in ${dependents[$pick]:-}; do
      indeg[$u]=$(( indeg[$u] - 1 ))
      [ "${indeg[$u]}" -eq 0 ] && ready+=("$u")
    done
  done
  if [ "${#order[@]}" -ne "${#members[@]}" ]; then
    rsp_refuse 44 order_cycle "the dependency edges among unit(s) with task(s) $(printf '%s/' "${members[@]}" | sed 's#/$##') form a cycle; break it with --merge, or correct the dependency edges"
  fi
  printf '%s\n' "${order[@]}"
}

ORDER_FLAG=""

# rsp_apply_order_override -- parses ORDER_FLAG (comma-separated task numbers) into a stdout
# list of unit roots, one per line, covering every UNIT_ROOTS entry exactly once. Refuses (46)
# on an unknown number or a count mismatch.
rsp_apply_order_override() {
  local -a nums=() seen_roots=() out=()
  local n root u found
  IFS=',' read -ra nums <<< "$ORDER_FLAG"
  for n in "${nums[@]}"; do
    rsp_contains_task "$n" || rsp_refuse 46 order_flag_invalid "--order names task ${n}, which is not in the selection"
    root="$(rsp_unit_of_task "$n")"
    found="false"
    for u in "${seen_roots[@]:-}"; do [ "$u" = "$root" ] && found="true"; done
    [ "$found" = "true" ] && continue
    seen_roots+=("$root")
    out+=("$root")
  done
  if [ "${#out[@]}" -ne "${#UNIT_ROOTS[@]}" ]; then
    rsp_refuse 46 order_flag_invalid "--order names ${#out[@]} unit(s) but the selection built ${#UNIT_ROOTS[@]}; name every unit exactly once"
  fi
  printf '%s\n' "${out[@]}"
}

# PLAN_* are parallel arrays, one entry per final unit, in final stack order, filled by
# rsp_cut_plan and consumed by both rsp_cut_print (dry-run and real alike) and rsp_cut_execute
# (real only). Kept as module-level globals, like SEL_TASKS/UNIT_* above, rather than threaded
# through return values, matching this script's existing convention for this phase's state.
PLAN_NN=()
PLAN_UNIT=()
PLAN_BRANCH=()
PLAN_BASE=()
PLAN_BASE_IS_REVIEW=()

# rsp_cut_plan <integration_branch> -- resolves the selection, attributes every task, pulls in
# any unmerged path-overlapping task, builds units, orders them, and fills PLAN_* with each
# final unit's ordinal, branch and base. Writes no ref, no manifest and no file.
rsp_cut_plan() {
  local branch="$1"
  rsp_validate_selection
  local t
  for t in "${SEL_TASKS[@]}"; do
    rsp_attribute_task "$t" "$branch"
  done
  rsp_detect_pulled_in "$review_base" "$branch"
  rsp_build_task_merges
  rsp_build_units
  rsp_build_dependency_edges_and_components
  rsp_check_order_contradictions

  local -a final_units=()
  if [ -n "$ORDER_FLAG" ]; then
    mapfile -t final_units < <(rsp_apply_order_override)
    declare -A COMPONENT_MEMBERS=([ALL]="${final_units[*]}")
    local -a comp_order=(ALL)
  else
    declare -A COMPONENT_MEMBERS=()
    local -a comp_order=()
    local u c
    for u in "${UNIT_ROOTS[@]}"; do
      c="$(comp_find "$u")"
      if [ -z "${COMPONENT_MEMBERS[$c]:-}" ]; then
        comp_order+=("$c")
      fi
      COMPONENT_MEMBERS[$c]="${COMPONENT_MEMBERS[$c]:-}${COMPONENT_MEMBERS[$c]:+ }${u}"
    done
    mapfile -t comp_order < <(
      local cc first
      for cc in "${comp_order[@]}"; do
        first="$(printf '%s\n' ${COMPONENT_MEMBERS[$cc]} | while read -r uu; do printf '%s\n' ${UNIT_TASKS[$uu]}; done | LC_ALL=C sort -n | head -n1)"
        printf '%s %s\n' "$first" "$cc"
      done | LC_ALL=C sort -n -k1,1 | awk '{print $2}'
    )
  fi

  local nn=0 comp prev_branch u out_branch out_base nn_padded members sorted
  for comp in "${comp_order[@]}"; do
    read -ra members <<< "${COMPONENT_MEMBERS[$comp]}"
    if [ -n "$ORDER_FLAG" ]; then
      sorted=("${members[@]}")
    else
      mapfile -t sorted < <(rsp_topo_sort_component "${members[@]}")
    fi
    prev_branch=""
    for u in "${sorted[@]}"; do
      nn=$((nn + 1))
      nn_padded="$(printf '%02d' "$nn")"
      out_branch="${prefix}/${stack_id}/${nn_padded}-${UNIT_SLUG[$u]}"
      if [ -z "$prev_branch" ]; then
        out_base="$review_base"
        PLAN_BASE_IS_REVIEW+=("true")
      else
        out_base="$prev_branch"
        PLAN_BASE_IS_REVIEW+=("false")
      fi
      PLAN_NN+=("$nn_padded")
      PLAN_UNIT+=("$u")
      PLAN_BRANCH+=("$out_branch")
      PLAN_BASE+=("$out_base")
      prev_branch="$out_branch"
    done
  done
}

# rsp_cut_print -- prints the "UNIT NN: ..." lines from PLAN_*/UNIT_*, identically whether or
# not this invocation goes on to execute (rsp_cut_execute). This is the one print surface both
# --dry-run and a real cut share, so a suite assertion written against either reads the same
# format.
rsp_cut_print() {
  local i n u note
  n="${#PLAN_NN[@]}"
  for ((i = 0; i < n; i++)); do
    u="${PLAN_UNIT[$i]}"
    note=""
    [ "${UNIT_NOPROOF[$u]}" = "true" ] && note="${note} no_proof=true"
    printf 'UNIT %s: tasks=%s branch=%s base=%s end=%s%s\n' \
      "${PLAN_NN[$i]}" "$(echo ${UNIT_TASKS[$u]} | tr ' ' ',')" "${PLAN_BRANCH[$i]}" "${PLAN_BASE[$i]}" "${UNIT_END[$u]:0:12}" "$note"
  done
  echo "NOTE: review-stack-prepare.sh: resolved ${n} unit(s) for stack '${stack_id}' (remote='${remote}' platform='${platform}' review_base='${review_base}')." >&2
}

# rsp_overlay_tree <base_tree> <end_commit> <paths_newline> -- stdout: the sha of a new tree
# object equal to <base_tree> with each path in <paths_newline> set to its blob (mode+oid) at
# <end_commit>, or removed when absent there. Builds the tree in a private temporary index
# (GIT_INDEX_FILE); never touches the shared working tree, the shared index, or HEAD.
rsp_overlay_tree() {
  local base_tree="$1" end_commit="$2" paths="$3" tmp_index p line mode sha tree
  tmp_index="$(mktemp)"
  rm -f "$tmp_index"
  GIT_INDEX_FILE="$tmp_index" git read-tree "$base_tree" || { rm -f "$tmp_index"; return 1; }
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    line="$(git ls-tree "$end_commit" -- "$p" 2>/dev/null)"
    if [ -z "$line" ]; then
      GIT_INDEX_FILE="$tmp_index" git update-index --force-remove -- "$p" >/dev/null 2>&1 || true
    else
      mode="$(printf '%s' "$line" | awk '{print $1}')"
      sha="$(printf '%s' "$line" | awk '{print $3}')"
      GIT_INDEX_FILE="$tmp_index" git update-index --add --cacheinfo "${mode},${sha},${p}" || {
        rm -f "$tmp_index"
        return 1
      }
    fi
  done <<< "$paths"
  tree="$(GIT_INDEX_FILE="$tmp_index" git write-tree)"
  rm -f "$tmp_index"
  printf '%s' "$tree"
}

# rsp_move_commit_onto_new_parent <old_parent> <new_parent> <commit> -- stdout: the sha of the
# tree <commit> would have if its base were moved from <old_parent> to <new_parent>, via the
# three-way `git merge-tree --write-tree --merge-base=<old_parent> <new_parent> <commit>`. The
# one primitive PD6 names for both the first cut (moving the bottom unit's overlay onto the
# review base's actual tip) and every later restack. A conflict refuses (48) and names the
# path(s); never falls back to a forced write.
rsp_move_commit_onto_new_parent() {
  local old_parent="$1" new_parent="$2" commit="$3" out rc names
  out="$(git merge-tree --write-tree --merge-base="$old_parent" "$new_parent" "$commit" 2>/dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    names="$(git merge-tree --write-tree --name-only --merge-base="$old_parent" "$new_parent" "$commit" 2>/dev/null \
      | awk 'NR==1{next} /^$/{exit} {print}' | tr '\n' ',' | sed 's/,$//')"
    rsp_refuse 48 ref_conflict "moving a unit's commit from parent ${old_parent:0:12} onto ${new_parent:0:12} conflicted on path(s): ${names:-<unknown>}"
  fi
  printf '%s\n' "$out" | head -n 1
}

# rsp_unit_title <unit_root> <integration_branch> -- stdout: the subject of the lowest member
# task's "task N: complete implementation" commit on <integration_branch> if one exists, else
# the subject of the lowest member's attributed end commit, with the "task N" prefix stripped
# either way. Used as both the review commit's message and the PR title.
rsp_unit_title() {
  local u="$1" branch="$2" lowest subj
  lowest="${UNIT_TASKS[$u]%% *}"
  subj="$(git log -1 --format=%s -E --grep="^task ${lowest}: complete implementation" "$branch" 2>/dev/null || true)"
  if [ -z "$subj" ]; then
    subj="$(git log -1 --format=%s "${TASK_END[$lowest]}" 2>/dev/null || true)"
  fi
  [ -n "$subj" ] || subj="task ${lowest}"
  printf '%s' "$subj" | sed -E 's/^task [0-9]+:? ?//'
}

# rsp_write_body <path> <title> <tasks_csv> <parent_branch> <child_branch> <paths_newline>
#     <noproof> <colanded> -- writes one PR body file: Summary, Relationship to other PRs
#     (parent and, when one exists in this same cut, child), Changed files, and the
#     attributed-without-a-proof / co-landed-lines notices where they apply.
rsp_write_body() {
  local path="$1" title="$2" tasks_csv="$3" parent="$4" child="$5" paths="$6" noproof="$7" colanded="$8"
  {
    printf '# %s\n\n' "$title"
    echo "## Summary"
    echo ""
    echo "Task(s) ${tasks_csv}, prepared by review-stack-prepare.sh for stack '${stack_id}'."
    echo ""
    echo "## Relationship to other PRs"
    echo ""
    printf -- '- Parent: `%s`\n' "$parent"
    if [ -n "$child" ]; then
      printf -- '- Child: `%s`\n' "$child"
    else
      echo "- Child: none (top of this component)"
    fi
    echo ""
    echo "## Changed files"
    echo ""
    printf '%s\n' "$paths" | sed -E 's/^(.+)$/- `\1`/'
    if [ "$noproof" = "true" ]; then
      echo ""
      echo 'ATTRIBUTED WITHOUT A PROOF: this unit was attributed by the "task N:" commit-subject'
      echo "convention, not a recorded landing proof."
    fi
    if [ "$colanded" = "true" ]; then
      echo ""
      echo "CO-LANDED LINES: these tasks are reviewed together as one unit because their work"
      echo "shares one or more files (or was explicitly merged) and cannot be separated by path."
    fi
  } > "$path"
}

# rsp_manifest_field <manifest_json> <branch> <field> -- stdout: <field> of the entry whose
# branch equals <branch> in <manifest_json> (a prior on-disk manifest, or empty), or nothing.
rsp_manifest_field() {
  local json="$1" branch="$2" field="$3"
  [ -n "$json" ] || return 0
  printf '%s' "$json" | jq -r --arg b "$branch" --arg f "$field" \
    '(.entries // [])[] | select(.branch == $b) | .[$f] // empty' 2>/dev/null | head -n 1
}

# rsp_cut_execute <integration_branch> -- the real (non-dry-run) body of `cut`: builds each
# planned unit's review commit by plumbing alone, moves its branch by compare-and-swap, writes
# its PR body file, and writes the stack's manifest. Reads any prior on-disk manifest for this
# stack id first, so an unchanged entry keeps its recorded `request`/`state` across a re-cut.
rsp_cut_execute() {
  local branch="$1"
  local reviews_dir manifest_path old_manifest_json review_merge_base
  local i n u out_branch out_base is_bottom anchor_commit parent_commit anchor_tree
  local overlay_tree pre_move_commit final_tree final_commit old_ref existing_sha existing_tree existing_parent
  local remote_tracking remote_sha known_sha title body_path child_branch old_commit old_request old_state
  local -a manifest_entries=()

  reviews_dir="${SPECS_DIR}/.orchestration/reviews/${stack_id}"
  manifest_path="${reviews_dir}/manifest.json"
  old_manifest_json=""
  [ -f "$manifest_path" ] && old_manifest_json="$(cat "$manifest_path" 2>/dev/null || true)"
  mkdir -p "$reviews_dir"

  review_merge_base="$(git merge-base "$review_base" "$branch" 2>/dev/null || true)"
  [ -n "$review_merge_base" ] || review_merge_base="$review_base"

  n="${#PLAN_NN[@]}"
  for ((i = 0; i < n; i++)); do
    u="${PLAN_UNIT[$i]}"
    out_branch="${PLAN_BRANCH[$i]}"
    out_base="${PLAN_BASE[$i]}"
    is_bottom="${PLAN_BASE_IS_REVIEW[$i]}"

    if [ "$is_bottom" = "true" ]; then
      anchor_commit="$review_merge_base"
      parent_commit="$(git rev-parse "$review_base")"
    else
      parent_commit="$(git rev-parse "refs/heads/${out_base}")"
      anchor_commit="$parent_commit"
    fi
    anchor_tree="$(git rev-parse "${anchor_commit}^{tree}")"
    overlay_tree="$(rsp_overlay_tree "$anchor_tree" "${UNIT_END[$u]}" "${UNIT_PATHS[$u]}")"

    if [ "$anchor_commit" = "$parent_commit" ]; then
      final_tree="$overlay_tree"
    else
      pre_move_commit="$(git commit-tree "$overlay_tree" -p "$anchor_commit" <<< "review-stack-prepare.sh: overlay before move")"
      final_tree="$(rsp_move_commit_onto_new_parent "$anchor_commit" "$parent_commit" "$pre_move_commit")"
    fi

    title="$(rsp_unit_title "$u" "$branch")"

    old_ref="refs/heads/${out_branch}"
    existing_sha="$(git rev-parse -q --verify "$old_ref" 2>/dev/null || true)"
    final_commit=""
    if [ -n "$existing_sha" ]; then
      existing_tree="$(git rev-parse "${existing_sha}^{tree}" 2>/dev/null || true)"
      existing_parent="$(git rev-parse -q --verify "${existing_sha}^1" 2>/dev/null || true)"
      if [ "$existing_tree" = "$final_tree" ] && [ "$existing_parent" = "$parent_commit" ]; then
        final_commit="$existing_sha"
      fi
    fi

    remote_tracking="refs/remotes/${remote}/${out_branch}"
    remote_sha="$(git rev-parse -q --verify "$remote_tracking" 2>/dev/null || true)"
    if [ -n "$remote_sha" ]; then
      known_sha="$(rsp_manifest_field "$old_manifest_json" "$out_branch" "commit")"
      if [ "$remote_sha" != "$known_sha" ] && [ "$remote_sha" != "$final_commit" ] && [ "$remote_sha" != "$existing_sha" ]; then
        rsp_refuse 49 unknown_remote_commit "the remote-tracking ref '${remote_tracking}' holds commit ${remote_sha:0:12}, which stack '${stack_id}'s manifest does not record for branch '${out_branch}'; fetch and reconcile, or start a new stack id"
      fi
    fi

    if [ -z "$final_commit" ]; then
      final_commit="$(git commit-tree "$final_tree" -p "$parent_commit" <<< "$title")"
      if ! git update-ref "$old_ref" "$final_commit" "$existing_sha"; then
        rsp_refuse 48 ref_conflict "could not move ref '${old_ref}' to ${final_commit:0:12} by compare-and-swap against '${existing_sha:-<absent>}'; it moved concurrently -- re-run cut"
      fi
    fi

    old_commit="$(rsp_manifest_field "$old_manifest_json" "$out_branch" "commit")"
    old_request=""
    old_state="prepared"
    if [ -n "$old_commit" ] && [ "$old_commit" = "$final_commit" ]; then
      old_request="$(rsp_manifest_field "$old_manifest_json" "$out_branch" "request")"
      old_state="$(rsp_manifest_field "$old_manifest_json" "$out_branch" "state")"
      [ -n "$old_state" ] || old_state="prepared"
    fi

    child_branch=""
    if [ $((i + 1)) -lt "$n" ] && [ "${PLAN_BASE[$((i + 1))]}" = "$out_branch" ]; then
      child_branch="${PLAN_BRANCH[$((i + 1))]}"
    fi
    body_path="${reviews_dir}/${PLAN_NN[$i]}-body.md"
    rsp_write_body "$body_path" "$title" "${UNIT_TASKS[$u]// /, }" "$out_base" "$child_branch" "${UNIT_PATHS[$u]}" \
      "${UNIT_NOPROOF[$u]}" "$([ "$(echo ${UNIT_TASKS[$u]} | wc -w)" -gt 1 ] && echo true || echo false)"

    manifest_entries+=("$(jq -n \
      --argjson ordinal "$((i + 1))" \
      --argjson tasks "$(printf '%s\n' ${UNIT_TASKS[$u]} | jq -R 'tonumber' | jq -s -c '.')" \
      --arg branch "$out_branch" --arg base "$out_base" --arg commit "$final_commit" \
      --arg parent "$parent_commit" --arg title "$title" --arg body_path "$body_path" \
      --arg state "$old_state" --arg request "$old_request" \
      '{ordinal: $ordinal, tasks: $tasks, branch: $branch, base: $base, commit: $commit, parent_commit: $parent, title: $title, body_path: $body_path, state: $state, request: $request}')")
  done

  printf '%s\n' "${manifest_entries[@]}" | jq -s \
    --arg stack_id "$stack_id" --arg remote "$remote" --arg integration_branch "$branch" --arg review_base "$review_base" \
    '{stack_id: $stack_id, remote: $remote, integration_branch: $integration_branch, review_base: $review_base, entries: .}' \
    > "$manifest_path"
  echo "NOTE: review-stack-prepare.sh: wrote ${n} review commit(s) and ${manifest_path} for stack '${stack_id}'." >&2
}

# rsp_show_stack <json_flag> -- reads stack_id's manifest and either emits it verbatim
# (<json_flag>=true) or prints, per entry in order: branch, base, title, body path, then the
# literal /please push command; after the last entry, the literal /merge --stack command and
# one line stating the typed-grant count. Refuses (50) when the manifest does not exist.
rsp_show_stack() {
  local json_flag="$1" manifest_path n i branch base title body_path
  manifest_path="${SPECS_DIR}/.orchestration/reviews/${stack_id}/manifest.json"
  if [ ! -f "$manifest_path" ]; then
    rsp_refuse 50 manifest_missing "no manifest exists for stack '${stack_id}' at ${manifest_path}; run 'cut' first"
  fi
  if [ "$json_flag" = "true" ]; then
    cat "$manifest_path"
    return 0
  fi
  n="$(jq '(.entries // []) | length' "$manifest_path")"
  for ((i = 0; i < n; i++)); do
    branch="$(jq -r ".entries[$i].branch" "$manifest_path")"
    base="$(jq -r ".entries[$i].base" "$manifest_path")"
    title="$(jq -r ".entries[$i].title" "$manifest_path")"
    body_path="$(jq -r ".entries[$i].body_path" "$manifest_path")"
    printf 'PR %s: branch=%s base=%s title=%s body_path=%s\n' "$((i + 1))" "$branch" "$base" "$title" "$body_path"
    printf '  /please push %s %s\n' "$remote" "$branch"
  done
  printf '/merge --stack %s\n' "$stack_id"
  echo "NOTE: review-stack-prepare.sh: ${n} entrie(s) in stack '${stack_id}' need ${n} typed /please push grant(s) plus this one /merge; this script runs none of them." >&2
}

# rsp_record_request <ordinal> <url> -- fills entry <ordinal>'s `request` field in stack_id's
# manifest with <url>. Refuses on bad args (51), a missing manifest (50), or an unknown
# ordinal (52). A --dry-run invocation reports what it would do and writes nothing.
rsp_record_request() {
  local ordinal="$1" url="$2" manifest_path tmp
  if [ -z "$ordinal" ] || [ -z "$url" ] || ! [[ "$ordinal" =~ ^[0-9]+$ ]]; then
    rsp_refuse 51 record_request_args_invalid "record-request needs an ordinal and a URL, e.g. 'record-request 1 https://...'"
  fi
  manifest_path="${SPECS_DIR}/.orchestration/reviews/${stack_id}/manifest.json"
  if [ ! -f "$manifest_path" ]; then
    rsp_refuse 50 manifest_missing "no manifest exists for stack '${stack_id}' at ${manifest_path}; run 'cut' first"
  fi
  if ! jq -e --argjson n "$ordinal" '(.entries // [])[] | select(.ordinal == $n)' "$manifest_path" >/dev/null 2>&1; then
    rsp_refuse 52 record_request_entry_not_found "stack '${stack_id}' has no entry ${ordinal}"
  fi
  if [ "$dry_run" = "true" ]; then
    echo "NOTE: review-stack-prepare.sh: [dry-run] would record request '${url}' for stack '${stack_id}' entry ${ordinal}." >&2
    return 0
  fi
  tmp="$(mktemp)"
  jq --argjson n "$ordinal" --arg url "$url" \
    '(.entries[] | select(.ordinal == $n) | .request) = $url' \
    "$manifest_path" > "$tmp" && mv "$tmp" "$manifest_path"
  echo "NOTE: review-stack-prepare.sh: recorded request for stack '${stack_id}' entry ${ordinal}." >&2
}

[ "$#" -ge 1 ] || rsp_usage
subcommand="$1"
shift
case "$subcommand" in
  cut | restack | show | record-request) ;;
  *) rsp_usage ;;
esac

dry_run="false"
review_base_flag_set="false"
review_base_flag_value=""
remote_flag=""
stack_id=""
milestone_flag=""
batch_flag=""
tasks_flag=""
prefix="review"
ORDER_FLAG=""
json_flag="false"
rest_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run="true"
      shift
      ;;
    --json)
      json_flag="true"
      shift
      ;;
    --review-base)
      review_base_flag_set="true"
      review_base_flag_value="${2:-}"
      shift 2
      ;;
    --remote)
      remote_flag="${2:-}"
      shift 2
      ;;
    --stack-id)
      stack_id="${2:-}"
      shift 2
      ;;
    --milestone)
      milestone_flag="${2:-}"
      shift 2
      ;;
    --batch)
      batch_flag="${2:-}"
      shift 2
      ;;
    --tasks)
      tasks_flag="${2:-}"
      shift 2
      ;;
    --merge)
      MERGE_PAIRS+=("${2:-}")
      shift 2
      ;;
    --order)
      ORDER_FLAG="${2:-}"
      shift 2
      ;;
    --prefix)
      prefix="${2:-}"
      shift 2
      ;;
    *)
      rest_args+=("$1")
      shift
      ;;
  esac
done

if [ "$subcommand" = "cut" ]; then
  # Gathered (never refusing) before the integration branch, so the branch's "newest batch
  # record naming one of the selected tasks" step (see the RESOLUTION header) has tasks to look
  # up when a selection was given; an absent selection leaves SEL_TASKS empty and changes
  # nothing else about this resolution chain.
  rsp_gather_selection
  rsp_resolve_integration_branch "${SEL_TASKS[@]}"
else
  rsp_resolve_integration_branch
fi
integration_branch="$RSP_INTEGRATION_BRANCH"
rsp_resolve_review_base "$review_base_flag_set" "$review_base_flag_value" "$integration_branch"
review_base="$RSP_REVIEW_BASE"
rsp_resolve_remote "$remote_flag" "$integration_branch"
remote="$RSP_REMOTE"
rsp_detect_platform "$remote"
platform="$RSP_PLATFORM"

if [ "$subcommand" = "cut" ]; then
  rsp_cut_plan "$integration_branch"
  rsp_cut_print
  [ "$dry_run" = "true" ] || rsp_cut_execute "$integration_branch"
elif [ "$subcommand" = "show" ] && [ -n "$stack_id" ]; then
  rsp_show_stack "$json_flag"
elif [ "$subcommand" = "record-request" ] && [ -n "$stack_id" ]; then
  rsp_record_request "${rest_args[0]:-}" "${rest_args[1]:-}"
else
  # restack's recompute is filled by a later plan phase; show/record-request with no --stack-id
  # fall through here unchanged, so the review_base/remote/platform resolver assertions written
  # against them stay reachable. This phase stops here, having resolved every input and refused
  # on any input that cannot be resolved; it writes no ref, no manifest and no file.
  echo "NOTE: review-stack-prepare.sh: resolved integration_branch='${integration_branch}' review_base='${review_base}' remote='${remote}' platform='${platform}' for subcommand '${subcommand}' (stack_id='${stack_id}', dry_run=${dry_run}); subcommand body not yet implemented, nothing written." >&2
fi
exit 0
