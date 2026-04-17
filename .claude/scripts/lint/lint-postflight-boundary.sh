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
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# If no paths provided, scan all skill files
if [[ ${#SKILL_PATHS[@]} -eq 0 ]]; then
    mapfile -t SKILL_PATHS < <(find "$PROJECT_ROOT/.claude/skills" "$PROJECT_ROOT/.claude/extensions" -name "SKILL.md" -type f 2>/dev/null | sort)
fi

# Counters
VIOLATIONS=0
FILES_CHECKED=0
FILES_WITH_VIOLATIONS=0

# Check if a skill delegates to a subagent
does_skill_delegate() {
    local file="$1"
    grep -qE 'Task tool|subagent_type|subagent|Invoke Subagent' "$file" 2>/dev/null
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

    # Check for violations - capture return value
    set +e
    check_postflight_violations "$skill_file"
    file_violations=$?
    set -e

    if [[ $file_violations -gt 0 ]]; then
        ((FILES_WITH_VIOLATIONS++)) || true
        ((VIOLATIONS+=file_violations)) || true
    else
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
