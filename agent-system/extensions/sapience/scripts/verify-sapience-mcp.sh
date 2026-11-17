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
# No top-level `~/.claude.json` `.mcpServers.sapience` entry exists on this machine: the former
# machine-wide home-manager activation (`modules/home/services/sapience.nix`'s
# `sapienceMcpServer` block and its `registerMcpServer` option) has been retired, and
# registration is per-project only (see setup-sapience-mcp.sh's header for the full per-project
# model). `--retire-global` therefore has nothing to retire here; a leftover top-level entry, if
# one is ever found, is a stale residual rather than an expected machine-wide registration -- see
# the trailing conditional NOTE below.
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
#   (e) the merged .claude/settings.local.json carries all 7 permission grants and all 5 hooks,
#       when the extension is loaded in this project. manager.load's forced-reload branch
#       retracts a narrowed grant on a `deploy-headless.sh` resync, so a count above 7 here is
#       real drift -- re-run `deploy-headless.sh` against this repository to converge it.
#   (f) when CWD is a linked git worktree, asserts the worktree itself carries NO
#       mcp__sapience__* permission grant and none of the five sapience hook keys -- the
#       hook/permission-grant channel is deliberately absent from a worktree even though MCP
#       retrieval (checks a/b above) is resolved to the parent checkout. Logs a skip line, never
#       a pass or a fail, when CWD is not a linked worktree.
#   (g) $HOME/.claude/settings.json carries no machine-wide vendor sapience hook (a
#       SessionStart/SessionEnd/Stop command naming ~/.sapience/mcp.py or sapience_cli.py),
#       re-added by ~/.sapience/sapience_upkeep.py's wire_hooks() on every auto_update/update
#       --wire pass unless config.json's "hooks" opt-out holds. Reports that opt-out value
#       (false/true/absent) unconditionally, pass or fail.
#
# The project root detected above (and used for checks a/b) is the PARENT CHECKOUT for a linked
# worktree, never the worktree itself -- see the marker-delimited resolution block below.
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

# === BEGIN sapience-worktree-checkout-resolution (byte-identical in every copy: this hook,
# verify-sapience-mcp.sh, sapience-retrieve.sh, sapience-remember.sh, and
# verify-sapience-context-scoping.sh -- test-sapience-mcp-registration.sh's lockstep case
# extracts this marker-delimited block from each copy and asserts they are all byte-identical).
# Resolves a directory (default: cwd) to its git toplevel, following a linked worktree to its
# PARENT CHECKOUT rather than the worktree itself. Echoes the toplevel path and returns 0, or
# returns 1 with no output when the directory is not inside a git repository at all.
#
# Detection: compare `git rev-parse --git-dir` against `--git-common-dir`. Equal (including
# both failing, on a non-git path) means "not a linked worktree -- behave exactly like a bare
# `git rev-parse --show-toplevel`". Unequal means "linked worktree -- the common dir's PARENT
# directory is the checkout". `--git-common-dir` returns a relative path at a checkout root but
# an absolute path from inside a worktree, so it is absolutized before its parent is taken.
resolve_checkout_toplevel() {
    local dir="${1:-.}" git_dir common_dir
    git_dir="$(git -C "$dir" rev-parse --git-dir 2>/dev/null)" || return 1
    common_dir="$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null)" || return 1
    if [ "$git_dir" = "$common_dir" ]; then
        git -C "$dir" rev-parse --show-toplevel 2>/dev/null
        return $?
    fi
    case "$common_dir" in
        /*) : ;;
        *) common_dir="$(cd "$dir" 2>/dev/null && pwd)/$common_dir" ;;
    esac
    (cd "$common_dir/.." 2>/dev/null && pwd)
}
# === END sapience-worktree-checkout-resolution ===

# Detect project root from .claude-extensions.json at CWD or git root -- the git root resolved
# below is the PARENT CHECKOUT for a linked worktree (never the worktree itself). Kept in
# lockstep with sapience-mcp-register-project.sh's own copy (see the marker block above).
GIT_ROOT="$(resolve_checkout_toplevel 2>/dev/null || true)"
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
    log "  'hooks' remains a home-manager ENFORCED key, but the registration command is now"
    log "  carried as a durable entry in ~/.dotfiles/config/claude/settings.json, so a"
    log "  'home-manager switch' restores rather than removes it. A missing entry here most"
    log "  likely means install-sapience-mcp-session-hook.sh has not yet been run on this"
    log "  machine, or the dotfiles entry has not yet been applied. Re-run"
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
        if [ "$GRANT_COUNT" -eq 7 ] && [ "$HOOK_KEYS" = "$EXPECTED_HOOK_KEYS" ]; then
            pass "(e) merged $MERGED_SETTINGS carries all 7 permission grants and all 5 hooks"
        else
            fail "(e) merged $MERGED_SETTINGS has $GRANT_COUNT/7 sapience grants and hook keys $HOOK_KEYS (expected $EXPECTED_HOOK_KEYS)"
            log ""
            log "  NOTE: a grant count above 7 is real drift, not an expected residual -- run"
            log "  deploy-headless.sh against this repository: manager.load's forced-reload"
            log "  branch retracts a narrowed grant (and sweeps any leftover mcp__sapience__*"
            log "  write-tool entry) on an ordinary resync."
            OVERALL_OK=false
        fi
    else
        log "  (e) sapience extension not active; skipping merged-settings grant/hook check"
    fi
else
    log "  (e) $MERGED_SETTINGS not found; skipping merged-settings grant/hook check (no deploy in this tree)"
fi

# Check (f): a linked worktree must carry no sapience hooks or permission grants, even though
# MCP retrieval (checks a/b) is resolved to the parent checkout. Recomputes the git-dir /
# git-common-dir comparison directly (rather than reusing GIT_ROOT, which already followed the
# worktree to its checkout) so this check is keyed on CWD's own worktree-ness.
WT_GIT_DIR="$(git rev-parse --git-dir 2>/dev/null || true)"
WT_COMMON_DIR="$(git rev-parse --git-common-dir 2>/dev/null || true)"
if [ -n "$WT_GIT_DIR" ] && [ -n "$WT_COMMON_DIR" ] && [ "$WT_GIT_DIR" != "$WT_COMMON_DIR" ]; then
    WT_SETTINGS="$(pwd)/.claude/settings.local.json"
    if [ -f "$WT_SETTINGS" ]; then
        WT_GRANT_COUNT=$(jq '[.permissions.allow[]? | select(startswith("mcp__sapience__"))] | length' "$WT_SETTINGS" 2>/dev/null || echo 0)
        WT_HOOK_COUNT=$(jq '[.hooks | keys[]? | select(. == "SessionStart" or . == "UserPromptSubmit" or . == "PreToolUse" or . == "SessionEnd" or . == "Stop")] | length' "$WT_SETTINGS" 2>/dev/null || echo 0)
        if [ "$WT_GRANT_COUNT" -eq 0 ] && [ "$WT_HOOK_COUNT" -eq 0 ]; then
            pass "(f) linked worktree carries no sapience permission grants or hooks"
        else
            fail "(f) linked worktree's $WT_SETTINGS carries $WT_GRANT_COUNT sapience grant(s) and $WT_HOOK_COUNT sapience hook key(s) -- the hook/grant channel must stay absent from a worktree"
            OVERALL_OK=false
        fi
    else
        pass "(f) linked worktree carries no .claude/settings.local.json at all (no sapience grants or hooks possible)"
    fi
else
    log "  (f) CWD is not a linked worktree; skipping worktree hook/grant-absence check"
fi

# Check (g): machine-wide vendor hook recurrence detector. Mirrors
# ~/.sapience/sapience_upkeep.py's hooks_opted_out() (env SAPIENCE_NO_HOOKS == "1", else
# config.json's "hooks" is false) and wire_hooks()'s three REQUIRED additions (SessionStart
# --briefing-text, SessionEnd --receipt, Stop --effect-line). wire_hooks() re-adds these three
# hooks to $HOME/.claude/settings.json on every auto_update/update --wire pass unless the
# opt-out holds -- hand-removing the entries alone does not prevent recurrence; only the
# opt-out flag does. If a newer sapience_upkeep.py changes the REQUIRED set or the script
# basenames, this local mirror will not see it until updated to match.
VENDOR_HOOK_MATCHES=""
if [ -f "$LIVE_SETTINGS" ]; then
    for VENDOR_HOOK_KEY in SessionStart SessionEnd Stop; do
        while IFS= read -r VENDOR_HOOK_CMD; do
            [ -z "$VENDOR_HOOK_CMD" ] && continue
            case "$VENDOR_HOOK_CMD" in
                *.sapience/mcp.py*|*.sapience/sapience_cli.py*)
                    VENDOR_HOOK_MATCHES="${VENDOR_HOOK_MATCHES}${VENDOR_HOOK_KEY}: ${VENDOR_HOOK_CMD}"$'\n'
                    ;;
            esac
        done < <(jq -r --arg key "$VENDOR_HOOK_KEY" '[.hooks[$key][]?.hooks[]?.command // empty] | .[]' "$LIVE_SETTINGS" 2>/dev/null)
    done
fi

if [ -n "$VENDOR_HOOK_MATCHES" ]; then
    fail "(g) $LIVE_SETTINGS carries a machine-wide vendor sapience hook"
    log ""
    while IFS= read -r VENDOR_HOOK_MATCH_LINE; do
        [ -z "$VENDOR_HOOK_MATCH_LINE" ] && continue
        log "    $VENDOR_HOOK_MATCH_LINE"
    done <<< "$VENDOR_HOOK_MATCHES"
    log ""
    log "  Hand-removing these entries alone does not prevent recurrence: wire_hooks() re-adds"
    log "  them on every auto_update/update --wire pass unless the opt-out holds. Remedy: set"
    log "  ~/.sapience/config.json's \"hooks\" to false, or export SAPIENCE_NO_HOOKS=1."
    OVERALL_OK=false
else
    pass "(g) no machine-wide vendor sapience hook in $LIVE_SETTINGS"
fi

# Unconditionally report the vendor opt-out value, pass or fail -- a clean (g) could otherwise
# mean either "opted out" or "never wired", and this line disambiguates.
if [ -r "$SAPIENCE_CONFIG" ]; then
    HOOKS_OPT_VALUE="$(jq -r 'if has("hooks") then (.hooks | tostring) else "absent" end' "$SAPIENCE_CONFIG" 2>/dev/null || echo "absent")"
else
    HOOKS_OPT_VALUE="absent"
fi
log "  (g) ~/.sapience/config.json hooks opt-out value: ${HOOKS_OPT_VALUE}"

# Note: this machine's home-manager activation no longer creates a top-level
# ~/.claude.json .mcpServers.sapience entry (modules/home/services/sapience.nix's
# sapienceMcpServer block and its registerMcpServer option have been retired). If one is still
# present here, it is a stale leftover from before that retirement, not an expected machine-wide
# registration.
if [ -f "$CLAUDE_CONFIG" ] && jq -e '.mcpServers.sapience' "$CLAUDE_CONFIG" > /dev/null 2>&1; then
    log ""
    log "  NOTE: a top-level .mcpServers.sapience entry also survives in $CLAUDE_CONFIG. This is"
    log "  a stale leftover from before this machine's home-manager sapienceMcpServer activation"
    log "  was retired -- consider running --retire-global to remove it, or re-applying the"
    log "  current home-manager generation."
fi

log ""
if $OVERALL_OK; then
    pass "sapience per-project activation surface verified for $EXPECTED_PROJECT_PATH"
    exit 0
else
    fail "one or more sapience activation surface checks failed for $EXPECTED_PROJECT_PATH"
    exit 1
fi
