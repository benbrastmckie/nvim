# Research Report: Task #377 - Unified Dictation Keymap

**Task**: 377 - ctrl_keymap_dictation_neovim_claude_sidebar
**Started**: 2026-04-08T00:00:00Z
**Completed**: 2026-04-08T00:30:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `lua/neotex/plugins/tools/stt/init.lua`, `lua/neotex/config/keymaps.lua`
- Previous research: `specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/reports/01_teammate-c-findings.md`
- WezTerm docs: `wezterm.org/config/lua/config/enable_kitty_keyboard.html`
- Kitty keyboard protocol spec: `sw.kovidgoyal.net/kitty/keyboard-protocol/`
- WezTerm config: `/home/benjamin/.config/config-files/wezterm.lua`
- Blog: `harrymin.dev/posts/fix-terminal-keybindings-csi-u/`
**Artifacts**: specs/377_ctrl_keymap_dictation_neovim_claude_sidebar/reports/02_unified-keymap-research.md
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- `<C-'>` (Ctrl+apostrophe) CAN work as a unified key in both normal mode and terminal mode, but ONLY with the Kitty keyboard protocol enabled. Without it, the keypress is indistinguishable from a bare apostrophe.
- WezTerm's `enable_kitty_keyboard` defaults to **false**. The user's WezTerm config does NOT currently enable it. This MUST be set to `true` for `<C-'>` to work.
- Neovim 0.11.6 (the installed version) fully supports Kitty keyboard protocol in both normal and terminal mode mappings, so no Neovim-side barriers exist.
- Once the Kitty protocol is enabled, `<C-'>` can replace `<C-\>` entirely as a single unified STT toggle across all modes, with no Neovim-level conflicts.
- The existing `<C-'>` terminal-mode mapping already works (it was designed for this), so the change is primarily: (1) add `<C-'>` in normal mode, (2) remove `<C-\>` in normal mode, (3) enable Kitty protocol in WezTerm.

## Context & Scope

The user wants ONE keymapping for dictation that works everywhere: normal mode (regular editing), terminal mode (Claude Code sidebar), and ideally insert mode. The current implementation uses two different keys:

- `<C-\>` in normal mode (stt/init.lua line 311)
- `<C-'>` in terminal mode (stt/init.lua line 319)

The preferred unified key is `<C-'>`. This research investigates feasibility, compatibility, and any blockers.

## Findings

### Finding 1: `<C-'>` in Normal Mode -- Fully Supported with Kitty Protocol

In traditional terminal encoding, `Ctrl+punctuation` keys are NOT reliably transmitted. The terminal clears the upper bits of the ASCII value when Ctrl is held, but for punctuation characters whose upper bits are already 0, this produces ambiguous or identical keycodes. Apostrophe (ASCII 39, 0x27) falls into this category.

**With Kitty keyboard protocol**: The key is encoded as `CSI 39;5u` (codepoint 39 = apostrophe, modifier 5 = Ctrl+1). This is unambiguous and fully distinguishable from a bare apostrophe.

**Neovim 0.11.6 support**: Neovim 0.8+ added Kitty/CSI-u protocol support for normal mode mappings. Neovim 0.11 extended this to terminal mode (:tmap) as well. The installed version (0.11.6) supports both.

**Conclusion**: `vim.keymap.set('n', "<C-'>", ...)` will work correctly when the Kitty protocol is active.

### Finding 2: WezTerm Kitty Protocol is Currently DISABLED

The user's WezTerm configuration (`/home/benjamin/.config/config-files/wezterm.lua`) does NOT contain `enable_kitty_keyboard`. Per the official WezTerm documentation, the default value is **`false`**.

**Action required**: Add `config.enable_kitty_keyboard = true` to the WezTerm config. Since this config is Nix/home-manager managed, this must be done through the home-manager configuration source (as documented in `docs/KEYBOARD_PROTOCOL_SETUP.md`).

**Note**: The config already documents this requirement for the `<C-i>` / `<Tab>` disambiguation (see `docs/KEYBOARD_PROTOCOL_SETUP.md` lines 59-81), but it was never actually applied. Enabling it now serves dual purpose: fixing jump list navigation AND enabling `<C-'>`.

### Finding 3: No Neovim-Level Conflicts for `<C-'>` in Any Mode

Comprehensive grep of the entire `lua/` directory confirms `<C-'>` is only mapped in terminal mode (`'t'`). There are zero mappings for `<C-'>` in normal (`'n'`), insert (`'i'`), or visual (`'v'`) modes.

The key is not a Neovim built-in in any mode. Unlike `<C-\>` which is a prefix for `<C-\><C-n>` (terminal escape sequence), `<C-'>` has no built-in meaning in Neovim.

### Finding 4: `<C-\>` Can Be Fully Replaced

`<C-\>` in normal mode has a subtle conflict: it IS a Neovim prefix key (`<C-\><C-n>` switches to normal mode in terminal buffers). While the normal-mode mapping works because Neovim waits for a timeout before resolving the prefix, it creates a perceptible delay and user confusion.

`<C-'>` has NO such prefix conflict. It resolves immediately with no timeout ambiguity.

**Recommendation**: Replace `<C-\>` with `<C-'>` in normal mode entirely.

### Finding 5: Insert Mode Mapping is Also Possible

For completeness, `<C-'>` can also be mapped in insert mode (`'i'`). This would let the user start dictation while actively typing without switching to normal mode first. The handler would be identical to the normal mode one.

### Finding 6: The Kitty Protocol Requirement is a Gating Dependency

Without `enable_kitty_keyboard = true` in WezTerm:
- `<C-'>` in normal mode will be SILENTLY IGNORED (Neovim receives bare `'` which doesn't match the mapping)
- `<C-'>` in terminal mode MAY also fail (the terminal process inside Neovim receives the raw keypress, and without proper encoding it may not reach the tmap handler)

This is the single most critical prerequisite. The implementation plan MUST gate on this.

### Finding 7: Fallback Alternatives if Kitty Protocol Cannot Be Enabled

If for any reason the Kitty protocol cannot be enabled, the best alternative unified keys from the free inventory are:

| Key | Pros | Cons |
|-----|------|------|
| `<C-y>` | Free globally, no prefix conflicts, works without Kitty protocol (letter key) | Less mnemonic for "voice/dictation" |
| `<C-q>` | Free globally, traditional "record" association (like media controls) | Some terminals intercept for flow control (XON/XOFF) |
| `<C-x>` | Free globally, works without Kitty protocol | Common "cut" association in other editors |

However, these are fallbacks only. `<C-'>` is the preferred choice because:
- It is already the terminal-mode mapping (no user relearning)
- Apostrophe has a mnemonic connection to "speech/voice"
- It avoids conflicts with letter-based Ctrl keys that plugins might claim later

## Decisions

1. **`<C-'>` is the recommended unified key** for STT dictation across all modes.
2. **Kitty keyboard protocol MUST be enabled** in WezTerm -- this is a hard prerequisite.
3. **`<C-\>` should be removed** from normal mode STT mapping to avoid the prefix-key ambiguity.
4. **Three modes should be mapped**: normal (`'n'`), terminal (`'t'`), and insert (`'i'`).
5. **No fallback key** is needed if the Kitty protocol is properly configured.

## Recommendations

1. **Phase 1 (prerequisite)**: Enable `config.enable_kitty_keyboard = true` in WezTerm config via home-manager. This is a user action (Nix rebuild required).
2. **Phase 2 (implementation)**: Modify `stt/init.lua` to:
   - Replace `<C-\>` normal-mode mapping with `<C-'>`
   - Add `<C-'>` insert-mode mapping
   - Keep existing `<C-'>` terminal-mode mapping
   - All three modes call the same `M.toggle_recording` (terminal mode wraps with stopinsert/startinsert)
3. **Phase 3 (documentation)**: Update `docs/MAPPINGS.md` and the keymaps.lua header comments to reflect the unified `<C-'>` mapping.
4. **Phase 4 (validation)**: Test `<C-'>` in all three modes after enabling the Kitty protocol. Use `nvim --cmd 'verbose map <C-">` or the insert-mode `Ctrl+V` trick to verify the key is received.

## Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| WezTerm Kitty protocol breaks other keybindings | MEDIUM | Test existing Ctrl mappings (`<C-;>`, `<C-p>`, etc.) after enabling. The protocol should be backwards-compatible but verify. |
| Nix/home-manager config is complex to modify | LOW | The exact change is documented in `docs/KEYBOARD_PROTOCOL_SETUP.md` lines 59-81. |
| SSH sessions may not support Kitty protocol | LOW | STT (microphone recording) requires local audio anyway, so SSH is not a relevant use case. |
| The `<C-'>` insert-mode mapping conflicts with digraph input | LOW | Neovim uses `<C-k>` for digraphs, not `<C-'>`. No conflict. |

## Appendix

### Search Queries Used
- `grep -r "C-'" lua/` -- found only terminal-mode mapping in stt/init.lua
- `grep -r "C-\\\\" lua/` -- found normal-mode STT and terminal escape sequences
- `grep -r "kitty.*keyboard\|keyboard.*protocol" nvim/` -- found KEYBOARD_PROTOCOL_SETUP.md
- `grep "kitty\|keyboard_protocol" wezterm.lua` -- confirmed NOT enabled
- WebSearch: "wezterm enable_kitty_keyboard_protocol default value"
- WebFetch: wezterm.org/config/lua/config/enable_kitty_keyboard.html -- confirmed default=false
- WebFetch: sw.kovidgoyal.net/kitty/keyboard-protocol/ -- confirmed apostrophe=codepoint 39, CSI 39;5u
- WebFetch: harrymin.dev/posts/fix-terminal-keybindings-csi-u/ -- CSI-u encoding explanation

### Key Technical Details

**Kitty protocol encoding for `<C-'>`**:
```
ESC [ 39 ; 5 u
       ^    ^
       |    +-- modifier: Ctrl (4) + 1 = 5
       +------- codepoint: apostrophe (ASCII 39)
```

**Neovim version compatibility**:
- 0.8+: Kitty/CSI-u in normal mode
- 0.11+: Kitty/CSI-u in terminal mode (:tmap)
- 0.11.6: Installed version (fully compatible)

**WezTerm config change required**:
```lua
config.enable_kitty_keyboard = true
```

### References
- [WezTerm enable_kitty_keyboard docs](https://wezterm.org/config/lua/config/enable_kitty_keyboard.html)
- [Kitty keyboard protocol specification](https://sw.kovidgoyal.net/kitty/keyboard-protocol/)
- [Why Ctrl+; Doesn't Work in Your Terminal](https://harrymin.dev/posts/fix-terminal-keybindings-csi-u/)
- [Neovim 0.11 terminal mode Kitty protocol support](https://x.com/Neovim/status/1881149319316951210)
- [Neovim TUI documentation](https://neovim.io/doc/user/tui/)
- Local: `docs/KEYBOARD_PROTOCOL_SETUP.md` -- existing guide for enabling the protocol
