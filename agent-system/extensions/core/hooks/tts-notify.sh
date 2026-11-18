#!/usr/bin/env bash
# TTS notification hook for Claude Code events
# Announces WezTerm tab number via piper neural TTS for lifecycle transitions,
# interactive prompts requiring user input, and finished Stop-hook runs.
#
# Integration:
#   Notification hook (permission_prompt, idle_prompt, elicitation_dialog): called with no args
#   Lifecycle transitions: called by update-task-status.sh postflight with --lifecycle STATUS
#   Stop hook (no-workflow-marker branch): called by claude-stop-notify.sh with --stop
#
# Requirements: piper (neural TTS) + a voice model, paplay (pulseaudio-utils), wezterm
#
# Supported Modes:
#   Interactive (no args) - speaks "Tab N" for permission_prompt/idle_prompt/elicitation_dialog
#   Lifecycle (--lifecycle STATUS) - speaks "Tab N STATUS" (e.g., "Tab 3 researched")
#   Stop (--stop) - speaks "Tab N done", distinguishable by ear from the interactive utterance
#
# Lifecycle status vocabulary (no artifact-type vocabulary):
#   researching, researched, planning, planned, implementing, completed, blocked
#
# Cooldown (applies uniformly to all three modes above):
#   A pane-keyed stamp collapses any repeat utterance inside TTS_COOLDOWN seconds into a single
#   fire, so an idle_prompt re-fire, a coinciding Stop+Notification pair, or any future double
#   registration degrades to one utterance instead of a burst. The stamp is written only on a
#   path that actually reaches speak() (non-sliding: a suppressed invocation never resets the
#   window). Keyed by WEZTERM_PANE so concurrent panes never suppress each other. Every
#   suppressed invocation is still logged, so no evidence is lost -- only audio.
#
# Configuration:
#   TTS_ENABLED   - Set to "0" to disable (default: 1)
#   PIPER_VOICE   - Path to piper .onnx voice model
#                   (default: $HOME/.local/share/piper/en_US-lessac-medium.onnx)
#   TTS_COOLDOWN  - Seconds a pane must wait between actual utterances (default: 75)

set -euo pipefail

# Configuration with defaults
TTS_ENABLED="${TTS_ENABLED:-1}"
PIPER_VOICE="${PIPER_VOICE:-$HOME/.local/share/piper/en_US-lessac-medium.onnx}"
TTS_COOLDOWN="${TTS_COOLDOWN:-75}"

# Cooldown stamp: ephemeral per-pane runtime state, not repo-local evidence (that is LOG_FILE
# below). Lives under XDG_RUNTIME_DIR (falling back to /tmp) so a repo with no specs/ tree can
# still write it, and is keyed by WEZTERM_PANE so concurrent panes never suppress each other,
# plus UID so a shared /tmp fallback cannot collide across users.
COOLDOWN_FILE="${XDG_RUNTIME_DIR:-/tmp}/claude-tts-cooldown-${UID:-0}-${WEZTERM_PANE:-nopane}"

# Log file
LOG_FILE="specs/tmp/claude-tts-notify.log"

# --- Parse arguments ---
LIFECYCLE_STATUS=""
STOP_MODE=""
if [[ "${1:-}" == "--lifecycle" ]] && [[ -n "${2:-}" ]]; then
    LIFECYCLE_STATUS="$2"
elif [[ "${1:-}" == "--stop" ]]; then
    STOP_MODE="1"
fi

# Helper: log message
log() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Helper: return success JSON for hook
exit_success() {
    echo '{}'
    exit 0
}

# Helper: true (0) if a real utterance fired in the last TTS_COOLDOWN seconds for this pane.
# Every file operation is wrapped so a read failure degrades to "cooldown never engages" --
# announcing is the fail-open direction, never silence.
cooldown_blocked() {
    local last_time now elapsed
    last_time=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo "")
    [[ -z "$last_time" ]] && return 1
    [[ "$last_time" =~ ^[0-9]+$ ]] || return 1
    now=$(date +%s)
    elapsed=$(( now - last_time ))
    (( elapsed < TTS_COOLDOWN )) && return 0
    return 1
}

# Helper: stamp the current time as the last real utterance for this pane. Called only on a
# path that actually reaches speak(), never on a suppressed invocation (non-sliding window).
cooldown_stamp() {
    date +%s > "$COOLDOWN_FILE" 2>/dev/null || true
}

# Helper: get WezTerm tab prefix ("Tab N" or fallback "Tab")
get_tab_prefix() {
    local tab_prefix="Tab"
    if [[ -n "${WEZTERM_PANE:-}" ]] && command -v wezterm &>/dev/null; then
        local all_panes current_tab_id unique_tab_ids tab_index position tab_num
        all_panes=$(wezterm cli list --format=json 2>/dev/null) || true
        current_tab_id=$(echo "$all_panes" | jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tab_id" 2>/dev/null || echo "")
        if [[ -n "$current_tab_id" ]] && ! [[ "$current_tab_id" == "null" ]]; then
            unique_tab_ids=$(echo "$all_panes" | jq -r '[.[].tab_id] | unique | .[]') || true
            tab_index=0
            position=0
            while IFS= read -r tab_id; do
                if [[ "$tab_id" == "$current_tab_id" ]]; then
                    position=$tab_index
                    break
                fi
                tab_index=$((tab_index + 1))
            done <<< "$unique_tab_ids"
            tab_num=$((position + 1))
            tab_prefix="Tab $tab_num"
        fi
    fi
    echo "$tab_prefix"
}

# Helper: speak a message via piper (neural TTS)
# Streams synthesized audio straight to paplay; no temp WAV needed.
speak() {
    local message="$1"
    if ! command -v paplay &>/dev/null; then
        log "No audio player found (paplay) - skipping TTS"
        return 1
    fi
    if [[ ! -f "$PIPER_VOICE" ]]; then
        log "Piper voice model not found at '$PIPER_VOICE' - skipping TTS"
        return 1
    fi
    (timeout 10s bash -c "printf '%s' '${message}' | piper --model '${PIPER_VOICE}' --output_file - --quiet 2>/dev/null | paplay 2>/dev/null" &) || true
    return 0
}

# Check if TTS is disabled
if [[ "$TTS_ENABLED" != "1" ]]; then
    exit_success
fi

# Check if piper is available
if ! command -v piper &>/dev/null; then
    log "piper command not found - skipping TTS notification"
    exit_success
fi

# Determine mode name for cooldown logging, before the gate below.
if [[ -n "$LIFECYCLE_STATUS" ]]; then
    MODE_NAME="lifecycle:$LIFECYCLE_STATUS"
elif [[ -n "$STOP_MODE" ]]; then
    MODE_NAME="stop"
else
    MODE_NAME="interactive"
fi

# ============================================================
# COOLDOWN GATE: applies uniformly to every mode below.
# Collapses any repeat utterance inside TTS_COOLDOWN seconds into a single fire. The log stays
# a complete record of every invocation, suppressed or not.
# ============================================================
if cooldown_blocked; then
    SUPPRESSED_LAST=$(cat "$COOLDOWN_FILE" 2>/dev/null || echo "0")
    SUPPRESSED_ELAPSED=$(( $(date +%s) - SUPPRESSED_LAST ))
    log "Suppressed by cooldown: mode=$MODE_NAME elapsed=${SUPPRESSED_ELAPSED}s window=${TTS_COOLDOWN}s"
    exit_success
fi

# ============================================================
# LIFECYCLE MODE: --lifecycle STATUS
# Speak "Tab N STATUS" for researched/planned/completed events
# ============================================================
if [[ -n "$LIFECYCLE_STATUS" ]]; then
    TAB_PREFIX=$(get_tab_prefix)
    MESSAGE="$TAB_PREFIX $LIFECYCLE_STATUS"
    speak "$MESSAGE"
    cooldown_stamp
    log "Lifecycle notification sent: $MESSAGE (status=$LIFECYCLE_STATUS)"
    exit_success
fi

# ============================================================
# STOP MODE: --stop
# Speak "Tab N done" for a finished run's no-workflow-marker Stop hook branch. The "done" word
# is what makes this utterance distinguishable by ear from the bare "Tab N" interactive one.
# ============================================================
if [[ -n "$STOP_MODE" ]]; then
    TAB_PREFIX=$(get_tab_prefix)
    MESSAGE="$TAB_PREFIX done"
    speak "$MESSAGE"
    cooldown_stamp
    log "Stop notification sent: $MESSAGE"
    exit_success
fi

# ============================================================
# INTERACTIVE MODE: no args (Notification hook)
# Speak "Tab N" for permission_prompt, idle_prompt, and elicitation_dialog
# ============================================================
TAB_PREFIX=$(get_tab_prefix)
MESSAGE="$TAB_PREFIX"
speak "$MESSAGE"
cooldown_stamp
log "Interactive notification sent: $MESSAGE"
exit_success
