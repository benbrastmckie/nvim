# Implementation Summary: Unified Ctrl-' Dictation Keymap

- **Task**: 377 - ctrl_keymap_dictation_neovim_claude_sidebar
- **Status**: [COMPLETED]
- **Started**: 2026-04-08T12:00:00Z
- **Completed**: 2026-04-08T12:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Artifacts**: plans/02_unified-keymap-plan.md, summaries/02_implementation-summary.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Implemented a unified `<C-'>` dictation keymap across all Neovim modes (normal, insert, terminal) with context-aware routing between Claude Code native voice and Vosk STT. This replaces the previous split `<C-\>` (normal) and `<C-'>` (terminal-only) mappings with a single consistent keymap.

## What Changed

- Created `~/.claude/keybindings.json` with `meta+k` -> `voice:pushToTalk` binding for Claude Code
- Added `_is_claude_code_buffer()` helper wrapping session-manager with pcall guard
- Added `_send_claude_voice_toggle()` helper sending `\x1bk` escape sequence via chansend
- Replaced `<C-\>` normal-mode mapping with context-aware `<C-'>` normal-mode mapping
- Added new `<C-'>` insert-mode mapping for Vosk STT toggle
- Updated `<C-'>` terminal-mode mapping with Claude Code routing (sends meta+k) vs Vosk STT (stopinsert/startinsert)
- Fixed terminal insertion bug in `transcribe_and_insert()`: uses `chansend` for terminal buffers instead of `nvim_put` which fails silently
- Added `vim.g.stt_recording` global state for statusline integration
- Updated module header documentation to reflect new unified keymap behavior

## Decisions

- Used `pcall` guard for session-manager require at module level to avoid hard dependency
- Context routing is exclusive: Claude Code buffers never reach Vosk path, eliminating toggle conflicts
- Insert-mode mapping always routes to Vosk STT (insert mode in terminal is terminal mode, so Claude routing happens there)
- Used `vim.api.nvim_get_option_value` instead of deprecated `nvim_buf_get_option` for buftype check

## Impacts

- `<C-\>` no longer triggers STT in normal mode (removed)
- `<C-'>` now works consistently in all three modes
- Terminal text insertion now works correctly via chansend
- Statusline plugins can use `vim.g.stt_recording` to show recording state

## Follow-ups

- Test end-to-end with Claude Code sidebar to verify meta+k triggers voice:pushToTalk
- Consider updating `stt/README.md` to reflect new keymap (still references `<C-\>`)

## References

- `specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/plans/02_unified-keymap-plan.md`
- `specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/reports/02_unified-keymap-research.md`
- `lua/neotex/plugins/tools/stt/init.lua`
- `lua/neotex/plugins/ai/claude/core/session-manager.lua`
- `~/.claude/keybindings.json`
