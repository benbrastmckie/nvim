#!/bin/bash
# Log session events
# Called on SessionStart

LOG_DIR=".claude/logs"
LOG_FILE="$LOG_DIR/sessions.log"

# Create log directory if needed
mkdir -p "$LOG_DIR"

# Get timestamp
TIMESTAMP=$(date -Iseconds)

# Log session start
echo "[$TIMESTAMP] Session started" >> "$LOG_FILE"

# Output success - SessionStart hooks don't use "decision" field
echo '{}'
exit 0
