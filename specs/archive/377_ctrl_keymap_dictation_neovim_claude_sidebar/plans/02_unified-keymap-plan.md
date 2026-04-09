# Implementation Plan: Unified Ctrl-' Dictation Keymap

- **Task**: 377 - ctrl_keymap_dictation_neovim_claude_sidebar
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (Kitty keyboard protocol already enabled in WezTerm)
- **Research Inputs**: specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/reports/02_unified-keymap-research.md
- **Artifacts**: plans/02_unified-keymap-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Implement a single unified `<C-'>` keymap for dictation across all Neovim modes (normal, insert, terminal). In Claude Code terminal buffers, the keymap triggers Claude Code native voice:pushToTalk by sending a `meta+k` escape sequence via `chansend`. In all other buffers, it triggers the existing Vosk STT pipeline. This also fixes a terminal insertion bug where `nvim_put` fails silently on terminal buffers, creates `~/.claude/keybindings.json` for Claude Code voice binding, and removes the old `<C-\>` normal-mode mapping.

### Research Integration

Research report `02_unified-keymap-research.md` confirmed:
- `<C-'>` works reliably with Kitty keyboard protocol (CSI 39;5u encoding)
- Kitty protocol is now enabled in WezTerm (prerequisite completed)
- No Neovim-level conflicts for `<C-'>` in any mode
- `<C-\>` has prefix-key ambiguity that `<C-'>` avoids

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Single `<C-'>` keymap for dictation in normal, insert, and terminal modes
- Context-aware routing: Claude Code buffers get native voice, all others get Vosk STT
- Fix terminal insertion bug (use `chansend` instead of `nvim_put` for terminal buffers)
- Create `~/.claude/keybindings.json` with `meta+k` -> `voice:pushToTalk`
- Remove old `<C-\>` normal-mode mapping
- Expose `vim.g.stt_recording` for optional statusline integration

**Non-Goals**:
- Modifying WezTerm configuration (already done)
- Adding visual/select mode mappings
- Changing the Vosk STT pipeline itself
- Adding UI indicators beyond `vim.g.stt_recording`

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `is_claude_buffer` detection fails for edge cases | M | L | Use existing session-manager.lua function which already handles multiple buffer name patterns |
| `\x1bk` escape sequence not recognized by Claude Code | H | L | Verified `meta+k` = ESC+k; test with manual chansend before wiring keymap |
| `chansend` to wrong channel ID | H | L | Extract channel from `vim.b.terminal_job_id` with nil guard |
| Vosk STT toggle conflicts with Claude voice toggle | M | L | Routing is exclusive: Claude buffers never reach Vosk path |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Claude Code Keybindings and Context-Aware Routing Helper [COMPLETED]

**Goal**: Create the Claude Code keybindings file and add a helper function in stt/init.lua that detects whether the current buffer is a Claude Code terminal and routes accordingly.

**Tasks**:
- [ ] Create `~/.claude/keybindings.json` with `meta+k` -> `voice:pushToTalk` binding
- [ ] Add `local session_manager` require (with pcall guard) at top of stt/init.lua
- [ ] Add local helper function `_send_claude_voice_toggle(bufnr)` that:
  - Gets channel ID from `vim.b[bufnr].terminal_job_id`
  - Validates channel > 0
  - Sends `\x1bk` via `vim.fn.chansend(channel, "\x1bk")`
- [ ] Add local helper function `_is_claude_code_buffer(bufnr)` that wraps `session_manager.is_claude_buffer(bufnr)` with pcall guard, returning false on error

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `~/.claude/keybindings.json` - Create new file
- `lua/neotex/plugins/tools/stt/init.lua` - Add helper functions near top of file

**Verification**:
- `keybindings.json` exists and contains valid JSON with voice:pushToTalk binding
- Helper functions are syntactically correct (`:luafile %`)

---

### Phase 2: Unified Keymaps and Terminal Insertion Fix [COMPLETED]

**Goal**: Replace all existing STT keymaps with context-aware `<C-'>` mappings across three modes (normal, insert, terminal), fix the terminal insertion bug in `transcribe_and_insert()`, and expose recording state via `vim.g.stt_recording`.

**Tasks**:
- [ ] Remove the `<C-\>` normal-mode mapping (lines 311-315)
- [ ] Replace with `<C-'>` normal-mode mapping that routes:
  - If `_is_claude_code_buffer(current_buf)` and buftype is terminal: call `_send_claude_voice_toggle`
  - Otherwise: call `M.toggle_recording()`
- [ ] Modify the existing `<C-'>` terminal-mode mapping (lines 319-331) to add context routing:
  - If Claude Code buffer: send `meta+k` via `_send_claude_voice_toggle` (stay in terminal mode, no stopinsert)
  - Otherwise: existing behavior (stopinsert, toggle_recording, startinsert)
- [ ] Add new `<C-'>` insert-mode mapping with context routing:
  - If Claude Code buffer: not applicable (insert mode in terminal is terminal mode)
  - Otherwise: call `M.toggle_recording()` (stays in insert mode, text inserted at cursor on completion)
- [ ] Fix `transcribe_and_insert()` terminal insertion bug (around line 220):
  - After `vim.api.nvim_win_set_cursor`, check if `vim.api.nvim_buf_get_option(current_buf, 'buftype') == 'terminal'`
  - If terminal: use `vim.fn.chansend(vim.b[current_buf].terminal_job_id, text)` instead of `nvim_put`
  - If normal buffer: keep existing `nvim_put` behavior
- [ ] Set `vim.g.stt_recording = true` in `start_recording()` and `vim.g.stt_recording = false` in `stop_recording()`

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/tools/stt/init.lua` - Keymap replacements, transcribe fix, recording state

**Verification**:
- `:verbose nmap <C-'>` shows the normal-mode mapping
- `:verbose tmap <C-'>` shows the terminal-mode mapping
- `:verbose imap <C-'>` shows the insert-mode mapping
- No `<C-\>` mapping exists: `:verbose nmap <C-\>` returns nothing for STT
- `vim.g.stt_recording` toggles correctly

---

### Phase 3: Documentation and Header Update [COMPLETED]

**Goal**: Update the stt/init.lua module header documentation to reflect the new unified keymap, and verify all changes work end-to-end.

**Tasks**:
- [ ] Update module header comment block in stt/init.lua to document:
  - `<C-'>` as unified dictation key (all modes)
  - Context-aware routing behavior (Claude Code vs Vosk)
  - Removal of `<C-\>` mapping
  - `vim.g.stt_recording` global for statusline
- [ ] Verify no references to `<C-\>` STT mapping remain in the codebase (grep check)
- [ ] Verify `keybindings.json` format matches Claude Code expectations

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `lua/neotex/plugins/tools/stt/init.lua` - Header documentation

**Verification**:
- Module header accurately describes current behavior
- `grep -r 'C-\\\\.*STT\|STT.*C-\\\\' lua/` returns no matches
- All three mode mappings documented

---

## Testing & Validation

- [ ] Normal mode: `<C-'>` in a regular buffer triggers Vosk STT toggle
- [ ] Terminal mode: `<C-'>` in a non-Claude terminal triggers Vosk STT (stopinsert/startinsert)
- [ ] Terminal mode: `<C-'>` in a Claude Code buffer sends `meta+k` escape sequence
- [ ] Insert mode: `<C-'>` triggers Vosk STT toggle
- [ ] `<C-\>` no longer triggers STT in normal mode
- [ ] `vim.g.stt_recording` is `true` during recording, `false` after stop
- [ ] `transcribe_and_insert()` correctly uses `chansend` for terminal buffers
- [ ] `~/.claude/keybindings.json` exists with correct structure

## Artifacts & Outputs

- `specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/plans/02_unified-keymap-plan.md` (this file)
- `~/.claude/keybindings.json` (new file)
- `lua/neotex/plugins/tools/stt/init.lua` (modified)

## Rollback/Contingency

Revert the single file change via `git checkout HEAD -- lua/neotex/plugins/tools/stt/init.lua` and delete `~/.claude/keybindings.json`. The old `<C-\>` mapping and original terminal-mode `<C-'>` behavior will be restored.
