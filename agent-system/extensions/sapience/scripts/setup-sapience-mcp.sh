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
# This writer never touches the top-level `.mcpServers` key except via the standalone
# `--retire-global` action below, which is explicitly scoped to that one key alone. This
# machine's home-manager activation no longer writes a top-level `.mcpServers.sapience` entry:
# `modules/home/services/sapience.nix`'s `sapienceMcpServer` block and its `registerMcpServer`
# option have been retired, so registration is per-project only (see above). `--retire-global`
# is therefore an ordinary cleanup action, not an inert one -- it removes a top-level entry if
# one is still present (e.g. a stale leftover from before the retirement) and has nothing to do
# otherwise.
#
# Command-path invariant (mcp-server-ownership.md's ".claude/"-path boundary): the `command`
# this writer resolves must never point inside any repository's own, disposable `.claude/` tree.
# It resolves to either the nix-store-pinned interpreter the existing top-level entry already
# names, or a plain `python3` resolved via `command -v` -- never a path under `.claude/`.
#
# --reap (cross-project reaper): a registered `.projects[<path>]` row whose `<path>` has since
# been deleted or renamed can never again satisfy the SessionStart hook's own
# .claude-extensions.json-reachability precondition, so the bidirectional register/remove path
# above can never reach it -- removal only ever fires for a path that still exists AND still
# carries a manifest showing sapience inactive. `--reap` closes that gap from the one place that
# CAN see every registered path at once: this writer, which already owns every ~/.claude.json
# mutation. It removes ONLY `.mcpServers.sapience` from every `.projects[<path>]` row whose
# `<path>` is not a directory on disk; other servers on that row (e.g. `lean-lsp`) and the row
# itself are left untouched, and a row left with `"mcpServers": {}` is the accepted end state --
# deleting the whole project row would discard unrelated session/history/cost metadata. `--reap`
# is a standalone, cross-project action: it ignores `--scope` and needs no `--project`.
#
# Usage: ./setup-sapience-mcp.sh [OPTIONS]
#
# Options:
#   --project PATH     Override project path (default: current working directory)
#   --scope SCOPE       project (default) | global | both
#   --dry-run           Show what would be done without making changes
#   --remove            Remove the sapience entry from the selected --scope
#   --retire-global      Remove ONLY the top-level global entry, leaving .projects untouched
#   --reap               Remove orphaned .projects[<path>].mcpServers.sapience entries for every
#                        <path> that is no longer a directory on disk (cross-project; ignores
#                        --scope and --project). Other servers and the project row itself are
#                        left untouched; an emptied .mcpServers becomes {} and stays that way.
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
# --reap is a standalone cross-project action (like --retire-global above) rather than a
# per-scope step: it sweeps every `.projects[<path>]` row once, independent of any single
# project's scope selection.
#
# Interpreter resolution: `mcp.py` imports stdlib only (json, os, re, sys, urllib.*, hashlib,
# tempfile, time) and sapience.nix's home-manager module pins a plain `pkgs.python3` (no
# `withPackages`), so resolving `python3` via `command -v` is functionally equivalent to the
# nix-store-pinned interpreter the top-level entry already names -- this writer prefers
# inheriting that pinned path when it still resolves to an executable, and falls back to
# `command -v` both when no top-level entry exists yet to inherit from and when the one that
# does exist names a path that can no longer spawn the server. That executability test is what
# keeps a single unusable top-level value from propagating into every project entry written
# after it: an inherited pin is a candidate, never an answer.
#
# After running, restart Claude Code for changes to take effect (MCP server registration is
# snapshotted at session start; a just-written entry is not guaranteed to be visible in the
# session that wrote it).

set -euo pipefail

DRY_RUN=false
REMOVE=false
RETIRE_GLOBAL=false
REAP=false
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
        --reap)
            REAP=true
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

# --reap is a standalone, cross-project action: remove ONLY the `sapience` key from
# `.projects[<path>].mcpServers` for every registered `<path>` that is NOT a directory on disk,
# leaving every other key on that row (other servers, session/history/cost metadata) and every
# other `.projects` row untouched. Placed here -- before PROJECT_PATH/SCOPE resolution and
# before resolve_interpreter's hard `exit 1` below -- because a reap pass needs no interpreter
# at all; placing it later would make the hook's reap invocation fail outright on a machine
# with no resolvable python3, exactly the hazard --retire-global above already avoids via the
# same placement. Takes priority over --scope/--project/--remove, which it ignores.
#
# Two deliberate edge cases (documented, not revisited elsewhere):
#   - A row left with "mcpServers": {} after reaping sapience is left that way, never deleted
#     as a whole project row -- the row still carries unrelated session/history/cost metadata
#     that deleting the row would discard.
#   - A path that exists on disk but is unreadable or unmounted reads as absent via `[ ! -d ]`
#     and is reaped as if orphaned. Accepted: this is self-healing, since the next session start
#     in that repo re-registers the entry via the hook's own register branch.
process_reap() {
    if [ ! -f "$CLAUDE_CONFIG" ]; then
        log "No ~/.claude.json found, nothing to reap."
        return 0
    fi

    local candidates path
    candidates=$(jq -r '.projects // {} | to_entries[] | select(.value.mcpServers.sapience? != null) | .key' "$CLAUDE_CONFIG" 2>/dev/null || echo "")

    local orphans=()
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        if [ ! -d "$path" ]; then
            orphans+=("$path")
        fi
    done <<< "$candidates"

    if [ "${#orphans[@]}" -eq 0 ]; then
        log "No orphaned sapience registrations found (every registered path still exists on disk); nothing to reap."
        return 0
    fi

    if $DRY_RUN; then
        for path in "${orphans[@]}"; do
            log "[DRY RUN] Would reap the orphaned sapience entry for $path (project directory no longer exists)"
        done
        return 0
    fi

    local orphans_json
    orphans_json=$(printf '%s\n' "${orphans[@]}" | jq -R . | jq -s .)

    TMP_FILE=$(mktemp "${CLAUDE_CONFIG}.tmp.XXXXXXXXXX")
    jq --argjson paths "$orphans_json" \
        'reduce $paths[] as $p (.; del(.projects[$p].mcpServers.sapience))' \
        "$CLAUDE_CONFIG" > "$TMP_FILE"
    mv "$TMP_FILE" "$CLAUDE_CONFIG"

    for path in "${orphans[@]}"; do
        log "Reaped the orphaned sapience entry for $path (project directory no longer exists)"
        [ "$QUIET" = "true" ] && echo "sapience: reaped orphaned entry for $path"
    done
}

if $REAP; then
    process_reap
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
# names, but only while that path still resolves to an executable; otherwise fall back to a
# plain `command -v python3` resolved to an absolute path. Refuses loudly (non-zero exit) if
# neither resolves, rather than writing a command that cannot spawn the server.
resolve_interpreter() {
    local inherited inherited_resolved
    if [ -f "$CLAUDE_CONFIG" ]; then
        inherited=$(jq -r '.mcpServers.sapience.command // empty' "$CLAUDE_CONFIG" 2>/dev/null || echo "")
        if [ -n "$inherited" ] && [ "$inherited" != "null" ]; then
            # An inherited value is a candidate, not an answer: it is only usable if it still
            # resolves to something that can actually spawn the server. A value carrying a
            # slash is tested directly; a bare command name is resolved through PATH so this
            # function's contract of returning an absolute path still holds.
            inherited_resolved=""
            case "$inherited" in
                */*)
                    if [ -x "$inherited" ]; then
                        inherited_resolved="$inherited"
                    fi
                    ;;
                *)
                    inherited_resolved=$(command -v "$inherited" 2>/dev/null || echo "")
                    ;;
            esac
            if [ -n "$inherited_resolved" ]; then
                printf '%s' "$inherited_resolved"
                return 0
            fi
            # The inherited pin cannot spawn the server -- a nix generation was collected out
            # from under it, or it names a profile path that no longer exists. Fall through to
            # a fresh resolution rather than copy a dead interpreter into this scope's entry:
            # copying it is what would make one stale top-level value permanent across every
            # project registered after it. Written to stderr, never stdout, because this
            # function's stdout IS the resolved interpreter.
            echo "Note: ignoring top-level mcpServers.sapience.command '$inherited' (does not resolve to an executable); resolving python3 afresh." >&2
        fi
    fi

    local resolved
    resolved=$(command -v python3 2>/dev/null || echo "")
    if [ -n "$resolved" ]; then
        printf '%s' "$resolved"
        return 0
    fi

    echo "Error: could not resolve a usable python3 interpreter (no executable top-level mcpServers.sapience.command to inherit, and 'command -v python3' found nothing)." >&2
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

INTERPRETER="$(resolve_interpreter)"
HOST="$(resolve_host)"
MCP_PY="$HOME/.sapience/mcp.py"

log "Configuration:"
log "  Project path: $PROJECT_PATH"
log "  Claude config: $CLAUDE_CONFIG"
log "  Scope: $SCOPE"
log "  Interpreter: $INTERPRETER"
log "  Host: $HOST"
log ""

# Generate the sapience configuration. Identical shape at every scope -- only WHERE it is
# written differs. The entry never carries a token environment variable: mcp.py resolves the
# bearer token itself from ~/.sapience/config.json (mode 0600) via one shared module-level
# statement, evaluated at import before any CLI-flag or stdio dispatch, with that variable
# unset -- see context/project/sapience/domain/per-repo-scoping.md for the full token-homes
# record. Writing the raw token into this entry would copy a secret into a file that is
# routinely inspected in plaintext (`jq .projects[...]`, `claude mcp get`) and reachable by
# Sapience's own transcript-capture path.
generate_sapience_config() {
    jq -n \
        --arg command "$INTERPRETER" \
        --arg script "$MCP_PY" \
        --arg host "$HOST" \
        '{
            type: "stdio",
            command: $command,
            args: [$script],
            env: { SAPIENCE_HOST: $host }
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
