#!/usr/bin/env bash
# lint-deliberate-break-residue.sh - Detect residue of the deliberate-break-on-the-source-store
# anti-pattern: a suite that proves a regression anchor is not passing vacuously by temporarily
# re-gating a production script's own live logic in the shared source store, rather than on a
# sandbox or scratch copy.
#
# WHY THIS EXISTS
# ----------------
# A suite's regression-anchor check exists to prove its own fixture is not passing vacuously: it
# temporarily re-gates a block of a real collaborator script on a deliberately-false condition,
# confirms the fixture goes RED, then reverts. This technique is legitimate and documented. Its
# defect is blast radius, not existence: when the mutation is applied to the real source-store
# file rather than to a sandbox copy under test, the mutated file is live in the SHARED WORKING
# TREE for the whole duration of that fixture. Any concurrently running session -- another task's
# verification run, a gate, an unrelated orchestration cycle -- can read the broken collaborator
# script during that window, with no way to know why. A backup/restore pair plus an EXIT trap is
# recovery, not containment: a trap does not fire on SIGKILL, an OOM kill, or a host crash, and
# even a perfect restore does not erase the observation window.
#
# This lint reports two mechanical, unambiguous residue signals of the anti-pattern having been
# applied to the real source store rather than to a sandbox copy:
#   Check A -- a line beginning (after leading whitespace) with the literal guard
#              `while false &&` in a *.sh file. Such a guard is never legitimate production
#              code; it is the deliberate-false re-gate itself, caught live or left behind.
#   Check B -- a leftover `*.anchor-bak` file, the backup half of the old backup/restore
#              pattern. Its mere presence implies a crashed or otherwise incomplete restore.
#
# KNOWN LIMITATION (stated plainly rather than papered over)
# ------------------------------------------------------------
# This is a regex-only, line-oriented content lint plus a filename-pattern check. It therefore
# CANNOT see:
#   - An indirected mutation: a `while false &&` guard assembled across more than one line, or
#     held in a variable and substituted in later (e.g. a pattern built with `sed` into a
#     variable, never written as the literal text on any one line of the file itself).
#   - A backup file given a different name than the literal `*.anchor-bak` suffix.
# A clean run means "the known bad shapes are not present"; it never means "no source-store
# mutation exists". This lint is a guardrail against the recognizable, literal-text residue of a
# known incident, not a proof that the shared tree was never written mid-run.
#
# ADVISORY / GATE-LEVEL BY CONSTRUCTION
# ---------------------------------------
# This detector runs as part of an explicit gate pass (see gate 28 in verify-deploy.sh), never as
# a write-time PreToolUse block. A suite exercising the regression-anchor technique on a sandbox
# copy legitimately holds no such residue at all; one still exercising the anti-pattern on the
# real source store legitimately holds the mutation for the duration of one fixture -- a
# write-time block would make the technique unusable mid-run. The gate-level check catches what
# is left behind after a run, or what is caught by a concurrent gate invocation during one.
#
# SELF-EXCLUSION (the detector's main design problem, solved explicitly, never by a path
# exclusion)
# -----------------------------------------------------------------------------------------
# Check A's pattern is deliberately ANCHORED to the start of the line (after leading whitespace):
# `^[[:space:]]*while false[[:space:]]*&&`. A `sed` substitution replacement string containing
# the same phrase as quoted text -- for example
# `sed -i "s/^ *while IFS=.../ *while false \&\& IFS=.../"` -- never itself STARTS a line with
# that phrase; the line starts with `sed` (or whatever constructs the string). This is why no
# path exclusion is used: a path exclusion would also blind the detector to a real mutation
# planted directly in a test file's own fixture text, which is exactly where the anti-pattern's
# source lives. The anchored-start regex separates the two cases by shape, not by location.
#
# DETECTION MODEL
# -----------------
# Two independent checks, applied to every file under the scanned roots:
#   Check A: `grep -nE '^[[:space:]]*while false[[:space:]]*&&'` against every `*.sh` file.
#   Check B: `find ... -name '*.anchor-bak'` under the scanned roots (any file type).
# Each finding is reported as a `[VIOLATION]` line so `verify_deploy_extract_verdict_lines
# '[VIOLATION]' ...` can harvest it, matching gate 27's own consumer shape.
#
# Usage: lint-deliberate-break-residue.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. A directory is scanned recursively for
#              *.sh files (Check A) and any *.anchor-bak file (Check B). Defaults to
#              $PROJECT_ROOT/agent-system/extensions (the source store -- .claude/ is a
#              disposable generated deploy artifact and is never the correct place to fix a
#              finding).
#   --verbose  Report scan progress (files checked, scan roots) in addition to violation lines.
#   --quiet    Suppress the progress header and the all-clear summary. Violations are still
#              printed, and the failing summary is still printed, so a failing run is never
#              silent.
#   --help/-h  Print this header and exit 0.
#
# Exit codes:
#   0 - No findings (clean)
#   1 - One or more findings (Check A and/or Check B)
#   2 - Script error (unresolvable project root, missing shared library, unreadable scan path)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -h/--help prints this script's own header and exits before anything else runs, matching
# lint-shellcheck.sh's precedent for the one argument not shared with the rest of the cluster.
for _ldbr_arg in "$@"; do
    if [[ "$_ldbr_arg" == "-h" || "$_ldbr_arg" == "--help" ]]; then
        sed -n '2,78p' "$0" | sed 's/^# \{0,1\}//'
        exit 0
    fi
done
unset _ldbr_arg

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

# Root resolution, mirroring lint-scoped-commit-boundary.sh's own resolve_project_root: this
# script also runs directly from the source store (agent-system/extensions/core/scripts/lint/),
# where common_repo_root's levels-up assumption lands inside the extension rather than at the
# repo root.
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

if [[ ${#SCAN_PATHS[@]} -eq 0 ]]; then
    DEFAULT_SCAN="$PROJECT_ROOT/agent-system/extensions"
    if [[ ! -d "$DEFAULT_SCAN" ]]; then
        echo "ERROR: default scan root not found: $DEFAULT_SCAN" >&2
        echo "       Pass explicit path arguments, or run from a checkout containing the source store." >&2
        exit 2
    fi
    SCAN_PATHS=("$DEFAULT_SCAN")
fi

$QUIET || {
    echo "Checking for deliberate-break source-store residue..."
    echo "Scan roots: ${SCAN_PATHS[*]}"
    echo ""
}

# ---------------------------------------------------------------------------
# Check A: an anchored-start `while false &&` guard in a *.sh file
# ---------------------------------------------------------------------------
SH_FILES=()
lint_corpus_scan_collect_files SH_FILES "${DEFAULT_SCAN:-}" '*.sh' -- "${SCAN_PATHS[@]}" || exit 2

CHECK_A_PATTERN='^[[:space:]]*while false[[:space:]]*&&'
CHECK_A_VIOLATIONS=0
CHECK_A_FILES_CHECKED=0

for file in "${SH_FILES[@]}"; do
    ((CHECK_A_FILES_CHECKED++)) || true
    $VERBOSE && echo "  [scan] $file"

    matches="$(grep -nE "$CHECK_A_PATTERN" "$file" 2>/dev/null || true)"
    [[ -z "$matches" ]] && continue

    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        lineno="${match%%:*}"
        text="${match#*:}"
        text="${text#"${text%%[![:space:]]*}"}"
        echo -e "${RED}[VIOLATION]${NC} $file:$lineno: anchored-start 'while false &&' guard | $text"
        ((CHECK_A_VIOLATIONS++)) || true
    done <<< "$matches"
done

# ---------------------------------------------------------------------------
# Check B: a leftover *.anchor-bak file under the scanned roots
# ---------------------------------------------------------------------------
CHECK_B_VIOLATIONS=0

for scan_path in "${SCAN_PATHS[@]}"; do
    if [[ -d "$scan_path" ]]; then
        while IFS= read -r found; do
            [[ -z "$found" ]] && continue
            echo -e "${RED}[VIOLATION]${NC} $found: leftover *.anchor-bak file (surviving backup implies a crashed or incomplete restore)"
            ((CHECK_B_VIOLATIONS++)) || true
        done < <(find "$scan_path" -type f -name '*.anchor-bak' 2>/dev/null | sort)
    elif [[ -f "$scan_path" ]]; then
        case "$scan_path" in
            *.anchor-bak)
                echo -e "${RED}[VIOLATION]${NC} $scan_path: leftover *.anchor-bak file (surviving backup implies a crashed or incomplete restore)"
                ((CHECK_B_VIOLATIONS++)) || true
                ;;
        esac
    else
        echo "ERROR: scan path not found: $scan_path" >&2
        exit 2
    fi
done

TOTAL_VIOLATIONS=$((CHECK_A_VIOLATIONS + CHECK_B_VIOLATIONS))

if [[ $TOTAL_VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Deliberate-Break Residue Check Summary"
        echo "================================"
        echo "*.sh files checked (Check A): $CHECK_A_FILES_CHECKED"
        echo "Check A violations (while false && guard): 0"
        echo "Check B violations (*.anchor-bak residue): 0"
        echo -e "${GREEN}No deliberate-break source-store residue found.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Deliberate-Break Residue Check Summary"
echo "================================"
echo "*.sh files checked (Check A): $CHECK_A_FILES_CHECKED"
echo "Check A violations (while false && guard): $CHECK_A_VIOLATIONS"
echo "Check B violations (*.anchor-bak residue): $CHECK_B_VIOLATIONS"
echo "Total violations: $TOTAL_VIOLATIONS"
[[ $CHECK_A_VIOLATIONS -gt 0 ]] && echo -e "${RED}Found $CHECK_A_VIOLATIONS anchored-start 'while false &&' guard(s). See above for details.${NC}"
[[ $CHECK_B_VIOLATIONS -gt 0 ]] && echo -e "${RED}Found $CHECK_B_VIOLATIONS leftover *.anchor-bak file(s). See above for details.${NC}"
echo ""
echo "Fix (Check A): if this is a genuine deliberate-break regression-anchor technique, apply the"
echo "mutation to a sandbox or scratch copy produced after the collaborator's setup step, never to"
echo "the real source-store file; if it is leftover residue from an interrupted run, revert it."
echo "Fix (Check B): remove the leftover *.anchor-bak file, and if it recurs, replace the"
echo "backup/restore pattern with a sandbox-copy mutation so no backup is ever created."
echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
exit 1
