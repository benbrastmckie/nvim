#!/bin/bash
# Validate state.json and TODO.md are synchronized
# Called after writes to specs/

STATE_FILE="specs/state.json"
TODO_FILE="specs/TODO.md"

# Check both files exist
if [[ ! -f "$STATE_FILE" ]]; then
    echo '{"additionalContext": "Warning: state.json not found"}'
    exit 0
fi

if [[ ! -f "$TODO_FILE" ]]; then
    echo '{"additionalContext": "Warning: TODO.md not found"}'
    exit 0
fi

# Quick validation: check state.json is valid JSON
if ! jq empty "$STATE_FILE" 2>/dev/null; then
    echo '{"additionalContext": "Error: state.json is not valid JSON"}'
    exit 1
fi

# Success - PostToolUse hooks don't use "decision" field
echo '{}'
exit 0
