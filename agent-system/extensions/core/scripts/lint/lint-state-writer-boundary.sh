#!/usr/bin/env bash
# lint-state-writer-boundary.sh - Detect hand-rolled state.json writes across the source store.
#
# scripts/state-write.sh is the single mutex-guarded writer for specs/state.json and its
# archive/vault counterparts. Every read-modify-write of a state file is meant to go through it
# rather than hand-rolling the historical `jq '<filter>' specs/state.json > <staging-path> && mv
# <staging-path> specs/state.json` sequence. That hand-rolled sequence is unsafe on two
# independent axes -- it acquires no specs/.scope-lock mutex, so concurrent writers interleave and
# lose updates; and it stages through a fixed, shared temp path, so one process's cleanup can
# delete another's in-flight staging file. See state-write.sh's own header for the full account of
# both corruption channels.
#
# Converting the surviving hand-rolled writers is a one-time migration. Keeping them converted is
# not: every new command file or skill that needs to touch state is a fresh opportunity to
# copy-paste the old sequence from a neighbouring file. This lint is the guardrail against that
# regression -- it fails loudly when the literal anti-pattern text reappears anywhere under
# agent-system/extensions/.
#
# KNOWN LIMITATION (stated plainly rather than papered over)
# ---------------------------------------------------------
# This is a regex-only, line-oriented content lint. It matches the *literal shape* of the
# anti-pattern in the text of .md and .sh files. It therefore CANNOT catch:
#   - A variable-indirected write, e.g. a site that stages through `$STAGING` or `$STATE_FILE`
#     where the path is only resolved at runtime; nothing in the source text names `state.json`
#     or a `.tmp` staging path, so no regex can see it.
#   - A write assembled across more than the one-or-two adjacent lines the heuristics below read
#     (a filter built into a variable on line 10 and redirected on line 40).
#   - A write performed by a helper the lint has no reason to suspect, or by any non-.md/.sh
#     artifact.
# This lint is a guardrail against regression and recurrence of the literal anti-pattern text. It
# is NOT a proof of absence of every possible hand-rolled state write. Treat a clean run as "the
# known bad shape is not present", never as "all state writes go through state-write.sh".
#
# DETECTION MODEL
# ---------------
# Two layers, applied in order to every line matching the broad candidate pattern:
#
#   Layer 1 (structural, line shape): classifies each candidate line by the shape of the write.
#     A redirect whose target is /dev/null is a read-only existence check, not a write. A bare
#     `mv` onto a state.json target is a violation only when its SOURCE looks like a staging path
#     (contains a tmp component or a .tmp suffix) -- a `mv .../archive/state.json .../state.json`
#     file relocation is not a staged read-modify-write and is exempt by shape.
#
#   Layer 2 (file-level allowlist): a short, explicitly-reasoned list of files that legitimately
#     contain the pattern text. Every entry carries its reason inline below; there are no bare
#     paths on that list by design.
#
# Usage: lint-state-writer-boundary.sh [--verbose] [--quiet] [path...]
#
#   path...    Optional. Files or directories to scan. A directory is scanned recursively for
#              .md and .sh files. Defaults to $PROJECT_ROOT/agent-system/extensions (the source
#              store -- .claude/ is a disposable generated deploy artifact and is never the
#              correct place to fix a finding).
#   --verbose  Report every candidate line found, including exempt ones, tagged with the reason
#              each was exempted. Mirrors lint-postflight-boundary.sh's --verbose semantics.
#   --quiet    Suppress the progress header and the all-clear summary. Violations are still
#              printed, and the failing summary is still printed, so a failing run is never
#              silent.
#
# Exit codes:
#   0 - No unexcluded hits found
#   1 - One or more unexcluded hits found (each printed as file:line plus the matched text)
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

    # No source store located (e.g. a deploy-only checkout). The common_repo_root answer is still
    # the best available root for relative-path reporting; explicit scan paths remain usable.
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
# Candidate pattern
# ---------------------------------------------------------------------------
# Deliberately broad -- it over-matches, and the classifier below narrows. It covers every
# staging variant observed in the source store (specs/tmp/state.json, specs/state.json.tmp,
# /tmp/state.tmp, and a bare tmp.json), plus every bare `mv` onto a state.json target so the
# second line of a multi-line stage-then-move sequence is seen even when the redirect lives on
# the preceding line.
CANDIDATE_PATTERN='mv .*state\.json|state\.json[[:space:]]*>|>[[:space:]]*[^[:space:]]*state\.tmp|>[[:space:]]*[^[:space:]]*state\.json\.tmp'

# ---------------------------------------------------------------------------
# Layer 2: file-level allowlist
# ---------------------------------------------------------------------------
# Repo-relative paths. Every entry states WHY it is exempt -- a bare path list would rot into an
# unauditable suppression file. Entries marked "also structurally exempt" are additionally caught
# by Layer 1; they stay listed so that a future tightening of the structural rules cannot silently
# turn them into false positives.
EXCLUDED_FILES=(
    # The sanctioned writer itself. Its header comment quotes the anti-pattern in prose while
    # explaining what it replaces; the quotation is the whole point of the paragraph.
    "agent-system/extensions/core/scripts/state-write.sh"

    # This lint and its fixture test both contain the anti-pattern text by necessity -- one as the
    # detection pattern, the other as deliberate dirty fixtures. Without these two entries the
    # lint fails on itself.
    "agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh"
    "agent-system/extensions/core/scripts/tests/test-lint-state-writer-boundary.sh"

    # Vault restore: a bare `mv "${vault_path}/archive/state.json" "${vault_path}/state.json"`
    # file relocation, moving a whole state file into place. It is not a jq-staged
    # read-modify-write, so state-write.sh (which transforms content) is not the right tool.
    # Also structurally exempt -- the mv source is an archive path, not a staging path.
    "agent-system/extensions/core/commands/todo.md"
    "agent-system/extensions/core/skills/skill-todo/SKILL.md"
    "agent-system/extensions/core/scripts/deprecated/vault-operation.sh"

    # `jq -e ... specs/state.json > /dev/null` read-only existence checks. These read state and
    # discard the output; nothing is written. Also structurally exempt via the /dev/null rule.
    "agent-system/extensions/core/commands/task.md"
    "agent-system/extensions/core/context/orchestration/validation.md"

    # Deliberate corrupt-state test fixture: the test writes a knowingly-invalid status value
    # straight onto a fixture state file to assert the validator rejects it. Routing it through
    # state-write.sh would apply the very validation the test needs to bypass, defeating the test.
    "agent-system/extensions/core/scripts/tests/test-update-task-status.sh"

    # Illustrative prose about jq escaping. Its worked example writes specs/tmp/test-state.json --
    # a throwaway example file, not a live state writer.
    "agent-system/extensions/core/context/patterns/jq-escaping-workarounds.md"

    # Isolated-temp-root test fixtures (honest-session-liveness task): both suites mutate a
    # throwaway $TMPROOT/specs/state.json -- never the real specs/state.json -- to simulate a
    # covered task's file_scope widening after session registration / after a lock is acquired.
    # The jq-staged-then-mv shape is the fixture's deliberate scratch-file mutation, not a
    # production state writer; routing it through state-write.sh would require a real task
    # directory and lock machinery the fixture is specifically isolated from.
    "agent-system/extensions/core/scripts/test-session-registry.sh"
    "agent-system/extensions/core/scripts/tests/test-task-lock-liveness.sh"
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
# Layer 1: structural classification of a single candidate line
# ---------------------------------------------------------------------------
# Echoes "VIOLATION" or "EXEMPT: <reason>".
classify_line() {
    local text="$1"

    # Read-only existence check -- the redirect target is /dev/null, so nothing is written.
    if [[ "$text" =~ \>[[:space:]]*/dev/null ]]; then
        printf 'EXEMPT: read-only check (redirect target is /dev/null)\n'
        return 0
    fi

    # Staged write: state.json is read and redirected somewhere, or something is redirected into
    # a recognised staging path.
    if [[ "$text" =~ state\.json[[:space:]]*\> ]] \
        || [[ "$text" =~ \>[[:space:]]*[^[:space:]]*state\.tmp ]] \
        || [[ "$text" =~ \>[[:space:]]*[^[:space:]]*state\.json\.tmp ]] \
        || [[ "$text" =~ \>[[:space:]]*[^[:space:]]*tmp/state\.json ]]; then
        printf 'VIOLATION\n'
        return 0
    fi

    # Bare `mv` onto a state.json target. Violation only when the SOURCE looks like a staging
    # path -- that is the tell for the second line of a stage-then-move sequence. A relocation
    # whose source is a real state file (archive restore) is exempt by shape.
    if [[ "$text" =~ mv[[:space:]]+(-[^[:space:]]+[[:space:]]+)*\"?([^[:space:]\"]+)\"? ]]; then
        local src="${BASH_REMATCH[2]}"
        if [[ "$text" =~ mv[[:space:]].*state\.json ]]; then
            if [[ "$src" =~ (^|/)tmp/ || "$src" =~ \.tmp$ || "$src" =~ \.tmp[^a-zA-Z0-9] || "$src" =~ tmp\.json ]]; then
                printf 'VIOLATION\n'
                return 0
            fi
            printf 'EXEMPT: bare `mv` file relocation (source %s is not a staging path)\n' "$src"
            return 0
        fi
    fi

    printf 'EXEMPT: no staged read-modify-write shape\n'
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

$QUIET || {
    echo "Checking state-writer boundary compliance..."
    echo "Scan roots: ${SCAN_PATHS[*]}"
    echo ""
}

for file in "${FILES[@]}"; do
    ((FILES_CHECKED++)) || true

    file_excluded=false
    if is_excluded_file "$file"; then
        file_excluded=true
    fi

    matches=""
    matches="$(grep -nE "$CANDIDATE_PATTERN" "$file" 2>/dev/null || true)"
    [[ -z "$matches" ]] && continue

    file_violations=0
    while IFS= read -r match; do
        [[ -z "$match" ]] && continue
        lineno="${match%%:*}"
        text="${match#*:}"
        # Trim leading whitespace for readable reporting.
        text="${text#"${text%%[![:space:]]*}"}"

        if $file_excluded; then
            ((EXEMPTED++)) || true
            $VERBOSE && echo -e "${YELLOW}[EXEMPT]${NC} $file:$lineno: file-level allowlist entry | $text"
            continue
        fi

        verdict="$(classify_line "$text")"
        if [[ "$verdict" == "VIOLATION" ]]; then
            echo -e "${RED}[VIOLATION]${NC} $file:$lineno: $text"
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
        echo "State Writer Boundary Check Summary"
        echo "================================"
        echo "Files checked: $FILES_CHECKED"
        echo "Candidate lines exempted: $EXEMPTED"
        echo "Total violations: 0"
        echo -e "${GREEN}No hand-rolled state.json writes found.${NC}"
    }
    exit 0
fi

echo ""
echo "================================"
echo "State Writer Boundary Check Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Files with violations: $FILES_WITH_VIOLATIONS"
echo "Candidate lines exempted: $EXEMPTED"
echo "Total violations: $VIOLATIONS"
echo -e "${RED}Found $VIOLATIONS hand-rolled state.json write(s). See above for details.${NC}"
echo ""
echo "Fix: route the write through scripts/state-write.sh (see its header for the contract)."
echo "Edit the source store under agent-system/extensions/ -- .claude/ is a generated artifact."
exit 1
