#!/usr/bin/env bash
# SubagentStop hook to prevent premature workflow termination
# Called when a subagent session is about to stop
#
# Purpose: Force continuation when postflight operations are pending
# This prevents the "continue" prompt issue between skill return and orchestrator postflight
#
# Returns:
#   {"decision": "block", "reason": "..."} - Prevents stop, forces continuation
#   {} - Allows normal stop
#
# Marker selection is correlated to the stopping Claude Code session via each marker's
# `cc_session_id` field (written by skill_create_postflight_marker in scripts/skill-base.sh,
# sourced from $CLAUDE_CODE_SESSION_ID) against hook stdin's top-level `.session_id`. With
# markers from several concurrent sessions on disk, an uncorrelated `head -1` pick could block
# the wrong session, increment a foreign task's loop guard, or delete a marker it does not own.
# Fail-safe: on no match, act on NO marker -- never fall back to an arbitrary one. This applies
# equally to legacy markers (written before `cc_session_id` existed) and to a marker whose
# `cc_session_id` is present but empty. Mirrored in events-log-lifecycle.sh's SubagentStop
# branch, which applies the identical correlation to its own separate `MARKER_FILE` selection.
#
# Known, accepted limitation: within a single Claude Code session holding two markers
# simultaneously, `cc_session_id` does not disambiguate which of that session's own markers
# belongs to the subagent that just stopped. Hook stdin carries no Task-tool-call-scoped
# identifier that would let the writer disambiguate in advance; this is out of scope here.

# Read hook stdin (this hook previously read no stdin at all). `read -t 0.1` bounds the read so
# an absent or terminal stdin can never block the hook -- mirrors events-log-lifecycle.sh's
# identical drain idiom. Defaults to `{}` when stdin is empty or absent.
STDIN_JSON=""
if read -t 0.1 -r line; then
    STDIN_JSON="$line"
    while read -t 0.1 -r more; do
        STDIN_JSON="${STDIN_JSON}${more}"
    done
fi
[ -z "$STDIN_JSON" ] && STDIN_JSON='{}' || true

# Claude Code's own native session UUID (top-level .session_id on hook stdin) -- the
# correlation key matched against each marker's `cc_session_id` field below.
CC_SESSION_ID=$(echo "$STDIN_JSON" | jq -r '.session_id // empty' 2>/dev/null || echo "")

# Find task-scoped marker (or fallback to global for backward compatibility)
MARKER_FILE=""
LOOP_GUARD_FILE=""
TASK_DIR=""
MAX_CONTINUATIONS=3

# Log function for debugging
log_debug() {
    local LOG_DIR=".agent-logs"
    local LOG_FILE="$LOG_DIR/subagent-postflight.log"
    mkdir -p "$LOG_DIR"
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

# Enumerate every `.postflight-pending` marker and select only the one whose `cc_session_id`
# matches the stopping session ($CC_SESSION_ID, captured above from hook stdin). Never falls
# back to the first hit: on no correlated match, MARKER_FILE/TASK_DIR/LOOP_GUARD_FILE stay unset
# and main() takes the existing "no marker -- allow normal stop" path.
find_marker() {
    local enumerated=0
    local marker marker_cc_session_id

    while IFS= read -r marker; do
        [ -z "$marker" ] && continue
        enumerated=$((enumerated + 1))
        # Malformed marker: cc_session_id is unreadable, so it cannot be correlated -- skip it
        # without selecting it (never resurrect an arbitrary pick for a marker that fails to
        # parse).
        jq empty "$marker" 2>/dev/null || continue
        marker_cc_session_id=$(jq -r '.cc_session_id // empty' "$marker" 2>/dev/null)
        if [ -n "$CC_SESSION_ID" ] && [ -n "$marker_cc_session_id" ] && [ "$marker_cc_session_id" = "$CC_SESSION_ID" ]; then
            MARKER_FILE="$marker"
            TASK_DIR=$(dirname "$marker")
            LOOP_GUARD_FILE="$TASK_DIR/.postflight-loop-guard"
            return 0
        fi
    done < <(find specs -maxdepth 3 -name ".postflight-pending" -type f 2>/dev/null)

    # Global-fallback marker (backward compatibility during migration) is subject to the same
    # correlation check -- an uncorrelated global marker must not be selected either, or the
    # defect this fix removes would reopen through this second door.
    if [ -z "$MARKER_FILE" ] && [ -f "specs/.postflight-pending" ]; then
        enumerated=$((enumerated + 1))
        if jq empty "specs/.postflight-pending" 2>/dev/null; then
            marker_cc_session_id=$(jq -r '.cc_session_id // empty' "specs/.postflight-pending" 2>/dev/null)
            if [ -n "$CC_SESSION_ID" ] && [ -n "$marker_cc_session_id" ] && [ "$marker_cc_session_id" = "$CC_SESSION_ID" ]; then
                MARKER_FILE="specs/.postflight-pending"
                LOOP_GUARD_FILE="specs/.postflight-loop-guard"
                TASK_DIR="specs"
            fi
        fi
    fi

    if [ -z "$MARKER_FILE" ]; then
        log_debug "No correlated marker: enumerated $enumerated marker(s), stopping CC_SESSION_ID='$CC_SESSION_ID'"
    fi
}

# Check if we're in a potential infinite loop
check_loop_guard() {
    if [ -f "$LOOP_GUARD_FILE" ]; then
        local count
        count=$(cat "$LOOP_GUARD_FILE" 2>/dev/null || echo "0")
        if [ "$count" -ge "$MAX_CONTINUATIONS" ]; then
            # Three removal paths touch this marker/loop-guard pair; each must be
            # textually distinguishable in the log so a reader can tell them apart:
            #   1. This branch (cap reached) -- labelled "CAP-REACHED DELETE:" below.
            #   2. The stop_hook_active branch in main() -- labelled "STOP-HOOK-ACTIVE DELETE:".
            #   3. skill_cleanup's own `rm -f` (scripts/skill-base.sh) -- a silent removal with
            #      no log line at all; its absence from this log is how it is identified.
            local marker_session_id=""
            [ -n "$MARKER_FILE" ] && marker_session_id=$(jq -r '.session_id // empty' "$MARKER_FILE" 2>/dev/null)
            local marker_task_number=""
            [ -n "$TASK_DIR" ] && marker_task_number=$(basename "$TASK_DIR")
            log_debug "CAP-REACHED DELETE: marker=$MARKER_FILE task=$marker_task_number count=$count >= $MAX_CONTINUATIONS session_id=$marker_session_id cc_session_id=$CC_SESSION_ID"
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
            local sha_session_id sha_task_number
            sha_session_id=$(jq -r '.session_id // empty' "$MARKER_FILE" 2>/dev/null)
            sha_task_number=$(basename "$TASK_DIR")
            log_debug "STOP-HOOK-ACTIVE DELETE: marker=$MARKER_FILE task=$sha_task_number stop_hook_active=true session_id=$sha_session_id cc_session_id=$CC_SESSION_ID"
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
        # jq's `//` alternative operator only fires when the RHS field is absent/null -- it
        # never fires on a parse error, so an unguarded `.reason // default` extraction
        # collapses "marker does not parse" into the same default as "marker parses but has no
        # .reason", with the `2>/dev/null` swallowing jq's own diagnostic. Guard with `jq empty`
        # first (mirrors the identical check in events-log-lifecycle.sh's SubagentStop branch)
        # so a parse failure gets its own diagnostic reason instead.
        local reason
        if jq empty "$MARKER_FILE" 2>/dev/null; then
            reason=$(jq -r '.reason // "Postflight operations pending"' "$MARKER_FILE" 2>/dev/null)
        else
            local parse_err
            parse_err=$(jq empty "$MARKER_FILE" 2>&1 >/dev/null | head -1)
            reason="Postflight marker at $MARKER_FILE could not be parsed as JSON: $parse_err"
        fi
        log_debug "Blocking stop: $reason"

        # Return block decision. jq -n --arg safely escapes quotes, backslashes, and newlines in
        # $reason, so both branches above converge on one JSON-safe construction.
        echo "{\"decision\": \"block\", \"reason\": $(jq -n --arg r "$reason" '$r')}"
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
