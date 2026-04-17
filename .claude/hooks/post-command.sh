#!/bin/bash
# Post-command cleanup and logging
# Called on Stop event

LOG_DIR=".claude/logs"
LOG_FILE="$LOG_DIR/sessions.log"

# Create log directory if needed
mkdir -p "$LOG_DIR"

# Get timestamp
TIMESTAMP=$(date -Iseconds)

# Log session end
echo "[$TIMESTAMP] Response completed" >> "$LOG_FILE"

# Success - Stop hooks use different schema than PreToolUse
echo '{}'
exit 0
