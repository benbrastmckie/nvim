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
        "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/log-session.sh 2>/dev/null || echo '{}'"
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

The `tts-notify.sh` hook announces Claude Code events using piper neural TTS (streamed to `paplay`). It triggers on both Stop events (Claude finished) and Notification events (Claude needs input).

For comprehensive TTS/STT documentation including software dependencies, model setup, and workflow examples, see the [TTS/STT Integration Guide](tts-stt-integration.md).

**Hook Configuration** (`.claude/settings.json`):
```json
"Stop": [
  {
    "matcher": "*",
    "hooks": [
      {
        "type": "command",
        "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
      }
    ]
  }
],
"Notification": [
  {
    "matcher": "permission_prompt|elicitation_dialog",
    "hooks": [
      {
        "type": "command",
        "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/tts-notify.sh 2>/dev/null || echo '{}'"
      }
    ]
  }
]
```

### Features

- **WezTerm tab detection**: Announces "Tab 5" (completion) or "Tab 5 needs permission" (input-needed)
- **Event-specific messages**: Different messages for Stop, permission prompts, and questions
- **Cooldown**: 10-second minimum between notifications
- **Background execution**: Non-blocking with 10s timeout
- **Graceful fallback**: Silently skips if piper, the voice model, or audio is not available

### Configuration

Environment variables (set in shell or `.bashrc`):
```bash
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

`<C-'>` is the dictation key. In a Claude Code buffer it toggles Claude Code's own voice
recording; in every other buffer it toggles Vosk-based offline speech recognition and
inserts the transcript at the cursor.

### Keybindings

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>vr` | Normal | Start recording |
| `<leader>vs` | Normal | Stop recording and transcribe |
| `<leader>vv` | Normal | Toggle recording |
| `<leader>vh` | Normal | Health check (verify dependencies) |
| `<C-'>` | Normal | Claude Code push-to-talk in a Claude Code buffer, Vosk toggle elsewhere |
| `<C-'>` | Insert | Toggle Vosk recording |
| `<C-'>` | Terminal | Claude Code push-to-talk in a Claude Code buffer, Vosk toggle elsewhere |

### Terminal Mode Support

Terminal buffers send keystrokes straight to the running program, so `<C-'>` carries a
terminal-mode mapping that branches on the buffer
(`lua/neotex/plugins/tools/stt/init.lua`).

**In a Claude Code buffer** the key drives Claude Code's own voice mode. Neovim writes the
kitty-keyboard encoding of `ctrl+'` (`ESC[39;5u`) to the terminal channel, where Claude Code
matches its `voice:pushToTalk` binding:

1. Tap `<C-'>` to start recording
2. Speak your prompt
3. Tap `<C-'>` again to stop
4. The transcript lands in the Claude Code prompt, editable, rather than being sent

Claude Code ends a hold-mode recording when key events stop arriving rather than when the key
is released, so Neovim repeats the keypress on a timer to hold the key down itself. That is
what makes a tap gesture compatible with an editable transcript: Claude Code's own `tap` mode
submits any transcript of three or more words unconditionally.

Requires `ctrl+'` bound to `voice:pushToTalk` in `~/.claude/keybindings.json`, with
`voice.mode` set to `hold` and `voice.autoSubmit` false in `~/.claude/settings.json`.

**In any other buffer** the key drives Vosk:

1. Press `<C-'>` in the terminal buffer
2. Neovim exits terminal mode (`stopinsert`)
3. Vosk starts recording
4. Press `<C-'>` again to stop and transcribe
5. Text inserts at the cursor position

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
:verbose map <C-'>
```

Should show both normal-mode and terminal-mode mappings.

**Check the key reaches Claude Code**: another terminal-mode mapping on the same key wins
over this one. `lua/neotex/config/keymaps.lua` binds `<C-h>`, `<C-j>`, `<C-k>` and `<C-l>` to
window navigation in terminal buffers, so those keys never reach the program inside.

**Check Claude Code's voice configuration**:
```bash
cat ~/.claude/keybindings.json
python3 -c "import json; print(json.load(open('$HOME/.claude/settings.json'))['voice'])"
```

**Check Vosk is functional** (the non-Claude path):
```vim
:STTHealth
```

**Test in regular buffer first**, then try in Claude Code.

### TTS Not Announcing Completions

**Check TTS is enabled**:
```bash
echo $TTS_ENABLED  # should be 1
```

**Check piper is installed**:
```bash
which piper
ls ~/.local/share/piper/*.onnx   # voice model must exist (or set PIPER_VOICE)
```

**Test piper**:
```bash
echo "test" | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file - | paplay && echo "works"
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
         +-->  Speak with piper | paplay (background, 10s timeout)
```

### Notification Hook Flow

```
Claude needs user input
    |
    v
Notification hook fires (permission_prompt, elicitation_dialog)
    |
    +-->  tts-notify.sh (audio notification)
         |
         +-->  Read event type from stdin JSON
         +-->  Check cooldown (10s)
         +-->  Get WezTerm tab number
         +-->  Generate message: "Tab 5 needs permission" / "Tab 5 needs input" / "Tab 5 has a question"
         +-->  Speak with piper | paplay (background, 10s timeout)
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
- [Permission Configuration](../../../../docs/guides/permission-configuration.md) - Hook permissions
- [User Guide](../../../../docs/guides/user-guide.md) - General Claude Code usage
- Neovim STT README: `~/.config/nvim/lua/neotex/plugins/tools/stt/README.md`
