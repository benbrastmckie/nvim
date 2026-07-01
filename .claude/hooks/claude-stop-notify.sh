#!/bin/bash
# Unified Stop hook for Claude Code: workflow-active marker suppress pattern
#
# Architecture:
#   1. update-task-status.sh preflight writes .claude/tmp/workflow-active marker
#   2. This Stop hook checks the workflow-active marker:
#      - If marker exists: workflow is active (orchestrator pause) -> exit silently
#      - If no marker: interactive/non-lifecycle stop -> fire needs_input wezterm color
#
# Workflow-active marker: .claude/tmp/workflow-active
#   - Written by update-task-status.sh preflight (contains task number and timestamp)
#   - Cleared by wezterm-preflight-status.sh Tier 2 (non-lifecycle slash commands)
#   - Also cleared on next UserPromptSubmit for non-lifecycle commands
#
# Subagent suppression (defense-in-depth):
#   - Stop hook fires for all agents (including subagents)
#   - If stdin JSON contains agent_id field, this is a subagent stop -> suppress all dispatch
#
# Integration: Called from Stop hook in .claude/settings.json
# Requirements: bash, jq (for subagent detection), wezterm (optional)
#
# See: task 601 (simplify_notification_pipeline_merge_vocabulary)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Workflow-active marker path
WORKFLOW_ACTIVE="$SCRIPT_DIR/../tmp/workflow-active"

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

# --- Workflow-active check ---
# If workflow-active marker exists, this Stop fired during an orchestrator pause.
# Postflight already fired (or will fire) TTS+wezterm via update-task-status.sh.
# Exit silently to avoid overwriting the in-progress tab color.
if [[ -f "$WORKFLOW_ACTIVE" ]]; then
    exit_success
fi

# --- No active workflow: interactive / non-lifecycle stop ---
# Fire needs_input wezterm color only (no TTS for non-lifecycle stops)
wezterm_script="$SCRIPT_DIR/wezterm-notify.sh"
if [[ -f "$wezterm_script" ]]; then
    bash "$wezterm_script" 2>/dev/null || true
fi

exit_success
