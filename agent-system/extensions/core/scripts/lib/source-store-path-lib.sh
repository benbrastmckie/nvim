#!/usr/bin/env bash
# source-store-path-lib.sh - Single shared home for two predicates the phase-commit path (and any
# future consumer) needs: "which repository does this path actually belong to, and where inside
# it" and "is this string an unexpanded shell variable". Modelled structurally on
# scripts/lib/deploy-freshness-lib.sh: a header stating it is the single home of the algorithm,
# safe to source, sets no shell options a caller inherits, exports named functions, and reduces
# every failure mode to a silent, fail-soft non-answer rather than an abort.
#
# WHY THIS EXISTS
# ----------------
# A `file_scope` entry naming a source-store path (`agent-system/extensions/<name>/...`) is NOT a
# uniform case across repositories. `.claude-extensions.json`'s `source_dir` is resolved to an
# ABSOLUTE path; in a repository that merely CONSUMES a deploy, that absolute path's enclosing
# git toplevel is a DIFFERENT repository than the one doing the committing. In a repository that
# OWNS its own source store (this one, today), the same absolute path's enclosing toplevel is
# this repository's own root. The same literal string is an ordinary in-repo path in the second
# case and a path this repository cannot hold at all in the first. Any consumer of a `file_scope`
# entry must therefore classify before testing containment, never assume one shape universally.
#
# THE TWO EXPORTED FUNCTIONS
# --------------------------
#   source_store_classify <repo_root> <path>
#     Prints exactly one line:
#       IN_REPO
#         -- or --
#       SOURCE_STORE<TAB><extension><TAB><source_toplevel><TAB><path_relative_to_that_toplevel>
#         -- or --
#       OUT_OF_REPO<TAB><resolved_parent_dir>
#     Always returns 0.
#
#   source_store_unexpanded_variable <string>
#     Returns 0 (success) when <string> carries an unexpanded shell-variable shape (a `$`
#     followed by an identifier, or a `${...}` form); returns 1 otherwise. Prints nothing. The
#     reserved slashless `__WHOLE_TREE__` sentinel never matches (it contains no `$`).
#
# REPOSITORY-CONTAINMENT RULE (reused in spirit from git-commit-scoped.sh's V9 block)
# -------------------------------------------------------------------------------------
# Canonicalize `repo_root`, then resolve `dirname -- "$path"` (the ORIGINAL, unresolved string's
# parent -- never the final component) relative to it via `realpath -m --relative-to`. An empty
# result, exactly `..`, or a `../` prefix is the out-of-repository verdict; anything else is
# in-repository. This is the measured leaf-symlink-safety property git-commit-scoped.sh's V9
# block already established empirically: an in-repo symlink whose TARGET lies outside the
# repository is a legal pathspec (staged as a symlink blob) that a leaf-resolving predicate would
# wrongly call out-of-repository, while a path THROUGH a symlinked directory whose target lies
# outside the repository is correctly out-of-repository under the parent-only rule, since the
# symlinked directory component is itself part of the parent path. This file reuses that rule
# verbatim in spirit rather than reinventing it.
#
# SOURCE-STORE ATTRIBUTION RULE
# -----------------------------
# For each extension key in `<repo_root>/.claude-extensions.json`, resolve that extension's own
# `source_dir` (per-extension ONLY -- a top-level `.source_dir` lookup returns `null`, and `null`
# must never be read as the key being absent), then that directory's enclosing git toplevel, then
# `source_rel` = `source_dir` expressed relative to that toplevel.
#
# Guard first: if the resolved toplevel equals the canonicalized `repo_root`, this repository OWNS
# that extension's source store, so the extension contributes nothing to classification and every
# path stays whatever the bare containment rule already said (today's behavior, byte for byte).
# This is the INERTNESS property: in a repository that owns its own source store, this library
# changes nothing.
#
# Otherwise, attribute a tested path to that extension when it equals or is prefixed by
# `source_rel/` (the relative shape), or when its absolute resolution lies under `source_dir`
# (the absolute shape). Attribution takes precedence over the bare containment verdict in BOTH
# directions: a relative path the containment rule would call in-repository is still attributed
# when it matches `source_rel/`, and an absolute path the containment rule calls
# out-of-repository is refined to SOURCE_STORE when it is attributable. An out-of-repository path
# no extension can claim stays OUT_OF_REPO.
#
# FAIL-SOFT POSTURE
# -----------------
# Every failure mode below resolves to IN_REPO for `source_store_classify`, reproducing today's
# (pre-existing) behavior exactly rather than inventing a new one: a missing or unparseable
# `.claude-extensions.json`; a missing `jq`, `git`, or `realpath` binary; an extension entry
# carrying no `source_dir`; a `source_dir` that does not exist or is not inside a git working
# tree; or an empty resolved toplevel. This function never aborts and never exits non-zero; it
# sets no shell options a sourcing caller inherits (no `set -e`/`-u`/`-o pipefail` at file scope).

# _ssp_canon <path> -- canonicalize via realpath -m, printing nothing on failure.
_ssp_canon() {
  realpath -m -- "$1" 2>/dev/null
}

# _ssp_dirname_abs <repo_root> <path> -- the ORIGINAL (unresolved) path's parent directory,
# anchored at <repo_root> when <path> is relative (a bare `dirname` on a relative path resolves
# against the CALLER's cwd, not against repo_root, which this library must never assume equals
# cwd). Prints an unresolved (not yet realpath'd) absolute-or-repo-anchored string.
_ssp_dirname_abs() {
  local repo_root="$1" path="$2"
  if [[ "$path" = /* ]]; then
    dirname -- "$path"
  else
    printf '%s/%s\n' "${repo_root%/}" "$(dirname -- "$path")"
  fi
}

# _ssp_parent_rel <repo_root_canon> <repo_root> <path> -- resolve the ORIGINAL (unresolved)
# path's parent directory, anchored at repo_root when relative, relative to the canonicalized
# repo root. Prints the relative result, or nothing on failure.
_ssp_parent_rel() {
  local repo_root_canon="$1" repo_root="$2" path="$3"
  realpath -m --relative-to="$repo_root_canon" -- "$(_ssp_dirname_abs "$repo_root" "$path")" 2>/dev/null
}

# _ssp_is_out_of_repo_rel <rel> -- true when the resolved relative parent names an
# out-of-repository location: empty (realpath failure), exactly "..", or beginning "../".
_ssp_is_out_of_repo_rel() {
  case "$1" in
    ""|".."|"../"*) return 0 ;;
    *) return 1 ;;
  esac
}

# source_store_classify <repo_root> <path>
# See header for the full contract. Always returns 0 and prints exactly one line.
source_store_classify() {
  local repo_root="${1:-}" path="${2:-}"

  if [ -z "$repo_root" ] || [ -z "$path" ]; then
    echo "IN_REPO"
    return 0
  fi

  if ! command -v jq >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 || ! command -v realpath >/dev/null 2>&1; then
    echo "IN_REPO"
    return 0
  fi

  local repo_root_canon
  repo_root_canon="$(_ssp_canon "$repo_root")"
  if [ -z "$repo_root_canon" ]; then
    echo "IN_REPO"
    return 0
  fi

  # Bare containment verdict (the V9-style rule). Computed first; attribution below may refine an
  # OUT_OF_REPO verdict to SOURCE_STORE, or claim an IN_REPO-verdict path as SOURCE_STORE too.
  local parent_rel bare_out_of_repo=0
  parent_rel="$(_ssp_parent_rel "$repo_root_canon" "$repo_root" "$path")"
  if _ssp_is_out_of_repo_rel "$parent_rel"; then
    bare_out_of_repo=1
  fi

  # Resolve the extensions file for the attribution pass. A missing/unparseable file means
  # attribution contributes nothing: fall through to the bare verdict.
  local ext_file="${repo_root}/.claude-extensions.json"
  local ext_json=""
  if [ -f "$ext_file" ]; then
    ext_json="$(cat "$ext_file" 2>/dev/null)" || ext_json=""
    if [ -n "$ext_json" ] && ! echo "$ext_json" | jq -e . >/dev/null 2>&1; then
      ext_json=""
    fi
  fi

  if [ -n "$ext_json" ]; then
    local ext_names name
    ext_names="$(echo "$ext_json" | jq -r '.extensions // {} | keys[]?' 2>/dev/null)" || ext_names=""

    # Absolute resolution of the tested path's parent directory, used for the absolute-shape
    # attribution test below.
    local path_abs_dir
    path_abs_dir="$(_ssp_canon "$(_ssp_dirname_abs "$repo_root" "$path")")"

    while IFS= read -r name; do
      [ -n "$name" ] || continue

      local source_dir
      source_dir="$(echo "$ext_json" | jq -r --arg n "$name" '.extensions[$n].source_dir // empty' 2>/dev/null)"
      [ -n "$source_dir" ] || continue
      [ -d "$source_dir" ] || continue

      local source_toplevel
      source_toplevel="$(git -C "$source_dir" rev-parse --show-toplevel 2>/dev/null)" || continue
      [ -n "$source_toplevel" ] || continue
      source_toplevel="$(_ssp_canon "$source_toplevel")"
      [ -n "$source_toplevel" ] || continue

      # Inertness guard: this repository owns this extension's source store. Contribute nothing;
      # the bare containment verdict (already computed above) stands unchanged.
      if [ "$source_toplevel" = "$repo_root_canon" ]; then
        continue
      fi

      local source_dir_canon
      source_dir_canon="$(_ssp_canon "$source_dir")"
      [ -n "$source_dir_canon" ] || continue

      local source_rel
      source_rel="$(realpath -m --relative-to="$source_toplevel" -- "$source_dir_canon" 2>/dev/null)" || continue
      [ -n "$source_rel" ] || continue

      # Relative-shape attribution: the tested path (as a string, relative to repo_root) equals
      # source_rel or is prefixed by "source_rel/". The emitted fourth field is the path relative
      # to source_toplevel (the documented contract), which -- precisely because source_rel is
      # ITSELF already expressed relative to source_toplevel -- is the tested path's own string,
      # UNCHANGED (never stripped down to a sub-path of source_dir): the universal
      # "agent-system/extensions/<name>/..." spelling convention is simultaneously valid relative
      # to the consumer's root (what file_scope declares) and relative to source_toplevel (what
      # commit-source-store-path.sh needs to `git add` inside the second repository), because the
      # source repository's own on-disk layout mirrors the same convention at its own root.
      case "$path" in
        "$source_rel"|"$source_rel"/*)
          echo "SOURCE_STORE"$'\t'"$name"$'\t'"$source_toplevel"$'\t'"$path"
          return 0
          ;;
      esac

      # Absolute-shape attribution: the tested path's absolute resolution lies under source_dir
      # (or equals it). The emitted fourth field is the FULL resolved path (not just its parent)
      # re-expressed relative to source_toplevel -- the same "relative to source_toplevel"
      # contract the relative-shape branch above honors, computed directly via realpath here
      # since there is no original relative string to reuse verbatim.
      if [ -n "$path_abs_dir" ]; then
        local path_abs
        if [[ "$path" = /* ]]; then
          path_abs="$path"
        else
          path_abs="${repo_root%/}/${path}"
        fi
        path_abs="$(_ssp_canon "$path_abs")"
        case "$path_abs" in
          "$source_dir_canon"|"$source_dir_canon"/*)
            local rel_to_toplevel
            rel_to_toplevel="$(realpath -m --relative-to="$source_toplevel" -- "$path_abs" 2>/dev/null)"
            [ -n "$rel_to_toplevel" ] || continue
            echo "SOURCE_STORE"$'\t'"$name"$'\t'"$source_toplevel"$'\t'"$rel_to_toplevel"
            return 0
            ;;
        esac
      fi
    done <<< "$ext_names"
  fi

  # No extension claimed this path: fall through to the bare containment verdict.
  if [ "$bare_out_of_repo" -eq 1 ]; then
    local resolved_parent
    resolved_parent="$(_ssp_canon "$(_ssp_dirname_abs "$repo_root" "$path")")"
    [ -n "$resolved_parent" ] || resolved_parent="(unresolvable)"
    echo "OUT_OF_REPO"$'\t'"$resolved_parent"
    return 0
  fi

  echo "IN_REPO"
  return 0
}

# source_store_unexpanded_variable <string>
# Returns 0 when <string> carries an unexpanded shell-variable shape: a `$` followed by an
# identifier ([A-Za-z_][A-Za-z0-9_]*), or a `${...}` form. Returns 1 otherwise, including for a
# literal `$` not followed by either shape, and for the reserved slashless `__WHOLE_TREE__`
# sentinel (which contains no `$` at all).
source_store_unexpanded_variable() {
  local s="${1:-}"
  [ -n "$s" ] || return 1
  if [[ "$s" =~ \$\{[A-Za-z_][A-Za-z0-9_]*\} ]]; then
    return 0
  fi
  if [[ "$s" =~ \$[A-Za-z_][A-Za-z0-9_]* ]]; then
    return 0
  fi
  return 1
}
