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
SS_OUT_DOC=""

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

# ss_slice_diff_entries <id> -- NUL-delimited "<status>\0<path>\0..." pairs: this slice's own
# subset of the target->work_ref difference (git diff --name-status over the slice's own
# glob pathspecs). Caller reads two NUL-delimited tokens at a time.
ss_slice_diff_entries() {
  local id="$1"
  local -a globs pathspecs
  mapfile -d '' -t globs < <(printf '%s' "$SS_DOC" | jq -j --arg id "$id" '
    .slices[] | select(.id == $id) | (.paths // [])[] | . + "\u0000"')
  pathspecs=()
  local g
  for g in "${globs[@]}"; do
    [ -n "$g" ] || continue
    pathspecs+=(":(glob)${g}")
  done
  [ "${#pathspecs[@]}" -gt 0 ] || return 0
  git diff --name-status -z "$SS_TARGET_COMMIT" "$SS_WORK_COMMIT" -- "${pathspecs[@]}" 2>/dev/null
}

# ss_overlay_slice_tree <id> <base-treeish> -- the overlay primitive, written fresh and
# self-contained (no `source` of, no extraction from, scripts/review-stack-prepare.sh): a
# private GIT_INDEX_FILE (a mktemp file removed immediately after write-tree), `read-tree` of
# the base tree, then per this slice's own difference path either `update-index --cacheinfo`
# with that path's mode and object id at the work ref, or `update-index --force-remove` for a
# path the work ref deletes. Echoes the resulting tree object id. Touches no real repo state:
# HEAD, the shared index, and the working tree are untouched by every command here.
ss_overlay_slice_tree() {
  local id="$1" base_treeish="$2"
  local idx
  idx="$(mktemp)"
  GIT_INDEX_FILE="$idx" git read-tree "$base_treeish" >/dev/null
  local status path
  while IFS= read -r -d '' status && IFS= read -r -d '' path; do
    [ -n "$path" ] || continue
    if [ "$status" = "D" ]; then
      GIT_INDEX_FILE="$idx" git update-index --force-remove -- "$path" >/dev/null
    else
      local line mode oid
      line="$(git ls-tree "$SS_WORK_COMMIT" -- "$path")"
      mode="$(printf '%s' "$line" | awk '{print $1}')"
      oid="$(printf '%s' "$line" | awk '{print $3}')"
      if [ -n "$mode" ] && [ -n "$oid" ]; then
        GIT_INDEX_FILE="$idx" git update-index --add --cacheinfo "${mode},${oid},${path}" >/dev/null
      fi
    fi
  done < <(ss_slice_diff_entries "$id")
  local tree
  tree="$(GIT_INDEX_FILE="$idx" git write-tree)"
  rm -f "$idx"
  printf '%s' "$tree"
}

# ss_write_pr_body_if_absent <series-id> <slice-id> <title> -- writes a minimal pull-request
# body beside the series document at specs/.orchestration/slices/<series-id>/<slice-id>.md,
# only if the file is absent. An existing body is left untouched (it is editable until the
# request is opened).
ss_write_pr_body_if_absent() {
  local series_id="$1" id="$2" title="$3"
  local dir="specs/.orchestration/slices/${series_id}"
  local path="${dir}/${id}.md"
  if [ ! -f "$path" ]; then
    mkdir -p "$dir"
    printf '# %s\n\nSlice: %s\nSeries: %s\n' "$title" "$id" "$series_id" >"$path"
  fi
}

# ss_cmd_build <document-path|-> -- turns an approved series document into one commit per
# buildable slice and moves each slice's ref by compare-and-swap. Refuses whatever `check`
# refuses by calling the exact same validation functions `check` uses, never a duplicated
# reimplementation. Processes slices in document order; "re-derive, never rebase" means every
# non-merged slice is freshly overlaid every invocation, with no three-way merge anywhere.
#
# TEST HOOK (used only by the suite): if SS_TEST_PRE_SWAP_HOOK names an executable, it is run
# with the ref name as its one argument immediately after the compare-and-swap "old" value is
# captured and immediately before the swap is attempted -- the seam a synchronous test needs to
# simulate a ref moved concurrently between read and write. Unset in ordinary use.
ss_cmd_build() {
  local input_path="$1"
  ss_load_document "$input_path"
  ss_resolve_commits
  ss_check_ancestor
  ss_check_assignment_and_globs
  ss_check_depends_on
  ss_check_bar

  local series_id
  series_id="$(printf '%s' "$SS_DOC" | jq -r '.series_id')"

  SS_OUT_DOC="$SS_DOC"

  local -a ids
  mapfile -d '' -t ids < <(printf '%s' "$SS_DOC" | jq -j '.slices[].id | . + "\u0000"')

  local -A commit_for=()

  local id
  for id in "${ids[@]}"; do
    [ -n "$id" ] || continue
    local state
    state="$(printf '%s' "$SS_DOC" | jq -r --arg id "$id" '.slices[] | select(.id == $id) | .state // ""')"
    if [ "$state" = "merged" ]; then
      echo "SLICE ${id} already merged; skipped"
      continue
    fi

    local -a deps
    mapfile -d '' -t deps < <(printf '%s' "$SS_DOC" | jq -j --arg id "$id" '
      .slices[] | select(.id == $id) | (.depends_on // [])[] | . + "\u0000"')

    local -a unmerged_deps=()
    local d dstate
    for d in "${deps[@]}"; do
      [ -n "$d" ] || continue
      dstate="$(printf '%s' "$SS_DOC" | jq -r --arg id "$d" '.slices[] | select(.id == $id) | .state // ""')"
      [ "$dstate" = "merged" ] || unmerged_deps+=("$d")
    done

    local parent=""
    if [ "${#unmerged_deps[@]}" -ge 2 ]; then
      echo "SLICE ${id} waiting unmerged_depends_on=$(
        IFS=,
        echo "${unmerged_deps[*]}"
      )"
      continue
    elif [ "${#unmerged_deps[@]}" -eq 1 ]; then
      local dep="${unmerged_deps[0]}"
      parent="${commit_for[$dep]:-}"
      if [ -z "$parent" ]; then
        parent="$(printf '%s' "$SS_DOC" | jq -r --arg id "$dep" '.slices[] | select(.id == $id) | .commit // ""')"
      fi
      if [ -z "$parent" ]; then
        echo "SLICE ${id} waiting unmerged_depends_on=${dep}"
        continue
      fi
    else
      parent="$SS_TARGET_COMMIT"
    fi

    local tree
    tree="$(ss_overlay_slice_tree "$id" "$parent")"
    local title
    title="$(printf '%s' "$SS_DOC" | jq -r --arg id "$id" '.slices[] | select(.id == $id) | .title // ""')"
    local new_commit
    new_commit="$(printf '%s\n' "$title" | git commit-tree "$tree" -p "$parent")"

    local ref="refs/heads/slice/${series_id}/${id}"
    local old
    old="$(git rev-parse -q --verify "$ref" 2>/dev/null || true)"
    if [ -z "$old" ]; then
      old="$(printf '0%.0s' $(seq 1 "${#SS_TARGET_COMMIT}"))"
    fi

    if [ -n "${SS_TEST_PRE_SWAP_HOOK:-}" ] && [ -x "${SS_TEST_PRE_SWAP_HOOK}" ]; then
      "${SS_TEST_PRE_SWAP_HOOK}" "$ref" || true
    fi

    local caserr
    caserr="$(mktemp)"
    if ! git update-ref "$ref" "$new_commit" "$old" 2>"$caserr"; then
      local errmsg
      errmsg="$(cat "$caserr" 2>/dev/null)"
      rm -f "$caserr"
      ss_refuse 30 ref_compare_and_swap_conflict "ref '${ref}' moved concurrently since it was read: ${errmsg}"
    fi
    rm -f "$caserr"

    commit_for["$id"]="$new_commit"

    local new_state="$state"
    [ "$new_state" = "proposed" ] && new_state="built"

    SS_OUT_DOC="$(printf '%s' "$SS_OUT_DOC" | jq --arg id "$id" --arg commit "$new_commit" \
      --arg base "$parent" --arg ref "$ref" --arg state "$new_state" '
      .slices |= map(if .id == $id then
        .commit = $commit | .base_commit = $base | .ref = $ref | .state = $state
      else . end)')"

    ss_write_pr_body_if_absent "$series_id" "$id" "$title"

    echo "SLICE ${id} built commit=${new_commit} ref=${ref} base_commit=${parent}"
  done

  if [ "$input_path" != "-" ]; then
    printf '%s\n' "$SS_OUT_DOC" >"$input_path"
  else
    echo "document_not_persisted=stdin candidate document has no durable path; updated document follows"
    printf '%s\n' "$SS_OUT_DOC"
  fi
}

# ss_slice_content_matches_target <id> <slice-commit> -- the content-based merged test: true
# (exit 0) when this slice's own declared paths are byte-identical at the slice's own built
# commit and at the target's current tip. A content test, never a commit-ancestry test, so a
# squash merge (no shared history, identical resulting content) is recognised.
ss_slice_content_matches_target() {
  local id="$1" slice_commit="$2"
  local -a globs pathspecs
  mapfile -d '' -t globs < <(printf '%s' "$SS_DOC" | jq -j --arg id "$id" '
    .slices[] | select(.id == $id) | (.paths // [])[] | . + "\u0000"')
  pathspecs=()
  local g
  for g in "${globs[@]}"; do
    [ -n "$g" ] || continue
    pathspecs+=(":(glob)${g}")
  done
  [ "${#pathspecs[@]}" -gt 0 ] || return 1
  local diff_out
  diff_out="$(git diff --name-only "$slice_commit" "$SS_TARGET_COMMIT" -- "${pathspecs[@]}" 2>/dev/null)"
  [ -z "$diff_out" ]
}

# ss_cmd_status <document-path|-> -- per slice: the local ref and the remote tracking ref
# against the recorded commit, plus the content-based merged test. Purely a report: never
# writes to the document, never refuses on a condition `build`/`check` would refuse on (e.g.
# target not an ancestor of work_ref), since the whole point of `status` is to inform the
# caller about current reality -- including a reality `commands/slice.md`'s continue step must
# react to -- without blocking on it. No push, no merge, ever performed here.
ss_cmd_status() {
  ss_load_document "$1"
  ss_resolve_commits

  local series_id remote
  series_id="$(printf '%s' "$SS_DOC" | jq -r '.series_id')"
  remote="$(printf '%s' "$SS_DOC" | jq -r '.target.remote // empty')"

  local -a ids
  mapfile -d '' -t ids < <(printf '%s' "$SS_DOC" | jq -j '.slices[].id | . + "\u0000"')

  local id
  for id in "${ids[@]}"; do
    [ -n "$id" ] || continue
    local state ref rec_commit rec_base
    state="$(printf '%s' "$SS_DOC" | jq -r --arg id "$id" '.slices[] | select(.id == $id) | .state // ""')"
    ref="$(printf '%s' "$SS_DOC" | jq -r --arg id "$id" '.slices[] | select(.id == $id) | .ref // ""')"
    [ -n "$ref" ] || ref="refs/heads/slice/${series_id}/${id}"
    rec_commit="$(printf '%s' "$SS_DOC" | jq -r --arg id "$id" '.slices[] | select(.id == $id) | .commit // ""')"
    rec_base="$(printf '%s' "$SS_DOC" | jq -r --arg id "$id" '.slices[] | select(.id == $id) | .base_commit // ""')"

    local local_ref_state="absent" local_commit="" local_match="n/a"
    local_commit="$(git rev-parse -q --verify "$ref" 2>/dev/null || true)"
    if [ -n "$local_commit" ]; then
      local_ref_state="exists"
      if [ -n "$rec_commit" ]; then
        if [ "$local_commit" = "$rec_commit" ]; then
          local_match="yes"
        else
          local_match="no"
        fi
      fi
    fi

    local remote_ref_state="no_remote" remote_commit="" remote_match="n/a"
    if [ -n "$remote" ]; then
      remote_ref_state="absent"
      remote_commit="$(git rev-parse -q --verify "refs/remotes/${remote}/slice/${series_id}/${id}" 2>/dev/null || true)"
      if [ -n "$remote_commit" ]; then
        remote_ref_state="exists"
        if [ -n "$rec_commit" ]; then
          if [ "$remote_commit" = "$rec_commit" ]; then
            remote_match="yes"
          else
            remote_match="no"
          fi
        fi
      fi
    fi

    local merged="no"
    if [ -n "$local_commit" ] && ss_slice_content_matches_target "$id" "$local_commit"; then
      merged="yes"
    fi

    local rebuild_due="no"
    if [ "$merged" != "yes" ]; then
      local -a deps
      mapfile -d '' -t deps < <(printf '%s' "$SS_DOC" | jq -j --arg id "$id" '
        .slices[] | select(.id == $id) | (.depends_on // [])[] | . + "\u0000"')
      local -a unmerged_deps=()
      local d dstate
      for d in "${deps[@]}"; do
        [ -n "$d" ] || continue
        dstate="$(printf '%s' "$SS_DOC" | jq -r --arg id "$d" '.slices[] | select(.id == $id) | .state // ""')"
        [ "$dstate" = "merged" ] || unmerged_deps+=("$d")
      done
      local current_base=""
      if [ "${#unmerged_deps[@]}" -eq 0 ]; then
        current_base="$SS_TARGET_COMMIT"
      elif [ "${#unmerged_deps[@]}" -eq 1 ]; then
        current_base="$(printf '%s' "$SS_DOC" | jq -r --arg id "${unmerged_deps[0]}" '.slices[] | select(.id == $id) | .commit // ""')"
      fi
      if [ -n "$current_base" ] && [ -n "$rec_base" ] && [ "$current_base" != "$rec_base" ]; then
        rebuild_due="yes"
      fi
    fi

    echo "STATUS ${id} state=${state} local_ref=${local_ref_state} local_commit=${local_commit:--} local_matches_recorded=${local_match} remote_ref=${remote_ref_state} remote_commit=${remote_commit:--} remote_matches_recorded=${remote_match} merged=${merged} rebuild_due=${rebuild_due}"
  done
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
