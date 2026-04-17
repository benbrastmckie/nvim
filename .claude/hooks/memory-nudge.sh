#!/bin/bash
# Memory nudge hook for Claude Code Stop events
# Detects completed lifecycle operations and displays a one-line reminder
# suggesting /learn --task N for memory capture.
#
# Integration: Called from Stop hooks in .claude/settings.json
# Requirements: jq
#
# Design:
#   - Pattern-matches last_assistant_message for lifecycle completion signals
#   - Suppresses for subagent contexts (agent_id present)
#   - 5-minute cooldown to prevent nudge fatigue
#   - Outputs systemMessage JSON on stdout
#   - Always exits 0 (never blocks Claude)

set -uo pipefail

# Cooldown configuration (seconds)
NUDGE_COOLDOWN="${NUDGE_COOLDOWN:-300}"

# State files
COOLDOWN_FILE="specs/tmp/memory-nudge-last"

# Helper: exit cleanly without output
exit_success() {
    echo '{}'
    exit 0
}

# Guard: check jq availability
if ! command -v jq &>/dev/null; then
    exit_success
fi

# Read stdin JSON (hooks provide context via stdin)
STDIN_JSON=""
if read -t 0.1 -r line; then
    STDIN_JSON="$line"
    while read -t 0.1 -r more; do
        STDIN_JSON="${STDIN_JSON}${more}"
    done
fi

# Guard: need stdin
if [[ -z "$STDIN_JSON" ]]; then
    exit_success
fi

# Guard: suppress for subagent contexts
AGENT_ID=$(echo "$STDIN_JSON" | jq -r '.agent_id // empty' 2>/dev/null || echo "")
if [[ -n "$AGENT_ID" ]]; then
    exit_success
fi

# Guard: only trigger on end_turn stops
STOP_REASON=$(echo "$STDIN_JSON" | jq -r '.stop_reason // empty' 2>/dev/null || echo "")
if [[ "$STOP_REASON" != "end_turn" ]]; then
    exit_success
fi

# Guard: check cooldown
if [[ -f "$COOLDOWN_FILE" ]]; then
    LAST_TIME=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    ELAPSED=$((NOW - LAST_TIME))
    if (( ELAPSED < NUDGE_COOLDOWN )); then
        exit_success
    fi
fi

# Extract last assistant message
MESSAGE=$(echo "$STDIN_JSON" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")
if [[ -z "$MESSAGE" ]]; then
    exit_success
fi

# Pattern match for lifecycle completion signals
# Truncate to first 2000 chars to avoid regex performance issues on large messages
CHECK="${MESSAGE:0:2000}"

MATCHED=false

# Commit message patterns (from git commits in postflight)
if echo "$CHECK" | grep -qiE 'task [0-9]+: complete (research|implementation|plan)'; then
    MATCHED=true
# Status update patterns
elif echo "$CHECK" | grep -qiE 'status.*(researched|planned|completed|implemented)'; then
    MATCHED=true
# Natural language completion patterns
elif echo "$CHECK" | grep -qiE '(research|plan|implementation) complete'; then
    MATCHED=true
# Archive patterns (from /todo)
elif echo "$CHECK" | grep -qiE '(archived.*task|tasks? archived)'; then
    MATCHED=true
# Review completion
elif echo "$CHECK" | grep -qiE 'review (complete|finished|done)'; then
    MATCHED=true
fi

if [[ "$MATCHED" != "true" ]]; then
    exit_success
fi

# Extract task number from message
TASK_NUM=""
if [[ "$CHECK" =~ task\ ([0-9]+) ]]; then
    TASK_NUM="${BASH_REMATCH[1]}"
elif [[ "$CHECK" =~ Task\ \#([0-9]+) ]]; then
    TASK_NUM="${BASH_REMATCH[1]}"
fi

# Build nudge message
if [[ -n "$TASK_NUM" ]]; then
    NUDGE_MSG="[memory] Task $TASK_NUM lifecycle step completed. Consider: /learn --task $TASK_NUM"
else
    NUDGE_MSG="[memory] Lifecycle step completed. Consider: /learn to capture insights."
fi

# Ensure cooldown directory exists
mkdir -p "$(dirname "$COOLDOWN_FILE")"

# Update cooldown timestamp
date +%s > "$COOLDOWN_FILE"

# Output systemMessage JSON
echo "{\"systemMessage\": \"$NUDGE_MSG\"}"
exit 0
