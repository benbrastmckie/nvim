#!/usr/bin/env bash
# gate-cache-lib.sh - Content-addressed digest library for input-scoped gate invalidation.
# Turns a gate's declared `input_corpus` (gate-registry.data's 9th field, see that file's own
# header for the grammar) plus its own IMPLEMENTATION into one composite cache key per gate, with
# NO mtime dependence anywhere in the computation -- a checkout, a branch switch, or a `touch`
# must never change a key, and a real content change must never be missed.
#
# THE CACHE STORE (gate_cache_entry_read/write/invalidate below): verify-deploy.sh's
# --skip-unchanged flag is this library's first and, as of this writing, only caller. The store
# lives at `<root>/specs/.gate-cache/gate<N>.json`, one file per gate id -- NEVER under
# `.claude/**`, which `deploy-headless.sh` regenerates immediately before every `verify-deploy.sh`
# run that matters, so a cache placed there would always read back empty on exactly the runs
# this feature exists to speed up. `specs/` is never touched by deploy-headless.sh and is already
# the home of one structurally identical precedent -- `.orchestrator-deploy-ledger.json`
# (`lib/deploy-ledger-lib.sh`): durable, MACHINE-LOCAL, cross-invocation state, gitignored not
# because it is disposable but because it describes this machine's own deploy state and would
# mislead if read back on another clone. The gate cache is the same kind of thing for the same
# reason. Each entry is written ATOMICALLY (temp file in the same directory, then `mv -f`), so a
# reader never observes a partially-written entry -- there is no "partial read" failure mode to
# guard against separately; a crash between write and rename simply leaves no destination file,
# which reads as an ordinary miss. Every read also validates `format_version` against
# GATE_CACHE_FORMAT_VERSION, so a future change to the composite-key algorithm invalidates every
# existing entry instead of silently matching stale keys computed under a different algorithm.
#
# Rejected store-location candidates (recorded so a future reader does not re-litigate this):
#   - Inside `.claude/**` (e.g. `.claude/.gate-cache/`): wiped by every `deploy-headless.sh` run,
#     which runs immediately before every `verify-deploy.sh` invocation that matters. A cache
#     that cannot survive the one event that precedes its every real use is not a cache.
#   - A bare repo-root `.gate-cache/` (sibling of `.claude/`, not under `specs/`): would work
#     mechanically, but `specs/` already carries the established, gitignored, machine-local
#     "ephemeral orchestrator runtime state" class (`scripts/lib/runtime-file-patterns.sh`) and
#     its one durable-but-machine-local sibling (the deploy ledger) that this store matches in
#     kind; a second, independently-justified root-level convention would duplicate that policy
#     surface for no benefit.
#   - `/tmp` or another non-repo-local location: does not survive a reboot, is not scoped to
#     this repo (a second clone or worktree would collide or share a cache that does not apply to
#     it), and is explicitly the kind of location `.orchestrator-deploy-ledger.json`'s own
#     rejected-alternatives note already excludes for the identical reason.
#
# This library's lower half (corpus resolution, the two digests, the composite key -- everything
# above this point) remains pure computation with no file-mutating side effect; only the
# functions in the "Cache store" section below ever write or delete a file.
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
#   gate_cache_store_dir <root>
#     Echoes the store's directory path (`<root>/specs/.gate-cache`). Pure path computation,
#     creates nothing.
#
#   gate_cache_entry_path <gate_id> <root>
#     Echoes the entry file path for <gate_id> (`<store_dir>/gate<gate_id>.json`).
#
#   gate_cache_entry_read <gate_id> <root>
#     Reads <gate_id>'s entry, if any. On a valid, parseable, format-version-matching entry,
#     sets the globals GATE_CACHE_ENTRY_KEY and GATE_CACHE_ENTRY_TIMESTAMP and returns 0. On
#     ANY other outcome -- no entry file, unreadable file, malformed JSON, a gate_id field that
#     does not match the id requested, or a format_version mismatch -- clears both globals to
#     empty and returns 1. Every failure mode collapses to the same "miss" signal (return 1):
#     callers never need to distinguish "never cached" from "cache corrupted" from "cache stale
#     by format version," since all three demand the identical response (run the gate for
#     real). Requires `jq`; if `jq` is unavailable this always returns 1 (fail-open to "always a
#     miss," never a false hit).
#
#   gate_cache_entry_write <gate_id> <root> <composite_key>
#     Writes a green entry for <gate_id> atomically: builds the JSON in a temp file inside the
#     SAME directory as the real entry (so the final `mv -f` is an atomic same-filesystem
#     rename, never a cross-device copy), then renames it into place. Creates the store
#     directory (`mkdir -p`) if it does not yet exist. A caller must only call this after
#     confirming the gate completed with zero findings and zero failures in THIS run -- this
#     function itself does not re-check that; it trusts the caller's verdict and simply records
#     it. No-ops (fails open, returns 1, writes nothing) if `jq` is unavailable or the temp
#     write/rename fails for any reason -- a cache write that cannot be trusted to have
#     succeeded must never silently leave a half-written or stale entry in place.
#
#   gate_cache_entry_invalidate <gate_id> <root>
#     Deletes <gate_id>'s entry file if present. A no-op, not an error, if no entry exists.
#     Called whenever a gate that was actually dispatched did NOT complete cleanly (failed,
#     warned, timed out) or did not run its real check at all (its own internal SKIP guard) --
#     any stale entry for that id must not survive to be consulted next time.
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

# Bumping this invalidates EVERY existing cache entry on the next read (format_version
# mismatch is treated identically to "no entry" -- see gate_cache_entry_read). Bump it whenever
# the composite-key algorithm itself changes (a new digest component, a changed hashing method,
# a changed corpus-resolution rule) -- never for an unrelated store-format tweak that does not
# change what the key MEANS.
GATE_CACHE_FORMAT_VERSION=1

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

# Per-process memoization, keyed by "<spec>\x1e<root>" (a byte unlikely to appear in either
# component chosen as the join separator, since plain string concatenation could otherwise
# collide two different (spec, root) pairs onto the same cache key). Several real gates declare
# the IDENTICAL input_corpus string (measured: 11 gates share the bare `@extensions` spec, 3
# share `@extensions,.claude`) -- without this, --skip-unchanged's own pre-dispatch consult loop
# would recompute the SAME multi-thousand-file corpus resolution and hash pass once per gate
# that shares it, measured at costing most of the consult loop's own wall clock on a real
# registry (dozens of seconds) even though the underlying filesystem state never changed between
# those calls within one verify-deploy.sh process. This is pure within-process memoization --
# nothing is written to disk, and it has no bearing on the cache STORE (gate_cache_entry_*
# below), which is the cross-invocation persistence layer.
declare -gA GATE_CACHE_CORPUS_DIGEST_MEMO=()

gate_cache_corpus_digest() {
  local _spec="$1" _root="${2:-}" _corpus_file _path _fold _n=0 _memo_key

  if ! gate_cache_git_available; then
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi

  _memo_key="${_spec}"$'\x1e'"${_root}"
  if [ -n "${GATE_CACHE_CORPUS_DIGEST_MEMO[$_memo_key]+x}" ]; then
    echo "${GATE_CACHE_CORPUS_DIGEST_MEMO[$_memo_key]}"
    return 0
  fi

  gate_cache_resolve_corpus "$_spec" "$_root"
  _corpus_file="$GATE_CACHE_RESOLVED_FILE"
  if [ "$GATE_CACHE_UNRESOLVED" = "true" ]; then
    rm -f "$_corpus_file"
    echo "$GATE_CACHE_SENTINEL"
    return 0
  fi

  # Count resolved paths first (cheap, NUL-delimited) -- needed up front to decide whether the
  # batch fast path below is even worth attempting and, if attempted, to verify its output line
  # count matches before trusting it.
  local -a _gc_paths=()
  mapfile -d '' -t _gc_paths < "$_corpus_file" 2>/dev/null
  _n="${#_gc_paths[@]}"

  if [ "$_n" -eq 0 ]; then
    rm -f "$_corpus_file"
    echo "$GATE_CACHE_EMPTY_CORPUS_DIGEST"
    return 0
  fi

  # Both paths below populate the SAME parallel array, _gc_hashes (index-aligned with
  # _gc_paths), rather than building the fold text incrementally -- this keeps the fold FORMAT
  # defined in exactly one place (the paste call further down), so a run that happens to take
  # the fast path and a run that falls back to the slow path can never disagree about what the
  # fold text for the identical (path, hash) set looks like. A per-path-format divergence between
  # the two branches would make the composite key depend on WHICH CODE PATH RAN rather than on
  # actual file content -- never acceptable for a content-addressed digest.
  local -a _gc_hashes=()
  local _gc_batch_ok=false

  # FAST PATH: one `git hash-object --stdin-paths` call hashes every resolved path in a single
  # git process, instead of forking one `git hash-object` subprocess per file -- measured at
  # roughly 8x faster on a 3000+-file corpus (the @extensions/.claude-scoped corpora several
  # real gates declare), where the per-file loop alone cost several seconds and made
  # --skip-unchanged's own cache-consult overhead rival the cost of just running a cheap gate
  # for real. `--stdin-paths` takes NEWLINE-separated input and has no NUL-delimited variant, so
  # this is the one place this library accepts (and documents) the standard, narrow risk every
  # such git-tooling convention accepts: a corpus path containing a literal newline character
  # would misalign this fast path -- never silently, since the exit-code and line-count checks
  # below both gate it -- and fall through to the slow, per-file path, which has no such
  # limitation. On ANY irregularity (nonzero exit -- e.g. one unreadable path aborts the whole
  # batch call -- or an output line count not matching the input path count), this discards the
  # batch attempt entirely and falls through to the per-file loop unchanged; it never trusts a
  # partial or mismatched batch result.
  local _gc_abs_list _gc_hash_output
  local -a _gc_abs_paths=()
  # Bash parameter-expansion prefixing (`${arr[@]/#/prefix}`), NOT a per-element loop with
  # string concatenation: a naive `for p in "${_gc_paths[@]}"; do list="${list}${p}"$'\n'; done`
  # was measured at ~9.7s on a 4815-entry corpus alone (bash string concatenation degrades
  # badly at this scale) -- nearly as expensive as the per-file hash loop this batch path exists
  # to avoid in the first place. The expansion form builds the whole prefixed list in well under
  # a tenth of a second for the identical input.
  if [ -n "$_root" ]; then
    _gc_abs_paths=("${_gc_paths[@]/#/${_root}/}")
  else
    _gc_abs_paths=("${_gc_paths[@]}")
  fi
  _gc_abs_list="$(printf '%s\n' "${_gc_abs_paths[@]}")"
  if _gc_hash_output="$(printf '%s' "$_gc_abs_list" | git hash-object --stdin-paths 2>/dev/null)"; then
    mapfile -t _gc_hashes <<< "$_gc_hash_output"
    [ "${#_gc_hashes[@]}" -eq "$_n" ] && _gc_batch_ok=true
  fi

  if [ "$_gc_batch_ok" = "false" ]; then
    _gc_hashes=()
    for _path in "${_gc_paths[@]}"; do
      local _abs="$_path"
      [ -n "$_root" ] && _abs="$_root/$_path"
      _gc_hashes+=("$(gate_cache_hash_file "$_abs")")
    done
  fi
  rm -f "$_corpus_file"

  # Vectorized path<TAB>hash join via `paste`, NOT a per-entry string-concatenation loop (the
  # SAME O(n)-with-large-constant cost already measured and avoided above for building the
  # absolute-path list). TAB, not NUL, separates a path from its hash on each line -- GNU
  # paste's `-d` cannot emit a literal NUL byte (a shell argv cannot carry one either), and a
  # tab is already this codebase's established field separator elsewhere (gate-registry.data,
  # for one); no path in any real corpus this library resolves is expected to contain a literal
  # tab. Determinism is NOT sensitive to this particular byte choice: it only needs to be the
  # same choice on every invocation, which it is.
  _fold="$(paste -d $'\t' <(printf '%s\n' "${_gc_paths[@]}") <(printf '%s\n' "${_gc_hashes[@]}"))"

  # Sort the fold's lines for a path-order-independent digest (gate_registry_shared_corpus_build
  # and git ls-files already emit in a stable order, but sorting here makes that an assumption
  # this library does not depend on).
  local _gc_result
  _gc_result="$(gate_cache_hash_text "$(printf '%s\n' "$_fold" | sort)")"
  GATE_CACHE_CORPUS_DIGEST_MEMO["$_memo_key"]="$_gc_result"
  echo "$_gc_result"
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

# ──────────────────────────────────────────────────────────────────────────────────────────────
# Cache store
# ──────────────────────────────────────────────────────────────────────────────────────────────

gate_cache_jq_available() { command -v jq >/dev/null 2>&1; }

gate_cache_store_dir() {
  local _root="$1"
  echo "${_root}/specs/.gate-cache"
}

gate_cache_entry_path() {
  local _gate_id="$1" _root="$2"
  echo "$(gate_cache_store_dir "$_root")/gate${_gate_id}.json"
}

# shellcheck disable=SC2034  # out-parameter: set here, read by this library's own callers
# (verify-deploy.sh, test-gate-cache-lib.sh), never read within this file itself.
GATE_CACHE_ENTRY_KEY=""
# shellcheck disable=SC2034  # out-parameter, same reason as GATE_CACHE_ENTRY_KEY immediately above.
GATE_CACHE_ENTRY_TIMESTAMP=""

# gate_cache_entry_read <gate_id> <root> -- see this library's header for the full contract.
# Direct out-parameters (GATE_CACHE_ENTRY_KEY, GATE_CACHE_ENTRY_TIMESTAMP), never via command
# substitution -- same reason as GATE_CACHE_UNRESOLVED/GATE_CACHE_RESOLVED_FILE above (a
# function's global assignments do not survive a `$(...)` subshell boundary).
gate_cache_entry_read() {
  local _gate_id="$1" _root="$2" _path _raw _file_gate_id _file_version _gc_key _gc_ts _gc_verdict
  GATE_CACHE_ENTRY_KEY=""
  GATE_CACHE_ENTRY_TIMESTAMP=""

  if ! gate_cache_jq_available; then
    return 1
  fi
  _path="$(gate_cache_entry_path "$_gate_id" "$_root")"
  [ -f "$_path" ] || return 1
  [ -r "$_path" ] || return 1

  # One jq call, tab-separated fields -- avoids four separate jq invocations per read and
  # avoids any ambiguity from a key/timestamp value that happens to contain whitespace (tabs
  # cannot appear in valid JSON string content without being escaped, so splitting on a literal
  # tab this script itself inserts is safe).
  _raw="$(jq -r '[(.gate_id // ""), (.format_version // -1), (.key // ""), (.timestamp // ""), (.verdict // "")] | @tsv' "$_path" 2>/dev/null)" || return 1
  [ -n "$_raw" ] || return 1

  IFS=$'\t' read -r _file_gate_id _file_version _gc_key _gc_ts _gc_verdict <<< "$_raw"

  [ "$_file_gate_id" = "$_gate_id" ] || return 1
  [ "$_file_version" = "$GATE_CACHE_FORMAT_VERSION" ] || return 1
  [ "$_gc_verdict" = "green" ] || return 1
  [ -n "$_gc_key" ] || return 1

  # shellcheck disable=SC2034  # out-parameters: read by this library's own callers, not here.
  GATE_CACHE_ENTRY_KEY="$_gc_key"
  # shellcheck disable=SC2034  # out-parameter, same reason as the line immediately above.
  GATE_CACHE_ENTRY_TIMESTAMP="$_gc_ts"
  return 0
}

# gate_cache_entry_write <gate_id> <root> <composite_key> -- see this library's header for the
# full contract (atomic same-directory write-then-rename, mkdir -p, fail-open on any error).
gate_cache_entry_write() {
  local _gate_id="$1" _root="$2" _key="$3" _dir _path _tmp _ts

  if ! gate_cache_jq_available; then
    return 1
  fi
  [ -n "$_key" ] && [ "$_key" != "$GATE_CACHE_SENTINEL" ] || return 1

  _dir="$(gate_cache_store_dir "$_root")"
  mkdir -p "$_dir" 2>/dev/null || return 1
  _path="$(gate_cache_entry_path "$_gate_id" "$_root")"
  # Temp file in the SAME directory as the real entry -- required for `mv` to be an atomic
  # same-filesystem rename rather than a cross-device copy-then-delete (which is not atomic and
  # would reintroduce exactly the partial-read window this design otherwise avoids by
  # construction).
  _tmp="$(mktemp "${_dir}/.gate${_gate_id}.json.tmp.XXXXXX" 2>/dev/null)" || return 1
  _ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if ! jq -n \
      --arg gate_id "$_gate_id" \
      --argjson format_version "$GATE_CACHE_FORMAT_VERSION" \
      --arg key "$_key" \
      --arg verdict "green" \
      --arg timestamp "$_ts" \
      '{gate_id: $gate_id, format_version: $format_version, key: $key, verdict: $verdict, timestamp: $timestamp}' \
      > "$_tmp" 2>/dev/null; then
    rm -f "$_tmp"
    return 1
  fi

  mv -f "$_tmp" "$_path" 2>/dev/null || { rm -f "$_tmp"; return 1; }
  return 0
}

# gate_cache_entry_invalidate <gate_id> <root> -- see this library's header. A no-op (not an
# error) if no entry exists.
gate_cache_entry_invalidate() {
  local _gate_id="$1" _root="$2" _path
  _path="$(gate_cache_entry_path "$_gate_id" "$_root")"
  rm -f "$_path" 2>/dev/null
  return 0
}
