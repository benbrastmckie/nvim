# Implementation Plan: Redesign leader ao picker - Load Core Agent System

- **Task**: 118 - Redesign leader ao picker: Load All Artifacts -> Load Core Agent System
- **Status**: [IMPLEMENTING]
- **Effort**: 3-5 hours
- **Dependencies**: None
- **Research Inputs**:
  - [research-001.md](../reports/research-001.md) - scan_all_artifacts() analysis, extension manifest provides structure, exclusion strategy
  - [research-002.md](../reports/research-002.md) - Claude Code picker shared architecture, previewer hardcoded-path gaps, config threading
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

The `<leader>ao` (and `<leader>ac`) picker's "Load All Artifacts" entry currently syncs ALL global content to projects, including extension-owned agents, skills, commands, rules, context, and scripts. This pollutes non-extension projects with domain-specific artifacts (lean, latex, z3, etc.) that should only appear when explicitly loaded via extension entries. The fix builds an exclusion set from extension manifest `provides` fields, applies post-scan filtering in `scan_all_artifacts()`, renames the picker entry, fixes hardcoded `.claude` paths in the previewer, and threads config through to special entries and preview functions. Both the Claude and OpenCode pickers share identical code, so changes apply once and benefit both systems.

### Research Integration

Research report 001 mapped the complete extension-owned inventory across 9 manifests (20 agents, 22 skill directories, 3 commands, 4 rules, 8 context directories, 2 scripts) and recommended post-scan filtering (Option A) over modifying scan_directory_for_sync. Research report 002 identified three additional improvements: the previewer's hardcoded `.claude` paths (bug), missing config threading to `create_special_entries()` and `preview_load_all()`, and the need for entry-based config passing (Option A) to the previewer.

## Goals & Non-Goals

**Goals**:
- Build extension exclusion set from all extension manifests' `provides` fields
- Filter `scan_all_artifacts()` results to exclude extension-owned files
- Rename picker entry from "[Load All Artifacts]" to "[Load Core Agent System]"
- Fix previewer hardcoded `.claude` paths to use `config.base_dir`
- Thread picker config through to special entries and preview functions
- Ensure both Claude and OpenCode pickers benefit from changes

**Non-Goals**:
- Modifying extension loading/unloading logic
- Changing `scan_directory_for_sync()` utility internals
- Altering keymap bindings (`<leader>ao`, `<leader>ac`)
- Modifying the individual artifact load/update operations (Ctrl-l, Ctrl-u)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Skills matching by directory name misses nested files | Extension skills leak into core sync | Low | Use path-based matching (`global_path:match("/" .. dir_name .. "/")`) not filename matching |
| Context prefix matching too aggressive (e.g., "project/" matches everything) | Core context excluded | Low | Match exact prefix after `context/` segment: `"project/lean4"` only matches `context/project/lean4/...` |
| Malformed extension manifests cause errors | Core sync broken | Low | `manifest.list_extensions()` already validates manifests; invalid ones return nil and are skipped |
| Previewer refactor breaks existing preview display | Preview panel empty or wrong | Medium | Previewer changes are additive (pass config parameter, use it for base_dir); fallback to `.claude` when config is nil |
| OpenCode agents_subdir difference (`agent/subagents`) affects filtering | Agents not filtered correctly for OpenCode | Low | Filter runs on scan results which already use config-appropriate paths; matching is by filename, not path structure |

## Implementation Phases

### Phase 1: Build Extension Exclusion Infrastructure in sync.lua [COMPLETED]

- **Goal:** Add functions to build per-category exclusion sets from extension manifests and filter scan results against those sets. This is the core logic that enables core-only sync.

- **Tasks:**
  - [ ] Add `build_extension_exclusions(global_dir, config)` function to `sync.lua` that:
    - Derives extension config from `config.base_dir` using `shared.extensions.config.claude()` or `.opencode()`
    - Calls `shared.extensions.manifest.list_extensions(ext_config)` to get all extension manifests
    - Iterates over each manifest's `provides` field
    - Builds and returns a table with per-category exclusion sets:
      - `agents`: Set of filenames (e.g., `{ ["lean-research-agent.md"] = true }`)
      - `commands`: Set of filenames
      - `rules`: Set of filenames
      - `scripts`: Set of filenames
      - `hooks`: Set of filenames
      - `skills`: Set of directory names (e.g., `{ ["skill-lean-research"] = true }`)
      - `context`: Array of directory prefixes (e.g., `{ "project/lean4", "project/latex" }`)
  - [ ] Add `filter_extension_files(files, exclude_set)` function that filters a file array by checking `file.name` against the exclusion set (for agents, commands, rules, scripts, hooks)
  - [ ] Add `filter_extension_skills(files, skill_dirs_exclude)` function that filters skill files by checking if `file.global_path` contains any excluded skill directory name segment
  - [ ] Add `filter_extension_context(files, context_prefixes, base_dir)` function that filters context files by checking if the file's path relative to `context/` starts with any excluded prefix

- **Timing:** 1 hour

- **Files to modify:**
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Add 4 new functions

- **Verification:**
  - Functions are syntactically correct (no Lua errors on require)
  - `build_extension_exclusions()` returns expected structure when called with test config
  - Filter functions correctly exclude known extension files from test arrays

---

### Phase 2: Integrate Exclusion Filtering into scan_all_artifacts() [COMPLETED]

- **Goal:** Apply the exclusion filters after each scan category in `scan_all_artifacts()` so that the returned artifacts contain only core system files.

- **Tasks:**
  - [ ] At the top of `scan_all_artifacts()`, call `build_extension_exclusions(global_dir, config)` to get exclusion sets
  - [ ] After scanning agents, apply `filter_extension_files(artifacts.agents, exclusions.agents)`
  - [ ] After scanning commands, apply `filter_extension_files(artifacts.commands, exclusions.commands)`
  - [ ] After scanning skills (combined md + yaml), apply `filter_extension_skills(artifacts.skills, exclusions.skills)`
  - [ ] After scanning rules, apply `filter_extension_files(artifacts.rules, exclusions.rules)`
  - [ ] After scanning scripts, apply `filter_extension_files(artifacts.scripts, exclusions.scripts)`
  - [ ] After scanning hooks, apply `filter_extension_files(artifacts.hooks, exclusions.hooks)`
  - [ ] After scanning context (combined md + json + yaml), apply `filter_extension_context(artifacts.context, exclusions.context, base_dir)`
  - [ ] Ensure filtering is a no-op when no extensions exist (empty exclusion sets)

- **Timing:** 45 minutes

- **Files to modify:**
  - `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Modify `scan_all_artifacts()` (lines 159-261)

- **Verification:**
  - Open Neovim, navigate to a test project (e.g., `~/Projects/ModelChecker/`)
  - Run `<leader>ao`, select "[Load Core Agent System]" (after Phase 3 rename, or temporarily test with current label)
  - Verify the confirmation dialog shows reduced file counts (no lean, latex, z3, etc. agents/skills/commands/rules/context)
  - Compare before/after counts: extension agents (20), skills (~22 dirs), commands (3), rules (4), context dirs (8) should be excluded

---

### Phase 3: Rename Picker Entry and Thread Config to Special Entries [NOT STARTED]

- **Goal:** Rename "[Load All Artifacts]" to "[Load Core Agent System]" in the picker display, update the description text, and thread picker config through to `create_special_entries()` for system-appropriate labeling.

- **Tasks:**
  - [ ] Modify `create_special_entries()` signature in `entries.lua` to accept `config` parameter: `function M.create_special_entries(config)`
  - [ ] Change display text from `"[Load All Artifacts]"` to `"[Load Core Agent System]"`
  - [ ] Update description from `"Sync commands, hooks, skills, agents, docs, lib"` to `"Sync core system artifacts (excludes extensions)"`
  - [ ] Attach config to the `is_load_all` entry value: `config = config` in the entry table (for previewer access per Option A from research)
  - [ ] Update `create_picker_entries()` call site (line 699) to pass config: `local special = M.create_special_entries(config)`
  - [ ] Update help text reference in `previewer.lua` line 169: change `"[Load All]"` to `"[Load Core]"`

- **Timing:** 30 minutes

- **Files to modify:**
  - `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Modify `create_special_entries()` and `create_picker_entries()`
  - `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Update help text (line 169)

- **Verification:**
  - Open picker with `<leader>ao` and `<leader>ac`
  - Verify the entry reads "[Load Core Agent System]" with updated description
  - Verify help preview references "[Load Core]" instead of "[Load All]"

---

### Phase 4: Fix Previewer Hardcoded Paths and Config Threading [NOT STARTED]

- **Goal:** Fix the `preview_load_all()` and `preview_help()` functions to use `config.base_dir` instead of hardcoded `.claude`, and make the preview counts reflect core-only (filtered) artifacts.

- **Tasks:**
  - [ ] Modify `preview_load_all()` to accept config parameter: `local function preview_load_all(self, config)`
  - [ ] Replace the local `scan_directory_for_sync` helper (lines 18-38) with a config-aware version that uses `config.base_dir` instead of hardcoded `.claude`:
    - Change `global_dir .. "/.claude/" .. subdir` to `global_dir .. "/" .. base_dir .. "/" .. subdir`
    - Change `project_dir .. "/.claude/" .. subdir` to `project_dir .. "/" .. base_dir .. "/" .. subdir`
    - The function should accept `base_dir` as an additional parameter
  - [ ] In `preview_load_all()`, extract `base_dir` from config: `local base_dir = (config and config.base_dir) or ".claude"`
  - [ ] Update all `scan_directory_for_sync` calls in `preview_load_all()` to pass `base_dir`
  - [ ] Update the title line from `"Load All Artifacts"` to `"Load Core Agent System"`
  - [ ] Update the description lines (230-231) to use `base_dir` and mention extension exclusion:
    - `"This action will sync core system artifacts from " .. global_dir .. "/" .. base_dir .. "/ to your"`
    - `"local project's " .. base_dir .. "/ directory (extensions excluded)."`
  - [ ] Update the "Global directory" status line (261) to use `base_dir`
  - [ ] Modify `preview_help()` to accept config parameter: `local function preview_help(self, config)`
  - [ ] In `preview_help()`, replace hardcoded `.claude/` references with `base_dir`:
    - Line 161: `"  *       - Artifact defined locally in project (" .. base_dir .. "/)"`
    - Line 162: `"            Otherwise a global artifact from " .. global_dir .. "/" .. base_dir .. "/"`
    - Line 175: `"       Local artifacts override global ones from " .. global_dir .. "/"`
  - [ ] Update `create_command_previewer()` to pass config from entry value to preview functions:
    - At the `is_load_all` branch (line 758-759): `preview_load_all(self, entry.value.config)`
    - At the `is_help` branch (line 756-757): `preview_help(self, entry.value.config)` -- but help entry does not carry config, so pass nil (falls back to `.claude`)
  - [ ] Optionally attach config to the help entry in `create_special_entries()` for consistency

- **Timing:** 1 hour

- **Files to modify:**
  - `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Modify `scan_directory_for_sync`, `preview_load_all()`, `preview_help()`, `create_command_previewer()`

- **Verification:**
  - Open `<leader>ao` picker and hover over "[Load Core Agent System]"
  - Verify preview shows `.opencode` paths (not `.claude`) and correct counts
  - Open `<leader>ac` picker and verify preview shows `.claude` paths
  - Verify help text references `config.base_dir` correctly for both pickers
  - Verify all counts exclude extension artifacts

---

### Phase 5: End-to-End Verification and Testing [NOT STARTED]

- **Goal:** Validate the complete implementation across both picker systems, verify extension exclusion correctness, and ensure no regressions.

- **Tasks:**
  - [ ] Test core-only sync with OpenCode picker (`<leader>ao`):
    - Navigate to `~/Projects/ModelChecker/` (or any non-Neovim project)
    - Open `<leader>ao`, select "[Load Core Agent System]"
    - Verify confirmation dialog shows only core agents (general-*, planner, meta-builder, neovim-*, orchestrator) not extension agents (lean-*, latex-*, z3-*, etc.)
    - Verify only core skills appear (skill-git-workflow, skill-implementer, skill-learn, skill-meta, skill-neovim-*, skill-orchestrator, skill-planner, skill-refresh, skill-researcher, skill-status-sync)
    - Verify only core commands appear (no lake.md, lean.md, convert.md)
    - Verify only core rules appear (no lean4.md, latex.md, web-astro.md, nix.md)
    - Verify core context directories are included (hooks/, meta/, neovim/, processes/, repo/) and extension context excluded (lean4/, latex/, logic/, math/, physics/, typst/, web/, nix/, python/, z3/)
  - [ ] Test core-only sync with Claude picker (`<leader>ac`):
    - Verify same filtering behavior for `.claude` system
    - Confirm that since `.claude` global dir is currently clean, counts are unchanged (filtering is a no-op as expected)
  - [ ] Test extension loading still works independently:
    - Open `<leader>ao`, scroll to Extensions section
    - Load an extension (e.g., lean)
    - Verify extension artifacts appear in the project's `.opencode/` directory
    - Unload the extension
  - [ ] Test edge cases:
    - Test with no extensions directory present (graceful empty exclusion set)
    - Test with a project that already has extension artifacts loaded (core sync should not remove them, just skip syncing new extension content)
  - [ ] Run headless Lua syntax verification:
    ```bash
    nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "q"
    nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q"
    nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.previewer')" -c "q"
    ```

- **Timing:** 45 minutes

- **Files to modify:**
  - None (verification only)

- **Verification:**
  - All headless require tests pass without errors
  - Both pickers display "[Load Core Agent System]" with correct descriptions
  - Preview shows config-appropriate paths and filtered counts
  - Core sync excludes all 9 extensions' provided artifacts
  - Extension toggle (load/unload) still works independently
  - No Lua errors in picker operation

## Testing & Validation

- [ ] Headless module load test: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "q"` exits cleanly
- [ ] Headless module load test: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q"` exits cleanly
- [ ] Headless module load test: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.previewer')" -c "q"` exits cleanly
- [ ] OpenCode picker shows "[Load Core Agent System]" entry (not "[Load All Artifacts]")
- [ ] Claude picker shows "[Load Core Agent System]" entry
- [ ] OpenCode preview shows `.opencode` paths (not hardcoded `.claude`)
- [ ] Claude preview shows `.claude` paths
- [ ] Core sync to test project excludes extension agents (20 agents across 9 extensions)
- [ ] Core sync to test project excludes extension skills (22 skill directories)
- [ ] Core sync to test project excludes extension commands (lake.md, lean.md, convert.md)
- [ ] Core sync to test project excludes extension rules (lean4.md, latex.md, web-astro.md, nix.md)
- [ ] Core sync to test project excludes extension context directories (8 directories)
- [ ] Extension load/unload via Extensions section still works independently
- [ ] Help preview references correct base_dir for each picker

## Artifacts & Outputs

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Extension exclusion filtering added
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Renamed entry, config threading
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Config-aware previews, fixed hardcoded paths
- `specs/118_redesign_leader_ao_load_core_agent_system/summaries/implementation-summary-20260303.md` - Post-implementation summary

## Rollback/Contingency

All changes are in 3 Lua files. If the implementation causes issues:
1. Revert the 3 modified files with `git checkout HEAD -- lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`
2. The extension system, individual artifact load/update operations, and picker keymaps are all unchanged and unaffected
3. No state files, configuration files, or extension manifests are modified by this task
