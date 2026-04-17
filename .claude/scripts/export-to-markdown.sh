#!/usr/bin/env bash
#
# export-to-markdown.sh - Export .claude/ directory to single consolidated markdown file
#
# Usage: ./export-to-markdown.sh [OPTIONS]
#
# Options:
#   -o, --output FILE    Output file path (default: docs/claude-directory-export.md)
#   --help, -h           Show this help message
#
# Features:
#   - Generates hierarchical table of contents from directory structure
#   - Respects .gitignore exclusions plus backup file exclusions
#   - Wraps non-markdown files in appropriate code blocks (bash, json, yaml)
#   - Adjusts header levels to maintain hierarchy under file section headers
#   - Includes export timestamp for version tracking

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLAUDE_DIR="$PROJECT_ROOT/.claude"
DEFAULT_OUTPUT="$PROJECT_ROOT/docs/claude-directory-export.md"

# Exclusion patterns (from research findings)
EXCLUDE_PATTERNS=(
    "*.log"
    "*.tmp"
    "*.bak"
    "*.backup"
    "settings.local.json"
    "logs/*"
    ".gitignore"
)

# Output file
OUTPUT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Export .claude/ directory to single consolidated markdown file."
            echo ""
            echo "Options:"
            echo "  -o, --output FILE    Output file path (default: docs/claude-directory-export.md)"
            echo "  --help, -h           Show this help message"
            echo ""
            echo "Features:"
            echo "  - Generates hierarchical table of contents"
            echo "  - Respects .gitignore exclusions"
            echo "  - Wraps non-markdown in code blocks"
            echo "  - Adjusts markdown headers for hierarchy"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set default output if not specified
OUTPUT="${OUTPUT:-$DEFAULT_OUTPUT}"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT")"

# Check if file should be excluded
should_exclude() {
    local file="$1"
    local basename
    basename=$(basename "$file")
    local relpath="${file#$CLAUDE_DIR/}"

    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        # Handle glob patterns
        case "$pattern" in
            *\**)
                # Pattern with wildcard - check basename for *.ext patterns
                if [[ "$pattern" == \*.* ]]; then
                    local ext="${pattern#\*.}"
                    if [[ "$basename" == *".$ext" ]]; then
                        return 0
                    fi
                # Check for directory/* patterns
                elif [[ "$pattern" == */ ]]; then
                    local dir="${pattern%/\*}"
                    if [[ "$relpath" == "$dir/"* ]]; then
                        return 0
                    fi
                fi
                ;;
            *)
                # Exact match on basename or relpath
                if [[ "$basename" == "$pattern" ]] || [[ "$relpath" == "$pattern" ]]; then
                    return 0
                fi
                ;;
        esac
    done
    return 1
}

# Get file type for code block language
get_file_type() {
    local file="$1"
    local ext="${file##*.}"
    local basename
    basename=$(basename "$file")

    case "$ext" in
        sh)
            echo "bash"
            ;;
        json)
            echo "json"
            ;;
        yaml|yml)
            echo "yaml"
            ;;
        md)
            echo "markdown"
            ;;
        lean)
            echo "lean"
            ;;
        toml)
            echo "toml"
            ;;
        py)
            echo "python"
            ;;
        *)
            # Check for known filenames without extensions
            case "$basename" in
                Makefile|makefile)
                    echo "makefile"
                    ;;
                Dockerfile)
                    echo "dockerfile"
                    ;;
                *)
                    echo "text"
                    ;;
            esac
            ;;
    esac
}

# Adjust markdown headers by shifting them down 2 levels
# h1 (#) -> h3 (###), h2 (##) -> h4 (####), etc.
adjust_headers() {
    sed 's/^#/###/'
}

# Discover all exportable files
discover_files() {
    local files=()

    # Find all files, excluding patterns
    while IFS= read -r -d '' file; do
        if ! should_exclude "$file"; then
            files+=("$file")
        fi
    done < <(find "$CLAUDE_DIR" -type f -print0 2>/dev/null | sort -z)

    # Sort: root files first, then alphabetically by directory
    local root_files=()
    local dir_files=()

    for file in "${files[@]}"; do
        local relpath="${file#$CLAUDE_DIR/}"
        if [[ "$relpath" != */* ]]; then
            root_files+=("$file")
        else
            dir_files+=("$file")
        fi
    done

    # Sort root files alphabetically
    IFS=$'\n' root_files=($(sort <<<"${root_files[*]}")); unset IFS

    # Sort dir files alphabetically
    IFS=$'\n' dir_files=($(sort <<<"${dir_files[*]}")); unset IFS

    # Output root files first, then directory files
    printf '%s\n' "${root_files[@]}" "${dir_files[@]}"
}

# Generate table of contents from file list
generate_toc() {
    local files=("$@")
    local current_dir=""
    local file_count=${#files[@]}

    echo "## Table of Contents"
    echo ""
    echo "**Total files**: $file_count"
    echo ""

    for file in "${files[@]}"; do
        local relpath="${file#$CLAUDE_DIR/}"
        local dir
        dir=$(dirname "$relpath")
        local basename
        basename=$(basename "$relpath")

        # Track directory changes for hierarchy
        if [[ "$dir" != "$current_dir" ]]; then
            if [[ "$dir" != "." ]]; then
                # Get top-level directory
                local top_dir="${dir%%/*}"
                if [[ "$current_dir" != "$top_dir"* ]] || [[ "$current_dir" == "." ]]; then
                    echo "### $top_dir/"
                    echo ""
                fi
            fi
            current_dir="$dir"
        fi

        # Create anchor-safe link
        local anchor
        anchor=$(echo "$relpath" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g')

        # Format based on depth
        local indent=""
        local depth
        depth=$(echo "$relpath" | tr -cd '/' | wc -c)
        for ((i=0; i<depth; i++)); do
            indent="  $indent"
        done

        echo "${indent}- [$relpath](#$anchor)"
    done
    echo ""
}

# Process a single file and output to markdown
process_file() {
    local file="$1"
    local relpath="${file#$CLAUDE_DIR/}"
    local file_type
    file_type=$(get_file_type "$file")

    # Create anchor-safe ID
    local anchor
    anchor=$(echo "$relpath" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g')

    echo ""
    echo "---"
    echo ""
    echo "<a id=\"$anchor\"></a>"
    echo ""
    echo "## $relpath"
    echo ""

    # Handle content based on file type
    if [[ "$file_type" == "markdown" ]]; then
        # For markdown files, adjust headers and include directly
        adjust_headers < "$file"
    else
        # For non-markdown, wrap in code block
        echo '```'"$file_type"
        cat "$file"
        echo '```'
    fi
    echo ""
}

# Main export function
main() {
    echo "Exporting .claude/ directory to markdown..."
    echo "Source: $CLAUDE_DIR"
    echo "Output: $OUTPUT"
    echo ""

    # Discover files
    local files_list
    files_list=$(discover_files)

    # Convert to array
    local files=()
    while IFS= read -r file; do
        [[ -n "$file" ]] && files+=("$file")
    done <<< "$files_list"

    local file_count=${#files[@]}
    echo "Found $file_count files to export"
    echo ""

    # Start output file
    {
        echo "# .claude/ Directory Export"
        echo ""
        echo "**Generated**: $(date -Iseconds)"
        echo ""
        echo "**Source**: \`.claude/\` directory"
        echo ""
        echo "**File count**: $file_count"
        echo ""
        echo "---"
        echo ""

        # Generate TOC
        generate_toc "${files[@]}"

        # Process each file
        local processed=0
        for file in "${files[@]}"; do
            process_file "$file"
            processed=$((processed + 1))
            if (( processed % 50 == 0 )); then
                echo "Processed $processed / $file_count files..." >&2
            fi
        done

    } > "$OUTPUT"

    # Report results
    local output_size
    output_size=$(wc -c < "$OUTPUT")
    local output_lines
    output_lines=$(wc -l < "$OUTPUT")

    echo ""
    echo "Export complete!"
    echo "  Output file: $OUTPUT"
    echo "  File size: $((output_size / 1024)) KB"
    echo "  Line count: $output_lines"
}

main
