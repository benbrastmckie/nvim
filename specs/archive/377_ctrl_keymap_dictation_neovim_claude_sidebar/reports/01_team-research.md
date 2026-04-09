# Research Report: Task #377

**Task**: Add ctrl-based keymap for triggering dictation in Neovim with Claude Code sidebar voice recording support
**Date**: 2026-04-08
**Mode**: Team Research (4 teammates)

## Summary

The research reveals a **critical reframing**: the core dictation infrastructure already exists in this codebase (`stt/init.lua` with `<C-\>` normal mode and `<C-'>` terminal mode), but has bugs and gaps. Additionally, Claude Code v2.1.87 has **native voice dictation** (`/voice` command with configurable `voice:pushToTalk` keybinding) that provides a superior path for dictation within the Claude Code sidebar. The implementation should combine both: fix the existing Vosk STT for general Neovim use, and configure Claude Code's native voice for sidebar-specific dictation.

## Key Findings

### 1. Existing STT System (All Teammates Confirmed)

A complete Vosk-based speech-to-text system exists at `lua/neotex/plugins/tools/stt/init.lua`:
- `<C-\>` (normal mode) — toggle recording globally
- `<C-'>` (terminal mode) — toggle recording in Claude Code sidebar
- `<leader>vr/vs/vv/vh` — start/stop/toggle/health check
- Backend: `parecord` + `vosk-transcribe.py` (offline, local)
- Model: `vosk-model-small-en-us` installed at `~/.local/share/vosk/`

### 2. Claude Code Native Voice Dictation (Teammates A, B)

Claude Code v2.1.87 (installed) supports native push-to-talk voice:
- Activate with `/voice` command in Claude Code
- Default push-to-talk key: `Space` (hold to record)
- **Configurable** via `~/.claude/keybindings.json` with `voice:pushToTalk` action
- Modifier combos (e.g., `meta+k`) start recording instantly (no key-repeat warmup)
- Transcription streamed to Anthropic servers (not local)
- On Linux, falls back to `arecord` or `sox` for audio capture
- **`~/.claude/keybindings.json` does not yet exist** — no current configuration

Keybinding configuration format:
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

### 3. Complete Ctrl Keymap Inventory (Teammates A, C)

**Global normal mode**:
| Key | Action | Source |
|-----|--------|--------|
| `<C-z>` | Disabled (suspend) | keymaps.lua |
| `<C-t>` | Toggle terminal | keymaps.lua |
| `<C-s>` | Spelling suggestions | keymaps.lua |
| `<C-p>` | Find files | keymaps.lua |
| `<C-;>` | Toggle comment | keymaps.lua |
| `<C-m>` | Man pages | keymaps.lua |
| `<C-CR>` | Claude Code toggle | keymaps.lua |
| `<C-g>` | OpenCode toggle | keymaps.lua |
| `<C-h/j/k/l>` | Window navigation | keymaps.lua |
| `<C-u/d>` | Scroll half-page | keymaps.lua |
| `<C-i>` | Jump forward | keymaps.lua |
| `<C-\>` | STT toggle recording | stt/init.lua |

**Terminal mode**:
| Key | Action | Source |
|-----|--------|--------|
| `<C-t>` | Toggle terminal | keymaps.lua |
| `<C-h/j/k/l>` | Window navigation | keymaps.lua |
| `<C-'>` | STT toggle recording | stt/init.lua |

**Free globally**: `<C-a>`, `<C-b>`, `<C-e>`, `<C-f>`, `<C-n>` (global), `<C-q>`, `<C-r>` (global), `<C-x>`, `<C-y>`

**Insert mode (context-specific)**: blink-cmp uses `<C-k/j/b/f/space/e>` in insert mode

### 4. Keymaps Are Scattered (Critic Finding)

Ctrl keymaps are defined in **6+ locations**, not just `keymaps.lua` and `which-key.lua`:
1. `lua/neotex/config/keymaps.lua` — global non-leader
2. `lua/neotex/plugins/editor/which-key.lua` — leader keys only
3. `lua/neotex/plugins/tools/stt/init.lua` — `<C-\>` and `<C-'>`
4. `lua/neotex/plugins/lsp/blink-cmp.lua` — insert mode completion
5. `lua/neotex/plugins/editor/telescope.lua` — picker-local
6. `lua/neotex/plugins/tools/himalaya/` — email UI buffer-local
7. `after/ftplugin/` — filetype buffer-local

### 5. Terminal Insertion Bug (Critic Finding — HIGH Priority)

The terminal-mode `<C-'>` handler has a **critical bug**: after transcription completes, it uses `nvim_put()` to insert text, but terminal buffers are read-only to `nvim_put`. The correct API is `vim.fn.chansend(job_id, text)` to send text to the terminal process.

Current broken flow:
```
<C-'> → stopinsert → toggle_recording() → startinsert
                         ↓ (async)
              transcribe_and_insert() → nvim_put() ← FAILS on terminal buffer
```

### 6. Stale Documentation (Critic Finding)

`keymaps.lua` header comment documents `<C-c>` as "Toggle Claude Code" but **no such mapping exists**. The actual toggle is `<C-CR>`. This is misleading.

## Synthesis

### Conflicts Resolved

| Conflict | Resolution | Reasoning |
|----------|-----------|-----------|
| `meta+k` vs `ctrl+k` for Claude Code voice | **`meta+k` preferred** | Starts instantly (no warmup), doesn't conflict with `<C-k>` (blink-cmp select up in insert mode) |
| Keep Vosk STT vs switch to Claude Code native only | **Keep both** | Vosk is offline/private for general use; Claude Code native is superior for sidebar-specific dictation |
| Greenfield implementation vs fix existing | **Fix + enhance existing** | STT infrastructure exists; needs bug fixes and Claude Code native voice configuration |

### Gaps Identified

1. **Terminal text insertion is broken** — `nvim_put()` must be replaced with `chansend()`
2. **No recording state indicator** — `is_recording` is module-local with no statusline integration
3. **`<C-'>` terminal compatibility uncertain** — depends on Kitty keyboard protocol being active
4. **STT keymaps bypass centralized system** — `<C-\>` set directly in `stt/init.lua`, invisible to `:WhichKey`
5. **No Claude Code native voice configured** — `~/.claude/keybindings.json` doesn't exist
6. **Stale `<C-c>` documentation** in `keymaps.lua` header

### Recommendations

#### Track A: Claude Code Native Voice (Primary — for sidebar dictation)

1. **Create `~/.claude/keybindings.json`** binding `meta+k` to `voice:pushToTalk`
2. **No Neovim keymap needed** — `meta+k` (Alt+k) passes through terminal buffers transparently
3. User activates voice mode with `/voice` in Claude Code, then holds `Alt+k` to dictate
4. This is the **best practice for April 2026** per Claude Code documentation

#### Track B: Fix Existing Vosk STT (Secondary — for general Neovim dictation)

1. **Fix terminal insertion bug** — replace `nvim_put()` with `chansend()` in terminal buffer context
2. **Keep `<C-\>` (normal) and `<C-'>` (terminal)** as existing keymaps
3. **Add recording state indicator** — expose `vim.g.stt_recording` for statusline integration
4. **Register `<C-\>` in centralized keymap system** for discoverability
5. **Fix stale `<C-c>` documentation** in `keymaps.lua`

#### Track C: Neovim Convenience Wrapper (Optional enhancement)

A normal-mode keymap (e.g., `<C-e>` — free globally) that:
1. Finds the Claude Code window via `find_claude_window()`
2. Focuses it and enters terminal insert mode
3. User then holds `meta+k` for Claude Code native voice

This provides a one-keystroke "jump to Claude Code and dictate" workflow from anywhere.

### Implementation Priority

1. **Configure `~/.claude/keybindings.json`** — immediate, zero-risk (Track A)
2. **Fix terminal `chansend()` bug** — high priority, critical bug (Track B)
3. **Add recording indicator** — medium priority, UX improvement (Track B)
4. **Add convenience keymap** — low priority, ergonomic enhancement (Track C)
5. **Centralize keymap documentation** — low priority, maintenance (Track B)

## Teammate Contributions

| Teammate | Angle | Status | Confidence | Key Contribution |
|----------|-------|--------|------------|------------------|
| A | Primary | completed | high | Complete ctrl keymap inventory, Claude Code voice research, two-track strategy |
| B | Alternatives | completed | high | Prior art survey, toggle vs hold analysis, `chansend()` injection approach |
| C | Critic | completed | high | Terminal insertion bug discovery, scattered keymaps audit, stale docs |
| D | Horizons | completed | high | Strategic alignment, context-aware dictation vision, adjacent opportunities |

## References

- Claude Code `/voice` documentation (v2.1.69+)
- `lua/neotex/plugins/tools/stt/init.lua` — existing STT implementation
- `lua/neotex/config/keymaps.lua` — centralized keymap definitions
- `~/.claude/keybindings.json` — Claude Code keybinding configuration
- whisper.nvim, gp.nvim — prior art for Neovim voice plugins
