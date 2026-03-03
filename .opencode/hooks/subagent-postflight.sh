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

MARKER_FILE="specs/.postflight-pending"
LOOP_GUARD_FILE="specs/.postflight-loop-guard"
MAX_CONTINUATIONS=3

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
    # Check if postflight marker exists
    if [ -f "$MARKER_FILE" ]; then
        log_debug "Postflight marker found"

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
    rm -f "$LOOP_GUARD_FILE"
    echo '{}'
    exit 0
}

main
