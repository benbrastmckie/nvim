# Implementation Plan: Add which-key mappings under leader-x for process management

- **Task**: 360 - Add which-key mappings under leader-x for process management
- **Status**: [NOT STARTED]
- **Effort**: 45 minutes
- **Dependencies**: 358 (process.lua core), 359 (telescope process picker)
- **Research Inputs**: specs/360_process_whichkey_mappings/reports/01_process-keymaps.md
- **Artifacts**: plans/01_process-keymaps.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Add four process management keymappings (`<leader>xl`, `<leader>xp`, `<leader>xk`, `<leader>xo`) to the existing `<leader>x` group in `lua/neotex/plugins/editor/which-key.lua`. The mappings integrate with the process manager (task 358) and telescope process picker (task 359) using lazy `require()` wrappers. A dispatch function handles filetype-aware launch logic for typst and slidev files. All new mappings use unused key letters and coexist with the existing text manipulation mappings (xa, xA, xd, xs, xw).

### Research Integration

Key findings from the research report:
- The `<leader>x` group (lines 728-739) has 5 existing mappings; letters k, l, o, p are available
- Global mappings with runtime filetype dispatch (not buffer-local) is the recommended pattern
- Lazy `require()` wrappers match existing patterns (e.g., todo-comments at line 722)
- Icons selected: `""` (rocket/launch), `"󰒋"` (clipboard-list/processes), `"󰅚"` (close-circle/kill), `"󰖟"` (web/browser)
- The `<leader>xl` typst action should invoke `TypstPreview` command (existing plugin), not raw `typst watch`
- Slidev detection: check for `package.json` with slidev dependency

## Goals & Non-Goals

**Goals**:
- Add `<leader>xl` (launch), `<leader>xp` (processes), `<leader>xk` (kill all), `<leader>xo` (open browser) to which-key.lua
- Implement filetype-aware dispatch for `<leader>xl` (typst -> TypstPreview, markdown/slidev -> process.start)
- Use pcall wrappers so mappings degrade gracefully if dependencies (tasks 358/359) are not yet implemented

**Non-Goals**:
- Modifying the existing text manipulation mappings
- Implementing process.lua or process-picker.lua (handled by tasks 358, 359)
- Migrating typst ftplugin job tracking (handled by task 361)
- Renaming the `<leader>x` group from "text"

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Tasks 358/359 not yet implemented | M | H | Use pcall + graceful "not available" notifications |
| Key conflicts with future mappings | L | L | Letters xl/xp/xk/xo are well-scoped; unlikely conflicts |
| Slidev detection false positives | L | L | Check package.json dependencies specifically for "slidev" |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add process management mappings to which-key.lua [NOT STARTED]

**Goal**: Add the four process management keymappings with a dispatch function for filetype-aware launch.

**Tasks**:
- [ ] Add a `process_launch()` local function above the new wk.add() block that dispatches by filetype:
  - `typst` -> `vim.cmd("TypstPreview")`
  - `markdown` -> check for slidev project (look for `package.json` with `"slidev"` in cwd or parent), then call `require("neotex.util.process").start({ type = "slidev", file = vim.fn.expand("%:p") })`
  - Other filetypes -> `vim.notify("No launch action for filetype: " .. ft, vim.log.levels.INFO)`
- [ ] Add a `is_slidev_project()` local helper that walks up from the current file looking for `package.json` containing `"slidev"`
- [ ] Add a new `wk.add()` block after line 739 (after the existing `<leader>x` text group) with section comment header
- [ ] Register four mappings with lazy require wrappers and pcall error handling:
  - `<leader>xl` -> `process_launch()` dispatch function, desc "launch", icon `""`
  - `<leader>xp` -> `require("neotex.plugins.tools.process-picker").open()`, desc "processes", icon `"󰒋"`
  - `<leader>xk` -> `require("neotex.util.process").stop_all()`, desc "kill all", icon `"󰅚"`
  - `<leader>xo` -> `require("neotex.util.process").open_browser()`, desc "open in browser", icon `"󰖟"`

**Exact code to insert** after line 739 (`})` closing the text group wk.add):

```lua
-- ============================================================================
-- <leader>x - PROCESS MANAGEMENT (within text group)
-- ============================================================================

local function is_slidev_project(file)
  local dir = vim.fn.fnamemodify(file, ":h")
  for _ = 1, 10 do
    local pkg = dir .. "/package.json"
    if vim.fn.filereadable(pkg) == 1 then
      local content = vim.fn.readfile(pkg)
      for _, line in ipairs(content) do
        if line:find('"slidev"') or line:find('"@slidev/') then
          return true
        end
      end
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then break end
    dir = parent
  end
  return false
end

local function process_launch()
  local ft = vim.bo.filetype
  local file = vim.fn.expand("%:p")

  if ft == "typst" then
    vim.cmd("TypstPreview")
  elseif ft == "markdown" then
    if is_slidev_project(file) then
      local ok, process = pcall(require, "neotex.util.process")
      if ok then
        process.start({ type = "slidev", file = file })
      else
        vim.notify("Process manager not available", vim.log.levels.WARN)
      end
    else
      vim.notify("No launch action for this markdown file", vim.log.levels.INFO)
    end
  else
    vim.notify("No launch action for filetype: " .. ft, vim.log.levels.INFO)
  end
end

wk.add({
  { "<leader>xl", process_launch, desc = "launch", icon = "" },
  { "<leader>xp", function()
    local ok, picker = pcall(require, "neotex.plugins.tools.process-picker")
    if ok then
      picker.open()
    else
      vim.notify("Process picker not available", vim.log.levels.WARN)
    end
  end, desc = "processes", icon = "󰒋" },
  { "<leader>xk", function()
    local ok, process = pcall(require, "neotex.util.process")
    if ok then
      process.stop_all()
    else
      vim.notify("Process manager not available", vim.log.levels.WARN)
    end
  end, desc = "kill all", icon = "󰅚" },
  { "<leader>xo", function()
    local ok, process = pcall(require, "neotex.util.process")
    if ok then
      process.open_browser()
    else
      vim.notify("Process manager not available", vim.log.levels.WARN)
    end
  end, desc = "open in browser", icon = "󰖟" },
})
```

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/editor/which-key.lua` - Add ~60 lines after line 739

**Verification**:
- Open Neovim, press `<leader>x` and confirm xl/xp/xk/xo appear in which-key popup alongside xa/xA/xd/xs/xw
- Press `<leader>xl` on a non-typst/markdown file and confirm "No launch action" notification
- Press `<leader>xp` and confirm graceful "not available" message (until task 359 is done)
- Press `<leader>xk` and confirm graceful "not available" message (until task 358 is done)
- No Lua errors on startup or keypress

## Testing & Validation

- [ ] Neovim starts without errors after modification
- [ ] `<leader>x` which-key popup shows all 9 mappings (5 existing + 4 new)
- [ ] `<leader>xl` dispatches correctly per filetype (typst -> TypstPreview, markdown -> slidev check, other -> notification)
- [ ] `<leader>xp`, `<leader>xk`, `<leader>xo` show graceful "not available" messages when tasks 358/359 are not yet implemented
- [ ] Existing `<leader>xa`, `<leader>xA`, `<leader>xd`, `<leader>xs`, `<leader>xw` continue to work unchanged

## Artifacts & Outputs

- `specs/360_process_whichkey_mappings/plans/01_process-keymaps.md` (this file)
- `lua/neotex/plugins/editor/which-key.lua` (modified)

## Rollback/Contingency

Remove the inserted block (section comment + `is_slidev_project` + `process_launch` + `wk.add()` call) from which-key.lua. The existing text group mappings are untouched and require no rollback.
