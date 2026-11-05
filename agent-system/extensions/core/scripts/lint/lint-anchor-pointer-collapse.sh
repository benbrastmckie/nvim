#!/usr/bin/env bash
# lint-anchor-pointer-collapse.sh - Regression guard for the anchor-pointer convention
# (context/standards/anchor-pointer-convention.md): fail if a markdown block already collapsed
# to a one-line pointer has been reintroduced verbatim into the file it was collapsed FROM.
#
# WHY THIS EXISTS
# ----------------
# A markdown-consolidation task (see context/standards/anchor-pointer-convention.md) collapses a
# block restated across many files down to a one-line reference naming the anchor file/heading
# that already owns the content. The defining risk of a collapse is silent regression: a later
# edit to a "collapsed" file reintroduces the full block (e.g. a copy-paste from another
# not-yet-migrated sibling, or a well-meaning expansion of the pointer back into prose), quietly
# re-growing the exact duplication the collapse removed. This lint pins that one collapsed file
# stays collapsed.
#
# DELIBERATE SCOPE: PER-FILE, NOT WHOLE-CORPUS
# ---------------------------------------------
# This lint does NOT scan the whole corpus for every file that still carries a given block's
# text verbatim. A block is typically migrated in tranches (five files today, dozens more over
# later phases of the same task) -- at any point in that migration, the overwhelming majority of
# files sharing a block's text are legitimately NOT YET migrated, and a whole-corpus scan would
# fire on every one of them from the moment the FIRST file is collapsed. Instead, each registry
# row names its own `migrated_files` list -- the files already collapsed for that block -- and
# this lint checks only those files (never the un-migrated remainder) for regression. Growing the
# migrated set as more files are collapsed is a pure data edit: add the path to the row's
# migrated_files column. No invocation of this script's own code changes as coverage grows.
#
# REGISTRY FORMAT (lint/collapsed-blocks/registry.tsv)
# -----------------------------------------------------
# TAB-separated, one row per collapsed block, 4 columns:
#   anchor_path       Repo-relative path (from the project root) to the file that owns the
#                      content. Must exist on disk.
#   anchor_heading     The exact section heading the pointer names, for a human reader to
#                      cross-check; not itself matched by this lint.
#   block_file         Filename, relative to lint/collapsed-blocks/, holding the exact literal
#                      text of the collapsed block (the text that must not reappear in a migrated
#                      file). Byte-for-byte, not a regex.
#   migrated_files     Comma-separated, repo-relative paths of files already collapsed for this
#                      block. Each is checked for absence of the block text.
# Lines starting with `#` and blank lines are skipped. A registry that does not exist, or exists
# with zero data rows, is not an error -- it means no block has been collapsed yet.
#
# MATCHING MODEL
# ---------------
# Exact byte-for-byte substring containment of the registered block text inside the candidate
# file's full content, tested via `grep -Fqz` (NUL-separated records, so the whole file is one
# record and a multi-line fixed-string pattern can match across its embedded newlines). This is
# deliberately not a regex and not a line-oriented scan: the registered text is the literal
# collapsed block, captured once at collapse time.
#
# Usage: lint-anchor-pointer-collapse.sh [--verbose] [--quiet] [--registry PATH]
#
#   --registry PATH   Use PATH instead of the default registry (lint/collapsed-blocks/registry.tsv
#                      next to this script). Primarily for the fixture suite.
#   --root PATH        Resolve registry anchor_path/migrated_files entries against PATH instead of
#                      the detected project root. Primarily for the fixture suite.
#   --verbose          Report every registry row checked, including ones with no migrated files.
#   --quiet            Suppress the progress header and the all-clear summary. Violations are
#                      still printed, and the failing summary is still printed.
#
# Exit codes:
#   0 - No registered block reappeared in any of its own migrated files
#   1 - One or more violations found (each printed as file:anchor)
#   2 - Script error (missing registry row's anchor/block file, malformed row, bad --registry path)

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

VERBOSE=false
QUIET=false
REGISTRY_OVERRIDE=""
ROOT_OVERRIDE=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/../lib/common.sh" ]]; then
    echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/common.sh" >&2
    exit 2
fi
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose) VERBOSE=true; shift ;;
        --quiet) QUIET=true; shift ;;
        --registry)
            [[ $# -ge 2 ]] || { echo "ERROR: --registry requires a path argument" >&2; exit 2; }
            REGISTRY_OVERRIDE="$2"
            shift 2
            ;;
        --root)
            [[ $# -ge 2 ]] || { echo "ERROR: --root requires a path argument" >&2; exit 2; }
            ROOT_OVERRIDE="$2"
            shift 2
            ;;
        *)
            echo "ERROR: unrecognized argument: $1" >&2
            exit 2
            ;;
    esac
done

# Root resolution, matching lint-verdict-extraction-anchoring.sh's deploy/source-store-agnostic
# walk-up (common_repo_root assumes a 3-levels-up depth that only lands correctly from the
# deployed path; walk up looking for agent-system/extensions as the source-store landmark).
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

if [[ -n "$ROOT_OVERRIDE" ]]; then
    PROJECT_ROOT="$(cd "$ROOT_OVERRIDE" 2>/dev/null && pwd)"
    if [[ -z "$PROJECT_ROOT" ]]; then
        echo "ERROR: --root path not found: $ROOT_OVERRIDE" >&2
        exit 2
    fi
else
    PROJECT_ROOT="$(resolve_project_root)"
fi

if [[ -n "$REGISTRY_OVERRIDE" ]]; then
    REGISTRY_FILE="$REGISTRY_OVERRIDE"
    REGISTRY_DIR="$(cd "$(dirname "$REGISTRY_FILE")" 2>/dev/null && pwd)"
else
    REGISTRY_DIR="${SCRIPT_DIR}/collapsed-blocks"
    REGISTRY_FILE="${REGISTRY_DIR}/registry.tsv"
fi

if [[ -n "$REGISTRY_OVERRIDE" && -z "$REGISTRY_DIR" ]]; then
    echo "ERROR: --registry path's directory does not exist: $REGISTRY_OVERRIDE" >&2
    exit 2
fi

$QUIET || {
    echo "Checking anchor-pointer collapse regression..."
    echo "Registry: $REGISTRY_FILE"
    echo ""
}

if [[ ! -f "$REGISTRY_FILE" ]]; then
    $QUIET || echo "No registry file found -- no block has been collapsed yet. Nothing to check."
    exit 0
fi

VIOLATIONS=0
ROWS_CHECKED=0
FILES_CHECKED=0

while IFS=$'\t' read -r anchor_path anchor_heading block_file migrated_files; do
    # Skip comments and blank lines.
    [[ -z "${anchor_path// }" ]] && continue
    [[ "$anchor_path" == \#* ]] && continue

    ((ROWS_CHECKED++)) || true

    if [[ -z "$block_file" ]]; then
        echo "ERROR: registry row for anchor '$anchor_path' has no block_file column" >&2
        exit 2
    fi

    abs_block_file="${REGISTRY_DIR}/${block_file}"
    if [[ ! -f "$abs_block_file" ]]; then
        echo "ERROR: registry row's block_file not found: $abs_block_file (anchor: $anchor_path)" >&2
        exit 2
    fi

    abs_anchor="${PROJECT_ROOT}/${anchor_path}"
    if [[ ! -f "$abs_anchor" ]]; then
        echo "ERROR: registry row's anchor_path does not exist: $abs_anchor" >&2
        exit 2
    fi

    if [[ -z "${migrated_files// }" ]]; then
        $VERBOSE && echo -e "${YELLOW}[INFO]${NC} $anchor_path: no migrated files registered yet"
        continue
    fi

    IFS=',' read -r -a files <<< "$migrated_files"
    for rel_file in "${files[@]}"; do
        rel_file="${rel_file# }"
        rel_file="${rel_file% }"
        [[ -z "$rel_file" ]] && continue

        ((FILES_CHECKED++)) || true
        abs_file="${PROJECT_ROOT}/${rel_file}"

        if [[ ! -f "$abs_file" ]]; then
            echo "ERROR: registered migrated file does not exist: $abs_file (anchor: $anchor_path)" >&2
            exit 2
        fi

        if grep -Fqz -- "$(cat "$abs_block_file")" "$abs_file" 2>/dev/null; then
            echo -e "${RED}[VIOLATION]${NC} $rel_file: collapsed block reappeared verbatim -- see anchor $anchor_path § \"$anchor_heading\" instead of restating it here"
            ((VIOLATIONS++)) || true
        else
            $VERBOSE && echo -e "${GREEN}[OK]${NC} $rel_file: collapsed block absent (pointer intact)"
        fi
    done
done < "$REGISTRY_FILE"

if [[ $VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Anchor-Pointer Collapse Regression Summary"
        echo "================================"
        echo "Registry rows checked: $ROWS_CHECKED"
        echo "Migrated files checked: $FILES_CHECKED"
        echo "Total violations: 0"
        echo -e "${GREEN}No collapsed block has been reintroduced.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Anchor-Pointer Collapse Regression Summary"
echo "================================"
echo "Registry rows checked: $ROWS_CHECKED"
echo "Migrated files checked: $FILES_CHECKED"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS reintroduced collapsed block(s). See above for details.${NC}"
echo ""
echo "Fix: replace the reintroduced text with the one-line anchor pointer (see"
echo "context/standards/anchor-pointer-convention.md), or, if the text now genuinely differs"
echo "from the registered block, update lint/collapsed-blocks/ accordingly."
echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
exit 1
