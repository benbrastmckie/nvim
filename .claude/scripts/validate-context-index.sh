#!/usr/bin/env bash
#
# validate-context-index.sh - Validate .claude/context/index.json
#
# Usage: ./validate-context-index.sh [--fix]
#
# Checks:
# - JSON syntax validation
# - All paths in entries exist
# - Required fields are present
# - Line counts are approximately accurate
#
# Options:
#   --fix    Attempt to fix line count mismatches

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
INDEX_FILE="$PROJECT_ROOT/.claude/context/index.json"
CONTEXT_DIR="$PROJECT_ROOT/.claude/context"

FIX_MODE=false
if [[ "${1:-}" == "--fix" ]]; then
    FIX_MODE=true
fi

ERRORS=0
WARNINGS=0

log_error() {
    echo "[ERROR] $1" >&2
    ERRORS=$((ERRORS + 1))
}

log_warning() {
    echo "[WARN] $1" >&2
    WARNINGS=$((WARNINGS + 1))
}

log_info() {
    echo "[INFO] $1"
}

# Check if index.json exists
if [[ ! -f "$INDEX_FILE" ]]; then
    log_error "index.json not found at $INDEX_FILE"
    exit 1
fi

# Validate JSON syntax
log_info "Validating JSON syntax..."
if ! jq '.' "$INDEX_FILE" > /dev/null 2>&1; then
    log_error "index.json has invalid JSON syntax"
    exit 1
fi
log_info "JSON syntax is valid"

# Check required top-level fields
log_info "Checking required fields..."
for field in entries; do
    if ! jq -e ".$field" "$INDEX_FILE" > /dev/null 2>&1; then
        log_error "Missing required field: $field"
    fi
done
# Note: version and generated fields are optional (index may be extension-merged)

# Validate all paths exist
log_info "Validating file paths..."
jq -r '.entries[].path' "$INDEX_FILE" | while read -r path; do
    full_path="$CONTEXT_DIR/$path"
    if [[ ! -f "$full_path" ]]; then
        log_error "Path does not exist: $path"
    fi
done

# Check required entry fields
log_info "Checking entry fields..."
entry_count=$(jq '.entries | length' "$INDEX_FILE")
for ((i=0; i<entry_count; i++)); do
    path=$(jq -r ".entries[$i].path" "$INDEX_FILE")

    for field in path domain summary line_count; do
        if ! jq -e ".entries[$i].$field" "$INDEX_FILE" > /dev/null 2>&1; then
            log_error "Entry '$path' missing required field: $field"
        fi
    done
done

# Validate line counts (with 10% tolerance)
log_info "Validating line counts..."
jq -r '.entries[] | "\(.path)\t\(.line_count)"' "$INDEX_FILE" | while IFS=$'\t' read -r path expected; do
    full_path="$CONTEXT_DIR/$path"
    if [[ -f "$full_path" ]]; then
        actual=$(wc -l < "$full_path")
        diff=$((actual - expected))
        if [[ $diff -lt 0 ]]; then
            diff=$((-diff))
        fi
        tolerance=$((expected / 10))
        if [[ $tolerance -lt 10 ]]; then
            tolerance=10
        fi
        if [[ $diff -gt $tolerance ]]; then
            log_warning "Line count mismatch for $path: expected $expected, actual $actual"
            if $FIX_MODE; then
                # Note: Fixing would require modifying index.json
                log_info "  Would fix to: $actual"
            fi
        fi
    fi
done

# Validate domain values
log_info "Validating domain values..."
jq -r '.entries[] | "\(.path)\t\(.domain)"' "$INDEX_FILE" | while IFS=$'\t' read -r path domain; do
    case "$domain" in
        core|project|system) ;;
        *)
            log_error "Invalid domain '$domain' for entry: $path"
            ;;
    esac
done

# Check for deprecated entries without replacement
log_info "Checking deprecated entries..."
jq -r '.entries[] | select(.deprecated == true) | "\(.path)\t\(.replacement // "NONE")"' "$INDEX_FILE" | while IFS=$'\t' read -r path replacement; do
    if [[ "$replacement" == "NONE" ]]; then
        log_warning "Deprecated entry '$path' has no replacement specified"
    elif [[ ! -f "$CONTEXT_DIR/$replacement" ]]; then
        log_error "Deprecated entry '$path' has non-existent replacement: $replacement"
    fi
done

# Summary
echo ""
echo "=== Validation Summary ==="
echo "Entries checked: $entry_count"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"

if [[ $ERRORS -gt 0 ]]; then
    echo ""
    echo "Validation FAILED with $ERRORS error(s)"
    exit 1
else
    echo ""
    echo "Validation PASSED"
    exit 0
fi
