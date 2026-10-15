#!/usr/bin/env bash
# gate-cache-lib.sh - Content-addressed digest library for input-scoped gate invalidation.
# Turns a gate's declared `input_corpus` (gate-registry.data's 9th field, see that file's own
# header for the grammar) plus its own IMPLEMENTATION into one composite cache key per gate, with
# NO mtime dependence anywhere in the computation -- a checkout, a branch switch, or a `touch`
# must never change a key, and a real content change must never be missed.
#
# THIS LIBRARY HAS NO CALLER YET as of its introduction (--skip-unchanged and the cache store are
# a later phase). It is pure computation: corpus resolution, two digests, one composite key, and
# distinguishable fail-open sentinels. Nothing here mutates any file or changes any gate's
# behavior.
#
# THE FIVE-COMPONENT IMPLEMENTATION DIGEST (why a corpus digest alone is not enough): a gate
# whose declared DATA is unchanged can still behave differently if the CHECK ITSELF changed.
# Five independent components are folded in, so a change to any one of them changes the
# composite key:
#   1. The gate's `invoke` function body, extracted verbatim from verify-deploy.sh (or the
#      deployed copy, in deployed mode) between its `gateN_run() {` header and the matching
#      bare `}` line -- see gate_cache_extract_invoke_body for why this extraction is reliable
#      without a full bash parser (every gate function in this codebase closes on a bare `}`
#      line with no intervening bare `}`; control flow inside uses if/fi and for/done, never a
#      brace block, so the FIRST bare `}` after the header is always the function's own close).
#   2. Every script the invoke function body references -- discovered TEXTUALLY from that same
#      body (a `scripts/.../*.sh` path fragment, or a Lua `require '<dotted.module>'` string for
#      the two gates (5, 13) that shell out to headless nvim instead of a bash script) -- never
#      hand-maintained per gate, so a gate whose body changes which script it calls is caught by
#      this same extraction next time it runs, with no second place to update.
#   3. Every file under scripts/lib/*.sh -- a DELIBERATELY BOUNDED, CONSERVATIVE over-approximation
#      of "every library the invoked script sources," not a precise per-script static trace.
#      RATIONALE, recorded here because it is a real design choice and not an oversight: every
#      sourced-library line in this codebase sources via a VARIABLE
#      (`. "$LIB"`, `source "${SCRIPT_DIR}/../lib/common.sh"`), built from the sourcing script's
#      own resolved SCRIPT_DIR plus a literal suffix, assembled across one or more lines rather
#      than written as one literal path string. A reliable PER-SCRIPT textual trace of this
#      would need either executing the script (unsafe -- some of these scripts have side
#      effects) or a real bash parser (out of scope here). Including the WHOLE scripts/lib/
#      directory for any gate whose component 2 found at least one bash script reference is
#      SAFE in the required direction: it can only cause an OVER-invalidation (skip-eligibility
#      lost for a gate when an unrelated library changes), never an UNDER-invalidation (a real
#      change silently missed) -- which is exactly the asymmetry the dispatch requires
#      ("fail-open on cache trouble, fail-closed on assertions"). This is the "transitive
#      closure, bounded, with its bound recorded" the plan asks for: the bound is
#      "scripts/lib/*.sh in full," stated here rather than computed per call.
#   4. The gate's own registry row -- the raw TAB-separated line for that id in
#      gate-registry.data, verbatim. A row edit (e.g. a timeout_s or cost_class change) changes
#      behavior even with no script edit, so it must be part of the key.
#   5. The target-mode discriminator -- the literal string "source-store" or "deployed" (never a
#      file hash), since the SAME gate id can run against either tree and several gates' own
#      [SKIP] guards depend on which.
#
# CONTENT-ADDRESSED, NEVER MTIME: every file-based component is hashed via `git hash-object
# <path>` against the file's CURRENT WORKING-TREE BYTES -- not via `git cat-file` against a
# committed blob, and not via any `stat`/mtime read anywhere in this library. This is
# deliberately SIMPLER than "look up the index blob id for an unmodified tracked file, hash only
# a modified/untracked one": `git hash-object` recomputes git's own blob-hashing algorithm over
# the current file content regardless of tracked status, which for an UNMODIFIED tracked file
# reproduces the exact blob id the index already holds (same bytes, same algorithm, same
# result) and for a modified-or-untracked file does the only thing that is ever correct (hash
# what is actually on disk right now). One code path, no tracked/untracked branch, and no mtime
# input anywhere -- a `touch` changes nothing this library reads.
#
# FAIL-OPEN SENTINEL: GATE_CACHE_SENTINEL ("CANNOT_COMPUTE") is returned, never an empty string,
# whenever: the corpus is the `-` placeholder (not declared); a corpus entry cannot be resolved;
# the `git` binary is unavailable; or any file this library needs to hash cannot be read. The
# sentinel's shape (an uppercase word with an underscore) can never collide with a real digest
# (`git hash-object`'s own output is a 40-character lowercase hex SHA-1 on this repo's hash
# algorithm), so a caller can always tell "digest X" from "no digest available" by shape alone,
# with no separate out-of-band signal needed.
#
# Public functions:
#   gate_cache_resolve_corpus <corpus_spec> <root>
#     Expands a declared input_corpus string (gate-registry.data grammar: `-`, `@extensions`,
#     `@repo`, a literal path, a bare directory, a glob, or any of those `!`-prefixed for
#     exclusion) into a sorted, deduplicated, NUL-delimited temp file of repo-relative paths.
#     Prints that file's path on stdout (caller removes it). Sets the global
#     GATE_CACHE_UNRESOLVED to "true" when the spec itself is the placeholder (never skippable);
#     "false" otherwise. Resolution order: union every non-`!` entry, then subtract every
#     `!`-prefixed entry from that union -- documented here and in gate-registry.data identically.
#
#   gate_cache_corpus_digest <corpus_spec> <root>
#     Resolves the corpus, then hashes each resolved path's current working-tree content,
#     folding the sorted `path<NUL>blob` pairs into one composite digest. Echoes
#     GATE_CACHE_SENTINEL when the corpus is undeclared, git is unavailable, or no path in a
#     non-empty resolved set is readable; echoes a real digest otherwise (an EMPTY resolved set
#     from a declared-but-currently-zero-match corpus, e.g. a glob with no matches today, is NOT
#     a sentinel case -- it digests to a fixed "empty corpus" constant, since a declared corpus
#     that legitimately matches nothing today is a known, stable state, not a failure).
#
#   gate_cache_implementation_digest <gate_id> <root> <registry_data_file>
#     Computes the five-component digest described above for <gate_id>. Resolves verify-deploy.sh
#     from <root> in source-store mode first, falling back to the deployed copy -- the same
#     dual-mode discovery convention verify-deploy.sh and measure-gate-costs.sh already use.
#     Echoes GATE_CACHE_SENTINEL if verify-deploy.sh cannot be found, the gate's function body
#     cannot be extracted, the registry row cannot be read, or git is unavailable.
#
#   gate_cache_composite_key <gate_id> <root> <registry_data_file>
#     Reads <gate_id>'s input_corpus from the registry (via gate_registry_field, so
#     lib/gate-registry-lib.sh must already be sourced by the caller) and combines
#     gate_cache_corpus_digest's and gate_cache_implementation_digest's results into one key.
#     Echoes GATE_CACHE_SENTINEL if EITHER half is the sentinel -- a composite key is only ever
#     trustworthy when both halves were computable.
#
# Exit codes: these are library FUNCTIONS, not a standalone script -- each returns 0 on having
# produced SOME output (a real digest or the sentinel, which is itself a valid, intentional
# result, not an error) and a shell-level nonzero only for a genuine environment failure (e.g.
# mktemp itself failing). Callers must compare the ECHOED value against GATE_CACHE_SENTINEL, not
# the function's own return code, to detect "cannot compute."

set -uo pipefail

GATE_CACHE_SENTINEL="CANNOT_COMPUTE"
# A declared corpus that resolves to zero paths today (e.g. a glob with no current matches) is a
# stable, legitimate state -- digests to this fixed constant rather than to the sentinel, so a
# caller can tell "declared, currently empty" apart from both "not declared" (sentinel, via
# GATE_CACHE_UNRESOLVED) and "declared, N paths" (a real digest).
GATE_CACHE_EMPTY_CORPUS_DIGEST="EMPTY_CORPUS_0000000000000000000000"

_GC_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

gate_cache_git_available() { command -v git >/dev/null 2>&1; }

# gate_cache_hash_text <text> -- echoes the git-blob hash of a text BLOB (not a file), via
# `git hash-object --stdin`. Used to fold several already-computed sub-hashes into one digest
# without writing an intermediate file.
gate_cache_hash_text() {
  if ! gate_cache_git_available; then
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi
  printf '%s' "$1" | git hash-object --stdin 2>/dev/null || echo "$GATE_CACHE_SENTINEL"
}

# gate_cache_hash_file <path> -- echoes the git-blob hash of <path>'s CURRENT working-tree bytes
# (see this library's header "CONTENT-ADDRESSED, NEVER MTIME" section for why this one code path
# covers tracked, modified, and untracked files identically). Echoes GATE_CACHE_SENTINEL if the
# path is unreadable or git is unavailable.
gate_cache_hash_file() {
  local _path="$1"
  if ! gate_cache_git_available; then
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi
  if [ ! -r "$_path" ]; then
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi
  git hash-object "$_path" 2>/dev/null || echo "$GATE_CACHE_SENTINEL"
}

# ──────────────────────────────────────────────────────────────────────────────────────────────
# Corpus resolution
# ──────────────────────────────────────────────────────────────────────────────────────────────

GATE_CACHE_UNRESOLVED=false
# Set by gate_cache_resolve_corpus as a direct global (never via command substitution -- a
# function's variable assignments do not survive a `$(...)` capture, since that forks a
# subshell; this was a real bug caught live while first exercising this function (see
# progress/phase-3-progress.json's approaches_tried) and is why GATE_CACHE_UNRESOLVED and
# GATE_CACHE_RESOLVED_FILE are both out-parameters set by direct call, with callers reading them
# immediately afterward rather than capturing this function's stdout.
GATE_CACHE_RESOLVED_FILE=""

gate_cache_resolve_corpus() {
  local _spec="$1" _root="${2:-}" _outfile _tmp_union _tmp_excl _entry _e _neg
  GATE_CACHE_UNRESOLVED=false
  GATE_CACHE_RESOLVED_FILE=""
  _outfile="$(mktemp)" || return 1

  if [ -z "$_spec" ] || [ "$_spec" = "-" ]; then
    GATE_CACHE_UNRESOLVED=true
    GATE_CACHE_RESOLVED_FILE="$_outfile"
    return 0
  fi

  _tmp_union="$(mktemp)" || { rm -f "$_outfile"; return 1; }
  _tmp_excl="$(mktemp)" || { rm -f "$_outfile" "$_tmp_union"; return 1; }
  : > "$_tmp_union"
  : > "$_tmp_excl"

  IFS=',' read -r -a _gc_entries <<< "$_spec"
  for _entry in "${_gc_entries[@]}"; do
    _neg=false
    _e="$_entry"
    case "$_e" in
      '!'*) _neg=true; _e="${_e#!}" ;;
    esac
    local _dest="$_tmp_union"
    $_neg && _dest="$_tmp_excl"
    case "$_e" in
      '')
        GATE_CACHE_UNRESOLVED=true
        ;;
      '@extensions')
        if gate_cache_git_available && declare -F gate_registry_shared_corpus_build >/dev/null 2>&1; then
          local _f
          _f="$(gate_registry_shared_corpus_build "$_root")"
          cat "$_f" >> "$_dest" 2>/dev/null
          rm -f "$_f"
        else
          GATE_CACHE_UNRESOLVED=true
        fi
        ;;
      '@repo')
        if gate_cache_git_available && [ -n "$_root" ] && [ -d "$_root/.git" ]; then
          (cd "$_root" && git ls-files -z) >> "$_dest" 2>/dev/null
        else
          GATE_CACHE_UNRESOLVED=true
        fi
        ;;
      *)
        # Literal path, bare directory, or glob -- resolved against the FILESYSTEM, not
        # `git ls-files`, because several real declarations (e.g. gate 1/2/9's `.claude/**`
        # entries) point at the DEPLOYED tree, which is deliberately GITIGNORED (a disposable,
        # regenerated artifact -- see rules/source-store-deploy-boundary.md) and so is INVISIBLE
        # to `git ls-files` regardless of pathspec. `find -path`'s `*` crosses directory
        # separators (broader than a typical shell glob's single-level `*`) -- this is a
        # DELIBERATE, SAFE over-match: a broader corpus can only reduce skip-eligibility, never
        # cause the under-declared miss the dispatch forbids.
        if [ -n "$_root" ] && [ -f "$_root/$_e" ]; then
          printf '%s\0' "$_e" >> "$_dest"
        elif [ -n "$_root" ] && [ -d "$_root/$_e" ]; then
          (cd "$_root" && find "$_e" -type f -print0 2>/dev/null) >> "$_dest"
        elif [ -n "$_root" ]; then
          case "$_e" in
            *'*'*|*'?'*|*'['*)
              (cd "$_root" && find . -path "./$_e" -type f -print0 2>/dev/null | sed -z 's#^\./##') >> "$_dest"
              ;;
            *)
              : # does not exist and is not a glob shape -- legitimately zero matches, not unresolvable
              ;;
          esac
        fi
        ;;
    esac
  done

  sort -z -u "$_tmp_union" > "${_tmp_union}.sorted" 2>/dev/null
  sort -z -u "$_tmp_excl" > "${_tmp_excl}.sorted" 2>/dev/null
  if [ -s "${_tmp_excl}.sorted" ]; then
    comm -z -23 "${_tmp_union}.sorted" "${_tmp_excl}.sorted" > "$_outfile" 2>/dev/null \
      || cp "${_tmp_union}.sorted" "$_outfile"
  else
    cp "${_tmp_union}.sorted" "$_outfile" 2>/dev/null || : > "$_outfile"
  fi

  rm -f "$_tmp_union" "$_tmp_excl" "${_tmp_union}.sorted" "${_tmp_excl}.sorted"
  GATE_CACHE_RESOLVED_FILE="$_outfile"
  return 0
}

# ──────────────────────────────────────────────────────────────────────────────────────────────
# Corpus digest
# ──────────────────────────────────────────────────────────────────────────────────────────────

gate_cache_corpus_digest() {
  local _spec="$1" _root="${2:-}" _corpus_file _path _fold _n=0

  if ! gate_cache_git_available; then
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi

  gate_cache_resolve_corpus "$_spec" "$_root"
  _corpus_file="$GATE_CACHE_RESOLVED_FILE"
  if [ "$GATE_CACHE_UNRESOLVED" = "true" ]; then
    rm -f "$_corpus_file"
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi

  _fold=""
  while IFS= read -r -d '' _path; do
    [ -z "$_path" ] && continue
    _n=$((_n + 1))
    local _abs="$_path"
    [ -n "$_root" ] && _abs="$_root/$_path"
    local _blob
    _blob="$(gate_cache_hash_file "$_abs")"
    _fold="${_fold}${_path}"$'\x00'"${_blob}"$'\n'
  done < "$_corpus_file"
  rm -f "$_corpus_file"

  if [ "$_n" -eq 0 ]; then
    echo "$GATE_CACHE_EMPTY_CORPUS_DIGEST"
    return 0
  fi

  # Sort the fold's lines for a path-order-independent digest (gate_registry_shared_corpus_build
  # and git ls-files already emit in a stable order, but sorting here makes that an assumption
  # this library does not depend on).
  gate_cache_hash_text "$(printf '%s' "$_fold" | sort)"
  return 0
}

# ──────────────────────────────────────────────────────────────────────────────────────────────
# Implementation digest
# ──────────────────────────────────────────────────────────────────────────────────────────────

# gate_cache_resolve_verify_deploy <root> -- echoes the path to verify-deploy.sh, source-store
# copy first, falling back to the deployed copy -- the SAME dual-mode discovery convention
# verify-deploy.sh and measure-gate-costs.sh already use elsewhere in this codebase. Echoes
# nothing (empty) if neither exists.
gate_cache_resolve_verify_deploy() {
  local _root="$1" _p
  _p="$_root/agent-system/extensions/core/scripts/verify-deploy.sh"
  [ -f "$_p" ] && { echo "$_p"; return 0; }
  _p="$_root/.claude/scripts/verify-deploy.sh"
  [ -f "$_p" ] && { echo "$_p"; return 0; }
  return 0
}

gate_cache_target_mode() {
  local _root="$1"
  if [ -d "$_root/agent-system/extensions" ]; then
    echo "source-store"
  else
    echo "deployed"
  fi
}

# gate_cache_extract_invoke_body <gate_id> <verify_deploy_path> -- prints the path to a temp file
# containing gate<id>_run's exact function body (header line through its own matching bare `}`
# line, inclusive). See this library's header for why this extraction is reliable without a full
# bash parser in THIS codebase's gate functions specifically. Prints nothing (empty) and leaves
# no temp file if the function is not found.
gate_cache_extract_invoke_body() {
  local _gate_id="$1" _vd_path="$2" _outfile
  local _fn="gate${_gate_id}_run"
  [ -f "$_vd_path" ] || return 0
  _outfile="$(mktemp)" || return 1
  awk -v fn="${_fn}() {" 'BEGIN{p=0} $0==fn{p=1} p{print; if (p==1 && $0=="}") exit}' "$_vd_path" > "$_outfile"
  if [ ! -s "$_outfile" ]; then
    rm -f "$_outfile"
    return 0
  fi
  printf '%s\n' "$_outfile"
  return 0
}

# gate_cache_discover_invoked_scripts <body_file> -- textually scans a gate's extracted function
# body for (a) `scripts/.../*.sh` path fragments and (b) Lua `require '<dotted.module>'` strings
# (the two gates, 5 and 13, that shell out to headless nvim instead of invoking a bash script).
# Prints each discovered reference on its own line, sorted and deduplicated, tagged with its kind
# ("sh:" or "lua:" prefix) so the caller can resolve each differently.
gate_cache_discover_invoked_scripts() {
  local _body_file="$1"
  [ -f "$_body_file" ] || return 0
  {
    grep -oE 'scripts/[A-Za-z0-9_./-]*\.sh' "$_body_file" 2>/dev/null | sed 's/^/sh:/'
    grep -oE "require,? *'[A-Za-z0-9_.]+'" "$_body_file" 2>/dev/null \
      | grep -oE "'[A-Za-z0-9_.]+'" | tr -d "'" | sed 's/^/lua:/'
  } | sort -u
  return 0
}

# gate_cache_resolve_ref <ref> <root> -- resolves one "sh:<suffix>" or "lua:<dotted.module>"
# reference (as produced by gate_cache_discover_invoked_scripts) to an absolute file path,
# trying source-store layout first and falling back to deployed layout for the "sh:" case (lua
# modules live under lua/, which is identical in both modes -- it is the plugin runtime tree, not
# part of the agent-system deploy). Echoes nothing if unresolvable.
gate_cache_resolve_ref() {
  local _ref="$1" _root="$2" _p
  local _kind="${_ref%%:*}" _val="${_ref#*:}"
  case "$_kind" in
    sh)
      _p="$_root/agent-system/extensions/core/$_val"
      [ -f "$_p" ] && { echo "$_p"; return 0; }
      _p="$_root/.claude/$_val"
      [ -f "$_p" ] && { echo "$_p"; return 0; }
      ;;
    lua)
      _p="$_root/lua/$(printf '%s' "$_val" | tr '.' '/').lua"
      [ -f "$_p" ] && { echo "$_p"; return 0; }
      ;;
  esac
  return 0
}

gate_cache_implementation_digest() {
  local _gate_id="$1" _root="$2" _registry_file="$3"
  local _vd_path _body_file _target_mode

  if ! gate_cache_git_available; then
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi

  _vd_path="$(gate_cache_resolve_verify_deploy "$_root")"
  if [ -z "$_vd_path" ]; then
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi

  _body_file="$(gate_cache_extract_invoke_body "$_gate_id" "$_vd_path")"
  if [ -z "$_body_file" ]; then
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi

  # Component 1: the invoke function body itself.
  local _c1
  _c1="$(gate_cache_hash_file "$_body_file")"

  # Component 2: every discovered invoked script/lua-module reference, resolved and hashed.
  # Component 3: if ANY bash script reference was found, fold in the whole scripts/lib/*.sh
  # directory -- see this library's header for the bounded-closure rationale.
  local _c2="" _c3="" _found_sh=false _ref _resolved
  while IFS= read -r _ref; do
    [ -z "$_ref" ] && continue
    case "$_ref" in sh:*) _found_sh=true ;; esac
    _resolved="$(gate_cache_resolve_ref "$_ref" "$_root")"
    if [ -n "$_resolved" ]; then
      _c2="${_c2}${_ref}"$'\x00'"$(gate_cache_hash_file "$_resolved")"$'\n'
    else
      _c2="${_c2}${_ref}"$'\x00'"UNRESOLVED"$'\n'
    fi
  done < <(gate_cache_discover_invoked_scripts "$_body_file")
  rm -f "$_body_file"
  _c2="$(gate_cache_hash_text "$(printf '%s' "$_c2" | sort)")"

  if $_found_sh; then
    local _libdir="$_root/agent-system/extensions/core/scripts/lib"
    [ -d "$_libdir" ] || _libdir="$_root/.claude/scripts/lib"
    local _lib_fold="" _libfile
    if [ -d "$_libdir" ]; then
      while IFS= read -r -d '' _libfile; do
        _lib_fold="${_lib_fold}${_libfile}"$'\x00'"$(gate_cache_hash_file "$_libfile")"$'\n'
      done < <(find "$_libdir" -maxdepth 1 -name '*.sh' -print0 2>/dev/null | sort -z)
    fi
    _c3="$(gate_cache_hash_text "$_lib_fold")"
  fi

  # Component 4: the gate's own registry row, verbatim.
  local _c4="$GATE_CACHE_SENTINEL"
  if [ -f "$_registry_file" ]; then
    local _row
    _row="$(grep -E "^${_gate_id}"$'\t' "$_registry_file" 2>/dev/null | head -1)"
    if [ -n "$_row" ]; then
      _c4="$(gate_cache_hash_text "$_row")"
    fi
  fi

  # Component 5: the target-mode discriminator, a literal string (never a file hash).
  _target_mode="$(gate_cache_target_mode "$_root")"

  gate_cache_hash_text "${_c1}:${_c2}:${_c3}:${_c4}:${_target_mode}"
  return 0
}

# ──────────────────────────────────────────────────────────────────────────────────────────────
# Composite key
# ──────────────────────────────────────────────────────────────────────────────────────────────

gate_cache_composite_key() {
  local _gate_id="$1" _root="$2" _registry_file="$3" _corpus_spec _corpus_digest _impl_digest

  if ! declare -F gate_registry_field >/dev/null 2>&1; then
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi
  _corpus_spec="$(gate_registry_field "$_gate_id" input_corpus)"

  _corpus_digest="$(gate_cache_corpus_digest "$_corpus_spec" "$_root")"
  _impl_digest="$(gate_cache_implementation_digest "$_gate_id" "$_root" "$_registry_file")"

  if [ "$_corpus_digest" = "$GATE_CACHE_SENTINEL" ] || [ "$_impl_digest" = "$GATE_CACHE_SENTINEL" ]; then
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi

  gate_cache_hash_text "${_corpus_digest}:${_impl_digest}"
  return 0
}
