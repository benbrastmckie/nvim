#!/usr/bin/env bash
#
# install-lean-lsp-session-hook.sh - Idempotently install the per-project lean-lsp SessionStart
# hook at user level, so registration is automatic in EVERY session (including a fresh git
# worktree with no repository .claude/ deploy at all).
#
# This is a two-file install, both to STABLE user-level paths (never inside any repository's
# own, disposable .claude/ tree -- see mcp-server-ownership.md's .claude/-path boundary
# invariant, which this script's own targets must never violate):
#
#   1. The hook itself      -> $HOME/.claude/hooks/lean-lsp-register-project.sh
#   2. The writer it calls  -> $HOME/.claude/scripts/setup-lean-mcp.sh
#
# (2) exists because the hook must work in a directory with no repository .claude/ deploy at
# all (the exact acceptance scenario this task is built around), so it cannot resolve the writer
# relative to CWD's own .claude/scripts/ -- it needs its own stable copy, installed here.
#
# The hooks.SessionStart registration itself is written to TWO places, per this task's D4:
#   - $HOME/.dotfiles/config/claude/settings.json  -- the durable source (survives a
#     home-manager rebuild, which resets $HOME/.claude/settings.json's `hooks` key from exactly
#     this file -- see ~/.dotfiles/modules/home/core/dotfiles.nix's activation.claudeSettings).
#   - $HOME/.claude/settings.json  -- the live file, mirrored for immediate effect without
#     requiring a rebuild first.
# Missing dotfiles source is a WARNING, never a hard failure (the live-file mirror alone still
# gives immediate effect; only durability across the next rebuild is lost).
#
# Idempotent: running this twice in a row makes no further change the second time (checked by
# looking for this hook's own command string already present in .hooks.SessionStart).
#
# Usage: ./install-lean-lsp-session-hook.sh [OPTIONS]
#
# Options:
#   --dry-run   Show what would change without writing anything
#   --remove    Uninstall: remove the SessionStart entry from both settings files and delete
#               the two installed files
#   --help      Show this help message

set -euo pipefail

DRY_RUN=false
REMOVE=false

while [[ $# -gt 0 ]]; do
    case $1 in
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SRC="$SCRIPT_DIR/../hooks/lean-lsp-register-project.sh"
WRITER_SRC="$SCRIPT_DIR/setup-lean-mcp.sh"

HOOK_DST="$HOME/.claude/hooks/lean-lsp-register-project.sh"
WRITER_DST="$HOME/.claude/scripts/setup-lean-mcp.sh"

LIVE_SETTINGS="$HOME/.claude/settings.json"
DOTFILES_SETTINGS="$HOME/.dotfiles/config/claude/settings.json"

# The exact command string this installer registers/looks for, byte-for-byte. Idempotency and
# --remove both key off this string, so it must never change casually -- a change here silently
# stops recognizing a previously-installed entry as "already present" and would double-register.
HOOK_COMMAND="bash \$HOME/.claude/hooks/lean-lsp-register-project.sh 2>/dev/null || echo '{}'"

# merge_session_start_entry FILE -- idempotently add the SessionStart hook entry to FILE's
# .hooks.SessionStart array (creating .hooks and .hooks.SessionStart if absent), unless an
# entry with this exact command already exists. No-op (prints and returns) if FILE is absent.
merge_session_start_entry() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "  (skip) $file does not exist"
        return 0
    fi

    local already
    already=$(jq --arg cmd "$HOOK_COMMAND" \
        '[.hooks.SessionStart[]?.hooks[]?.command // empty] | any(. == $cmd)' \
        "$file" 2>/dev/null || echo "false")

    if [ "$already" = "true" ]; then
        echo "  (no-op) $file already has the lean-lsp SessionStart hook"
        return 0
    fi

    if $DRY_RUN; then
        echo "  [DRY RUN] Would add SessionStart(matcher=startup) hook entry to $file"
        return 0
    fi

    local tmp
    tmp=$(mktemp "${file}.tmp.XXXXXXXXXX")
    jq --arg cmd "$HOOK_COMMAND" \
        '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{"matcher": "startup", "hooks": [{"type": "command", "command": $cmd}]}])' \
        "$file" > "$tmp"
    mv "$tmp" "$file"
    echo "  Added SessionStart(matcher=startup) hook entry to $file"
}

# remove_session_start_entry FILE -- remove every SessionStart array entry whose hooks[].command
# matches our exact command string. No-op if FILE is absent or has no such entry.
remove_session_start_entry() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "  (skip) $file does not exist"
        return 0
    fi

    local has_entry
    has_entry=$(jq --arg cmd "$HOOK_COMMAND" \
        '[.hooks.SessionStart[]?.hooks[]?.command // empty] | any(. == $cmd)' \
        "$file" 2>/dev/null || echo "false")

    if [ "$has_entry" != "true" ]; then
        echo "  (no-op) $file has no lean-lsp SessionStart hook to remove"
        return 0
    fi

    if $DRY_RUN; then
        echo "  [DRY RUN] Would remove the SessionStart hook entry from $file"
        return 0
    fi

    local tmp
    tmp=$(mktemp "${file}.tmp.XXXXXXXXXX")
    jq --arg cmd "$HOOK_COMMAND" \
        '.hooks.SessionStart = [.hooks.SessionStart[]? | select(([.hooks[]?.command // empty] | any(. == $cmd)) | not)]' \
        "$file" > "$tmp"
    mv "$tmp" "$file"
    echo "  Removed the SessionStart hook entry from $file"
}

if $REMOVE; then
    echo "Removing the lean-lsp SessionStart hook registration..."
    echo "Live settings ($LIVE_SETTINGS):"
    remove_session_start_entry "$LIVE_SETTINGS"
    echo "Dotfiles source ($DOTFILES_SETTINGS):"
    remove_session_start_entry "$DOTFILES_SETTINGS"

    if $DRY_RUN; then
        echo "[DRY RUN] Would remove $HOOK_DST and $WRITER_DST"
        exit 0
    fi

    rm -f "$HOOK_DST" "$WRITER_DST"
    echo "Removed $HOOK_DST and $WRITER_DST (if present)."
    exit 0
fi

echo "Installing the lean-lsp SessionStart hook..."

if $DRY_RUN; then
    echo "[DRY RUN] Would copy $HOOK_SRC -> $HOOK_DST"
    echo "[DRY RUN] Would copy $WRITER_SRC -> $WRITER_DST"
else
    mkdir -p "$(dirname "$HOOK_DST")" "$(dirname "$WRITER_DST")"
    cp "$HOOK_SRC" "$HOOK_DST"
    chmod +x "$HOOK_DST"
    cp "$WRITER_SRC" "$WRITER_DST"
    chmod +x "$WRITER_DST"
    echo "  Copied hook to $HOOK_DST"
    echo "  Copied writer to $WRITER_DST"
fi

echo "Live settings ($LIVE_SETTINGS):"
merge_session_start_entry "$LIVE_SETTINGS"

echo "Dotfiles source ($DOTFILES_SETTINGS):"
if [ ! -f "$DOTFILES_SETTINGS" ]; then
    echo "  WARNING: $DOTFILES_SETTINGS not found -- the live-file mirror above still gives"
    echo "  immediate effect, but this hook will NOT survive the next 'home-manager switch'"
    echo "  (which resets \$HOME/.claude/settings.json's hooks key from that file). Add the"
    echo "  entry there manually, or re-run this installer once that file exists."
else
    merge_session_start_entry "$DOTFILES_SETTINGS"
fi

echo ""
echo "Done. lean-lsp will now be registered automatically, per-project, at the start of every"
echo "session started inside a Lean project directory."
