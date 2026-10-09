#!/usr/bin/env bash
# Unified Stop hook for Claude Code: workflow-active marker suppress pattern
#
# Architecture:
#   1. update-task-status.sh preflight writes a PER-SESSION
#      .claude/tmp/workflow-active-<CC_SESSION_ID> marker (keyed by Claude Code's own native
#      session UUID -- see that script's header comment for the two-id-spaces rationale)
#   2. This Stop hook checks whether ANY session's workflow-active marker is present:
#      - If any marker exists: some workflow is active (orchestrator pause) -> exit silently
#      - If no marker at all: interactive/non-lifecycle stop -> fire needs_input wezterm color
#
# Suppression is deliberately GLOBAL (any session's marker suppresses this hook's own fire),
# even though storage is per-session: this hook's job is "don't reset the tab color while ANY
# orchestrator workflow anywhere is mid-flight", not "while MY OWN session is". Scoping the
# glance-check to the current session only would reintroduce a race for a single interactive
# session running back-to-back lifecycle commands. Per-session storage exists so a DIFFERENT
# hook -- wezterm-preflight-status.sh's ESC-cancel cleanup -- can delete only its own marker
# without deleting a concurrently-active session's marker out from under it (the defect this
# conversion closes); it is not meant to narrow this hook's own suppression scope.
#
# Workflow-active marker: .claude/tmp/workflow-active-<CC_SESSION_ID> (one per Claude Code
# session)
#   - Written by update-task-status.sh preflight (contains task number and timestamp)
#   - Cleared by wezterm-preflight-status.sh Tier 2 (non-lifecycle slash commands), scoped to
#     the CURRENT session's own marker only
#   - Also cleared on next UserPromptSubmit for non-lifecycle commands (same scoping)
#
# Subagent suppression (defense-in-depth):
#   - Stop hook fires for all agents (including subagents)
#   - If stdin JSON contains agent_id field, this is a subagent stop -> suppress all dispatch
#
# Integration: Called from Stop hook in .claude/settings.json
# Requirements: bash, jq (for subagent detection), wezterm (optional)
#
# See: simplify_notification_pipeline_merge_vocabulary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Workflow-active marker glob: per-session files, e.g. .claude/tmp/workflow-active-<uuid>.
# Suppression here is global (see header comment) -- any match at all is sufficient, so a glob
# existence check is exactly right; no single session_id needs to be resolved.
#
# Deliberate: the trailing `*` is stored LITERALLY here (assignment context never expands
# globs) and is only expanded later, at its one unquoted use site (`for marker in
# $WORKFLOW_ACTIVE_GLOB`), where unquoted word-splitting re-triggers real glob matching. That is
# the intended two-step shape, not a bug -- an array would be the alternative shellcheck
# suggests, but it cannot hold an as-yet-unexpanded pattern the same way a plain variable can.
# shellcheck disable=SC2125
WORKFLOW_ACTIVE_GLOB="$SCRIPT_DIR/../tmp/workflow-active-"*

# Helper: return success JSON for Stop hook
exit_success() {
    echo '{}'
    exit 0
}

# --- Subagent detection (defense-in-depth) ---
# Read stdin JSON to check if this is a subagent stop event.
# If agent_id is present in the stop context, suppress all lifecycle dispatch.
STDIN_JSON=$(cat 2>/dev/null || echo '{}')
AGENT_ID=$(echo "$STDIN_JSON" | jq -r '.agent_id // empty' 2>/dev/null || echo "")
if [[ -n "$AGENT_ID" ]]; then
    # This is a subagent stop -- suppress all dispatch
    exit_success
fi

# --- Ensure tmp directory exists ---
mkdir -p "$SCRIPT_DIR/../tmp" 2>/dev/null || true

# --- Workflow-active check (any session) ---
# If ANY session's workflow-active-<uuid> marker exists, this Stop fired during an orchestrator
# pause (possibly a different session's). Postflight already fired (or will fire) TTS+wezterm
# via update-task-status.sh. Exit silently to avoid overwriting the in-progress tab color. Glob
# expansion with no match yields the literal unexpanded pattern under default bash globbing, so
# the existence test is against that literal string too -- `-f` on a nonexistent literal path is
# simply false, which is exactly the desired no-match behavior; nullglob is not needed here.
for marker in $WORKFLOW_ACTIVE_GLOB; do
    if [[ -f "$marker" ]]; then
        exit_success
    fi
done

# --- No active workflow: interactive / non-lifecycle stop ---
# Fire needs_input wezterm color only (no TTS for non-lifecycle stops)
wezterm_script="$SCRIPT_DIR/wezterm-notify.sh"
if [[ -f "$wezterm_script" ]]; then
    bash "$wezterm_script" 2>/dev/null || true
fi

exit_success
