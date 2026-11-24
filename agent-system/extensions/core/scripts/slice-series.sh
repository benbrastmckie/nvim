#!/usr/bin/env bash
# slice-series.sh - the one script /slice drives: check, build, status over a single series
# document. Pure git plumbing. Never touches HEAD, the shared index, or the working tree.
#
# THIS SCRIPT NEVER CALLS: git push, git checkout, git switch, git merge, git rebase, git
# replay, gh, or glab. Grepping this file for any of those strings (outside this header)
# returns nothing; the test suite asserts it over the script's non-comment lines.
#
# SUBCOMMANDS (exactly three; any other argument, including none, is a named refusal)
# -------------------------------------------------------------------------------------
#   check <document-path|->    Validates a series document without writing anything:
#                               (a) the target is an ancestor of the work ref; (b) every path
#                               in the target->work-ref difference is in exactly one slice or
#                               matched by not_landing; (c) no declared glob matches zero paths
#                               of the difference; (d) every depends_on entry names a declared
#                               slice and the edge set has no cycle (bounded DFS, no persisted
#                               order); (e) every slice is at or under the bar or carries one of
#                               the two accepted over_bar_reason values. Prints the counts a
#                               caller's proposal table needs.
#   build <document-path|->    Turns an approved series document into one commit per buildable
#                               slice (private index overlay, write-tree, commit-tree) and moves
#                               each slice's ref by compare-and-swap. Refuses whatever `check`
#                               refuses by routing through the same validation entry point.
#   status <document-path|->   Reports, per slice, the local ref and the remote tracking ref
#                               against the recorded commit, plus the content-based merged test.
#
# Every subcommand takes a CANDIDATE-DOCUMENT input: a positional path, or `-` to read the
# series document from stdin. This is deliberately NOT the durable series path
# (specs/.orchestration/slices/<series id>.json) -- the script has no notion of a "durable"
# path at all. A caller validating a not-yet-approved proposal passes a throwaway candidate
# document (or feeds it on stdin); only once a caller has decided to persist it does it pass
# the durable path itself. This is how a validation run can produce the counts a proposal
# prompt needs without writing anything.
#
# THE SERIES-DOCUMENT SCHEMA
# ----------------------------
# A series document is one JSON object:
#   series_id           string, stable identifier for this series.
#   target: {
#     remote             string, the remote this series targets (may be "").
#     branch             string, the branch on that remote (may be "").
#     commit             string, the target's resolved commit as of the last build (may be "");
#                         used as a fallback when remote/branch do not resolve live.
#   }
#   work_ref: {
#     name               string, a ref name resolved live when non-empty (e.g. a branch, or
#                         "HEAD"); may be "".
#     commit             string, the work ref's resolved commit as of the last build (may be
#                         ""); used as a fallback when name does not resolve live.
#   }
#   bar: {
#     lines              number, the lines-added threshold.
#     files              number, the files-changed threshold.
#     source             one of: "declared" | "measured" | "default" | "chosen at prompt".
#     n                  number, optional; the sample size backing a "measured" source.
#   }
#   not_landing          array of path globs (shell-style wildcards); a diff path matching one
#                         of these, and no slice's paths, does not land in this series.
#   slices               array of objects, each:
#     id                 string, unique within this document.
#     title              string.
#     paths              array of path globs (shell-style wildcards) this slice's commit
#                         carries.
#     depends_on         array of other slice ids this slice is built on top of.
#     over_bar_reason     one of "single_file" | "generated_tree" | "" (unset); the only two
#                         accepted escapes from the size bar (a single file that cannot be
#                         divided, and a declared generated or mechanical tree landing alone).
#     state              one of: "proposed" | "built" | "pushed" | "open" | "merged".
#     ref                string, the slice's branch ref once built
#                         (refs/heads/slice/<series id>/<id>).
#     commit             string, the slice's built commit.
#     base_commit        string, the commit the slice's tree was overlaid onto.
#     request_url        string, the pull request URL once opened.
#
# The pull-request body for slice <id> of series <series id> lives beside the series document
# at specs/.orchestration/slices/<series id>/<id>.md -- this script never writes outside that
# directory and the durable series-document path a caller gives it.
#
# USAGE
# -----
#   slice-series.sh check <document-path|->
#   slice-series.sh build <document-path|->
#   slice-series.sh status <document-path|->
#
# EXIT CODES
# ----------
#   0   success
#   2   usage_error                no subcommand, an unknown subcommand, or a missing document
#                                   argument
#  10   document_invalid            the candidate document is not a JSON object, or is missing
#                                   a required top-level key
#  11   document_unreadable         the candidate document path does not exist (or stdin could
#                                   not be read)
#  20   target_unresolvable         target.remote/target.branch/target.commit resolve to no
#                                   commit
#  21   work_ref_unresolvable       work_ref.name/work_ref.commit resolve to no commit
#  22   target_not_ancestor        the resolved target is not an ancestor of the resolved work
#                                   ref
#  23   path_unassigned             a difference path matches no slice's paths and no
#                                   not_landing glob
#  24   path_in_two_slices          a difference path matches more than one slice's paths
#  25   glob_empty                  a declared glob (a slice's own, or not_landing) matches zero
#                                   paths of the difference
#  26   depends_on_unknown          a depends_on entry names a slice id that is not declared
#  27   depends_on_cycle            the depends_on edge set contains a cycle
#  28   over_bar_no_reason         a slice is over the bar and carries no accepted
#                                   over_bar_reason
#  30   ref_compare_and_swap_conflict   build's three-argument `git update-ref` found the ref
#                                   had moved since it was read
#
# REFUSAL CONVENTION (decision: one named reason, one exit code, per class above)
# -----------------------------------------------------------------------------------
#   REFUSED: slice-series.sh: <reason>: <message>
# printed to stderr, followed by `exit <code>`. Every resolver below is called as a plain
# statement, never wrapped in "$(...)" -- exit inside a command-substitution subshell would
# only terminate that subshell, silently losing the refusal's exit code.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh disable=SC1091
source "${SCRIPT_DIR}/lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 2)"
# shellcheck source=deploy-root-guard.sh disable=SC1091
. "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
[ -n "${REPO_ROOT:-}" ] && PROJECT_ROOT="$REPO_ROOT"
cd "$PROJECT_ROOT" || exit 1

ss_usage() {
  echo "Usage: $0 {check|build|status} <document-path|->" >&2
  exit 2
}

# ss_refuse <exit_code> <reason> <message> -- the one refusal path every check below uses.
# Never call this inside "$(...)"; see the header note above.
ss_refuse() {
  local code="$1" reason="$2" message="$3"
  echo "REFUSED: slice-series.sh: ${reason}: ${message}" >&2
  exit "$code"
}

SS_DOC=""

# ss_load_document <path|-> -- sets SS_DOC to the document's raw JSON text, or refuses.
ss_load_document() {
  local path="$1"
  if [ "$path" = "-" ]; then
    SS_DOC="$(cat)"
  else
    if [ ! -f "$path" ]; then
      ss_refuse 11 document_unreadable "no such file: ${path}"
    fi
    SS_DOC="$(cat "$path")"
  fi
  if ! printf '%s' "$SS_DOC" | jq -e 'type == "object"' >/dev/null 2>&1; then
    ss_refuse 10 document_invalid "candidate document is not a JSON object"
  fi
  local missing
  missing="$(printf '%s' "$SS_DOC" | jq -r '
    ["series_id","target","work_ref","bar","not_landing","slices"] - keys | .[]' 2>/dev/null)"
  if [ -n "$missing" ]; then
    ss_refuse 10 document_invalid "missing required key(s): $(printf '%s' "$missing" | tr '\n' ' ')"
  fi
}

# ss_resolve_target_commit -- echoes the target's resolved commit, or empty. Never refuses;
# the caller checks for an empty result and refuses with the right exit code for its subcommand.
ss_resolve_target_commit() {
  local remote branch commit resolved=""
  remote="$(printf '%s' "$SS_DOC" | jq -r '.target.remote // empty')"
  branch="$(printf '%s' "$SS_DOC" | jq -r '.target.branch // empty')"
  commit="$(printf '%s' "$SS_DOC" | jq -r '.target.commit // empty')"
  if [ -n "$remote" ] && [ -n "$branch" ]; then
    resolved="$(git rev-parse -q --verify "refs/remotes/${remote}/${branch}" 2>/dev/null || true)"
  fi
  if [ -z "$resolved" ] && [ -n "$branch" ]; then
    resolved="$(git rev-parse -q --verify "${branch}^{commit}" 2>/dev/null || true)"
  fi
  if [ -z "$resolved" ] && [ -n "$commit" ]; then
    resolved="$(git rev-parse -q --verify "${commit}^{commit}" 2>/dev/null || true)"
  fi
  printf '%s' "$resolved"
}

# ss_resolve_work_ref_commit -- echoes the work ref's resolved commit, or empty.
ss_resolve_work_ref_commit() {
  local name commit resolved=""
  name="$(printf '%s' "$SS_DOC" | jq -r '.work_ref.name // empty')"
  commit="$(printf '%s' "$SS_DOC" | jq -r '.work_ref.commit // empty')"
  if [ -n "$name" ]; then
    resolved="$(git rev-parse -q --verify "${name}^{commit}" 2>/dev/null || true)"
  fi
  if [ -z "$resolved" ] && [ -n "$commit" ]; then
    resolved="$(git rev-parse -q --verify "${commit}^{commit}" 2>/dev/null || true)"
  fi
  printf '%s' "$resolved"
}

# ss_resolve_commits -- sets SS_TARGET_COMMIT / SS_WORK_COMMIT, or refuses with 20/21.
SS_TARGET_COMMIT=""
SS_WORK_COMMIT=""
ss_resolve_commits() {
  SS_TARGET_COMMIT="$(ss_resolve_target_commit)"
  [ -n "$SS_TARGET_COMMIT" ] || ss_refuse 20 target_unresolvable "target.remote/target.branch/target.commit did not resolve to a commit"
  SS_WORK_COMMIT="$(ss_resolve_work_ref_commit)"
  [ -n "$SS_WORK_COMMIT" ] || ss_refuse 21 work_ref_unresolvable "work_ref.name/work_ref.commit did not resolve to a commit"
}

# ss_check_ancestor -- refuses 22 unless SS_TARGET_COMMIT is an ancestor of SS_WORK_COMMIT.
ss_check_ancestor() {
  if ! git merge-base --is-ancestor "$SS_TARGET_COMMIT" "$SS_WORK_COMMIT" 2>/dev/null; then
    ss_refuse 22 target_not_ancestor "target ${SS_TARGET_COMMIT} is not an ancestor of work_ref ${SS_WORK_COMMIT}"
  fi
}

# ss_check_assignment_and_globs -- validates (b) and (c) together: every difference path is in
# exactly one slice's paths or matched by not_landing, and no declared glob (a slice's own, or
# not_landing) matches zero difference paths. Sets SS_ASSIGNED / SS_UNASSIGNED / SS_TWO /
# SS_NOTLAND / SS_DIFF_TOTAL on success; refuses (23, 24, 25) otherwise.
SS_ASSIGNED=0
SS_UNASSIGNED=0
SS_TWO=0
SS_NOTLAND=0
SS_DIFF_TOTAL=0
ss_check_assignment_and_globs() {
  local -a diff_paths
  mapfile -d '' -t diff_paths < <(git diff --name-only -z "$SS_TARGET_COMMIT" "$SS_WORK_COMMIT")
  SS_DIFF_TOTAL="${#diff_paths[@]}"

  local -a g_kind g_owner g_pattern g_hits
  local entry
  while IFS= read -r -d '' entry; do
    [ -n "$entry" ] || continue
    local k o pat
    IFS=$'\x1f' read -r k o pat <<<"$entry"
    g_kind+=("$k")
    g_owner+=("$o")
    g_pattern+=("$pat")
    g_hits+=(0)
  done < <(printf '%s' "$SS_DOC" | jq -j '
    def sep: "\u001f";
    (.slices[] | .id as $id | (.paths // [])[] | "slice" + sep + $id + sep + .),
    ((.not_landing // [])[] | "notland" + sep + "" + sep + .)
    | . + "\u0000"
  ')

  local n="${#g_pattern[@]}"
  local p
  for p in "${diff_paths[@]}"; do
    [ -n "$p" ] || continue
    local slice_hits=0 nl_hit=0
    local j
    for ((j = 0; j < n; j++)); do
      # shellcheck disable=SC2053 # intentional unquoted RHS: shell glob match, not literal
      if [[ "$p" == ${g_pattern[j]} ]]; then
        g_hits[j]=$((g_hits[j] + 1))
        if [ "${g_kind[j]}" = "slice" ]; then
          slice_hits=$((slice_hits + 1))
        else
          nl_hit=1
        fi
      fi
    done
    if [ "$slice_hits" -ge 2 ]; then
      ss_refuse 24 path_in_two_slices "path '${p}' matches more than one slice's paths"
    elif [ "$slice_hits" -eq 1 ]; then
      SS_ASSIGNED=$((SS_ASSIGNED + 1))
    elif [ "$nl_hit" -eq 1 ]; then
      SS_NOTLAND=$((SS_NOTLAND + 1))
    else
      SS_UNASSIGNED=$((SS_UNASSIGNED + 1))
      ss_refuse 23 path_unassigned "path '${p}' is not assigned to any slice and does not match not_landing"
    fi
  done

  for ((j = 0; j < n; j++)); do
    if [ "${g_hits[j]}" -eq 0 ]; then
      if [ "${g_kind[j]}" = "slice" ]; then
        ss_refuse 25 glob_empty "slice '${g_owner[j]}' glob '${g_pattern[j]}' matches zero paths of the difference"
      else
        ss_refuse 25 glob_empty "not_landing glob '${g_pattern[j]}' matches zero paths of the difference"
      fi
    fi
  done
}

# ss_check_depends_on -- validates (d): every depends_on entry names a declared slice id, and
# the edge set has no cycle. Bounded DFS with a visited/in-progress marker; no persisted order,
# no component analysis. Refuses 26/27.
ss_check_depends_on() {
  local -a ids
  mapfile -d '' -t ids < <(printf '%s' "$SS_DOC" | jq -j '.slices[].id | . + "\u0000"')

  local -A ss_state=()
  local id
  for id in "${ids[@]}"; do
    [ -n "$id" ] && ss_state["$id"]=0
  done

  ss_depends_on_dfs() {
    local node="$1"
    case "${ss_state[$node]:-0}" in
      1) ss_refuse 27 depends_on_cycle "a cycle exists in depends_on involving slice '${node}'" ;;
      2) return 0 ;;
    esac
    ss_state["$node"]=1
    local -a deps
    mapfile -d '' -t deps < <(printf '%s' "$SS_DOC" | jq -j --arg id "$node" '
      .slices[] | select(.id == $id) | (.depends_on // [])[] | . + "\u0000"')
    local dep
    for dep in "${deps[@]}"; do
      [ -n "$dep" ] || continue
      if [ -z "${ss_state[$dep]+x}" ]; then
        ss_refuse 26 depends_on_unknown "slice '${node}' depends_on unknown slice '${dep}'"
      fi
      ss_depends_on_dfs "$dep"
    done
    ss_state["$node"]=2
  }

  for id in "${ids[@]}"; do
    [ -n "$id" ] || continue
    if [ "${ss_state[$id]}" = 0 ]; then
      ss_depends_on_dfs "$id"
    fi
  done
}

# ss_check_bar -- validates (e): every slice is at or under the bar, or carries one of the two
# accepted over_bar_reason values ("single_file" | "generated_tree"). Prints one "SLICE ..."
# line per slice with its measured files/lines. Refuses 28.
ss_check_bar() {
  local bar_lines bar_files
  bar_lines="$(printf '%s' "$SS_DOC" | jq -r '.bar.lines // 0')"
  bar_files="$(printf '%s' "$SS_DOC" | jq -r '.bar.files // 0')"

  local -a ids
  mapfile -d '' -t ids < <(printf '%s' "$SS_DOC" | jq -j '.slices[].id | . + "\u0000"')

  local id
  for id in "${ids[@]}"; do
    [ -n "$id" ] || continue
    local -a globs pathspecs
    mapfile -d '' -t globs < <(printf '%s' "$SS_DOC" | jq -j --arg id "$id" '
      .slices[] | select(.id == $id) | (.paths // [])[] | . + "\u0000"')
    pathspecs=()
    local g
    for g in "${globs[@]}"; do
      [ -n "$g" ] || continue
      pathspecs+=(":(glob)${g}")
    done

    local files=0 lines=0 numstat
    if [ "${#pathspecs[@]}" -gt 0 ]; then
      numstat="$(git diff --numstat "$SS_TARGET_COMMIT" "$SS_WORK_COMMIT" -- "${pathspecs[@]}" 2>/dev/null || true)"
      if [ -n "$numstat" ]; then
        files="$(printf '%s\n' "$numstat" | grep -c '.')"
        lines="$(printf '%s\n' "$numstat" | awk '{ if ($1 ~ /^[0-9]+$/) s += $1 } END { print s + 0 }')"
      fi
    fi

    local reason over="no"
    reason="$(printf '%s' "$SS_DOC" | jq -r --arg id "$id" '
      .slices[] | select(.id == $id) | (.over_bar_reason // "")')"
    if [ "$files" -gt "$bar_files" ] || [ "$lines" -gt "$bar_lines" ]; then
      over="yes"
      case "$reason" in
        single_file | generated_tree) : ;;
        *) ss_refuse 28 over_bar_no_reason "slice '${id}' is over the bar (files=${files} lines=${lines}, bar files=${bar_files} lines=${bar_lines}) and carries no accepted over_bar_reason" ;;
      esac
    fi
    echo "SLICE ${id} files=${files} lines=${lines} bar_files=${bar_files} bar_lines=${bar_lines} over=${over} reason=${reason:--}"
  done
}

# ss_cmd_check <document-path|-> -- the full validation entry point (a)-(e), plus the counts a
# proposal prompt needs. `build` routes through this same function rather than duplicating it.
ss_cmd_check() {
  ss_load_document "$1"
  ss_resolve_commits
  ss_check_ancestor
  ss_check_assignment_and_globs
  ss_check_depends_on
  echo "OK"
  echo "target=${SS_TARGET_COMMIT} work_ref=${SS_WORK_COMMIT}"
  echo "diff_total=${SS_DIFF_TOTAL}"
  echo "assigned=${SS_ASSIGNED} unassigned=${SS_UNASSIGNED} in_two_slices=${SS_TWO} not_landing=${SS_NOTLAND}"
  echo "not_landing_generated=none declared; every path counts toward the bar"
  ss_check_bar
}

ss_cmd_build() {
  ss_refuse 2 usage_error "build is not yet implemented"
}

ss_cmd_status() {
  ss_refuse 2 usage_error "status is not yet implemented"
}

ss_main() {
  local sub="${1:-}"
  case "$sub" in
    check)
      shift
      [ "$#" -ge 1 ] || ss_usage
      ss_cmd_check "$1"
      ;;
    build)
      shift
      [ "$#" -ge 1 ] || ss_usage
      ss_cmd_build "$1"
      ;;
    status)
      shift
      [ "$#" -ge 1 ] || ss_usage
      ss_cmd_status "$1"
      ;;
    "")
      ss_refuse 2 usage_error "no subcommand given; expected one of: check, build, status"
      ;;
    *)
      ss_refuse 2 usage_error "unknown subcommand '${sub}'; expected one of: check, build, status"
      ;;
  esac
}

ss_main "$@"
