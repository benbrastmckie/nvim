#!/usr/bin/env bash
# lint-extension-readme-table.sh - Bidirectionally diff the real agent-system/extensions/*/
# directory set against the first column of agent-system/extensions/README.md's Available
# Extensions table, so the two can never silently drift apart again.
#
# WHY THIS EXISTS
# ----------------
# The Available Extensions table is the only extension inventory a human reads, but nothing
# mechanically checked it against the real directory set. A prior task's Phase 1 had to
# manually correct four missing rows (books, cslib, email, literature) because the drift went
# undetected. This lint is the regression guard: a real extension directory with no table row,
# or a table row naming no real directory, is now a loud, mechanical failure.
#
# DETECTION MODEL
# -----------------
# A bidirectional set diff of two things only: the basenames of
# agent-system/extensions/*/ (minus the `core` exemption below) versus the first pipe-delimited
# cell of every data row in the `## Available Extensions` table. Order-blind, description-blind,
# Docs-link-blind -- this lint checks set membership of the first column only, never row order,
# description text, or link targets.
#
# THE `core` EXEMPTION
# ---------------------
# `core` is excluded from the directory set by an explicit, hardcoded string comparison, not by
# any manifest field. `core` is the unconditionally-loaded base system, deliberately not a
# pickable "available extension", so it has no table row by design. `routing_exempt: true` in
# manifest.json is NOT a usable proxy for this exemption: `approvals`, `slidev`, and `sapience`
# all set `routing_exempt: true` too, and all three belong in the table with a `Task Type: -`
# row. Only `core` itself is excluded.
#
# NET-SIZE RATIONALE (why this is a new file, not an extension of an existing lint)
# -------------------------------------------------------------------------------------
# check-extension-docs.sh and lint-routing-wiring.sh were both read before deciding to add a new
# file. Neither reads the top-level agent-system/extensions/README.md at all, and neither's
# detection model (per-extension doc-presence checks; manifest.json routing_agents keys via jq)
# fits a markdown-table-vs-directory-set diff. A new, small file reusing
# lint-corpus-scan-lib.sh's shared flag-parsing layer is the right shape.
#
# INPUT CONTRACT
# ----------------
# A single optional positional EXTENSIONS_ROOT (the first SCAN_PATHS entry after flag parsing),
# defaulting to $PROJECT_ROOT/agent-system/extensions. The lint reads <root>/README.md and
# enumerates <root>/*/ from that same root -- a single-root shape, not two independent path
# overrides, so one scratch directory is a complete fixture for the regression suite.
#
# Usage: lint-extension-readme-table.sh [--verbose] [--quiet] [EXTENSIONS_ROOT]
#
#   EXTENSIONS_ROOT  Optional. Directory whose immediate subdirectories are the extension set and
#                     whose README.md holds the Available Extensions table. Defaults to the
#                     resolved project root's agent-system/extensions directory.
#   --verbose         Report the `core` exemption line (and nothing else beyond the normal
#                     violation/summary output -- this lint has no other EXEMPT-tagged lines).
#   --quiet           Suppress the progress header and the all-clear summary. Violations are
#                     still printed, and the failing summary is still printed, so a failing run
#                     is never silent.
#
# Exit codes:
#   0 - No violations found (every non-core directory has a row; every row names a real
#       directory)
#   1 - One or more violations found (each printed as a [VIOLATION]-tagged line)
#   2 - Script error (unresolvable project root, missing shared library, missing README.md, no
#       `## Available Extensions` heading found, or an empty directory enumeration -- each a
#       loud named failure, never a silent pass)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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
# Root resolution: dual-mode probe, copied in shape from
# lint-dead-command-recommendations.sh / lint-state-writer-boundary.sh so this script runs
# identically from the source-store copy (agent-system/extensions/core/scripts/lint/) or the
# deployed copy (.claude/scripts/lint/) -- both live in the same repository, and both resolve to
# the same agent-system/extensions corpus.
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

PROJECT_ROOT="$(resolve_project_root)"

if [[ ${#SCAN_PATHS[@]} -gt 0 ]]; then
    EXTENSIONS_ROOT="${SCAN_PATHS[0]}"
else
    EXTENSIONS_ROOT="$PROJECT_ROOT/agent-system/extensions"
fi

if [[ ! -d "$EXTENSIONS_ROOT" ]]; then
    echo "ERROR: extensions root not found: $EXTENSIONS_ROOT" >&2
    exit 2
fi

README_PATH="$EXTENSIONS_ROOT/README.md"
if [[ ! -f "$README_PATH" ]]; then
    echo "ERROR: README.md not found at $README_PATH" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Directory enumeration: every immediate subdirectory of EXTENSIONS_ROOT, basename only,
# excluding the literal `core` (see THE `core` EXEMPTION header note above for why no manifest
# field is a usable substitute).
# ---------------------------------------------------------------------------
shopt -s nullglob
declare -a DIR_SET=()
CORE_PRESENT=false
for d in "$EXTENSIONS_ROOT"/*/; do
    [[ -d "$d" ]] || continue
    b="$(basename "$d")"
    if [[ "$b" == "core" ]]; then
        CORE_PRESENT=true
        continue
    fi
    DIR_SET+=("$b")
done

if [[ ${#DIR_SET[@]} -eq 0 ]]; then
    echo "ERROR: directory enumeration yielded an empty set under $EXTENSIONS_ROOT (excluding core)" >&2
    echo "       This almost always means the project root resolved incorrectly. Pass an explicit" >&2
    echo "       EXTENSIONS_ROOT argument, or run from a checkout containing the agent-system/extensions source store." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Table parsing: locate the `## Available Extensions` heading, skip the header and separator
# rows, and extract the first pipe-delimited cell of each subsequent table row until the table
# ends (first non-`|` line).
# ---------------------------------------------------------------------------
if ! grep -q '^## Available Extensions' "$README_PATH"; then
    echo "ERROR: no '## Available Extensions' heading found in $README_PATH" >&2
    exit 2
fi

declare -a TABLE_ROWS=()
in_table=0
saw_header=0
saw_separator=0
while IFS= read -r line; do
    if [[ "$in_table" -eq 0 ]]; then
        if [[ "$line" == "## Available Extensions"* ]]; then
            in_table=1
        fi
        continue
    fi
    # Inside the section: skip blank lines until the table header starts.
    if [[ "$saw_header" -eq 0 ]]; then
        if [[ "$line" == \|* ]]; then
            saw_header=1
        fi
        continue
    fi
    if [[ "$saw_separator" -eq 0 ]]; then
        # Separator row: |---|---|...
        saw_separator=1
        continue
    fi
    # Table body: a line starting with `|` is a data row; the first non-`|` line ends the table.
    if [[ "$line" != \|* ]]; then
        break
    fi
    cell="${line#|}"
    cell="${cell%%|*}"
    # Trim leading/trailing whitespace.
    cell="${cell#"${cell%%[![:space:]]*}"}"
    cell="${cell%"${cell##*[![:space:]]}"}"
    # Strip optional surrounding backticks so the parser is robust to either styling.
    cell="${cell#\`}"
    cell="${cell%\`}"
    [[ -z "$cell" ]] && continue
    TABLE_ROWS+=("$cell")
done < "$README_PATH"

if [[ "$saw_header" -eq 0 ]]; then
    echo "ERROR: '## Available Extensions' heading found but no table header row followed it in $README_PATH" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Bidirectional diff.
# ---------------------------------------------------------------------------
declare -A DIR_IN_SET=()
for b in "${DIR_SET[@]}"; do
    DIR_IN_SET["$b"]=1
done
declare -A ROW_IN_SET=()
for r in "${TABLE_ROWS[@]}"; do
    ROW_IN_SET["$r"]=1
done

VIOLATIONS=0
declare -a MISSING_ROWS=()
declare -a DANGLING_ROWS=()

for b in "${DIR_SET[@]}"; do
    if [[ -z "${ROW_IN_SET[$b]+x}" ]]; then
        MISSING_ROWS+=("$b")
    fi
done
for r in "${TABLE_ROWS[@]}"; do
    if [[ -z "${DIR_IN_SET[$r]+x}" ]]; then
        DANGLING_ROWS+=("$r")
    fi
done

$QUIET || {
    echo "Checking Available Extensions table against the real extension directory set..."
    echo "Extensions root: $EXTENSIONS_ROOT"
    echo "Directories (excluding core): ${#DIR_SET[@]}"
    echo "Table rows: ${#TABLE_ROWS[@]}"
    echo ""
}

if $CORE_PRESENT && $VERBOSE; then
    echo -e "${YELLOW}[EXEMPT]${NC} core: unconditionally-loaded base system, deliberately not a pickable extension; never requires a table row"
fi

for b in "${MISSING_ROWS[@]}"; do
    echo -e "${RED}[VIOLATION]${NC} $README_PATH: directory '$b' has no Available Extensions table row"
    ((VIOLATIONS++)) || true
done
for r in "${DANGLING_ROWS[@]}"; do
    echo -e "${RED}[VIOLATION]${NC} $README_PATH: table row '$r' names no real extension directory"
    ((VIOLATIONS++)) || true
done

if [[ "$VIOLATIONS" -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Extension README Table Check Summary"
        echo "================================"
        echo "Directories checked: ${#DIR_SET[@]}"
        echo "Table rows checked: ${#TABLE_ROWS[@]}"
        echo "Total violations: 0"
        echo -e "${GREEN}Every non-core extension directory has a table row, and every table row names a real directory.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Extension README Table Check Summary"
echo "================================"
echo "Directories checked: ${#DIR_SET[@]}"
echo "Table rows checked: ${#TABLE_ROWS[@]}"
echo "Missing rows: ${#MISSING_ROWS[@]}"
echo "Dangling rows: ${#DANGLING_ROWS[@]}"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS table/directory mismatch(es). See above for details.${NC}"
echo ""
echo "Fix: add a table row for each missing directory, and remove each dangling row, in"
echo "$README_PATH. Edit the source store under agent-system/extensions/README.md --"
echo ".claude/ is a generated artifact."
exit 1
