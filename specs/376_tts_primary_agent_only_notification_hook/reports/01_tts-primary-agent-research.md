# Research: TTS Notification -- Primary Agent Only with Notification Hook

**Task**: #376
**Date**: 2026-04-08
**Status**: Complete

---

## Problem Statement

The current `tts-notify.sh` hook fires on every `Stop` event regardless of whether the caller is the primary (top-level) agent or a spawned subagent. This causes unwanted TTS announcements when subagents complete work. Additionally, there is no `Notification` hook configured, so TTS does not fire when the primary agent needs interactive feedback (permission prompts, idle prompts, elicitation dialogs).

**Goals**:
1. Suppress TTS for subagent completions
2. Add TTS for primary agent interactive feedback events

---

## Current Configuration

### tts-notify.sh (`.claude/hooks/tts-notify.sh`)

- Uses Piper TTS with `en_US-lessac-medium.onnx` model
- Detects WezTerm tab number and announces "Tab N"
- Has cooldown logic (default 10s) via `/tmp/claude-tts-last-notify`
- Supports PulseAudio (`paplay`) and ALSA (`aplay`) backends
- **No subagent detection** -- fires on every `Stop` event

### settings.json Hook Bindings

| Event | Hooks | TTS-relevant |
|-------|-------|-------------|
| `Stop` | post-command.sh, **tts-notify.sh**, wezterm-notify.sh | Yes -- fires for ALL agents |
| `SubagentStop` | subagent-postflight.sh | No -- separate event, not TTS |
| `SessionStart` | wezterm-clear, log-session, ready-signal | No |
| `UserPromptSubmit` | wezterm-task-number, wezterm-clear-status | No |
| `PreToolUse` | state.json validation | No |
| `PostToolUse` | state.json sync validation | No |
| **`Notification`** | **Not configured** | **Missing** |

---

## Key Finding: `agent_id` Field

Claude Code hook commands receive JSON on stdin. The JSON schema includes:

| Field | Present in Primary | Present in Subagent | Notes |
|-------|-------------------|--------------------|----|
| `session_id` | Yes | Yes | Same for all |
| `cwd` | Yes | Yes | Working directory |
| `hook_event_name` | Yes | Yes | Event that triggered |
| `agent_id` | **No** | **Yes** | Unique subagent identifier |
| `agent_type` | Sometimes | Yes | Agent name (e.g., "Explore") |
| `stop_hook_active` | Yes (Stop only) | Yes (Stop only) | Prevents infinite loops |

**The definitive signal**: If `agent_id` is present in the hook input JSON, the hook is executing inside a subagent. If absent, it is the primary agent.

---

## Available Hook Events for Interactive Feedback

The `Notification` hook event fires on these notification types:

| Notification Type | When It Fires | User Action Needed |
|-------------------|---------------|-------------------|
| `permission_prompt` | Claude needs tool permission | Yes -- approve/deny |
| `idle_prompt` | Claude is waiting for user input | Yes -- provide input |
| `elicitation_dialog` | MCP server requests user input | Yes -- respond |
| `auth_success` | Authentication completed | No -- informational |

All of these except `auth_success` represent cases where the primary agent is waiting for user attention -- ideal TTS trigger points.

---

## Implementation Plan

### Change 1: Add `agent_id` Guard to `tts-notify.sh`

Insert after the `TTS_ENABLED` check (line 38), before the piper availability check:

```bash
# Read hook input from stdin
HOOK_INPUT=$(cat)

# Skip TTS for subagents (agent_id is only present in subagent context)
AGENT_ID=$(echo "$HOOK_INPUT" | jq -r '.agent_id // empty' 2>/dev/null)
if [[ -n "$AGENT_ID" ]]; then
    log "Subagent detected (agent_id=$AGENT_ID) - skipping TTS"
    exit_success
fi
```

**Important**: Since the script currently does not read stdin at all, adding `cat` has no side effects. The JSON is passed on stdin by Claude Code's hook executor.

### Change 2: Add `Notification` Hook to `settings.json`

Add a new hook event entry alongside the existing `Stop`, `SubagentStop`, etc.:

```json
"Notification": [
  {
    "matcher": "*",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
      }
    ]
  }
]
```

The `agent_id` guard in Change 1 protects this too -- if a subagent triggers a notification, it won't fire TTS.

### Optional: Notification Type Filtering

For more granular control, the `Notification` hook input JSON includes a `type` field. You could filter to only TTS on actionable notifications:

```bash
NOTIF_TYPE=$(echo "$HOOK_INPUT" | jq -r '.type // empty' 2>/dev/null)
if [[ "$NOTIF_TYPE" == "auth_success" ]]; then
    log "Non-actionable notification type: $NOTIF_TYPE - skipping TTS"
    exit_success
fi
```

This is optional since `auth_success` is rare and harmless to announce.

### Optional: Differentiated TTS Messages

Currently TTS just says "Tab N". With the Notification hook, you could differentiate:

```bash
EVENT=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // "stop"' 2>/dev/null)
case "$EVENT" in
    "Notification")
        MESSAGE="${TAB_LABEL}needs attention"
        ;;
    "Stop")
        MESSAGE="${TAB_LABEL%: }"  # existing behavior
        ;;
esac
```

---

## Files to Modify

| File | Change | Lines Affected |
|------|--------|---------------|
| `.claude/hooks/tts-notify.sh` | Add stdin read + `agent_id` guard | Insert after line 38 (~6 lines) |
| `.claude/settings.json` | Add `Notification` hook entry | Insert in `hooks` object (~10 lines) |

---

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `cat` blocks if no stdin | Low -- Claude Code always provides stdin JSON | Add timeout: `timeout 1s cat` |
| `agent_id` field renamed in future | Very low -- stable API | Field is documented in official hooks reference |
| Notification hook fires too often | Low -- only on permission/idle/elicitation | Existing cooldown logic (10s) already handles this |
| TTS plays during active typing | Medium -- Stop fires after every response | Existing cooldown handles most cases; WezTerm tab focus detection could further filter |

---

## References

- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide.md) -- Official hook documentation
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks.md) -- Event types and JSON schemas
- [Claude Code Subagents](https://code.claude.com/docs/en/sub-agents.md) -- Subagent lifecycle
- Current implementation: `.claude/hooks/tts-notify.sh` (119 lines)
- Current hook config: `.claude/settings.json` (lines 34-126)
