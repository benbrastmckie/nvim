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
#   cut              Build the review refs and the manifest for a stack. Selection flags
#                     (--milestone, --batch, --tasks, --merge, --order, --prefix) and the actual
#                     ref-writing body are added by a later plan phase; this phase resolves the
#                     four inputs below and stops.
#   restack           Move a stack's descendants onto a merged parent's new base. Body added by
#                     a later plan phase; this phase resolves and stops.
#   show              Print a stack's manifest with its literal commands. Body added by a later
#                     plan phase; this phase resolves and stops.
#   record-request    Record a PR URL against one manifest entry. Body added by a later plan
#                     phase; this phase resolves and stops.
#
# RESOLUTION (every subcommand, before any of the above runs)
# -------------------------------------------------------------
# 1. Integration branch: the newest batch record naming one of the selected tasks (none are
#    selectable yet in this phase), else the declared `integration_branch`
#    (batch_admission_integration_branch), else the branch HEAD names. Never refused: absence
#    only narrows what "the bottom of the stack" can mean.
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
# USAGE
# -----
#   review-stack-prepare.sh cut [--dry-run] [--review-base REF] [--remote NAME]
#   review-stack-prepare.sh restack --stack-id NAME [--dry-run] [--review-base REF] [--remote NAME]
#   review-stack-prepare.sh show --stack-id NAME [--review-base REF] [--remote NAME]
#   review-stack-prepare.sh record-request --stack-id NAME [--review-base REF] [--remote NAME]
#
# EXIT CODES
# ----------
#   0   resolved (and, once a later phase fills the subcommand's body, that body's own result)
#   2   usage error
#  10   review_base_undeclared
#  11   review_base_invalid
#  12   review_base_unresolvable
#  13   review_base_is_integration_branch
#  20   remote_unresolvable
#  30   platform_gitlab_unsupported
#  31   platform_unrecognized_host
#  32   platform_push_url_mismatch

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

SPECS_DIR="${PROJECT_ROOT}/specs"

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
# empty. Same chain milestone-review-handoff.sh's resolve_integration_branch() uses; task
# arguments are accepted now so the later selection-bearing phase needs no change here.
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
rest_args=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run="true"
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
    *)
      rest_args+=("$1")
      shift
      ;;
  esac
done

rsp_resolve_integration_branch
integration_branch="$RSP_INTEGRATION_BRANCH"
rsp_resolve_review_base "$review_base_flag_set" "$review_base_flag_value" "$integration_branch"
review_base="$RSP_REVIEW_BASE"
rsp_resolve_remote "$remote_flag" "$integration_branch"
remote="$RSP_REMOTE"
rsp_detect_platform "$remote"
platform="$RSP_PLATFORM"

# Every subcommand's own body (cut's ref-writing, restack's recompute, show's manifest print,
# record-request's manifest update) is filled by a later plan phase. This phase stops here,
# having resolved every input a cut needs and refused on any input that cannot be resolved; it
# writes no ref, no manifest and no file.
echo "NOTE: review-stack-prepare.sh: resolved integration_branch='${integration_branch}' review_base='${review_base}' remote='${remote}' platform='${platform}' for subcommand '${subcommand}' (stack_id='${stack_id}', dry_run=${dry_run}); subcommand body not yet implemented, nothing written." >&2
exit 0
