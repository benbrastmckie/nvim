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

# Detect expected project path if not provided. Lean 4 projects use lakefile.lean; some
# (e.g. cslib) use lakefile.toml instead -- both are valid Lake project markers, and this
# detection must stay in lockstep with setup-lean-mcp.sh's so the two standalone operator
# scripts never disagree about which directories are Lean projects.
if [ -z "$EXPECTED_PROJECT_PATH" ]; then
    GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    if [ -f "lakefile.lean" ] || [ -f "lakefile.toml" ]; then
        EXPECTED_PROJECT_PATH="$(pwd)"
    elif [ -n "$GIT_ROOT" ] && { [ -f "$GIT_ROOT/lakefile.lean" ] || [ -f "$GIT_ROOT/lakefile.toml" ]; }; then
        EXPECTED_PROJECT_PATH="$GIT_ROOT"
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

# Check 3: Command path must never resolve inside a repository's own .claude/ deploy tree.
# This is the check that would have caught the registration defect this script exists to
# prevent by SHAPE (a wrapper script living inside a disposable, wholesale-regenerated
# deploy tree) rather than by the incidental absence of an env var. See
# mcp-server-ownership.md's durable invariant and rules/source-store-deploy-boundary.md.
COMMAND=$(jq -r '.mcpServers."lean-lsp".command // empty' "$CLAUDE_CONFIG")
case "$COMMAND" in
    */.claude/*)
        fail "Command resolves inside a .claude/ deploy tree: $COMMAND"
        log ""
        log "  .claude/ is disposable and regenerated wholesale; a command path must point"
        log "  at a stable location outside any repository's .claude/ directory."
        log ""
        log "Run setup-lean-mcp.sh to fix"
        exit 1
        ;;
esac

# Check 4: Is the command correct? A wrong command cannot spawn the server at all -- this is
# a hard failure, not a warning (a command that cannot spawn breaks the feature outright).
if [ "$COMMAND" != "uvx" ]; then
    fail "Unexpected command: $COMMAND (expected: uvx) -- this command cannot spawn the sanctioned server"
    log ""
    log "Run setup-lean-mcp.sh to fix"
    exit 1
fi

# Check 5: Are the args correct? Same rationale as Check 4 -- wrong args cannot spawn the
# sanctioned server.
ARGS=$(jq -r '.mcpServers."lean-lsp".args[0] // empty' "$CLAUDE_CONFIG")
if [ "$ARGS" != "lean-lsp-mcp" ]; then
    fail "Unexpected args: $ARGS (expected: lean-lsp-mcp) -- this command cannot spawn the sanctioned server"
    log ""
    log "Run setup-lean-mcp.sh to fix"
    exit 1
fi

# Check 6: Is the project path set?
CONFIGURED_PATH=$(jq -r '.mcpServers."lean-lsp".env.LEAN_PROJECT_PATH // empty' "$CLAUDE_CONFIG")

if [ -z "$CONFIGURED_PATH" ]; then
    fail "LEAN_PROJECT_PATH not set"
    log ""
    log "Run setup-lean-mcp.sh to fix"
    exit 1
fi

log "  Project path: $CONFIGURED_PATH"

# Check 7: Does the project path match expected?
if [ "$CONFIGURED_PATH" != "$EXPECTED_PROJECT_PATH" ]; then
    fail "Project path mismatch"
    log ""
    log "  Configured: $CONFIGURED_PATH"
    log "  Expected:   $EXPECTED_PROJECT_PATH"
    log ""
    log "Run setup-lean-mcp.sh --project '$EXPECTED_PROJECT_PATH' to fix"
    exit 2
fi

# Check 8: Does the project path exist and contain a Lake project marker (lakefile.lean or
# lakefile.toml)?
if [ ! -d "$CONFIGURED_PATH" ]; then
    fail "Project path does not exist: $CONFIGURED_PATH"
    exit 1
fi

if [ ! -f "$CONFIGURED_PATH/lakefile.lean" ] && [ ! -f "$CONFIGURED_PATH/lakefile.toml" ]; then
    warn "Project path missing lakefile.lean/lakefile.toml: $CONFIGURED_PATH"
fi

# Check 9: Does a project-scoped entry shadow the global entry this script just verified?
# ~/.claude.json's per-project .projects[<path>].mcpServers takes precedence over the
# top-level global mcpServers for that project, so a local override silently makes every
# check above irrelevant to what actually spawns there. Under the single-global-entry model
# (Option A) any such override is treated as drift, not a legitimate second mechanism.
SHADOW_ENTRY=$(jq -c --arg path "$EXPECTED_PROJECT_PATH" '.projects[$path].mcpServers."lean-lsp" // empty' "$CLAUDE_CONFIG" 2>/dev/null || echo "")
if [ -n "$SHADOW_ENTRY" ] && [ "$SHADOW_ENTRY" != "null" ]; then
    fail "Project-scoped lean-lsp entry shadows the global entry for $EXPECTED_PROJECT_PATH"
    log ""
    log "  .projects[\"$EXPECTED_PROJECT_PATH\"].mcpServers.\"lean-lsp\" exists and takes"
    log "  precedence over the global entry this script just verified -- the global checks"
    log "  above do not describe what actually spawns in this project."
    log "  Shadow entry: $SHADOW_ENTRY"
    log ""
    log "Under the single global-entry model, remove the project-scoped override:"
    log "  jq 'del(.projects[\"$EXPECTED_PROJECT_PATH\"].mcpServers.\"lean-lsp\")' -- see"
    log "  mcp-server-ownership.md for the recorded invariant."
    exit 1
fi

log ""
pass "lean-lsp configured correctly for subagent access"
log ""
log "Note: Restart Claude Code if you recently ran setup-lean-mcp.sh"
exit 0
