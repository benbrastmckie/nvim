#!/usr/bin/env bash
#
# setup-sapience-mcp.sh - Configure the sapience MCP server, per project, in ~/.claude.json
#
# Per-project model, mirroring agent-system/extensions/lean/scripts/setup-lean-mcp.sh's own
# per-project `lean-lsp` registration: each project that loads the sapience extension gets its
# OWN entry under `.projects["<abs project path>"].mcpServers.sapience`. A project-scoped entry
# takes precedence over the top-level global `.mcpServers.sapience` entry for that same project
# directory -- see agent-system/extensions/core/context/patterns/mcp-server-ownership.md for the
# full registration/permission split and the per-project-vs-global precedence rule.
#
# This writer never touches the top-level `.mcpServers` key (except via the standalone
# `--retire-global` action below, which is explicitly scoped to that one key alone). The
# top-level `.mcpServers.sapience` entry is written today by this machine's home-manager
# activation (`modules/home/services/sapience.nix`'s `sapienceMcpServer` block) and is
# RE-CREATED unconditionally on every `home-manager switch` while
# `programs.sapience.registerMcpServer` is true -- so it is NOT this task's to remove, and
# `--retire-global` is deliberately inert in practice until a companion task in that other
# repository disables that activation block. Running `--retire-global` before that companion
# lands would disable Sapience in every repo still relying on the machine-wide entry.
#
# Command-path invariant (mcp-server-ownership.md's ".claude/"-path boundary): the `command`
# this writer resolves must never point inside any repository's own, disposable `.claude/` tree.
# It resolves to either the nix-store-pinned interpreter the existing top-level entry already
# names, or a plain `python3` resolved via `command -v` -- never a path under `.claude/`.
#
# Usage: ./setup-sapience-mcp.sh [OPTIONS]
#
# Options:
#   --project PATH     Override project path (default: current working directory)
#   --scope SCOPE       project (default) | global | both
#   --dry-run           Show what would be done without making changes
#   --remove            Remove the sapience entry from the selected --scope
#   --retire-global      Remove ONLY the top-level global entry, leaving .projects untouched
#   --quiet             Silent and exit 0 when the entry already matches; one line when it
#                        writes. Suitable for hook invocation.
#   --help              Show this help message
#
# The script will (per selected scope):
#   1. Resolve the project path (--project, or the current working directory)
#   2. Create ~/.claude.json if it doesn't exist
#   3. Add/repair the sapience entry at that scope if it is missing or diverges
#   4. Preserve every other entry in the file (whole-file jq merge, never a wholesale rewrite)
#
# Interpreter resolution: `mcp.py` imports stdlib only (json, os, re, sys, urllib.*, hashlib,
# tempfile, time) and sapience.nix's home-manager module pins a plain `pkgs.python3` (no
# `withPackages`), so resolving `python3` via `command -v` is functionally equivalent to the
# nix-store-pinned interpreter the top-level entry already names -- this writer prefers
# inheriting that pinned path when present, and falls back to `command -v` only when no
# top-level entry exists yet to inherit from.
#
# After running, restart Claude Code for changes to take effect (MCP server registration is
# snapshotted at session start; a just-written entry is not guaranteed to be visible in the
# session that wrote it).

set -euo pipefail

DRY_RUN=false
REMOVE=false
RETIRE_GLOBAL=false
QUIET=false
PROJECT_PATH=""
SCOPE="project"

while [[ $# -gt 0 ]]; do
    case $1 in
        --project)
            PROJECT_PATH="$2"
            shift 2
            ;;
        --scope)
            SCOPE="$2"
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
        --retire-global)
            RETIRE_GLOBAL=true
            shift
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

case "$SCOPE" in
    project|global|both) ;;
    *)
        echo "Error: --scope must be one of: project, global, both (got: $SCOPE)"
        exit 1
        ;;
esac

log() {
    if ! $QUIET; then
        echo "$@"
    fi
}

CLAUDE_CONFIG="$HOME/.claude.json"
SAPIENCE_CONFIG="$HOME/.sapience/config.json"
DEFAULT_HOST="https://app.spnc.ai"

# --retire-global is a standalone action: remove ONLY the top-level global entry, leaving
# .projects entirely untouched, then exit. Takes priority over --scope/--remove.
if $RETIRE_GLOBAL; then
    if [ ! -f "$CLAUDE_CONFIG" ]; then
        log "No ~/.claude.json found, nothing to retire."
        exit 0
    fi

    if ! jq -e '.mcpServers.sapience' "$CLAUDE_CONFIG" > /dev/null 2>&1; then
        log "No top-level sapience entry found, nothing to retire."
        exit 0
    fi

    if $DRY_RUN; then
        log "[DRY RUN] Would remove the top-level global sapience entry from $CLAUDE_CONFIG (leaving .projects untouched)"
        exit 0
    fi

    TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
    jq 'del(.mcpServers.sapience)' "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"

    log "Retired the top-level global sapience entry from $CLAUDE_CONFIG (.projects untouched)."
    exit 0
fi

# Resolve project path if not provided: current working directory. Unlike lean's lakefile
# detection, there is no file-marker test here -- the caller (the SessionStart hook in Phase 3)
# is responsible for deciding whether sapience should be active for this project at all; this
# writer only needs to know WHERE to write once that decision has already been made.
if [ -z "$PROJECT_PATH" ]; then
    PROJECT_PATH="$(pwd)"
fi

# resolve_interpreter -- prefer the pinned nix-store path the existing top-level entry already
# names (if any), else fall back to a plain `command -v python3` resolved to an absolute path.
# Refuses loudly (non-zero exit) if neither resolves, rather than writing a command that cannot
# spawn the server.
resolve_interpreter() {
    local inherited
    if [ -f "$CLAUDE_CONFIG" ]; then
        inherited=$(jq -r '.mcpServers.sapience.command // empty' "$CLAUDE_CONFIG" 2>/dev/null || echo "")
        if [ -n "$inherited" ] && [ "$inherited" != "null" ]; then
            printf '%s' "$inherited"
            return 0
        fi
    fi

    local resolved
    resolved=$(command -v python3 2>/dev/null || echo "")
    if [ -n "$resolved" ]; then
        printf '%s' "$resolved"
        return 0
    fi

    echo "Error: could not resolve a python3 interpreter (no top-level mcpServers.sapience.command to inherit, and 'command -v python3' found nothing)." >&2
    exit 1
}

# resolve_host -- ~/.sapience/config.json's .host when present and non-empty, else the default.
resolve_host() {
    local host
    if [ -r "$SAPIENCE_CONFIG" ]; then
        host=$(jq -r '.host // empty' "$SAPIENCE_CONFIG" 2>/dev/null || echo "")
        if [ -n "$host" ] && [ "$host" != "null" ]; then
            printf '%s' "$host"
            return 0
        fi
    fi
    printf '%s' "$DEFAULT_HOST"
}

# resolve_token -- ~/.sapience/config.json's .token when present and non-empty, else empty.
# "Register without a token until config.json has one" -- the same fallback this machine's
# `sapienceMcpServer` nix activation uses for the top-level entry today.
resolve_token() {
    local token
    if [ -r "$SAPIENCE_CONFIG" ]; then
        token=$(jq -r '.token // empty' "$SAPIENCE_CONFIG" 2>/dev/null || echo "")
        if [ -n "$token" ] && [ "$token" != "null" ]; then
            printf '%s' "$token"
            return 0
        fi
    fi
    printf '%s' ""
}

INTERPRETER="$(resolve_interpreter)"
HOST="$(resolve_host)"
TOKEN="$(resolve_token)"
MCP_PY="$HOME/.sapience/mcp.py"

log "Configuration:"
log "  Project path: $PROJECT_PATH"
log "  Claude config: $CLAUDE_CONFIG"
log "  Scope: $SCOPE"
log "  Interpreter: $INTERPRETER"
log "  Host: $HOST"
log ""

# Generate the sapience configuration. Identical shape at every scope -- only WHERE it is
# written differs.
generate_sapience_config() {
    jq -n \
        --arg command "$INTERPRETER" \
        --arg script "$MCP_PY" \
        --arg host "$HOST" \
        --arg token "$TOKEN" \
        '{
            type: "stdio",
            command: $command,
            args: [$script],
            env: ({ SAPIENCE_HOST: $host } + (if ($token | length) > 0 then { SAPIENCE_TOKEN: $token } else {} end))
        }'
}

# jq_get_path SCOPE -- the jq filter selecting this scope's sapience entry, as a string
# fragment for use inside a larger jq program. Uses the $path --arg variable for project
# scope so the project path never needs literal interpolation into the jq program text.
jq_get_path() {
    case "$1" in
        project) echo '.projects[$path].mcpServers.sapience' ;;
        global)  echo '.mcpServers.sapience' ;;
    esac
}

# scope_label SCOPE -- human-readable label for messages.
scope_label() {
    case "$1" in
        project) echo "project scope (.projects[\"$PROJECT_PATH\"])" ;;
        global)  echo "global scope (top-level .mcpServers)" ;;
    esac
}

# process_remove SCOPE -- remove the sapience entry at SCOPE, if present.
process_remove() {
    local scope="$1"
    local get_path del_expr label existing
    get_path="$(jq_get_path "$scope")"
    label="$(scope_label "$scope")"

    if [ ! -f "$CLAUDE_CONFIG" ]; then
        log "No ~/.claude.json found, nothing to remove."
        return 0
    fi

    existing=$(jq -c --arg path "$PROJECT_PATH" "${get_path} // empty" "$CLAUDE_CONFIG" 2>/dev/null || echo "")
    if [ -z "$existing" ] || [ "$existing" = "null" ]; then
        log "sapience not found at $label, nothing to remove."
        return 0
    fi

    if $DRY_RUN; then
        log "[DRY RUN] Would remove sapience from $label"
        return 0
    fi

    case "$scope" in
        project) del_expr='del(.projects[$path].mcpServers.sapience)' ;;
        global)  del_expr='del(.mcpServers.sapience)' ;;
    esac

    TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
    jq --arg path "$PROJECT_PATH" "$del_expr" "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"

    log "Removed sapience from $label"
    [ "$QUIET" = "true" ] && echo "sapience: removed for $PROJECT_PATH ($scope scope)"
}

# process_write SCOPE -- create-or-repair the sapience entry at SCOPE, using whole-entry (never
# per-field) comparison and replacement, so a divergent command/args/env is corrected together,
# not patched field by field.
process_write() {
    local scope="$1"
    local get_path set_expr label existing_entry sapience_config canonical_entry entries_match

    get_path="$(jq_get_path "$scope")"
    label="$(scope_label "$scope")"
    sapience_config=$(generate_sapience_config)
    canonical_entry=$(printf '%s' "$sapience_config" | jq -c '.')

    # Ensure the config file exists before reading it. An empty `{}` skeleton is sufficient;
    # the write below auto-vivifies every intermediate object (.projects, .projects[path],
    # .mcpServers) via jq's assignment autovivification.
    if [ ! -f "$CLAUDE_CONFIG" ]; then
        if $DRY_RUN; then
            log "[DRY RUN] Would create $CLAUDE_CONFIG and register sapience at $label:"
            printf '%s\n' "$sapience_config" | sed 's/^/  /'
            return 0
        fi
        echo '{}' > "$CLAUDE_CONFIG"
    fi

    existing_entry=$(jq -c --arg path "$PROJECT_PATH" "${get_path} // empty" "$CLAUDE_CONFIG" 2>/dev/null || echo "")

    if [ -n "$existing_entry" ] && [ "$existing_entry" != "null" ]; then
        entries_match=$(jq -n --argjson a "$existing_entry" --argjson b "$canonical_entry" '$a == $b')

        if [ "$entries_match" = "true" ]; then
            log "sapience already configured correctly at $label."
            log "No changes needed."
            return 0
        fi

        log "sapience already configured at $label but diverges from the sanctioned shape."
        log "  Current entry:    $existing_entry"
        log "  Sanctioned entry: $canonical_entry"
        log ""

        if $DRY_RUN; then
            log "[DRY RUN] Would replace the entire sapience entry at $label with:"
            printf '%s\n' "$sapience_config" | sed 's/^/  /'
            return 0
        fi

        case "$scope" in
            project) set_expr='.projects[$path].mcpServers.sapience = $sapienceConfig' ;;
            global)  set_expr='.mcpServers.sapience = $sapienceConfig' ;;
        esac

        TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
        jq --arg path "$PROJECT_PATH" --argjson sapienceConfig "$sapience_config" "$set_expr" "$CLAUDE_CONFIG" > "$TMP_FILE"
        mv "$TMP_FILE" "$CLAUDE_CONFIG"

        log "Replaced sapience entry at $label with the sanctioned shape."
        [ "$QUIET" = "true" ] && echo "sapience: repaired for $PROJECT_PATH ($scope scope)"
        return 0
    fi

    # No existing entry at this scope: add one.
    if $DRY_RUN; then
        log "[DRY RUN] Would add sapience at $label"
        log ""
        log "New sapience configuration:"
        printf '%s\n' "$sapience_config" | sed 's/^/  /'
        return 0
    fi

    case "$scope" in
        project) set_expr='.projects[$path].mcpServers.sapience = $sapienceConfig' ;;
        global)  set_expr='.mcpServers.sapience = $sapienceConfig' ;;
    esac

    TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
    jq --arg path "$PROJECT_PATH" --argjson sapienceConfig "$sapience_config" "$set_expr" "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"

    log "Added sapience at $label"
    [ "$QUIET" = "true" ] && echo "sapience: registered for $PROJECT_PATH ($scope scope)"
}

SCOPES_TO_PROCESS=()
case "$SCOPE" in
    project) SCOPES_TO_PROCESS=(project) ;;
    global)  SCOPES_TO_PROCESS=(global) ;;
    both)    SCOPES_TO_PROCESS=(project global) ;;
esac

for s in "${SCOPES_TO_PROCESS[@]}"; do
    if $REMOVE; then
        process_remove "$s"
    else
        process_write "$s"
    fi
    log ""
done

if ! $DRY_RUN && ! $QUIET; then
    echo "Restart Claude Code for changes to take effect."
fi
