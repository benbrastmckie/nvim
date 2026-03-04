#!/bin/bash
# SubagentStop hook to prevent premature workflow termination
# Called when a subagent session is about to stop
#
# Purpose: Force continuation when postflight operations are pending
# This prevents the "continue" prompt issue between skill return and orchestrator postflight
#
# Returns:
#   {"decision": "block", "reason": "..."} - Prevents stop, forces continuation
#   {} - Allows normal stop

# Find task-scoped marker (or fallback to global for backward compatibility)
MARKER_FILE=""
LOOP_GUARD_FILE=""
TASK_DIR=""
MAX_CONTINUATIONS=3

# Search for task-scoped marker first
find_marker() {
    local found_marker=$(find specs -maxdepth 3 -name ".postflight-pending" -type f 2>/dev/null | head -1)
    if [ -n "$found_marker" ]; then
        MARKER_FILE="$found_marker"
        TASK_DIR=$(dirname "$found_marker")
        LOOP_GUARD_FILE="$TASK_DIR/.postflight-loop-guard"
    elif [ -f "specs/.postflight-pending" ]; then
        # Fallback to global marker (backward compatibility during migration)
        MARKER_FILE="specs/.postflight-pending"
        LOOP_GUARD_FILE="specs/.postflight-loop-guard"
        TASK_DIR="specs"
    fi
}

# Log function for debugging
log_debug() {
    local LOG_DIR=".opencode/logs"
    local LOG_FILE="$LOG_DIR/subagent-postflight.log"
    mkdir -p "$LOG_DIR"
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

# Check if we're in a potential infinite loop
check_loop_guard() {
    if [ -f "$LOOP_GUARD_FILE" ]; then
        local count=$(cat "$LOOP_GUARD_FILE" 2>/dev/null || echo "0")
        if [ "$count" -ge "$MAX_CONTINUATIONS" ]; then
            log_debug "Loop guard triggered: $count >= $MAX_CONTINUATIONS"
            # Reset guard and allow stop
            rm -f "$LOOP_GUARD_FILE"
            rm -f "$MARKER_FILE"
            return 1  # Allow stop
        fi
        # Increment counter
        echo $((count + 1)) > "$LOOP_GUARD_FILE"
        log_debug "Loop guard incremented to $((count + 1))"
    else
        # First continuation, initialize guard
        echo "1" > "$LOOP_GUARD_FILE"
        log_debug "Loop guard initialized to 1"
    fi
    return 0  # Allow continuation
}

# Main logic
main() {
    # Find marker file (task-scoped or global fallback)
    find_marker

    # Check if postflight marker exists
    if [ -n "$MARKER_FILE" ] && [ -f "$MARKER_FILE" ]; then
        log_debug "Postflight marker found at: $MARKER_FILE"
        log_debug "Task directory: $TASK_DIR"

        # Check for stop_hook_active flag in marker (prevents hooks calling hooks)
        if grep -q '"stop_hook_active": true' "$MARKER_FILE" 2>/dev/null; then
            log_debug "stop_hook_active flag set, allowing stop"
            rm -f "$MARKER_FILE"
            rm -f "$LOOP_GUARD_FILE"
            echo '{}'
            exit 0
        fi

        # Check loop guard
        if ! check_loop_guard; then
            log_debug "Loop guard prevented continuation"
            echo '{}'
            exit 0
        fi

        # Block the stop to allow postflight to complete
        local reason=$(jq -r '.reason // "Postflight operations pending"' "$MARKER_FILE" 2>/dev/null)
        log_debug "Blocking stop: $reason"

        # Return block decision
        # Note: Using simple JSON output - no jq dependency for robustness
        echo "{\"decision\": \"block\", \"reason\": \"$reason\"}"
        exit 0
    fi

    # No marker - allow normal stop
    log_debug "No postflight marker, allowing stop"
    # Clean up any orphaned loop guard files
    if [ -n "$LOOP_GUARD_FILE" ] && [ -f "$LOOP_GUARD_FILE" ]; then
        rm -f "$LOOP_GUARD_FILE"
    fi
    echo '{}'
    exit 0
}

main
