# Implementation Plan: Integrate typst preview with process manager

- **Task**: 361 - Integrate typst preview with process manager
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: 358 (process.lua), 360 (which-key mappings)
- **Research Inputs**: specs/361_typst_process_integration/reports/01_typst-integration.md
- **Artifacts**: plans/01_typst-integration.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

Migrate `after/ftplugin/typst.lua` from ad-hoc `vim.fn.jobstart`/`jobstop` calls with a script-local `typst_watch_job` variable to the shared `neotex.util.process` registry created in task 358. This makes typst watch, compile, and preview processes visible in the telescope process picker (task 359) and manageable through the unified `<leader>x` keymaps (task 360). The migration replaces 4 jobstart call sites and 2 jobstop call sites while preserving existing toggle semantics, quickfix integration, and keybindings.

### Research Integration

Key findings from the research report (01_typst-integration.md):
- Two functions use raw jobstart and can be directly migrated: `typst_watch()` and `typst_compile()`
- TypstPreview commands are plugin-managed and must be wrapped (not replaced) with virtual registry entries
- The `sioyek` PDF viewer launch is intentionally detached and should not be tracked
- Process.lua must support callback passthrough (`on_stdout`, `on_stderr`, `on_exit`) to preserve `typst_compile()` quickfix integration
- Toggle semantics for `typst_watch()` can use `process.is_running("typst-watch")` or equivalent lookup

## Goals & Non-Goals

**Goals**:
- Replace `typst_watch_job` variable and raw jobstart/jobstop with process.lua API calls
- Register TypstPreview as a virtual entry in the process registry when started/stopped
- Preserve toggle semantics for `typst_watch()` (calling again stops existing watch)
- Preserve quickfix error parsing in `typst_compile()` via callback passthrough
- Make all typst processes visible in the telescope process picker

**Non-Goals**:
- Extracting shared helper functions (`detect_main_file`, `detect_project_root`) into a shared module (separate task)
- Modifying typst-preview.nvim plugin configuration (port stays at default 0)
- Tracking the detached `sioyek` PDF viewer process
- Changing any keybindings or which-key registrations

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Process.lua API not yet implemented (task 358 not done) | H | M | Plan assumes API from 358 research; implementation blocks on 358 completion |
| Callback passthrough breaks quickfix integration | H | L | Test `typst_compile()` error parsing explicitly; verify `on_stderr`/`on_exit` work through process.lua |
| Toggle semantics regression | M | L | Use `process.find_by_name("typst-watch")` to check running state before starting |
| TypstPreview virtual entry becomes stale on crash | L | M | VimLeavePre cleanup in process.lua handles this; TypstPreviewStop explicit deregister handles normal case |
| Process.lua `start()` returns different ID format than `vim.fn.jobstart` | M | L | Do not rely on job_id directly; use process registry name-based lookup |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Migrate typst_watch and typst_compile to process.lua [NOT STARTED]

**Goal**: Replace raw `vim.fn.jobstart`/`jobstop` calls in `typst_watch()`, `typst_watch_stop()`, and `typst_compile()` with `process.start()`/`process.stop()` from the shared process registry.

**Tasks**:
- [ ] Add `local process = require("neotex.util.process")` at top of `after/ftplugin/typst.lua`
- [ ] Remove the script-local `typst_watch_job = nil` variable (line 274)
- [ ] Rewrite `typst_watch()` (lines 276-314):
  - Replace toggle check (`if typst_watch_job then vim.fn.jobstop(...)`) with `process.find_by_name("typst-watch")` lookup and `process.stop(id)`
  - Replace `typst_watch_job = vim.fn.jobstart(cmd, {...})` with `process.start({ name = "typst-watch", cmd = cmd, on_stdout = ..., on_exit = ... })`
  - Preserve `on_stdout` callback for "compiled successfully" notifications
  - Preserve `on_exit` callback for exit code handling (SIGTERM 143 = normal stop)
  - Remove manual `typst_watch_job = nil` in on_exit (process.lua handles cleanup)
- [ ] Rewrite `typst_watch_stop()` (lines 316-324):
  - Replace `vim.fn.jobstop(typst_watch_job)` with name-based lookup and `process.stop(id)`
  - Replace `typst_watch_job` nil check with `process.find_by_name("typst-watch")` existence check
- [ ] Rewrite `typst_compile()` (lines 206-271):
  - Replace `vim.fn.jobstart(cmd, {...})` with `process.start({ name = "typst-compile", cmd = cmd, on_stderr = ..., on_exit = ... })`
  - Preserve `stderr_buffered = true` behavior (pass through to process.lua options or handle in callbacks)
  - Preserve the entire `on_exit` callback with quickfix population logic unchanged
  - Mark as one-shot process if process.lua supports it

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `after/ftplugin/typst.lua` - Replace jobstart/jobstop calls with process.lua API

**Verification**:
- `typst_watch()` starts a watch process that appears in `process.list()`
- Calling `typst_watch()` again stops the running watch (toggle preserved)
- `typst_watch_stop()` stops the watch and removes it from registry
- `typst_compile()` runs compilation, populates quickfix on error, appears briefly in registry
- No references to `typst_watch_job` variable remain in the file
- No direct `vim.fn.jobstart` calls remain except the detached `sioyek` launcher (line 331)

---

### Phase 2: Wrap TypstPreview commands with virtual registry entries [NOT STARTED]

**Goal**: Register TypstPreview as a virtual process entry in the registry when started, and deregister when stopped, so it appears in the telescope process picker.

**Tasks**:
- [ ] Create wrapper function `typst_preview_start()`:
  - Calls `vim.cmd("TypstPreview")`
  - Registers a virtual entry via `process.register_external({ name = "typst-preview", cmd = "tinymist preview", type = "browser" })` (or equivalent API)
- [ ] Create wrapper function `typst_preview_stop()`:
  - Calls `vim.cmd("TypstPreviewStop")`
  - Deregisters the virtual entry via `process.deregister("typst-preview")` (or name-based removal)
- [ ] Create wrapper function `typst_preview_toggle()`:
  - Checks `process.find_by_name("typst-preview")` to determine state
  - Calls start or stop wrapper accordingly
- [ ] Update which-key mappings (lines 386-394):
  - Change `<leader>lp` from `"<cmd>TypstPreview<CR>"` to `typst_preview_start`
  - Change `<leader>lx` from `"<cmd>TypstPreviewStop<CR>"` to `typst_preview_stop`
  - Change `<leader>ll` from `"<cmd>TypstPreviewToggle<CR>"` to `typst_preview_toggle`
- [ ] Update `tinymist_clear_cache()` (line 364): ensure `pcall(vim.cmd, "TypstPreviewStop")` also deregisters from process registry

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `after/ftplugin/typst.lua` - Add wrapper functions and update which-key entries

**Verification**:
- `<leader>lp` starts TypstPreview AND registers it in `process.list()`
- `<leader>lx` stops TypstPreview AND removes it from `process.list()`
- `<leader>ll` toggles correctly with registry state matching plugin state
- `tinymist_clear_cache()` deregisters the preview entry
- Virtual entry visible in telescope process picker (when tasks 358/359 are implemented)

## Testing & Validation

- [ ] Open a `.typ` file, press `<leader>lc` -- watch process appears in registry, notifications work
- [ ] Press `<leader>lc` again -- watch stops (toggle), removed from registry
- [ ] Press `<leader>lw` -- watch stops if running, correct warning if not
- [ ] Press `<leader>lr` -- one-shot compile runs, quickfix populates on error, process briefly in registry
- [ ] Press `<leader>lp` -- TypstPreview starts, virtual entry in registry
- [ ] Press `<leader>lx` -- TypstPreview stops, virtual entry removed
- [ ] Press `<leader>ll` -- toggles preview with registry tracking
- [ ] Press `<leader>lC` (clear cache) -- stops preview and deregisters
- [ ] Press `<leader>lv` -- sioyek opens, NOT tracked in registry (detached, intentional)
- [ ] No `typst_watch_job` variable references remain (grep verification)
- [ ] Only one `vim.fn.jobstart` remains (the detached sioyek call on line 331)

## Artifacts & Outputs

- `specs/361_typst_process_integration/plans/01_typst-integration.md` (this plan)
- `after/ftplugin/typst.lua` (modified)

## Rollback/Contingency

Revert `after/ftplugin/typst.lua` to its pre-migration state via `git checkout`. The file is self-contained -- no other files depend on the `typst_watch_job` variable or the raw jobstart calls. If process.lua API is unavailable or incompatible, the original code can be restored with a single file revert.
