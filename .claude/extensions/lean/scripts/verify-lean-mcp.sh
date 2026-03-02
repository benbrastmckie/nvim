#!/usr/bin/env bash
#
# verify-lean-mcp.sh - Verify lean-lsp MCP server configuration
#
# This script checks if lean-lsp is properly configured in user scope
# (~/.claude.json) for use with Claude Code subagents.
#
# Usage: ./verify-lean-mcp.sh [OPTIONS]
#
# Options:
#   --project PATH    Override expected project path (default: auto-detect)
#   --quiet           Only output pass/fail, no details
#   --help            Show this help message
#
# Exit codes:
#   0 - Configuration valid
#   1 - Configuration missing or invalid
#   2 - Project path mismatch

set -euo pipefail

# Default values
QUIET=false
EXPECTED_PROJECT_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            EXPECTED_PROJECT_PATH="$2"
            shift 2
            ;;
        --quiet|-q)
            QUIET=true
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

# Detect expected project path if not provided
if [ -z "$EXPECTED_PROJECT_PATH" ]; then
    if [ -f "lakefile.lean" ]; then
        EXPECTED_PROJECT_PATH="$(pwd)"
    elif [ -f "$(git rev-parse --show-toplevel 2>/dev/null)/lakefile.lean" ]; then
        EXPECTED_PROJECT_PATH="$(git rev-parse --show-toplevel)"
    else
        echo "Error: Could not detect Lean project path."
        echo "Run from project directory or use --project PATH"
        exit 1
    fi
fi

CLAUDE_CONFIG="$HOME/.claude.json"

# Helper functions
log() {
    if ! $QUIET; then
        echo "$@"
    fi
}

pass() {
    if $QUIET; then
        echo "PASS"
    else
        echo "[PASS] $1"
    fi
}

fail() {
    if $QUIET; then
        echo "FAIL"
    else
        echo "[FAIL] $1"
    fi
}

warn() {
    if ! $QUIET; then
        echo "[WARN] $1"
    fi
}

# Check 1: Does ~/.claude.json exist?
log "Checking lean-lsp configuration..."
log ""

if [ ! -f "$CLAUDE_CONFIG" ]; then
    fail "~/.claude.json not found"
    log ""
    log "Run setup-lean-mcp.sh to configure"
    exit 1
fi

log "  Config file: $CLAUDE_CONFIG"

# Check 2: Is lean-lsp configured?
if ! jq -e '.mcpServers."lean-lsp"' "$CLAUDE_CONFIG" > /dev/null 2>&1; then
    fail "lean-lsp not found in ~/.claude.json"
    log ""
    log "Run setup-lean-mcp.sh to configure"
    exit 1
fi

log "  lean-lsp: configured"

# Check 3: Is the command correct?
COMMAND=$(jq -r '.mcpServers."lean-lsp".command // empty' "$CLAUDE_CONFIG")
if [ "$COMMAND" != "uvx" ]; then
    warn "Unexpected command: $COMMAND (expected: uvx)"
fi

# Check 4: Are the args correct?
ARGS=$(jq -r '.mcpServers."lean-lsp".args[0] // empty' "$CLAUDE_CONFIG")
if [ "$ARGS" != "lean-lsp-mcp" ]; then
    warn "Unexpected args: $ARGS (expected: lean-lsp-mcp)"
fi

# Check 5: Is the project path set?
CONFIGURED_PATH=$(jq -r '.mcpServers."lean-lsp".env.LEAN_PROJECT_PATH // empty' "$CLAUDE_CONFIG")

if [ -z "$CONFIGURED_PATH" ]; then
    fail "LEAN_PROJECT_PATH not set"
    log ""
    log "Run setup-lean-mcp.sh to fix"
    exit 1
fi

log "  Project path: $CONFIGURED_PATH"

# Check 6: Does the project path match expected?
if [ "$CONFIGURED_PATH" != "$EXPECTED_PROJECT_PATH" ]; then
    fail "Project path mismatch"
    log ""
    log "  Configured: $CONFIGURED_PATH"
    log "  Expected:   $EXPECTED_PROJECT_PATH"
    log ""
    log "Run setup-lean-mcp.sh --project '$EXPECTED_PROJECT_PATH' to fix"
    exit 2
fi

# Check 7: Does the project path exist and contain lakefile.lean?
if [ ! -d "$CONFIGURED_PATH" ]; then
    fail "Project path does not exist: $CONFIGURED_PATH"
    exit 1
fi

if [ ! -f "$CONFIGURED_PATH/lakefile.lean" ]; then
    warn "Project path missing lakefile.lean: $CONFIGURED_PATH"
fi

log ""
pass "lean-lsp configured correctly for subagent access"
log ""
log "Note: Restart Claude Code if you recently ran setup-lean-mcp.sh"
exit 0
