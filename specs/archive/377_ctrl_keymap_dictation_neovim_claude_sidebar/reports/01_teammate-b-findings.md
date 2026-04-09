# Teammate B Research Findings: Alternative Patterns and Prior Art
# Task 377: Ctrl-Based Keymap for Dictation in Neovim / Claude Code Sidebar

**Researcher**: Teammate B (Alternative Approaches)
**Date**: 2026-04-08
**Focus**: Alternative voice dictation tools, prior art, keymap patterns, cross-platform approaches

---

## Key Findings

### 1. Claude Code Native Voice Dictation (Primary Discovery)

Claude Code v2.1.69+ has **native push-to-talk voice dictation** built in, enabled with `/voice`.

**Critical technical details:**
- Default push-to-talk key: `Space` (hold to record, release to finalize)
- Configurable via `~/.claude/keybindings.json` under `"voice:pushToTalk"` in `"Chat"` context
- Recommended alternative: `meta+k` (modifier combo, starts recording immediately without warmup)
- Hold `Space` detection uses key-repeat events from the terminal; modifier combos skip this warmup entirely
- Transcription is streamed live (text appears dimmed until finalized)
- Audio streams to Anthropic servers (requires Claude.ai account, not API key)
- On Linux, falls back to `arecord` (ALSA) or `rec` (SoX) if native module cannot load
- Language configurable via `/config` or `settings.json`

**Keybinding configuration example:**
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

**Implication**: The task of "triggering dictation" in Claude Code already has a native mechanism. The Neovim keymap would be a convenience wrapper to either (a) focus the Claude terminal and engage voice mode, or (b) trigger a key event in the Claude terminal's context.

---

### 2. Existing Neovim Voice Dictation Plugins (Prior Art)

Several mature plugins exist for comparison:

#### whisper.nvim (Avi-D-coder)
- Toggle approach: `<C-g>` starts, `<Space>` inserts mid-session, `<C-g>` again stops
- Supports local models (tiny.en through medium.en)
- Lualine integration for status (`Recording`, `Processing...`)
- State management: binary toggle flag + streaming mode with `poll_interval_ms`
- Key insight: **toggle style is preferred over hold for insert-mode use** (avoids accidental firing)

#### vocal.nvim (kyza0d)
- Lightweight, OpenAI Whisper API or local models
- Records directly within Neovim, inserts into buffer

#### whisper-vim (fernandonobel)
- Shell script approach: `sox` records, `whisper-cli` transcribes
- Simple and composable

#### gp.nvim (Robitx)
- Full AI plugin with voice: transcription replaces current line, visual selection, or range
- Supports Anthropic backend

#### speech-to-text.nvim (eyalk11)
- `:Voice` command, multiple engine support (whisper, OpenAI, Google, Azure)

**Common pattern**: All plugins use either toggle (press once start, press again stop) or a dedicated command. None use hold-to-record natively in Neovim (hold requires key-repeat detection, which is unreliable in terminal contexts outside of Claude Code's own input loop).

---

### 3. Alternative Keymap Approaches

#### Toggle Pattern (Recommended for Neovim)
- Press `<C-k>` (or similar) once to start recording, press again to stop
- State stored in a module-level boolean: `local is_recording = false`
- Most reliable approach for Neovim; avoids key-repeat timing issues
- Used by: whisper.nvim, nvim-recorder, NeoComposer

#### Hold-to-Record (Not Recommended for Neovim)
- Requires key-repeat detection; Claude Code does this by watching rapid repeat events in its own input loop
- In Neovim, a held key in terminal mode simply floods input to the running process
- `<C-\><C-n>` is needed to exit terminal mode; this disrupts hold semantics
- **Conclusion**: Hold-to-record is impractical from a Neovim keymap; better to use Claude Code's native hold mechanism once focused in the terminal

#### Focus-then-Trigger Pattern (Hybrid)
- From normal mode in Neovim: `<C-k>` focuses the Claude terminal and enters insert mode
- Claude Code's own `Space` (or rebound `meta+k`) handles the hold-to-record once the terminal is focused
- This is architecturally clean: Neovim handles navigation, Claude Code handles voice

#### Two-Step Toggle via `vim.fn.chansend()`
- Alternative: Neovim keymap focuses Claude terminal AND injects a key sequence into it
- `vim.fn.chansend(job_id, "\x1bk")` would inject `meta+k` if Claude Code is bound to it
- Requires knowing the terminal buffer's `b:terminal_job_id`
- Technically possible but fragile (escape code translation depends on terminal emulator)

---

### 4. Linux Voice Recording Building Blocks

#### arecord + whisper.cpp pipeline
```bash
arecord -f S16_LE -r 16000 -c 1 -t wav - | ./whisper-cli -m model.bin -f -
```
- Direct pipe from microphone to transcription
- Claude Code already falls back to `arecord` on Linux when native module unavailable

#### Toggle via PID file (whisper-hotkey-linux pattern)
```bash
if [ -f /tmp/whisper-recording.pid ]; then
  kill $(cat /tmp/whisper-recording.pid)  # stop
else
  arecord ... & echo $! > /tmp/whisper-recording.pid  # start
fi
```
- Global hotkey (F9) triggers shell script that checks PID file
- Clean toggle without key-repeat semantics

#### Clipboard insertion pattern
- Many Linux tools (whisper-hotkey-linux, openwhispr, linux-whisper) use:
  1. Record audio on hotkey press
  2. Transcribe with whisper.cpp locally
  3. Copy to clipboard via `xclip`/`xdotool`/`wl-clipboard`
  4. User pastes manually or tool auto-pastes at cursor
- **Not appropriate** for Claude Code terminal (need text in the input box, not clipboard paste)

---

### 5. Claude Code Neovim Plugins (Ecosystem Context)

Several Neovim-Claude Code integration plugins exist but **none implement voice dictation**:

#### coder/claudecode.nvim
- WebSocket MCP protocol (RFC 6455), zero external dependencies
- Commands: `:ClaudeCode` toggle, `:ClaudeCodeFocus`, `:ClaudeCodeSend`
- Input via standard terminal; no voice support
- Terminal `job_id` accessible via `b:terminal_job_id` on the Claude buffer

#### greggh/claude-code.nvim
- Simple terminal toggle with single keypress

#### The existing neotex config (this repo)
- Uses `claude-code` plugin internally
- `M.find_claude_window()` finds Claude window by buffer name match
- `M.open_claude()` opens and auto-enters insert mode with `vim.defer_fn`
- Access to terminal channel via `vim.b.terminal_job_id` or `vim.fn.jobstart()`

---

### 6. Key Technical Constraint: Terminal Mode in Neovim

In Neovim terminal mode:
- All keys except `<C-\>` are passed directly to the running process
- `<C-\><C-n>` exits terminal mode (returns to normal mode)
- Terminal-mode keymaps use `:tnoremap` / `vim.keymap.set("t", ...)`
- To send input to a terminal buffer from Lua: `vim.fn.chansend(job_id, text)`
- To inject special keys: `vim.api.nvim_replace_termcodes()` converts notation like `<M-k>`

This means a `<C-k>` keymap defined in terminal mode would **intercept** the key before Claude Code sees it—this is exactly what we want.

---

## Recommended Approach

Based on the research, the cleanest implementation is a **two-phase keymap**:

### Phase 1: Native Claude Code voice (simplest path)
- Rebind Claude Code's push-to-talk from `Space` to `ctrl+k` or `meta+k` in `~/.claude/keybindings.json`
- This is fully supported and documented
- Requires user to already be in Claude Code's input box
- No Neovim Lua code needed for the voice trigger itself

### Phase 2: Neovim convenience wrapper (adds ergonomics)
A single `<C-k>` keymap (normal mode) that:
1. Finds the Claude terminal window using `M.find_claude_window()`
2. Focuses it (`vim.api.nvim_set_current_win(win)`)
3. Enters terminal insert mode (`vim.cmd("startinsert")`)
4. Optionally injects the `meta+k` key event into the channel to start recording immediately

```lua
vim.keymap.set("n", "<C-k>", function()
  local terminal = require("neotex.plugins.ai.claude.claude-session.terminal")
  local win = terminal.find_claude_window()
  if win then
    vim.api.nvim_set_current_win(win)
    vim.defer_fn(function()
      vim.cmd("startinsert")
      -- Optional: auto-trigger voice by injecting meta+k
      local buf = vim.api.nvim_win_get_buf(win)
      local job_id = vim.b[buf].terminal_job_id
      if job_id then
        local key = vim.api.nvim_replace_termcodes("<M-k>", true, true, true)
        vim.fn.chansend(job_id, key)
      end
    end, 50)
  end
end, { desc = "Focus Claude and trigger voice dictation" })
```

### Alternative: Pure keybindings.json approach (zero Lua)
If the user primarily works within Claude Code's terminal, simply rebinding `voice:pushToTalk` to `ctrl+k` in `~/.claude/keybindings.json` is sufficient with no Neovim plugin code required.

---

## Evidence / Examples

| Tool | Approach | Key | State Management |
|------|----------|-----|-----------------|
| Claude Code native | Hold | `Space` or `meta+k` | Key-repeat detection in input loop |
| whisper.nvim | Toggle | `<C-g>` | Module-level boolean |
| whisper-hotkey-linux | Toggle | F9 | PID file |
| openwhispr | Toggle | Custom global | Process state |
| gp.nvim | Command | Custom | Plugin state |

**Key insight from Claude Code docs**: The recommended binding for instant activation (no warmup) is a modifier combination. `ctrl+k` expressed in keybindings.json as `"ctrl+k": "voice:pushToTalk"` would work directly, or `"meta+k"` for Alt+k.

---

## Confidence Level

| Finding | Confidence |
|---------|-----------|
| Claude Code native voice dictation exists and is configurable | **High** - official docs confirm |
| `meta+k` / modifier combos skip warmup | **High** - official docs confirm |
| Toggle is better than hold for Neovim-level keymaps | **High** - architectural constraint |
| `vim.fn.chansend()` can inject keys into terminal buffer | **High** - Neovim API documented |
| Existing Neovim config has `find_claude_window()` available | **High** - read source code |
| Auto-inject of `meta+k` will reliably trigger Claude Code voice | **Medium** - terminal escape code translation varies |
| Pure keybindings.json approach is sufficient for most use cases | **High** |

---

## Summary for Synthesis

The core finding is that **Claude Code already has the voice infrastructure**. The Neovim keymap task reduces to:

1. **Minimum viable**: Add `"ctrl+k": "voice:pushToTalk"` (or `meta+k`) to `~/.claude/keybindings.json`
2. **Enhanced**: Add Neovim normal-mode `<C-k>` keymap that focuses Claude terminal and enters insert mode, so the user can trigger voice from anywhere in the editor
3. **Full automation**: Optionally inject the push-to-talk key via `chansend()` after focusing, combining both steps into one keystroke

The toggle pattern (used by whisper.nvim and others) is the right model for a **standalone** dictation module, but since Claude Code already handles the voice loop natively, the Neovim side only needs to handle **navigation and focus**.
