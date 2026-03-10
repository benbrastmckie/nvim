#!/usr/bin/env bash
#
# setup-lean-mcp.sh - Configure lean-lsp MCP server in user scope
#
# This script adds the lean-lsp MCP server to ~/.claude.json (user scope)
# to work around Claude Code platform bugs where custom subagents cannot
# access project-scoped MCP servers (.mcp.json).
#
# Usage: ./setup-lean-mcp.sh [OPTIONS]
#
# Options:
#   --project PATH    Override project path (default: auto-detect)
#   --dry-run         Show what would be done without making changes
#   --remove          Remove lean-lsp from user scope
#   --help            Show this help message
#
# The script will:
#   1. Detect the Lean project path (or use --project)
#   2. Create ~/.claude.json if it doesn't exist
#   3. Add lean-lsp server configuration if not present
#   4. Preserve existing user configuration
#
# After running, restart Claude Code for changes to take effect.

set -euo pipefail

# Default values
DRY_RUN=false
REMOVE=false
PROJECT_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_PATH="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --remove)
            REMOVE=true
            shift
            ;;
        --help|-h)
            sed -n '2,/^$/p' "$0" | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run with --help for usage"
            exit 1
            ;;
    esac
done

# Detect project path if not provided
if [ -z "$PROJECT_PATH" ]; then
    # Try to detect from current directory or git root
    if [ -f "lakefile.lean" ]; then
        PROJECT_PATH="$(pwd)"
    elif [ -f "$(git rev-parse --show-toplevel 2>/dev/null)/lakefile.lean" ]; then
        PROJECT_PATH="$(git rev-parse --show-toplevel)"
    else
        echo "Error: Could not detect Lean project path."
        echo "Run from project directory or use --project PATH"
        exit 1
    fi
fi

CLAUDE_CONFIG="$HOME/.claude.json"

echo "Configuration:"
echo "  Project path: $PROJECT_PATH"
echo "  Claude config: $CLAUDE_CONFIG"
echo ""

# Generate the lean-lsp configuration
generate_lean_lsp_config() {
    cat << EOF
{
  "type": "stdio",
  "command": "uvx",
  "args": ["lean-lsp-mcp"],
  "env": {
    "LEAN_LOG_LEVEL": "WARNING",
    "LEAN_PROJECT_PATH": "$PROJECT_PATH"
  }
}
EOF
}

# Handle removal
if $REMOVE; then
    if [ ! -f "$CLAUDE_CONFIG" ]; then
        echo "No ~/.claude.json found, nothing to remove."
        exit 0
    fi

    if ! jq -e '.mcpServers."lean-lsp"' "$CLAUDE_CONFIG" > /dev/null 2>&1; then
        echo "lean-lsp not found in ~/.claude.json, nothing to remove."
        exit 0
    fi

    if $DRY_RUN; then
        echo "[DRY RUN] Would remove lean-lsp from $CLAUDE_CONFIG"
        exit 0
    fi

    # Remove lean-lsp using jq
    TMP_FILE=$(mktemp)
    jq 'del(.mcpServers."lean-lsp")' "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"

    echo "Removed lean-lsp from $CLAUDE_CONFIG"
    echo ""
    echo "Restart Claude Code for changes to take effect."
    exit 0
fi

# Check if config exists
if [ ! -f "$CLAUDE_CONFIG" ]; then
    if $DRY_RUN; then
        echo "[DRY RUN] Would create $CLAUDE_CONFIG with lean-lsp configuration:"
        echo ""
        echo '{'
        echo '  "mcpServers": {'
        echo '    "lean-lsp": '
        generate_lean_lsp_config | sed 's/^/    /'
        echo '  }'
        echo '}'
        exit 0
    fi

    # Create new config file
    echo "Creating $CLAUDE_CONFIG..."

    cat > "$CLAUDE_CONFIG" << EOF
{
  "mcpServers": {
    "lean-lsp": $(generate_lean_lsp_config)
  }
}
EOF

    echo "Created $CLAUDE_CONFIG with lean-lsp configuration."
    echo ""
    echo "Restart Claude Code for changes to take effect."
    exit 0
fi

# Config exists, check if lean-lsp already configured
if jq -e '.mcpServers."lean-lsp"' "$CLAUDE_CONFIG" > /dev/null 2>&1; then
    EXISTING_PATH=$(jq -r '.mcpServers."lean-lsp".env.LEAN_PROJECT_PATH // empty' "$CLAUDE_CONFIG")

    if [ "$EXISTING_PATH" = "$PROJECT_PATH" ]; then
        echo "lean-lsp already configured with correct project path."
        echo "No changes needed."
        exit 0
    fi

    echo "lean-lsp already configured but with different project path:"
    echo "  Current: $EXISTING_PATH"
    echo "  New: $PROJECT_PATH"
    echo ""

    if $DRY_RUN; then
        echo "[DRY RUN] Would update LEAN_PROJECT_PATH to: $PROJECT_PATH"
        exit 0
    fi

    # Update the project path
    TMP_FILE=$(mktemp)
    jq --arg path "$PROJECT_PATH" '.mcpServers."lean-lsp".env.LEAN_PROJECT_PATH = $path' "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"

    echo "Updated LEAN_PROJECT_PATH to: $PROJECT_PATH"
    echo ""
    echo "Restart Claude Code for changes to take effect."
    exit 0
fi

# Config exists but lean-lsp not present
if $DRY_RUN; then
    echo "[DRY RUN] Would add lean-lsp to existing $CLAUDE_CONFIG"
    echo ""
    echo "New lean-lsp configuration:"
    generate_lean_lsp_config | sed 's/^/  /'
    exit 0
fi

# Add lean-lsp to existing config
echo "Adding lean-lsp to existing configuration..."

TMP_FILE=$(mktemp)
LEAN_CONFIG=$(generate_lean_lsp_config)

# Use jq to add the server, preserving existing content
jq --argjson leanConfig "$LEAN_CONFIG" '.mcpServers."lean-lsp" = $leanConfig' "$CLAUDE_CONFIG" > "$TMP_FILE"
mv "$TMP_FILE" "$CLAUDE_CONFIG"

echo "Added lean-lsp to $CLAUDE_CONFIG"
echo ""
echo "Restart Claude Code for changes to take effect."
