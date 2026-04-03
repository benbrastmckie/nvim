# Research Report: Task #361

**Task**: 361 - Integrate typst preview with process manager
**Started**: 2026-04-03T17:05:00Z
**Completed**: 2026-04-03T17:05:00Z
**Effort**: 30 minutes
**Dependencies**: 358 (process manager core), 360 (which-key mappings)
**Sources/Inputs**: Codebase analysis, typst-preview.nvim GitHub documentation
**Artifacts**: specs/361_typst_process_integration/reports/01_typst-integration.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- `after/ftplugin/typst.lua` contains three distinct job categories: `typst_compile()` (one-shot), `typst_watch()` (long-running), and TypstPreview commands (plugin-managed)
- Only `typst_watch()` and `typst_compile()` use raw `vim.fn.jobstart`/`jobstop` -- these CAN be migrated to process.lua
- TypstPreview commands are fully managed by the typst-preview.nvim plugin internally -- these must be WRAPPED, not replaced
- The `typst_watch_job` variable (script-local, line 274) is the only persistent job state; it tracks a single watch process with toggle semantics
- Migration is straightforward: replace 2 jobstart call sites and 2 jobstop call sites with process.lua API calls

## Context & Scope

Task 361 requires migrating typst job tracking from ad-hoc local variables in `after/ftplugin/typst.lua` to the shared process registry created in task 358. The goal is uniform process visibility in the telescope picker (task 359) and consistent lifecycle management.

## Findings

### 1. Complete Inventory of Job Management Code

#### File: `after/ftplugin/typst.lua` (413 lines)

**Job-managing functions:**

| Function | Lines | Type | Job Tracking | Browser-Serving |
|----------|-------|------|-------------|-----------------|
| `typst_compile()` | 206-271 | One-shot | None (fire-and-forget) | No |
| `typst_watch()` | 276-314 | Long-running | `typst_watch_job` variable | No |
| `typst_watch_stop()` | 316-324 | Cleanup | Clears `typst_watch_job` | No |
| `typst_view_pdf()` | 326-336 | Detached | None (`{ detach = true }`) | No (opens Sioyek) |

**Raw jobstart call sites (4 total):**

1. **Line 223**: `vim.fn.jobstart(cmd, {...})` in `typst_compile()` -- one-shot compile, stderr-buffered, populates quickfix on failure
2. **Line 296**: `typst_watch_job = vim.fn.jobstart(cmd, {...})` in `typst_watch()` -- long-running watch, stdout callback for "compiled successfully" messages
3. **Line 331**: `vim.fn.jobstart({ "sioyek", pdf }, { detach = true })` in `typst_view_pdf()` -- detached process, not tracked
4. **Line 364**: `pcall(vim.cmd, "TypstPreviewStop")` in `tinymist_clear_cache()` -- indirect, via plugin command

**Raw jobstop call sites (2 total):**

1. **Line 279**: `vim.fn.jobstop(typst_watch_job)` in `typst_watch()` toggle-off path
2. **Line 318**: `vim.fn.jobstop(typst_watch_job)` in `typst_watch_stop()`

**State variable:**

- `typst_watch_job` (line 274): Script-local variable, initialized to `nil`. Set by `typst_watch()`, cleared by `on_exit` callback and `typst_watch_stop()`. Only tracks ONE watch process at a time. Toggle semantics: calling `typst_watch()` when running stops the existing process.

#### Keybindings (`<leader>l` group, lines 379-395):

| Key | Function | Migration Target |
|-----|----------|-----------------|
| `<leader>lc` | `typst_watch` | Migrate to process.lua `start()` |
| `<leader>lw` | `typst_watch_stop` | Migrate to process.lua `stop()` |
| `<leader>lr` | `typst_compile` | Migrate to process.lua `start()` (one-shot) |
| `<leader>lp` | `<cmd>TypstPreview<CR>` | Wrap with process.lua registration |
| `<leader>ll` | `<cmd>TypstPreviewToggle<CR>` | Wrap with process.lua registration |
| `<leader>lx` | `<cmd>TypstPreviewStop<CR>` | Wrap with process.lua deregistration |
| `<leader>lv` | `typst_view_pdf` | No migration (detached, not tracked) |
| `<leader>ls` | `TypstPreviewSyncCursor` | No migration (not a process) |

### 2. Typst Preview Plugin Analysis

**Plugin**: `chomosuke/typst-preview.nvim` v1.x
**Config file**: `lua/neotex/plugins/text/typst-preview.lua`

**How it works:**
- Launches a tinymist preview server internally
- Opens a WebSocket connection for live updates
- Serves content to a browser (this IS browser-serving)
- Manages its own process lifecycle completely

**Commands provided:**
- `:TypstPreview` / `:TypstPreviewToggle` / `:TypstPreviewStop`
- `:TypstPreviewFollowCursor` / `:TypstPreviewNoFollowCursor` / `:TypstPreviewFollowCursorToggle`
- `:TypstPreviewSyncCursor`

**Lua API:**
- `require('typst-preview').set_follow_cursor(bool)`
- `require('typst-preview').sync_with_cursor()`

**Configuration relevant to integration:**
- `port` (default: 0, meaning random) -- can be set to a fixed port
- `host` (default: '127.0.0.1')
- `open_cmd` -- custom URL opener, receives URL with port

**Key limitation**: The plugin does NOT expose the server port or process ID through its public API. The port is handled internally. There is no `get_port()` or `get_pid()` function.

**Custom callbacks in our config:**
- `get_main_file(current_file)` -- duplicates `detect_main_file()` logic from ftplugin
- `get_root(main_file)` -- duplicates `detect_project_root()` logic from ftplugin

### 3. Integration Boundary Analysis

#### CAN be migrated (raw jobstart processes):

| Process | Current Tracking | Migration Strategy |
|---------|-----------------|-------------------|
| `typst watch` | `typst_watch_job` variable | Replace with `process.start({ cmd = {...}, name = "typst-watch", ... })` |
| `typst compile` | None (fire-and-forget) | Replace with `process.start({ cmd = {...}, name = "typst-compile", oneshot = true, ... })` |

These are straightforward. The process manager just wraps `vim.fn.jobstart` and stores the result in its registry instead of a local variable.

#### MUST stay (plugin-managed, but can be wrapped):

| Process | Why It Cannot Be Replaced | Wrapping Strategy |
|---------|--------------------------|-------------------|
| TypstPreview server | Plugin manages tinymist internally, no exposed PID/port | Register a "virtual" entry in process registry when `:TypstPreview` is called; deregister on `:TypstPreviewStop` |

#### Should NOT be migrated:

| Process | Reason |
|---------|--------|
| `sioyek` PDF viewer | Detached process (`{ detach = true }`), intentionally fire-and-forget |
| `tinymist_clear_cache` | Not a long-running process, just calls LspRestart |

### 4. TypstPreview Integration Strategy

Since typst-preview.nvim does not expose its server port or PID, we have two options:

**Option A: Virtual Registry Entry (Recommended)**
- When `<leader>lp` is pressed, call `:TypstPreview` AND register a virtual entry in process.lua
- The virtual entry stores: `{ name = "typst-preview", cmd = "tinymist preview", port = "unknown", type = "plugin-managed" }`
- When `<leader>lx` is pressed, call `:TypstPreviewStop` AND deregister from process.lua
- Pro: Minimal invasiveness, preview appears in telescope picker
- Con: Cannot show actual port or stop via process manager (must use plugin command)

**Option B: Fixed Port Configuration**
- Set `port = 12321` (or similar) in typst-preview.nvim config
- Register the entry with known port in process.lua
- Pro: Can show port, open browser via process manager
- Con: Port conflicts if multiple previews needed (unlikely for typst)

**Recommendation**: Use Option B with a configurable port. Set a default port in the typst-preview config (e.g., `port = 0` with detection), and register the entry. If port detection is not possible, fall back to Option A.

**Practical approach for Option B**: Use a fixed port like `12741` in the typst-preview.nvim config. This makes the port known to the process registry. The `open_cmd` config option could be leveraged to intercept the URL and extract the port if we keep `port = 0`.

### 5. Shared Helper Functions

Both `after/ftplugin/typst.lua` and `lua/neotex/plugins/text/typst-preview.lua` duplicate:
- `detect_main_file()` / `get_main_file()` -- identical logic
- `detect_project_root()` / `get_root()` -- similar logic

**Recommendation**: Extract shared helpers into a utility module (e.g., `lua/neotex/util/typst.lua`) and have both files import from it. This is out of scope for task 361 but worth noting for code quality.

### 6. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Breaking `typst_watch` toggle semantics | Low | Medium | Process.lua must support toggle (start if not running, stop if running) |
| TypstPreview virtual entry becomes stale | Medium | Low | Add autocmd or periodic check; TypstPreviewStop already explicit |
| Buffer-local state dependencies | Low | Low | `typst_watch_job` is script-local (not buffer-local), so no buffer isolation issues |
| `on_exit` callback not firing | Low | Medium | Process.lua should handle cleanup on exit callback, matching current behavior |
| Quickfix integration in `typst_compile` | Low | High | Process.lua `start()` must support `on_stderr` and `on_exit` callbacks passthrough |

**Critical requirement**: The `typst_compile()` function has complex stderr parsing and quickfix population in its `on_exit` callback (lines 235-269). Process.lua must allow custom callbacks to be passed through, not just generic tracking.

### 7. Buffer-Local State Dependencies

- `vim.b.typst_main_file` -- buffer-local, used by both ftplugin and plugin config. NOT affected by migration.
- `typst_watch_job` -- script-local to ftplugin (not buffer-local). This means only one watch process can run at a time across all typst buffers. This is the current behavior and should be preserved.
- `vim.opt_local.winfixbuf = false` (line 413) -- needed for typst-preview cross-jump. NOT affected by migration.

## Decisions

1. **Wrap, don't replace** TypstPreview commands -- the plugin manages its own process internally
2. **Replace** `typst_watch()` and `typst_compile()` jobstart/jobstop with process.lua API
3. **Keep** `sioyek` launcher as detached (no tracking needed)
4. **Preserve** toggle semantics for `typst_watch()` via process.lua
5. **Use Option B** (fixed port) for TypstPreview if feasible; fall back to Option A (virtual entry)
6. **Defer** helper deduplication (`detect_main_file`, `detect_project_root`) to a separate task

## Risks & Mitigations

- **Callback passthrough**: Process.lua API must accept `on_stdout`, `on_stderr`, `on_exit` callbacks. Without this, `typst_compile()` quickfix integration breaks. Mitigation: Design process.lua `start()` to merge tracking callbacks with user-provided callbacks.
- **Toggle semantics**: `typst_watch()` currently toggles on re-invocation. Process.lua should provide a `toggle(name)` method or the ftplugin wrapper handles this by checking `process.is_running("typst-watch")`.
- **Stale virtual entries**: If Neovim crashes or TypstPreview stops unexpectedly, the virtual entry may persist. Mitigation: Use `VimLeavePre` cleanup (already planned for process.lua) and/or periodic health checks.

## Recommended Approach

### Phase 1: Migrate `typst_watch()` and `typst_compile()`

1. Replace `typst_watch_job` variable and raw jobstart with:
   ```lua
   local process = require("neotex.util.process")
   process.start({
     name = "typst-watch",
     cmd = cmd,
     on_stdout = function(...) end,
     on_exit = function(...) end,
   })
   ```
2. Replace toggle logic with `process.is_running("typst-watch")` check
3. Replace `typst_watch_stop()` with `process.stop("typst-watch")`
4. Migrate `typst_compile()` similarly, marking as one-shot

### Phase 2: Wrap TypstPreview commands

1. Replace `<leader>lp` mapping to call a wrapper function:
   ```lua
   local function typst_preview_start()
     vim.cmd("TypstPreview")
     process.register_external({
       name = "typst-preview",
       cmd = "tinymist preview",
       port = 12741,  -- or detect from config
       type = "browser",
     })
   end
   ```
2. Similarly wrap `<leader>lx` to deregister
3. Wrap `<leader>ll` (toggle) with conditional register/deregister

### Phase 3: Verify integration

1. Confirm processes appear in telescope picker (task 359)
2. Confirm `<leader>xp` (process picker from task 360) shows typst processes
3. Confirm VimLeavePre cleanup stops all typst processes

## Appendix

### Search Queries Used
- Codebase: `typst_watch_job`, `jobstart`, `jobstop`, `TypstPreview` in after/ftplugin/ and lua/
- Web: "chomosuke typst-preview.nvim API commands port websocket"
- Web: typst-preview.nvim README.md for full command and config reference

### References
- [typst-preview.nvim GitHub](https://github.com/chomosuke/typst-preview.nvim)
- [typst-preview.nvim README](https://github.com/chomosuke/typst-preview.nvim/blob/master/README.md)
- `after/ftplugin/typst.lua` -- primary migration target
- `lua/neotex/plugins/text/typst-preview.lua` -- plugin configuration
- `after/ftplugin/tex.lua` -- comparison pattern (LaTeX uses VimTeX, not raw jobstart)
