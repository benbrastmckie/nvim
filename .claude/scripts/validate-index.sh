#!/usr/bin/env bash
# validate-index.sh - Validate context index entries
#
# Checks:
# 1. Orphaned entries (empty load_when without always:true)
# 2. Missing files (path doesn't exist)
# 3. Duplicate paths
# 4. Budget estimates per agent/task_type
#
# Usage: ./validate-index.sh [index-file]
#        Default: .claude/context/index.json

set -euo pipefail

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Determine index file
INDEX_FILE="${1:-.claude/context/index.json}"
CONTEXT_DIR=".claude/context"

# Track warnings and errors
WARNINGS=0
ERRORS=0

echo "Validating context index: $INDEX_FILE"
echo "========================================"

# Check if file exists
if [[ ! -f "$INDEX_FILE" ]]; then
    echo -e "${RED}ERROR: Index file not found: $INDEX_FILE${NC}"
    exit 1
fi

# 1. Check for orphaned entries (empty load_when without always:true)
echo ""
echo "Checking for orphaned entries..."
ORPHANED=$(jq -r '.entries[] | select(
    (.load_when.agents | length) == 0 and
    (.load_when.task_types | length) == 0 and
    (.load_when.commands | length) == 0 and
    (.load_when.always == true | not)
) | .path' "$INDEX_FILE" 2>/dev/null || echo "")

if [[ -n "$ORPHANED" ]]; then
    echo -e "${YELLOW}WARNING: Found orphaned entries with empty load_when:${NC}"
    echo "$ORPHANED" | while read -r path; do
        echo "  - $path"
        ((WARNINGS++)) || true
    done
else
    echo -e "${GREEN}OK: No orphaned entries found${NC}"
fi

# 2. Check for missing files
echo ""
echo "Checking for missing files..."
MISSING=0
while IFS= read -r path; do
    full_path="$CONTEXT_DIR/$path"
    if [[ ! -f "$full_path" ]]; then
        if [[ $MISSING -eq 0 ]]; then
            echo -e "${YELLOW}WARNING: Found entries with missing files:${NC}"
        fi
        echo "  - $path (expected at $full_path)"
        ((MISSING++)) || true
        ((WARNINGS++)) || true
    fi
done < <(jq -r '.entries[].path' "$INDEX_FILE" 2>/dev/null)

if [[ $MISSING -eq 0 ]]; then
    echo -e "${GREEN}OK: All paths exist${NC}"
fi

# 3. Check for duplicate paths
echo ""
echo "Checking for duplicate paths..."
DUPLICATES=$(jq -r '.entries[].path' "$INDEX_FILE" | sort | uniq -d)

if [[ -n "$DUPLICATES" ]]; then
    echo -e "${YELLOW}WARNING: Found duplicate paths:${NC}"
    echo "$DUPLICATES" | while read -r path; do
        echo "  - $path"
        ((WARNINGS++)) || true
    done
else
    echo -e "${GREEN}OK: No duplicate paths${NC}"
fi

# 4. Budget estimates per agent
echo ""
echo "Budget estimates by agent:"
echo "---------------------------"
for agent in "general-research-agent" "planner-agent" "general-implementation-agent" "meta-builder-agent" "code-reviewer-agent" "spawn-agent"; do
    # Use "| not" pattern to avoid jq escaping issues
    lines=$(jq --arg agent "$agent" '[.entries[] | select(.load_when.agents[]? == $agent) | .line_count] | add // 0' "$INDEX_FILE")
    count=$(jq --arg agent "$agent" '[.entries[] | select(.load_when.agents[]? == $agent)] | length' "$INDEX_FILE")
    printf "  %-30s %5d entries, %6d lines\n" "$agent:" "$count" "$lines"
done

# 5. Budget estimates per task_type
echo ""
echo "Budget estimates by task_type:"
echo "------------------------------"
for tt in "meta" "markdown" "general"; do
    lines=$(jq --arg tt "$tt" '[.entries[] | select(.load_when.task_types[]? == $tt) | .line_count] | add // 0' "$INDEX_FILE")
    count=$(jq --arg tt "$tt" '[.entries[] | select(.load_when.task_types[]? == $tt)] | length' "$INDEX_FILE")
    printf "  %-30s %5d entries, %6d lines\n" "$tt:" "$count" "$lines"
done

# 6. Universal (always:true) budget
echo ""
echo "Universal entries (always:true):"
echo "---------------------------------"
lines=$(jq '[.entries[] | select(.load_when.always == true) | .line_count] | add // 0' "$INDEX_FILE")
count=$(jq '[.entries[] | select(.load_when.always == true)] | length' "$INDEX_FILE")
printf "  %-30s %5d entries, %6d lines\n" "always:true:" "$count" "$lines"

# Summary
echo ""
echo "========================================"
TOTAL=$(jq '.entries | length' "$INDEX_FILE")
TOTAL_LINES=$(jq '[.entries[].line_count] | add // 0' "$INDEX_FILE")
echo "Total: $TOTAL entries, $TOTAL_LINES lines"

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Validation FAILED with $ERRORS errors and $WARNINGS warnings${NC}"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}Validation passed with $WARNINGS warnings${NC}"
    exit 0
else
    echo -e "${GREEN}Validation PASSED${NC}"
    exit 0
fi
