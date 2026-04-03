# Research Report: Task #359

**Task**: 359 - Create telescope process picker
**Started**: 2026-04-03T17:00:00Z
**Completed**: 2026-04-03T17:05:00Z
**Effort**: 1 hour
**Dependencies**: 358 (process manager core)
**Sources/Inputs**: Codebase analysis (telescope.lua, pickers.lua, picker.lua, worktree.lua, typst.lua)
**Artifacts**: specs/359_telescope_process_picker/reports/01_process-picker.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The codebase has 14 files using `pickers.new()`, providing rich examples of custom telescope pickers with entry makers, previewers, and custom actions
- The recommended approach is a standalone module at `lua/neotex/plugins/tools/process-picker.lua` that returns an M table (not a plugin spec) and is called from which-key mappings
- The picker should use `new_buffer_previewer` for stdout/stderr display and `attach_mappings` for kill/browser actions
- Refresh after kill is handled by closing and re-opening the picker via `vim.defer_fn`

## Context & Scope

Task 359 creates a telescope picker that displays processes tracked by the `process.lua` registry (task 358). The picker needs columns (name, command, port, uptime, status), a preview pane showing stdout/stderr, and actions for killing processes and opening ports in a browser.

## Findings

### Telescope Picker API Patterns in Codebase

The codebase uses telescope extensively. Key patterns discovered:

**1. Standard require imports** (from `pickers.lua`, `picker.lua`, `worktree.lua`):
```lua
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
```

**2. Picker creation pattern** (from `pickers.lua:112-166`):
```lua
pickers.new({}, {
  prompt_title = "Title",
  finder = finders.new_table({
    results = data_array,
    entry_maker = function(item)
      return {
        value = item,           -- raw data object
        display = "formatted",  -- what user sees
        ordinal = "searchable", -- what fuzzy search matches
      }
    end,
  }),
  sorter = conf.generic_sorter({}),
  previewer = previewer_instance,
  attach_mappings = function(prompt_bufnr, map)
    -- Override default action
    actions.select_default:replace(function()
      local selection = action_state.get_selected_entry()
      actions.close(prompt_bufnr)
      -- do something with selection.value
    end)
    -- Add custom keymaps
    map("i", "<C-o>", function() ... end)
    return true  -- keep default mappings for unhandled keys
  end,
}):find()
```

**3. Buffer previewer pattern** (from `pickers.lua:84-111`):
```lua
local previewer = previewers.new_buffer_previewer({
  title = "Preview Title",
  define_preview = function(self, entry, status)
    local lines = { "line1", "line2", ... }
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    -- Optional: set filetype for syntax highlighting
    vim.api.nvim_set_option_value("filetype", "log", { buf = self.state.bufnr })
  end,
})
```

**4. Custom action mapping** (from `picker.lua:144-188`):
```lua
attach_mappings = function(prompt_bufnr, map)
  actions.select_default:replace(function()
    local selection = action_state.get_selected_entry()
    if not selection then return end
    actions.close(prompt_bufnr)
    -- perform action
  end)
  map("i", "<C-r>", function()
    local selection = action_state.get_selected_entry()
    if not selection then return end
    actions.close(prompt_bufnr)
    -- perform action
    -- Refresh picker
    vim.defer_fn(function()
      picker_mod.show(opts)
    end, 100)
  end)
  return true
end
```

**5. Entry display formatting** (from `pickers.lua:118-125`):
```lua
entry_maker = function(session)
  local display = string.format(
    "%2d. %-12s | %-8s msgs | %-15s | %s",
    session.number,
    session.modified,
    session.messages,
    session.branch,
    session.summary:sub(1, 40)
  )
  return { value = session, display = display, ordinal = ... }
end
```

### Telescope Configuration

From `telescope.lua`:
- Theme: No global theme set (defaults used). Extensions use `get_dropdown` and `get_cursor` selectively.
- Extensions loaded: fzf, yank_history, bibtex, ui-select
- Default mappings: C-j/C-k for navigation, Esc to close, C-q for quickfix
- The process picker should use default theme (no special theme needed for a full-width picker with preview)

### Plugin Loading Pattern

From `tools/init.lua`:
- Uses `safe_require` with validation
- Modules must return a table with `[1]` (repo string), `import`, or `dir` to be valid plugin specs
- The process picker is NOT a plugin spec -- it is a utility module called from keymaps
- Therefore it should NOT be added to `tools/init.lua`
- Instead, it should be a standalone module (e.g., `lua/neotex/util/process-picker.lua` or `lua/neotex/plugins/tools/process-picker.lua`) that exports an `M.show()` function called from which-key mappings in task 360

**Decision**: Place at `lua/neotex/plugins/tools/process-picker.lua` per the task description, but structure it as a utility module (`local M = {}; return M`) not a lazy.nvim plugin spec. The which-key mapping (task 360) will `require("neotex.plugins.tools.process-picker").show()`.

### Process Registry API (Task 358)

From the task 358 description and typst.lua analysis, the process.lua registry will provide:
- `process.start(opts)` -- start a tracked process via `vim.fn.jobstart`
- `process.stop(id)` -- stop via `vim.fn.jobstop` + cleanup
- `process.list()` -- returns all tracked processes

Each process entry will contain: `pid`, `cmd`, `port`, `cwd`, `start_time`, stdout/stderr buffer.

From `typst.lua:274-314`, the existing pattern uses `vim.fn.jobstart` with `on_stdout`, `on_stderr`, and `on_exit` callbacks. The process registry will wrap this pattern.

### Existing Process Tracking (typst.lua)

The `typst.lua` ftplugin currently tracks `typst_watch_job` as a local variable (line 274). Task 361 will migrate this to the shared registry. The picker needs to work with whatever the registry exposes.

## Recommendations

### Recommended Module Structure

```lua
-- lua/neotex/plugins/tools/process-picker.lua
local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")

local function format_uptime(start_time)
  local elapsed = os.time() - start_time
  if elapsed < 60 then return elapsed .. "s"
  elseif elapsed < 3600 then return math.floor(elapsed / 60) .. "m"
  else return math.floor(elapsed / 3600) .. "h " .. math.floor((elapsed % 3600) / 60) .. "m"
  end
end

local function create_previewer()
  return previewers.new_buffer_previewer({
    title = "Process Output",
    define_preview = function(self, entry, _)
      local proc = entry.value
      local lines = {}
      -- Header
      table.insert(lines, "Command: " .. proc.cmd)
      table.insert(lines, "PID: " .. (proc.pid or "N/A"))
      table.insert(lines, "Port: " .. (proc.port or "none"))
      table.insert(lines, "CWD: " .. (proc.cwd or "N/A"))
      table.insert(lines, "Started: " .. os.date("%H:%M:%S", proc.start_time))
      table.insert(lines, "")
      table.insert(lines, "--- stdout ---")
      -- Append recent stdout lines from proc.stdout buffer
      -- Append recent stderr lines from proc.stderr buffer
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
    end,
  })
end

function M.show(opts)
  opts = opts or {}
  local process = require("neotex.util.process")
  local processes = process.list()

  if #processes == 0 then
    vim.notify("No background processes running", vim.log.levels.INFO)
    return
  end

  pickers.new(opts, {
    prompt_title = "Background Processes",
    finder = finders.new_table({
      results = processes,
      entry_maker = function(proc)
        local display = string.format(
          "%-15s %-30s %-8s %-8s %s",
          proc.name or "unnamed",
          (proc.cmd or ""):sub(1, 30),
          proc.port and (":" .. proc.port) or "",
          format_uptime(proc.start_time),
          proc.status or "running"
        )
        return {
          value = proc,
          display = display,
          ordinal = (proc.name or "") .. " " .. (proc.cmd or ""),
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    previewer = create_previewer(),
    attach_mappings = function(prompt_bufnr, map)
      -- <CR> to kill selected process
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        if not selection then return end
        actions.close(prompt_bufnr)
        process.stop(selection.value.id)
        vim.notify("Stopped: " .. (selection.value.name or selection.value.cmd), vim.log.levels.INFO)
        -- Refresh picker
        vim.defer_fn(function() M.show(opts) end, 100)
      end)
      -- <C-o> to open port in browser
      map("i", "<C-o>", function()
        local selection = action_state.get_selected_entry()
        if not selection or not selection.value.port then
          vim.notify("No port for this process", vim.log.levels.WARN)
          return
        end
        local url = "http://localhost:" .. selection.value.port
        vim.fn.jobstart({ "xdg-open", url }, { detach = true })
        vim.notify("Opening " .. url, vim.log.levels.INFO)
      end)
      map("n", "<C-o>", function()
        local selection = action_state.get_selected_entry()
        if not selection or not selection.value.port then
          vim.notify("No port for this process", vim.log.levels.WARN)
          return
        end
        local url = "http://localhost:" .. selection.value.port
        vim.fn.jobstart({ "xdg-open", url }, { detach = true })
        vim.notify("Opening " .. url, vim.log.levels.INFO)
      end)
      return true
    end,
  }):find()
end

return M
```

### Entry Display Format

Recommended column layout:
```
NAME            COMMAND                        PORT     UPTIME   STATUS
typst-watch     typst watch main.typ           :3000    5m       running
slidev          npx slidev                     :3030    12m      running
```

Use `string.format` with fixed widths: `%-15s %-30s %-8s %-8s %s`.

### Previewer Content

The preview pane should show:
1. Process metadata header (command, PID, port, CWD, start time)
2. Separator line
3. Recent stdout lines (last 50-100 lines from the stdout ring buffer)
4. Recent stderr lines (last 20-50 lines, if any)

The stdout/stderr data comes from the process registry's ring buffer. The `define_preview` callback reads `proc.stdout` and `proc.stderr` arrays.

### Refresh Strategy

Following the pattern in `picker.lua:162-166`:
1. Close the picker after an action (`actions.close(prompt_bufnr)`)
2. Re-open after a short delay: `vim.defer_fn(function() M.show(opts) end, 100)`
3. This re-queries `process.list()` to get fresh data

### Integration with process.lua Registry

The picker depends on `process.list()` returning an array of process objects. Each object needs at minimum:
- `id` -- unique identifier for `process.stop(id)`
- `name` -- human-readable name
- `cmd` -- the command string
- `port` -- port number or nil
- `start_time` -- unix timestamp
- `status` -- "running", "stopped", etc.
- `stdout` -- array of recent stdout lines
- `stderr` -- array of recent stderr lines
- `pid` -- system PID
- `cwd` -- working directory

### Open Browser Action

Use `xdg-open` (Linux) matching the pattern from the task 358 description. The `<C-o>` mapping should:
1. Get selected entry's port
2. Construct `http://localhost:{port}`
3. Open via `vim.fn.jobstart({"xdg-open", url}, {detach = true})`

## Decisions

- **File location**: `lua/neotex/plugins/tools/process-picker.lua` as specified in task description
- **Module type**: Utility module (M table), not a lazy.nvim plugin spec -- will NOT be added to `tools/init.lua`
- **Theme**: Default telescope theme (full width with preview), matching how `pickers.lua` creates its picker
- **Refresh**: Close-and-reopen pattern via `vim.defer_fn`, matching `picker.lua` convention
- **Browser**: `xdg-open` for Linux, consistent with task 358 description

## Risks & Mitigations

- **Risk**: Process registry API from task 358 may differ from assumed interface
  - **Mitigation**: Keep picker loosely coupled; only depends on `list()` returning process objects and `stop(id)` accepting an ID. Field names can be adjusted during implementation.
- **Risk**: stdout/stderr ring buffer may not exist yet in process.lua
  - **Mitigation**: Use `pcall` and fallback to "No output available" in previewer
- **Risk**: Picker refresh after kill may flash or lose cursor position
  - **Mitigation**: 100ms delay matches existing codebase pattern; acceptable UX

## Appendix

### Files Examined
- `lua/neotex/plugins/editor/telescope.lua` -- Main telescope config (211 lines)
- `lua/neotex/plugins/ai/claude/ui/pickers.lua` -- Claude session picker with previewer (272 lines)
- `lua/neotex/plugins/ai/shared/extensions/picker.lua` -- Extension picker with actions (256 lines)
- `lua/neotex/plugins/tools/worktree.lua` -- Git worktree picker (80+ lines examined)
- `lua/neotex/plugins/tools/init.lua` -- Tool plugin loading with safe_require (133 lines)
- `after/ftplugin/typst.lua` -- Existing process tracking pattern (413 lines)
- `lua/neotex/plugins/tools/mail.lua` -- Email integration (60 lines examined)

### Codebase grep results
- 14 files in `lua/` use `pickers.new` or `require("telescope.pickers")`
