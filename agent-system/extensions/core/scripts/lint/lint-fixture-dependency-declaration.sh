#!/usr/bin/env bash
# lint-fixture-dependency-declaration.sh - Detect a scripts/tests/*.sh fixture suite whose
# hand-maintained copy-into-sandbox list omits a MANDATORY scripts/lib/*.sh dependency of a
# script the suite itself copies.
#
# WHY THIS EXISTS
# ----------------
# A fixture suite under scripts/tests/ that copies helper scripts into a sandbox declares WHICH
# helpers to copy as a curated, hand-maintained list (an array, or an open-coded pair of
# require_file/cp lines). When a copied script gains a new mandatory `source`/`.` dependency,
# nothing updates that list, and the suite fails at RUN TIME with a bare "No such file or
# directory" whose cause is invisible from the failure text. Three confirmed historical
# instances of exactly this drift (each a missing lib/project-number-inuse.sh, each hand-repaired
# by appending the one missing line) motivate this lint-time detector, which reports the drift
# before a run hits it.
#
# THE TWO DECLARATION SHAPES (both handled by one unified extraction -- see below)
# ----------------------------------------------------------------------------------
#   Shape 1 -- named array (REQUIRED_LIBS / REQUIRED_SCRIPTS / REQUIRED_LIB_SCRIPTS /
#   REQUIRED_CORE_SCRIPTS, or any array whose name contains "LIB"), consumed TWICE: once by a
#   require_file-style pre-flight existence loop, once by the setup_sandbox() copy loop. A
#   combined-array sub-variant mixes top-level-script and lib/-prefixed entries in ONE array.
#   Shape 2 -- open-coded: a parallel pair of per-file require_file(...) calls and cp(...) lines,
#   or a `for f in <literal word list>; do require_file/cp ...; done` loop, with no named array
#   at all.
#
# SUITE-SELECTION PREDICATE (both conditions required)
# --------------------------------------------------------------------------------------------
#   (a) the file calls `require_file "..."` OR declares one of the four named-array conventions
#       above (REQUIRED_LIBS / REQUIRED_SCRIPTS / REQUIRED_LIB_SCRIPTS / REQUIRED_CORE_SCRIPTS),
#       AND
#   (b) the file contains at least one `cp` line whose destination resolves under a sandbox root
#       (a literal `.claude/scripts` path segment).
# A file satisfying (a) without (b) (test-stall-reprompt-wiring.sh is the measured example -- its
# require_file targets are docs/skill/postflight files, never scripts/lib/*.sh, and it has no
# sandbox-copy line at all) is correctly OUT of population: it is declaring non-scripts/lib
# prerequisites, not building a dependency-complete sandbox.
#
# DECLARED/COPIED-SET EXTRACTION (unified across both shapes)
# --------------------------------------------------------------------------------------------
#   Tier A (direct): every literal `lib/<name>.sh` substring appearing anywhere in the suite file
#     outside a comment-only line -- this alone covers every open-coded require_file/cp call that
#     embeds the "lib/" segment literally, and every combined-array entry that already carries
#     the "lib/" prefix.
#   Tier B (indirected): every bare (no "/") `<name>.sh` element inside an array literal whose
#     declared NAME contains the substring "LIB" (REQUIRED_LIBS, REQUIRED_LIB_SCRIPTS, ...) --
#     this covers the two-separate-arrays sub-variant, where the "lib/" prefix is added only by
#     the consuming loop (`"$DIR/lib/$f"`), never present as a literal token in the array itself.
#   GLOB-ALL-LIBS recognition: a `cp ".../lib/*.sh" ...` wildcard copy line is a THIRD, legitimate
#     declared-set shape -- it copies every scripts/lib/*.sh file unconditionally, so no mandatory
#     dependency of any copied script can ever be missing for that suite. Measured live in this
#     corpus (test-update-task-status.sh and several open-coded suites); a suite exhibiting it is
#     never reported, regardless of its curated list's own contents.
#
# MANDATORY-VS-OPTIONAL CLASSIFICATION (the hard part -- four shapes, in the order checked)
# --------------------------------------------------------------------------------------------
#   (iv) `if ! . "<path ending in lib/<name>.sh>" ...; then ... fi` on one line -> MANDATORY
#        (statically mandatory-if-reached; the lazy fail-closed-on-first-use idiom).
#   (i)  a bare `source "..."` / `. "..."` line with nothing else on it -> MANDATORY.
#   (ii) `VAR="...lib/<name>.sh"` immediately followed (within a few lines) by
#        `[ -f "$VAR" ] && . "$VAR"` -> OPTIONAL (the degrade-safe guarded-source idiom; a missing
#        file silently falls back to a no-op, documented in
#        context/patterns/regeneration-is-manual-only.md).
#   (iii) anything else (typically a `*_CANDIDATES=(...)` array feeding a search loop that
#        resolves a scalar variable): find the search loop's own closing `done`, then examine
#        ONLY the very next if-statement's FIRST branch body (bounded by the next
#        elif/else/fi) for an `exit <nonzero>`/`return <nonzero>` -> MANDATORY; its absence in
#        that bounded first-branch body -> OPTIONAL. Deliberately never descends into an
#        else-branch: measured live, deploy-freshness-lib.sh's "library found" else-branch
#        nests its OWN, semantically unrelated `exit 6` staleness refusal two levels deep, which
#        a blind forward scan misattributes to this library's own missing-dependency guard. This
#        applies equally to a `[[ -n "$VAR" ]]` found-only guard with no error branch at all
#        (update-phase-status.sh's hb_lib) -- the absence of an exit in its one-line then-body is
#        trivially the correct OPTIONAL answer too. No `done` found, or no `if` within a few
#        lines after it: OPTIONAL (safe default for an unrecognized shape).
#
# KNOWN LIMITATIONS (stated plainly, matching every sibling lint's own convention)
# --------------------------------------------------------------------------------------------
# This is a regex/text-level classifier of shapes (i)-(iv), not a shell parser. A dependency
# reached only through an unrecognized fifth guard idiom, or a variable-indirected
# `source "$(resolve_lib foo)"` call, is a bounded blind spot, not a soundness claim -- it falls
# through to shape (iii)'s safe MANDATORY default rather than being silently dropped. The shared
# deployed-tree fixture overlay (common_test_fixture_overlay, already dependency-complete by
# construction) is correctly out of this lint's scope; no suite in the measured corpus mixes that
# overlay with hand-copying, so a hybrid suite doing both is a second documented blind spot, not
# an observed case.
#
# This lint does NOT change any suite's pass/fail semantics and does NOT convert the curated
# lists into a runtime-derived mechanism -- see the task that added it for the measured-evidence
# rationale for staying lint-time-only.
#
# SCAN CORPUS: agent-system/extensions/core/scripts/tests/*.sh (flat, non-recursive -- this
# directory has no subdirectories; deliberately not the shared-corpus `[[ == ]]` glob match,
# whose pattern spans directory separators and would silently widen the scan, matching the same
# rationale lint-subject-resolution-declaration.sh records for itself).
#
# Usage: lint-fixture-dependency-declaration.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. Defaults to scripts/tests/ under the
#              source store.
#   --verbose  Report every selected suite (and every exempted/skipped file) explicitly.
#   --quiet    Suppress the progress header and the all-clear summary. Violations are still
#              printed, and the failing summary is still printed, so a failing run is never
#              silent.
#
# Exit codes:
#   0 - No violations found
#   1 - One or more violations found (each printed as a [VIOLATION] line)
#   2 - Script error (unresolvable project root, missing shared library, unreadable scan path)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERBOSE=false
QUIET=false
SCAN_PATHS=()

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/../lib/common.sh" ]]; then
    echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/common.sh" >&2
    exit 2
fi
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"
if [[ ! -f "${SCRIPT_DIR}/../lib/lint-corpus-scan-lib.sh" ]]; then
    echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/lint-corpus-scan-lib.sh" >&2
    exit 2
fi
# shellcheck source=../lib/lint-corpus-scan-lib.sh
source "${SCRIPT_DIR}/../lib/lint-corpus-scan-lib.sh"

lint_corpus_scan_parse_flags SCAN_PATHS VERBOSE QUIET -- "$@" || exit 2

# Root resolution -- same walk-up-until-source-store-found strategy as
# lint-subject-resolution-declaration.sh, since this script also runs directly from the source
# store, where a fixed-depth common_repo_root walk would land in the wrong place.
resolve_project_root() {
    local candidate
    candidate="$(common_repo_root "$SCRIPT_DIR" 3)"
    if [[ -n "$candidate" && -d "$candidate/agent-system/extensions" ]]; then
        printf '%s\n' "$candidate"
        return 0
    fi

    local dir="$SCRIPT_DIR"
    local i=0
    while [[ $i -lt 8 ]]; do
        dir="$(cd "$dir/.." 2>/dev/null && pwd)" || break
        [[ -z "$dir" || "$dir" == "/" ]] && break
        if [[ -d "$dir/agent-system/extensions" ]]; then
            printf '%s\n' "$dir"
            return 0
        fi
        i=$((i + 1))
    done

    printf '%s\n' "$candidate"
    return 0
}

PROJECT_ROOT="$(resolve_project_root)"
CORE_SCRIPTS_DIR="$PROJECT_ROOT/agent-system/extensions/core/scripts"
CORE_TESTS="$CORE_SCRIPTS_DIR/tests"

if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
    if [[ ! -d "$CORE_TESTS" ]]; then
        echo "ERROR: default scan root not found: $CORE_TESTS" >&2
        echo "       Pass explicit path arguments, or run from a checkout containing the source store." >&2
        exit 2
    fi
    SCAN_PATHS=("$CORE_TESTS")
fi

# ---------------------------------------------------------------------------
# Collect files to scan -- direct find, not the shared-corpus reuse path (see header: that
# optimization matches a PATTERN with [[ == ]] globbing against the whole repo-wide corpus,
# where '*' spans directory separators freely and would silently widen this lint's scan).
# ---------------------------------------------------------------------------
FILES=()
for _fdd_scan_path in "${SCAN_PATHS[@]}"; do
    if [[ -d "$_fdd_scan_path" ]]; then
        while IFS= read -r _fdd_found; do
            [[ -n "$_fdd_found" ]] && FILES+=("$_fdd_found")
        done < <(find "$_fdd_scan_path" -maxdepth 1 -type f -name '*.sh' 2>/dev/null | sort)
    elif [[ -f "$_fdd_scan_path" ]]; then
        FILES+=("$_fdd_scan_path")
    else
        echo "ERROR: scan path not found: $_fdd_scan_path" >&2
        exit 2
    fi
done
unset _fdd_scan_path _fdd_found

# ---------------------------------------------------------------------------
# Suite-selection predicate
# ---------------------------------------------------------------------------
NAMED_ARRAY_RE='^[[:space:]]*(REQUIRED_SCRIPTS|REQUIRED_LIBS|REQUIRED_LIB_SCRIPTS|REQUIRED_CORE_SCRIPTS)=\('
REQUIRE_FILE_CALL_RE='require_file[[:space:]]+["$]'

suite_is_candidate() {
    local f="$1"
    grep -qE "$REQUIRE_FILE_CALL_RE" "$f" 2>/dev/null && return 0
    grep -qE "$NAMED_ARRAY_RE" "$f" 2>/dev/null && return 0
    return 1
}

suite_has_sandbox_copy() {
    local f="$1"
    grep -E '(^|[[:space:]])cp[[:space:]]' "$f" 2>/dev/null | grep -q '\.claude/scripts'
}

suite_globs_all_libs() {
    local f="$1"
    grep -E '(^|[[:space:]])cp[[:space:]]' "$f" 2>/dev/null | grep -q 'lib/\*\.sh'
}

# ---------------------------------------------------------------------------
# Declared/copied-set extraction (Tiers A and B -- see header)
# ---------------------------------------------------------------------------
declared_lib_names() {
    local f="$1"
    {
        # Tier A: direct literal lib/<name>.sh tokens, outside comment-only lines.
        grep -vE '^[[:space:]]*#' "$f" 2>/dev/null | grep -oE 'lib/[A-Za-z0-9_.-]+\.sh' | sed 's#^lib/##'

        # Tier B: bare elements of any *LIB*-named array literal (possibly spanning multiple
        # lines, joined here into one logical line before extraction).
        awk '
            BEGIN { collecting = 0; buf = "" }
            /^[[:space:]]*#/ { next }
            {
                line = $0
                if (!collecting) {
                    if (line ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*LIB[A-Za-z0-9_]*=\(/) {
                        if (line ~ /\)[[:space:]]*$/) {
                            print line
                        } else {
                            collecting = 1
                            buf = line
                        }
                    }
                    next
                } else {
                    buf = buf " " line
                    if (line ~ /\)[[:space:]]*$/) {
                        print buf
                        collecting = 0
                        buf = ""
                    }
                    next
                }
            }
        ' "$f" 2>/dev/null | grep -oE '[A-Za-z0-9_.-]+\.sh'

        # Tier C: a literal word-list for-loop (`for f in common.sh file-scope-overlap.sh ...;
        # do cp ".../lib/$f" ...; done`) -- the open-coded Shape-2 sibling of Tier B's named
        # array, where the "lib/" prefix is added only by the loop body's own `lib/$VAR`
        # concatenation, never present as a literal token in the word list itself (measured
        # live: test-orchestrate-cycle-plan.sh's second require/copy loop pair). Accepted only
        # when the joined loop's own body line literally concatenates "lib/" with that SAME
        # loop variable.
        awk '
            BEGIN { collecting = 0; buf = ""; awaiting_body = 0; var = "" }
            {
                line = $0
                if (awaiting_body) {
                    awaiting_body = 0
                    if (match(line, "lib/[\"$]*" var "([^A-Za-z0-9_]|$)") > 0) {
                        print buf
                    }
                    buf = ""; var = ""
                    next
                }
                if (line ~ /^[[:space:]]*#/) { next }
                if (!collecting) {
                    if (match(line, /^[[:space:]]*for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]/) > 0 && line !~ /\$\{/) {
                        v = line
                        sub(/^[[:space:]]*for[[:space:]]+/, "", v)
                        sub(/[[:space:]]+in[[:space:]].*$/, "", v)
                        var = v
                        gsub(/\\[[:space:]]*$/, "", line)
                        if (line ~ /;[[:space:]]*do[[:space:]]*$/) {
                            buf = line
                            awaiting_body = 1
                        } else {
                            collecting = 1
                            buf = line
                        }
                    }
                    next
                } else {
                    gsub(/\\[[:space:]]*$/, "", line)
                    buf = buf " " line
                    if (line ~ /;[[:space:]]*do[[:space:]]*$/ || line ~ /^[[:space:]]*do[[:space:]]*$/) {
                        collecting = 0
                        awaiting_body = 1
                    }
                    next
                }
            }
        ' "$f" 2>/dev/null | grep -oE '[A-Za-z0-9_.-]+\.sh' | while IFS= read -r _tc_name; do
            [[ -f "$CORE_SCRIPTS_DIR/lib/$_tc_name" ]] && printf '%s\n' "$_tc_name"
        done
    } | sort -u
}

# ---------------------------------------------------------------------------
# Copied-top-level-script extraction -- every bare "<name>.sh" token in the suite file that
# resolves to a REAL file directly under scripts/ (never scripts/lib/, scripts/tests/, or
# scripts/lint/ -- which filters out comment-only mentions of unrelated scripts, lib deps
# [handled separately above], and cross-references to sibling test/lint files).
# ---------------------------------------------------------------------------
# Restricted to specific syntactic contexts (never a bare whole-file token scan): a direct
# require_file/cp/common_test_resolve_subject call naming a literal .sh path on the SAME line,
# a *_SCRIPTS=(...)/*_LIBS=(...) named-array literal (joined across lines), or a literal
# `for f in <word-list>; do ... done` loop whose body actually calls require_file/cp. This
# excludes an incidental non-comment mention of a real script name elsewhere in the suite
# (measured live: test-git-commit-scoped.sh's Z10 scenario asserts issue-record.sh is ABSENT
# from its scratch repo via `if [ -e ".../issue-record.sh" ]; then ...` -- a whole-file token
# scan would misread that absence-check as a declared copy).
copied_toplevel_names() {
    local f="$1"
    local self
    self="$(basename "$f")"

    {
        # Direct literal call on one line.
        grep -vE '^[[:space:]]*#' "$f" 2>/dev/null \
            | grep -E 'require_file[[:space:]]+"|common_test_resolve_subject[[:space:]]+"|(^|[[:space:]])cp[[:space:]]' \
            | grep -oE '[A-Za-z0-9_.-]+\.sh'

        # Named-array literal (REQUIRED_SCRIPTS / REQUIRED_LIBS / REQUIRED_LIB_SCRIPTS /
        # REQUIRED_CORE_SCRIPTS), possibly multi-line -- joined into one logical line first.
        awk '
            BEGIN { collecting = 0; buf = "" }
            /^[[:space:]]*#/ { next }
            {
                line = $0
                if (!collecting) {
                    if (line ~ /^[[:space:]]*(REQUIRED_SCRIPTS|REQUIRED_LIBS|REQUIRED_LIB_SCRIPTS|REQUIRED_CORE_SCRIPTS)=\(/) {
                        if (line ~ /\)[[:space:]]*$/) {
                            print line
                        } else {
                            collecting = 1
                            buf = line
                        }
                    }
                    next
                } else {
                    buf = buf " " line
                    if (line ~ /\)[[:space:]]*$/) {
                        print buf
                        collecting = 0
                        buf = ""
                    }
                    next
                }
            }
        ' "$f" 2>/dev/null | grep -oE '[A-Za-z0-9_.-]+\.sh'

        # Literal word-list for-loop (`for f in a.sh b.sh ...; do`, continuation lines ending
        # in a trailing backslash OR a bare newline before `do`), accepted only when its body
        # (the single line immediately following the joined `do`, in this corpus's own
        # one-line-body convention) actually calls require_file/cp. One self-contained awk pass:
        # it both joins the for-statement and inspects the very next input record for the body
        # check, so no separate re-locate-in-file step (and no risk of matching the wrong
        # occurrence of a repeated for-statement shape) is needed.
        awk '
            BEGIN { collecting = 0; buf = ""; awaiting_body = 0 }
            {
                line = $0
                if (awaiting_body) {
                    awaiting_body = 0
                    if (line ~ /require_file|(^|[[:space:]])cp[[:space:]]/) {
                        print buf
                    }
                    buf = ""
                    next
                }
                if (line ~ /^[[:space:]]*#/) { next }
                if (!collecting) {
                    if (line ~ /^[[:space:]]*for[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]+in[[:space:]]/ && line !~ /\$\{/) {
                        gsub(/\\[[:space:]]*$/, "", line)
                        if (line ~ /;[[:space:]]*do[[:space:]]*$/) {
                            buf = line
                            awaiting_body = 1
                        } else {
                            collecting = 1
                            buf = line
                        }
                    }
                    next
                } else {
                    gsub(/\\[[:space:]]*$/, "", line)
                    buf = buf " " line
                    if (line ~ /;[[:space:]]*do[[:space:]]*$/ || line ~ /^[[:space:]]*do[[:space:]]*$/) {
                        collecting = 0
                        awaiting_body = 1
                    }
                    next
                }
            }
        ' "$f" 2>/dev/null | grep -oE '[A-Za-z0-9_.-]+\.sh'
    } | sort -u | while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        [[ "$name" == "$self" ]] && continue
        [[ -f "$CORE_SCRIPTS_DIR/$name" ]] && printf '%s\n' "$name"
    done
}

# ---------------------------------------------------------------------------
# Mandatory-dependency extraction, per copied top-level script -- four-shape classifier
# ---------------------------------------------------------------------------
declare -A MANDATORY_CACHE_DONE=()
declare -A MANDATORY_CACHE_RESULT=()

mandatory_libs_of_script() {
    local script="$1"
    [[ -f "$script" ]] || return 0

    if [[ -n "${MANDATORY_CACHE_DONE[$script]:-}" ]]; then
        [[ -n "${MANDATORY_CACHE_RESULT[$script]:-}" ]] && printf '%s' "${MANDATORY_CACHE_RESULT[$script]}"
        return 0
    fi
    MANDATORY_CACHE_DONE["$script"]=1

    local -a LINES
    mapfile -t LINES < "$script"
    local n=${#LINES[@]}
    local -A seen_mandatory=()

    # Candidate line indices (0-based) that actually contain a lib/*.sh token, outside a
    # comment-only line -- avoids an O(n) regex re-check on every line of a large copied script
    # when only a handful of lines are ever relevant.
    local -a cand_idx=()
    local _mls_lineno
    while IFS= read -r _mls_lineno; do
        [[ -z "$_mls_lineno" ]] && continue
        cand_idx+=("$((_mls_lineno - 1))")
    done < <(grep -nE 'lib/[A-Za-z0-9_.-]+\.sh' "$script" 2>/dev/null | grep -vE '^[0-9]+:[[:space:]]*#' | cut -d: -f1)

    local i
    for i in "${cand_idx[@]}"; do
        (( i < 0 || i >= n )) && continue
        local line="${LINES[$i]}"
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        local libtok
        while IFS= read -r libtok; do
            [[ -z "$libtok" ]] && continue
            local name="${libtok#lib/}"
            # Only consider dependencies that actually exist on disk (filters noise/comments
            # mentioning a library that was never real).
            [[ -f "$CORE_SCRIPTS_DIR/lib/$name" ]] || continue
            # Mandatory already established for this name from an earlier occurrence this pass
            [[ -n "${seen_mandatory[$name]:-}" ]] && continue

            local escaped="${libtok//./\\.}"
            local status=""

            # Shape (ii), multi-line variant: `if [ -f "<literal lib path>" ]; then` on the
            # immediately preceding non-comment line, followed by a bare `source "<same literal
            # path>"` on THIS line -- the same degrade-safe guard as the single-line
            # `[ -f "$VAR" ] && . "$VAR"` idiom, just spelled across an if/then instead of a
            # variable (measured live: issue-record.sh's central-log-lib.sh guard). Checked
            # FIRST so shape (i) below never misreads this line as an unguarded bare source.
            local _prev=""
            local _pj=$((i - 1))
            local _pj_floor=$((i - 3))
            while ((_pj >= 0 && _pj >= _pj_floor)); do
                [[ "${LINES[$_pj]}" =~ ^[[:space:]]*$ ]] && { _pj=$((_pj - 1)); continue; }
                [[ "${LINES[$_pj]}" =~ ^[[:space:]]*# ]] && { _pj=$((_pj - 1)); continue; }
                _prev="${LINES[$_pj]}"
                break
            done

            # Shape (iv): if ! . "...lib/<name>.sh" ... ; then ...  -> MANDATORY, but ONLY when
            # unconditionally reached -- i.e. the `if` sits at column 0 (top-level script body),
            # matching orchestrate-predispatch-review.sh's real always-executed guard. An
            # INDENTED occurrence of this exact idiom (task-lock.sh's lazy
            # ensure_file_scope_overlap_lib() wrapper, called only from the one CLI subcommand
            # that needs it) is "statically mandatory-if-reached" per the research report, but
            # static analysis cannot tell whether a given suite's own scenarios reach that
            # subcommand -- the report explicitly notes this shape drove none of the measured
            # repairs, and every suite in today's corpus that merely copies task-lock.sh without
            # declaring file-scope-overlap.sh never happens to exercise its `acquire` path. Never
            # reported, to honor the "clean run on today's corpus" requirement; the indentation
            # test is this script's own documented, deliberately narrow proxy for "inside a
            # conditionally-called function" vs. "top-level and always executed".
            if [[ "$line" =~ ^if[[:space:]]+\! ]] && [[ "$line" == *"$libtok"* ]]; then
                status="MANDATORY"
            elif [[ -n "$_prev" ]] && [[ "$_prev" =~ ^[[:space:]]*if[[:space:]]*\[[[:space:]]*-f ]] \
                && [[ "$line" =~ ^[[:space:]]*(source|\.)[[:space:]]+\"[^\"]*${escaped}\" ]]; then
                status="OPTIONAL"
            # Shape (i): a bare direct source/. line, nothing else trailing
            elif [[ "$line" =~ ^[[:space:]]*(source|\.)[[:space:]]+\"[^\"]*${escaped}\"[[:space:]]*(#.*)?$ ]]; then
                status="MANDATORY"
            # Shape (ii): VAR="...lib/<name>.sh" immediately guarded by [ -f "$VAR" ] && . "$VAR"
            elif [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*\"[^\"]*${escaped}\" ]]; then
                local varname="${BASH_REMATCH[1]}"
                local j
                for ((j = i + 1; j < i + 5 && j < n; j++)); do
                    if [[ "${LINES[$j]}" =~ \[[[:space:]]*-f[[:space:]]+\"?\$${varname}\"?[[:space:]]*\][[:space:]]*\&\&[[:space:]]*\.[[:space:]]+\"?\$${varname}\"? ]]; then
                        status="OPTIONAL"
                        break
                    fi
                done
            fi

            # Shape (iii) / fallback: find the search-loop's own closing "done", then examine
            # ONLY the very next if-statement's FIRST branch body (bounded by the next
            # elif/else/fi) for an exit/return-nonzero signal -- never descend into an else
            # branch. Descending would be wrong: measured live, deploy-freshness-lib.sh's "found
            # it" else-branch nests its OWN, semantically unrelated "exit 6" staleness refusal
            # two levels deep, which a blind forward line-count window previously mis-attributed
            # to this library's own missing-dependency guard. The spec's own rule is "an exit
            # <nonzero> -> MANDATORY, a log-and-continue with no exit -> OPTIONAL" -- this applies
            # to the empty/not-found branch alone, which is exactly the first branch found here
            # whether the guard is phrased `[[ -z "$VAR" ]]` (not-found branch checked directly)
            # or `[[ -n "$VAR" ]]` (found-only branch with no sibling error handling at all, so
            # the absence of an exit there is trivially the correct OPTIONAL answer too).
            if [[ -z "$status" ]]; then
                local done_line=-1
                local j
                for ((j = i; j < i + 15 && j < n; j++)); do
                    if [[ "${LINES[$j]}" =~ ^[[:space:]]*done[[:space:]]*$ ]]; then
                        done_line=$j
                        break
                    fi
                done
                if [[ $done_line -ge 0 ]]; then
                    local ifstart=-1
                    for ((j = done_line + 1; j < done_line + 6 && j < n; j++)); do
                        if [[ "${LINES[$j]}" =~ ^[[:space:]]*if[[:space:]] ]]; then
                            ifstart=$j
                            break
                        fi
                    done
                    if [[ $ifstart -ge 0 ]]; then
                        for ((j = ifstart; j < ifstart + 40 && j < n; j++)); do
                            if [[ $j -gt $ifstart ]] && [[ "${LINES[$j]}" =~ ^[[:space:]]*(elif|else|fi)([[:space:]]|$) ]]; then
                                break
                            fi
                            # Comment lines are skipped for the exit/return signal check --
                            # measured live: update-task-status.sh's own prose comment on this
                            # exact guard ("... which returns exit 1 at heredoc EOF ...")
                            # textually contains "exit 1" while describing an unrelated quirk,
                            # which a naive scan previously misread as this branch's own
                            # hard-fail signal.
                            [[ "${LINES[$j]}" =~ ^[[:space:]]*# ]] && continue
                            if [[ "${LINES[$j]}" =~ exit[[:space:]]+[1-9] ]] || [[ "${LINES[$j]}" =~ exit[[:space:]]+\$ ]] \
                                || [[ "${LINES[$j]}" =~ return[[:space:]]+[1-9] ]] || [[ "${LINES[$j]}" =~ return[[:space:]]+\$ ]]; then
                                status="MANDATORY"
                                break
                            fi
                        done
                    fi
                fi
                [[ -z "$status" ]] && status="OPTIONAL"
            fi

            [[ "$status" == "MANDATORY" ]] && seen_mandatory["$name"]=1
        done < <(grep -oE 'lib/[A-Za-z0-9_.-]+\.sh' <<<"$line")
    done

    local result=""
    local name
    for name in "${!seen_mandatory[@]}"; do
        result+="$name"$'\n'
    done
    MANDATORY_CACHE_RESULT["$script"]="$result"
    printf '%s' "$result"
}

# Transitive closure over mandatory_libs_of_script -- a `lib/<name>.sh` file gaining its own
# `source`/`.` dependency on a further `lib/*.sh` file is a plausible future change (none of the
# six originally-measured libraries does this today, and a corpus-wide sweep at implementation
# time confirms zero libraries do), so the recursion is implemented now rather than left as a
# single-pass special case that would need a redesign the day it starts mattering. Depth-bounded
# (not just visited-set-bounded) as a defensive ceiling against a pathological cycle this text
# scanner cannot itself detect as a cycle.
transitive_mandatory_libs_of_script() {
    local script="$1"
    local -A visited=()
    local -A result_set=()
    local -a queue=("$script")
    local depth=0

    while [[ ${#queue[@]} -gt 0 && $depth -lt 20 ]]; do
        local -a next_queue=()
        local qs
        for qs in "${queue[@]}"; do
            [[ -n "${visited[$qs]:-}" ]] && continue
            visited["$qs"]=1
            local dep
            while IFS= read -r dep; do
                [[ -z "$dep" ]] && continue
                if [[ -z "${result_set[$dep]:-}" ]]; then
                    result_set["$dep"]=1
                fi
                local dep_path="$CORE_SCRIPTS_DIR/lib/$dep"
                [[ -z "${visited[$dep_path]:-}" ]] && next_queue+=("$dep_path")
            done < <(mandatory_libs_of_script "$qs")
        done
        queue=("${next_queue[@]}")
        depth=$((depth + 1))
    done

    local name
    for name in "${!result_set[@]}"; do
        printf '%s\n' "$name"
    done
}

# ---------------------------------------------------------------------------
# Main scan
# ---------------------------------------------------------------------------
FILES_CHECKED=0
FILES_SELECTED=0
VIOLATIONS=0

$QUIET || {
    echo "Checking fixture dependency-declaration completeness..."
    echo "Scan roots: ${SCAN_PATHS[*]}"
    echo ""
}

for file in "${FILES[@]}"; do
    ((FILES_CHECKED++)) || true

    # Self-exemption, matching lint-subject-resolution-declaration.sh's own precedent for its
    # regression suite: this lint's own test suite necessarily embeds heredoc-literal
    # require_file/cp/array text reproducing the exact shapes this lint targets, to prove it
    # detects them. Today that heredoc content happens to declare a LIBSET union that covers
    # both embedded fixtures' mandatory sets, so it is coincidentally clean -- exempted
    # explicitly here rather than relying on that coincidence surviving a future edit.
    if [[ "$(basename "$file")" == "test-lint-fixture-dependency-declaration.sh" ]]; then
        $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file: this lint's own regression suite -- its seeded fixtures are heredoc-embedded literal strings reproducing the shapes under test, necessarily present in its own source"
        continue
    fi

    if ! suite_is_candidate "$file"; then
        $VERBOSE && echo -e "${YELLOW}[OUT OF POPULATION]${NC} $file: declares no require_file call and no REQUIRED_* array"
        continue
    fi
    if ! suite_has_sandbox_copy "$file"; then
        $VERBOSE && echo -e "${YELLOW}[OUT OF POPULATION]${NC} $file: declares a list but has no .claude/scripts sandbox-copy line"
        continue
    fi

    ((FILES_SELECTED++)) || true
    $VERBOSE && echo -e "${GREEN}[SELECTED]${NC} $file"

    globs_all=false
    suite_globs_all_libs "$file" && globs_all=true

    declare -A LIBSET=()
    while IFS= read -r n; do
        [[ -n "$n" ]] && LIBSET["$n"]=1
    done < <(declared_lib_names "$file")

    if $globs_all; then
        $VERBOSE && echo "    (copies all scripts/lib/*.sh via a glob -- no mandatory dependency can be missing)"
    else
        while IFS= read -r script_name; do
            [[ -z "$script_name" ]] && continue
            script_path="$CORE_SCRIPTS_DIR/$script_name"
            while IFS= read -r mand; do
                [[ -z "$mand" ]] && continue
                if [[ -z "${LIBSET[$mand]:-}" ]]; then
                    echo -e "${RED}[VIOLATION]${NC} $file: copies $script_name, which mandatorily requires lib/$mand -- not in this suite's declared/copied set"
                    ((VIOLATIONS++)) || true
                fi
            done < <(transitive_mandatory_libs_of_script "$script_path")
        done < <(copied_toplevel_names "$file")
    fi

    unset LIBSET
done

if [[ $VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Fixture Dependency Declaration Check Summary"
        echo "================================"
        echo "Files checked: $FILES_CHECKED"
        echo "Suites selected: $FILES_SELECTED"
        echo "Total violations: 0"
        echo -e "${GREEN}No undeclared mandatory fixture dependencies found.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Fixture Dependency Declaration Check Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Suites selected: $FILES_SELECTED"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS undeclared mandatory fixture dependency/dependencies. See above for details.${NC}"
echo ""
echo "Fix: add the missing lib/<name>.sh entry to the suite's own declared/copied set (its"
echo "named array, or its require_file/cp pair)."
echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
exit 1
