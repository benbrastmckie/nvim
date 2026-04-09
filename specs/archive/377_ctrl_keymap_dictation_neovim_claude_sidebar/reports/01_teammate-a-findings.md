# Teammate A Findings: Ctrl Keymaps & Claude Code Voice Dictation Integration

## Key Findings

### 1. Complete Ctrl Key Inventory

#### Global Normal Mode (`n`) Ctrl Keymaps
All defined in `/home/benjamin/.config/nvim/lua/neotex/config/keymaps.lua`:

| Key | Action |
|-----|--------|
| `<C-z>` | Disabled (prevents accidental suspension) |
| `<C-t>` | Toggle terminal window (ToggleTerm) |
| `<C-s>` | Spelling suggestions (Telescope) |
| `<C-p>` | Find files (Telescope) |
| `<C-;>` | Toggle comment on current line |
| `<C-m>` | Search man pages (Telescope) |
| `<C-CR>` | Toggle Claude Code (smart_toggle) |
| `<C-g>` | Toggle OpenCode |
| `<C-h>` | Navigate window left |
| `<C-j>` | Navigate window down |
| `<C-k>` | Navigate window up |
| `<C-l>` | Navigate window right |
| `<C-u>` | Scroll up with centering |
| `<C-d>` | Scroll down with centering |
| `<C-i>` | Jump forward in jump list |
| `<C-\>` | STT: Toggle recording (Vosk speech-to-text) |

#### Terminal Mode (`t`) Ctrl Keymaps
Buffer-local for non-Claude, non-OpenCode terminals:

| Key | Action |
|-----|--------|
| `<C-t>` | Toggle terminal (global) |
| `<C-h>` | Navigate window left |
| `<C-j>` | Navigate window down |
| `<C-k>` | Navigate window up |
| `<C-l>` | Navigate window right |
| `<C-'>` | STT: Toggle recording (terminal mode - already defined in `stt/init.lua`) |

For OpenCode terminals, `<C-j>/<C-k>` are remapped to arrow keys, and `<C-g>` toggles OpenCode.

#### Normal mode `<C-CR>` (all modes: n, i, v, t)
Toggle Claude Code sidebar — the primary sidebar toggle.

#### Ctrl keys used only in specific picker/Telescope contexts (buffer-local insert mode)
These are only active in picker UIs, not globally conflicting:
- `<C-r>`, `<C-d>`, `<C-u>`, `<C-f>`, `<C-b>`, `<C-l>`, `<C-s>`, `<C-e>`, `<C-n>`, `<C-t>`, `<C-q>`, `<C-a>` (Telescope/picker mappings)
- `<C-n>`, `<C-f>`, `<C-d>`, `<C-o>`, `<C-x>`, `<C-h>` (worktree picker)
- `<C-LeftMouse>`, `<C-LeftRelease>` (URL click support)

#### Insert mode Ctrl keymaps (global)
- `<C-CR>`: Toggle Claude Code
- `<C-g>`: Toggle OpenCode

#### Markdown buffer-local Ctrl keymaps
- `<C-n>`: Toggle checkbox (only in markdown buffers)
- `<C-D>`: Shift-tab handler for autolist

#### Currently FREE global Ctrl combinations (single key, no modifier conflict)
The following are **NOT used** globally:
- `<C-a>` — free (not globally bound; used in tmux/screen as prefix but not in nvim)
- `<C-b>` — free (tmux prefix, but not bound in nvim; used only in deprecated neoscroll)
- `<C-e>` — free (not globally bound)
- `<C-f>` — free (not globally bound; used in picker only)
- `<C-n>` — free globally (only used buffer-local in markdown)
- `<C-o>` — free globally (explicitly preserved for jump list — do NOT use)
- `<C-q>` — free (not globally bound)
- `<C-r>` — free globally (used in picker only)
- `<C-v>` — free (not bound; standard Vim block visual mode — risky)
- `<C-w>` — free (not bound; standard Vim window prefix — risky)
- `<C-x>` — free (not bound; Claude Code uses `Ctrl+X Ctrl+K` chord)
- `<C-y>` — free (not globally bound)

**Note on `<C-c>`**: The comment block in keymaps.lua mentions `<C-c>` toggles Claude Code, and MAPPINGS.md lists it. However, the actual code in keymaps.lua uses `<C-CR>` (Ctrl+Enter), not `<C-c>`. The `<C-c>` reference in the docs is outdated/inconsistent. In practice, `<C-c>` is used by Telescope (`actions.close`) and Claude Code CLI internally (hardcoded interrupt). Do NOT use `<C-c>`.

---

### 2. Existing STT/Voice Dictation Infrastructure

A full STT (Speech-to-Text) system already exists at:
- `/home/benjamin/.config/nvim/lua/neotex/plugins/tools/stt/init.lua`
- `/home/benjamin/.config/nvim/lua/neotex/plugins/tools/stt-plugin.lua`

**Current keymaps** (defined in `stt/init.lua`):
- `<leader>vr` — Start recording
- `<leader>vs` — Stop recording and transcribe
- `<leader>vv` — Toggle recording
- `<leader>vh` — Health check
- `<C-\>` (normal mode) — Toggle recording
- `<C-'>` (terminal mode) — Toggle recording in Claude Code sidebar

**How the terminal-mode mapping works** (`<C-'>`):
```lua
vim.keymap.set('t', "<C-'>", function()
  vim.cmd('stopinsert')          -- Exit terminal mode temporarily
  M.toggle_recording()           -- Start/stop Vosk recording
  vim.schedule(function()
    vim.cmd('startinsert')       -- Return to terminal mode
  end)
end, { noremap = true, silent = true, desc = "STT: Toggle recording (terminal mode, Ctrl-')" })
```

**The `<C-\>` constraint**: In terminal mode, `<C-\>` is reserved by Neovim itself (it is part of `<C-\><C-n>`, the terminal escape sequence). Therefore the terminal-mode STT binding uses `<C-'>` instead.

**Technology**: Vosk (offline, local), using `parecord` + a Python transcription script.

---

### 3. Claude Code Native Voice Dictation (`/voice`)

Claude Code v2.1.69+ (the installed version is **2.1.87**, so this is available) has native voice dictation:

- **Activation**: Run `/voice` in the Claude Code CLI to toggle voice mode on/off
- **Push-to-talk**: Default key is `Space` (hold to record, release to finalize)
- **Alternative keys**: Can be rebound via `~/.claude/keybindings.json` to modifier combinations like `meta+k`, `ctrl+v`, etc.
- **Modifier combos start instantly** (no warmup delay), while bare keys like Space require key-repeat warmup
- **Transcription**: Sent to Anthropic servers (NOT local), requires Claude.ai account authentication
- **`voiceEnabled`** setting persists across sessions
- **No current configuration**: `~/.claude/keybindings.json` does not exist; `settings.local.json` has no `voiceEnabled` key

**Keybinding configuration format** (`~/.claude/keybindings.json`):
```json
{
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "ctrl+v": "voice:pushToTalk",
        "space": null
      }
    }
  ]
}
```

**Key constraints for Claude Code bindings**:
- `ctrl+c` — reserved (hardcoded interrupt)
- `ctrl+d` — reserved (hardcoded exit)
- `ctrl+m` — reserved (identical to Enter)
- `ctrl+b` — conflicts with tmux prefix
- `ctrl+a` — conflicts with GNU screen prefix
- `ctrl+z` — reserved (SIGTSTP)

**Already-used Claude Code bindings**:
- `ctrl+l` — `chat:clearInput`
- `ctrl+s` — `chat:stash`
- `ctrl+g`, `ctrl+x ctrl+e` — `chat:externalEditor`
- `ctrl+r` — `history:search`
- `ctrl+t` — `app:toggleTodos`
- `ctrl+o` — `app:toggleTranscript`
- `ctrl+x ctrl+k` — `chat:killAgents`
- `ctrl+b` — `task:background` (and tmux conflict)
- `ctrl+v` — `chat:imagePaste`

**Note**: `ctrl+v` is `chat:imagePaste` in Claude Code's Chat context — risky to rebind.

---

### 4. How to Detect the Claude Code Sidebar Buffer

From `keymaps.lua` (set_terminal_keymaps):
```lua
local bufname = vim.api.nvim_buf_get_name(0)
local is_claude = bufname:match("claude") or bufname:match("ClaudeCode")
```

From `claudecode.lua`:
```lua
vim.bo.filetype = "claude-code"
-- and:
if vim.bo.buftype == "terminal" and (bufname:match("claude") or bufname:match("ClaudeCode")) then
```

From `session-manager.lua`:
```lua
function M.is_claude_buffer(bufnr)  -- public API
```

So detection can use: `vim.bo.filetype == "claude-code"` or `vim.bo.buftype == "terminal"` + buffer name matching.

---

## Recommended Approach

### Two-Track Strategy

The task says "ctrl-based keymap for triggering dictation in Neovim with Claude Code sidebar voice recording support." This can be implemented two ways — or both:

#### Track A: Neovim-Side STT (Vosk, already exists)
**Current state**: Already implemented with `<C-\>` (normal) and `<C-'>` (terminal).

**The problem with `<C-\>` in terminal mode**: `<C-\>` is reserved by Neovim (part of `<C-\><C-n>` escape sequence), so terminal-mode uses `<C-'>` instead. However, `<C-'>` may not be ergonomic or well-known.

**Recommendation**: The existing `<C-'>` terminal-mode binding is the correct approach. The task may want a more intuitive or standardized ctrl key. Options:

- `<C-'>` — already implemented, works, but unusual
- `<C-\>` — works in normal mode; terminal mode would need stopinsert trick (already done for `<C-'>`)

Since `<C-\>` in terminal mode is NOT available (reserved by Neovim for `<C-\><C-n>`), the approach using `<C-'>` is correct and should be kept.

**If a new ctrl key is desired**: `<C-e>` is free globally and not used in Claude Code defaults. `<C-y>` and `<C-q>` are also free.

#### Track B: Claude Code Native Voice (`/voice` with push-to-talk)
**Claude Code's native voice** is more powerful (server-side transcription, no local Vosk model needed, coding vocabulary tuned).

**To enable a ctrl-based push-to-talk**:
1. Run `/voice` in Claude Code to enable voice mode
2. Create `~/.claude/keybindings.json`:
```json
{
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "ctrl+space": "voice:pushToTalk"
      }
    }
  ]
}
```

**Best ctrl key for Claude Code push-to-talk**:
- `ctrl+space` — not listed as used by Claude Code, not reserved, ergonomic
- `meta+k` / `meta+v` — modifier combos that start instantly (no warmup)
- Avoid `ctrl+v` (already `chat:imagePaste`), `ctrl+s`, `ctrl+r`, `ctrl+o`, `ctrl+t`, `ctrl+l`, `ctrl+g`

**From the Neovim side**: The Claude Code terminal buffer is `buftype=terminal`. The Neovim `t` mode keymap would need to send the key to the Claude Code process. This is non-trivial because terminal-mode mappings intercept before sending to the program. The most practical approach is to map a Neovim terminal-mode key that sends the ctrl sequence through to Claude Code:

```lua
-- In terminal mode, send ctrl+space to Claude Code's push-to-talk
vim.keymap.set('t', '<C-Space>', function()
  -- Claude Code is already in insert/typing mode in terminal
  -- We need to send the raw keystroke to the process
  vim.api.nvim_feedkeys(
    vim.api.nvim_replace_termcodes('<C-Space>', true, false, true),
    't', -- 't' mode sends to terminal
    false
  )
end, { buffer = true, desc = "Claude Code: Push-to-talk voice dictation" })
```

**Simpler approach**: Just configure Claude Code to use a modifier combo that naturally passes through the terminal without needing Neovim intervention. Most modifier+key combos (like `meta+k`) are passed through terminal buffers transparently.

#### Recommended Combined Implementation

1. **For Claude Code native voice** (preferred for dictation INTO Claude Code prompts):
   - Add `~/.claude/keybindings.json` binding `ctrl+space` or `meta+k` to `voice:pushToTalk`
   - From Neovim, no special mapping needed if using modifier combos that pass through
   - Add a Neovim `<leader>av` or similar command to toggle `/voice` mode in Claude Code

2. **For general Neovim STT** (existing Vosk system, types into any buffer):
   - Keep existing `<C-\>` (normal mode) and `<C-'>` (terminal mode)
   - Consider adding `<C-Space>` as an additional terminal-mode toggle for ergonomics

**Best single ctrl key to add** (doesn't conflict): `<C-Space>` is not in the current inventory and is a natural "voice activation" key. However, the constraint is that in terminal mode, `<C-Space>` sends a null byte (`\0`) in many terminals — behavior varies by terminal emulator.

**Most robust option**: Use `meta+k` (Alt+k) for the Claude Code push-to-talk binding and a Neovim terminal-mode mapping for `<M-k>` that is aware of the Claude Code buffer context.

---

## Evidence/Examples

### From `stt/init.lua` — existing terminal-mode STT:
```lua
vim.keymap.set('t', "<C-'>", function()
  vim.cmd('stopinsert')
  M.toggle_recording()
  vim.schedule(function() vim.cmd('startinsert') end)
end, { noremap = true, silent = true, desc = "STT: Toggle recording (terminal mode, Ctrl-')" })
```

### From `claudecode.lua` — comment confirming this design:
```lua
-- Note: Terminal STT toggle (<C-'>) is defined globally in stt/init.lua
-- Note: <C-CR> mapping for Claude Code toggle is defined in keymaps.lua
```

### Claude Code keybindings.json example for voice:
```json
{
  "bindings": [
    {
      "context": "Chat",
      "bindings": {
        "meta+k": "voice:pushToTalk",
        "space": null
      }
    }
  ]
}
```

### Free ctrl keys confirmed:
- `<C-e>`, `<C-y>`, `<C-q>`, `<C-n>` (global), `<C-Space>` (terminal-dependent)

---

## Confidence Level

**High confidence**:
- Complete ctrl keymap inventory from source code
- Claude Code v2.1.87 is installed (voice support confirmed available)
- `~/.claude/keybindings.json` does not exist (no conflicts to worry about)
- Existing STT module uses `<C-'>` for terminal mode (already implemented)
- `<C-\>` cannot be used in terminal mode (Neovim reserved)
- Official docs confirm `meta+k` as the recommended modifier combo for instant push-to-talk

**Medium confidence**:
- Whether `<C-Space>` works reliably in this specific terminal setup (Kitty) — needs testing
- Whether Claude Code native `/voice` is enabled for this account (it was ~5% rollout in March 2026; may or may not be available)

**Low confidence**:
- Whether the user wants Track A (Vosk/local), Track B (Claude Code native), or both
- Exact ergonomic preference for the new ctrl key

---

## Summary

The implementation should focus on two complementary approaches:

1. **Claude Code native voice** (`/voice` with `voice:pushToTalk`): Create `~/.claude/keybindings.json` binding `meta+k` (or `ctrl+space`) to push-to-talk. This handles dictation within the Claude Code sidebar prompt.

2. **Neovim-side STT** (already implemented): The `<C-\>` (normal) and `<C-'>` (terminal) bindings exist and work. If a new ctrl key is desired for the terminal-mode binding, `<C-e>` or `<C-y>` are clean options, but `<C-'>` is already functional.

The task description says "ctrl-based keymap for triggering dictation in Neovim with Claude Code sidebar voice recording support" — this most directly points to configuring Claude Code's native `/voice` push-to-talk via `keybindings.json`, with an appropriate modifier combo that works within the Neovim terminal buffer context.
