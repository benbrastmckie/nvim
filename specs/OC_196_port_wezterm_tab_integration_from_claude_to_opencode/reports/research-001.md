# Research Report: Task OC_196

**Task**: OC_196 - port_wezterm_tab_integration_from_claude_to_opencode
**Started**: 2026-03-13T00:00:00Z
**Completed**: 2026-03-13T00:45:00Z
**Effort**: 0.5-1 hours
**Dependencies**: None
**Sources/Inputs**: Codebase (.claude/, .opencode/), previous research reports (task 107)
**Artifacts**: specs/OC_196_port_wezterm_tab_integration_from_claude_to_opencode/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

The wezterm tab integration features have been **mostly ported** from .claude/ to .opencode/, with the .opencode/ version actually being **more advanced** in some areas. However, there are **two significant gaps** that need to be addressed:

1. **Notification Hook Missing**: The .opencode/ settings.json lacks the `Notification` hook for `permission_prompt|idle_prompt|elicitation_dialog` events, which is documented but not implemented
2. **Claude-Ready Signal Missing**: The `claude-ready-signal.sh` hook for Neovim sidebar readiness is absent from .opencode/ SessionStart hooks

**Key Finding**: The .opencode/ `wezterm-task-number.sh` is actually **more feature-rich** than the .claude/ version - it extracts and sets TASK_NAME and TASK_ACTION variables in addition to TASK_NUMBER.

## Current State Comparison

### Hook Files Status

| Hook File | .claude/ | .opencode/ | Status | Notes |
|-----------|----------|------------|--------|-------|
| wezterm-task-number.sh | [64 lines] | [93 lines] | **Enhanced** | .opencode/ adds TASK_NAME and TASK_ACTION |
| wezterm-notify.sh | [58 lines] | [58 lines] | **Identical** | Both set CLAUDE_STATUS=needs_input |
| wezterm-clear-status.sh | [42 lines] | [42 lines] | **Identical** | Clears CLAUDE_STATUS |
| wezterm-clear-task-number.sh | [25 lines] | [25 lines] | **Identical** | Clears TASK_NUMBER on session start |
| tts-notify.sh | [144 lines] | [144 lines] | **Adapted** | .opencode/ uses /tmp/opencode-* paths |

### Settings.json Hook Registration

#### .claude/settings.json (Complete)

```json
{
  "SessionStart": [
    { "matcher": "*", "hooks": ["wezterm-clear-task-number.sh"] },
    { "matcher": "startup", "hooks": ["log-session.sh", "claude-ready-signal.sh"] }
  ],
  "UserPromptSubmit": [
    { "matcher": "*", "hooks": ["wezterm-task-number.sh", "wezterm-clear-status.sh"] }
  ],
  "Stop": [
    { "matcher": "*", "hooks": ["post-command.sh", "tts-notify.sh", "wezterm-notify.sh"] }
  ],
  "Notification": [
    { "matcher": "permission_prompt|idle_prompt|elicitation_dialog", "hooks": ["tts-notify.sh"] }
  ],
  "SubagentStop": [
    { "matcher": "*", "hooks": ["subagent-postflight.sh"] }
  ]
}
```

#### .opencode/settings.json (Incomplete)

```json
{
  "SessionStart": [
    { "matcher": "startup", "hooks": ["log-session.sh", "wezterm-clear-task-number.sh"] }
    // MISSING: claude-ready-signal.sh
  ],
  "UserPromptSubmit": [
    { "matcher": "*", "hooks": ["wezterm-clear-status.sh", "wezterm-task-number.sh"] }
    // Note: Different order than .claude/
  ],
  "Stop": [
    { "matcher": "*", "hooks": ["post-command.sh", "wezterm-notify.sh", "tts-notify.sh"] }
  ],
  // MISSING: Notification hook entirely
  "SubagentStop": [
    { "matcher": "*", "hooks": ["subagent-postflight.sh"] }
  ]
}
```

### What's Already Ported

**Status: [COMPLETE]**

1. **Task Number Display** (.opencode/hooks/wezterm-task-number.sh)
   - Parses /research N, /plan N, /implement N, /revise N commands
   - Sets TASK_NUMBER via OSC 1337
   - **Bonus**: Also extracts TASK_NAME from state.json
   - **Bonus**: Also sets TASK_ACTION (e.g., "RESEARCHING", "PLANNING")
   - Clears variables on non-workflow commands

2. **Tab Notification on Stop** (.opencode/hooks/wezterm-notify.sh)
   - Sets CLAUDE_STATUS=needs_input when Claude stops
   - Triggers amber background in WezTerm inactive tabs
   - Called from Stop hook

3. **Notification Clearing** (.opencode/hooks/wezterm-clear-status.sh)
   - Clears CLAUDE_STATUS when user submits prompt
   - Restores normal tab appearance
   - Called from UserPromptSubmit hook

4. **Session Cleanup** (.opencode/hooks/wezterm-clear-task-number.sh)
   - Clears TASK_NUMBER on SessionStart
   - Prevents stale task numbers across sessions

5. **TTS Notifications** (.opencode/hooks/tts-notify.sh)
   - Announces WezTerm tab number via Piper TTS
   - Uses /tmp/opencode-* paths (adapted from specs/tmp/claude-*)
   - Called from Stop hook

### What's Missing

**Status: [NEEDS IMPLEMENTATION]**

1. **Notification Hook** (.opencode/settings.json)
   - **Gap**: No "Notification" hook event registered
   - **Impact**: TTS does NOT fire on permission_prompt, idle_prompt, or elicitation_dialog
   - **Documentation says**: .opencode/docs/guides/tts-stt-integration.md documents this hook
   - **Actual state**: Not implemented in settings.json

2. **Claude-Ready Signal** (.opencode/settings.json)
   - **Gap**: No claude-ready-signal.sh in SessionStart hook
   - **Impact**: Neovim sidebar has ~30 second delay when opening Claude Code
   - **Location**: scripts/claude-ready-signal.sh exists but not hooked in .opencode/

## Technical Implementation Details

### OSC 1337 Escape Sequences

Both systems use the same OSC 1337 protocol for WezTerm integration:

```
ESC ] 1337 ; SetUserVar=name=base64_value BEL
```

**Variables Set:**

| Variable | Set By | Purpose |
|----------|--------|---------|
| TASK_NUMBER | wezterm-task-number.sh | Task number for tab title |
| TASK_NAME | wezterm-task-number.sh | Task slug for display (opencode only) |
| TASK_ACTION | wezterm-task-number.sh | Current action (RESEARCHING, etc.) (opencode only) |
| CLAUDE_STATUS | wezterm-notify.sh | "needs_input" or empty |

### TTY Access Pattern

Hooks write directly to pane TTY (not stdout) because Claude Code hooks have redirected stdio:

```bash
PANE_TTY=$(wezterm cli list --format=json | \
  jq -r ".[] | select(.pane_id == $WEZTERM_PANE) | .tty_name")
printf '\033]1337;SetUserVar=NAME=base64value\007' > "$PANE_TTY"
```

### Hook Event Flow

```
User Prompt Submit
    │
    ▼
┌─────────────────────────────────────────┐
│ UserPromptSubmit Hook                   │
│                                         │
│ 1. wezterm-clear-status.sh (clears)     │
│ 2. wezterm-task-number.sh (sets)        │
│    - Extracts N from "/research N"      │
│    - Sets TASK_NUMBER=N                 │
│    - [opencode] Sets TASK_NAME          │
│    - [opencode] Sets TASK_ACTION        │
└─────────────────────────────────────────┘
    │
    ▼
Claude Processes Request
    │
    ▼
┌─────────────────────────────────────────┐
│ Stop Hook                               │
│                                         │
│ 1. post-command.sh                      │
│ 2. wezterm-notify.sh (sets amber)       │
│    - Sets CLAUDE_STATUS=needs_input     │
│ 3. tts-notify.sh (audio)                │
│    - "Tab N"                            │
└─────────────────────────────────────────┘
    │
    ▼
User Sees Amber Tab / Hears Audio
```

### Notification Hook (Missing in opencode)

```
Claude Needs Input (permission/question/idle)
    │
    ▼
┌─────────────────────────────────────────┐
│ [MISSING] Notification Hook             │
│                                         │
│ tts-notify.sh should fire here          │
│ - permission_prompt: "Tab N"            │
│ - idle_prompt: "Tab N"                  │
│ - elicitation_dialog: "Tab N"           │
└─────────────────────────────────────────┘
```

## Opencode-Specific Adaptations

### 1. Enhanced Task Information

.opencode/ hooks extract additional context from state.json:

```bash
# From wezterm-task-number.sh (opencode version)
TASK_NAME=$(jq -r --arg n "$TASK_NUMBER" \
    '.active_projects[] | select(.project_number == ($n | tonumber)) | .project_name' \
    specs/state.json 2>/dev/null || echo "")

# TASK_ACTION is derived from command and uppercased:
# research -> RESEARCHING, plan -> PLANNING, etc.
```

### 2. Path Adaptations

| .claude/ | .opencode/ |
|----------|------------|
| specs/tmp/claude-tts-last-notify | /tmp/opencode-tts-last-notify |
| specs/tmp/claude-tts-notify.log | /tmp/opencode-tts-notify.log |
| specs/tmp/claude-tts-$$.wav | /tmp/opencode-tts-$$.wav |

### 3. Hook Timeouts

.opencode/ settings.json adds timeout values to hooks:

```json
{
  "command": "bash .opencode/hooks/wezterm-clear-task-number.sh",
  "timeout": 5000
}
```

## Recommendations for Completing the Port

### Priority 1: Add Notification Hook (High Impact)

Add to .opencode/settings.json:

```json
"Notification": [
  {
    "matcher": "permission_prompt|idle_prompt|elicitation_dialog",
    "hooks": [
      {
        "type": "command",
        "command": "bash .opencode/hooks/tts-notify.sh 2>/dev/null || echo '{}'",
        "timeout": 10000
      }
    ]
  }
]
```

**Note**: Documentation at `.opencode/docs/guides/tts-stt-integration.md` already describes this configuration but it's not actually implemented in settings.json.

### Priority 2: Add Claude-Ready Signal (Medium Impact)

Add to .opencode/settings.json SessionStart hook:

```json
{
  "matcher": "startup",
  "hooks": [
    {
      "type": "command",
      "command": "bash .opencode/hooks/log-session.sh 2>/dev/null || echo '{}'"
    },
    {
      "type": "command",
      "command": "bash ~/.config/nvim/scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'",
      "timeout": 5000
    },
    {
      "type": "command",
      "command": "bash .opencode/hooks/wezterm-clear-task-number.sh 2>/dev/null || echo '{}'",
      "timeout": 5000
    }
  ]
}
```

**Note**: The script `scripts/claude-ready-signal.sh` already exists and works for both systems.

### Priority 3: Documentation Updates (Low Impact)

1. Update `.opencode/context/project/hooks/wezterm-integration.md` to mention:
   - TASK_NAME and TASK_ACTION variables (opencode enhancements)
   - Notification hook status (once implemented)

2. Update `.opencode/docs/guides/tts-stt-integration.md` to reflect actual settings.json state

## Technical Considerations

### Hook Event Availability

**Question**: Does opencode actually support the Notification hook event?

**Evidence**:
- .opencode/docs/guides/tts-stt-integration.md documents it
- .opencode/hooks/tts-notify.sh has code to read `notification_type` from stdin
- But .opencode/settings.json doesn't register it

**Recommendation**: Attempt to add the Notification hook. If opencode doesn't support it, the hook simply won't fire (graceful degradation).

### State File Location

.opencode/ correctly uses `specs/state.json` (same as .claude/), so the TASK_NAME extraction in wezterm-task-number.sh will work.

### Hook Ordering

.claude/ runs wezterm-task-number.sh BEFORE wezterm-clear-status.sh
.opencode/ runs wezterm-clear-status.sh BEFORE wezterm-task-number.sh

**Impact**: Negligible - both achieve the same end state. The order matters only if there's a race condition, which there isn't in this case.

## Context Extension Recommendations

Based on this research, the following context documentation could be created:

1. **`.opencode/context/project/hooks/hook-events.md`**
   - Document which hook events opencode supports
   - Compare with Claude Code's documented events
   - Note any limitations or differences

2. **`.opencode/context/project/hooks/notification-hook.md`**
   - Document the Notification hook specifically
   - List supported notification types
   - Provide configuration examples

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| opencode doesn't support Notification hook | Medium | Medium | Add hook and test; graceful degradation if unsupported |
| claude-ready-signal.sh doesn't work with opencode | Low | High | Test with Neovim; script uses standard nvim --remote-expr |
| Hook ordering differences cause issues | Low | Low | Both orders are functionally equivalent |
| Documentation inconsistency causes confusion | High | Low | Update docs after implementation |

## Decisions

1. **Notification hook should be added** - Even though it's not currently in settings.json, the documentation suggests it should exist and the hook script supports it

2. **Claude-ready signal should be added** - The script exists and is compatible; only the settings.json hook registration is missing

3. **No changes needed to hook scripts** - All wezterm-*.sh scripts are already fully functional and adapted for opencode

4. **TASK_NAME and TASK_ACTION are valuable enhancements** - These should be documented as opencode-specific improvements

## Appendix

### Files Examined

- .claude/settings.json
- .opencode/settings.json
- .claude/hooks/wezterm-task-number.sh
- .opencode/hooks/wezterm-task-number.sh
- .claude/hooks/wezterm-notify.sh
- .opencode/hooks/wezterm-notify.sh
- .claude/hooks/wezterm-clear-status.sh
- .opencode/hooks/wezterm-clear-status.sh
- .claude/hooks/wezterm-clear-task-number.sh
- .opencode/hooks/wezterm-clear-task-number.sh
- .claude/hooks/tts-notify.sh
- .opencode/hooks/tts-notify.sh
- scripts/claude-ready-signal.sh
- lua/neotex/lib/wezterm.lua
- lua/neotex/config/autocmds.lua
- .opencode/context/project/hooks/wezterm-integration.md
- .claude/docs/guides/neovim-integration.md
- .opencode/docs/guides/tts-stt-integration.md
- specs/archive/107_port_tts_notification_hooks/reports/research-001.md

### Search Queries Used

1. `glob(".claude/hooks/*.sh")` - List all .claude hook files
2. `glob(".opencode/hooks/*.sh")` - List all .opencode hook files
3. `grep "Notification" .claude/settings.json` - Find Notification hook
4. `grep "Notification" .opencode/settings.json` - Check for Notification hook
5. `diff -r .claude/hooks/wezterm*.sh .opencode/hooks/wezterm*.sh` - Compare hook implementations
