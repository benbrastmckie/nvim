#!/usr/bin/env bash
#
# claude-cleanup.sh - Comprehensive cleanup of ~/.claude/ directory
#
# Usage: ./claude-cleanup.sh [OPTIONS]
#
# Options:
#   --age HOURS    Only delete files older than HOURS (default: 8, 0 for clean slate)
#   --dry-run      Show what would be cleaned without changes
#   --force        Skip confirmation prompt and clean immediately
#   --help, -h     Show this help message
#
# Cleanable directories:
#   - projects/       Session .jsonl files and subdirectories
#   - debug/          Debug output files
#   - file-history/   File version snapshots
#   - todos/          Todo list backups
#   - session-env/    Environment snapshots
#   - telemetry/      Usage telemetry data
#   - shell-snapshots/ Shell state
#   - plugins/cache/  Old plugin versions
#   - cache/          General cache
#
# Safety (NEVER deleted):
#   - sessions-index.json (in each project directory)
#   - settings.json
#   - .credentials.json
#   - Files modified within last hour (safety margin)
#   - history.jsonl (user command history)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CLAUDE_DIR="${HOME}/.claude"
AGE_HOURS=8
DRY_RUN=false
FORCE=false

# Safety margin: never delete files modified within the last hour
SAFETY_MARGIN_SECONDS=3600

# Protected files (never delete)
PROTECTED_FILES=(
    "sessions-index.json"
    "settings.json"
    ".credentials.json"
    "history.jsonl"
)

# Directories to clean
CLEANABLE_DIRS=(
    "projects"
    "debug"
    "file-history"
    "todos"
    "session-env"
    "telemetry"
    "shell-snapshots"
    "plugins/cache"
    "cache"
)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --age)
            AGE_HOURS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Comprehensive cleanup of ~/.claude/ directory."
            echo ""
            echo "Options:"
            echo "  --age HOURS    Only delete files older than HOURS (default: 8)"
            echo "                 Use --age 0 for clean slate (only respects safety margin)"
            echo "  --dry-run      Show what would be cleaned without changes"
            echo "  --force        Skip confirmation prompt and clean immediately"
            echo "  --help, -h     Show this help message"
            echo ""
            echo "Cleanable directories:"
            echo "  projects/, debug/, file-history/, todos/, session-env/,"
            echo "  telemetry/, shell-snapshots/, plugins/cache/, cache/"
            echo ""
            echo "Safety (NEVER deleted):"
            echo "  - sessions-index.json, settings.json, .credentials.json"
            echo "  - Files modified within last hour"
            echo "  - history.jsonl (command history)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Convert hours to seconds for age threshold
if [[ "$AGE_HOURS" == "0" ]]; then
    # Clean slate mode: only respect safety margin
    AGE_THRESHOLD_SECONDS=$SAFETY_MARGIN_SECONDS
else
    AGE_THRESHOLD_SECONDS=$((AGE_HOURS * 3600))
fi

# Format bytes to human-readable
format_size() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        local gb=$((bytes / 1073741824))
        local gb_frac=$(((bytes % 1073741824) * 10 / 1073741824))
        echo "${gb}.${gb_frac} GB"
    elif [[ $bytes -ge 1048576 ]]; then
        local mb=$((bytes / 1048576))
        local mb_frac=$(((bytes % 1048576) * 10 / 1048576))
        echo "${mb}.${mb_frac} MB"
    elif [[ $bytes -ge 1024 ]]; then
        local kb=$((bytes / 1024))
        echo "${kb} KB"
    else
        echo "${bytes} B"
    fi
}

# Get file age in seconds
get_file_age_seconds() {
    local file="$1"
    local now
    now=$(date +%s)
    local mtime
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || echo "$now")
    echo $((now - mtime))
}

# Get file age in human-readable format
get_file_age_human() {
    local seconds=$1
    local days=$((seconds / 86400))
    local hours=$(((seconds % 86400) / 3600))
    local minutes=$(((seconds % 3600) / 60))

    if [[ $days -gt 0 ]]; then
        echo "${days}d ${hours}h"
    elif [[ $hours -gt 0 ]]; then
        echo "${hours}h ${minutes}m"
    else
        echo "${minutes}m"
    fi
}

# Check if file is protected (should never be deleted)
is_protected() {
    local path="$1"
    local basename
    basename=$(basename "$path")

    for protected in "${PROTECTED_FILES[@]}"; do
        if [[ "$basename" == "$protected" ]]; then
            return 0
        fi
    done
    return 1
}

# Check if file should be cleaned based on age
should_clean() {
    local path="$1"

    # Never delete protected files
    if is_protected "$path"; then
        return 1
    fi

    # Get file age
    local age_seconds
    age_seconds=$(get_file_age_seconds "$path")

    # Never delete files newer than safety margin (1 hour)
    if [[ $age_seconds -lt $SAFETY_MARGIN_SECONDS ]]; then
        return 1
    fi

    # Check against age threshold
    if [[ $age_seconds -ge $AGE_THRESHOLD_SECONDS ]]; then
        return 0
    fi

    return 1
}

# Survey a directory for cleanup candidates
# Sets: DIR_TOTAL_SIZE, DIR_CLEAN_SIZE, DIR_CLEAN_COUNT, DIR_CLEAN_FILES[]
survey_directory() {
    local dir_path="$1"

    DIR_TOTAL_SIZE=0
    DIR_CLEAN_SIZE=0
    DIR_CLEAN_COUNT=0
    DIR_CLEAN_FILES=()

    if [[ ! -d "$dir_path" ]]; then
        return 0
    fi

    # Survey files
    while IFS= read -r -d '' file; do
        local size
        size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null || echo 0)
        DIR_TOTAL_SIZE=$((DIR_TOTAL_SIZE + size))

        if should_clean "$file"; then
            DIR_CLEAN_SIZE=$((DIR_CLEAN_SIZE + size))
            DIR_CLEAN_COUNT=$((DIR_CLEAN_COUNT + 1))
            DIR_CLEAN_FILES+=("$file")
        fi
    done < <(find "$dir_path" -type f -print0 2>/dev/null)

    # Also count directory sizes for subdirectories
    while IFS= read -r -d '' subdir; do
        if [[ "$subdir" != "$dir_path" ]]; then
            # Check if subdirectory is old enough based on its newest file
            local newest_mtime=0
            while IFS= read -r -d '' subfile; do
                local mtime
                mtime=$(stat -c %Y "$subfile" 2>/dev/null || stat -f %m "$subfile" 2>/dev/null || echo 0)
                if [[ $mtime -gt $newest_mtime ]]; then
                    newest_mtime=$mtime
                fi
            done < <(find "$subdir" -type f -print0 2>/dev/null)

            if [[ $newest_mtime -gt 0 ]]; then
                local now
                now=$(date +%s)
                local age_seconds=$((now - newest_mtime))

                # Check safety margin and age threshold
                if [[ $age_seconds -ge $SAFETY_MARGIN_SECONDS ]] && [[ $age_seconds -ge $AGE_THRESHOLD_SECONDS ]]; then
                    # Don't add subdirectory files again - they're already counted
                    # Just mark the directory for deletion
                    :
                fi
            fi
        fi
    done < <(find "$dir_path" -type d -print0 2>/dev/null)
}

# Survey all directories
survey_all() {
    TOTAL_BEFORE_SIZE=0
    TOTAL_CLEAN_SIZE=0
    TOTAL_CLEAN_COUNT=0

    declare -gA SURVEY_RESULTS

    echo ""
    echo -e "${CYAN}Claude Code Directory Cleanup${NC}"
    echo "============================="
    echo ""
    echo -e "Target: ${BLUE}~/.claude/${NC}"
    echo ""

    # Get total ~/.claude size
    local claude_total_size
    claude_total_size=$(du -sb "$CLAUDE_DIR" 2>/dev/null | cut -f1 || echo 0)
    echo "Current total size: $(format_size $claude_total_size)"
    echo ""

    if [[ "$AGE_HOURS" == "0" ]]; then
        echo -e "${YELLOW}Mode: Clean slate${NC} (delete everything except safety margin)"
    else
        echo "Age threshold: ${AGE_HOURS} hours"
    fi
    echo "Safety margin: 1 hour (files modified within last hour are preserved)"
    echo ""

    echo "Scanning directories..."
    echo ""

    printf "%-20s %12s %12s %8s\n" "Directory" "Total" "Cleanable" "Files"
    printf "%-20s %12s %12s %8s\n" "----------" "-------" "----------" "-----"

    for dir in "${CLEANABLE_DIRS[@]}"; do
        local full_path="${CLAUDE_DIR}/${dir}"

        if [[ -d "$full_path" ]]; then
            survey_directory "$full_path"

            TOTAL_BEFORE_SIZE=$((TOTAL_BEFORE_SIZE + DIR_TOTAL_SIZE))
            TOTAL_CLEAN_SIZE=$((TOTAL_CLEAN_SIZE + DIR_CLEAN_SIZE))
            TOTAL_CLEAN_COUNT=$((TOTAL_CLEAN_COUNT + DIR_CLEAN_COUNT))

            # Store results
            SURVEY_RESULTS["${dir}_total"]=$DIR_TOTAL_SIZE
            SURVEY_RESULTS["${dir}_clean"]=$DIR_CLEAN_SIZE
            SURVEY_RESULTS["${dir}_count"]=$DIR_CLEAN_COUNT

            # Format output
            if [[ $DIR_CLEAN_COUNT -gt 0 ]]; then
                printf "%-20s %12s %12s %8d\n" "$dir/" "$(format_size $DIR_TOTAL_SIZE)" "$(format_size $DIR_CLEAN_SIZE)" "$DIR_CLEAN_COUNT"
            else
                printf "%-20s %12s %12s %8s\n" "$dir/" "$(format_size $DIR_TOTAL_SIZE)" "-" "-"
            fi
        else
            printf "%-20s %12s %12s %8s\n" "$dir/" "(not found)" "-" "-"
        fi
    done

    echo ""
    printf "%-20s %12s %12s %8d\n" "TOTAL" "$(format_size $TOTAL_BEFORE_SIZE)" "$(format_size $TOTAL_CLEAN_SIZE)" "$TOTAL_CLEAN_COUNT"
    echo ""
}

# Perform cleanup for a single directory
cleanup_directory() {
    local dir_path="$1"
    local dir_name="$2"

    if [[ ! -d "$dir_path" ]]; then
        return 0
    fi

    local deleted=0
    local deleted_size=0
    local failed=0

    # Find and delete old files
    while IFS= read -r -d '' file; do
        if should_clean "$file"; then
            local size
            size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null || echo 0)
            local age_seconds
            age_seconds=$(get_file_age_seconds "$file")
            local basename
            basename=$(basename "$file")
            local short_name="${basename:0:20}"
            [[ ${#basename} -gt 20 ]] && short_name="${short_name}..."

            if $DRY_RUN; then
                echo "  Would delete: ${dir_name}/${short_name} ($(format_size $size), $(get_file_age_human $age_seconds) old)"
                deleted=$((deleted + 1))
                deleted_size=$((deleted_size + size))
            else
                if rm -f "$file" 2>/dev/null; then
                    deleted=$((deleted + 1))
                    deleted_size=$((deleted_size + size))
                else
                    failed=$((failed + 1))
                fi
            fi
        fi
    done < <(find "$dir_path" -type f -print0 2>/dev/null)

    # Clean up empty directories
    if ! $DRY_RUN; then
        find "$dir_path" -type d -empty -delete 2>/dev/null || true
    fi

    CLEANUP_DELETED=$((CLEANUP_DELETED + deleted))
    CLEANUP_DELETED_SIZE=$((CLEANUP_DELETED_SIZE + deleted_size))
    CLEANUP_FAILED=$((CLEANUP_FAILED + failed))
}

# Perform full cleanup
perform_cleanup() {
    CLEANUP_DELETED=0
    CLEANUP_DELETED_SIZE=0
    CLEANUP_FAILED=0

    echo ""
    if $DRY_RUN; then
        echo -e "${YELLOW}Dry run - showing what would be deleted:${NC}"
    else
        echo -e "${GREEN}Performing cleanup...${NC}"
    fi
    echo ""

    for dir in "${CLEANABLE_DIRS[@]}"; do
        local full_path="${CLAUDE_DIR}/${dir}"
        if [[ -d "$full_path" ]]; then
            cleanup_directory "$full_path" "$dir"
        fi
    done

    echo ""
    if $DRY_RUN; then
        echo -e "${YELLOW}Dry Run Summary${NC}"
        echo "==============="
        echo "Would delete: $CLEANUP_DELETED files"
        echo "Would reclaim: $(format_size $CLEANUP_DELETED_SIZE)"
    else
        echo -e "${GREEN}Cleanup Complete${NC}"
        echo "================"
        echo "Deleted: $CLEANUP_DELETED files"
        echo "Failed:  $CLEANUP_FAILED files"
        echo "Space reclaimed: $(format_size $CLEANUP_DELETED_SIZE)"

        # Show new total size
        local new_total
        new_total=$(du -sb "$CLAUDE_DIR" 2>/dev/null | cut -f1 || echo 0)
        echo ""
        echo "New total size: $(format_size $new_total)"
    fi
    echo ""
}

# Output JSON summary for programmatic use
output_json_summary() {
    echo "{"
    echo "  \"files_deleted\": $CLEANUP_DELETED,"
    echo "  \"bytes_freed\": $CLEANUP_DELETED_SIZE,"
    echo "  \"directories_cleaned\": ${#CLEANABLE_DIRS[@]},"
    echo "  \"failed\": $CLEANUP_FAILED"
    echo "}"
}

# Main execution
main() {
    # Check if ~/.claude exists
    if [[ ! -d "$CLAUDE_DIR" ]]; then
        echo "Error: ~/.claude directory not found"
        exit 1
    fi

    # Run survey
    survey_all

    # Check if there's anything to clean
    if [[ $TOTAL_CLEAN_COUNT -eq 0 ]]; then
        echo -e "${GREEN}No cleanup candidates found.${NC}"
        echo "All files are either protected or within the age threshold."
        echo ""
        exit 0
    fi

    echo -e "${YELLOW}Space that can be reclaimed: $(format_size $TOTAL_CLEAN_SIZE)${NC}"
    echo ""

    # Handle dry-run mode
    if $DRY_RUN; then
        perform_cleanup
        exit 0
    fi

    # Handle force mode
    if $FORCE; then
        perform_cleanup
        exit 0
    fi

    # Default mode: exit with code 1 to signal that candidates exist
    # The calling skill will handle confirmation via AskUserQuestion
    exit 1
}

main
