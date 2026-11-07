#!/usr/bin/env bash
# git-corpus-enum-lib.sh - Single shared definition of "the set of files a git-backed lint
# should scan under a path scope", for any lint that enumerates its scan corpus via
# `git ls-files PATH_SCOPE`.
#
# THE DEFECT THIS CORRECTS: `git ls-files PATH_SCOPE` reads the git INDEX. For a file that
# exists on disk but is not yet git-tracked, that enumeration returns zero rows, even though the
# path itself exists (so a caller's own `[[ -e "$enum_dir" ]]` existence guard still passes).
# A caller whose scan loop is fed solely from that enumeration therefore iterates zero times and
# reports a clean verdict for a file it never actually examined -- a FALSE CLEAN, with no
# diagnostic of any kind. This defeats exactly the self-hygiene checks a newly created file most
# needs (a new blocking write-time hook linting its own just-written source before it is ever
# committed is the motivating case). The remedy -- enumerate the UNION of tracked and
# untracked-but-not-ignored paths -- is not new to this repo: script-inventory.sh's
# `enumerate_candidates`/`enumerate_untracked_matches` already implements it, including the
# deliberate `--exclude-standard` boundary that keeps gitignored build output and the disposable
# `.claude/` deploy tree excluded. This library extracts that same shape into one shared
# definition so check-record-versioning.sh and check-task-references.sh cannot drift from each
# other's enumeration semantics the way they had drifted from script-inventory.sh's.
#
# KNOWN ADJACENT ENUMERATION SITES (recorded here, once, as the durable home for this audit --
# see context/patterns/context-discovery.md's model for where audit narrative like this belongs;
# not duplicated into docs/reference/utility-scripts-inventory.md):
#
#   - check-record-versioning.sh, check-task-references.sh: BOTH shared this exact defect (a
#     byte-identical `scan_tree` shape, the same `PATH_SCOPE` contract, the same `-e`-only
#     existence guard) and both are wired to this library's `git_corpus_enum` as the fix.
#   - check-extension-docs.sh: an ADJACENT instance (its "script file on disk not in
#     provides.scripts" rule enumerates via `git ls-files`, so an uncommitted new script is
#     invisible to that manifest-declaration-parity check), but a different contract
#     (declaration parity, not a content scan) and a different gate. Named but deliberately NOT
#     fixed here -- left to its own record rather than widening this library's footprint into
#     gate 3's territory without that change's own fixture coverage.
#   - script-inventory.sh: NOT defective -- already enumerates the tracked/untracked union and
#     already discloses the untracked set. This is the precedent this library generalizes, not a
#     sibling defect.
#   - check-runtime-file-tracking.sh: NOT defective -- it uses `git ls-files` to *determine
#     tracking status*; untracked-ness is the signal that check exists to detect, not a blind
#     spot in it.
#   - lint/lint-shellcheck.sh: NOT defective in the case that matters -- its default repo-wide
#     enumeration is tracked-only by documented design, but an explicit `SCAN_PATHS` argument
#     switches it to `find`, which already sees untracked files.
#   - assess-repo-health.sh, context-reachability.sh: tracked-only with a documented `find`
#     fallback outside a work tree, but both produce a health/reachability REPORT rather than a
#     clean/dirty verdict on a specific named file, so there is no false-clean claim to make.
#     Not changed here; not asserted defect-free beyond that reasoning.
#
# CONTRACT (mirrors lib/common.sh's and lib/lint-corpus-scan-lib.sh's own contracts verbatim):
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this
#     file must never change the calling shell's error-handling behavior.
#   - Never calls `exit` -- a caller decides what an empty result or a missing git binary means
#     for its own exit-code contract; this library only ever returns via its functions' own exit
#     status or stdout.
#   - Reports an unusable git invocation (not inside a work tree, git not on PATH) via an empty
#     stdout result, never by writing to stderr itself -- diagnostics of "what did I not scan and
#     why" are this library's STATED PURPOSE for a caller to compose and print, not something
#     this library prints unprompted.
#
# Usage (from a caller that has already resolved REPO_ROOT and a PATH_SCOPE / enum_path):
#
#   done < <(git_corpus_enum "$REPO_ROOT" "$enum_path")
#       Drop-in replacement for `done < <(git -C "$REPO_ROOT" ls-files "$enum_path" 2>/dev/null)`
#       -- identical newline-delimited, repo-root-relative, sort -u'd output shape, so no
#       existing scan-loop body needs to change.
#
#   git_corpus_unenumerated_report "$REPO_ROOT" "$enum_path"
#       For a SCOPED (non-".") enum_path only: one line per on-disk regular file under that path
#       the union above does NOT include, in the form
#         [SKIP] <rel>: gitignored (not scanned)
#       Silent (empty stdout) when the exclusion set is empty. Intended for the caller to
#       redirect to stderr.
#
#   git_corpus_untracked_count "$REPO_ROOT" "$enum_path"
#       Prints the integer count of untracked-but-included paths in the union, for a caller's
#       own disclosure line.

# git_corpus_enum <repo_root> <enum_path>
# Prints, newline-delimited and `sort -u`'d, repo-root-relative paths: the union of
# `git -C <repo_root> ls-files <enum_path>` (tracked) and
# `git -C <repo_root> ls-files --others --exclude-standard <enum_path>` (untracked, not
# gitignored). `--exclude-standard` honors .gitignore, so gitignored content stays excluded.
git_corpus_enum() {
  local repo_root="$1"
  local enum_path="$2"
  {
    git -C "$repo_root" ls-files "$enum_path" 2>/dev/null
    git -C "$repo_root" ls-files --others --exclude-standard "$enum_path" 2>/dev/null
  } | sort -u
}

# git_corpus_untracked_count <repo_root> <enum_path>
# Prints the count of untracked-but-not-ignored paths the union above adds beyond the tracked
# set alone, for a caller's own "N untracked file(s) included" disclosure line.
git_corpus_untracked_count() {
  local repo_root="$1"
  local enum_path="$2"
  git -C "$repo_root" ls-files --others --exclude-standard "$enum_path" 2>/dev/null | sort -u | wc -l | tr -d ' '
}

# git_corpus_unenumerated_report <repo_root> <enum_path>
# For a SCOPED (non-".") enum_path: walks every on-disk regular file under
# <repo_root>/<enum_path> (or, when enum_path itself names a single file, that file alone) and
# prints one "  [SKIP] <rel>: gitignored (not scanned)" line per file the union from
# git_corpus_enum does NOT include. A repo-wide ("." ) enum_path is deliberately not walked here
# (the exclusion set there is the whole disposable deploy tree and is noise, not signal) --
# callers only invoke this in PATH_SCOPE mode, per this library's own header. Silent (no output)
# when every on-disk file under the scope is already covered by the union.
git_corpus_unenumerated_report() {
  local repo_root="$1"
  local enum_path="$2"
  local scope_dir="$repo_root/$enum_path"

  [[ "$enum_path" == "." ]] && return 0
  [[ -e "$scope_dir" ]] || return 0

  local -A included=()
  local rel
  while IFS= read -r rel; do
    [[ -z "$rel" ]] && continue
    included["$rel"]=1
  done < <(git_corpus_enum "$repo_root" "$enum_path")

  local on_disk
  if [[ -f "$scope_dir" ]]; then
    on_disk="$enum_path"
    if [[ -z "${included[$on_disk]:-}" ]]; then
      echo "  [SKIP] $on_disk: gitignored (not scanned)"
    fi
    return 0
  fi

  while IFS= read -r -d '' abs; do
    rel="${abs#"$repo_root"/}"
    if [[ -z "${included[$rel]:-}" ]]; then
      echo "  [SKIP] $rel: gitignored (not scanned)"
    fi
  done < <(find "$scope_dir" -type f -print0 2>/dev/null | sort -z)
}
