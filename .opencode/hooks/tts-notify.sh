#!/bin/bash
# TTS notification hook for OpenCode completion
# Announces task completion via Piper TTS when OpenCode workflow commands finish
#
# Integration: Called from Stop hook in .opencode/settings.json
# Requirements: piper-tts, aplay (alsa-utils), jq, wezterm (optional)
#
# Configuration:
#   OPENCODE_TTS_ENABLED - Enable/disable TTS (default: 1)
#   PIPER_MODEL - Path to piper voice model (default: ~/.local/share/piper/en_US-lessac-medium.onnx)
#   TTS_COOLDOWN - Seconds between notifications (default: 10)
#
# Features:
#   - Reads specs/state.json to find active tasks for task-aware announcements
#   - Announces: "Task N [command] complete" or "Tab N: OpenCode complete"

set -uo pipefail

# Configuration with defaults
OPENCODE_TTS_ENABLED="${OPENCODE_TTS_ENABLED:-1}"
PIPER_MODEL="${PIPER_MODEL:-$HOME/.local/share/piper/en_US-lessac-medium.onnx}"
TTS_COOLDOWN="${TTS_COOLDOWN:-10}"

# State files
LAST_NOTIFY_FILE="/tmp/opencode-tts-last-notify"
LOG_FILE="/tmp/opencode-tts-notify.log"

# Helper: log message
log() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

# Helper: return success JSON for Stop hook
exit_success() {
    echo '{}'
    exit 0
}

# Check if TTS is disabled
if [[ "$OPENCODE_TTS_ENABLED" != "1" ]]; then
    exit_success
fi

# Check if piper is available
if ! command -v piper &>/dev/null; then
    log "piper command not found - skipping TTS notification"
    exit_success
fi

# Check if model exists
if [[ ! -f "$PIPER_MODEL" ]]; then
    log "Piper model not found at $PIPER_MODEL - skipping TTS notification"
    exit_success
fi

# Check cooldown (simple time-based)
if [[ -f "$LAST_NOTIFY_FILE" ]]; then
    LAST_TIME=$(cat "$LAST_NOTIFY_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    ELAPSED=$((NOW - LAST_TIME))
    if (( ELAPSED < TTS_COOLDOWN )); then
        log "Cooldown active: ${ELAPSED}s < ${TTS_COOLDOWN}s - skipping notification"
        exit_success
    fi
fi

# Get active task info from state.json for task-aware announcements
TASK_INFO=""
STATE_FILE="${PWD}/specs/state.json"
if [[ -f "$STATE_FILE" ]]; then
    # Find tasks with active workflow statuses
    ACTIVE_TASK=$(jq -r '.active_projects[] | select(.status == "researching" or .status == "planning" or .status == "implementing") | "\(.project_number):\(.status)"' "$STATE_FILE" 2>/dev/null | head -1)
    
    if [[ -n "$ACTIVE_TASK" ]]; then
        TASK_NUM=$(echo "$ACTIVE_TASK" | cut -d':' -f1)
        TASK_STATUS=$(echo "$ACTIVE_TASK" | cut -d':' -f2)
        
        # Map status to command type
        case "$TASK_STATUS" in
            "researching") CMD_TYPE="research" ;;
            "planning") CMD_TYPE="plan" ;;
            "implementing") CMD_TYPE="implementation" ;;
            *) CMD_TYPE="complete" ;;
        esac
        
        TASK_INFO="Task ${TASK_NUM} ${CMD_TYPE} complete"
    fi
fi

# Get WezTerm tab info
TAB_LABEL=""
if [[ -n "${WEZTERM_PANE:-}" ]] && command -v wezterm &>/dev/null; then
    # Get all panes data
    ALL_PANES=$(wezterm cli list --format=json 2>/dev/null)

    # Get the tab_id for the current pane
    CURRENT_TAB_ID=$(echo "$ALL_PANES" | jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tab_id" 2>/dev/null || echo "")

    # Check if we got a valid tab_id
    if [[ -n "$CURRENT_TAB_ID" ]] && ! [[ "$CURRENT_TAB_ID" == "null" ]]; then
        # Get list of unique tab_ids in the order they appear
        UNIQUE_TAB_IDS=$(echo "$ALL_PANES" | jq -r '[.[].tab_id] | unique | .[]')

        # Find the position (0-indexed) of current tab
        TAB_INDEX=0
        POSITION=0
        while IFS= read -r tab_id; do
            if [[ "$tab_id" == "$CURRENT_TAB_ID" ]]; then
                POSITION=$TAB_INDEX
                break
            fi
            ((TAB_INDEX++))
        done <<< "$UNIQUE_TAB_IDS"

        # Convert to 1-indexed for display
        TAB_NUM=$((POSITION + 1))
        TAB_LABEL="Tab ${TAB_NUM}: "
    fi
fi

# Build the announcement message
if [[ -n "$TASK_INFO" ]]; then
    # Task-aware announcement takes priority
    MESSAGE="${TAB_LABEL}${TASK_INFO}"
else
    # Fallback to generic OpenCode completion
    MESSAGE="${TAB_LABEL}OpenCode complete"
fi

# Clean up the message (remove trailing colons/spaces)
MESSAGE=$(echo "$MESSAGE" | sed 's/: *$//')

# Speak using piper with paplay (background, tolerant of errors)
if command -v paplay &>/dev/null; then
    # paplay available (PulseAudio) - need to write to temp file first
    TEMP_WAV="/tmp/opencode-tts-$$.wav"
    (timeout 10s bash -c "echo '$MESSAGE' | piper --model '$PIPER_MODEL' --output_file '$TEMP_WAV' 2>/dev/null && paplay '$TEMP_WAV' 2>/dev/null; rm -f '$TEMP_WAV'" &) || true
elif command -v aplay &>/dev/null; then
    # aplay available (ALSA)
    (timeout 10s bash -c "echo '$MESSAGE' | piper --model '$PIPER_MODEL' --output_file - 2>/dev/null | aplay -q 2>/dev/null" &) || true
else
    log "No audio player found (aplay or paplay) - skipping TTS notification"
    exit_success
fi

# Update cooldown timestamp
date +%s > "$LAST_NOTIFY_FILE"

log "Notification sent: $MESSAGE"

exit_success
