# Implementation Plan: Context-Aware Dictation Keymaps

- **Task**: 377 - Add ctrl-based keymap for triggering dictation in Neovim with Claude Code sidebar voice recording support
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_team-research.md
- **Artifacts**: plans/01_dictation-keymap-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

The existing `<C-\>` (normal mode) and `<C-'>` (terminal mode) keymaps unconditionally invoke Vosk STT dictation. This plan adds context-aware routing: when the active buffer is a Claude Code terminal, the same keymaps trigger Claude Code's native `voice:pushToTalk` instead of Vosk STT. Additionally, the plan fixes a critical bug where `transcribe_and_insert()` uses `nvim_put()` in terminal buffers (which fails silently) and configures `~/.claude/keybindings.json` for the `voice:pushToTalk` binding. Done when both keymaps dispatch correctly by context and Vosk terminal insertion uses `chansend()`.

### Research Integration

Research report `01_team-research.md` provided:
- Complete Ctrl keymap inventory confirming no conflicts with the chosen approach
- Claude Code v2.1.87 native voice API details (`voice:pushToTalk`, `meta+k` binding)
- Discovery of the terminal insertion bug (`nvim_put()` vs `chansend()`)
- Confirmation that `is_claude_buffer()` exists in `session-manager.lua` for buffer detection
- `find_claude_window()` exists in `claude-session/terminal.lua` for window/buffer lookup

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Same keymaps (`<C-\>`, `<C-'>`) route to Claude Code native voice when in a Claude Code buffer
- Same keymaps route to Vosk STT for all other contexts (unchanged behavior)
- Configure `~/.claude/keybindings.json` with `meta+k` bound to `voice:pushToTalk`
- Fix terminal insertion bug: use `chansend()` for terminal buffers in Vosk STT path
- Expose `is_recording` state via `vim.g.stt_recording` for optional statusline use

**Non-Goals**:
- Replacing Vosk STT with Claude Code voice globally
- Adding new keymaps beyond the existing `<C-\>` and `<C-'>`
- Statusline integration (expose state only; UI is a separate task)
- Centralizing scattered keymap definitions (maintenance task, out of scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `meta+k` escape sequence not recognized by Claude Code in terminal | H | L | Research confirms modifier combos pass through; fall back to alternative key if needed |
| `is_claude_buffer()` returns false for valid Claude buffers | M | L | Function is battle-tested in session-manager; add debug logging on detection failure |
| `chansend()` requires correct channel ID | M | M | Extract channel from `nvim_buf_get_option(bufnr, 'channel')` which is already used in `is_claude_buffer()` |
| `~/.claude/keybindings.json` format changes in future Claude versions | L | L | Use documented schema; file is simple JSON with no version coupling |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Configure Claude Code keybindings and add detection helper [COMPLETED]

**Goal**: Create `~/.claude/keybindings.json` and add a local helper in `stt/init.lua` to detect Claude Code buffers without hard-coupling to the session-manager module.

**Tasks**:
- [ ] Create `~/.claude/keybindings.json` with `meta+k` bound to `voice:pushToTalk` in Chat context, disabling default `space` binding
- [ ] Add local helper function `is_claude_code_buffer(bufnr)` in `stt/init.lua` that checks `buftype == 'terminal'` and buffer name matches Claude patterns (reuse logic from `session-manager.lua` or `pcall(require)` the existing function)
- [ ] Add local helper function `get_terminal_channel(bufnr)` to safely extract the terminal channel ID for a buffer

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `~/.claude/keybindings.json` - Create with push-to-talk binding
- `lua/neotex/plugins/tools/stt/init.lua` - Add detection and channel helpers

**Verification**:
- `~/.claude/keybindings.json` exists and is valid JSON
- Helper functions return correct values for Claude Code and non-Claude buffers

---

### Phase 2: Add context-aware routing to keymap handlers [COMPLETED]

**Goal**: Modify `<C-\>` (normal mode) and `<C-'>` (terminal mode) handlers to check if the current buffer is a Claude Code buffer and dispatch accordingly -- sending the `meta+k` escape sequence to Claude Code or falling through to Vosk STT.

**Tasks**:
- [ ] Create `send_claude_voice_key(bufnr)` function that sends the `meta+k` escape sequence (`\x1bk` or `\033k`) to the terminal channel via `chansend()`
- [ ] Modify the `<C-\>` normal mode handler: if current buffer is Claude Code, call `send_claude_voice_key()`; otherwise call `M.toggle_recording()` as before
- [ ] Modify the `<C-'>` terminal mode handler: if current buffer is Claude Code, send `meta+k` escape sequence directly via `chansend()`; otherwise fall through to existing Vosk STT toggle
- [ ] Add `vim.g.stt_recording = is_recording` state updates in `start_recording()` and `stop_recording()` for external consumers

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/tools/stt/init.lua` - Modify keymap handlers and add routing logic

**Verification**:
- In a Claude Code terminal buffer, `<C-'>` sends `meta+k` escape sequence (observable via debug logging)
- In a non-Claude terminal buffer, `<C-'>` triggers Vosk STT recording
- In normal mode on a Claude Code buffer, `<C-\>` sends `meta+k`
- In normal mode on a regular buffer, `<C-\>` triggers Vosk STT recording

---

### Phase 3: Fix terminal insertion bug for Vosk STT [COMPLETED]

**Goal**: Replace `nvim_put()` with `chansend()` when inserting transcribed text into terminal buffers, so Vosk STT works correctly in non-Claude terminal contexts.

**Tasks**:
- [ ] In `transcribe_and_insert()`, detect whether `current_buf` is a terminal buffer (`buftype == 'terminal'`)
- [ ] If terminal buffer: get the channel ID and use `vim.fn.chansend(channel, text)` to send transcribed text
- [ ] If normal buffer: keep existing `nvim_put()` logic unchanged
- [ ] Handle edge case where channel is invalid (buffer closed during transcription) by falling back to register storage

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/tools/stt/init.lua` - Modify `transcribe_and_insert()` function

**Verification**:
- Open a non-Claude terminal, trigger Vosk STT with `<C-'>`, speak, and verify text appears in terminal
- Open a normal buffer, trigger Vosk STT with `<C-\>`, speak, and verify text inserts at cursor (regression test)

---

### Phase 4: Integration testing and documentation [COMPLETED]

**Goal**: End-to-end verification of all four code paths (Claude vs non-Claude x normal vs terminal) and update module documentation.

**Tasks**:
- [ ] Test `<C-\>` in normal mode on a regular buffer (Vosk STT fires)
- [ ] Test `<C-\>` in normal mode on a Claude Code buffer (sends `meta+k` to Claude)
- [ ] Test `<C-'>` in terminal mode in a non-Claude terminal (Vosk STT fires, text inserts via `chansend()`)
- [ ] Test `<C-'>` in terminal mode in a Claude Code terminal (sends `meta+k` to Claude)
- [ ] Update module header comment in `stt/init.lua` to document context-aware behavior
- [ ] Verify `vim.g.stt_recording` toggles correctly during recording cycle

**Timing**: 45 minutes

**Depends on**: 2, 3

**Files to modify**:
- `lua/neotex/plugins/tools/stt/init.lua` - Update header documentation

**Verification**:
- All four code paths produce expected behavior
- No regressions in existing Vosk STT functionality
- Module header accurately describes the context-aware routing

## Testing & Validation

- [ ] `~/.claude/keybindings.json` is valid JSON and contains `voice:pushToTalk` binding
- [ ] `<C-\>` in normal mode dispatches to Vosk STT on regular buffers
- [ ] `<C-\>` in normal mode dispatches to Claude voice on Claude buffers
- [ ] `<C-'>` in terminal mode dispatches to Vosk STT on non-Claude terminals
- [ ] `<C-'>` in terminal mode dispatches to Claude voice on Claude terminals
- [ ] Vosk STT transcribed text inserts correctly in terminal buffers via `chansend()`
- [ ] Vosk STT transcribed text inserts correctly in normal buffers via `nvim_put()` (regression)
- [ ] `vim.g.stt_recording` reflects current recording state
- [ ] No errors in `:messages` after exercising all paths

## Artifacts & Outputs

- `~/.claude/keybindings.json` - Claude Code push-to-talk configuration
- `lua/neotex/plugins/tools/stt/init.lua` - Modified with context-aware routing and terminal fix
- `specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/plans/01_dictation-keymap-plan.md` - This plan
- `specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/summaries/01_dictation-keymap-summary.md` - Post-implementation summary

## Rollback/Contingency

Revert `stt/init.lua` to the pre-change version via `git checkout HEAD -- lua/neotex/plugins/tools/stt/init.lua`. Delete `~/.claude/keybindings.json` if Claude Code voice behavior is undesired. Both changes are isolated -- the STT module has no downstream consumers, and the keybindings file is independent of Neovim configuration.
