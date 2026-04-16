# Research Report: Task #420

**Task**: 420 - Prevent extension loader sync from overwriting repo-specific CLAUDE.md customizations
**Started**: 2026-04-13T12:00:00Z
**Completed**: 2026-04-13T12:30:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**:
- Codebase exploration of extension loader system
- `lua/neotex/plugins/ai/shared/extensions/` (init, loader, merge, state, config modules)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (core sync operation)
- Extension manifests (`present/manifest.json`, `nvim/manifest.json`)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` (scan utilities)
**Artifacts**:
- `specs/420_prevent_extension_loader_overwriting_repo_customizations/reports/01_extension-loader-sync.md`
**Standards**: report-format.md, artifact-management.md, tasks.md

## Executive Summary

- There are **two independent sync mechanisms** that can overwrite repo-specific CLAUDE.md content, each with a different root cause
- **Mechanism 1 ("Load Core Agent System")**: The `sync.load_all_globally()` function copies `.claude/CLAUDE.md` wholesale from the global nvim config to the target repo, obliterating any repo-local content including extension-injected sections
- **Mechanism 2 ("Extension reload")**: The extension `unload()`/`load()` cycle correctly uses section markers (`<!-- SECTION: extension_present -->`) for its own injected content, but the core sync overwrites the entire file first
- The extension merge system (`merge.inject_section`) is well-designed with idempotent section markers, but it cannot protect against the core sync's full-file overwrite
- The fix requires making the core sync aware of extension-injected sections in `CLAUDE.md`, either by merging rather than overwriting, or by protecting marked sections during sync

## Context & Scope

When the `<leader>ac` keybinding opens the Claude Commands picker, one of the options is "Load Core Agent System" which syncs the entire `.claude/` directory from `~/.config/nvim/.claude/` (the "global" source) to the current project. This is implemented in `sync.load_all_globally()`.

Separately, extensions can be loaded/unloaded via the same picker. Extensions use a merge-based approach for CLAUDE.md: they inject content between HTML comment markers (`<!-- SECTION: extension_foo -->` ... `<!-- END_SECTION: extension_foo -->`).

The problem: when the core sync runs after extensions have been loaded, it copies the global `.claude/CLAUDE.md` (which has NO extension sections) over the local `.claude/CLAUDE.md` (which HAS extension sections), silently removing all extension-injected content.

## Findings

### Codebase Architecture

The extension loader system lives in `lua/neotex/plugins/ai/shared/extensions/` with five modules:

| Module | Purpose |
|--------|---------|
| `config.lua` | Configuration schema (base_dir, merge_target_key, etc.) |
| `init.lua` | Public API: `load()`, `unload()`, `reload()`, `verify()` |
| `loader.lua` | File copy engine for agents, skills, context, scripts, data |
| `merge.lua` | Merge strategies for CLAUDE.md, settings.json, index.json |
| `state.lua` | Extension state tracking via extensions.json |
| `verify.lua` | Post-load verification |

### Mechanism 1: Core Sync ("Load Core Agent System")

**File**: `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`

The `scan_all_artifacts()` function (line 186) builds a list of all artifacts to sync. At line 293-312, it handles `root_files`:

```lua
root_file_names = { ".gitignore", "README.md", "CLAUDE.md", "settings.local.json" }
```

For each root file, it reads from the global source and determines whether to "copy" (new) or "replace" (existing). When the user selects "Sync all", the `execute_sync()` function (line 100) calls `sync_files()` which reads the global file content and writes it to the local path, performing a **complete overwrite**.

This is the primary root cause. The global `.claude/CLAUDE.md` in `~/.config/nvim` is the canonical agent system documentation. It does NOT contain any extension sections because extensions are loaded per-project. When this file overwrites the local copy, all extension-injected sections (like the present extension's skill-agent mapping table, commands table, and routing table) are lost.

### Mechanism 2: Extension Load/Unload

**File**: `lua/neotex/plugins/ai/shared/extensions/init.lua`

The extension `load()` function (line 206) correctly uses merge semantics:

1. Copies files (agents, skills, context, etc.) via `loader.copy_simple_files()`
2. Processes merge targets via `process_merge_targets()` which calls `merge.inject_section()`
3. Tracks all changes in `extensions.json` for clean unload

The `merge.inject_section()` function (merge.lua line 137) is well-designed:
- Uses HTML comment markers: `<!-- SECTION: extension_present -->`
- Is idempotent (updates existing sections, appends new ones)
- Backs up the target file before modification
- Tracks the section_id for later removal via `remove_section()`

However, the extension system has **no protection against external modification** of the target file between load and unload. If the core sync overwrites CLAUDE.md, the extension state still records the section as "merged", but the content is gone.

### How the Problem Manifests

The typical sequence causing data loss:

1. User opens project (e.g., zed repo)
2. User runs `<leader>ac` and selects "Load Core Agent System" -- this copies core `.claude/` including `CLAUDE.md`
3. User selects extension "present" from picker -- this injects present extension sections into `.claude/CLAUDE.md` with section markers
4. User works normally, possibly adding repo-specific customizations to CLAUDE.md outside any section markers
5. Later, user runs `<leader>ac` "Load Core Agent System" again to get latest changes
6. The sync **overwrites** `.claude/CLAUDE.md` with the global version, removing:
   - All extension-injected sections (between `<!-- SECTION -->` markers)
   - All repo-specific manual customizations

### Extension Manifest Structure

Extensions declare their CLAUDE.md contributions via `merge_targets.claudemd`:

```json
{
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_present"
    }
  }
}
```

The `EXTENSION.md` file contains the content to inject (tables, documentation). This is appended between section markers when the extension is loaded.

### What Repo-Specific Content Is At Risk

Any content in `.claude/CLAUDE.md` that differs from the global source:
1. **Extension-injected sections** (between `<!-- SECTION -->` markers) -- the primary concern
2. **Manual additions** to tables (e.g., adding a custom agent to the Skill-Agent Mapping table)
3. **Repo-specific documentation** added outside section markers

### Other Repos at Risk

Any repo where the user has:
- Loaded extensions via `<leader>ac`
- Made manual edits to `.claude/CLAUDE.md`
- Then synced core again

The zed repo (mentioned in the task description) is the known example, but any project using extensions is vulnerable.

## Decisions

- The extension merge system (section markers + inject/remove) is the correct pattern and should be preserved
- The core sync's full-file overwrite of `CLAUDE.md` is the root cause and must be changed
- The fix should not require changes to existing extension manifests

## Recommendations

### Approach 1: Section-Aware Sync for CLAUDE.md (Recommended)

Modify `sync_files()` or `execute_sync()` to treat `CLAUDE.md` specially:

1. When syncing `CLAUDE.md`, read the local file first
2. Extract all `<!-- SECTION: ... -->` blocks from the local file
3. Write the global CLAUDE.md content
4. Re-inject the preserved section blocks at the end

**Pros**: Preserves extension sections automatically, no extension manifest changes needed, backward compatible.
**Cons**: Does not preserve manual edits outside section markers.

**Implementation sketch** (in `sync.lua`):

```lua
-- Before overwriting CLAUDE.md, preserve extension sections
local function preserve_sections(local_content)
  local sections = {}
  for section_id, content in local_content:gmatch(
    "<!%-%- SECTION: ([%w_]+) %-%->(.-)<!%-%- END_SECTION: [%w_]+ %-%->"
  ) do
    table.insert(sections, { id = section_id, content = content })
  end
  return sections
end

local function restore_sections(new_content, sections)
  for _, section in ipairs(sections) do
    local start_marker = "<!-- SECTION: " .. section.id .. " -->"
    local end_marker = "<!-- END_SECTION: " .. section.id .. " -->"
    new_content = new_content .. "\n" .. start_marker .. section.content .. end_marker .. "\n"
  end
  return new_content
end
```

### Approach 2: Exclude CLAUDE.md from Root File Sync

Remove `CLAUDE.md` from the `root_file_names` list in `scan_all_artifacts()`, relying solely on the extension merge system and manual management for that file.

**Pros**: Simple one-line change.
**Cons**: Users lose the ability to get CLAUDE.md updates from global source. The core agent system documentation would drift.

### Approach 3: Two-Layer CLAUDE.md Architecture

Split CLAUDE.md into two files:
- `.claude/CLAUDE.core.md` -- synced from global, never modified locally
- `.claude/CLAUDE.md` -- the actual file read by Claude, which `@import`s the core file and has local additions

**Pros**: Clean separation of concerns.
**Cons**: Claude Code does not support `@import` in CLAUDE.md files. Would require a build/concatenation step.

### Approach 4: Post-Sync Extension Re-injection

After `execute_sync()` completes, read `extensions.json` and re-run `process_merge_targets()` for all loaded extensions.

**Pros**: Uses existing merge logic, handles all merge target types (CLAUDE.md, settings, index.json).
**Cons**: Requires the sync operation to be aware of the extension system. Couples the two systems.

**Implementation sketch** (in `sync.lua`):

```lua
-- After execute_sync(), re-inject extension sections
local ext_state = state_mod.read(project_dir, config)
local loaded = state_mod.list_loaded(ext_state)
for _, ext_name in ipairs(loaded) do
  local extension = manifest_mod.get_extension(ext_name, ext_config)
  if extension then
    process_merge_targets(extension.manifest, extension.path, project_dir, ext_config)
  end
end
```

### Approach 5: Validation Warning Before Sync

Add a check in `load_all_globally()` that detects extension sections in CLAUDE.md and warns the user before overwriting.

**Pros**: Non-invasive, user retains control.
**Cons**: Does not prevent data loss if user dismisses warning. Extra friction.

### Recommended Solution: Approach 1 + Approach 4 Combined

1. **For CLAUDE.md specifically**: Extract and re-inject section markers (Approach 1) -- this is fast, simple, and handles the common case
2. **For all merge targets**: After sync, re-run merge targets for loaded extensions (Approach 4) -- this handles settings.json and index.json too, where the same overwrite problem could occur

The combined approach is robust because:
- Section preservation (Approach 1) handles CLAUDE.md without needing to re-read extension sources
- Post-sync re-injection (Approach 4) provides defense-in-depth for all merge targets
- Neither approach requires changes to extension manifests or the merge module

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Section markers could be malformed after manual editing | Validate marker pairs before preservation; skip orphaned markers |
| Multiple syncs could accumulate duplicate sections | The existing `inject_section()` is idempotent -- it replaces existing sections with same ID |
| Performance impact of re-injection | Minimal: reading extensions.json and a few EXTENSION.md files is fast |
| Backward compatibility | No changes to manifest format or extension API; existing extensions work unchanged |

## Appendix

### Key Files

| File | Role |
|------|------|
| `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` | Core sync operation (contains root_file_names list) |
| `lua/neotex/plugins/ai/shared/extensions/merge.lua` | Section inject/remove logic |
| `lua/neotex/plugins/ai/shared/extensions/init.lua` | Extension load/unload orchestration |
| `lua/neotex/plugins/ai/shared/extensions/config.lua` | Extension system configuration |
| `lua/neotex/plugins/ai/shared/extensions/state.lua` | Extension state (extensions.json) |
| `lua/neotex/plugins/ai/shared/extensions/loader.lua` | File copy engine |
| `lua/neotex/plugins/editor/which-key.lua:250` | `<leader>ac` keybinding definition |

### Section Marker Format

```
<!-- SECTION: extension_present -->
... extension content ...
<!-- END_SECTION: extension_present -->
```

### Sync Flow Diagram

```
User: <leader>ac -> "Load Core Agent System"
  |
  v
sync.load_all_globally()
  |
  v
scan_all_artifacts() -> builds root_files list including CLAUDE.md
  |
  v
execute_sync() -> sync_files() for each category
  |
  v
sync_files(root_files) -> reads global CLAUDE.md, writes to local  <-- OVERWRITES
  |
  v
Extension sections LOST
```

### Extension Load Flow Diagram

```
User: <leader>ac -> select extension "present"
  |
  v
manager.load("present")
  |
  v
process_merge_targets()
  |
  v
merge.inject_section(target_path, content, "extension_present")
  |
  v
Reads local CLAUDE.md, appends <!-- SECTION --> block  <-- CORRECT
```
