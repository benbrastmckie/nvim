# Implementation Plan: Task #114

- **Task**: 114 - make_leader_ao_identical_to_leader_ac
- **Status**: [NOT STARTED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false
- **Date**: 2026-03-02
- **Feature**: Unify leader-ao and leader-ac keymaps so both have identical normal/visual behavior
- **Estimated Hours**: 1-2 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

Currently `<leader>ac` has two behaviors: normal mode opens the Claude commands picker, visual mode sends selection to Claude with a prompt. Meanwhile `<leader>ao` is a which-key group with three subcommands (`aoc`, `aoe`, `aot`). This plan makes `<leader>ao` a direct keymap that mirrors `<leader>ac` -- normal mode opens the OpenCode commands picker, visual mode sends selection to OpenCode with a prompt. The `<leader>aoe` extension picker keymap is removed (command remains accessible via `:OpencodeExtensions`), and `<leader>aot` toggle is removed (redundant with `<C-g>`).

### Research Integration

The research report confirmed:
- `<leader>ae` has no active keymap binding (only a stale comment in `claude/extensions/picker.lua`)
- `<leader>ao` is a which-key group, not a direct action
- OpenCode provides `require("opencode").prompt(text)` API which can accept arbitrary text for visual mode parity
- `<C-g>` already provides OpenCode toggle, making `<leader>aot` redundant
- The `OpencodeExtensions` user command should remain functional (just no keymap)

## Goals & Non-Goals

**Goals**:
- Make `<leader>ao` in normal mode open the OpenCode Commands picker (same as current `<leader>aoc`)
- Make `<leader>ao` in visual mode send selection to OpenCode with a prompt (mirroring `<leader>ac` visual behavior)
- Remove `<leader>aoc`, `<leader>aoe`, `<leader>aot` subcommand keymaps
- Remove stale `<leader>ae` and `<leader>aoe` comments from extension picker modules
- Update documentation to reflect changes

**Non-Goals**:
- Resolving the `<leader>as` conflict (Claude sessions vs OpenCode select) -- out of scope
- Removing the `OpencodeExtensions` or `OpencodeCommands` user commands -- they remain accessible via `:command`
- Modifying `<C-g>` toggle behavior
- Changing any Claude keymaps

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| OpenCode `prompt()` API may not accept arbitrary text cleanly | M | L | Research confirmed `prompt(text)` works; test with actual selection in Phase 2 verification |
| Users accustomed to `<leader>aoc`/`<leader>aoe`/`<leader>aot` | L | L | These were just added in task 113, minimal muscle memory |
| Visual mode handler for OpenCode may need terminal-state integration | M | M | OpenCode uses snacks.nvim terminal (different from Claude); use `opencode.prompt()` API instead of terminal manipulation |

## Implementation Phases

### Phase 1: Create OpenCode Visual Selection Module [NOT STARTED]

**Goal**: Create a visual mode handler for OpenCode that mirrors the Claude visual module's prompt-and-send behavior, using the `opencode.prompt()` API.

**Tasks**:
- [ ] Create `lua/neotex/plugins/ai/opencode/core/visual.lua` module
- [ ] Implement `get_visual_selection()` helper (extract from claude visual module or create shared utility)
- [ ] Implement `send_visual_to_opencode_with_prompt()` function that gets selection, prompts user via `vim.ui.input`, formats message with file context, and sends via `require("opencode").prompt(formatted_text)`
- [ ] Ensure the module follows the same pattern as `claude/core/visual.lua` (LuaDoc comments, pcall for opencode require, progress notifications)

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/opencode/core/visual.lua` - NEW: OpenCode visual selection handler

**Verification**:
- Module loads without error: `nvim --headless -c "lua require('neotex.plugins.ai.opencode.core.visual')" -c "q"`
- Module exposes `send_visual_to_opencode_with_prompt()` function

---

### Phase 2: Update which-key Keymaps [NOT STARTED]

**Goal**: Replace the `<leader>ao` group with direct keymaps matching `<leader>ac` behavior, and remove `<leader>aoe`/`<leader>aot` subcommands.

**Tasks**:
- [ ] In `lua/neotex/plugins/editor/which-key.lua`, remove the 4-line `<leader>ao` group block (lines 261-264: group definition, `aoc`, `aoe`, `aot`)
- [ ] Add `<leader>ao` normal mode keymap: `{ "<leader>ao", "<cmd>OpencodeCommands<CR>", desc = "opencode commands", icon = "..." }`
- [ ] Add `<leader>ao` visual mode keymap: `{ "<leader>ao", function() require("neotex.plugins.ai.opencode.core.visual").send_visual_to_opencode_with_prompt() end, desc = "send selection to opencode with prompt", mode = { "v" }, icon = "..." }`

**Timing**: 0.25 hours

**Files to modify**:
- `lua/neotex/plugins/editor/which-key.lua` - Replace `<leader>ao` group with direct keymaps

**Verification**:
- Neovim starts without errors: `nvim --headless -c "q"`
- `<leader>ao` in normal mode opens the OpenCode Commands picker (manual test or headless command check)
- `<leader>aoc`, `<leader>aoe`, `<leader>aot` no longer appear in which-key popup

---

### Phase 3: Clean Up Stale Comments and Documentation [NOT STARTED]

**Goal**: Remove stale keymap references from source comments and update MAPPINGS.md to reflect new keybindings.

**Tasks**:
- [ ] In `lua/neotex/plugins/ai/claude/extensions/picker.lua` line 2, update comment from `-- Dedicated extension management picker (<leader>ae)` to `-- Dedicated extension management picker (via :ClaudeExtensions command)` or similar
- [ ] In `lua/neotex/plugins/ai/opencode/extensions/picker.lua` line 2, update comment from `-- Dedicated extension management picker (<leader>aoe)` to `-- Dedicated extension management picker (via :OpencodeExtensions command)`
- [ ] In `lua/neotex/config/keymaps.lua` line 24, update comment from `<leader>aoo` reference to `<leader>ao` or remove stale reference
- [ ] In `docs/MAPPINGS.md`, update the AI/ASSISTANT section:
  - Change `<leader>ao` from "Open session" to "opencode commands" (normal) / "send selection to opencode with prompt" (visual)
  - Remove any references to `<leader>aoc`, `<leader>aoe`, `<leader>aot`
  - Add visual mode row for `<leader>ao`

**Timing**: 0.25 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/extensions/picker.lua` - Update stale `<leader>ae` comment
- `lua/neotex/plugins/ai/opencode/extensions/picker.lua` - Update stale `<leader>aoe` comment
- `lua/neotex/config/keymaps.lua` - Update stale `<leader>aoo` comment
- `docs/MAPPINGS.md` - Update AI/ASSISTANT keymap table

**Verification**:
- No references to `<leader>ae`, `<leader>aoe`, `<leader>aot`, or `<leader>aoc` remain in modified files
- MAPPINGS.md accurately reflects new keymap structure
- Run grep to confirm: `grep -rn "leader>ae\|leader>aoe\|leader>aot\|leader>aoc" lua/ docs/`

---

## Testing & Validation

- [ ] Neovim starts without errors: `nvim --headless -c "q"` exits cleanly
- [ ] OpenCode visual module loads: `nvim --headless -c "lua require('neotex.plugins.ai.opencode.core.visual')" -c "q"`
- [ ] No stale keymap references in source: `grep -rn "leader>ae\b\|leader>aoe\|leader>aot\|leader>aoc" lua/ docs/` returns no matches
- [ ] `<leader>ao` in normal mode opens OpencodeCommands picker (functional test)
- [ ] `<leader>ao` in visual mode prompts and sends to OpenCode (functional test)
- [ ] `:OpencodeExtensions` command still works (extension picker accessible without keymap)
- [ ] `<C-g>` still toggles OpenCode (unchanged, regression check)

## Artifacts & Outputs

- `lua/neotex/plugins/ai/opencode/core/visual.lua` - New OpenCode visual selection module
- `lua/neotex/plugins/editor/which-key.lua` - Updated keymaps
- `lua/neotex/plugins/ai/claude/extensions/picker.lua` - Cleaned comment
- `lua/neotex/plugins/ai/opencode/extensions/picker.lua` - Cleaned comment
- `lua/neotex/config/keymaps.lua` - Cleaned comment
- `docs/MAPPINGS.md` - Updated documentation

## Rollback/Contingency

All changes are in tracked Lua configuration files. If the implementation fails:
1. Revert the which-key changes to restore the `<leader>ao` group with subcommands
2. Remove the new `opencode/core/visual.lua` module
3. Restore original comments in extension picker files
4. Revert MAPPINGS.md changes

Since all changes are in git-tracked files, `git checkout -- <file>` can restore any individual file to its pre-implementation state.
