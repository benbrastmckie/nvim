#!/usr/bin/env bash
# lint-corpus-scan-lib.sh - Single shared definition of the "collect files to scan" wrapper
# previously copy-pasted, byte-identically, into six of the seven-member lint cluster
# (lint-scoped-commit-boundary.sh, lint-task-lookup-adoption.sh, lint-directory-pathspec-boundary.sh,
# lint-state-writer-boundary.sh, lint-hook-registration-paths.sh, lint-shellcheck.sh --
# lint-branch-gated-sections.sh does not carry this particular wrapper, though it shares the
# wider cluster skeleton Phase 5 extracts separately).
#
# WHY THIS EXISTS: the gate-framework refactor's own shared-corpus-enumeration phase, whose
# stated goal was to "eliminate the duplicated corpus enumeration", instead added this
# byte-identical 12-line call-site block (plus its travelling seven-line comment) to each of
# those six files independently -- it removed duplicate EXECUTION (each lint no longer ran its
# own independent `find`) by adding duplicate SOURCE (each lint still carries its own copy of the
# call-site wrapper). This library is the correction: one definition, one call site per lint,
# each lint's own copy deleted.
#
# CONTRACT (mirrors lib/common.sh's own contract verbatim):
#   - Sets no shell options (no `set -e`, no `set -u`, no `set -o pipefail`) -- sourcing this
#     file must never change the calling shell's error-handling behavior.
#   - Never calls `exit` -- a caller decides what an empty or error result means for its own
#     exit-code contract (this cluster's lints exit 2 on a genuinely bad scan path; this library
#     reports that condition via a non-zero return, never by exiting the caller's process out
#     from under it).
#   - Requires `lib/common.sh` to already be sourced by the caller BEFORE this file (for
#     `common_shared_corpus_available` / `common_shared_corpus_files`); this file does not
#     source it itself, to avoid a double-source ordering dependency.
#
# Usage (from a caller that has already sourced lib/common.sh and built its own SCAN_PATHS array):
#
#   declare -a FILES=()
#   lint_corpus_scan_collect_files FILES "$DEFAULT_SCAN" '*.md' '*.sh' -- "${SCAN_PATHS[@]}"
#   rc=$?
#   # rc == 0: FILES now holds the sorted, matched file list (NUL-safe paths; a path containing a
#   #          newline is not supported, matching every caller's pre-existing `find`-based
#   #          enumeration, which never supported one either).
#   # rc == 2: a path in SCAN_PATHS was neither a file nor a directory; the caller's own
#   #          "ERROR: scan path not found: <path>" + `exit 2` convention is unchanged -- this
#   #          library reports the failing path on its own stderr line so the caller can simply
#   #          `exit 2` without re-deriving which path failed.
#
# lint_corpus_scan_collect_files OUTVAR DEFAULT_SCAN PATTERN [PATTERN...] -- SCAN_PATH [SCAN_PATH...]
#
#   OUTVAR        Name of the caller's array variable to populate (via `local -n` nameref,
#                 matching the established convention in lib/gate-registry-lib.sh). Cleared and
#                 repopulated; never appended to.
#   DEFAULT_SCAN  The caller's own default scan root (its $DEFAULT_SCAN, e.g.
#                 "$PROJECT_ROOT/agent-system/extensions"), used only to recognize the
#                 unmodified-default-scan fast path below.
#   PATTERN...    One or more `find -name`-style glob patterns (e.g. '*.md' '*.sh'). At least one
#                 is required.
#   --            Literal separator between PATTERN... and SCAN_PATH....
#   SCAN_PATH...  The caller's own resolved SCAN_PATHS array elements, expanded in order.
#
# BEHAVIOR: when SCAN_PATH... is exactly one element equal to DEFAULT_SCAN (the caller's
# unmodified default scan, i.e. no explicit path argument was passed on the lint's own command
# line) AND `common_shared_corpus_available` reports true, reuses verify-deploy.sh's already-built
# whole-corpus enumeration via `common_shared_corpus_files` instead of a second independent
# `find` -- this is the Phase 9 ("Shared Corpus Enumeration") optimization every one of the six
# callers already carried inline. Otherwise (an explicit path argument was given -- a standalone
# invocation with a custom root, or a fixture test's scratch directory -- or the shared cache is
# unavailable) falls through to a per-path `find`/file-existence walk, exactly as every caller's
# own pre-extraction fallback did.
lint_corpus_scan_collect_files() {
    local _lcs_outvar="$1"; shift
    local _lcs_default_scan="$1"; shift

    local -a _lcs_patterns=()
    while [[ $# -gt 0 ]] && [[ "$1" != "--" ]]; do
        _lcs_patterns+=("$1")
        shift
    done
    if [[ "${1:-}" != "--" ]]; then
        echo "ERROR: lint_corpus_scan_collect_files: missing '--' separator before scan paths" >&2
        return 2
    fi
    shift # consume --
    local -a _lcs_scan_paths=("$@")

    if [[ "${#_lcs_patterns[@]}" -eq 0 ]]; then
        echo "ERROR: lint_corpus_scan_collect_files: at least one glob PATTERN is required" >&2
        return 2
    fi

    local -n _lcs_out="$_lcs_outvar"
    _lcs_out=()
    local _lcs_scan_path _lcs_found _lcs_pat _lcs_i
    local -a _lcs_find_name_expr=()

    if [[ "${#_lcs_scan_paths[@]}" -eq 1 ]] \
        && [[ "${_lcs_scan_paths[0]}" == "${_lcs_default_scan:-}" ]] \
        && common_shared_corpus_available; then
        # Phase 9 ("Shared Corpus Enumeration"): verify-deploy.sh already walked the whole
        # agent-system/extensions tree once for the whole gate battery -- reuse it here instead
        # of a second independent `find`. Only engaged for the unmodified default scan root (no
        # explicit scan-path argument); any explicit path (standalone invocation with a custom
        # root, or a fixture test's scratch directory) falls through to the branch below exactly
        # as before, so standalone invocability and the find-based fixture path are both
        # preserved.
        while IFS= read -r -d '' _lcs_found; do
            _lcs_out+=("$_lcs_found")
        done < <(common_shared_corpus_files "${_lcs_patterns[@]}" | sort -z)
        return 0
    fi

    _lcs_i=0
    for _lcs_pat in "${_lcs_patterns[@]}"; do
        if [[ "$_lcs_i" -gt 0 ]]; then
            _lcs_find_name_expr+=(-o)
        fi
        _lcs_find_name_expr+=(-name "$_lcs_pat")
        _lcs_i=$((_lcs_i + 1))
    done

    for _lcs_scan_path in "${_lcs_scan_paths[@]}"; do
        if [[ -d "$_lcs_scan_path" ]]; then
            while IFS= read -r _lcs_found; do
                _lcs_out+=("$_lcs_found")
            done < <(find "$_lcs_scan_path" -type f \( "${_lcs_find_name_expr[@]}" \) 2>/dev/null | sort)
        elif [[ -f "$_lcs_scan_path" ]]; then
            _lcs_out+=("$_lcs_scan_path")
        else
            echo "ERROR: scan path not found: $_lcs_scan_path" >&2
            return 2
        fi
    done
    return 0
}
