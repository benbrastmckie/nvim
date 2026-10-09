#!/usr/bin/env bash
#
# validate-context-index.sh - Validate .claude/context/index.json
#
# Usage: ./validate-context-index.sh [--fix] [--strict]
#
# Schema: .claude/context/index.schema.json defines the JSON Schema for index.json.
#         This script performs structural validation independently of ajv.
#
# Checks:
# - JSON syntax validation
# - All paths in entries exist
# - Required fields are present
# - Line counts are approximately accurate
# - Domain values are one of core|project|system
# - Deprecated entries declare a resolvable replacement
#
# All six check blocks above feed a single ERRORS/WARNINGS counter pair in the parent
# shell. Five blocks read entries via `< <(jq ...)` process substitution specifically so the
# `while read` loop body runs in the CURRENT shell rather than a subshell -- piping `jq | while
# read` would put the loop in a subshell and silently discard every counter increment inside it
# (this was a real, previously-shipped defect: the summary reported "Warnings: 0" while the loop
# body printed dozens of real [WARN] lines). The sixth block ("Checking entry fields") is a
# C-style `for` loop, not a pipe, and was never affected.
#
# Options:
#   --fix      Attempt to fix line count mismatches. Presently a no-op stub: it only prints
#              what it would change (see the line-count block below) and never writes
#              index.json. Real regeneration targets the SOURCE STORE
#              (agent-system/extensions/*/index-entries.json), not this deployed-index
#              validator -- see generate-context-line-counts.sh.
#   --strict   Exit nonzero when WARNINGS > 0, in addition to the existing ERRORS > 0 case.
#              Opt-in only; the default exit code is still driven by ERRORS alone so existing
#              callers see no behavior change.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Same REPO_ROOT-bypass pattern as check-extension-docs.sh: the deploy-root-guard only fires
# when REPO_ROOT is unset, so a deliberate source-store verification invocation
# (REPO_ROOT=$(pwd) bash agent-system/extensions/core/scripts/validate-context-index.sh) can
# validate the deployed .claude/context/index.json without tripping the guard.
[[ -n "${REPO_ROOT:-}" ]] || . "${SCRIPT_DIR}/deploy-root-guard.sh" || exit 1
PROJECT_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
INDEX_FILE="$PROJECT_ROOT/.claude/context/index.json"
CONTEXT_DIR="$PROJECT_ROOT/.claude/context"

FIX_MODE=false
STRICT_MODE=false
for arg in "$@"; do
    case "$arg" in
        --fix) FIX_MODE=true ;;
        --strict) STRICT_MODE=true ;;
    esac
done

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
# Note: version and generated are optional per the schema, but the loader (merge.lua's
# M.append_index_entries) DOES write both on every merge as of the upsert-semantics change --
# version is set once ("1.0.0") and left untouched thereafter; generated is refreshed on every
# write. Only entries is schema-required, so this loop intentionally does not enforce the other
# two.
log_info "Checking required fields..."
# shellcheck disable=SC2043  # Single-element today (only `entries` is schema-required per the
# comment above), but the loop shape is deliberate symmetry for a schema that may require more
# top-level fields later.
for field in entries; do
    if ! jq -e ".$field" "$INDEX_FILE" > /dev/null 2>&1; then
        log_error "Missing required field: $field"
    fi
done

# Validate all paths exist
log_info "Validating file paths..."
while read -r path; do
    full_path="$CONTEXT_DIR/$path"
    if [[ ! -f "$full_path" ]]; then
        log_error "Path does not exist: $path"
    fi
done < <(jq -r '.entries[].path' "$INDEX_FILE")

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
while IFS=$'\t' read -r path expected; do
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
                # Fixing would require modifying index.json, which is a generated deploy
                # artifact -- this stub deliberately never writes it. Real regeneration
                # targets the source store; see generate-context-line-counts.sh --write.
                log_info "  Would fix to: $actual"
            fi
        fi
    fi
done < <(jq -r '.entries[] | "\(.path)\t\(.line_count)"' "$INDEX_FILE")

# Validate domain values
log_info "Validating domain values..."
while IFS=$'\t' read -r path domain; do
    case "$domain" in
        core|project|system) ;;
        *)
            log_error "Invalid domain '$domain' for entry: $path"
            ;;
    esac
done < <(jq -r '.entries[] | "\(.path)\t\(.domain)"' "$INDEX_FILE")

# Check for deprecated entries without replacement
log_info "Checking deprecated entries..."
while IFS=$'\t' read -r path replacement; do
    if [[ "$replacement" == "NONE" ]]; then
        log_warning "Deprecated entry '$path' has no replacement specified"
    elif [[ ! -f "$CONTEXT_DIR/$replacement" ]]; then
        log_error "Deprecated entry '$path' has non-existent replacement: $replacement"
    fi
done < <(jq -r '.entries[] | select(.deprecated == true) | "\(.path)\t\(.replacement // "NONE")"' "$INDEX_FILE")

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
elif [[ $WARNINGS -gt 0 ]]; then
    echo ""
    echo "Validation PASSED with $WARNINGS warning(s)"
    if $STRICT_MODE; then
        echo "Validation FAILED in --strict mode: warnings are treated as failures"
        exit 1
    fi
    exit 0
else
    echo ""
    echo "Validation PASSED"
    exit 0
fi
