# Neovim Integration Guide

This guide documents the integration between Claude Code and Neovim, including hook-based readiness signaling and TTS/STT functionality.

## Overview

The Claude Code Neovim integration provides:
- **Instant sidebar readiness** via SessionStart hooks
- **TTS notifications** when Claude completes work
- **STT input** for voice-driven prompts in Claude Code sidebar

## SessionStart Hook: Sidebar Readiness Signal

### Problem

When opening Claude Code from Neovim, the sidebar needs to know when Claude is ready to accept input. Without this signal, Neovim waits for a TextChanged fallback (~30 seconds delay).

### Solution

The `SessionStart` hook fires `claude-ready-signal.sh`, which signals Neovim via `nvim --remote-expr`:

**Hook Configuration** (`.claude/settings.json`):
```json
"SessionStart": [
  {
    "matcher": "startup",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/log-session.sh 2>/dev/null || echo '{}'"
      },
      {
        "type": "command",
        "command": "bash ~/.config/nvim/scripts/claude-ready-signal.sh 2>/dev/null || echo '{}'"
      }
    ]
  }
]
```

**Signal Script** (`~/.config/nvim/scripts/claude-ready-signal.sh`):
```bash
#!/usr/bin/env bash
# Claude Code SessionStart hook - signals Neovim when ready

if [ -n "$NVIM" ]; then
  # Use --remote-expr to execute Lua directly in Neovim context
  # This avoids sending keystrokes to the terminal window
  nvim --server "$NVIM" --remote-expr \
    'luaeval("require(\"neotex.plugins.ai.claude.utils.terminal-state\").on_claude_ready()")' \
    >/dev/null 2>&1
fi
```

### How It Works

1. User opens Claude Code from Neovim (`:ClaudeCode` or `<C-c>`)
2. Neovim creates terminal buffer (state: `OPENING`)
3. Claude Code starts, runs SessionStart hooks
4. `claude-ready-signal.sh` fires, calls `on_claude_ready()` in Neovim
5. Neovim state changes to `READY`, flushes pending commands
6. Sidebar becomes responsive **immediately** (no 30s delay)

### Fallback Mechanism

If the hook is missing or fails:
- Neovim falls back to `TextChanged` autocommand
- Detects Claude prompt via pattern matching
- ~30 second delay before sidebar responds

## TTS (Text-to-Speech) Notifications

### Overview

The `tts-notify.sh` hook announces Claude Code events using Piper TTS. It triggers on both Stop events (Claude finished) and Notification events (Claude needs input).

For comprehensive TTS/STT documentation including software dependencies, model setup, and workflow examples, see the [TTS/STT Integration Guide](tts-stt-integration.md).

**Hook Configuration** (`.claude/settings.json`):
```json
"Stop": [
  {
    "matcher": "*",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
      }
    ]
  }
],
"Notification": [
  {
    "matcher": "permission_prompt|idle_prompt|elicitation_dialog",
    "hooks": [
      {
        "type": "command",
        "command": "bash .claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
      }
    ]
  }
]
```

### Features

- **WezTerm tab detection**: Announces "Tab 5" (completion) or "Tab 5 needs permission" (input-needed)
- **Event-specific messages**: Different messages for Stop, permission prompts, idle prompts, and questions
- **Cooldown**: 10-second minimum between notifications
- **Background execution**: Non-blocking with 10s timeout
- **Graceful fallback**: Silently skips if Piper/audio not available

### Configuration

Environment variables (set in shell or `.bashrc`):
```bash
export PIPER_MODEL="$HOME/.local/share/piper/en_US-lessac-medium.onnx"
export TTS_COOLDOWN=10           # seconds between notifications
export TTS_ENABLED=1             # set to 0 to disable
```

### Toggling TTS

**Per-project toggle** (modifies `.claude/tts/tts-config.sh`):
```vim
<leader>at
```

See `lua/neotex/plugins/editor/which-key.lua` for implementation.

## STT (Speech-to-Text) Input

### Overview

Vosk-based offline speech recognition for voice input in Claude Code sidebar and regular buffers.

### Keybindings

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>vr` | Normal | Start recording |
| `<leader>vs` | Normal | Stop recording and transcribe |
| `<leader>vv` | Normal | Toggle recording |
| `<leader>vh` | Normal | Health check (verify dependencies) |
| `<C-\>` | Normal | Toggle recording (alternative binding) |
| `<C-\>` | Terminal | Toggle recording (works in Claude Code sidebar) |

### Terminal Mode Support

Terminal buffers (like Claude Code) intercept most keybindings. The `<C-\>` mapping includes a terminal-mode variant:

**Implementation** (`lua/neotex/plugins/tools/stt/init.lua`):
```lua
-- Terminal-mode mapping for Ctrl-\ (required for Claude Code sidebar)
vim.keymap.set('t', '<C-\\>', function()
  -- Exit terminal mode temporarily to allow STT to function
  vim.cmd('stopinsert')
  M.toggle_recording()
end, {
  noremap = true,
  silent = true,
  desc = 'STT: Toggle recording (terminal mode)'
})
```

**Behavior**:
1. Press `<C-\>` in Claude Code sidebar
2. Neovim exits terminal mode (`stopinsert`)
3. STT starts recording
4. Speak your prompt
5. Press `<C-\>` again to stop and transcribe
6. Text inserts at cursor position

### Dependencies

- `parecord` (PulseAudio or PipeWire)
- Python 3 with `vosk` package
- Vosk model: `~/.local/share/vosk/vosk-model-small-en-us`
- Transcription script: `~/.local/bin/vosk-transcribe.py`

### Health Check

Verify STT setup:
```vim
:STTHealth
" or
<leader>vh
```

## Troubleshooting

### Sidebar Still Has 30s Delay

**Check hook is registered**:
```bash
jq '.hooks.SessionStart' .claude/settings.json
```

Should show `claude-ready-signal.sh` in the hooks array.

**Check signal script exists**:
```bash
ls -la ~/.config/nvim/scripts/claude-ready-signal.sh
```

**Test hook manually**:
```bash
export NVIM=/tmp/nvim-sock-12345  # get from :echo v:servername
bash ~/.config/nvim/scripts/claude-ready-signal.sh
```

### STT Doesn't Work in Claude Code Sidebar

**Verify terminal-mode mapping**:
```vim
:verbose map <C-\>
```

Should show both normal-mode and terminal-mode mappings.

**Check STT is functional**:
```vim
:STTHealth
```

**Test in regular buffer first**, then try in Claude Code.

### TTS Not Announcing Completions

**Check TTS is enabled**:
```bash
echo $TTS_ENABLED  # should be 1
```

**Check Piper is installed**:
```bash
which piper
```

**Check model exists**:
```bash
ls -la ~/.local/share/piper/en_US-lessac-medium.onnx
```

**Check logs**:
```bash
tail -20 specs/tmp/claude-tts-notify.log
```

## Architecture

### Event Flow

```
User opens Claude Code
    |
    v
Neovim creates terminal buffer (state: OPENING)
    |
    v
Claude Code starts
    |
    v
SessionStart hook fires
    |
    +-->  log-session.sh (logging)
    |
    +-->  claude-ready-signal.sh (Neovim signal)
         |
         v
    nvim --remote-expr calls on_claude_ready()
         |
         v
    Neovim state: READY
    Flushes pending commands
         |
         v
    Sidebar responsive (no delay)
```

### Stop Hook Flow

```
Claude completes task
    |
    v
Stop hook fires
    |
    +-->  post-command.sh (cleanup/logging)
    |
    +-->  tts-notify.sh (audio notification)
         |
         +-->  Check cooldown (10s)
         +-->  Get WezTerm tab number
         +-->  Generate message: "Tab 5"
         +-->  Speak with Piper (background, 10s timeout)
```

### Notification Hook Flow

```
Claude needs user input
    |
    v
Notification hook fires (permission_prompt, idle_prompt, elicitation_dialog)
    |
    +-->  tts-notify.sh (audio notification)
         |
         +-->  Read event type from stdin JSON
         +-->  Check cooldown (10s)
         +-->  Get WezTerm tab number
         +-->  Generate message: "Tab 5 needs permission" / "Tab 5 needs input" / "Tab 5 has a question"
         +-->  Speak with Piper (background, 10s timeout)
```

## Related Files

### Claude Code
- `.claude/settings.json` - Hook configuration
- `.claude/hooks/log-session.sh` - Session logging
- `.claude/hooks/tts-notify.sh` - TTS announcements
- `.claude/hooks/post-command.sh` - Post-command cleanup

### Neovim
- `~/.config/nvim/scripts/claude-ready-signal.sh` - SessionStart signal
- `~/.config/nvim/lua/neotex/plugins/ai/claude/claude-session/terminal-state.lua` - Terminal state management
- `~/.config/nvim/lua/neotex/plugins/tools/stt/init.lua` - STT plugin
- `~/.config/nvim/docs/MAPPINGS.md` - Keybinding reference

## See Also

- [TTS/STT Integration Guide](tts-stt-integration.md) - Complete TTS/STT documentation with software dependencies
- [Permission Configuration](../../../../../../.claude/docs/guides/permission-configuration.md) - Hook permissions
- [User Guide](../../../../../../.claude/docs/guides/user-guide.md) - General Claude Code usage
- Neovim STT README: `~/.config/nvim/lua/neotex/plugins/tools/README.md`
