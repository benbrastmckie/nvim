# Research Report: Task #358

**Task**: 358 - Create process manager core module
**Started**: 2026-04-03T17:05:00Z
**Completed**: 2026-04-03T17:05:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**: Codebase exploration (ftplugin, util modules, autocmds, toggleterm)
**Artifacts**: specs/358_process_manager_core/reports/01_process-mgr-core.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The codebase has a clear pattern for job management in `after/ftplugin/typst.lua` using `vim.fn.jobstart`/`jobstop` with a module-local variable -- this is exactly what the process manager should centralize
- The `lua/neotex/util/` namespace already has 13 modules following a consistent `local M = {} / return M` pattern with optional `setup()` functions, and `init.lua` auto-loads submodules
- Browser opening via `xdg-open` already exists in `lua/neotex/util/url.lua` with cross-platform detection; the process manager should reuse this pattern
- `VimLeavePre` cleanup is well-established across 5 existing modules; the process manager should follow the augroup pattern from `sleep-inhibit.lua`
- Port detection via `vim.uv.new_tcp()` (libuv) is the recommended approach -- no external tool dependencies

## Context and Scope

Research covers: existing job management patterns, utility module conventions, notification system integration, port auto-detection approaches, browser opening patterns, VimLeavePre cleanup, slidev specifics, and toggleterm compatibility.

## Findings

### 1. Existing Job Management Patterns

**`after/ftplugin/typst.lua`** (lines 274-324):
- Uses a module-local `typst_watch_job = nil` variable to track a single job
- `typst_watch()` calls `vim.fn.jobstart(cmd, opts)` with `on_stdout` and `on_exit` callbacks
- `on_exit` sets `typst_watch_job = nil` for cleanup
- `typst_watch_stop()` calls `vim.fn.jobstop(typst_watch_job)` then nils the variable
- Toggle pattern: `typst_watch()` stops if already running before starting new
- Exit code 143 (SIGTERM) treated as normal stop

**`typst_compile()`** (lines 206-271):
- Fire-and-forget compile job with `stderr_buffered = true`
- Parses stderr into quickfix items on exit
- Uses `vim.schedule()` inside `on_exit` for safe UI updates

**Key observation**: The typst module tracks only one job. The process manager must support multiple concurrent jobs with a registry table keyed by ID.

**`lua/neotex/util/sleep-inhibit.lua`**:
- Closest existing pattern to what process.lua needs
- Uses `M._state` table for job tracking (`inhibit_job_id`, `is_active`)
- `VimLeavePre` cleanup with `pcall(vim.fn.jobstop, id)`
- Good error handling with `vim.fn.executable()` check

### 2. Utility Module Patterns

All util modules follow this structure:
```lua
local M = {}
-- Optional: local notify = require('neotex.util.notifications')

-- Private functions (local function _helper())
-- Public API (function M.func())
-- Optional: function M.setup(opts)

return M
```

**`lua/neotex/util/init.lua`** auto-loads submodules listed in a `modules` table and calls `setup()` if it exists. The process manager module should:
1. Be added to the `modules` list in `init.lua`
2. Implement a `setup()` function that registers the `VimLeavePre` autocmd
3. Follow the naming convention: `lua/neotex/util/process.lua`

**Note**: `init.lua` also aliases public functions onto `M`, so `process.lua` functions like `start`, `stop`, `list` would become available as `util.start()` etc. Since these names are too generic, the process module should either:
- Use prefixed names: `M.process_start()`, `M.process_stop()`, `M.process_list()`
- Or (recommended) NOT be auto-loaded by init.lua and instead be required directly as `require('neotex.util.process')`

**Recommendation**: Keep `process.lua` as a standalone require (not in init.lua's auto-load list) to avoid name collisions. Consumers require it explicitly.

### 3. Notification System

**`lua/neotex/util/notifications.lua`** provides:
- `notify.editor(message, category, context)` -- module-specific notification
- Categories: `ERROR`, `WARNING`, `USER_ACTION`, `STATUS`, `BACKGROUND`
- Rate limiting and batching built-in

**Usage in process.lua**:
```lua
local notify = require('neotex.util.notifications')

-- For user-visible actions (process started/stopped):
notify.editor("Started slidev on port 3030", notify.categories.USER_ACTION)

-- For errors:
notify.editor("Failed to start process", notify.categories.ERROR, { error = err })

-- For background info:
notify.editor("Process exited cleanly", notify.categories.STATUS)
```

### 4. Port Auto-Detection

**Recommended approach: `vim.uv.new_tcp()`** (libuv, built into Neovim):

```lua
local function find_available_port(base_port)
  base_port = base_port or 3030
  for port = base_port, base_port + 100 do
    local tcp = vim.uv.new_tcp()
    local ok = pcall(function()
      tcp:bind("127.0.0.1", port)
    end)
    tcp:close()
    if ok then
      return port
    end
  end
  return nil
end
```

**Why this approach**:
- No external dependencies (no `ss` or `netstat` parsing)
- Uses Neovim's built-in libuv bindings (`vim.uv` or `vim.loop`)
- Fast: bind attempt is synchronous and immediate
- Reliable: tests actual port availability, not just listing
- Cross-platform: works on Linux, macOS, Windows

**Note**: `vim.uv` is the modern API (Neovim 0.10+). For backward compatibility, `vim.loop` is the older alias. Since this config targets modern Neovim, use `vim.uv`.

**Base port strategy**:
- Slidev default: 3030
- Typst-preview: handled by the plugin (random port)
- General: start at 8080 or configurable per filetype

### 5. Browser Opening

**Existing pattern in `lua/neotex/util/url.lua`** (lines 199-221):
```lua
if vim.fn.has("mac") == 1 then
  cmd = string.format("silent !open '%s' &", url)
elseif vim.fn.has("unix") == 1 then
  cmd = string.format("silent !xdg-open '%s' &", url)
elseif vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
  cmd = string.format("silent !start \"\" \"%s\"", url)
end
vim.cmd(cmd)
```

**For the process manager**, the browser-open function should:
1. Track which ports have been opened (set of opened ports)
2. Skip opening if already opened for that port (prevents duplicate tabs)
3. Use `vim.fn.jobstart({"xdg-open", url}, {detach = true})` instead of `vim.cmd("silent !")` for cleaner async execution
4. Delay opening slightly (`vim.defer_fn`, ~1500ms) to let the server start

**Recommended implementation**:
```lua
local opened_ports = {}

local function open_browser(port)
  if opened_ports[port] then return end
  opened_ports[port] = true

  vim.defer_fn(function()
    local url = string.format("http://localhost:%d", port)
    if vim.fn.has("unix") == 1 then
      vim.fn.jobstart({"xdg-open", url}, { detach = true })
    elseif vim.fn.has("mac") == 1 then
      vim.fn.jobstart({"open", url}, { detach = true })
    end
  end, 1500)
end
```

### 6. VimLeavePre Cleanup Strategy

**Existing patterns across the codebase** (5 modules):
- `toggleterm.lua`: Iterates all buffers, deletes terminal buftype buffers
- `sleep-inhibit.lua`: Uses augroup with `clear = true`, calls `pcall(vim.fn.jobstop, id)`
- `yanky.lua`, `autocmds.lua`, `himalaya/state.lua`: Various cleanup tasks

**Recommended pattern** (following sleep-inhibit.lua):
```lua
function M.setup(opts)
  local augroup = vim.api.nvim_create_augroup("ProcessManager", { clear = true })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = augroup,
    callback = function()
      for id, proc in pairs(M._registry) do
        pcall(vim.fn.jobstop, proc.job_id)
      end
      M._registry = {}
    end,
    desc = "Cleanup all tracked processes on Neovim exit",
  })
end
```

**Key considerations**:
- Use `pcall` around `jobstop` since the process may have already exited
- Clear the registry after stopping to prevent double-cleanup
- The augroup with `clear = true` prevents duplicate autocmds on re-source
- No notifications during `VimLeavePre` (Neovim is shutting down)

### 7. Slidev Specifics

Slidev is a presentation framework that serves markdown files as slides:
- Command: `npx slidev <file.md> --port <port>`
- Default port: 3030
- Working directory: should be the directory containing the markdown file (for relative asset resolution)
- Detection: a slidev file typically lives in a directory with `package.json` containing `"slidev"` as a dependency, or the markdown contains frontmatter with `---\ntheme:` or `---\nlayout:`

**Slidev detection heuristic**:
1. Check for `package.json` in file's directory or parent, containing `@slidev/cli` dependency
2. Check for `slides.md` or `slidev` in directory name
3. Check markdown frontmatter for slidev-specific keys (`theme`, `layout`, `class`, `highlighter`)

**Working directory**: Use the directory containing the target markdown file.

### 8. ToggleTerm Interaction

**`lua/neotex/plugins/editor/toggleterm.lua`**:
- Uses `<C-t>` mapping for toggle
- Direction: `vertical` (80 columns)
- Has its own `VimLeavePre` that deletes terminal buffers
- `close_on_exit = true`

**No conflict expected** because:
- The process manager uses `vim.fn.jobstart` (headless background jobs)
- ToggleTerm manages interactive terminal buffers
- They operate in completely different domains
- The process manager should NOT create terminal buffers -- just background jobs with stdout/stderr capture

### Recommended API Design

```lua
-- lua/neotex/util/process.lua
local M = {}

-- Private state
M._registry = {}    -- id -> process_info
M._next_id = 1      -- monotonically increasing
M._opened_ports = {} -- port -> true (browser tracking)

--- Start a background process
--- @param opts table
---   cmd: string[] (required) - command and arguments
---   name: string (optional) - display name
---   cwd: string (optional) - working directory
---   port: number|true (optional) - port number, or true for auto-detect
---   open_browser: boolean (optional) - auto-open browser on start
---   base_port: number (optional) - starting port for auto-detection
---   on_exit: function (optional) - callback(id, exit_code)
--- @return number|nil id Process ID in registry, or nil on failure
function M.start(opts) end

--- Stop a tracked process
--- @param id number Registry ID
--- @return boolean success
function M.stop(id) end

--- List all tracked processes
--- @return table[] Array of {id, name, cmd, port, cwd, start_time, status}
function M.list() end

--- Stop all tracked processes
function M.stop_all() end

--- Get process info by ID
--- @param id number
--- @return table|nil
function M.get(id) end

--- Find process by port
--- @param port number
--- @return table|nil
function M.find_by_port(port) end

--- Setup: register VimLeavePre cleanup
function M.setup(opts) end
```

**Registry entry structure**:
```lua
{
  id = 1,
  job_id = 42,          -- vim.fn.jobstart return value
  name = "slidev",
  cmd = {"npx", "slidev", "slides.md", "--port", "3030"},
  port = 3030,
  cwd = "/path/to/project",
  start_time = os.time(),
  stdout = {},           -- ring buffer (last N lines)
  stderr = {},           -- ring buffer (last N lines)
  status = "running",    -- "running" | "stopped" | "exited"
  exit_code = nil,
}
```

**Filetype launchers** (separate from core, but included for extensibility):
```lua
-- Filetype-aware launch registry
M._launchers = {}

--- Register a filetype launcher
--- @param ft string Filetype or pattern
--- @param launcher function(filepath) -> opts table for M.start()
function M.register_launcher(ft, launcher) end

--- Launch for current buffer's filetype
--- @return number|nil id
function M.launch() end
```

This keeps the core module focused on process lifecycle while allowing filetype-specific behavior to be registered from ftplugin files or plugin configs.

## Decisions

1. **Standalone module**: `process.lua` will NOT be auto-loaded by `util/init.lua` to avoid generic name collisions (`start`, `stop`, `list`). Consumers use `require('neotex.util.process')`.
2. **Port detection via libuv**: Use `vim.uv.new_tcp()` bind test -- no external dependencies.
3. **Browser tracking**: Maintain a set of opened ports to prevent duplicate browser tabs per session.
4. **Ring buffer for output**: Cap stdout/stderr at 200 lines each to prevent memory growth.
5. **Filetype launchers as registry**: Instead of hardcoding slidev/typst logic, provide `register_launcher()` so ftplugin files can register their own launch commands. Core module ships with a markdown-slidev launcher as a default.
6. **No terminal buffers**: Background jobs only via `vim.fn.jobstart`. Interactive terminals remain in toggleterm's domain.

## Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| Port bind-test race condition (port freed between check and use) | Acceptable for dev tools; retry with next port on EADDRINUSE |
| Orphaned processes if Neovim crashes (no VimLeavePre) | Document that crash-orphans require manual cleanup; consider writing PID file |
| stdout/stderr buffer memory growth | Ring buffer capped at 200 lines per stream |
| Slidev detection false positives | Use conservative heuristic (require package.json with slidev dep) |
| Browser open delay too short for slow server startup | Make delay configurable, default 1500ms, allow per-launcher override |
| `vim.uv` vs `vim.loop` compatibility | Use `vim.uv` (Neovim 0.10+); config targets modern Neovim |

## Appendix

### Files Examined
- `after/ftplugin/typst.lua` -- existing jobstart/jobstop patterns, the primary migration target
- `lua/neotex/util/misc.lua` -- module pattern reference
- `lua/neotex/util/notifications.lua` -- notification API for process events
- `lua/neotex/util/init.lua` -- submodule auto-loader (process.lua should NOT be added here)
- `lua/neotex/util/url.lua` -- xdg-open browser pattern
- `lua/neotex/util/sleep-inhibit.lua` -- background job + VimLeavePre cleanup pattern
- `lua/neotex/plugins/editor/toggleterm.lua` -- terminal management (no conflicts)
- `lua/neotex/config/autocmds.lua` -- VimLeavePre examples

### Search Queries
- `Grep: jobstart` in `after/ftplugin/` -- found only typst.lua
- `Grep: xdg-open` across codebase -- found url.lua pattern
- `Grep: VimLeavePre` across codebase -- found 5 existing cleanup handlers
- `Glob: lua/neotex/util/*.lua` -- found 13 existing util modules
