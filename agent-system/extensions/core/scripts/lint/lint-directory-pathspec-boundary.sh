#!/usr/bin/env bash
# lint-directory-pathspec-boundary.sh - Detect a bare SHARED-directory pathspec passed to
# git-commit-scoped.sh across the source store.
#
# A `git-commit-scoped.sh` call that ends in `-- specs/` (or `-- .claude/`, or any other bare
# shared-directory token) stages the ENTIRE shared tree under that directory, not just the
# files this call site itself wrote. Under two concurrent /orchestrate sessions this sweeps
# session B's in-progress, uncommitted specs/ artifacts into session A's commit the moment A
# commits next -- the mode-1b bleed this lint guards against. git-commit-scoped.sh's own V5
# per-path contention-claim check cannot compensate for this: V5 compares pathspec tokens by
# exact string equality against specs/.contention-claims/ manifest entries, so a `specs/` token
# can never match a file-path manifest entry and simply slips past (confirmed by direct code
# reading, not assumed -- see specs/309_replace_directory_pathspecs_with_explicit_file_lists/
# reports/01_directory-pathspec-v5-gap.md). The fix belongs at the call site, not inside the
# primitive: replace the bare directory token with the explicit file list the recipe actually
# touches. This lint is the guardrail against that pattern regrowing.
#
# IMPORTANT DISTINCTION FROM lint-scoped-commit-boundary.sh
# -----------------------------------------------------------
# That sibling lint treats "ends in a trailing `-- <pathspec>`" as the COMPLIANT shape (it is
# guarding against a hand-rolled bare commit invocation with no pathspec at all). This lint
# guards the
# opposite failure mode: a call that DOES end in a trailing pathspec, but that pathspec is
# itself a bare, non-task-scoped directory. The two lints are complementary, not overlapping --
# a call site can satisfy one and violate the other.
#
# A TASK-SCOPED directory pathspec (e.g. `-- "${task_dir}/"` or
# `-- "specs/${padded_num}_${slug}/reports/"`) is explicitly SANCTIONED by
# context/standards/git-staging-scope.md's own per-operation scope and is NOT flagged here: it
# names one task's own directory, so a cross-session bleed is impossible by construction. Only
# a SHARED directory token -- one with no task-identifying component -- is a violation.
#
# DETECTION MODEL
# ----------------
# Three layers, applied in order:
#
#   Layer 1 (candidate window): a line containing the literal text "git-commit-scoped.sh" opens
#     a window. The window extends across subsequent lines while each line ends in a backslash
#     continuation (`\`), and closes at the first line that does not (this may be the opening
#     line itself, for a single-line invocation). The assembled window text is then searched for
#     a trailing, whitespace-delimited `--` token; everything after it is the pathspec tail.
#
#   Layer 2 (structural classifier): the pathspec tail is split into whitespace-delimited
#     tokens (quote-aware, via `xargs -n1`, which strips quoting but never expands `$`
#     variables, so a literal `${...}` or `{N}`-style placeholder token survives verbatim). Each
#     token is then classified:
#       - A `:(exclude)...` token is never a positive pathspec and is skipped entirely.
#       - A token that does NOT end in `/` is an explicit file path -- EXEMPT.
#       - A token that ends in `/` AND carries a `${...}` interpolation, a `{N}`/`{NNN}`-style
#         placeholder, OR a literal `{NNN}_{SLUG}`/`{N}_{SLUG}`-convention directory segment
#         already substituted with a concrete task number (matched as `/[0-9]+_`, e.g. a
#         worked, already-rendered example like `specs/427_some-slug/reports/`) is a task-scoped
#         directory -- EXEMPT (sanctioned, see above).
#       - A token that ends in `/` with no such component is a bare shared directory --
#         VIOLATION.
#
#   Layer 3 (file-level allowlist): a short list of files that legitimately contain the
#     violation shape as fixture text rather than a live call site (this lint's own test, and
#     itself). Every entry carries its reason inline. No entry may stand in for an unfixed
#     real violation.
#
# KNOWN LIMITATION (stated plainly rather than papered over)
# ------------------------------------------------------------
# This is a regex/line-oriented content lint, the same class of tool as its sibling. It
# therefore CANNOT catch:
#   - A variable-indirected pathspec, e.g. `-- "${stage_paths[@]}"` where `stage_paths` is built
#     elsewhere and might itself be assembled from a bare directory. Such a token does not end
#     in `/` as WRITTEN, so it classifies as an explicit file path (EXEMPT) regardless of what
#     the variable resolves to at runtime. A reviewer must still read the surrounding steps that
#     populate the variable.
#   - An invocation assembled across more lines than the backslash-continuation window reads
#     (e.g. the script path and its `--` pathspec built on separate, non-continued statements).
#   - A pathspec token split unusually across a line break inside an unterminated quote.
# A clean run means "no bare shared-directory pathspec TOKEN, as written, was found" -- never a
# proof that every git-commit-scoped.sh call site stages exactly what it should.
#
# Usage: lint-directory-pathspec-boundary.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. A directory is scanned recursively for
#              .md and .sh files. Defaults to $PROJECT_ROOT/agent-system/extensions (the source
#              store -- .claude/ is a disposable generated deploy artifact and is never the
#              correct place to fix a finding).
#   --verbose  Report every candidate token found, including exempt and skipped ones, tagged
#              with the reason each was exempted/skipped.
#   --quiet    Suppress the progress header and the all-clear summary. Violations are still
#              printed, and the failing summary is still printed, so a failing run is never
#              silent.
#
# Exit codes:
#   0 - No unexcluded violations found
#   1 - One or more unexcluded violations found (each printed as file:line plus the token)
#   2 - Script error (unresolvable project root, missing shared library, unreadable scan path)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# Root resolution -- identical strategy to lint-scoped-commit-boundary.sh: this script runs both
# from the deployed copy (.claude/scripts/lint/) and the source store
# (agent-system/extensions/core/scripts/lint/), which sit at different depths below the repo
# root. Walk up until a directory containing agent-system/extensions is found, falling back to
# the common_repo_root answer.
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

# ---------------------------------------------------------------------------
# Layer 3: file-level allowlist
# ---------------------------------------------------------------------------
# Repo-relative paths. Every entry states WHY it is exempt. No entry may stand in for an unfixed
# real violation -- both entries here are self-reference only.
EXCLUDED_FILES=(
    # This lint's own header and comments discuss the violation shape in prose (e.g. this file's
    # own usage/example text); its fixture test below writes the shape as synthetic dirty
    # fixtures. Both are self-reference, not a deferred real violation.
    "agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh"
    "agent-system/extensions/core/scripts/tests/test-lint-directory-pathspec-boundary.sh"
)

is_excluded_file() {
    local file="$1"
    local rel="${file#"$PROJECT_ROOT"/}"
    local entry
    for entry in "${EXCLUDED_FILES[@]}"; do
        [[ "$rel" == "$entry" ]] && return 0
        [[ "$file" == */"$entry" ]] && return 0
    done
    return 1
}

# ---------------------------------------------------------------------------
# Layer 2: structural classification of a single pathspec token
# ---------------------------------------------------------------------------
# Echoes "VIOLATION", "EXEMPT: <reason>", or "SKIP: <reason>".
classify_token() {
    local token="$1"

    # A `:(exclude)...` magic pathspec is never a positive pathspec -- it narrows what the
    # positive tokens already selected, and carries no staging risk of its own.
    if [[ "$token" == :\(exclude\)* ]]; then
        printf 'SKIP: exclude-magic pathspec (not a positive pathspec)\n'
        return 0
    fi

    # Does not end in a directory separator -- an explicit file path.
    if [[ "$token" != */ ]]; then
        printf 'EXEMPT: explicit file path\n'
        return 0
    fi

    # Ends in `/`. Task-scoped if it carries a `${...}` interpolation, a `{N}`/`{NNN}`-style
    # placeholder, or a literal `{NNN}_{SLUG}`/`{N}_{SLUG}`-convention directory segment already
    # substituted with a concrete task number (e.g. `specs/427_some-slug/reports/` in a worked,
    # already-rendered example) -- all three are sanctioned by git-staging-scope.md's
    # per-operation scope, since each names one task's own directory and a cross-session bleed
    # is impossible by construction.
    if [[ "$token" == *'${'* ]] || [[ "$token" =~ \{[A-Za-z0-9_]+\} ]] || [[ "$token" =~ /[0-9]+_ ]]; then
        printf 'EXEMPT: task-scoped directory (sanctioned by git-staging-scope.md)\n'
        return 0
    fi

    printf 'VIOLATION\n'
    return 0
}

# ---------------------------------------------------------------------------
# Collect files to scan
# ---------------------------------------------------------------------------
FILES=()
for scan_path in "${SCAN_PATHS[@]}"; do
    if [[ -d "$scan_path" ]]; then
        while IFS= read -r found; do
            FILES+=("$found")
        done < <(find "$scan_path" -type f \( -name '*.md' -o -name '*.sh' \) 2>/dev/null | sort)
    elif [[ -f "$scan_path" ]]; then
        FILES+=("$scan_path")
    else
        echo "ERROR: scan path not found: $scan_path" >&2
        exit 2
    fi
done

# ---------------------------------------------------------------------------
# Main scan
# ---------------------------------------------------------------------------
VIOLATIONS=0
FILES_CHECKED=0
FILES_WITH_VIOLATIONS=0
EXEMPTED=0
SKIPPED=0

$QUIET || {
    echo "Checking directory-pathspec boundary compliance..."
    echo "Scan roots: ${SCAN_PATHS[*]}"
    echo ""
}

for file in "${FILES[@]}"; do
    ((FILES_CHECKED++)) || true

    file_excluded=false
    if is_excluded_file "$file"; then
        file_excluded=true
    fi

    mapfile -t lines < "$file"
    total=${#lines[@]}
    file_violations=0
    i=0

    while (( i < total )); do
        line="${lines[$i]}"
        lineno=$((i + 1))

        if [[ "$line" != *"git-commit-scoped.sh"* ]]; then
            ((i++)) || true
            continue
        fi

        # Layer 1: assemble the candidate window via backslash continuation.
        open_lineno=$lineno
        assembled=""
        j=$i
        while (( j < total )); do
            cur="${lines[$j]}"
            if [[ "$cur" =~ \\[[:space:]]*$ ]]; then
                stripped="${cur%\\*}"
                assembled+="$stripped "
                ((j++)) || true
            else
                assembled+="$cur"
                break
            fi
        done
        close_lineno=$((j + 1))

        if [[ "$assembled" =~ [[:space:]]--([[:space:]]+(.*))?$ ]]; then
            tail="${BASH_REMATCH[2]}"
            if [[ -n "$tail" ]]; then
                while IFS= read -r tok; do
                    [[ -z "$tok" ]] && continue
                    verdict="$(classify_token "$tok")"
                    case "$verdict" in
                        VIOLATION)
                            if $file_excluded; then
                                ((EXEMPTED++)) || true
                                $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$close_lineno: file-level allowlist entry | $tok"
                            else
                                echo -e "${RED}[VIOLATION]${NC} $file:$close_lineno: bare shared-directory pathspec '$tok' (git-commit-scoped.sh invocation opened at line $open_lineno)"
                                ((file_violations++)) || true
                                ((VIOLATIONS++)) || true
                            fi
                            ;;
                        SKIP*)
                            ((SKIPPED++)) || true
                            $VERBOSE && echo -e "${YELLOW}[SKIP]${NC} $file:$close_lineno: ${verdict#SKIP: } | $tok"
                            ;;
                        *)
                            ((EXEMPTED++)) || true
                            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$close_lineno: ${verdict#EXEMPT: } | $tok"
                            ;;
                    esac
                done < <(printf '%s\n' "$tail" | xargs -n1 2>/dev/null || true)
            fi
        fi

        i=$((j + 1))
    done

    if [[ $file_violations -gt 0 ]]; then
        ((FILES_WITH_VIOLATIONS++)) || true
    fi
done

if [[ $VIOLATIONS -eq 0 ]]; then
    $QUIET || {
        echo ""
        echo "================================"
        echo "Directory-Pathspec Boundary Check Summary"
        echo "================================"
        echo "Files checked: $FILES_CHECKED"
        echo "Candidate tokens exempted: $EXEMPTED"
        echo "Candidate tokens skipped (exclude-magic): $SKIPPED"
        echo "Total violations: 0"
        echo -e "${GREEN}No bare shared-directory pathspec passed to git-commit-scoped.sh.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "Directory-Pathspec Boundary Check Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Files with violations: $FILES_WITH_VIOLATIONS"
echo "Candidate tokens exempted: $EXEMPTED"
echo "Candidate tokens skipped (exclude-magic): $SKIPPED"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS bare shared-directory pathspec(s). See above for details.${NC}"
echo ""
echo "Fix: replace the bare directory token with the explicit file list the recipe actually"
echo "touches (see git-staging-scope.md). Edit the source store under agent-system/extensions/"
echo "-- .claude/ is a generated artifact."
exit 1
