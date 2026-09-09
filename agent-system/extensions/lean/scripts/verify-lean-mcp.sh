#!/usr/bin/env bash
#
# verify-lean-mcp.sh - Verify per-project lean-lsp MCP server configuration
#
# Per-project model (see setup-lean-mcp.sh's header for the full rationale): each Lean project
# gets its OWN entry under `.projects["<abs project path>"].mcpServers."lean-lsp"` in
# ~/.claude.json. This script verifies THAT entry for the current (or --project-overridden)
# project. Under this model, the project-scoped entry's ABSENCE or staleness is the drift -- not
# its presence, which was the previous (single-global-entry) model's Check 9. A SURVIVING
# top-level global `.mcpServers."lean-lsp"` entry is now itself drift too (Check 9, inverted):
# it can silently answer lean-lsp tool calls for whichever project it names, for ANY session that
# has not yet been given its own project-scoped entry, which is exactly the wrong-project-answers
# defect this per-project model exists to remove.
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
# detection must stay in lockstep with setup-lean-mcp.sh's and
# lean-lsp-register-project.sh's so all three never disagree about which directories are Lean
# projects.
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
log "Checking lean-lsp configuration (per-project scope)..."
log ""

if [ ! -f "$CLAUDE_CONFIG" ]; then
    fail "~/.claude.json not found"
    log ""
    log "Run setup-lean-mcp.sh (project scope) to configure"
    exit 1
fi

log "  Config file: $CLAUDE_CONFIG"
log "  Expected project path: $EXPECTED_PROJECT_PATH"

# Check 2: Is a project-scoped entry present for this project? Under the per-project model an
# ABSENT entry is the drift -- there is no fallback to a global entry to check instead.
PROJECT_ENTRY=$(jq -c --arg path "$EXPECTED_PROJECT_PATH" '.projects[$path].mcpServers."lean-lsp" // empty' "$CLAUDE_CONFIG" 2>/dev/null || echo "")

if [ -z "$PROJECT_ENTRY" ] || [ "$PROJECT_ENTRY" = "null" ]; then
    fail "No project-scoped lean-lsp entry for $EXPECTED_PROJECT_PATH"
    log ""
    log "  .projects[\"$EXPECTED_PROJECT_PATH\"].mcpServers.\"lean-lsp\" does not exist. Under"
    log "  the per-project model this project has no lean-lsp registration at all (there is no"
    log "  global fallback to fall back to -- see mcp-server-ownership.md)."
    log ""
    log "Run setup-lean-mcp.sh --scope project --project '$EXPECTED_PROJECT_PATH' to configure"
    exit 1
fi

log "  lean-lsp (project scope): configured"

# Check 3: Command path must never resolve inside a repository's own .claude/ deploy tree.
# This is the check that would have caught the registration defect this script exists to
# prevent by SHAPE (a wrapper script living inside a disposable, wholesale-regenerated
# deploy tree) rather than by the incidental absence of an env var. See
# mcp-server-ownership.md's durable invariant and rules/source-store-deploy-boundary.md.
COMMAND=$(printf '%s' "$PROJECT_ENTRY" | jq -r '.command // empty')
case "$COMMAND" in
    */.claude/*)
        fail "Command resolves inside a .claude/ deploy tree: $COMMAND"
        log ""
        log "  .claude/ is disposable and regenerated wholesale; a command path must point"
        log "  at a stable location outside any repository's .claude/ directory."
        log ""
        log "Run setup-lean-mcp.sh --scope project to fix"
        exit 1
        ;;
esac

# Check 4: Is the command correct? A wrong command cannot spawn the server at all -- this is
# a hard failure, not a warning (a command that cannot spawn breaks the feature outright).
if [ "$COMMAND" != "uvx" ]; then
    fail "Unexpected command: $COMMAND (expected: uvx) -- this command cannot spawn the sanctioned server"
    log ""
    log "Run setup-lean-mcp.sh --scope project to fix"
    exit 1
fi

# Check 5: Are the args correct? Same rationale as Check 4 -- wrong args cannot spawn the
# sanctioned server.
ARGS=$(printf '%s' "$PROJECT_ENTRY" | jq -r '.args[0] // empty')
if [ "$ARGS" != "lean-lsp-mcp" ]; then
    fail "Unexpected args: $ARGS (expected: lean-lsp-mcp) -- this command cannot spawn the sanctioned server"
    log ""
    log "Run setup-lean-mcp.sh --scope project to fix"
    exit 1
fi

# Check 6: Is the project path set?
CONFIGURED_PATH=$(printf '%s' "$PROJECT_ENTRY" | jq -r '.env.LEAN_PROJECT_PATH // empty')

if [ -z "$CONFIGURED_PATH" ]; then
    fail "LEAN_PROJECT_PATH not set"
    log ""
    log "Run setup-lean-mcp.sh --scope project to fix"
    exit 1
fi

log "  Project path: $CONFIGURED_PATH"

# Check 7: Does the project path match expected? Since the entry is looked up BY expected path
# (.projects[$EXPECTED_PROJECT_PATH]), a mismatch here can only happen if the entry's OWN
# env.LEAN_PROJECT_PATH was hand-edited to a different value than the key it is filed under --
# still worth catching, since that inner value (not the outer key) is what the spawned server
# actually uses.
if [ "$CONFIGURED_PATH" != "$EXPECTED_PROJECT_PATH" ]; then
    fail "Project path mismatch"
    log ""
    log "  Configured: $CONFIGURED_PATH"
    log "  Expected:   $EXPECTED_PROJECT_PATH"
    log ""
    log "Run setup-lean-mcp.sh --scope project --project '$EXPECTED_PROJECT_PATH' to fix"
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

# Check 9 (inverted): does a top-level global lean-lsp entry survive? Under the per-project
# model the global entry is RETIRED (D2) -- keeping it around means any session in a project
# that has NOT yet been given its own project-scoped entry silently gets the global entry's
# answer instead of no answer at all, which is exactly the wrong-project-answers defect this
# model exists to remove. A correct project-scoped entry (checks 2-8, already passed at this
# point) does NOT make a surviving global entry harmless: it is still drift, and still reported.
GLOBAL_ENTRY=$(jq -c '.mcpServers."lean-lsp" // empty' "$CLAUDE_CONFIG" 2>/dev/null || echo "")
if [ -n "$GLOBAL_ENTRY" ] && [ "$GLOBAL_ENTRY" != "null" ]; then
    fail "A top-level global lean-lsp entry survives alongside this project's correct entry"
    log ""
    log "  .mcpServers.\"lean-lsp\" still exists: $GLOBAL_ENTRY"
    log "  Under the per-project model this entry is retired -- any project without its own"
    log "  project-scoped entry would silently get THIS entry's answer instead of no answer,"
    log "  which is the wrong-project-indexing defect this model exists to prevent."
    log ""
    log "Run setup-lean-mcp.sh --retire-global to remove it"
    exit 1
fi

log ""
pass "lean-lsp configured correctly for subagent access (project scope)"
log ""
log "Note: Restart Claude Code if you recently ran setup-lean-mcp.sh (session-start snapshot trap)"
exit 0
