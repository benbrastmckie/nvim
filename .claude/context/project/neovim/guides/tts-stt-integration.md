# TTS/STT Integration for Claude Code and Neovim

This document describes the integration of text-to-speech (TTS) notifications for Claude Code and speech-to-text (STT) input for Neovim.

## Overview

The integration provides two independent features:

1. **TTS Notifications**: Claude Code announces events via Piper TTS with WezTerm tab identification
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
    piper-tts
    espeak-ng        # Piper dependency for phonemization
    alsa-utils       # For aplay

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
| Piper TTS | `piper-tts` | Neural text-to-speech synthesis |
| espeak-ng | `espeak-ng` | Phonemization backend for Piper |
| aplay | `alsa-utils` | ALSA audio playback |
| paplay | `pulseaudio` | PulseAudio audio playback (alternative to aplay) |
| jq | `jq` | JSON parsing in shell scripts |
| wezterm | `wezterm` | Terminal emulator with CLI for tab detection |
| Python 3 + Vosk | `python3.withPackages (ps: [ps.vosk])` | Offline speech recognition |

### Model Downloads

#### Piper Voice Model (TTS)

Download a voice model from [Piper releases](https://github.com/rhasspy/piper/releases) or [Hugging Face](https://huggingface.co/rhasspy/piper-voices):

```bash
mkdir -p ~/.local/share/piper
cd ~/.local/share/piper

# Download medium quality US English voice
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json
```

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

Claude Code triggers `tts-notify.sh` via hooks when:

1. **Stop Event**: Claude finishes responding - announces "Tab N"
2. **Notification Events** (input-needed): `permission_prompt`, `idle_prompt`, `elicitation_dialog` - announces "Tab N"

The script:
1. Checks a 10-second cooldown to prevent notification spam
2. Detects the WezTerm tab number via `wezterm cli list`
3. Speaks "Tab N" using Piper TTS

### Hook Configuration

The hooks are configured in `.claude/settings.json`:

```json
{
  "hooks": {
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
  }
}
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PIPER_MODEL` | `~/.local/share/piper/en_US-lessac-medium.onnx` | Path to Piper voice model |
| `TTS_COOLDOWN` | `10` | Seconds between notifications |
| `TTS_ENABLED` | `1` | Set to `0` to disable notifications |

### Examples

```bash
# Disable TTS temporarily
export TTS_ENABLED=0

# Use a different voice
export PIPER_MODEL=~/.local/share/piper/en_GB-alba-medium.onnx

# Reduce cooldown to 5 seconds
export TTS_COOLDOWN=5
```

### Notification Event Types

| Event | Trigger | Message |
|-------|---------|---------|
| Stop | Claude finishes responding | "Tab N" |
| permission_prompt | Claude needs tool permission | "Tab N" |
| idle_prompt | Claude is waiting for user input | "Tab N" |
| elicitation_dialog | Claude asks a clarifying question | "Tab N" |

### Troubleshooting

**No sound plays**:
- Check that `piper` is installed: `which piper`
- Verify model exists: `ls -la ~/.local/share/piper/`
- Test audio: `echo "Hello" | piper --model ~/.local/share/piper/en_US-lessac-medium.onnx --output_file - | aplay`

**WezTerm tab not detected**:
- Ensure WezTerm is the terminal emulator
- Check `WEZTERM_PANE` is set: `echo $WEZTERM_PANE`
- Test CLI: `wezterm cli list --format=json`

**Notifications too frequent/infrequent**:
- Adjust `TTS_COOLDOWN` environment variable
- Check `specs/tmp/claude-tts-last-notify` timestamp

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
4. When Claude finishes, hear "Tab 2"
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
4. When you hear "Tab 1", switch back
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
| `.claude/hooks/tts-notify.sh` | Claude Code TTS hook |
| `~/.config/nvim/lua/neotex/plugins/tools/stt/init.lua` | Neovim STT plugin |
| `~/.config/nvim/lua/neotex/plugins/tools/stt-plugin.lua` | Lazy.nvim plugin spec |
| `~/.config/nvim/lua/neotex/plugins/editor/which-key.lua` | Keybinding configuration |
| `~/.local/bin/vosk-transcribe.py` | Vosk transcription script |
| `specs/tmp/claude-tts-last-notify` | Cooldown timestamp |
| `specs/tmp/claude-tts-notify.log` | TTS notification log |
| `specs/tmp/nvim-stt-recording.wav` | Temporary recording file |

### Model Sizes

| Model | Size | Purpose |
|-------|------|---------|
| Piper en_US-lessac-medium | ~45 MB | TTS voice synthesis |
| Vosk small-en-us | ~50 MB | Speech recognition |

Total disk usage: ~95 MB for both features.

## Uninstallation

### Remove TTS Notifications

1. Edit `.claude/settings.json`, remove TTS hook entries from Stop and Notification hooks
2. Delete `.claude/hooks/tts-notify.sh`
3. Optionally delete `~/.local/share/piper/` to remove voice models

### Remove STT Plugin

1. Remove the STT entry from `~/.config/nvim/lua/neotex/plugins/tools/init.lua`
2. Remove the `<leader>v` voice group from `~/.config/nvim/lua/neotex/plugins/editor/which-key.lua`
3. Delete `~/.config/nvim/lua/neotex/plugins/tools/stt/` directory
4. Delete `~/.config/nvim/lua/neotex/plugins/tools/stt-plugin.lua`
5. Delete `~/.local/bin/vosk-transcribe.py`
6. Optionally delete `~/.local/share/vosk/` to remove speech models

## See Also

- [Piper TTS](https://github.com/rhasspy/piper) - Fast neural TTS
- [Vosk](https://alphacephei.com/vosk/) - Offline speech recognition
- [Claude Code Hooks](https://code.claude.com/docs/en/hooks) - Hook documentation
- [WezTerm CLI](https://wezterm.org/cli/cli/activate-tab.html) - Tab management
- [Neovim Integration Guide](neovim-integration.md) - SessionStart hooks and sidebar readiness
