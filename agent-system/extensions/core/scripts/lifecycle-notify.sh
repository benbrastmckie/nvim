#!/usr/bin/env bash
# lifecycle-notify.sh - Bridge script for orchestrator phase transition notifications
#
# Usage:
#   lifecycle-notify.sh STATUS           # Normal mode: tab color + TTS
#   lifecycle-notify.sh STATUS --quiet   # Quiet mode: tab color only (no TTS)
#   lifecycle-notify.sh ""               # Empty status: no-op, exits 0. The no-op is now LOGGED
#                                         # (appended to specs/tmp/claude-tts-notify.log) so a
#                                         # caller passing an empty/unset status leaves a visible
#                                         # trace instead of vanishing silently.
#
# Called by orchestrator-postflight.sh Stage 8b for lifecycle phase transitions.
#
# Arguments:
#   $1  STATUS   - Lifecycle status string (e.g., "researched", "planned", "implemented")
#   $2  --quiet  - Optional flag to suppress TTS announcement
#
# Behavior:
#   Always calls wezterm-notify.sh STATUS for tab color update
#   In normal mode (no --quiet): also calls tts-notify.sh --lifecycle STATUS
#
# orchestrate-active marker:
#   The check below (`-f "$SCRIPT_DIR/../tmp/orchestrate-active"`) is live code: when that file
#   exists, TTS from THIS script is suppressed (tab color still updates). But nothing in the
#   source store currently WRITES .claude/tmp/orchestrate-active, so in practice this check
#   never finds the file and this auto-suppression path does not currently engage -- stated
#   honestly here rather than describing a producer that does not exist.
#
#   Decision table for the four scenarios this marker was intended to distinguish:
#     - a standalone research-phase dispatch for N completes: no orchestrate-active -> TTS fires
#     - mid-orchestrate research completes: orchestrate-active exists -> TTS suppressed, tab color
#       only (currently unreachable: see "zero writers" note above)
#     - orchestrate final completion: the actual suppression mechanism is the SEPARATE
#       workflow-active-<CC_SESSION_ID> marker claude-stop-notify.sh checks (not this script's
#       orchestrate-active check) -- once no such marker remains, that hook's no-marker branch
#       fires tts-notify.sh --stop ("Tab N done")
#     - orchestrate paused/blocked: same mechanism as above -- claude-stop-notify.sh's
#       workflow-active-marker check, not this script's orchestrate-active check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"
LOG_FILE="specs/tmp/claude-tts-notify.log"

# Helper: log message (same log file and line shape tts-notify.sh's own log() writes, so the
# no-op branch below leaves a trace in the same evidence surface as a successful notification).
log() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# Parse arguments
STATUS="${1:-}"
QUIET="${2:-}"

# No-op if status is empty -- logged (not silent) so an empty/unset-variable regression at a
# caller's Stage 8a call site produces a visible artifact on its very first execution.
if [[ -z "$STATUS" ]]; then
    log "Lifecycle notification skipped: empty status received, no notification sent"
    exit 0
fi

# Auto-suppress TTS when running mid-orchestrate (orchestrate-active marker exists)
# Tab color still updates; only TTS is suppressed.
if [[ -f "$SCRIPT_DIR/../tmp/orchestrate-active" ]]; then
    QUIET="--quiet"
fi

# Always update WezTerm tab color via wezterm-notify.sh
if [[ -f "$HOOKS_DIR/wezterm-notify.sh" ]]; then
    bash "$HOOKS_DIR/wezterm-notify.sh" "$STATUS" 2>/dev/null || true
fi

# In normal mode (not --quiet): also announce via TTS
if [[ "$QUIET" != "--quiet" ]]; then
    if [[ -f "$HOOKS_DIR/tts-notify.sh" ]]; then
        bash "$HOOKS_DIR/tts-notify.sh" --lifecycle "$STATUS" 2>/dev/null || true
    fi
fi

exit 0
