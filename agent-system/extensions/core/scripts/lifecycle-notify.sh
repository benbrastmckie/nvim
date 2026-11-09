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
#   When .claude/tmp/orchestrate-active exists, TTS is automatically suppressed (tab color
#   still updates) to implement the UX decision table:
#     - a standalone research-phase dispatch for N completes: no orchestrate-active -> TTS fires
#     - mid-orchestrate research completes: orchestrate-active exists -> TTS suppressed, tab color only
#     - orchestrate final completion: orchestrate-active cleared by Stage 8 -> subsequent Stop hook
#       fires TTS (via tts-notify.sh integration)
#     - orchestrate paused/blocked: orchestrate-active cleared by Stage 8 partial -> Stop hook fires TTS

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
