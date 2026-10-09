#!/usr/bin/env bash
# lint-shellcheck.sh - Shellcheck lint gate for every tracked *.sh under agent-system/extensions/.
#
# WHY THIS EXISTS
# ----------------
# The agent system is ~359 bash scripts, and its own rules target exactly the silent-failure
# classes shellcheck detects at -S warning: masked exit codes (SC2155), cd-without-exit (SC2164),
# single-pass loops (SC2066), and unset/unassigned variables (SC2154) -- cf. the silent
# staging-drop incident this repository's own rules narrate elsewhere. Nothing upstream of a
# consumer repo's own CI ran shellcheck before this lint existed, so findings accumulated and
# only ever surfaced downstream, where they cannot be fixed at the source and every deploy could
# turn a consumer's CI red. The lint belongs where the scripts are authored: here.
#
# EXIT-CODE CONTRACT
# -------------------
#   0  - no findings at -S warning across every scanned file
#   1  - one or more findings
#   2  - script error: unresolvable project root, an explicit scan path that does not exist, or
#        an empty resulting file set (an empty set means the scan root or pathspec is wrong --
#        it must never read as a clean pass)
#   70 - the `shellcheck` binary is not resolvable on PATH. This is a named, non-zero failure,
#        never a silent skip and never a `bash -n` substitute -- precedent:
#        Logos/Verification's scripts/lint-shell.sh exit 70 convention.
#
# DUAL FILE-SET CONTRACT
# -----------------------
# With no positional scan path, the default scan is every tracked *.sh file under
# agent-system/extensions/ (all five extensions), discovered via `git ls-files` from the resolved
# repo root. With one or more explicit positional paths, each is walked with
# `find <path> -type f -name '*.sh'` instead -- `git ls-files` cannot serve a fixture test, whose
# scratch fixtures live under a `mktemp -d` workdir that is not a git work tree. Precedent:
# lint-state-writer-boundary.sh's identical no-argument-vs-explicit-path split.
#
# Usage: lint-shellcheck.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. A directory is walked recursively for
#              *.sh files via `find`. With no path argument, defaults to every tracked *.sh file
#              under $PROJECT_ROOT/agent-system/extensions (the source store -- .claude/ is a
#              disposable generated deploy artifact and is never the correct place to fix a
#              finding).
#   --verbose  Echo the resolved `shellcheck --version` line (so a future version drift is
#              diagnosable from gate output rather than mysterious) and per-file scan progress,
#              in addition to the per-finding [VIOLATION] lines.
#   --quiet    Counts only: suppress the progress header and every per-finding [VIOLATION] line,
#              printing only the final finding count. Exit status is unaffected either way.

set -euo pipefail

VERBOSE=false
QUIET=false
SCAN_PATHS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --quiet|-q)
            QUIET=true
            shift
            ;;
        -h|--help)
            sed -n '2,38p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            SCAN_PATHS+=("$1")
            shift
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "${SCRIPT_DIR}/../lib/common.sh" ]]; then
    echo "ERROR: shared library not found at ${SCRIPT_DIR}/../lib/common.sh" >&2
    exit 2
fi
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

# Root resolution. common_repo_root <dir> 3 is correct for the DEPLOYED copy
# (.claude/scripts/lint/), but this script also runs directly from the source store
# (agent-system/extensions/core/scripts/lint/), where 3 levels up lands inside the extension
# rather than at the repo root. Resolve by walking up until a directory containing
# agent-system/extensions is found, falling back to the common_repo_root answer.
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
if [[ -z "$PROJECT_ROOT" || ! -d "$PROJECT_ROOT" ]]; then
    echo "ERROR: could not resolve project root" >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Binary resolution -- never a silent skip, never a bash -n substitute.
# ---------------------------------------------------------------------------
SHELLCHECK_BIN=""
if command -v shellcheck >/dev/null 2>&1; then
    SHELLCHECK_BIN="$(command -v shellcheck)"
else
    echo "ERROR: shellcheck is not resolvable on PATH -- no substitute check was run." >&2
    echo "       Install shellcheck (e.g. via nix, apt, or brew) and re-run this lint." >&2
    exit 70
fi

if $VERBOSE; then
    echo "Resolved shellcheck: $SHELLCHECK_BIN"
    "$SHELLCHECK_BIN" --version | sed 's/^/  /'
fi

# ---------------------------------------------------------------------------
# Collect files to scan (dual file-set contract)
# ---------------------------------------------------------------------------
FILES=()
if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
    while IFS= read -r -d '' rel; do
        FILES+=("$PROJECT_ROOT/$rel")
    done < <(cd "$PROJECT_ROOT" && git ls-files -z -- 'agent-system/extensions/*.sh')
else
    for scan_path in "${SCAN_PATHS[@]}"; do
        if [[ -d "$scan_path" ]]; then
            while IFS= read -r found; do
                FILES+=("$found")
            done < <(find "$scan_path" -type f -name '*.sh' 2>/dev/null | sort)
        elif [[ -f "$scan_path" ]]; then
            FILES+=("$scan_path")
        else
            echo "ERROR: scan path not found: $scan_path" >&2
            exit 2
        fi
    done
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    echo "ERROR: no *.sh files found to scan -- the scan root or pathspec is wrong." >&2
    echo "       This is a script error (exit 2), never a silent clean pass." >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Run shellcheck and re-emit each finding as its own [VIOLATION]-prefixed line, so Gate 22 can
# reuse Gate 21's [VIOLATION] scrape verbatim.
# ---------------------------------------------------------------------------
$QUIET || {
    echo "Checking shellcheck compliance (-S warning)..."
    echo "Files to scan: ${#FILES[@]}"
    $VERBOSE && printf '  %s\n' "${FILES[@]}"
    echo ""
}

set +e
SHELLCHECK_OUTPUT="$("$SHELLCHECK_BIN" -x -S warning -f gcc "${FILES[@]}" 2>&1)"
SHELLCHECK_STATUS=$?
set -e

VIOLATIONS=0
if [[ -n "$SHELLCHECK_OUTPUT" ]]; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        ((VIOLATIONS++)) || true
        $QUIET || echo "[VIOLATION] $line"
    done <<< "$SHELLCHECK_OUTPUT"
fi

if [[ "$SHELLCHECK_STATUS" -eq 0 && "$VIOLATIONS" -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Shellcheck Summary"
        echo "================================"
        echo "Files checked: ${#FILES[@]}"
        echo "Total findings: 0"
        echo "No shellcheck findings at -S warning."
    }
    $QUIET && echo "0 finding(s) across ${#FILES[@]} file(s)"
    exit 0
fi

if [[ "$VIOLATIONS" -eq 0 && "$SHELLCHECK_STATUS" -ne 0 ]]; then
    # The tool itself errored (e.g. a parse failure) without emitting a gcc-format finding line.
    echo "ERROR: shellcheck exited $SHELLCHECK_STATUS with no parsed findings -- investigate:" >&2
    echo "$SHELLCHECK_OUTPUT" >&2
    exit 2
fi

$QUIET || {
    echo ""
    echo "================================"
    echo "Shellcheck Summary"
    echo "================================"
    echo "Files checked: ${#FILES[@]}"
    echo "Total findings: $VIOLATIONS"
    echo "Found $VIOLATIONS shellcheck finding(s) at -S warning. See above for details."
    echo ""
    echo "Fix: resolve each finding, or add an inline '# shellcheck disable=SCxxxx' with a"
    echo "one-line reason for a deliberate exception. Never a file- or repo-level disable."
    echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
}
$QUIET && echo "$VIOLATIONS finding(s) across ${#FILES[@]} file(s)"
exit 1
