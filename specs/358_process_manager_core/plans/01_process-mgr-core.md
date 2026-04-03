# Implementation Plan: Create process manager core module

- **Task**: 358 - Create process manager core module
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/358_process_manager_core/reports/01_process-mgr-core.md
- **Artifacts**: plans/01_process-mgr-core.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Create `lua/neotex/util/process.lua` -- a centralized process manager for background jobs in Neovim. The module provides a job registry, lifecycle management (start/stop/list/stop_all), port auto-detection via `vim.uv.new_tcp()`, browser auto-open with duplicate prevention, VimLeavePre cleanup, and a filetype launcher registry for extensibility. The module follows existing util module conventions (`local M = {} / return M`) but is required explicitly rather than auto-loaded by `util/init.lua` to avoid generic name collisions.

### Research Integration

Key findings from the research report:
- Existing job pattern in `after/ftplugin/typst.lua` uses module-local variable for single job tracking -- the process manager generalizes this to a multi-job registry
- `lua/neotex/util/sleep-inhibit.lua` provides the closest cleanup pattern (VimLeavePre with pcall + augroup)
- `lua/neotex/util/url.lua` has cross-platform browser opening via xdg-open -- process manager reuses the pattern with `vim.fn.jobstart` for cleaner async execution
- Port detection via `vim.uv.new_tcp()` bind test avoids external dependencies
- The process module should NOT be added to `util/init.lua`'s auto-load list

## Goals & Non-Goals

**Goals**:
- Create a standalone process registry module at `lua/neotex/util/process.lua`
- Implement core API: `start(opts)`, `stop(id)`, `list()`, `stop_all()`, `get(id)`, `find_by_port(port)`
- Implement port auto-detection using `vim.uv.new_tcp()` bind test
- Implement browser auto-open via xdg-open with per-port duplicate prevention
- Register VimLeavePre autocmd to clean up all tracked jobs on exit
- Implement filetype launcher registry: `register_launcher(ft, fn)` and `launch()`
- Ship default launchers for slidev (markdown) and typst-preview (typst)

**Non-Goals**:
- Migrating existing `after/ftplugin/typst.lua` job code (that is task 361)
- Creating the telescope picker UI (that is task 359)
- Adding which-key mappings (that is task 360)
- Interactive terminal buffer management (toggleterm's domain)
- Windows support (config targets Linux/macOS)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Port bind-test race condition (port freed between check and use) | L | L | Acceptable for dev tools; retry with next port on EADDRINUSE |
| Orphaned processes on Neovim crash (no VimLeavePre) | M | L | Document manual cleanup; PID tracking possible in future |
| stdout/stderr buffer memory growth | M | M | Ring buffer capped at 200 lines per stream |
| Slidev detection false positives | L | L | Conservative heuristic requiring package.json with slidev dep |
| Browser open delay too short for slow servers | L | M | Configurable delay, default 1500ms, per-launcher override |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Core module and process registry [NOT STARTED]

**Goal**: Create the process.lua module with registry data structure, `start()`, `stop()`, `list()`, `stop_all()`, `get()`, `find_by_port()`, and port auto-detection. This phase delivers a working process manager without browser or filetype features.

**Tasks**:
- [ ] Create `lua/neotex/util/process.lua` with module boilerplate following existing util patterns
- [ ] Define private state: `M._registry = {}`, `M._next_id = 1`, `M._opened_ports = {}`
- [ ] Implement `_find_available_port(base_port)` using `vim.uv.new_tcp()` bind test (scan base_port to base_port+100)
- [ ] Implement `_make_ring_buffer(max_size)` returning a table with `:push(line)` and `:lines()` methods, capped at 200 lines
- [ ] Implement `M.start(opts)`:
  - Validate `opts.cmd` is a non-empty table
  - If `opts.port == true`, call `_find_available_port(opts.base_port or 8080)`
  - Substitute `{port}` placeholder in cmd args with resolved port number
  - Call `vim.fn.jobstart(cmd, { cwd, on_stdout, on_stderr, on_exit })` 
  - On stdout/stderr: push lines into ring buffers
  - On exit: update registry entry status to "exited", set exit_code, call `opts.on_exit` if provided
  - Register entry in `M._registry[id]` with: id, job_id, name, cmd, port, cwd, start_time, stdout, stderr, status="running", exit_code=nil
  - Return id or nil on failure
- [ ] Implement `M.stop(id)`: call `pcall(vim.fn.jobstop, entry.job_id)`, set status="stopped", remove from registry after cleanup
- [ ] Implement `M.stop_all()`: iterate registry, stop each, clear registry
- [ ] Implement `M.list()`: return array of entry info tables (id, name, cmd, port, cwd, start_time, status)
- [ ] Implement `M.get(id)`: return registry entry or nil
- [ ] Implement `M.find_by_port(port)`: iterate registry, return first entry matching port
- [ ] Implement `M.setup(opts)`: create `ProcessManager` augroup, register VimLeavePre autocmd that calls `M.stop_all()`
- [ ] Add LuaDoc annotations for all public functions

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/util/process.lua` - Create new file (entire module)

**Verification**:
- Module loads without error: `nvim --headless -c "lua print(vim.inspect(require('neotex.util.process')))" -c "q"`
- All public functions exist and are callable
- `start()` returns an id when given a valid command
- `stop()` terminates a running process
- `list()` returns tracked processes
- `find_by_port()` returns correct entry

---

### Phase 2: Browser auto-open and notification integration [NOT STARTED]

**Goal**: Add browser auto-open functionality with duplicate prevention and integrate with the notification system for user feedback on process lifecycle events.

**Tasks**:
- [ ] Implement `_open_browser(port, delay)`:
  - Check `M._opened_ports[port]`; return early if already opened
  - Set `M._opened_ports[port] = true`
  - Use `vim.defer_fn` with configurable delay (default 1500ms)
  - Inside deferred fn: `vim.fn.jobstart({"xdg-open", url}, { detach = true })` for Linux, `{"open", url}` for macOS
  - Detect platform using `vim.fn.has("mac")` / `vim.fn.has("unix")`
- [ ] Integrate browser open into `M.start()`: if `opts.open_browser == true` and port is resolved, call `_open_browser(port, opts.browser_delay)`
- [ ] Add notification integration using `require('neotex.util.notifications')`:
  - On process start: `notify.editor("Started {name} on port {port}", notify.categories.USER_ACTION)`
  - On process start (no port): `notify.editor("Started {name}", notify.categories.USER_ACTION)`
  - On process stop: `notify.editor("Stopped {name}", notify.categories.USER_ACTION)`
  - On process exit (unexpected): `notify.editor("{name} exited with code {N}", notify.categories.WARNING)`
  - On process exit (normal): `notify.editor("{name} exited", notify.categories.STATUS)`
  - On port detection failure: `notify.editor("No available port found", notify.categories.ERROR)`
- [ ] Add `M.reset_browser_tracking()` to allow re-opening browsers after manual close
- [ ] Suppress notifications during VimLeavePre cleanup (set a `_shutting_down` flag)

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `lua/neotex/util/process.lua` - Add browser and notification functions

**Verification**:
- Starting a process with `open_browser = true` opens browser after delay
- Same port does not open duplicate browser tab
- Notifications appear for start/stop events
- No notifications during VimLeavePre cleanup

---

### Phase 3: Filetype launcher registry with defaults [NOT STARTED]

**Goal**: Add the filetype launcher registry and ship default launchers for slidev (markdown in slidev dirs) and typst-preview. This makes the module extensible for future filetypes.

**Tasks**:
- [ ] Implement `M._launchers = {}` table for filetype -> launcher function mapping
- [ ] Implement `M.register_launcher(ft, launcher_fn)`:
  - `ft`: string filetype (e.g., "markdown", "typst")
  - `launcher_fn`: `function(filepath) -> opts_table` returning a table suitable for `M.start()`
  - Store in `M._launchers[ft]`
- [ ] Implement `M.launch(filepath)`:
  - Default filepath to current buffer: `vim.api.nvim_buf_get_name(0)`
  - Determine filetype from `vim.bo.filetype` or `vim.filetype.match({ filename = filepath })`
  - Look up launcher in `M._launchers[ft]`
  - If no launcher found, notify warning and return nil
  - Call launcher function to get opts, then call `M.start(opts)`
  - Return process id
- [ ] Implement `_is_slidev_project(filepath)` detection:
  - Check for `package.json` in file's directory or parent containing `@slidev/cli`
  - Check markdown frontmatter for slidev keys (theme, layout, highlighter)
  - Return boolean
- [ ] Register default slidev launcher in `M.setup()`:
  ```lua
  M.register_launcher("markdown", function(filepath)
    if not _is_slidev_project(filepath) then return nil end
    local dir = vim.fn.fnamemodify(filepath, ":h")
    return {
      cmd = {"npx", "slidev", filepath, "--port", "{port}"},
      name = "slidev",
      cwd = dir,
      port = true,
      base_port = 3030,
      open_browser = true,
      browser_delay = 2000,
    }
  end)
  ```
- [ ] Register default typst launcher in `M.setup()` (wraps TypstPreview command):
  ```lua
  M.register_launcher("typst", function(filepath)
    -- Typst-preview is handled by the plugin, so we just track it
    -- The launcher triggers the command and registers in the registry
    vim.cmd("TypstPreview")
    return nil  -- TypstPreview manages its own process
  end)
  ```
- [ ] Add `M.get_launchers()` to list registered filetype launchers
- [ ] Add LuaDoc annotations for launcher API

**Timing**: 45 minutes

**Depends on**: 2

**Files to modify**:
- `lua/neotex/util/process.lua` - Add launcher registry and default launchers

**Verification**:
- `register_launcher("test", fn)` stores the launcher
- `get_launchers()` returns registered filetypes
- `launch()` on a markdown file in a slidev project starts slidev with port auto-detection
- `launch()` on an unsupported filetype shows warning notification
- Slidev detection correctly identifies slidev projects vs regular markdown

## Testing & Validation

- [ ] Module loads cleanly: `nvim --headless -c "lua require('neotex.util.process')" -c "q"` exits 0
- [ ] Port detection finds an available port: `lua print(require('neotex.util.process')._find_available_port(8080))`
- [ ] Start/stop lifecycle: start a sleep process, verify in list, stop it, verify removed
- [ ] Ring buffer caps at 200 lines (start a process that outputs >200 lines, verify buffer size)
- [ ] Browser dedup: call `_open_browser` twice with same port, verify xdg-open called only once
- [ ] VimLeavePre cleanup: start processes, exit Neovim, verify no orphaned jobs
- [ ] Launcher registry: register a test launcher, call launch(), verify process starts

## Artifacts & Outputs

- `lua/neotex/util/process.lua` - The process manager module (new file)
- `specs/358_process_manager_core/plans/01_process-mgr-core.md` - This plan
- `specs/358_process_manager_core/summaries/01_process-mgr-core-summary.md` - Execution summary (created during implementation)

## Rollback/Contingency

The process manager is a new standalone module with no existing code dependencies. Rollback is simply deleting `lua/neotex/util/process.lua`. No existing files are modified in this task, so there is zero risk of regression. Downstream tasks (359-361) depend on this module but are separate tasks.
