# Teammate C (Critic) Findings: Task 377 - Ctrl Keymap Dictation

**Date**: 2026-04-08
**Role**: Critic - gaps, blind spots, unvalidated assumptions
**Task**: Add ctrl-based keymap for triggering dictation with Claude Code sidebar support

---

## Key Findings

### Finding 1: The STT Infrastructure Already Exists

The task description implies this is a greenfield feature, but **a full STT implementation already exists** in this codebase:

- `/lua/neotex/plugins/tools/stt/init.lua` - Complete Vosk-based STT module
- `/lua/neotex/plugins/tools/stt-plugin.lua` - Lazy.nvim plugin spec
- `~/.local/bin/vosk-transcribe.py` - Transcription script (exists on disk)
- `~/.local/share/vosk/vosk-model-small-en-us` - Model (installed)
- `vosk` Python package - Installed
- `parecord` - Available

The STT module already has **exactly the ctrl keymaps described**:
- `<C-\>` in normal mode (`stt/init.lua` line 311) - toggle recording
- `<C-'>` in terminal mode (`stt/init.lua` line 319) - for Claude Code sidebar

This fundamentally changes the nature of the task from "implement" to "assess/fix" existing implementation.

### Finding 2: The Keymap Documentation is Misleading

The header comment in `keymaps.lua` (lines 23, 78) says `<C-c>` "Toggle Claude Code", but **there is no actual `<C-c>` keymap definition anywhere in the codebase**. The actual Claude Code toggle is `<C-CR>` (Ctrl+Enter) defined on lines 265-279. This is stale documentation that could mislead research.

The real Ctrl keymap inventory from code (not comments):
- `<C-z>` - disabled (suspend)
- `<C-t>` - toggle terminal (n + t modes)
- `<C-s>` - spell suggestions
- `<C-p>` - find files
- `<C-;>` - toggle comment
- `<C-m>` - man pages
- `<C-CR>` - Claude Code toggle (all modes)
- `<C-g>` - OpenCode toggle (n + i modes)
- `<C-h/j/k/l>` - window navigation (n mode)
- `<C-i>` - jump forward
- `<C-u/d>` - scroll half-page
- `<C-\>` - STT toggle recording (n mode, in stt/init.lua)
- `<C-'>` - STT toggle (t mode, in stt/init.lua)
- `<C-D>` - list unindent (i mode, buffer-local markdown)
- `<C-n>` - increment checkbox (n mode, buffer-local markdown)
- blink-cmp: `<C-k/j>` select, `<C-b/f>` scroll docs, `<C-space>` show, `<C-e>` hide (i mode)

### Finding 3: Keymaps Are NOT "Entirely Contained in which-key.lua and keymap.lua"

Ctrl keymaps are defined in at least **6 different locations**:
1. `lua/neotex/config/keymaps.lua` - global non-leader keys
2. `lua/neotex/plugins/editor/which-key.lua` - leader keys only
3. `lua/neotex/plugins/tools/stt/init.lua` - `<C-\>` and `<C-'>` (always set in setup())
4. `lua/neotex/plugins/lsp/blink-cmp.lua` - insert mode completion keys
5. `lua/neotex/plugins/editor/telescope.lua` - `<C-c>` close picker
6. `lua/neotex/plugins/tools/himalaya/` - multiple buffer-local `<C-d/u/f/b/q/a>` in email UIs
7. `after/ftplugin/lectic.markdown.lua` - `<C-n>` buffer-local
8. Various Telescope pickers in claude worktree and picker init

The claim that keymaps are centralized is an aspirational policy, not current reality.

### Finding 4: Critical Bug in Terminal Mode STT Insertion

The terminal mode handler (`stt/init.lua` lines 319-331) has a **logic flaw** for inserting text into the Claude Code sidebar:

```lua
vim.keymap.set('t', "<C-'>", function()
  vim.cmd('stopinsert')        -- exit terminal mode to normal mode
  M.toggle_recording()          -- starts/stops recording
  vim.schedule(function()
    vim.cmd('startinsert')      -- returns to terminal insert
  end)
end, ...)
```

When `toggle_recording()` *stops* recording, `transcribe_and_insert()` runs **asynchronously**. By the time transcription completes and `nvim_put()` is called:
- The code checks `vim.api.nvim_get_current_buf() == current_buf` - this is the terminal buffer
- `nvim_put()` on a terminal buffer does **not** send text to the terminal process; it inserts into the buffer's text representation, which is read-only for terminal buffers
- The correct approach is `vim.fn.chansend(job_id, text)` to send text to the Claude Code process

The `startinsert` call in `vim.schedule()` fires immediately after `toggle_recording()` returns, but recording is async - the user returns to terminal insert mode before transcription finishes. The text appears to get discarded (or worse, inserted at cursor position in normal mode state that was briefly active).

---

## Gaps and Blind Spots

### Gap 1: "Claude Code sidebar voice recording support" is Undefined

The task title says "Claude Code sidebar voice recording support" but this could mean:
1. Trigger recording from inside the Claude Code terminal buffer
2. Insert transcribed text into the Claude Code input prompt
3. Use Claude Code's own voice input feature (if it has one)
4. Record audio and paste transcription into whatever buffer is current

The existing implementation attempts interpretation #1 and #2 together, but fails at #2 (see Finding 4).

### Gap 2: No State Indicator for Active Recording

When recording is active, there is no persistent indicator. The `is_recording` flag is module-local Lua state with no vim variable exposure. If the user:
- Opens a new buffer
- Switches windows
- Triggers a different action

...there is no way to know recording is happening except through the `notify` call at start (which disappears). No statusline integration, no `vim.g.stt_recording` global flag.

### Gap 3: The C-' Key May Not Be Distinguishable by Terminal Emulator

`<C-'>` (Ctrl+apostrophe) is a non-standard key combination. In traditional terminal protocols, Ctrl+key is only reliably distinguished for letters, `[`, `\`, `]`, `^`, `_`, `@`. Apostrophe (ASCII 39) may or may not be sent as a distinct code depending on:
- The terminal emulator (WezTerm vs Kitty vs standard xterm)
- Whether the Kitty Keyboard Protocol or CSI-u protocol is active

This config uses WezTerm/Kitty (see `terminal-commands.lua`). With Kitty protocol enabled (which this config does conditionally), `<C-'>` may work. Without it, the key may be silently swallowed or sent as a bare `'`.

### Gap 4: C-\ Conflict with Terminal Mode Semantics

`<C-\>` is the traditional terminal-mode escape prefix in Neovim (`<C-\><C-n>` exits terminal mode). While the STT plugin registers `<C-\>` only in normal mode (`'n'`), this can create confusion: users who accidentally type `<C-\>` expecting to start `<C-\><C-n>` will trigger recording instead.

### Gap 5: Concurrent Recording Race Condition

The `is_recording` guard exists but is not atomic. In theory (and in async Lua):
1. User presses `<C-\>` in normal mode AND `<C-'>` in terminal mode nearly simultaneously
2. Both calls see `is_recording = false` before either sets it to `true`
3. Two `parecord` processes start writing to the same `/tmp/nvim-stt-recording.wav`

This is unlikely in practice but a real failure mode.

### Gap 6: The Normal-Mode C-\ Keymap Is Set Outside Which-Key

`stt/init.lua` line 311 calls `vim.keymap.set('n', '<C-\>', ...)` directly, bypassing the centralized keymap system. This key doesn't appear in `:WhichKey` or in the docs at `keymaps.lua`. It's an invisible global keymap.

---

## Unvalidated Assumptions

### Assumption 1: "Claude Code sidebar" = terminal buffer with `claude` in name

**Status**: PARTIALLY VALIDATED. The `claudecode.lua` autocmd confirms Claude Code runs as a terminal buffer with `claude` or `ClaudeCode` in the buffer name. The terminal mode `<C-'>` mapping fires for ANY terminal buffer, not specifically Claude Code.

### Assumption 2: Text can be inserted into the Claude Code terminal prompt

**Status**: UNVALIDATED. The current approach uses `nvim_put` which is wrong for terminal buffers. The correct approach would be `chansend` to send to the terminal process's stdin. However, Claude Code reads input through its own TUI, not raw stdin - so even `chansend` may not work as expected. Claude Code may have its own input handling that ignores programmatic text injection.

### Assumption 3: The `<C-\>` mapping doesn't conflict with anything

**Status**: PARTIALLY INVALID. While `<C-\>` in normal mode is not mapped elsewhere in this config (confirmed), it IS a meaningful vim sequence prefix (`<C-\><C-n>`) in normal mode, though normal mode doesn't use it for terminal escape. The terminal-mode handling in `keymaps.lua` uses `<C-\><C-n>` explicitly (line 126), and `<C-\>` is already used as a prefix character by Neovim itself.

### Assumption 4: parecord captures the correct audio device

**Status**: UNVALIDATED. `parecord` uses PulseAudio/PipeWire defaults. If the user's microphone is not set as the default source in PulseAudio, recording will fail silently (capturing from a non-existent or wrong source) or produce silence. The health check doesn't verify audio device availability - only that the binary exists.

### Assumption 5: Vosk transcription latency is acceptable

**Status**: UNVALIDATED. The `vosk-model-small-en-us` is a small model (~40MB) but transcription latency depends on recording length and CPU. For a 30-second max recording, transcription could take several seconds. There's no progress indicator during transcription, and the `notify("Transcribing...")` call was explicitly commented out.

---

## Risk Assessment

| Risk | Severity | Likelihood | Notes |
|------|----------|-----------|-------|
| Text insertion into Claude Code sidebar fails silently | HIGH | HIGH | `nvim_put` wrong API for terminal buffers |
| `<C-'>` not recognized by terminal emulator | HIGH | MEDIUM | Depends on keyboard protocol active |
| Documentation mismatch (`<C-c>` phantom mapping) | MEDIUM | HIGH | Already present, confusing researchers |
| No recording state indicator | MEDIUM | HIGH | User won't know recording is active |
| STT keymaps bypass centralized keymap system | LOW | HIGH | Already the case, cosmetic issue |
| `parecord` captures wrong audio device | HIGH | LOW | Depends on system audio config |
| Concurrent recording race condition | LOW | LOW | Extremely unlikely in practice |

---

## What the Task Actually Needs (Critical Assessment)

The task description ("Add a ctrl-based keymapping for triggering dictation") implies the feature doesn't exist. **It does exist.** The real gaps are:

1. **The terminal-mode text insertion is broken** for inserting transcribed text into a terminal buffer (wrong API)
2. **The C-' key may be unreliable** across terminal emulators without Kitty protocol
3. **No recording state visibility** in statusline or via vim global
4. **The keymap is undocumented** in the centralized keymap system
5. **No test for whether the target buffer is actually Claude Code** - the terminal mode mapping fires everywhere

The task should probably be reframed as: "Fix and document the existing STT dictation keymaps for Claude Code sidebar integration."

---

## Confidence Level

- **Keymap inventory accuracy**: HIGH - comprehensive grep across all lua files confirms scope
- **STT infrastructure existence**: HIGH - all files confirmed on disk, dependencies verified
- **Terminal buffer insertion bug**: MEDIUM-HIGH - behavior inferred from API semantics; `nvim_put` in terminal mode behavior needs empirical verification
- **C-' terminal compatibility**: MEDIUM - depends on runtime terminal emulator config not inspectable from static analysis
- **Assumption about C-c phantom mapping**: HIGH - confirmed no actual map() call exists
