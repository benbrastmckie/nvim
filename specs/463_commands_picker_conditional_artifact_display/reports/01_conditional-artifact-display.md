# Research Report: Task #463

**Task**: 463 - Conditional Artifact Display in Commands Picker
**Started**: 2026-04-16T00:00:00Z
**Completed**: 2026-04-16T00:15:00Z
**Effort**: medium
**Dependencies**: None (task 463 already has uncommitted changes from prior work)
**Sources/Inputs**:
- Codebase: `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`
- Codebase: `lua/neotex/plugins/ai/claude/commands/picker/init.lua`
- Codebase: `lua/neotex/plugins/ai/claude/commands/parser.lua`
- Codebase: `lua/neotex/plugins/ai/shared/extensions/init.lua`
- Codebase: `lua/neotex/plugins/ai/shared/extensions/state.lua`
- Codebase: `lua/neotex/plugins/ai/shared/picker/config.lua`
- Codebase: `lua/neotex/plugins/ai/claude/extensions/init.lua`
**Artifacts**:
- `specs/463_commands_picker_conditional_artifact_display/reports/01_conditional-artifact-display.md`
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The commands picker (`entries.lua`) currently creates ALL artifact sections unconditionally -- commands, skills, agents, hooks, rules, scripts, tests, docs, context, lib, templates, memories, root files, and extensions are always shown regardless of whether the core agent system or any extensions are loaded.
- The asterisk (`*`) prefix is used across ALL artifact types to indicate "is_local" (exists in the project directory vs only in the global source). This conflicts with the desired behavior where asterisks should be reserved exclusively for extensions (to indicate loaded/active status).
- Extension state can be queried via `state_mod.read()` + `state_mod.list_loaded()` to determine which extensions are currently active; the extensions module's `list_available()` already provides per-extension status.
- The core agent system's "loaded" status can be inferred by checking whether the local project has a `.claude/` directory with core artifacts (commands, skills, agents).
- The refactoring requires changes primarily in `entries.lua` (the `create_picker_entries` function and individual `create_*_entries` functions) and possibly minor changes in `init.lua`.

## Context & Scope

The `<leader>ac` keymap opens the ClaudeCommands picker, which displays a hierarchical listing of all agent system artifacts. The task requires three behavioral changes:

1. **Conditional section visibility**: When no extensions are loaded, only show Extensions + special entries (Load Core, Help). Once extensions are loaded, show the full artifact listing.
2. **Remove asterisk from non-extension artifacts**: The `*` prefix currently indicates `is_local` on all artifact types. It should only appear on extensions (indicating loaded/active status).
3. **Previews must continue working**: All displayed artifacts must retain their previewer functionality.

### Uncommitted Changes

Two files have uncommitted changes from task 463 prior work:
- `entries.lua`: Simplified extension status indicator (removed `[active]`/`[inactive]` labels, kept only `[update]` indicator, asterisk prefix for active extensions)
- `init.lua`: Added cursor restoration after extension load/unload operations

## Findings

### 1. Current Entry Creation Architecture

`create_picker_entries(structure, config)` in `entries.lua` (line 1012) orchestrates all section creation. It calls 14 section creators in sequence:

| Order | Section Creator | Data Source | Asterisk Use |
|-------|----------------|-------------|--------------|
| 1 | `create_special_entries` | Static | None |
| 2 | `create_extensions_entries` | `extensions.list_available()` | `*` = active extension |
| 3 | `create_docs_entries` | Filesystem scan | `*` = is_local |
| 4 | `create_context_entries` | Filesystem scan | `*` = is_local |
| 5 | `create_lib_entries` | Filesystem scan | `*` = is_local |
| 6 | `create_templates_entries` | Filesystem scan | `*` = is_local |
| 7 | `create_scripts_entries` | Filesystem scan | `*` = is_local |
| 8 | `create_tests_entries` | Filesystem scan | `*` = is_local |
| 9 | `create_rules_entries` | Filesystem scan | `*` = is_local |
| 10 | `create_memory_entries` | Filesystem scan | `*` = is_local |
| 11 | `create_hooks_entries` | `structure.hook_events` | `*` = is_local |
| 12 | `create_skills_entries` | `structure.skills` | `*` = is_local |
| 13 | `create_agents_entries` | `structure.agents` | `*` = is_local |
| 14 | `create_root_files_entries` | `structure.root_files` | `*` = is_local |
| 15 | `create_commands_entries` | `structure.primary_commands` | `*` = is_local |

Insertion order is reversed for the descending sort strategy, so the last inserted appears at the top of the picker.

### 2. Asterisk Semantics

The asterisk prefix has two distinct meanings currently:
- **Extensions**: `*` means the extension is actively loaded (`ext.status == "active"`)
- **All other artifacts**: `*` means the artifact file exists locally in the project's `.claude/` directory (vs only existing in the global `~/.config/nvim/.claude/` directory)

The `is_local` flag is set by the `parse_with_fallback`, `parse_skills_with_fallback`, `parse_agents_with_fallback`, `parse_hooks_with_fallback` functions in `parser.lua` and by `scan.merge_artifacts` for filesystem-scanned artifacts.

### 3. Detecting Extension Load State

The extension system provides multiple ways to check state:

```lua
-- Via the extensions module (Claude-specific)
local exts = require("neotex.plugins.ai.claude.extensions")
local loaded_list = exts.list_loaded()  -- returns array of extension names
local available = exts.list_available() -- returns array with status field

-- Via the state module directly (generic)
local state_mod = require("neotex.plugins.ai.shared.extensions.state")
local ext_config = require("neotex.plugins.ai.claude.extensions.config").get()
local state = state_mod.read(vim.fn.getcwd(), ext_config)
local is_loaded = state_mod.is_loaded(state, "neovim")
local loaded_names = state_mod.list_loaded(state)
```

The `state_mod.list_loaded(state)` function (in `state.lua`) iterates `state.extensions` and returns names where `status == "active"`.

### 4. Detecting Core Agent System State

There is no explicit "core loaded" flag. The "Load Core Agent System" button (`sync.load_all_globally`) copies core artifacts from `~/.config/nvim/.claude/` to the project's `.claude/` directory. Core load state can be inferred by:

- Checking if `vim.fn.isdirectory(project_dir .. "/.claude/commands") == 1`
- Or checking if any commands were found (the existing guard at line 40 of `init.lua` already does this)

However, for the conditional display logic, we should NOT gate on "core loaded" -- the task description says: "When no extensions are loaded, only show the Extensions section." The core artifacts (commands, skills, agents, etc.) should appear based on whether they exist, but **whether sections are shown should depend on extension load state**.

Re-reading the task description more carefully:
1. "When no extensions are loaded, only show the Extensions section" -- this means hide all non-extension sections when no extensions are loaded
2. "Once the core agent system is loaded and extensions are loaded, show the full artifact listing" -- show everything when extensions exist

### 5. Format Functions Using Asterisk

The following functions produce asterisk prefixes for non-extension entries:

- `format_hook_event()` (line 17): `local prefix = has_local_hook and "*" or " "`
- `format_command()` (line 57): `local prefix = command.is_local and "*" or " "`
- `format_skill()` (line 619): `local prefix = skill.is_local and "*" or " "`
- `format_agent()` (line 636): `local prefix = agent.is_local and "*" or " "`
- `format_root_file()` (line 734): `local prefix = root_file.is_local and "*" or " "`
- `create_context_entries()` (line 120): `file.is_local and "*" or " "`
- `create_memory_entries()` (line 259, 281): `*_is_local and "*" or " "`
- `create_rules_entries()` (line 339): `rule.is_local and "*" or " "`
- `create_docs_entries()` (line 392): `is_local and "*" or " "`
- `create_lib_entries()` (line 440): `lib.is_local and "*" or " "`
- `create_templates_entries()` (line 490): `tmpl.is_local and "*" or " "`
- `create_scripts_entries()` (line 540): `script.is_local and "*" or " "`
- `create_tests_entries()` (line 590): `test.is_local and "*" or " "`

### 6. Previewer Impact

The previewer (`previewer.lua`) handles each `entry_type` independently. No changes are needed in the previewer since artifacts that are not shown simply won't be previewed. When they are shown (after extensions are loaded), the existing previewer logic handles them correctly.

## Decisions

1. **Conditional display gate**: Use `extensions.list_loaded()` (or equivalent) to check if any extensions are active. When the list is empty, only render Extensions + special entries.
2. **Asterisk removal**: Replace `is_local and "*" or " "` with `" "` (always space) in all non-extension format functions. The asterisk prefix should ONLY appear in `create_extensions_entries()`.
3. **Implementation location**: The conditional logic should be added to `create_picker_entries()` which already orchestrates all section creation. Skip calling non-extension section creators when no extensions are loaded.
4. **Config threading**: The extension check needs access to the `config` object (specifically `extensions_module`) to load the correct extensions module. This is already available as a parameter to `create_picker_entries`.

## Recommendations

### Implementation Approach

**Phase 1: Remove asterisk from non-extension artifacts**

Modify these functions in `entries.lua` to always use `" "` prefix instead of `is_local and "*" or " "`:
- `format_hook_event()` -- change line 35
- `format_command()` -- change line 58
- `format_skill()` -- change line 623
- `format_agent()` -- change line 639
- `format_root_file()` -- change line 738
- `create_context_entries()` -- change line 120
- `create_memory_entries()` -- change lines 259, 281
- `create_rules_entries()` -- change line 339
- `create_docs_entries()` -- change line 392
- `create_lib_entries()` -- change line 440
- `create_templates_entries()` -- change line 490
- `create_scripts_entries()` -- change line 540
- `create_tests_entries()` -- change line 590

**Phase 2: Add conditional section display**

Modify `create_picker_entries()` to check extension state before creating non-extension sections:

```lua
function M.create_picker_entries(structure, config)
  local all_entries = {}

  -- 1. Special entries (always shown)
  local special = M.create_special_entries(config)
  for _, entry in ipairs(special) do
    table.insert(all_entries, entry)
  end

  -- 2. Extensions section (always shown)
  local ext_entries = M.create_extensions_entries(config)
  for _, entry in ipairs(ext_entries) do
    table.insert(all_entries, entry)
  end

  -- Check if any extensions are loaded; if not, stop here
  local extensions_module = config and config.extensions_module
    or "neotex.plugins.ai.claude.extensions"
  local ok, extensions = pcall(require, extensions_module)
  local has_loaded_extensions = false
  if ok then
    local loaded = extensions.list_loaded()
    has_loaded_extensions = #loaded > 0
  end

  if not has_loaded_extensions then
    return all_entries
  end

  -- 3+. All other sections (only when extensions are loaded)
  -- ... (existing code for docs, context, lib, etc.)
end
```

**Phase 3: Testing**

- Open picker with no extensions loaded: should only show Extensions + Help + Load Core
- Load an extension, reopen: should show all sections without asterisks on non-extension entries
- Verify previews still work for all artifact types
- Verify Ctrl-l, Ctrl-u, Ctrl-s, Ctrl-e keymaps work on visible entries

### Edge Cases to Consider

1. **Config.extensions_module is nil**: Default to Claude module path (already handled by `or` fallback)
2. **pcall failure on extensions module**: Treat as no extensions loaded (show only Extensions section)
3. **Extensions loaded but core not synced**: Some sections may be empty (commands, skills, agents return empty arrays), which is already handled by the `if #entries > 0` guards in each section creator
4. **OpenCode variant**: The same `create_picker_entries` is used for both Claude and OpenCode configs; the extensions_module config field differs but the API is identical

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Breaking OpenCode picker | Low | Both share same code path; `config.extensions_module` handles the divergence |
| User confusion about missing sections | Medium | Could add a hint entry like "Load extensions to see all artifacts" when sections are hidden |
| Performance of `list_loaded()` on each picker open | Low | It reads a small JSON file from disk; negligible |
| Removing asterisks loses useful information | Medium | Users who relied on `*` to distinguish local vs global artifacts lose that signal. Consider adding a different indicator or tooltip in the previewer |

## Appendix

### Key File Paths
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Primary modification target (entry creation)
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Picker orchestration (minor if any changes)
- `lua/neotex/plugins/ai/claude/commands/parser.lua` - Structure parsing (no changes needed)
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Extension manager factory (read-only reference)
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - Extension state tracking (read-only reference)
- `lua/neotex/plugins/ai/shared/picker/config.lua` - Config presets (read-only reference)

### Asterisk Occurrence Count
- 15 distinct locations across `entries.lua` use `is_local and "*" or " "` for non-extension artifacts
- 1 location uses `*` correctly for extension active status (line 933)
