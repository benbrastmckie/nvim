#!/usr/bin/env bash
#
# verify-sapience-mcp.sh - Verify the per-project Sapience activation surface for one project:
# extension activation, the per-project MCP registration, the installed user-level files, the
# SessionStart registration, and (when a repo is given and loads the extension) the merged
# settings fragment's permission grants and hooks.
#
# Per-project model (see setup-sapience-mcp.sh's header for the full rationale): each project
# that loads the sapience extension gets its OWN entry under
# `.projects["<abs project path>"].mcpServers.sapience` in ~/.claude.json. This script verifies
# the full per-project activation surface for THAT project (or --project-overridden).
#
# The surviving top-level `~/.claude.json` `.mcpServers.sapience` entry is reported as EXPECTED,
# not drift, for as long as this machine's home-manager activation
# (`modules/home/services/sapience.nix`'s `sapienceMcpServer` block) keeps re-creating it -- the
# inverse of lean's verify-lean-mcp.sh Check 9, which treats a surviving global entry as drift
# to be retired. Do not "fix" this by running --retire-global; that is this extension's own
# writer's job, gated on a companion task this repository does not own.
#
# Usage: ./verify-sapience-mcp.sh [OPTIONS]
#
# Options:
#   --project PATH    Override expected project path (default: auto-detect from CWD/git root)
#   --quiet           Only output pass/fail, no details
#   --help            Show this help message
#
# Checks (each reported by name):
#   (a) .claude-extensions.json shows extensions.sapience.status == "active" for this project
#   (b) .projects[<abs path>].mcpServers.sapience exists in ~/.claude.json and matches the
#       canonical entry (command, args, env.SAPIENCE_HOST, and whether SAPIENCE_TOKEN is present
#       given ~/.sapience/config.json)
#   (c) both installed user-level files exist and are executable
#   (d) the SessionStart entry is present in $HOME/.claude/settings.json (catches a post-switch
#       durability loss)
#   (e) the merged .claude/settings.local.json carries all 11 permission grants and all 5 hooks,
#       when the extension is loaded in this project
#
# Exit codes:
#   0 - Configuration valid (all applicable checks pass)
#   1 - Configuration missing or invalid
#   2 - Project path mismatch (an explicit --project disagrees with the detected project root)

set -uo pipefail

QUIET=false
EXPECTED_PROJECT_PATH=""

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

# Detect project root from .claude-extensions.json at CWD or git root -- kept in lockstep with
# sapience-mcp-register-project.sh's own copy.
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
DETECTED_PROJECT_PATH=""
EXTENSIONS_FILE=""
if [ -f ".claude-extensions.json" ]; then
    DETECTED_PROJECT_PATH="$(pwd)"
    EXTENSIONS_FILE="$(pwd)/.claude-extensions.json"
elif [ -n "$GIT_ROOT" ] && [ -f "$GIT_ROOT/.claude-extensions.json" ]; then
    DETECTED_PROJECT_PATH="$GIT_ROOT"
    EXTENSIONS_FILE="$GIT_ROOT/.claude-extensions.json"
fi

if [ -z "$EXPECTED_PROJECT_PATH" ]; then
    if [ -z "$DETECTED_PROJECT_PATH" ]; then
        echo "Error: could not detect a project root (.claude-extensions.json not found at CWD or git root)."
        echo "Run from a repository root or use --project PATH"
        exit 1
    fi
    EXPECTED_PROJECT_PATH="$DETECTED_PROJECT_PATH"
elif [ -n "$DETECTED_PROJECT_PATH" ] && [ "$EXPECTED_PROJECT_PATH" != "$DETECTED_PROJECT_PATH" ]; then
    fail "Project path mismatch: --project $EXPECTED_PROJECT_PATH disagrees with the detected project root $DETECTED_PROJECT_PATH"
    exit 2
elif [ -z "$DETECTED_PROJECT_PATH" ]; then
    # --project was given explicitly but no .claude-extensions.json is reachable from CWD/git
    # root at all; fall back to checking --project's OWN .claude-extensions.json directly.
    if [ -f "$EXPECTED_PROJECT_PATH/.claude-extensions.json" ]; then
        EXTENSIONS_FILE="$EXPECTED_PROJECT_PATH/.claude-extensions.json"
    fi
fi

CLAUDE_CONFIG="$HOME/.claude.json"
SAPIENCE_CONFIG="$HOME/.sapience/config.json"
DEFAULT_HOST="https://app.spnc.ai"

log "Checking sapience configuration (per-project scope)..."
log ""
log "  Expected project path: $EXPECTED_PROJECT_PATH"

OVERALL_OK=true

# Check (a): extension activation.
if [ -z "$EXTENSIONS_FILE" ] || [ ! -f "$EXTENSIONS_FILE" ]; then
    fail "(a) .claude-extensions.json not found for $EXPECTED_PROJECT_PATH"
    OVERALL_OK=false
    SAPIENCE_ACTIVE=false
else
    SAPIENCE_STATUS="$(jq -r '.extensions.sapience.status // empty' "$EXTENSIONS_FILE" 2>/dev/null || echo "")"
    if [ "$SAPIENCE_STATUS" = "active" ]; then
        pass "(a) sapience extension active for $EXPECTED_PROJECT_PATH"
        SAPIENCE_ACTIVE=true
    else
        fail "(a) sapience extension not active for $EXPECTED_PROJECT_PATH (status: ${SAPIENCE_STATUS:-absent})"
        OVERALL_OK=false
        SAPIENCE_ACTIVE=false
    fi
fi

# Check (b): per-project MCP registration entry.
if [ ! -f "$CLAUDE_CONFIG" ]; then
    fail "(b) $CLAUDE_CONFIG not found"
    OVERALL_OK=false
else
    PROJECT_ENTRY=$(jq -c --arg path "$EXPECTED_PROJECT_PATH" '.projects[$path].mcpServers.sapience // empty' "$CLAUDE_CONFIG" 2>/dev/null || echo "")

    if [ -z "$PROJECT_ENTRY" ] || [ "$PROJECT_ENTRY" = "null" ]; then
        if $SAPIENCE_ACTIVE; then
            fail "(b) no project-scoped sapience entry for $EXPECTED_PROJECT_PATH (extension is active -- expected a registration)"
            OVERALL_OK=false
        else
            log "  (b) no project-scoped sapience entry for $EXPECTED_PROJECT_PATH (extension inactive -- this is correct)"
        fi
    else
        # Recompute the canonical entry the same way the writer would, to compare.
        INHERITED_COMMAND="$(jq -r '.mcpServers.sapience.command // empty' "$CLAUDE_CONFIG" 2>/dev/null || echo "")"
        if [ -n "$INHERITED_COMMAND" ] && [ "$INHERITED_COMMAND" != "null" ]; then
            EXPECTED_COMMAND="$INHERITED_COMMAND"
        else
            EXPECTED_COMMAND="$(command -v python3 2>/dev/null || echo "")"
        fi
        EXPECTED_HOST="$DEFAULT_HOST"
        EXPECTED_HAS_TOKEN=false
        if [ -r "$SAPIENCE_CONFIG" ]; then
            CFG_HOST="$(jq -r '.host // empty' "$SAPIENCE_CONFIG" 2>/dev/null || echo "")"
            [ -n "$CFG_HOST" ] && [ "$CFG_HOST" != "null" ] && EXPECTED_HOST="$CFG_HOST"
            CFG_TOKEN="$(jq -r '.token // empty' "$SAPIENCE_CONFIG" 2>/dev/null || echo "")"
            [ -n "$CFG_TOKEN" ] && [ "$CFG_TOKEN" != "null" ] && EXPECTED_HAS_TOKEN=true
        fi

        ACTUAL_COMMAND=$(jq -r '.command // empty' <<< "$PROJECT_ENTRY")
        ACTUAL_ARGS0=$(jq -r '.args[0] // empty' <<< "$PROJECT_ENTRY")
        ACTUAL_HOST=$(jq -r '.env.SAPIENCE_HOST // empty' <<< "$PROJECT_ENTRY")
        ACTUAL_HAS_TOKEN=$(jq -r '.env | has("SAPIENCE_TOKEN")' <<< "$PROJECT_ENTRY")

        case "$ACTUAL_COMMAND" in
            */.claude/*)
                fail "(b) command resolves inside a .claude/ deploy tree: $ACTUAL_COMMAND"
                OVERALL_OK=false
                ;;
            *)
                MISMATCH=""
                [ "$ACTUAL_COMMAND" = "$EXPECTED_COMMAND" ] || MISMATCH="command (got $ACTUAL_COMMAND, expected $EXPECTED_COMMAND)"
                [ -z "$MISMATCH" ] && { [ "$ACTUAL_ARGS0" = "$HOME/.sapience/mcp.py" ] || MISMATCH="args[0] (got $ACTUAL_ARGS0)"; }
                [ -z "$MISMATCH" ] && { [ "$ACTUAL_HOST" = "$EXPECTED_HOST" ] || MISMATCH="env.SAPIENCE_HOST (got $ACTUAL_HOST, expected $EXPECTED_HOST)"; }
                [ -z "$MISMATCH" ] && { [ "$ACTUAL_HAS_TOKEN" = "$EXPECTED_HAS_TOKEN" ] || MISMATCH="env token presence (got $ACTUAL_HAS_TOKEN, expected $EXPECTED_HAS_TOKEN)"; }

                if [ -z "$MISMATCH" ]; then
                    pass "(b) project-scoped sapience entry for $EXPECTED_PROJECT_PATH matches the canonical shape"
                else
                    fail "(b) project-scoped sapience entry for $EXPECTED_PROJECT_PATH diverges: $MISMATCH"
                    OVERALL_OK=false
                fi
                ;;
        esac
    fi
fi

# Check (c): installed user-level files.
HOOK_DST="$HOME/.claude/hooks/sapience-mcp-register-project.sh"
WRITER_DST="$HOME/.claude/scripts/setup-sapience-mcp.sh"
if [ -x "$HOOK_DST" ] && [ -x "$WRITER_DST" ]; then
    pass "(c) both installed user-level files exist and are executable"
else
    fail "(c) one or both installed user-level files are missing or not executable ($HOOK_DST, $WRITER_DST)"
    log ""
    log "Run install-sapience-mcp-session-hook.sh to install"
    OVERALL_OK=false
fi

# Check (d): SessionStart registration (catches a post-home-manager-switch durability loss).
LIVE_SETTINGS="$HOME/.claude/settings.json"
HOOK_COMMAND="bash \$HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'"
if [ -f "$LIVE_SETTINGS" ] && jq -e --arg cmd "$HOOK_COMMAND" '[.hooks.SessionStart[]?.hooks[]?.command // empty] | any(. == $cmd)' "$LIVE_SETTINGS" > /dev/null 2>&1; then
    pass "(d) SessionStart entry present in $LIVE_SETTINGS"
else
    fail "(d) SessionStart entry missing from $LIVE_SETTINGS"
    log ""
    log "  This is the durability-loss check: 'hooks' is a home-manager ENFORCED key, reset"
    log "  from ~/.dotfiles/config/claude/settings.json on every 'home-manager switch'. Re-run"
    log "  install-sapience-mcp-session-hook.sh to restore the registration."
    OVERALL_OK=false
fi

# Check (e): merged settings.local.json (only when a repo with a deploy is reachable).
MERGED_SETTINGS="$EXPECTED_PROJECT_PATH/.claude/settings.local.json"
if [ -f "$MERGED_SETTINGS" ]; then
    if $SAPIENCE_ACTIVE; then
        GRANT_COUNT=$(jq '[.permissions.allow[]? | select(startswith("mcp__sapience__"))] | length' "$MERGED_SETTINGS" 2>/dev/null || echo 0)
        HOOK_KEYS=$(jq -c '[.hooks | keys[]? | select(. == "SessionStart" or . == "UserPromptSubmit" or . == "PreToolUse" or . == "SessionEnd" or . == "Stop")] | sort' "$MERGED_SETTINGS" 2>/dev/null || echo "[]")
        EXPECTED_HOOK_KEYS='["PreToolUse","SessionEnd","SessionStart","Stop","UserPromptSubmit"]'
        if [ "$GRANT_COUNT" -eq 11 ] && [ "$HOOK_KEYS" = "$EXPECTED_HOOK_KEYS" ]; then
            pass "(e) merged $MERGED_SETTINGS carries all 11 permission grants and all 5 hooks"
        else
            fail "(e) merged $MERGED_SETTINGS has $GRANT_COUNT/11 sapience grants and hook keys $HOOK_KEYS (expected $EXPECTED_HOOK_KEYS)"
            OVERALL_OK=false
        fi
    else
        log "  (e) sapience extension not active; skipping merged-settings grant/hook check"
    fi
else
    log "  (e) $MERGED_SETTINGS not found; skipping merged-settings grant/hook check (no deploy in this tree)"
fi

# Note: the surviving top-level ~/.claude.json .mcpServers.sapience entry is EXPECTED, not
# drift, until the companion task disables programs.sapience.registerMcpServer. Say so
# explicitly so a reader is not sent to remove it.
if [ -f "$CLAUDE_CONFIG" ] && jq -e '.mcpServers.sapience' "$CLAUDE_CONFIG" > /dev/null 2>&1; then
    log ""
    log "  NOTE: a top-level .mcpServers.sapience entry also survives in $CLAUDE_CONFIG. This is"
    log "  EXPECTED, not drift, until a companion task disables this machine's home-manager"
    log "  sapienceMcpServer activation -- do not run --retire-global to 'fix' this."
fi

log ""
if $OVERALL_OK; then
    pass "sapience per-project activation surface verified for $EXPECTED_PROJECT_PATH"
    exit 0
else
    fail "one or more sapience activation surface checks failed for $EXPECTED_PROJECT_PATH"
    exit 1
fi
