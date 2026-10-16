#!/usr/bin/env bash
# lint-branch-gated-sections.sh - Detect marked-but-unextracted branch-gated sections above a
# byte threshold on runtime-loaded executable `.md` surfaces.
#
# Companion enforcement for context/patterns/mode-gated-section-loading.md: a skill's SKILL.md
# body and a command's .md body load in full on every invocation (no include/partial mechanism,
# deploy is a byte-for-byte copy), so a large mutually-exclusive branch section left inline is
# paid for on every invocation that skips it. Authors mark such a section with the paired
#   <!-- branch-gated:begin condition="..." --> ... <!-- branch-gated:end -->
# comment pair while deciding whether/how to extract it. This lint fires when a marked section
# (or the sum of several in one file) exceeds the byte threshold below, so the marked-but-
# unextracted state does not linger silently.
#
# KNOWN LIMITATION (stated plainly rather than papered over)
# ------------------------------------------------------------
# This is a marker-keyed lint. It can only ever see sections an author has already wrapped in
# the branch-gated:begin/end marker pair. A genuinely large, mutually-exclusive branch section
# that was never marked evades this lint entirely -- there is nothing in the unmarked prose for
# a structural scan to key on. A clean run means "no MARKED section exceeds the threshold", never
# "no branch-gated section is inline anywhere in the tree". See mode-gated-section-loading.md's
# "When to Extract" section for the authoring-time guidance that is this lint's only defense
# against that blind spot.
#
# THRESHOLD CALIBRATION
# ----------------------
# THRESHOLD_BYTES=8000 sits below every known instance measured at authoring time (17,309 /
# 25,883 / 43,254 / 65,772 / 103,462 B) by a wide margin, so it needs no re-tuning as those land,
# and above small legitimately-inline branch content whose extraction overhead (new file,
# pointer, index entry) would exceed the win. It is a single named constant specifically so a
# future re-calibration is a one-line change, not a structural one.
#
# CONVENTION-SELECTION (structural-plus-reasoned-allowlist, not zero-tolerance)
# -------------------------------------------------------------------------------
# A live count of marked-but-unextracted files across the tree at authoring time came back ZERO
# (no markers exist anywhere yet). Despite that, this lint deliberately adopts the
# structural-plus-reasoned-allowlist shape rather than zero-tolerance: per-file extraction work
# (see context/patterns/mode-gated-section-loading.md's extraction procedure) legitimately
# produces a marked-but-unextracted intermediate state as a routine, expected step -- the marker
# is applied BEFORE the section is cut out, specifically so boundaries can be re-located by
# literal text. A zero-tolerance assertion would make that ordinary in-progress state a hard
# failure for every future extraction, this task's own pilot included. The allowlist mechanism
# below is present but starts EMPTY -- there is no known standing exception at authoring time --
# per the decision rule in context/patterns/adoption-lint-conventions.md. A future entry is a
# deliberate act with a stated reason, never the default response to a failing run.
#
# DETECTION MODEL
# -----------------
# Two layers, applied in order:
#
#   Layer 1 (structural): for each in-scope file, pair every
#     <!-- branch-gated:begin condition="..." --> with the NEXT <!-- branch-gated:end -->,
#     encountered in a single top-to-bottom pass. Malformed marker states are reported as their
#     own named diagnostic, never silently skipped:
#       - UNMATCHED_BEGIN: a begin marker with no following end marker before EOF.
#       - UNMATCHED_END: an end marker with no preceding open begin marker.
#       - NESTED: a second begin marker encountered while a prior begin is still open.
#     For each well-formed pair, the span's byte size is measured with `sed -n '<start>,<end>p'
#     <file> | wc -c` (start/end are the marker lines themselves, so the measured span includes
#     both marker lines and everything between them). A file's violation total is the SUM of all
#     its well-formed spans' byte sizes -- multiple sections each below threshold that sum above
#     it is still a violation, not just the single largest section.
#
#   Layer 2 (file-level allowlist): an EXCLUDED_FILES-style block, identical in shape to
#     lint-task-lookup-adoption.sh's -- every entry carries an inline reason; bare paths are
#     prohibited by construction. Starts empty per the CONVENTION-SELECTION note above.
#
# Scope, by construction (never by exclusion list): `commands/*.md` (top-level only) and
# `skills/*/SKILL.md` (exactly one skill-directory level deep) across each extension.
# `docs/`, `context/`, `rules/`, `agents/`, and any `scripts/*.sh` are out of scope because the
# scan never visits them -- illustrative marker examples in prose documentation (such as this
# lint's own header, or mode-gated-section-loading.md's worked examples) are never scan targets.
#
# Usage: lint-branch-gated-sections.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Directories to scan (each treated as its own scan root, mode-probed
#              independently) or individual files (scanned directly, bypassing scope rules).
#              Defaults to the resolved project root's source-store or deployed scan roots.
#   --verbose  Report every well-formed span found, including those under threshold or
#              allowlist-exempted, tagged with its byte size and disposition.
#   --quiet    Suppress the progress header and the all-clear summary. Violations are still
#              printed, and the failing summary is still printed, so a failing run is never
#              silent.
#
# Exit codes:
#   0 - No unexcluded violations found (no over-threshold sum, no malformed markers)
#   1 - One or more unexcluded violations found
#   2 - Script error (unresolvable project root, missing shared library, unreadable scan path)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

THRESHOLD_BYTES=8000

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

VERBOSE=false
QUIET=false
SCAN_PATHS=()
lint_corpus_scan_parse_flags SCAN_PATHS VERBOSE QUIET -- "$@"

# ---------------------------------------------------------------------------
# Root resolution: dual-mode probe, reused from lint-task-lookup-adoption.sh verbatim.
# ---------------------------------------------------------------------------
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

# scan_root_mode <root> -- "source-store" or "deployed", by probing for core/manifest.json one
# level under <root>. Identical probe to lint-task-lookup-adoption.sh's scan_root_mode().
scan_root_mode() {
    local root="$1"
    if [[ -f "$root/core/manifest.json" ]]; then
        printf 'source-store\n'
    else
        printf 'deployed\n'
    fi
}

# ---------------------------------------------------------------------------
# Scan-scope collection: commands/*.md (top-level only) + skills/*/SKILL.md (exactly one
# skill-directory level deep). Narrower than lint-task-lookup-adoption.sh's commands/skills/
# agents-at-any-depth-any-name scope -- this lint targets only the two executable surfaces that
# are actually loaded whole on every invocation.
# ---------------------------------------------------------------------------
collect_scan_files() {
    local _root="$1"
    local _mode="$2"
    local _ext_dir

    if [[ "$_mode" == "source-store" ]]; then
        for _ext_dir in "$_root"/*/; do
            [[ -d "$_ext_dir" ]] || continue
            if [[ -d "${_ext_dir}commands" ]]; then
                find "${_ext_dir}commands" -maxdepth 1 -type f -name '*.md' 2>/dev/null
            fi
            if [[ -d "${_ext_dir}skills" ]]; then
                find "${_ext_dir}skills" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' 2>/dev/null
            fi
        done
    else
        if [[ -d "$_root/commands" ]]; then
            find "$_root/commands" -maxdepth 1 -type f -name '*.md' 2>/dev/null
        fi
        if [[ -d "$_root/skills" ]]; then
            find "$_root/skills" -mindepth 2 -maxdepth 2 -type f -name 'SKILL.md' 2>/dev/null
        fi
    fi
    unset _root _mode _ext_dir
    return 0
}

FILES=()

if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
    REPO_ROOT_CANDIDATE="$(resolve_project_root)"
    if [[ -d "$REPO_ROOT_CANDIDATE/agent-system/extensions" ]]; then
        SCAN_MODE="source-store"
        PROJECT_ROOT="$REPO_ROOT_CANDIDATE/agent-system/extensions"
    else
        SCAN_MODE="deployed"
        PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." 2>/dev/null && pwd || printf '%s' "$REPO_ROOT_CANDIDATE")"
    fi

    if [[ ! -d "$PROJECT_ROOT" ]]; then
        echo "ERROR: default scan root not found: $PROJECT_ROOT" >&2
        echo "       Pass explicit path arguments, or run from a checkout containing the source store." >&2
        exit 2
    fi
    while IFS= read -r found; do
        [[ -n "$found" ]] && FILES+=("$found")
    done < <(collect_scan_files "$PROJECT_ROOT" "$SCAN_MODE" | sort -u)
else
    PROJECT_ROOT=""
    for scan_path in "${SCAN_PATHS[@]}"; do
        if [[ -d "$scan_path" ]]; then
            scan_path="$(cd "$scan_path" && pwd)"
            [[ -z "$PROJECT_ROOT" ]] && PROJECT_ROOT="$scan_path"
            path_mode="$(scan_root_mode "$scan_path")"
            while IFS= read -r found; do
                [[ -n "$found" ]] && FILES+=("$found")
            done < <(collect_scan_files "$scan_path" "$path_mode" | sort -u)
        elif [[ -f "$scan_path" ]]; then
            FILES+=("$scan_path")
        else
            echo "ERROR: scan path not found: $scan_path" >&2
            exit 2
        fi
    done
fi

# ---------------------------------------------------------------------------
# Layer 2: file-level allowlist. Starts empty -- see CONVENTION-SELECTION note in the header.
# Repo-relative paths (relative to PROJECT_ROOT). Every entry states WHY it is exempt.
# ---------------------------------------------------------------------------
EXCLUDED_FILES=(
    # (none yet -- see header's CONVENTION-SELECTION note for why this starts empty)
)

is_excluded_file() {
    local file="$1"
    local rel="${file#"$PROJECT_ROOT"/}"
    local entry
    for entry in "${EXCLUDED_FILES[@]}"; do
        [[ -z "$entry" ]] && continue
        [[ "$rel" == "$entry" ]] && return 0
        [[ "$file" == */"$entry" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Per-file scan: pair markers, measure spans, report malformed states.
# Sets (via global accumulator arrays) FILE_SPAN_TOTAL and FILE_DIAGNOSTICS for the file just
# scanned; caller reads these immediately after calling.
# ---------------------------------------------------------------------------
scan_file() {
    local file="$1"
    FILE_SPAN_TOTAL=0
    FILE_DIAGNOSTICS=()
    FILE_SPAN_DETAILS=()

    [[ -f "$file" ]] || return 0

    local state="outside"
    local pending_begin_line=""
    local lineno=0
    local line

    while IFS= read -r line || [[ -n "$line" ]]; do
        lineno=$((lineno + 1))
        if [[ "$line" == *"<!-- branch-gated:begin"* ]]; then
            if [[ "$state" == "outside" ]]; then
                state="inside"
                pending_begin_line="$lineno"
            else
                FILE_DIAGNOSTICS+=("NESTED begin at line $lineno (previous unclosed begin at line $pending_begin_line)")
            fi
        elif [[ "$line" == *"<!-- branch-gated:end -->"* ]]; then
            if [[ "$state" == "inside" ]]; then
                local span_bytes
                span_bytes="$(sed -n "${pending_begin_line},${lineno}p" "$file" | wc -c | tr -d ' ')"
                FILE_SPAN_TOTAL=$((FILE_SPAN_TOTAL + span_bytes))
                FILE_SPAN_DETAILS+=("lines ${pending_begin_line}-${lineno}: ${span_bytes} B")
                state="outside"
                pending_begin_line=""
            else
                FILE_DIAGNOSTICS+=("UNMATCHED_END at line $lineno (no preceding open begin marker)")
            fi
        fi
    done < "$file"

    if [[ "$state" == "inside" ]]; then
        FILE_DIAGNOSTICS+=("UNMATCHED_BEGIN at line $pending_begin_line (never closed before EOF)")
    fi
}

# ---------------------------------------------------------------------------
# Main scan
# ---------------------------------------------------------------------------
VIOLATIONS=0
FILES_CHECKED=0
FILES_WITH_VIOLATIONS=0
FILES_WITH_SPANS=0

$QUIET || {
    echo "Checking branch-gated section byte-threshold compliance..."
    if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
        echo "Scan root: $PROJECT_ROOT (mode: $SCAN_MODE)"
    else
        echo "Scan paths: ${SCAN_PATHS[*]}"
    fi
    echo "Threshold: ${THRESHOLD_BYTES} B (aggregate marked-but-unextracted bytes per file)"
    echo ""
}

for file in "${FILES[@]}"; do
    ((FILES_CHECKED++)) || true

    FILE_SPAN_TOTAL=0
    FILE_DIAGNOSTICS=()
    FILE_SPAN_DETAILS=()
    scan_file "$file"

    file_excluded=false
    if is_excluded_file "$file"; then
        file_excluded=true
    fi

    if [[ ${#FILE_SPAN_DETAILS[@]} -gt 0 ]]; then
        ((FILES_WITH_SPANS++)) || true
    fi

    file_has_violation=false

    # Malformed markers are always reported, never silently skipped -- even on an allowlisted
    # file, since the allowlist exempts byte-threshold size, not marker well-formedness.
    for diag in "${FILE_DIAGNOSTICS[@]}"; do
        echo -e "${RED}[VIOLATION]${NC} $file: MALFORMED MARKER: $diag"
        file_has_violation=true
        ((VIOLATIONS++)) || true
    done

    if $VERBOSE && [[ ${#FILE_SPAN_DETAILS[@]} -gt 0 ]]; then
        for detail in "${FILE_SPAN_DETAILS[@]}"; do
            echo -e "${YELLOW}[SPAN]${NC} $file: $detail"
        done
    fi

    if [[ $FILE_SPAN_TOTAL -gt $THRESHOLD_BYTES ]]; then
        if $file_excluded; then
            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file: ${FILE_SPAN_TOTAL} B marked (over ${THRESHOLD_BYTES} B threshold) | file-level allowlist entry"
        else
            echo -e "${RED}[VIOLATION]${NC} $file: ${FILE_SPAN_TOTAL} B marked-but-unextracted (threshold ${THRESHOLD_BYTES} B)"
            file_has_violation=true
            ((VIOLATIONS++)) || true
        fi
    fi

    if $file_has_violation; then
        ((FILES_WITH_VIOLATIONS++)) || true
    fi
done

if [[ $VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Branch-Gated Section Threshold Check Summary"
        echo "================================"
        echo "Files checked: $FILES_CHECKED"
        echo "Files with marked spans: $FILES_WITH_SPANS"
        echo "Total violations: 0"
        echo -e "${GREEN}No marked-but-unextracted branch-gated section exceeds the threshold.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Branch-Gated Section Threshold Check Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Files with violations: $FILES_WITH_VIOLATIONS"
echo "Files with marked spans: $FILES_WITH_SPANS"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS branch-gated section violation(s). See above for details.${NC}"
echo ""
echo "Fix: extract the marked section per context/patterns/mode-gated-section-loading.md's"
echo "extraction procedure, or resolve the malformed marker pair."
echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
exit 1
