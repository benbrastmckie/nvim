# Research Report: Task #119

**Task**: 119 - fix_hardcoded_paths_in_picker
**Started**: 2026-03-03T00:00:00Z
**Completed**: 2026-03-03T00:30:00Z
**Effort**: 1-2 hours (implementation)
**Dependencies**: Task 118 (completed - config threading infrastructure)
**Sources/Inputs**: Local codebase analysis (picker modules, shared config, parser)
**Artifacts**: - /home/benjamin/.config/nvim/specs/119_fix_hardcoded_paths_in_picker/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- Six functions in `entries.lua` and two functions in `sync.lua`/`edit.lua` use hardcoded `".claude/"` path segments instead of reading from the picker config's `base_dir` field
- The `preview_heading` function in `previewer.lua` has hardcoded `".claude/"` paths and does not receive config
- The `scan_artifacts_for_picker` function in `scan.lua` also hardcodes `".claude/"` paths
- Task 118 already established the config-threading infrastructure (shared.picker.config, config param on `create_special_entries`, config param on `create_picker_entries`), so the fix involves threading `config` to the remaining functions and using `config.base_dir`

## Context & Scope

The picker system displays Claude Code artifacts (commands, hooks, skills, agents, docs, lib, scripts, tests, templates) in a Telescope picker. It was originally designed solely for `.claude/` directories. Task 118 introduced the shared picker config system (`neotex.plugins.ai.shared.picker.config`) so that both Claude (`<leader>ac`) and OpenCode (`<leader>ao`) can reuse the same picker infrastructure with different `base_dir` values (`.claude` vs `.opencode`).

However, several functions were not updated during task 118 and still construct paths using the hardcoded `".claude/"` string, causing the OpenCode picker to scan the wrong directories.

## Findings

### 1. Hardcoded Paths in `entries.lua` (6 functions)

All six directory-scanning entry creators in `display/entries.lua` follow the same pattern -- they call `vim.fn.getcwd()` and `scan.get_global_dir()` locally and concatenate `"/.claude/"` instead of using `config.base_dir`:

**`create_docs_entries()` (lines 80-122)**
```lua
local local_docs = scan.scan_directory(project_dir .. "/.claude/docs", "*.md")
local global_docs = scan.scan_directory(global_dir .. "/.claude/docs", "*.md")
```

**`create_lib_entries()` (lines 126-168)**
```lua
local local_lib = scan.scan_directory(project_dir .. "/.claude/lib", "*.sh")
local global_lib = scan.scan_directory(global_dir .. "/.claude/lib", "*.sh")
```

**`create_templates_entries()` (lines 172-214)**
```lua
local local_templates = scan.scan_directory(project_dir .. "/.claude/templates", "*.yaml")
local global_templates = scan.scan_directory(global_dir .. "/.claude/templates", "*.yaml")
```

**`create_scripts_entries()` (lines 218-260)**
```lua
local local_scripts = scan.scan_directory(project_dir .. "/.claude/scripts", "*.sh")
local global_scripts = scan.scan_directory(global_dir .. "/.claude/scripts", "*.sh")
```

**`create_tests_entries()` (lines 264-306)**
```lua
local local_tests = scan.scan_directory(project_dir .. "/.claude/tests", "test_*.sh")
local global_tests = scan.scan_directory(global_dir .. "/.claude/tests", "test_*.sh")
```

**`create_extensions_entries()` (line 590)**
```lua
local extensions_module = config and config.extensions_module or "neotex.plugins.ai.claude.extensions"
```
Note: This function already receives `config` but the five functions above do not.

### 2. Hardcoded Paths in `previewer.lua` (2 locations)

**`preview_heading()` (lines 62-114)**
```lua
local local_path = vim.fn.getcwd() .. "/.claude/" .. ordinal .. "/README.md"
local global_path = scan_mod.get_global_dir() .. "/.claude/" .. ordinal .. "/README.md"
```
This function does NOT receive a config parameter. The `entry` it receives has no config attached (headings are not special entries). The heading entries would need config threaded to them, or `preview_heading` needs to accept config separately.

**`scan_directory_for_sync()` in previewer (lines 19-40)**
This is a local helper that already accepts a `base_dir` parameter and defaults to `".claude"`. It IS already called with `base_dir` from `preview_load_all()` (line 192). This is already fixed.

### 3. Hardcoded Paths in `sync.lua` - `update_artifact_from_global()` (lines 546-644)

```lua
-- Line 593: Root file path construction
global_filepath = global_dir .. "/.claude/" .. artifact.name

-- Line 595: Non-root file path construction
global_filepath = global_dir .. "/.claude/" .. config.dir .. "/" .. artifact.name .. config.ext

-- Line 611: Root file local directory
local_dir = project_dir .. "/.claude"

-- Line 614: Non-root file local directory
local_dir = project_dir .. "/.claude/" .. config.dir
```

Note: the variable name `config` here is confusing because it shadows the picker config -- this `config` refers to the local `subdir_map[artifact_type]` variable. The actual picker config (with `base_dir`) is not available in this function.

### 4. Hardcoded Paths in `edit.lua` (3 locations)

**`save_artifact_to_global()` (line 73)**
```lua
local global_target_dir = global_dir .. "/.claude/" .. subdir
```

**`load_artifact_locally()` (lines 144, 153, 199, 201)**
```lua
local local_dir = project_dir .. "/.claude/" .. subdir
global_filepath = global_dir .. "/.claude/" .. subdir .. "/" .. artifact.name
local dep_global_path = global_dir .. "/.claude/commands/" .. dep_name .. ".md"
local dep_local_path = project_dir .. "/.claude/commands/" .. dep_name .. ".md"
```

### 5. Hardcoded Paths in `scan.lua` - `scan_artifacts_for_picker()` (lines 176-201)

```lua
local local_path = dirs.project_dir .. "/.claude/" .. subdir
local global_path = dirs.global_dir .. "/.claude/" .. subdir
```

### 6. Hardcoded Paths in `parser.lua` - `get_command_structure()` (lines 747-761)

```lua
local project_dir = vim.fn.getcwd() .. "/.claude/commands"
local global_dir = scan_mod.get_global_dir() .. "/.claude/commands"
```

Note: `get_extended_structure()` (the main function used by the picker) already correctly uses `config.base_dir`. The `get_command_structure()` function is a separate entry point.

## Current Config Threading Status

The config threading infrastructure is partially complete from task 118:

| Function | Receives config? | Uses base_dir? | Status |
|----------|-----------------|----------------|--------|
| `init.show_commands_picker()` | Yes | Yes | OK |
| `parser.get_extended_structure()` | Yes | Yes | OK |
| `entries.create_picker_entries()` | Yes (config param) | Passes to some | Partial |
| `entries.create_special_entries()` | Yes | Yes | OK |
| `entries.create_extensions_entries()` | Yes | Yes | OK |
| `entries.create_commands_entries()` | No (uses structure) | N/A | OK (parser handles) |
| `entries.create_skills_entries()` | No (uses structure) | N/A | OK (parser handles) |
| `entries.create_agents_entries()` | No (uses structure) | N/A | OK (parser handles) |
| `entries.create_hooks_entries()` | No (uses structure) | N/A | OK (parser handles) |
| `entries.create_root_files_entries()` | No (uses structure) | N/A | OK (parser handles) |
| **`entries.create_docs_entries()`** | **No** | **No - hardcoded** | **NEEDS FIX** |
| **`entries.create_lib_entries()`** | **No** | **No - hardcoded** | **NEEDS FIX** |
| **`entries.create_templates_entries()`** | **No** | **No - hardcoded** | **NEEDS FIX** |
| **`entries.create_scripts_entries()`** | **No** | **No - hardcoded** | **NEEDS FIX** |
| **`entries.create_tests_entries()`** | **No** | **No - hardcoded** | **NEEDS FIX** |
| `previewer.preview_help()` | Yes | Yes | OK |
| `previewer.preview_load_all()` | Yes | Yes | OK |
| **`previewer.preview_heading()`** | **No** | **No - hardcoded** | **NEEDS FIX** |
| **`sync.update_artifact_from_global()`** | **No** | **No - hardcoded** | **NEEDS FIX** |
| **`edit.save_artifact_to_global()`** | **No** | **No - hardcoded** | **NEEDS FIX** |
| **`edit.load_artifact_locally()`** | **No** | **No - hardcoded** | **NEEDS FIX** |
| **`scan.scan_artifacts_for_picker()`** | **No** | **No - hardcoded** | **NEEDS FIX** |
| `sync.load_all_globally()` | Yes | Yes | OK |
| `sync.scan_all_artifacts()` | Yes | Yes | OK |
| `sync.execute_sync()` | Yes (base_dir param) | Yes | OK |

## Recommendations

### Implementation Approach

**Phase 1: Thread config to entries.lua functions (5 functions)**

Add a `config` parameter to each of the five directory-scanning entry creator functions. In `create_picker_entries()`, pass the `config` parameter to each call. The pattern is uniform:

```lua
-- Before:
function M.create_docs_entries()
  local project_dir = vim.fn.getcwd()
  local global_dir = scan.get_global_dir()
  local local_docs = scan.scan_directory(project_dir .. "/.claude/docs", "*.md")
  local global_docs = scan.scan_directory(global_dir .. "/.claude/docs", "*.md")

-- After:
function M.create_docs_entries(config)
  local project_dir = vim.fn.getcwd()
  local global_dir = config and config.global_source_dir or scan.get_global_dir()
  local base_dir = config and config.base_dir or ".claude"
  local local_docs = scan.scan_directory(project_dir .. "/" .. base_dir .. "/docs", "*.md")
  local global_docs = scan.scan_directory(global_dir .. "/" .. base_dir .. "/docs", "*.md")
```

**Phase 2: Thread config to previewer.preview_heading()**

The heading entries currently do not carry config. Two options:
1. Attach config to heading entries in `entries.lua` (like special entries do) and extract in previewer
2. Pass config through the previewer constructor

Option 1 is simpler and consistent with how special entries already work. Add `config = config` to each heading entry creation, then extract `entry.value.config` in `preview_heading()`.

**Phase 3: Thread config to sync.update_artifact_from_global()**

Add a `config` parameter (or extract `base_dir` from the picker config). The function is called from `init.lua` line 193 where `config` is available but not passed. The tricky part is the local variable `config` (renamed from `subdir_map[artifact_type]`) which shadows the picker config. Rename the local variable to `type_config` to avoid confusion.

**Phase 4: Thread config to edit.lua functions**

Both `save_artifact_to_global()` and `load_artifact_locally()` need a `config` or `base_dir` parameter. They are called from `init.lua` where picker config is available. Same rename issue: the local `subdir_map` variable.

**Phase 5: Fix scan.scan_artifacts_for_picker()**

Add `base_dir` parameter or config parameter. Currently this function is used by the artifact registry system and may need a separate approach.

### Lazy Loading Strategy

No lazy loading changes needed -- all modules are already loaded on-demand when the picker is opened.

### Keymap Interaction

- `<leader>ac` calls `claude/commands/picker.lua` which creates `shared_config.claude()` and passes it to `init.show_commands_picker()`
- `<leader>ao` calls `opencode/commands/picker.lua` which creates `shared_config.opencode()` and passes it to `init.show_commands_picker()`
- The config flows through `init.lua` -> `entries.lua` / `previewer.lua` / `sync.lua` / `edit.lua`
- The fix ensures all downstream functions receive and use this config

## Decisions

- Use option 1 (attach config to heading entries) for `preview_heading()` config threading, consistent with existing special entry pattern
- Rename local `config` variable in `sync.update_artifact_from_global()` to `type_config` to avoid shadowing
- Pass picker config (or just base_dir) as additional parameter to `edit.lua` functions
- The `scan_artifacts_for_picker()` function in `scan.lua` should also accept a `base_dir` parameter but this function may not be actively used by the current picker flow (it appears to be part of the artifact registry system); verify usage before fixing

## Risks & Mitigations

- **Risk**: Changing function signatures could break callers not yet updated
  - **Mitigation**: All new parameters default to `.claude` when nil, ensuring backward compatibility
- **Risk**: The variable name `config` is used both for picker config and for local type config maps
  - **Mitigation**: Rename local variables to `type_config` where there is ambiguity
- **Risk**: Tests may reference hardcoded paths
  - **Mitigation**: scan_spec.lua tests use `.claude` in test fixtures; these are correct for testing the Claude path and do not need changing. Add new tests for `.opencode` paths.

## Context Extension Recommendations

None -- the existing context files adequately cover the picker architecture and shared config patterns.

## Appendix

### Files Requiring Changes

1. `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`
   - `create_docs_entries()` -- add config param, use base_dir
   - `create_lib_entries()` -- add config param, use base_dir
   - `create_templates_entries()` -- add config param, use base_dir
   - `create_scripts_entries()` -- add config param, use base_dir
   - `create_tests_entries()` -- add config param, use base_dir
   - `create_picker_entries()` -- pass config to above functions, attach config to heading entries

2. `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`
   - `preview_heading()` -- extract config from entry, use base_dir for README path

3. `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
   - `update_artifact_from_global()` -- add config/base_dir param, rename local config, use base_dir

4. `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/operations/edit.lua`
   - `save_artifact_to_global()` -- add config/base_dir param, use base_dir
   - `load_artifact_locally()` -- add config/base_dir param, use base_dir

5. `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/init.lua`
   - Pass config to `sync.update_artifact_from_global()` call (line 193)
   - Pass config to `edit.load_artifact_locally()` call (line 169)
   - Pass config to `edit.save_artifact_to_global()` call (line 217)

6. `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua`
   - `scan_artifacts_for_picker()` -- add base_dir param, use it instead of hardcoded `.claude/`

### Hardcoded Path Count Summary

| File | Hardcoded ".claude/" Count | Status |
|------|---------------------------|--------|
| entries.lua | 10 (5 functions x 2 paths) | Needs fix |
| previewer.lua | 2 (preview_heading) | Needs fix |
| sync.lua (update_artifact) | 4 | Needs fix |
| edit.lua | 5 | Needs fix |
| scan.lua (scan_artifacts_for_picker) | 2 | Needs fix |
| **Total** | **23** | |

### References

- `neotex.plugins.ai.shared.picker.config` -- config factory (claude/opencode presets)
- `neotex.plugins.ai.claude.commands.picker.lua` -- Claude facade
- `neotex.plugins.ai.opencode.commands.picker.lua` -- OpenCode facade
- Task 118 commits (9cc31ab4..a1ebde1e) -- config threading infrastructure
