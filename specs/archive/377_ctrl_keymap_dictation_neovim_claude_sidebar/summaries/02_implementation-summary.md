# Implementation Summary: Unified Ctrl-' Dictation Keymap

- **Task**: 377 - ctrl_keymap_dictation_neovim_claude_sidebar
- **Status**: [COMPLETED]
- **Started**: 2026-04-08T12:00:00Z
- **Completed**: 2026-04-08T15:00:00Z
- **Effort**: 3 hours (including debugging keybinding format and terminal encoding)
- **Dependencies**: None
- **Artifacts**: plans/02_unified-keymap-plan.md, summaries/02_implementation-summary.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Implemented a unified `<C-'>` dictation keymap across all Neovim modes (normal, insert, terminal) with context-aware routing between Claude Code native voice and Vosk STT. In Claude Code buffers, holding `<C-'>` triggers push-to-talk via CSI u encoding sent through chansend. In all other buffers, it toggles the Vosk STT recording pipeline.

## What Changed

- Created `~/.claude/keybindings.json` with correct nested bindings format:
  - `ctrl+'` -> `voice:pushToTalk` (used from Neovim terminal via CSI u encoding)
  - `meta+k` -> `voice:pushToTalk` (used from standalone terminal via Alt+K)
- Added `voiceEnabled: true` to `~/.claude/settings.local.json` and `~/.dotfiles/config/claude-settings.json` (Home Manager source for settings.json, which is a read-only Nix store symlink)
- Added `_is_claude_code_buffer()` helper wrapping session-manager with pcall guard
- Added `_send_claude_voice_toggle()` helper sending `\x1b[39;5u` (CSI u encoding for Ctrl+') via chansend
- Replaced `<C-\>` normal-mode mapping with context-aware `<C-'>` normal-mode mapping
- Added new `<C-'>` insert-mode mapping for Vosk STT toggle
- Updated `<C-'>` terminal-mode mapping with Claude Code routing (push-to-talk) vs Vosk STT (stopinsert/startinsert)
- Fixed terminal insertion bug in `transcribe_and_insert()`: uses `chansend` for terminal buffers instead of `nvim_put` which fails silently
- Added `vim.g.stt_recording` global state for statusline integration
- Added `STTDebug` and `STTClaudeVoice` diagnostic commands

## Decisions

- **CSI u encoding over legacy escape sequences**: Legacy `\x1bk` (ESC+k for Alt+K) is ambiguous inside Neovim's terminal (libvterm) -- the ESC byte can be misinterpreted. CSI u encoding (`\x1b[39;5u` for Ctrl+') is unambiguous and works reliably via chansend.
- **Dual keybindings**: `ctrl+'` for Neovim integration (same physical key as `<C-'>`), `meta+k` for standalone terminal use (Alt+K). Both bound to `voice:pushToTalk` in the Chat context.
- **Correct keybindings.json format**: Claude Code requires a nested `{"bindings": [{"context": "Chat", "bindings": {...}}]}` structure, not the flat array format. The flat format is silently ignored.
- **Push-to-talk is hold-based**: The user must hold `<C-'>` to record, release to stop. Key repeat from holding generates repeated chansend calls, simulating the held key for Claude Code.
- Used `pcall` guard for session-manager require to avoid hard dependency
- Context routing is exclusive: Claude Code buffers never reach Vosk path

## Impacts

- `<C-\>` no longer triggers STT in normal mode (removed)
- `<C-'>` now works consistently in all three modes (normal, insert, terminal)
- Terminal text insertion works correctly via chansend for Vosk transcription output
- `vim.g.stt_recording` available for statusline plugins
- Claude Code voice push-to-talk works from Neovim sidebar via `<C-'>` hold

## Follow-ups

- None -- end-to-end testing confirmed working in both standalone WezTerm and Neovim sidebar

## References

- `specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/plans/02_unified-keymap-plan.md`
- `specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/reports/02_unified-keymap-research.md`
- `lua/neotex/plugins/tools/stt/init.lua`
- `lua/neotex/plugins/ai/claude/core/session-manager.lua`
- `~/.claude/keybindings.json`
- `~/.claude/settings.local.json`
- `~/.dotfiles/config/claude-settings.json`
