#!/bin/bash
# WezTerm tab notification clear hook for Claude Code
# Clears CLAUDE_STATUS user variable via OSC 1337 when user submits prompt
#
# Integration: Called from UserPromptSubmit hook in .claude/settings.json
# Requirements: wezterm with user variable support, jq for JSON parsing
#
# Clearing the variable ensures the tab color returns to normal after
# the user responds to Claude's input request.
#
# Note: Claude Code hooks run with redirected stdio (stdout is a socket),
# so we must write the escape sequence directly to the pane's TTY.

set -euo pipefail

# Helper: return success JSON for hook
exit_success() {
    echo '{}'
    exit 0
}

# Only run in WezTerm
if [[ -z "${WEZTERM_PANE:-}" ]]; then
    exit_success
fi

# Get the TTY for the current pane from WezTerm CLI
# Claude Code hooks have redirected stdio, so we cannot use /dev/tty
PANE_TTY=$(wezterm cli list --format=json 2>/dev/null | \
    jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tty_name" 2>/dev/null || echo "")

# Check if we found a writable TTY
if [[ -z "$PANE_TTY" ]] || [[ ! -w "$PANE_TTY" ]]; then
    exit_success
fi

# Clear CLAUDE_STATUS user variable via OSC 1337
# Set to empty string (empty base64 value)
# Write to the pane's TTY (not stdout)
printf '\033]1337;SetUserVar=CLAUDE_STATUS=\007' > "$PANE_TTY"

exit_success
