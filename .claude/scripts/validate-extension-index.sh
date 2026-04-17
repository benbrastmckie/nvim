#!/usr/bin/env bash
# validate-extension-index.sh - Validate extension index-entries.json files
#
# Checks:
# 1. JSON structure (must have {entries: [...]} format)
# 2. Path prefixes (must be project/ or core/, not .claude/, .opencode/, or context/)
# 3. Cross-system references (FAIL if .claude files reference .opencode or vice versa)
# 4. Path resolution (entries should resolve to real files)
#
# Usage: ./validate-extension-index.sh [--check-resolution]
#
# Options:
#   --check-resolution  Also verify that each path resolves to an actual file
#                       relative to the context/ directory (slower)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${SCRIPT_DIR}/../.."

CHECK_RESOLUTION=false
if [[ "${1:-}" == "--check-resolution" ]]; then
    CHECK_RESOLUTION=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error_count=0
warning_count=0

log_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    ((error_count++)) || true
}

log_warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
    ((warning_count++)) || true
}

log_ok() {
    echo -e "${GREEN}OK: $1${NC}"
}

# Check a single index-entries.json file
check_index_file() {
    local file="$1"
    local system_type="$2"  # "claude" or "opencode"
    local other_system=""

    if [[ "$system_type" == "claude" ]]; then
        other_system="opencode"
    else
        other_system="claude"
    fi

    # Check if file exists
    if [[ ! -f "$file" ]]; then
        log_error "$file: File not found"
        return 1
    fi

    # Check JSON validity
    if ! jq -e . "$file" > /dev/null 2>&1; then
        log_error "$file: Invalid JSON"
        return 1
    fi

    # Check for {entries: [...]} structure
    if ! jq -e '.entries' "$file" > /dev/null 2>&1; then
        # Check if it's a bare array
        if jq -e 'type == "array"' "$file" > /dev/null 2>&1; then
            log_error "$file: Uses bare array format instead of {entries: [...]}"
        else
            log_error "$file: Missing 'entries' field"
        fi
        return 1
    fi

    # Check path prefixes
    local bad_paths
    bad_paths=$(jq -r '.entries[].path | select(startswith(".claude/") or startswith(".opencode/") or startswith("context/"))' "$file" 2>/dev/null || true)

    if [[ -n "$bad_paths" ]]; then
        log_error "$file: Found paths with bad prefixes:"
        echo "$bad_paths" | head -5 | while read -r path; do
            echo "  - $path"
        done
        local count
        count=$(echo "$bad_paths" | wc -l)
        if [[ "$count" -gt 5 ]]; then
            echo "  ... and $((count - 5)) more"
        fi
        return 1
    fi

    # Check for cross-system references
    local cross_refs
    cross_refs=$(jq -r '.entries[].path | select(contains(".'$other_system'/") or contains("'$other_system'/"))' "$file" 2>/dev/null || true)

    if [[ -n "$cross_refs" ]]; then
        log_error "$file: Contains cross-system references to .$other_system:"
        echo "$cross_refs" | head -5 | while read -r path; do
            echo "  - $path"
        done
        return 1
    fi

    # Optional: Check path resolution
    if [[ "$CHECK_RESOLUTION" == "true" ]]; then
        local context_dir="${PROJECT_DIR}/.$system_type/context"
        local missing_paths=""

        while IFS= read -r path; do
            local full_path="$context_dir/$path"
            if [[ ! -f "$full_path" ]]; then
                missing_paths+="  - $path\n"
            fi
        done < <(jq -r '.entries[].path' "$file" 2>/dev/null)

        if [[ -n "$missing_paths" ]]; then
            log_warning "$file: Some paths do not resolve to files:"
            echo -e "$missing_paths" | head -10
        fi
    fi

    # Count entries
    local entry_count
    entry_count=$(jq '.entries | length' "$file")
    log_ok "$file: $entry_count entries, all paths valid"
    return 0
}

echo "Validating extension index-entries.json files..."
echo ""

# Check .claude extensions
echo "=== .claude extensions ==="
for file in "$PROJECT_DIR"/.claude/extensions/*/index-entries.json; do
    if [[ -f "$file" ]]; then
        check_index_file "$file" "claude" || true
    fi
done

echo ""

# Check .opencode extensions
echo "=== .opencode extensions ==="
for file in "$PROJECT_DIR"/.opencode/extensions/*/index-entries.json; do
    if [[ -f "$file" ]]; then
        check_index_file "$file" "opencode" || true
    fi
done

echo ""
echo "=== Summary ==="
echo "Errors: $error_count"
echo "Warnings: $warning_count"

if [[ "$error_count" -gt 0 ]]; then
    echo -e "${RED}FAILED${NC}"
    exit 1
else
    echo -e "${GREEN}PASSED${NC}"
    exit 0
fi
