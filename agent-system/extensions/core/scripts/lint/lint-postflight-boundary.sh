#!/usr/bin/env bash
# lint-postflight-boundary.sh - Detect postflight boundary violations in skills
#
# Checks for prohibited patterns in skill SKILL.md files after postflight stages:
# - Edit tool calls on source files (not specs/*)
# - Build/test commands (lake build, nvim --headless, pnpm build, etc.)
# - MCP tool references
# - Grep/analysis commands
#
# Usage: lint-postflight-boundary.sh [--verbose] [skill-path...]
#
# Exit codes:
#   0 - No violations found
#   1 - Violations found
#   2 - Script error

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
VERBOSE=false
SKILL_PATHS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        *)
            SKILL_PATHS+=("$1")
            shift
            ;;
    esac
done

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"
PROJECT_ROOT="$(common_repo_root "$SCRIPT_DIR" 3)"

# If no paths provided, scan all skill files
if [[ ${#SKILL_PATHS[@]} -eq 0 ]]; then
    mapfile -t SKILL_PATHS < <(find "$PROJECT_ROOT/.claude/skills" "$PROJECT_ROOT/.claude/extensions" -name "SKILL.md" -type f 2>/dev/null | sort)
fi

# Counters
VIOLATIONS=0
FILES_CHECKED=0
FILES_WITH_VIOLATIONS=0
MISSING_SECTION_COUNT=0

# Check if a skill delegates to a subagent
#
# TIGHTENED (see the shared-skill-stage-skeleton report's MUST-NOT-presence finding): the prior
# pattern (`Agent tool|subagent_type|subagent|Invoke Subagent`) matched bare substring mentions
# of "subagent" anywhere in the file -- including NEGATED prose like "executes inline without
# spawning a subagent" (skill-refresh, skill-status-sync) or "Direct execution without subagent
# overhead" (skill-status-sync). Those are direct-execution skills that explicitly do NOT
# delegate; the loose predicate falsely counted them as needing a postflight-boundary section.
# The four alternatives below are all POSITIVE delegation markers observed across every skill
# that already carries a legitimate MUST NOT (Postflight Boundary) section (29/32 via
# `subagent_type:`, the remaining 3 team skills via the "Agent tool for team coordination" /
# "Spawn teammates using Agent tool" phrasing) and were verified to produce zero false positives
# against the known direct-execution skills (skill-status-sync, skill-refresh, skill-tag,
# skill-git-workflow, skill-zulip, skill-todo).
does_skill_delegate() {
    local file="$1"
    grep -qE 'subagent_type[[:space:]]*:|Tool:[[:space:]]*Agent\b|Spawn teammates using Agent tool|Agent tool for team coordination' "$file" 2>/dev/null
}

# Check for the specific "## MUST NOT (Postflight Boundary)" heading -- NOT any "## MUST NOT"
# heading. A skill may carry an unrelated MUST NOT section (e.g. skill-orchestrate's
# "## MUST NOT (Context Flatness Constraint)") without carrying the postflight-boundary one;
# treating any-heading as sufficient would silently pass a skill that lacks the actual contract.
has_postflight_boundary_section() {
    local file="$1"
    grep -qE '^## MUST NOT \(Postflight Boundary\)' "$file" 2>/dev/null
}

# Check for prohibited patterns in postflight section
check_postflight_violations() {
    local file="$1"
    local violations_in_file=0

    # Extract postflight section (Stage 6+ that includes status update or parsing return)
    # Note: Stage 5 is typically "Invoke Subagent", Stage 6+ is postflight
    # Exclude "Create Postflight Marker" which is preflight
    local postflight_section
    postflight_section=$(awk '
        /^### Stage [6-9]|^### Stage 1[0-9]/ { in_postflight=1 }
        /Stage [5-9]: .*(Parse.*Return|Update.*Status \(Postflight\)|Postflight Status)/ { in_postflight=1 }
        # skill-orchestrate SKILL.md four-move loop (see
        # docs/architecture/orchestrate-state-machine.md) abandoned "### Stage N" numbering
        # entirely; its own postflight body lives under "### Move 3: Postflight". Recognized here
        # by heading text containing "Postflight" rather than a numbered Stage/Move token, so a
        # future rename of the numbering scheme does not silently reopen this same fail-open gap.
        /^#{2,4} .*Postflight/ { in_postflight=1 }
        # Stop at Return Format or Error Handling sections
        /^## Return Format|^## Error Handling|^## MUST NOT/ && in_postflight { in_postflight=0 }
        in_postflight { print }
    ' "$file" 2>/dev/null || true)

    if [[ -z "$postflight_section" ]]; then
        $VERBOSE && echo "  [SKIP] No postflight section found"
        return 0
    fi

    # Skip checking the MUST NOT section itself and documentation notes
    local postflight_without_exclusions
    postflight_without_exclusions=$(echo "$postflight_section" | awk '
        # Exclude MUST NOT section
        /^## MUST NOT/ { in_mustnot=1 }
        /^---$/ && in_mustnot { in_mustnot=0; next }
        /^## / && in_mustnot { in_mustnot=0 }
        # Exclude documentation notes that explain agent responsibilities
        /^\*\*Note\*\*:/ { next }
        /agent performs|agent is responsible|done by agent/ { next }
        !in_mustnot { print }
    ')

    # Check for build commands in postflight (outside exclusions)
    # These patterns indicate actual build/verification execution
    # Excludes: jq, git, rm, mkdir, mv, cat which are allowed state management tools
    local build_patterns="lake build|nvim --headless|pnpm build|pnpm check|npm run build|cargo build|cargo test|pytest[^a-z]|nix build|nix flake check|typst compile|pdflatex|latexmk"

    # Look for actual build commands, not just bash blocks or documentation
    if echo "$postflight_without_exclusions" | grep -vE '^\`\`\`|^\s*#' | grep -qE "$build_patterns"; then
        echo -e "${RED}[VIOLATION]${NC} $file: Build command in postflight section"
        ((violations_in_file++))
    fi

    # Check for grep on source files
    if echo "$postflight_without_exclusions" | grep -qE 'grep.*Theories/|grep -r.*\\.(lua|lean|py)\b'; then
        echo -e "${RED}[VIOLATION]${NC} $file: Grep on source files in postflight"
        ((violations_in_file++))
    fi

    # Check for MCP tool usage
    if echo "$postflight_without_exclusions" | grep -qE 'mcp__[a-z_]+__[a-z_]+'; then
        echo -e "${RED}[VIOLATION]${NC} $file: MCP tool reference in postflight"
        ((violations_in_file++))
    fi

    return $violations_in_file
}

# Main loop
echo "Checking postflight boundary compliance..."
echo ""

for skill_file in "${SKILL_PATHS[@]}"; do
    [[ ! -f "$skill_file" ]] && continue
    ((FILES_CHECKED++)) || true

    # Skip non-delegating skills
    if ! does_skill_delegate "$skill_file"; then
        $VERBOSE && echo -e "${GREEN}[SKIP]${NC} $skill_file (non-delegating)"
        continue
    fi

    $VERBOSE && echo "Checking: $skill_file"

    # Section-presence check: a delegating skill without the specific
    # "## MUST NOT (Postflight Boundary)" heading is a named violation. This turns the prior
    # silent pass (a skill could lack the section entirely and the pattern checks below would
    # simply find nothing to complain about) into a loud, named failure.
    if ! has_postflight_boundary_section "$skill_file"; then
        echo -e "${RED}[VIOLATION]${NC} $skill_file: missing '## MUST NOT (Postflight Boundary)' section"
        ((MISSING_SECTION_COUNT++)) || true
        ((VIOLATIONS++)) || true
        ((FILES_WITH_VIOLATIONS++)) || true
    fi

    # Check for violations - capture return value
    set +e
    check_postflight_violations "$skill_file"
    file_violations=$?
    set -e

    if [[ $file_violations -gt 0 ]]; then
        ((FILES_WITH_VIOLATIONS++)) || true
        ((VIOLATIONS+=file_violations)) || true
    elif has_postflight_boundary_section "$skill_file"; then
        $VERBOSE && echo -e "${GREEN}[PASS]${NC} $skill_file"
    fi
done

# Summary
echo ""
echo "================================"
echo "Postflight Boundary Check Summary"
echo "================================"
echo "Files checked: $FILES_CHECKED"
echo "Files with violations: $FILES_WITH_VIOLATIONS"
echo "Missing '## MUST NOT (Postflight Boundary)' section: $MISSING_SECTION_COUNT"
echo "Total violations: $VIOLATIONS"

if [[ $VIOLATIONS -eq 0 ]]; then
    echo -e "${GREEN}All skills comply with postflight boundary restrictions.${NC}"
    exit 0
else
    echo -e "${RED}Found $VIOLATIONS violation(s). See above for details.${NC}"
    echo ""
    echo "Reference: .claude/context/standards/postflight-tool-restrictions.md"
    exit 1
fi
