#!/usr/bin/env bash
#
# install-sapience-mcp-session-hook.sh - Idempotently install the per-project sapience
# SessionStart hook at user level, so registration/removal is automatic in EVERY session
# (including a fresh git worktree with no repository .claude/ deploy at all).
#
# This is a two-file install, both to STABLE user-level paths (never inside any repository's
# own, disposable .claude/ tree -- see mcp-server-ownership.md's .claude/-path boundary
# invariant, which this script's own targets must never violate):
#
#   1. The hook itself      -> $HOME/.claude/hooks/sapience-mcp-register-project.sh
#   2. The writer it calls  -> $HOME/.claude/scripts/setup-sapience-mcp.sh
#
# (2) exists because the hook must work in a directory with no repository .claude/ deploy at
# all, so it cannot resolve the writer relative to CWD's own .claude/scripts/ -- it needs its
# own stable copy, installed here.
#
# The hooks.SessionStart registration is written by TWO independent writers that converge on the
# identical command string, in the same home-manager ENFORCED `hooks` key
# (`~/.dotfiles/modules/home/core/dotfiles.nix`'s `[_NOTE,env,hooks,model,permissions,statusLine]`
# set):
#
#   1. This installer -- writes $HOME/.claude/settings.json directly. This is the only write
#      target this script itself ever touches: it is forbidden to touch any `.dotfiles` file, so
#      it narrowly diverges from the lean model (install-lean-lsp-session-hook.sh), whose own
#      installer writes BOTH `$HOME/.claude/settings.json` and
#      `$HOME/.dotfiles/config/claude/settings.json` itself. Do not "repair" this script to add a
#      second write target of its own -- writer 2 below already covers that role, from the other
#      repository.
#   2. A companion-owned, durable `SessionStart` entry in
#      `$HOME/.dotfiles/config/claude/settings.json`, written by that other repository's own
#      home-manager activation and merged into the enforced `hooks` key on every
#      `home-manager switch`. This is what makes the registration durable across a switch.
#
# Because both writers emit the byte-identical command string below, running this installer
# after a switch that already placed the entry (via writer 2) is a documented no-op, never a
# double registration -- the idempotency check below (looking for this hook's own command string
# already present in .hooks.SessionStart) is exactly what verifies that.
#
# Idempotent: running this twice in a row makes no further change the second time (checked by
# looking for this hook's own command string already present in .hooks.SessionStart).
#
# Usage: ./install-sapience-mcp-session-hook.sh [OPTIONS]
#
# Options:
#   --dry-run   Show what would change without writing anything
#   --remove    Uninstall: remove the SessionStart entry from the live settings file, delete the
#               two installed files, and remove this project's own
#               .projects[...].mcpServers.sapience entry via the writer's --remove (so the
#               immediate case does not wait for the next session start)
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
HOOK_SRC="$SCRIPT_DIR/../hooks/sapience-mcp-register-project.sh"
WRITER_SRC="$SCRIPT_DIR/setup-sapience-mcp.sh"

HOOK_DST="$HOME/.claude/hooks/sapience-mcp-register-project.sh"
WRITER_DST="$HOME/.claude/scripts/setup-sapience-mcp.sh"

LIVE_SETTINGS="$HOME/.claude/settings.json"

# The exact command string this installer registers/looks for, byte-for-byte. Idempotency and
# --remove both key off this string, so it must never change casually -- a change here silently
# stops recognizing a previously-installed entry as "already present" and would double-register.
HOOK_COMMAND="bash \$HOME/.claude/hooks/sapience-mcp-register-project.sh 2>/dev/null || echo '{}'"

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
        echo "  (no-op) $file already has the sapience SessionStart hook"
        return 0
    fi

    if $DRY_RUN; then
        echo "  [DRY RUN] Would add SessionStart hook entry to $file"
        return 0
    fi

    local tmp
    tmp=$(mktemp "${file}.tmp.XXXXXXXXXX")
    jq --arg cmd "$HOOK_COMMAND" \
        '.hooks.SessionStart = ((.hooks.SessionStart // []) + [{"hooks": [{"type": "command", "command": $cmd}]}])' \
        "$file" > "$tmp"
    mv "$tmp" "$file"
    echo "  Added SessionStart hook entry to $file"
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
        echo "  (no-op) $file has no sapience SessionStart hook to remove"
        return 0
    fi

    if $DRY_RUN; then
        echo "  [DRY RUN] Would remove the SessionStart hook entry from $file"
        return 0
    fi

    local tmp
    tmp=$(mktemp "${file}.tmp.XXXXXXXXXX")
    # Filter out the matching entry, then PRUNE an emptied .hooks.SessionStart array entirely
    # (rather than leaving a `[]`-valued key behind) so --remove exactly reverses a prior
    # install against a fixture that had no SessionStart key at all before -- not merely an
    # equivalent-but-not-identical empty-array state. Mirrors this corpus's own
    # prune_empty_hooks convention (lua/neotex/plugins/ai/shared/extensions/merge.lua).
    jq --arg cmd "$HOOK_COMMAND" \
        '.hooks.SessionStart = [.hooks.SessionStart[]? | select(([.hooks[]?.command // empty] | any(. == $cmd)) | not)]
         | if (.hooks.SessionStart | length) == 0 then .hooks |= del(.SessionStart) else . end' \
        "$file" > "$tmp"
    mv "$tmp" "$file"
    echo "  Removed the SessionStart hook entry from $file"
}

print_registration_note() {
    echo ""
    echo "NOTE: this script writes the SessionStart registration directly to $LIVE_SETTINGS."
    echo "'hooks' is a home-manager ENFORCED key (see \$HOME/.dotfiles/modules/home/core/dotfiles.nix),"
    echo "reset from \$HOME/.dotfiles/config/claude/settings.json on every 'home-manager switch'."
    echo "That other repository's own home-manager activation carries a companion-owned"
    echo "SessionStart entry invoking this same hook, independently of this script, so the"
    echo "registration survives a switch: the enforced 'hooks' key preserves that entry, and"
    echo "re-running this installer afterward reports a no-op (the byte-identical command string"
    echo "is already present) rather than a double registration."
}

if $REMOVE; then
    echo "Removing the sapience SessionStart hook registration..."
    echo "Live settings ($LIVE_SETTINGS):"
    remove_session_start_entry "$LIVE_SETTINGS"

    # Also remove this project's own per-project ~/.claude.json entry immediately, rather than
    # waiting for the next session start's bidirectional hook pass.
    if [ -f "$WRITER_DST" ]; then
        echo "Removing this project's own per-project ~/.claude.json entry..."
        if $DRY_RUN; then
            echo "  [DRY RUN] Would run: $WRITER_DST --scope project --remove --quiet"
        else
            bash "$WRITER_DST" --scope project --remove --quiet || true
        fi
    fi

    if $DRY_RUN; then
        echo "[DRY RUN] Would remove $HOOK_DST and $WRITER_DST"
        exit 0
    fi

    rm -f "$HOOK_DST" "$WRITER_DST"
    echo "Removed $HOOK_DST and $WRITER_DST (if present)."
    exit 0
fi

echo "Installing the sapience SessionStart hook..."

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
if [ ! -f "$LIVE_SETTINGS" ]; then
    if $DRY_RUN; then
        echo "  [DRY RUN] Would create $LIVE_SETTINGS and add the SessionStart hook entry"
    else
        mkdir -p "$(dirname "$LIVE_SETTINGS")"
        echo '{}' > "$LIVE_SETTINGS"
        merge_session_start_entry "$LIVE_SETTINGS"
    fi
else
    merge_session_start_entry "$LIVE_SETTINGS"
fi

print_registration_note

echo ""
echo "Done. sapience will now be registered/removed automatically, per-project, at the start of"
echo "every session, based on whether that repo's .claude-extensions.json shows the sapience"
echo "extension active."
