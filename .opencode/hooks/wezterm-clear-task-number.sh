#!/bin/bash
# Clear TASK_NUMBER user variable for WezTerm tab title
# Called from SessionStart hook to reset task number on session events
#
# Related: Task 802 - Fix WezTerm tab task number clearing
# Related: wezterm-task-number.sh - Sets task number on workflow commands
set -euo pipefail

# Only run in WezTerm
if [[ -z "${WEZTERM_PANE:-}" ]]; then
    echo '{}'
    exit 0
fi

# Get the TTY for the current pane
PANE_TTY=$(wezterm cli list --format=json 2>/dev/null | \
    jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tty_name" 2>/dev/null || echo "")

if [[ -n "$PANE_TTY" ]] && [[ -w "$PANE_TTY" ]]; then
    # Clear TASK_NUMBER via OSC 1337
    printf '\033]1337;SetUserVar=TASK_NUMBER=\007' > "$PANE_TTY"
fi

echo '{}'
exit 0
