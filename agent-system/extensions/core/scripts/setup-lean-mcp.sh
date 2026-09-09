#!/usr/bin/env bash
#
# setup-lean-mcp.sh - Configure lean-lsp MCP server in user scope
#
# This script adds the lean-lsp MCP server to ~/.claude.json (user scope). A subagent CAN
# reach a project-scoped `.mcp.json` server once the workspace is trusted -- directly
# demonstrated, twice. The real friction cost is narrower: a fresh clone still carries a
# one-time interactive workspace-trust step (Claude Code v2.1.196+) that user-scope
# registration does not, and a cloned repository cannot approve its own servers. lean-lsp
# stays in user scope for an independent reason -- it needs a per-project computed
# `LEAN_PROJECT_PATH`, which this script detects below.
# See agent-system/extensions/core/context/patterns/mcp-server-ownership.md for the full
# registration/permission split.
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
    # Try to detect from current directory or git root. Lean 4 projects use lakefile.lean;
    # some (e.g. cslib) use lakefile.toml instead -- both are valid Lake project markers.
    GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -f "lakefile.lean" ] || [ -f "lakefile.toml" ]; then
        PROJECT_PATH="$(pwd)"
    elif [ -n "$GIT_ROOT" ] && { [ -f "$GIT_ROOT/lakefile.lean" ] || [ -f "$GIT_ROOT/lakefile.toml" ]; }; then
        PROJECT_PATH="$GIT_ROOT"
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

    # Remove lean-lsp using jq. Temp file lives alongside $CLAUDE_CONFIG so mv stays a
    # same-filesystem atomic rename regardless of CWD.
    TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
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

# Config exists, check if lean-lsp already configured. The comparison and the repair both
# operate on the WHOLE entry (not just env.LEAN_PROJECT_PATH), because a hand-edited or
# otherwise divergent entry can carry a wrong command/args while still matching on project
# path alone -- an entry-shape drift that a field-only comparison cannot see or fix.
if jq -e '.mcpServers."lean-lsp"' "$CLAUDE_CONFIG" > /dev/null 2>&1; then
    EXISTING_ENTRY=$(jq -c '.mcpServers."lean-lsp"' "$CLAUDE_CONFIG")
    EXISTING_COMMAND=$(jq -r '.mcpServers."lean-lsp".command // "(none)"' "$CLAUDE_CONFIG")
    EXISTING_ARGS=$(jq -c '.mcpServers."lean-lsp".args // []' "$CLAUDE_CONFIG")
    EXISTING_PATH=$(jq -r '.mcpServers."lean-lsp".env.LEAN_PROJECT_PATH // "(none)"' "$CLAUDE_CONFIG")

    LEAN_CONFIG=$(generate_lean_lsp_config)
    CANONICAL_ENTRY=$(printf '%s' "$LEAN_CONFIG" | jq -c '.')

    ENTRIES_MATCH=$(jq -n --argjson a "$EXISTING_ENTRY" --argjson b "$CANONICAL_ENTRY" '$a == $b')

    if [ "$ENTRIES_MATCH" = "true" ]; then
        echo "lean-lsp already configured with correct project path."
        echo "No changes needed."
        exit 0
    fi

    echo "lean-lsp already configured but diverges from the sanctioned shape:"
    echo "  Current command:      $EXISTING_COMMAND"
    echo "  Current args:         $EXISTING_ARGS"
    echo "  Current project path: $EXISTING_PATH"
    echo "  Sanctioned command:      uvx"
    echo "  Sanctioned args:         [\"lean-lsp-mcp\"]"
    echo "  Sanctioned project path: $PROJECT_PATH"
    echo ""

    if $DRY_RUN; then
        echo "[DRY RUN] Would replace the entire lean-lsp entry with:"
        printf '%s\n' "$LEAN_CONFIG" | sed 's/^/  /'
        exit 0
    fi

    # Overwrite the whole entry with the sanctioned shape -- never a targeted per-field
    # assignment, so command/args drift (e.g. a dead wrapper script) is corrected along
    # with the project path. Temp file lives alongside $CLAUDE_CONFIG so mv stays a
    # same-filesystem atomic rename regardless of CWD.
    TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
    jq --argjson leanConfig "$LEAN_CONFIG" '.mcpServers."lean-lsp" = $leanConfig' "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"

    echo "Replaced lean-lsp entry with the sanctioned shape (command, args, and project path)."
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

TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
LEAN_CONFIG=$(generate_lean_lsp_config)

# Use jq to add the server, preserving existing content
jq --argjson leanConfig "$LEAN_CONFIG" '.mcpServers."lean-lsp" = $leanConfig' "$CLAUDE_CONFIG" > "$TMP_FILE"
mv "$TMP_FILE" "$CLAUDE_CONFIG"

echo "Added lean-lsp to $CLAUDE_CONFIG"
echo ""
echo "Restart Claude Code for changes to take effect."
