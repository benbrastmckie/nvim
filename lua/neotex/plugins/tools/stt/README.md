# STT (Speech-to-Text) Plugin

Offline speech recognition for Neovim using Vosk.

## Features

- **Offline recognition**: No internet required, Vosk models run locally
- **Terminal mode support**: Works in Claude Code sidebar and other terminal buffers
- **Auto-transcription**: Records → stops → transcribes → inserts at cursor
- **Configurable timeout**: Default 30 seconds max recording length

## Quick Start

### Start/Stop Recording

```vim
<leader>vr     " Start recording
<leader>vs     " Stop and transcribe
<leader>vv     " Toggle recording

<C-'>          " Dictation key (normal, insert and terminal modes)
```

`<C-'>` is context-aware. In a Claude Code buffer it toggles Claude Code's own voice
recording; in every other buffer it toggles Vosk recording. See
[Claude Code Voice Mode](#claude-code-voice-mode).

### Health Check

```vim
:STTHealth
" or
<leader>vh
```

## Terminal Mode Support

Terminal buffers send keystrokes straight to the running program, so `<C-'>` carries a
terminal-mode mapping alongside the normal- and insert-mode ones. The mapping branches on
the buffer:

```lua
vim.keymap.set('t', "<C-'>", function()
  local bufnr = vim.api.nvim_get_current_buf()
  if _is_claude_code_buffer(bufnr) then
    _send_claude_ptt(bufnr)        -- hand the key to Claude Code
  else
    vim.cmd('stopinsert')          -- drive Vosk instead
    M.toggle_recording()
    vim.schedule(function() vim.cmd('startinsert') end)
  end
end, { noremap = true, silent = true })
```

Claude Code buffers are identified through `neotex.plugins.ai.claude.core.session-manager`,
falling back to a buffer-name match when that module is unavailable.

### Non-Claude terminals

1. Press `<C-'>` in the terminal buffer
2. Neovim leaves terminal mode (`stopinsert`)
3. Vosk recording starts or stops
4. Terminal mode resumes once transcription finishes

## Claude Code Voice Mode

Claude Code has its own speech-to-text, and in a Claude Code buffer `<C-'>` feeds that
rather than Vosk. The mapping writes the push-to-talk key's bytes to the terminal channel,
where Claude Code matches them against its `voice:pushToTalk` binding.

### The physical key and the wire key are separate

`<C-'>` is the key the user presses; it is handled entirely inside Neovim and never
crosses the channel. What crosses the channel is whichever keystroke Claude Code has bound
to `voice:pushToTalk`, written as the bytes a pty would deliver for it.

That keystroke must be one a pty can carry. A terminal encodes `ctrl+<letter>` and
`ctrl+<@ [ \ ] ^ _ ?>` as a single control byte, an encoding fixed since ASCII. Every other
ctrl combination — `ctrl+'` among them — exists only as a kitty-protocol CSI-u sequence,
and whether a CSI-u sequence written into a terminal channel is matched against a binding
is up to the embedded program's input layer rather than a contract Neovim can rely on. So
the module refuses a keystroke it cannot encode as a control byte and says which link
failed, instead of writing bytes that may be silently dropped.

A keystroke mapped in Neovim's terminal mode is no obstacle. `<C-k>` is bound to window
navigation, which intercepts the *physical* key; `chansend` writes to the pty directly and
is unaffected.

### Required Claude Code configuration

`~/.claude/keybindings.json` binds the key. Neovim reads this file to decide what to send,
so it is the single source of truth for the choice:

```json
{
  "$schema": "https://www.schemastore.org/claude-code-keybindings.json",
  "bindings": [
    { "context": "Chat", "bindings": { "ctrl+k": "voice:pushToTalk" } }
  ]
}
```

`~/.claude/settings.json` holds the mode:

```json
{
  "voice": { "enabled": true, "mode": "hold", "autoSubmit": false }
}
```

`:STTHealth` reports each link of this chain — the bound keystroke and its context, the
bytes being sent and where that choice came from, and the voice-mode state — and names the
one that is broken. `vim.g.stt_claude_ptt_key` overrides the keystroke for a session.

`voice.enabled` persists across sessions, so voice mode stays on by default. When it is
switched off, the first `<C-'>` press sends `/voice <mode>` to turn it back on instead of
forwarding a keypress; hold the key again to record. A three-second grace window keeps the
key repeats of one held press from re-sending that command.

### Why hold-to-talk works through Neovim

Hold-to-talk never observes the key being released. Claude Code arms a 200ms timer that
each key event re-arms, and treats the timer firing as the release; a 2000ms fallback
covers the case where no auto-repeat arrives at all. Neovim forwards the initial press and
every auto-repeat into a terminal buffer but drops the true release event, so auto-repeat
is what carries the whole gesture — which is exactly what Claude Code measures.

### Virtual hold: tapping instead of holding

Because the recording ends when key events stop rather than when the key comes up, Neovim
can hold the key down on the user's behalf. `<C-'>` is therefore a **toggle**: the first
press starts repeating the keypress every 80ms, and the second press stops repeating, which
Claude Code reads as the release 200ms later.

This is what makes a tap gesture compatible with an editable transcript. Claude Code's own
`tap` mode submits any transcript of three or more words unconditionally, and
`voice.autoSubmit` has no effect there — it applies to `hold` only. Running a tap gesture
*through* hold mode keeps the transcript in the prompt.

| Claude Code `voice.mode` | Gesture at `<C-'>` | Transcript handling |
|--------------------------|--------------------|---------------------|
| `hold` | Tap to start, tap to stop | Inserted into the prompt for editing |
| `tap` | Tap to start, tap to stop | Submitted automatically at three or more words |

Holding the key physically also works: auto-repeat arriving within 250ms of the previous
press is swallowed, so one held press stays one gesture rather than toggling repeatedly.

A recording that stops on its own after roughly two seconds means key events are not
reaching Claude Code at all.

### Configuration

```lua
-- Mode used when Neovim has to enable Claude Code voice mode itself
vim.g.stt_claude_voice_mode = "hold"          -- or "tap"

-- "virtual_hold" (default) makes <C-'> a toggle; "passthrough" forwards each
-- key event as-is, so the key must be held down physically
vim.g.stt_claude_ptt_style = "virtual_hold"

-- Safety cap on a virtual hold, in seconds
vim.g.stt_claude_hold_timeout = 120
```

Virtual hold engages only when Claude Code's `voice.mode` is `hold`; under `tap` the key is
forwarded as a single press, since repeating it would toggle the recorder on and off.

`vim.g.stt_claude_recording` is true while a virtual hold is active, for statusline use.

`:STTClaudeVoice` sends `/voice` to a Claude Code buffer to switch voice mode on or off.

## Dependencies

Install requirements:

```bash
# PulseAudio/PipeWire
sudo pacman -S pulseaudio-utils  # or pipewire-pulse

# Python and Vosk
pip install vosk

# Download Vosk model
mkdir -p ~/.local/share/vosk
cd ~/.local/share/vosk
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-en-us-0.15.zip
mv vosk-model-small-en-us-0.15 vosk-model-small-en-us

# Install transcription helper
# (should already exist in ~/.local/bin/vosk-transcribe.py)
```

## Configuration

Optional configuration (set in `init.lua` or via globals):

```lua
vim.g.stt_model_path = "~/.local/share/vosk/vosk-model-small-en-us"
vim.g.stt_transcribe_script = "~/.local/bin/vosk-transcribe.py"
vim.g.stt_record_timeout = 30  -- max seconds
vim.g.stt_sample_rate = 16000  -- Hz
```

## Usage Commands

```vim
:STTStart       " Start recording
:STTStop        " Stop and transcribe
:STTToggle      " Toggle recording
:STTHealth      " Check dependencies
```

## Keybindings Reference

| Key | Mode | Description |
|-----|------|-------------|
| `<leader>vr` | Normal | Start recording |
| `<leader>vs` | Normal | Stop recording and transcribe |
| `<leader>vv` | Normal | Toggle recording |
| `<leader>vh` | Normal | Health check |
| `:STTClaudeVoice` | Any | Toggle Claude Code voice mode via `/voice` |
| `<C-'>` | Normal | Vosk toggle, or Claude Code push-to-talk in a Claude Code buffer |
| `<C-'>` | Insert | Toggle Vosk recording |
| `<C-'>` | Terminal | Vosk toggle, or Claude Code push-to-talk in a Claude Code buffer |

## Troubleshooting

### No audio recording

**Check parecord**:
```bash
which parecord
parecord --list-devices
```

**Test recording manually**:
```bash
parecord --channels=1 --rate=16000 --file-format=wav /tmp/test.wav
# Speak for 5 seconds, then Ctrl-C
aplay /tmp/test.wav
```

### Transcription fails

**Check Python and Vosk**:
```bash
python3 -c "import vosk; print('Vosk OK')"
```

**Check model exists**:
```bash
ls -la ~/.local/share/vosk/vosk-model-small-en-us
```

**Test transcription script**:
```bash
python3 ~/.local/bin/vosk-transcribe.py /tmp/test.wav ~/.local/share/vosk/vosk-model-small-en-us
```

### Doesn't work in Claude Code sidebar

**Verify terminal-mode mapping**:
```vim
:verbose map <C-'>
```

Should show a terminal-mode and a normal-mode entry, both Lua functions described as
`STT: Toggle dictation`.

**Check the key reaches Claude Code**: another terminal-mode mapping on the same key wins
over this one. `lua/neotex/config/keymaps.lua` maps `<C-h>`, `<C-j>`, `<C-k>` and `<C-l>`
to window navigation in terminal buffers, so those keys never reach the program inside.
Bind `voice:pushToTalk` to a key that is not mapped there.

**Check Claude Code's own configuration**:
```bash
cat ~/.claude/keybindings.json   # ctrl+' bound to voice:pushToTalk
python3 -c "import json; print(json.load(open('$HOME/.claude/settings.json'))['voice'])"
```

**Recording stops after about two seconds while the key is held**: Claude Code is not
seeing auto-repeat, and its fallback release timer is firing. Confirm the terminal
auto-repeats the key while held.

**Check buffer type**:
```vim
:echo &buftype
" Should show 'terminal' in Claude Code
```

### Empty transcriptions

- Speak clearly and close to microphone
- Reduce background noise
- Vosk small model has limited vocabulary (use medium/large for better results)
- Check recording file was created: `ls -lh /tmp/nvim-stt-recording.wav`

## Architecture

### Recording Flow

```
User presses <C-'> (terminal mode, non-Claude buffer)
    │
    ▼
Exits terminal mode (stopinsert)
    │
    ▼
M.toggle_recording() called
    │
    ▼
jobstart(parecord) -> /tmp/nvim-stt-recording.wav
    │
    ▼
User speaks (up to 30s)
    │
    ▼
User presses <C-'> again
    │
    ▼
jobstop(parecord) sends SIGTERM
    │
    ▼
on_exit callback triggered
    │
    ▼
M.transcribe_and_insert()
    │
    ▼
jobstart(python3 vosk-transcribe.py)
    │
    ▼
on_exit: insert text at cursor
```

### State Management

```lua
local recording_job_id = nil    -- parecord job ID
local is_recording = false       -- recording state
local recording_file = "/tmp/nvim-stt-recording.wav"
```

## Integration with Claude Code

The STT plugin integrates with Claude Code sidebar via:

1. **Push-to-talk forwarding**: `<C-'>` drives Claude Code's voice mode from a Claude Code
   buffer (see [Claude Code Voice Mode](#claude-code-voice-mode))
2. **SessionStart hook**: Claude signals Neovim when ready (see `.claude/docs/guides/neovim-integration.md`)
3. **TTS notifications**: pico2wave announces when Claude completes (see `.claude/hooks/tts-notify.sh`)

**Full integration docs**: See `.claude/docs/guides/neovim-integration.md` in your project root.

## Files

- `init.lua` - Main plugin implementation
- `README.md` - This file

## See Also

- [MAPPINGS.md](../../../../docs/MAPPINGS.md) - Full keybinding reference
- [Claude Code Integration](../../../ai/claude/README.md) - Claude Code plugin
- [Neovim Integration Guide](?path=.claude/docs/guides/neovim-integration.md) - Claude Code hooks
