# TTS/STT Integration for Claude Code and Neovim

This document describes the integration of text-to-speech (TTS) notifications for Claude Code and speech-to-text (STT) input for Neovim.

## Overview

The integration provides two independent features:

1. **TTS Notifications**: Claude Code announces events via piper neural TTS with WezTerm tab identification
2. **STT Input**: Neovim voice recording and transcription via Vosk for inserting text at cursor

Both features work completely offline with no cloud APIs required.

## Prerequisites

### System Requirements

- **NixOS** (tested) or Linux with PulseAudio/PipeWire
- **Audio hardware**: Working microphone for STT, speakers for TTS

### Required Packages

Add to your NixOS configuration:

```nix
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    # TTS
    piper            # Piper neural text-to-speech engine (prebuilt binary)
    pulseaudio       # For paplay

    # STT
    (python3.withPackages (ps: with ps; [
      vosk
    ]))
    pulseaudio       # For parecord (or pipewire-pulse)

    # Utilities
    jq               # For JSON parsing in hooks
    wezterm          # Terminal with tab detection
  ];

  # Ensure user is in audio group
  users.users.yourname.extraGroups = [ "audio" ];
}
```

### Software Dependencies Summary

| Package | NixOS Package | Purpose |
|---------|---------------|---------|
| piper | `piper` | Neural text-to-speech synthesis (requires a voice model) |
| paplay | `pulseaudio` | PulseAudio audio playback |
| jq | `jq` | JSON parsing in shell scripts |
| wezterm | `wezterm` | Terminal emulator with CLI for tab detection |
| Python 3 + Vosk | `python3.withPackages (ps: [ps.vosk])` | Offline speech recognition |

### Model Downloads

#### piper (TTS)

Piper requires an `.onnx` voice model plus its `.onnx.json` config. The hook defaults to
`~/.local/share/piper/en_US-lessac-medium.onnx` (override with the `PIPER_VOICE` env var).
Models are available from [rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices);
this repo's NixOS config provisions the Lessac medium voice via `packages/piper-voices.nix`.

#### Vosk Speech Model (STT)

Download a model from [Vosk Models](https://alphacephei.com/vosk/models):

```bash
mkdir -p ~/.local/share/vosk
cd ~/.local/share/vosk

# Download small English model (~50MB, good accuracy)
wget https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
unzip vosk-model-small-en-us-0.15.zip
mv vosk-model-small-en-us-0.15 vosk-model-small-en-us
```

## TTS Notifications for Claude Code

### How It Works

TTS fires in two categories:

1. **Lifecycle transitions**: After a task status transition, a lifecycle skill's own postflight
   Stage 8a calls `skill_lifecycle_notify "$status"` (a shared function in `skill-base.sh`), which
   invokes `lifecycle-notify.sh STATUS`, which in turn calls `tts-notify.sh --lifecycle STATUS`,
   speaking "Tab N STATUS" (e.g., "Tab 3 researched"). `/orchestrate` calls `lifecycle-notify.sh`
   directly from `orchestrator-postflight.sh` instead of going through a skill's Stage 8a.
   `update-task-status.sh` itself does not invoke any TTS script; it only writes task status.

2. **Interactive prompts**: `permission_prompt` and `elicitation_dialog` Notification hook events
   trigger `tts-notify.sh` with no args, which speaks "Tab N" to alert the user that input is needed.

The Stop hook does NOT trigger TTS. This eliminates random "Tab N" announcements during
mid-workflow orchestrator pauses.

### Lifecycle Vocabulary

TTS uses only lifecycle state names (no artifact-type vocabulary):
- `researching` — "Tab N researching"
- `researched` — "Tab N researched"
- `planning` — "Tab N planning"
- `planned` — "Tab N planned"
- `implementing` — "Tab N implementing"
- `completed` — "Tab N completed"
- `blocked` — "Tab N blocked"

### Hook Configuration

The hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
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
  }
}
```

Lifecycle TTS is fired by each lifecycle skill's own postflight Stage 8a, via the shared
`skill_lifecycle_notify` function in `skill-base.sh`:

```bash
# Stage 8a of a lifecycle skill's Postflight section (e.g. skill-nix-research/SKILL.md),
# following @.claude/context/patterns/skill-postflight-flow.md's Stage 8a:
skill_lifecycle_notify "$status"
```

`skill_lifecycle_notify` (in `skill-base.sh`) backgrounds a call to `lifecycle-notify.sh STATUS`,
which updates the WezTerm tab color and then calls `tts-notify.sh --lifecycle STATUS`. `$status`
is the operation's success-variant string read from `.return-meta.json` at that skill's own
Stage 6 — not `update-task-status.sh`'s internal `$STATE_STATUS`, which is a separate,
correctly-scoped variable local to that one script's own status-vocabulary mapping.

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TTS_ENABLED` | `1` | Set to `0` to disable notifications |

### Examples

```bash
# Disable TTS temporarily
export TTS_ENABLED=0
```

### Notification Event Types

| Event | Trigger | Message |
|-------|---------|---------|
| Lifecycle (skill postflight Stage 8a / orchestrator-postflight.sh) | Task status transition completes | "Tab N researched/planned/completed" |
| permission_prompt | Claude needs tool permission | "Tab N" |
| elicitation_dialog | Claude asks a clarifying question | "Tab N" |

### The --lifecycle Flag in tts-notify.sh

When called with `--lifecycle STATUS`:
- Speaks "Tab N STATUS" (e.g., "Tab 3 researched")
- Non-blocking background invocation
- No cooldown or signal file mechanism

When called with no args (Notification hook):
- Speaks "Tab N" immediately
- For permission_prompt and elicitation_dialog only

### Troubleshooting

**No lifecycle TTS fires**:
- Verify the lifecycle skill's own postflight Stage 8a calls `skill_lifecycle_notify "$status"`
  (not a stale or misnamed variable — passing an empty argument logs a skipped no-op instead of
  speaking, both to stderr and to the log below)
- Check log: `cat specs/tmp/claude-tts-notify.log`

**No sound plays**:
- Check that `piper` is installed: `which piper`
- Check the voice model exists: `ls ~/.local/share/piper/*.onnx` (or set `PIPER_VOICE`)
- Test audio: `echo "Hello" | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file - | paplay`

**WezTerm tab not detected**:
- Ensure WezTerm is the terminal emulator
- Check `WEZTERM_PANE` is set: `echo $WEZTERM_PANE`
- Test CLI: `wezterm cli list --format=json`

**View logs**:
```bash
cat specs/tmp/claude-tts-notify.log
```

## STT Input for Neovim

### How It Works

The Neovim STT plugin records audio via PulseAudio, transcribes it using Vosk, and inserts the text at the cursor position.

### Installation

The STT plugin is part of the neotex plugin collection. It is automatically loaded by lazy.nvim when placed in the tools directory.

**Plugin location**: `~/.config/nvim/lua/neotex/plugins/tools/stt/init.lua`

**Keybindings**: Configured via which-key in `~/.config/nvim/lua/neotex/plugins/editor/which-key.lua`

For standalone usage without neotex, you can load the plugin directly:

```lua
-- Load and setup STT plugin
require('neotex.plugins.tools.stt').setup({
  -- Optional: customize settings
  model_path = vim.fn.expand("~/.local/share/vosk/vosk-model-small-en-us"),
  record_timeout = 30,  -- Max recording time in seconds
  keymaps = true,  -- Enable built-in keymaps (default: false when using which-key)
})
```

### Keymappings

| Key | Action |
|-----|--------|
| `<leader>vr` | Start recording |
| `<leader>vs` | Stop recording and transcribe |
| `<leader>vt` | Toggle recording |
| `<leader>vh` | Health check (verify dependencies) |

### Commands

| Command | Description |
|---------|-------------|
| `:STTStart` | Start recording |
| `:STTStop` | Stop recording and transcribe |
| `:STTToggle` | Toggle recording |
| `:STTHealth` | Check dependencies |

### Configuration Options

```lua
require('neotex.plugins.tools.stt').setup({
  -- Path to Vosk model directory
  model_path = "~/.local/share/vosk/vosk-model-small-en-us",

  -- Path to transcription script
  transcribe_script = "~/.local/bin/vosk-transcribe.py",

  -- Maximum recording time in seconds
  record_timeout = 30,

  -- Audio sample rate (16kHz optimal for Vosk)
  sample_rate = 16000,

  -- Enable built-in keymaps (default: false)
  -- Note: When using which-key, keymaps are managed centrally
  keymaps = true,
})
```

### Troubleshooting

**"parecord not found"**:
- Install PulseAudio utilities: `pulseaudio` or `pipewire-pulse` package

**"Vosk model not found"**:
- Download and extract model to `~/.local/share/vosk/vosk-model-small-en-us`

**"No speech detected"**:
- Check microphone is working: `parecord --channels=1 --rate=16000 test.wav` then `aplay test.wav`
- Speak clearly and close to the microphone
- Try increasing recording duration

**Transcription errors**:
- Check Python and vosk are installed: `python3 -c "import vosk; print(vosk.__version__)"`
- Test directly: `~/.local/bin/vosk-transcribe.py specs/tmp/test.wav`

**Run health check**:
```vim
:STTHealth
```

## Workflow Examples

### Using TTS with Multiple WezTerm Tabs

1. Open multiple WezTerm tabs with Claude Code sessions
2. Start a long-running task (e.g., `/implement` or code review)
3. Switch to another tab to work
4. When the task completes, hear "Tab 2 completed"
5. Switch back to that tab to continue

### Using TTS for Permission Prompts

1. Run a command that triggers tool use (e.g., file writes)
2. Switch to another tab while Claude works
3. When Claude needs permission, hear "Tab 1"
4. Switch back to approve/deny the tool use

### Using STT for Dictation in Neovim

1. Position cursor where you want text inserted
2. Press `<leader>vr` to start recording
3. Speak your text clearly
4. Press `<leader>vs` to stop and transcribe
5. Text appears at cursor position

### Combining Both Features

1. In WezTerm Tab 1: Ask Claude to review code
2. Switch to WezTerm Tab 2: Open Neovim
3. Use STT to dictate documentation or comments
4. When you hear "Tab 1 researched", switch back
5. Continue working with Claude's response

## Technical Details

### Audio Format

Both features use:
- **Channels**: Mono (1 channel)
- **Sample rate**: 16000 Hz
- **Format**: WAV (PCM)

This format is optimal for speech recognition and keeps file sizes small.

### File Locations

| File | Purpose |
|------|---------|
| `.claude/hooks/tts-notify.sh` | Claude Code TTS hook (lifecycle + interactive) |
| `.claude/hooks/wezterm-notify.sh` | WezTerm tab color notification hook |
| `~/.config/nvim/lua/neotex/plugins/tools/stt/init.lua` | Neovim STT plugin |
| `~/.config/nvim/lua/neotex/plugins/tools/stt-plugin.lua` | Lazy.nvim plugin spec |
| `~/.config/nvim/lua/neotex/plugins/editor/which-key.lua` | Keybinding configuration |
| `~/.local/bin/vosk-transcribe.py` | Vosk transcription script |
| `specs/tmp/claude-tts-notify.log` | TTS notification log |
| `specs/tmp/nvim-stt-recording.wav` | Temporary recording file |

### Model Sizes

| Model | Size | Purpose |
|-------|------|---------|
| piper voice model (.onnx) | ~63 MB | TTS voice synthesis |
| Vosk small-en-us | ~50 MB | Speech recognition |

Total disk usage: ~113 MB for both features.

## Uninstallation

### Remove TTS Notifications

1. Edit `.claude/settings.json`, remove TTS hook entries from Notification hook
2. Delete `.claude/hooks/tts-notify.sh`

### Remove STT Plugin

1. Remove the STT entry from `~/.config/nvim/lua/neotex/plugins/tools/init.lua`
2. Remove the `<leader>v` voice group from `~/.config/nvim/lua/neotex/plugins/editor/which-key.lua`
3. Delete `~/.config/nvim/lua/neotex/plugins/tools/stt/` directory
4. Delete `~/.config/nvim/lua/neotex/plugins/tools/stt-plugin.lua`
5. Delete `~/.local/bin/vosk-transcribe.py`
6. Optionally delete `~/.local/share/vosk/` to remove speech models

## See Also

- [Piper](https://github.com/rhasspy/piper) - Fast, local neural TTS
- [piper-voices](https://huggingface.co/rhasspy/piper-voices) - Downloadable voice models
- [Vosk](https://alphacephei.com/vosk/) - Offline speech recognition
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks) - Hook documentation
- [WezTerm CLI](https://wezterm.org/cli/cli/activate-tab.html) - Tab management
- [WezTerm Integration Guide](../hooks/wezterm-integration.md) - Tab coloring and user variables
- [Neovim Integration Guide](neovim-integration.md) - SessionStart hooks and sidebar readiness
