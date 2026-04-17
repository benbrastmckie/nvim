#!/usr/bin/env bash
#
# claude-project-cleanup.sh - Survey and clean up accumulated Claude Code project files
#
# Usage: ./claude-project-cleanup.sh [OPTIONS]
#
# Options:
#   --age DAYS     Only target sessions older than DAYS (default: 7)
#   --dry-run      Show what would be cleaned without changes
#   --force        Skip confirmation prompt and clean immediately
#   --help, -h     Show this help message
#
# Safety:
#   - Never modifies sessions-index.json (Claude Code system file)
#   - Never deletes files modified within the last hour
#   - Confirmation required unless --force is provided
#   - Dry-run available to preview changes

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
AGE_DAYS=7
DRY_RUN=false
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --age)
            AGE_DAYS="$2"
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
            echo "Survey and clean up accumulated Claude Code project files."
            echo ""
            echo "Options:"
            echo "  --age DAYS     Only target sessions older than DAYS (default: 7)"
            echo "  --dry-run      Show what would be cleaned without changes"
            echo "  --force        Skip confirmation prompt and clean immediately"
            echo "  --help, -h     Show this help message"
            echo ""
            echo "Safety:"
            echo "  - Never modifies sessions-index.json"
            echo "  - Never deletes files modified within the last hour"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Get current project path
get_current_project() {
    # Use pwd as the project path
    pwd
}

# Encode project path to Claude Code directory name
# Replaces / with - and prepends -
encode_project_path() {
    local path="$1"
    echo "$path" | sed 's|/|-|g'
}

# Get Claude Code project directory
get_project_dir() {
    local project_path
    project_path=$(get_current_project)
    local encoded
    encoded=$(encode_project_path "$project_path")
    echo "${HOME}/.claude/projects/${encoded}"
}

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

# Get file age in days
get_file_age_days() {
    local file="$1"
    local now
    now=$(date +%s)
    local mtime
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
    local age_seconds=$((now - mtime))
    echo $((age_seconds / 86400))
}

# Get file age in human-readable format
get_file_age_human() {
    local file="$1"
    local now
    now=$(date +%s)
    local mtime
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
    local age_seconds=$((now - mtime))

    local days=$((age_seconds / 86400))
    local hours=$(((age_seconds % 86400) / 3600))

    if [[ $days -gt 0 ]]; then
        echo "${days}d ${hours}h"
    else
        local minutes=$(((age_seconds % 3600) / 60))
        echo "${hours}h ${minutes}m"
    fi
}

# Check if file was modified within the last hour (safety check)
is_recently_modified() {
    local file="$1"
    local now
    now=$(date +%s)
    local mtime
    mtime=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
    local age_seconds=$((now - mtime))
    [[ $age_seconds -lt 3600 ]]
}

# Survey the project directory
survey_project() {
    local project_dir="$1"
    local age_threshold="$2"

    if [[ ! -d "$project_dir" ]]; then
        echo "ERROR: Project directory not found: $project_dir"
        return 1
    fi

    local total_size=0
    local total_sessions=0
    local total_jsonl=0
    local cleanup_sessions=0
    local cleanup_size=0
    local cleanup_files=()
    local cleanup_dirs=()
    local largest_file=""
    local largest_size=0
    local largest_age=""

    # Count JSONL files and calculate sizes
    while IFS= read -r -d '' file; do
        local size
        size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null)
        total_size=$((total_size + size))
        total_jsonl=$((total_jsonl + 1))

        local age_days
        age_days=$(get_file_age_days "$file")

        # Check if this is a cleanup candidate
        if [[ $age_days -ge $age_threshold ]] && ! is_recently_modified "$file"; then
            cleanup_size=$((cleanup_size + size))
            cleanup_files+=("$file")

            # Track largest file
            if [[ $size -gt $largest_size ]]; then
                largest_size=$size
                largest_file="$file"
                largest_age=$(get_file_age_human "$file")
            fi
        fi
    done < <(find "$project_dir" -maxdepth 1 -name "*.jsonl" -type f -print0 2>/dev/null)

    # Count session directories
    while IFS= read -r -d '' dir; do
        local dir_size
        dir_size=$(du -sb "$dir" 2>/dev/null | cut -f1 || du -sk "$dir" 2>/dev/null | awk '{print $1 * 1024}')
        total_size=$((total_size + dir_size))
        total_sessions=$((total_sessions + 1))

        # Check directory modification time by looking at most recent file
        local newest_file
        newest_file=$(find "$dir" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
        if [[ -n "$newest_file" ]]; then
            local age_days
            age_days=$(get_file_age_days "$newest_file")

            if [[ $age_days -ge $age_threshold ]] && ! is_recently_modified "$newest_file"; then
                cleanup_size=$((cleanup_size + dir_size))
                cleanup_dirs+=("$dir")
                cleanup_sessions=$((cleanup_sessions + 1))
            fi
        fi
    done < <(find "$project_dir" -maxdepth 1 -type d ! -name "$(basename "$project_dir")" -print0 2>/dev/null)

    # Export results for use by caller
    SURVEY_TOTAL_SIZE=$total_size
    SURVEY_TOTAL_SESSIONS=$total_sessions
    SURVEY_TOTAL_JSONL=$total_jsonl
    SURVEY_CLEANUP_SESSIONS=$cleanup_sessions
    SURVEY_CLEANUP_SIZE=$cleanup_size
    SURVEY_CLEANUP_FILES=("${cleanup_files[@]}")
    SURVEY_CLEANUP_DIRS=("${cleanup_dirs[@]}")
    SURVEY_LARGEST_FILE=$largest_file
    SURVEY_LARGEST_SIZE=$largest_size
    SURVEY_LARGEST_AGE=$largest_age
}

# Display survey results
display_survey() {
    local project_path
    project_path=$(get_current_project)
    local project_dir
    project_dir=$(get_project_dir)

    echo ""
    echo -e "${CYAN}Claude Code Project Cleanup${NC}"
    echo "==========================="
    echo ""
    echo -e "Project: ${BLUE}$project_path${NC}"
    echo -e "Directory: ${BLUE}~/.claude/projects/$(basename "$project_dir")/${NC}"
    echo ""
    echo "Current Usage:"
    echo "  Total size:        $(format_size $SURVEY_TOTAL_SIZE)"
    echo "  Session dirs:      $SURVEY_TOTAL_SESSIONS"
    echo "  JSONL log count:   $SURVEY_TOTAL_JSONL"
    echo ""

    local cleanup_count=$((${#SURVEY_CLEANUP_FILES[@]} + ${#SURVEY_CLEANUP_DIRS[@]}))

    if [[ $cleanup_count -eq 0 ]]; then
        echo -e "${GREEN}No cleanup candidates found (age threshold: ${AGE_DAYS} days)${NC}"
        echo ""
        return 0
    fi

    echo -e "${YELLOW}Cleanup Candidates (sessions older than ${AGE_DAYS} days):${NC}"
    echo "  JSONL files:       ${#SURVEY_CLEANUP_FILES[@]}"
    echo "  Session dirs:      ${#SURVEY_CLEANUP_DIRS[@]}"
    echo "  Total size:        $(format_size $SURVEY_CLEANUP_SIZE)"

    if [[ -n "$SURVEY_LARGEST_FILE" ]]; then
        local basename
        basename=$(basename "$SURVEY_LARGEST_FILE" .jsonl)
        # Truncate UUID for display
        local short_name="${basename:0:8}..."
        echo "  Largest:           $short_name ($(format_size $SURVEY_LARGEST_SIZE), $SURVEY_LARGEST_AGE old)"
    fi
    echo ""

    return 1  # Indicates cleanup candidates exist
}

# Perform cleanup
perform_cleanup() {
    local deleted_files=0
    local deleted_dirs=0
    local deleted_size=0
    local failed=0

    echo ""
    if $DRY_RUN; then
        echo -e "${YELLOW}Dry run - showing what would be deleted:${NC}"
    else
        echo -e "${GREEN}Cleaning up old sessions...${NC}"
    fi
    echo ""

    # Delete JSONL files
    for file in "${SURVEY_CLEANUP_FILES[@]}"; do
        local basename
        basename=$(basename "$file" .jsonl)
        local short_name="${basename:0:8}..."
        local size
        size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null)

        if $DRY_RUN; then
            echo "  Would delete: $short_name.jsonl ($(format_size $size))"
            deleted_files=$((deleted_files + 1))
            deleted_size=$((deleted_size + size))
        else
            if rm -f "$file" 2>/dev/null; then
                echo "  Deleted: $short_name.jsonl ($(format_size $size))"
                deleted_files=$((deleted_files + 1))
                deleted_size=$((deleted_size + size))
            else
                echo "  Failed:  $short_name.jsonl"
                failed=$((failed + 1))
            fi
        fi
    done

    # Delete session directories
    for dir in "${SURVEY_CLEANUP_DIRS[@]}"; do
        local basename
        basename=$(basename "$dir")
        local short_name="${basename:0:8}..."
        local size
        size=$(du -sb "$dir" 2>/dev/null | cut -f1 || du -sk "$dir" 2>/dev/null | awk '{print $1 * 1024}')

        if $DRY_RUN; then
            echo "  Would delete: $short_name/ ($(format_size $size))"
            deleted_dirs=$((deleted_dirs + 1))
            deleted_size=$((deleted_size + size))
        else
            if rm -rf "$dir" 2>/dev/null; then
                echo "  Deleted: $short_name/ ($(format_size $size))"
                deleted_dirs=$((deleted_dirs + 1))
                deleted_size=$((deleted_size + size))
            else
                echo "  Failed:  $short_name/"
                failed=$((failed + 1))
            fi
        fi
    done

    echo ""
    if $DRY_RUN; then
        echo -e "${YELLOW}Dry Run Summary${NC}"
        echo "==============="
        echo "Would delete: $deleted_files JSONL files"
        echo "Would delete: $deleted_dirs session directories"
        echo "Would reclaim: $(format_size $deleted_size)"
    else
        echo -e "${GREEN}Claude Code Project Cleanup Complete${NC}"
        echo "===================================="
        echo "Deleted files: $deleted_files"
        echo "Deleted dirs:  $deleted_dirs"
        echo "Failed:        $failed"
        echo "Space reclaimed: $(format_size $deleted_size)"
    fi
    echo ""
}

# Main execution
main() {
    local project_dir
    project_dir=$(get_project_dir)

    # Run survey
    survey_project "$project_dir" "$AGE_DAYS" || {
        echo -e "${RED}Error: Could not survey project directory${NC}"
        echo "Directory: $project_dir"
        exit 1
    }

    # Display survey results
    # Note: display_survey returns 0 if no candidates, 1 if candidates exist
    # We capture the return value before set -e can act on it
    if display_survey; then
        has_candidates=0
    else
        has_candidates=1
    fi

    # Exit if no cleanup candidates
    if [[ $has_candidates -eq 0 ]]; then
        exit 0
    fi

    # Handle dry-run mode - show what would be deleted
    if $DRY_RUN; then
        perform_cleanup
        exit 0
    fi

    # Handle force mode - execute cleanup
    if $FORCE; then
        perform_cleanup
        exit 0
    fi

    # Default mode: exit with code 1 to signal skill that candidates exist
    # The skill will handle confirmation via AskUserQuestion
    echo "Total space that can be reclaimed: $(format_size $SURVEY_CLEANUP_SIZE)"
    echo ""
    exit 1
}

main
