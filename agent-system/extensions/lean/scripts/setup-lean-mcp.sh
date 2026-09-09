#!/usr/bin/env bash
#
# setup-lean-mcp.sh - Configure lean-lsp MCP server, per Lean project, in ~/.claude.json
#
# Per-project model (default, and the only model that scales to many concurrent Lean
# projects): each Lean project gets its OWN entry under
# `.projects["<abs project path>"].mcpServers."lean-lsp"`, holding that project's own
# `LEAN_PROJECT_PATH`. A project-scoped entry takes precedence over any top-level global
# entry for that same project directory -- confirmed empirically (a project-scoped entry
# pointing at a DIFFERENT project than the global entry is the one that actually answers
# lean-lsp tool calls, from both the main session and a dispatched subagent). The top-level
# global `.mcpServers."lean-lsp"` entry is RETIRED under this model (see --retire-global
# below): keeping it as a fallback would silently answer for any project that has not yet
# been registered, which is the exact defect this per-project model exists to remove. An
# absent entry fails loudly (no lean-lsp tool at all); a stale global entry fails
# confidently and wrong, which is worse.
#
# `--scope global` is retained only for rollback/contingency -- it reproduces the single
# global entry from an earlier model of this script, useful for reverting to it in one move.
#
# lean-lsp is registered in `~/.claude.json` (never inside a repository's own `.claude/`
# deploy tree, and never in a project-scoped `.mcp.json`) because it needs a per-project
# computed `LEAN_PROJECT_PATH` that a repository cannot compute or commit for itself. A
# subagent CAN reach a project-scoped entry once the workspace is trusted -- directly
# demonstrated. See agent-system/extensions/core/context/patterns/mcp-server-ownership.md
# for the full registration/permission split and the per-project-vs-global rationale.
#
# Usage: ./setup-lean-mcp.sh [OPTIONS]
#
# Options:
#   --project PATH     Override project path (default: auto-detect)
#   --scope SCOPE       project (default) | global | both
#   --dry-run           Show what would be done without making changes
#   --remove            Remove lean-lsp from the selected --scope
#   --retire-global      Remove ONLY the top-level global entry, leaving .projects untouched
#   --quiet             Silent and exit 0 when the entry already matches; one line when it
#                        writes. Suitable for hook invocation.
#   --help              Show this help message
#
# The script will (per selected scope):
#   1. Detect the Lean project path (or use --project)
#   2. Create ~/.claude.json if it doesn't exist
#   3. Add/repair the lean-lsp entry at that scope if it is missing or diverges
#   4. Preserve every other entry in the file (whole-file jq merge, never a wholesale rewrite)
#
# After running, restart Claude Code for changes to take effect (see the session-start
# snapshot trap in mcp-server-ownership.md -- an already-running session cannot see this
# write until it is restarted).

set -euo pipefail

# Default values
DRY_RUN=false
REMOVE=false
RETIRE_GLOBAL=false
QUIET=false
PROJECT_PATH=""
SCOPE="project"

# Parse arguments
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

# --retire-global is a standalone action: remove ONLY the top-level global entry, leaving
# .projects entirely untouched, then exit. Takes priority over --scope/--remove.
if $RETIRE_GLOBAL; then
    if [ ! -f "$CLAUDE_CONFIG" ]; then
        log "No ~/.claude.json found, nothing to retire."
        exit 0
    fi

    if ! jq -e '.mcpServers."lean-lsp"' "$CLAUDE_CONFIG" > /dev/null 2>&1; then
        log "No top-level lean-lsp entry found, nothing to retire."
        exit 0
    fi

    if $DRY_RUN; then
        log "[DRY RUN] Would remove the top-level global lean-lsp entry from $CLAUDE_CONFIG (leaving .projects untouched)"
        exit 0
    fi

    TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
    jq 'del(.mcpServers."lean-lsp")' "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"

    log "Retired the top-level global lean-lsp entry from $CLAUDE_CONFIG (.projects untouched)."
    exit 0
fi

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

log "Configuration:"
log "  Project path: $PROJECT_PATH"
log "  Claude config: $CLAUDE_CONFIG"
log "  Scope: $SCOPE"
log ""

# Generate the lean-lsp configuration. Identical shape at every scope -- only WHERE it is
# written differs; the per-project computed value (LEAN_PROJECT_PATH) is the same either way.
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

# jq_get_path SCOPE -- the jq filter selecting this scope's lean-lsp entry, as a string
# fragment for use inside a larger jq program. Uses the $path --arg variable for project
# scope so the project path never needs literal interpolation into the jq program text.
jq_get_path() {
    case "$1" in
        project) echo '.projects[$path].mcpServers."lean-lsp"' ;;
        global)  echo '.mcpServers."lean-lsp"' ;;
    esac
}

# scope_label SCOPE -- human-readable label for messages.
scope_label() {
    case "$1" in
        project) echo "project scope (.projects[\"$PROJECT_PATH\"])" ;;
        global)  echo "global scope (top-level .mcpServers)" ;;
    esac
}

# process_remove SCOPE -- remove the lean-lsp entry at SCOPE, if present.
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
        log "lean-lsp not found at $label, nothing to remove."
        return 0
    fi

    if $DRY_RUN; then
        log "[DRY RUN] Would remove lean-lsp from $label"
        return 0
    fi

    case "$scope" in
        project) del_expr='del(.projects[$path].mcpServers."lean-lsp")' ;;
        global)  del_expr='del(.mcpServers."lean-lsp")' ;;
    esac

    TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
    jq --arg path "$PROJECT_PATH" "$del_expr" "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"

    log "Removed lean-lsp from $label"
}

# process_write SCOPE -- create-or-repair the lean-lsp entry at SCOPE, using whole-entry
# (never per-field) comparison and replacement, so a divergent command/args/env is corrected
# together with the project path, not just patched on the LEAN_PROJECT_PATH field.
process_write() {
    local scope="$1"
    local get_path set_expr label existing_entry lean_config canonical_entry entries_match

    get_path="$(jq_get_path "$scope")"
    label="$(scope_label "$scope")"
    lean_config=$(generate_lean_lsp_config)
    canonical_entry=$(printf '%s' "$lean_config" | jq -c '.')

    # Ensure the config file exists before reading it. An empty `{}` skeleton is sufficient;
    # the write below auto-vivifies every intermediate object (.projects, .projects[path],
    # .mcpServers) via jq's assignment autovivification.
    if [ ! -f "$CLAUDE_CONFIG" ]; then
        if $DRY_RUN; then
            log "[DRY RUN] Would create $CLAUDE_CONFIG and register lean-lsp at $label:"
            printf '%s\n' "$lean_config" | sed 's/^/  /'
            return 0
        fi
        echo '{}' > "$CLAUDE_CONFIG"
    fi

    existing_entry=$(jq -c --arg path "$PROJECT_PATH" "${get_path} // empty" "$CLAUDE_CONFIG" 2>/dev/null || echo "")

    if [ -n "$existing_entry" ] && [ "$existing_entry" != "null" ]; then
        entries_match=$(jq -n --argjson a "$existing_entry" --argjson b "$canonical_entry" '$a == $b')

        if [ "$entries_match" = "true" ]; then
            log "lean-lsp already configured correctly at $label."
            log "No changes needed."
            return 0
        fi

        local existing_command existing_args existing_path
        existing_command=$(jq -r --arg path "$PROJECT_PATH" "(${get_path}).command // \"(none)\"" "$CLAUDE_CONFIG")
        existing_args=$(jq -c --arg path "$PROJECT_PATH" "(${get_path}).args // []" "$CLAUDE_CONFIG")
        existing_path=$(jq -r --arg path "$PROJECT_PATH" "(${get_path}).env.LEAN_PROJECT_PATH // \"(none)\"" "$CLAUDE_CONFIG")

        log "lean-lsp already configured at $label but diverges from the sanctioned shape:"
        log "  Current command:      $existing_command"
        log "  Current args:         $existing_args"
        log "  Current project path: $existing_path"
        log "  Sanctioned command:      uvx"
        log "  Sanctioned args:         [\"lean-lsp-mcp\"]"
        log "  Sanctioned project path: $PROJECT_PATH"
        log ""

        if $DRY_RUN; then
            log "[DRY RUN] Would replace the entire lean-lsp entry at $label with:"
            printf '%s\n' "$lean_config" | sed 's/^/  /'
            return 0
        fi

        case "$scope" in
            project) set_expr='.projects[$path].mcpServers."lean-lsp" = $leanConfig' ;;
            global)  set_expr='.mcpServers."lean-lsp" = $leanConfig' ;;
        esac

        TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
        jq --arg path "$PROJECT_PATH" --argjson leanConfig "$lean_config" "$set_expr" "$CLAUDE_CONFIG" > "$TMP_FILE"
        mv "$TMP_FILE" "$CLAUDE_CONFIG"

        log "Replaced lean-lsp entry at $label with the sanctioned shape (command, args, and project path)."
        [ "$QUIET" = "true" ] && echo "lean-lsp: repaired for $PROJECT_PATH ($scope scope)"
        return 0
    fi

    # No existing entry at this scope: add one.
    if $DRY_RUN; then
        log "[DRY RUN] Would add lean-lsp at $label"
        log ""
        log "New lean-lsp configuration:"
        printf '%s\n' "$lean_config" | sed 's/^/  /'
        return 0
    fi

    case "$scope" in
        project) set_expr='.projects[$path].mcpServers."lean-lsp" = $leanConfig' ;;
        global)  set_expr='.mcpServers."lean-lsp" = $leanConfig' ;;
    esac

    TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
    jq --arg path "$PROJECT_PATH" --argjson leanConfig "$lean_config" "$set_expr" "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"

    log "Added lean-lsp at $label"
    [ "$QUIET" = "true" ] && echo "lean-lsp: registered for $PROJECT_PATH ($scope scope)"
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
