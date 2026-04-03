# Implementation Plan: Telescope Process Picker

- **Task**: 359 - Create telescope process picker
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: 358 (process manager core module)
- **Research Inputs**: specs/359_telescope_process_picker/reports/01_process-picker.md
- **Artifacts**: plans/01_process-picker.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Create a telescope picker module at `lua/neotex/plugins/tools/process-picker.lua` that displays background processes from the `neotex.util.process` registry. The picker shows name, command, port, uptime, and status columns with a buffer previewer for stdout/stderr output. Actions include `<CR>` to kill a process (with picker refresh) and `<C-o>` to open the process port in a browser. The module exports `M.show()` for use by which-key mappings (task 360) and is NOT a lazy.nvim plugin spec.

### Research Integration

Key findings from the research report:
- 14 existing telescope pickers in the codebase provide consistent patterns for `pickers.new()`, `entry_maker`, `new_buffer_previewer`, and `attach_mappings`
- The close-and-reopen refresh pattern via `vim.defer_fn` is established in `picker.lua`
- The process registry (task 358) exposes `list()` returning process objects and `stop(id)` for termination
- Browser opening uses `xdg-open` via `vim.fn.jobstart` with `detach = true`

## Goals & Non-Goals

**Goals**:
- Create a telescope picker that displays all tracked background processes
- Support killing processes via `<CR>` with automatic picker refresh
- Support opening process ports in a browser via `<C-o>`
- Show process metadata and recent stdout/stderr in preview pane
- Export `M.show(opts)` function callable from which-key mappings

**Non-Goals**:
- Not a lazy.nvim plugin spec (will NOT be added to `tools/init.lua`)
- No process start/restart functionality from the picker
- No multi-select bulk operations
- No custom theme (use default telescope theme with preview)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Process registry API differs from assumed interface | M | L | Keep coupling loose; only depend on `list()` and `stop(id)`. Use optional chaining for field access. |
| stdout/stderr ring buffer not yet available in process.lua | M | M | Use `pcall` and fallback to "No output available" in previewer |
| Picker refresh after kill may flash | L | M | 100ms `vim.defer_fn` delay matches existing codebase pattern |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Core Picker Module [NOT STARTED]

**Goal**: Create the complete telescope process picker module with entry maker, previewer, actions, and `M.show()` export.

**Tasks**:
- [ ] Create `lua/neotex/plugins/tools/process-picker.lua` with `local M = {}` / `return M` structure
- [ ] Add telescope requires at module level: `pickers`, `finders`, `actions`, `action_state`, `conf`, `previewers`
- [ ] Implement `format_uptime(start_time)` helper: returns human-readable elapsed time (e.g., "5s", "12m", "1h 30m")
- [ ] Implement `create_entry_maker()` using `string.format("%-15s %-30s %-8s %-8s %s", name, cmd:sub(1,30), port, uptime, status)` with ordinal as `name .. " " .. cmd` for fuzzy search
- [ ] Implement `create_previewer()` using `previewers.new_buffer_previewer` with `define_preview` that shows: command, PID, port, CWD, start time header, separator, then stdout lines (last 50), then stderr lines (last 20) from process ring buffers. Set filetype to "log" for syntax highlighting.
- [ ] Implement `M.show(opts)` function that:
  - Calls `require("neotex.util.process").list()` to get processes
  - Shows `vim.notify("No background processes running", vim.log.levels.INFO)` if empty
  - Creates picker with `prompt_title = "Background Processes"`, the entry maker, `conf.generic_sorter({})`, and the previewer
- [ ] Implement `attach_mappings` with:
  - `actions.select_default:replace()` for `<CR>`: get selection, close picker, call `process.stop(selection.value.id)`, notify, re-open via `vim.defer_fn(function() M.show(opts) end, 100)`
  - `map("i", "<C-o>", ...)` and `map("n", "<C-o>", ...)`: get selection, check port exists, construct `http://localhost:{port}`, open via `vim.fn.jobstart({"xdg-open", url}, {detach = true})`, notify
  - Return `true` to keep default mappings for unhandled keys

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/tools/process-picker.lua` - New file: complete telescope picker module (~100 lines)

**Verification**:
- File exists and follows `local M = {} / return M` pattern
- Module loads without error: `lua require("neotex.plugins.tools.process-picker")`
- `M.show` is a callable function
- All telescope requires are present
- Entry maker produces display string with fixed-width columns
- Previewer uses `new_buffer_previewer` with process metadata header
- `<CR>` action calls `process.stop()` and refreshes picker
- `<C-o>` action opens browser for port-bearing processes

---

### Phase 2: Edge Cases and Polish [NOT STARTED]

**Goal**: Handle edge cases, add defensive coding, and verify integration readiness.

**Tasks**:
- [ ] Add `pcall` guard around `require("neotex.util.process")` in `M.show()` with user-friendly error if process module not available (task 358 not yet implemented)
- [ ] Add nil-safe field access in entry maker: `proc.name or "unnamed"`, `proc.cmd or ""`, `proc.port`, `proc.start_time or os.time()`, `proc.status or "unknown"`
- [ ] Add nil-safe field access in previewer for all process fields (`pid`, `cwd`, `stdout`, `stderr`)
- [ ] Handle empty stdout/stderr arrays in previewer: show "No output captured" placeholder
- [ ] Add `<C-o>` normal mode mapping (duplicate of insert mode) for consistency
- [ ] Verify no reference to `tools/init.lua` (module must NOT be registered as a plugin spec)
- [ ] Add LuaDoc comments for `M.show(opts)` with `@param opts table|nil` and `@return nil`

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/tools/process-picker.lua` - Add defensive guards and documentation

**Verification**:
- Module handles missing process.lua gracefully (no crash)
- Nil process fields do not cause errors in entry maker or previewer
- Empty stdout/stderr shows placeholder text in preview
- LuaDoc annotations present on public API
- File is NOT referenced in `tools/init.lua`

## Testing & Validation

- [ ] Module loads without error in Neovim: `:lua require("neotex.plugins.tools.process-picker")`
- [ ] `M.show()` displays "No background processes" notification when registry is empty
- [ ] With running processes (after task 358), picker displays entries with correct column format
- [ ] `<CR>` on a process entry kills it and refreshes the picker
- [ ] `<C-o>` on a port-bearing process opens the browser
- [ ] `<C-o>` on a portless process shows a warning notification
- [ ] Preview pane shows process metadata header and stdout/stderr content
- [ ] Module is not loaded by `tools/init.lua` as a plugin spec

## Artifacts & Outputs

- `specs/359_telescope_process_picker/plans/01_process-picker.md` (this plan)
- `lua/neotex/plugins/tools/process-picker.lua` (implementation output)
- `specs/359_telescope_process_picker/summaries/01_process-picker-summary.md` (post-implementation)

## Rollback/Contingency

Delete `lua/neotex/plugins/tools/process-picker.lua`. The module is standalone with no side effects on load and is not registered in any plugin spec loader. No other files are modified.
