# Research Report: Task #360

**Task**: 360 - Add which-key mappings under leader-x for process management
**Started**: 2026-04-03T17:05:00Z
**Completed**: 2026-04-03T17:05:00Z
**Effort**: 45 minutes
**Dependencies**: 358 (process.lua core), 359 (telescope process picker)
**Sources/Inputs**: Codebase analysis of which-key.lua, ftplugin/typst.lua, ftplugin/markdown.lua, typst-preview.lua, telescope picker patterns
**Artifacts**: specs/360_process_whichkey_mappings/reports/01_process-keymaps.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `<leader>x` group (lines 728-739 of which-key.lua) currently has 5 text manipulation mappings (xa, xA, xd, xs, xw) with room for new entries
- Process management mappings (xl, xp, xk, xo) use unused letters and can coexist without conflict
- Filetype-aware launch (`<leader>xl`) should use a dispatch function calling into process.lua (task 358), not inline logic
- The telescope process picker (`<leader>xp`) follows established custom picker patterns seen in worktree.lua and yanky.lua
- Icons should follow the existing Nerd Font v3 icon convention used throughout which-key.lua

## Context & Scope

This task adds 4 new keymappings to the existing `<leader>x` (text) group for process management. The mappings must coexist with 5 existing text manipulation bindings and integrate with the process manager (task 358) and telescope picker (task 359).

## Findings

### Current `<leader>x` Group Structure

Located at lines 728-739 of `lua/neotex/plugins/editor/which-key.lua`:

```lua
wk.add({
  { "<leader>x", group = "text", icon = "~\243\176\164\140", mode = { "n", "v" } },
  { "<leader>xa", desc = "align", icon = "~\243\176\169\158", mode = { "n", "v" } },
  { "<leader>xA", desc = "align with preview", icon = "~\243\176\169\158", mode = { "n", "v" } },
  { "<leader>xd", desc = "toggle diff overlay", icon = "~\243\176\169\147" },
  { "<leader>xs", desc = "split/join toggle", icon = "~\243\176\169\139", mode = { "n", "v" } },
  { "<leader>xw", desc = "toggle word diff", icon = "~\243\176\169\147" },
})
```

Key observations:
- Group name is "text" with icon "\243\176\164\140" (nf-md-format_text)
- Mode is `{ "n", "v" }` for the group and most mappings
- The xa/xA/xd/xs/xw mappings are **label-only** (no command assigned in which-key) -- they document mappings defined elsewhere (mini.align, treesj, etc.)
- Available letters: b, c, e, f, g, h, i, j, k, l, m, n, o, p, q, r, t, u, v, x, y, z

### Group Name Consideration

The current group is named "text" but will now contain process management. Two options:

1. **Rename to "text/exec"** or similar -- breaks mental model
2. **Keep "text" group, add process mappings as a sub-group** -- which-key v3 supports nested groups

**Recommendation**: Add a `<leader>x` sub-group is not needed. The which-key v3 API allows flat addition of new mappings to the same prefix. Simply add the new mappings in a separate `wk.add()` call in the same file. The group label "text" can optionally be renamed to "text/process" but this is cosmetic -- the user suggested keeping the group as-is with mixed concerns, similar to how `<leader>r` (run) contains both formatting, fold toggles, SSH, URL opening, and model checking.

### Recommended New Mappings

| Key | Action | Description | Icon | Mode |
|-----|--------|-------------|------|------|
| `<leader>xl` | Launch current file | Filetype-aware launch via process.lua | (nf-md-rocket_launch) | n |
| `<leader>xp` | Process picker | Open telescope process picker | (nf-md-format_list_bulleted) | n |
| `<leader>xk` | Kill all processes | Stop all tracked background processes | (nf-md-stop_circle) | n |
| `<leader>xo` | Open in browser | Open current file's port in browser | (nf-md-web) | n |

### Icon Choices

Based on the icon conventions in the file:

- **Launch** `<leader>xl`: `""` (nf-cod-rocket) or `"󰐊"` (nf-md-play) -- `"󰐊"` is already used for `<leader>rb` (lean build) and `<leader>rm` (model checker), so use `""` (nf-cod-rocket) for differentiation
- **Process picker** `<leader>xp`: `"󰒋"` (nf-md-clipboard_list) or `"󱎫"` -- use `"󰒋"` for list-of-processes metaphor
- **Kill all** `<leader>xk`: `"󰅚"` (nf-md-close_circle) -- already used for `<leader>rl` (show linter errors) and other "stop/close" actions, consistent
- **Open browser** `<leader>xo`: `"󰖟"` (nf-md-web) -- already used for `<leader>rg` (go to URL), consistent

### Filetype Detection Strategy for `<leader>xl`

The launch mapping needs a dispatch function. Based on codebase patterns:

```lua
local function process_launch()
  local process = require("neotex.util.process")  -- from task 358
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")

  if ft == "typst" then
    -- Delegate to process.start() which wraps typst-preview or typst watch
    process.start({
      type = "typst-preview",
      file = file,
    })
  elseif ft == "markdown" then
    -- Check if this is a slidev project
    if is_slidev_project(file) then
      process.start({
        type = "slidev",
        file = file,
      })
    else
      vim.notify("No launch action for this markdown file", vim.log.levels.INFO)
    end
  else
    vim.notify("No launch action for filetype: " .. ft, vim.log.levels.INFO)
  end
end
```

**Slidev detection heuristic** (check in order):
1. Look for `package.json` in current directory or parent with `"slidev"` in dependencies
2. Look for `slides.md` naming convention
3. Look for YAML frontmatter with `theme:` key (slidev convention)

This matches the founder extension's slidev project structure where decks have `package.json` with slidev dependencies.

### Existing Patterns for Filetype-Aware Commands

The codebase uses two patterns:

1. **`cond` functions in which-key** (lines 177-199): Functions like `is_python()`, `is_markdown()` control visibility. Used for `<leader>rp` (python run), `<leader>rr` (reorder list).

2. **Buffer-local mappings in ftplugin** (after/ftplugin/typst.lua, markdown.lua): The typst ftplugin registers buffer-local which-key mappings with `buffer = 0`. The markdown ftplugin registers `<leader>p` (pandoc) mappings the same way.

**Recommendation for `<leader>xl`**: Register it as a **global mapping** in which-key.lua with a dispatch function. The dispatch function checks filetype at invocation time rather than at registration time. This is simpler than buffer-local registration and matches the `<leader>rm` (model checker) pattern which also dispatches based on context.

### Integration Points

1. **process.lua** (task 358): The `<leader>xl` and `<leader>xk` mappings call `process.start()` and `process.stop_all()` respectively
2. **telescope process picker** (task 359): The `<leader>xp` mapping calls `require("neotex.plugins.tools.process-picker").open()`
3. **xdg-open** pattern: The `<leader>xo` mapping calls `process.open_browser()` which uses `xdg-open` (matching the pattern in `lua/neotex/util/url.lua` line 204 and `lua/neotex/plugins/text/typst-preview.lua` line 15)
4. **typst-preview.nvim**: The `<leader>xl` for typst files could either launch `TypstPreview` command (existing plugin) or use `typst watch` via process.lua. Since typst-preview.nvim already handles browser-based preview with cross-jump, the launch action should probably invoke `TypstPreview` and register the process in the shared registry

### Typst Watch Job Migration (Task 361 Overlap)

The `after/ftplugin/typst.lua` file has a local `typst_watch_job` variable (line 274) for tracking the watch process. Task 361 will migrate this to the shared process registry. For task 360, the `<leader>xl` mapping for typst should call `TypstPreview` (the web preview command from typst-preview.nvim) and not duplicate the watch functionality. Task 361 will later unify both under the process manager.

### Implementation Structure

The new mappings should be added as a separate `wk.add()` block immediately after the existing `<leader>x` text group (after line 739), following the section comment pattern:

```lua
-- ============================================================================
-- <leader>x - PROCESS MANAGEMENT (within text group)
-- ============================================================================

wk.add({
  { "<leader>xl", function() require("neotex.util.process").launch() end,
    desc = "launch", icon = "" },
  { "<leader>xp", function() require("neotex.plugins.tools.process-picker").open() end,
    desc = "processes", icon = "󰒋" },
  { "<leader>xk", function() require("neotex.util.process").stop_all() end,
    desc = "kill all", icon = "󰅚" },
  { "<leader>xo", function() require("neotex.util.process").open_browser() end,
    desc = "open in browser", icon = "󰖟" },
})
```

This uses lazy `require()` calls (matching the pattern at line 722 for todo-comments and line 659 for notifications) so process.lua does not need to be loaded until the mapping is invoked.

## Decisions

- **Keep `<leader>x` group name as "text"**: Mixed concerns are acceptable (precedent: `<leader>r` "run" group has formatting, SSH, URLs, folds, model checking)
- **Global mappings, not buffer-local**: The dispatch function handles filetype checks at invocation time
- **Lazy require pattern**: Use `function() require(...) end` wrappers for all process mappings
- **Separate wk.add() block**: Add after the existing text group block, with a section comment
- **TypstPreview for typst launch**: Use existing typst-preview.nvim rather than raw typst watch

## Risks & Mitigations

- **Risk**: process.lua (task 358) not yet implemented -- `<leader>xl`, `<leader>xk`, `<leader>xo` will error if invoked
  - **Mitigation**: Lazy require + pcall wrapper in the dispatch function; show "Process manager not available" notification
- **Risk**: telescope process picker (task 359) not yet implemented -- `<leader>xp` will error
  - **Mitigation**: Same pcall pattern; graceful error message
- **Risk**: Group rename confusion -- users expect `<leader>x` = text
  - **Mitigation**: Keep group name "text"; the process mappings use unused letters and are self-documenting via which-key descriptions

## Appendix

### Search Queries Used
- Glob: `**/after/ftplugin/typst.lua`, `**/after/ftplugin/markdown.lua`, `**/process*.lua`, `**/lua/neotex/util/*.lua`
- Grep: `<leader>r` in which-key.lua, `slidev` across codebase, `telescope.*picker` in tools/, `xdg-open` in lua/
- Read: which-key.lua (lines 1-80, 80-230, 650-763), typst.lua ftplugin (full), markdown.lua ftplugin (full), typst-preview.lua (full), worktree.lua (picker pattern)

### References
- which-key.nvim v3 API: Group definitions, conditional visibility, icon support
- Nerd Font v3 icon names used for icon selection
- typst-preview.nvim: Browser-based live preview with cross-jump
- Telescope custom picker pattern: pickers.new() with finders, sorters, actions
