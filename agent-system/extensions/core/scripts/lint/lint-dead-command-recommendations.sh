#!/usr/bin/env bash
# lint-dead-command-recommendations.sh - Flag a literal `Next: /X` or `Run /X` recommendation
# line that names a command with no definition file anywhere under
# agent-system/extensions/*/commands/*.md.
#
# WHY THIS EXISTS
# ----------------
# /implement, /research and /plan were removed from the agent system; /orchestrate is now the
# only lifecycle driver, and no other command replaced them. Despite that, source-store prose and
# embedded JSON examples kept recommending them as the actionable next step -- an agent faithfully
# rendering such a line reproduces an unrunnable recommendation. This lint is the regression guard
# against that defect class ever reappearing, for any current or future command, not just these
# three.
#
# VALID-COMMAND ENUMERATION (no hardcoded allowlist)
# ----------------------------------------------------
# The valid-command set is derived at run time by enumerating every `*/commands/*.md` file
# reachable from the resolved extensions root (and, additively, from each directory passed as an
# explicit scan-path argument -- this is what lets the fixture suite's self-updating-behavior case
# add a synthetic command to the valid set without touching this script). `README.md` is excluded
# case-insensitively: it is the one real-world non-command file living alongside actual command
# definitions. A command name is valid if and only if a `commands/<name>.md` file exists somewhere
# in that enumeration; nothing is ever hardcoded here, so adding or removing a command file
# changes this lint's verdict on the next run with no edit to this script.
#
# NET-SIZE RATIONALE (why this is a new file, not an extension of an existing lint)
# -------------------------------------------------------------------------------------
# Two candidate hosts were read in full before deciding to add a new file. lint-routing-wiring.sh
# operates purely on manifest.json `routing_agents` keys plus agent-file existence via jq; it never
# enumerates `commands/*.md` at all, and its manifest-keyed detection model is incompatible with a
# line-oriented full-corpus text scan for a recommendation SHAPE. lint-contract-compliance.sh is
# scoped specifically to hard-mode behavioral contracts, an unrelated concern. Neither is a natural
# host. The additive cost of a new file is held down by reusing lint-corpus-scan-lib.sh for the
# file-collection and flag-parsing layers rather than reimplementing either.
#
# SCOPE: THE FULL CORPUS, NOT THE EXECUTABLE-SURFACE SUBSET
# -------------------------------------------------------------
# context/patterns/adoption-lint-conventions.md scopes an adoption lint to `scripts/*.sh` plus
# `*.md` restricted to `commands/`, `skills/`, `agents/`, treating `docs/`, `context/`, `rules/` as
# out of scope "by construction". This lint is a different class: an actionable recommendation
# line IS the defect wherever it is rendered, including in `context/` and `docs/` prose and in a
# `.json` embedded example string. Only that document's dual-mode-root-resolution shape transfers
# here; its scope restriction does not. Zero-tolerance, no allowlist: this lint retires its own
# findings to zero within the same landing event, which is the decision rule's own criterion for
# skipping the allowlist convention entirely.
#
# DETECTION MODEL
# -----------------
# Two layers, applied in order:
#   Layer 1 (broad candidate scan): any line containing the literal text `Next:` or the standalone
#     word `Run` is a candidate -- deliberately broad; Layer 2 narrows it.
#   Layer 2 (shape + enumeration classification): the candidate line is first normalized by
#     stripping backtick/asterisk/underscore markdown-emphasis characters (so `` Next: `/plan 1` ``
#     and `**Run** /plan` classify identically to the unadorned form), then tested against the
#     anchored shape `Next:` optionally followed by `Run`, directly followed by `/<name>`; or the
#     standalone word `Run` directly followed by `/<name>`. A line with no such shape is EXEMPT
#     (no recommendation at all). A line with the shape is a VIOLATION unless `<name>` is in the
#     enumerated valid-command set, in which case it is EXEMPT (a real, invocable command).
#
# KNOWN LIMITATION (stated plainly rather than papered over)
# ------------------------------------------------------------
# This is a regex-only, line-oriented content lint. It cannot see a recommendation assembled
# across more than one physical line, built up via string concatenation/interpolation, or named
# only indirectly through a variable. A clean run means "no literal `Next:`/`Run` line names an
# undefined command", never "every possible recommendation in this corpus is runnable".
#
# Usage: lint-dead-command-recommendations.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. A directory is scanned for `*.md` and
#              `*.json` files recursively. Defaults to the resolved project root's
#              agent-system/extensions directory (the whole source-store corpus, no per-extension
#              restriction).
#   --verbose  Report every candidate line found, including exempt ones, tagged with the reason
#              each was exempted.
#   --quiet    Suppress the progress header and the all-clear summary. Violations are still
#              printed, and the failing summary is still printed, so a failing run is never
#              silent.
#
# Exit codes:
#   0 - No unexcused violations found
#   1 - One or more unexcused violations found (each printed as file:line plus the dead command)
#   2 - Script error (unresolvable project root, missing shared library, unreadable scan path, or
#       an empty valid-command enumeration -- almost always a wrong-root symptom)

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
# Root resolution: dual-mode probe, copied in shape from lint-state-writer-boundary.sh /
# lint-task-lookup-adoption.sh so this script runs identically from the source-store copy
# (agent-system/extensions/core/scripts/lint/) or the deployed copy (.claude/scripts/lint/) --
# both live in the same repository, and both resolve to the same agent-system/extensions corpus.
# The acceptance test for each candidate is common_test_ext_root succeeding against it, not a
# bare `-d "$candidate/agent-system/extensions"` check -- this admits the
# .claude-extensions.json core.source_dir indirection for a repository whose source store is
# external, exactly like deploy-root-guard.sh's own widened self-correction acceptance test.
# ---------------------------------------------------------------------------
resolve_project_root() {
    local candidate
    candidate="$(common_repo_root "$SCRIPT_DIR" 3)"
    if [[ -n "$candidate" ]] && common_test_ext_root "$candidate" >/dev/null; then
        printf '%s\n' "$candidate"
        return 0
    fi

    local dir="$SCRIPT_DIR"
    local i=0
    while [[ $i -lt 8 ]]; do
        dir="$(cd "$dir/.." 2>/dev/null && pwd)" || break
        [[ -z "$dir" || "$dir" == "/" ]] && break
        if common_test_ext_root "$dir" >/dev/null; then
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
    # DEFAULT_SCAN: the resolved extensions root, through the SAME shared resolver (repo-root
    # source store first, then the .claude-extensions.json core.source_dir indirection) -- not a
    # bare "$PROJECT_ROOT/agent-system/extensions" path, which cannot exist at all once
    # PROJECT_ROOT itself only resolved via the indirection branch above.
    DEFAULT_SCAN="$(common_test_ext_root "$PROJECT_ROOT")"
    if [[ -z "$DEFAULT_SCAN" || ! -d "$DEFAULT_SCAN" ]]; then
        echo "ERROR: default scan root not found under $PROJECT_ROOT (tried a local" >&2
        echo "       agent-system/extensions directory, then the .claude-extensions.json" >&2
        echo "       core.source_dir indirection)" >&2
        echo "       Pass explicit path arguments, or run from a checkout containing the source store." >&2
        exit 2
    fi
    SCAN_PATHS=("$DEFAULT_SCAN")
fi

# ---------------------------------------------------------------------------
# Valid-command enumeration. No hardcoded allowlist anywhere in this file: the set is built by
# walking the filesystem. Always includes the real repository's extensions root (so a single-file
# scan-path argument, e.g. the fixture suite's negative case naming /orchestrate, still resolves
# against the real command set) and additively includes every explicit directory scan-path
# argument (so a fixture scratch tree's own commands/ directory can introduce a synthetic command
# into the valid set, proving the enumeration is derived rather than hardcoded).
# ---------------------------------------------------------------------------
shopt -s nullglob
declare -A VALID_SET=()

collect_commands_from_root() {
    local root="$1"
    local f b
    # Shape A: root/*/commands/*.md -- a multi-extension parent (the real extensions/ directory,
    # or a scratch tree mimicking its shape).
    for f in "$root"/*/commands/*.md; do
        [[ -f "$f" ]] || continue
        b="$(basename "$f")"
        [[ "${b,,}" == "readme.md" ]] && continue
        VALID_SET["${b%.md}"]=1
    done
    # Shape B: root/commands/*.md -- root IS itself a single extension directory (or a scratch
    # tree built that way).
    for f in "$root"/commands/*.md; do
        [[ -f "$f" ]] || continue
        b="$(basename "$f")"
        [[ "${b,,}" == "readme.md" ]] && continue
        VALID_SET["${b%.md}"]=1
    done
}

VALID_SET_ROOT="$(common_test_ext_root "$PROJECT_ROOT")"
if [[ -n "$VALID_SET_ROOT" ]]; then
    collect_commands_from_root "$VALID_SET_ROOT"
fi
if [[ ${#VALID_SET[@]} -eq 0 ]]; then
    echo "ERROR: valid-command enumeration yielded an empty set under $PROJECT_ROOT" >&2
    echo "       (tried a local agent-system/extensions directory, then the" >&2
    echo "       .claude-extensions.json core.source_dir indirection)." >&2
    echo "       This almost always means the project root resolved incorrectly. Pass explicit" >&2
    echo "       path arguments, or run from a checkout containing the agent-system/extensions source store." >&2
    exit 2
fi
for _p in "${SCAN_PATHS[@]}"; do
    [[ -d "$_p" ]] && collect_commands_from_root "$_p"
done
unset _p

# ---------------------------------------------------------------------------
# Collect files to scan: *.md and *.json under every scan path, full corpus (no commands/skills/
# agents restriction -- see SCOPE note in the header).
# ---------------------------------------------------------------------------
FILES=()
lint_corpus_scan_collect_files FILES "${DEFAULT_SCAN:-}" '*.md' '*.json' -- "${SCAN_PATHS[@]}" || exit 2

# ---------------------------------------------------------------------------
# Layer 1: broad candidate pattern
# ---------------------------------------------------------------------------
CANDIDATE_PATTERN='Next:|\<Run\>'

# ---------------------------------------------------------------------------
# Layer 2: shape + enumeration classification of a single candidate line.
# Echoes "VIOLATION:<command>" or "EXEMPT: <reason>".
# ---------------------------------------------------------------------------
classify_line() {
    local text="$1"
    local norm
    norm="$(printf '%s' "$text" | tr -d '`*_')"

    local cmd=""
    if [[ "$norm" =~ Next:[[:space:]]*(Run[[:space:]]+)?/([A-Za-z][A-Za-z0-9_-]*) ]]; then
        cmd="${BASH_REMATCH[2]}"
    elif [[ "$norm" =~ (^|[^A-Za-z])Run[[:space:]]+/([A-Za-z][A-Za-z0-9_-]*) ]]; then
        cmd="${BASH_REMATCH[2]}"
    fi

    if [[ -z "$cmd" ]]; then
        printf 'EXEMPT: no Next:/Run recommendation shape on this line\n'
        return 0
    fi

    if [[ -n "${VALID_SET[$cmd]+x}" ]]; then
        printf 'EXEMPT: /%s is a defined command\n' "$cmd"
        return 0
    fi

    printf 'VIOLATION:%s\n' "$cmd"
    return 0
}

# ---------------------------------------------------------------------------
# Main scan
# ---------------------------------------------------------------------------
VIOLATIONS=0
CANDIDATES=0
FILES_CHECKED=0
FILES_WITH_VIOLATIONS=0
EXEMPTED=0

$QUIET || {
    echo "Checking dead-command-recommendation compliance..."
    echo "Scan roots: ${SCAN_PATHS[*]}"
    echo "Valid commands enumerated: ${#VALID_SET[@]}"
    echo ""
}

for file in "${FILES[@]}"; do
    ((FILES_CHECKED++)) || true

    matches=""
    matches="$(grep -nE "$CANDIDATE_PATTERN" "$file" 2>/dev/null || true)"
    [[ -z "$matches" ]] && continue

    file_violations=0
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        lineno="${match%%:*}"
        text="${match#*:}"
        text="${text#"${text%%[![:space:]]*}"}"
        ((CANDIDATES++)) || true

        verdict="$(classify_line "$text")"
        if [[ "$verdict" == VIOLATION:* ]]; then
            cmd="${verdict#VIOLATION:}"
            echo -e "${RED}[VIOLATION]${NC} $file:$lineno: /$cmd has no definition file | $text"
            ((file_violations++)) || true
            ((VIOLATIONS++)) || true
        else
            ((EXEMPTED++)) || true
            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$lineno: ${verdict#EXEMPT: } | $text"
        fi
    done <<< "$matches"

    if [[ $file_violations -gt 0 ]]; then
        ((FILES_WITH_VIOLATIONS++)) || true
    fi
done

if [[ $VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Dead-Command-Recommendation Check Summary"
        echo "================================"
        echo "Files checked: $FILES_CHECKED"
        echo "Candidate lines scanned: $CANDIDATES"
        echo "Candidate lines exempted: $EXEMPTED"
        echo "Total violations: 0"
        echo -e "${GREEN}No recommendation names a command with no definition file.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Dead-Command-Recommendation Check Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Files with violations: $FILES_WITH_VIOLATIONS"
echo "Candidate lines scanned: $CANDIDATES"
echo "Candidate lines exempted: $EXEMPTED"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS dead-command recommendation(s). See above for details.${NC}"
echo ""
echo "Fix: retarget the recommendation onto /orchestrate, the only lifecycle driver that exists."
echo "Never invent a replacement command. Edit the source store under agent-system/extensions/ --"
echo ".claude/ is a generated artifact."
exit 1
