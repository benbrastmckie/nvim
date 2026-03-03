# Research Report: Task #120 (Supplemental)

**Task**: 120 - fix_pretooluse_hook_picker_display
**Started**: 2026-03-03T00:00:00Z
**Completed**: 2026-03-03T01:00:00Z
**Effort**: 2-4 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Local source code analysis of picker architecture (13 Lua modules), settings.json hook definitions, shared picker config
**Artifacts**: - specs/120_fix_pretooluse_hook_picker_display/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- The picker architecture has a fundamental design issue: it uses multiple hardcoded descriptions dictionaries and per-type entry creation functions rather than a unified, registry-driven approach, making it fragile when the agent system changes
- The `[Hook Events]` section is the primary offender: it hardcodes event descriptions in TWO separate locations (entries.lua lines 29-38 and previewer.lua lines 320-329), and events appear even when they have zero manageable artifacts
- The recommended path forward is a two-phase approach: (1) immediate fix to filter hook events with no manageable hooks, and (2) a broader refactor to consolidate hardcoded lists into the existing `artifacts/registry.lua` pattern
- Most picker sections (Commands, Skills, Agents, Docs, Lib, Scripts, Tests, Templates, Root Files) are already fully dynamic -- they scan the filesystem and only show what exists
- The `[Hook Events]` section is the only section that derives entries from `settings.json` configuration rather than filesystem scanning, creating the semantic mismatch between "configured events" and "manageable artifacts"

## Context & Scope

This research focuses on the broader question of how the `<leader>ac` (ClaudeCommands) and `<leader>ao` (OpencodeCommands) pickers should determine what items to display, with particular attention to ensuring pickers include exactly the artifacts they need to manage, dynamically updated as the agent systems change.

The existing research-001.md covers the narrow inline-command hook detection bug. This report examines the broader architectural patterns.

## Findings

### 1. Current Picker Architecture Analysis

The picker system is built from these modules:

```
picker.lua (facade)
  |
  v
picker/init.lua (orchestrator - Telescope integration)
  |
  +-- display/entries.lua (entry creation - 11 section builders)
  +-- display/previewer.lua (preview rendering - 14 previewers)
  +-- utils/scan.lua (filesystem scanning)
  +-- utils/helpers.lua (formatting, file ops)
  +-- artifacts/registry.lua (artifact type configurations)
  +-- artifacts/metadata.lua (description extraction)
  +-- operations/sync.lua (Load Core Agent System)
  +-- operations/edit.lua (load/save/edit operations)
  +-- operations/terminal.lua (Claude Code terminal integration)
```

The `shared/picker/config.lua` parameterizes the picker for `.claude` vs `.opencode` directories. The OpenCode variant sets `hooks_subdir = nil` since OpenCode does not use hooks.

### 2. Section-by-Section Dynamic vs Static Analysis

| Section | Entry Source | Dynamic? | Problem? |
|---------|-------------|----------|----------|
| [Commands] | Filesystem scan of `commands/` dir | Fully dynamic | No |
| [Root Files] | Hardcoded list of 4 filenames | Semi-static | Minor |
| [Agents] | Filesystem scan of `agents/` dir | Fully dynamic | No |
| [Skills] | Filesystem scan of `skills/` dir | Fully dynamic | No |
| [Hook Events] | `settings.json` parsing | Config-derived | **Yes** |
| [Tests] | Filesystem scan of `tests/` dir | Fully dynamic | No |
| [Scripts] | Filesystem scan of `scripts/` dir | Fully dynamic | No |
| [Templates] | Filesystem scan of `templates/` dir | Fully dynamic | No |
| [Lib] | Filesystem scan of `lib/` dir | Fully dynamic | No |
| [Docs] | Filesystem scan of `docs/` dir | Fully dynamic | No |
| [Extensions] | Extension manifest scanning | Fully dynamic | No |
| [Load Core] | Special entry (always shown) | Static | No |
| [Help] | Special entry (always shown) | Static | No |

**Key insight**: 10 of 13 sections are already fully dynamic -- they scan the filesystem and only display entries for artifacts that actually exist. The `[Hook Events]` section is the exception because it reads from `settings.json` configuration rather than scanning a directory for manageable files.

### 3. The Hook Events Problem in Detail

The hook events section has a fundamentally different data source than all other sections. Here is the complete data flow:

```
settings.json (or settings.local.json)
    |
    +-- hooks.PreToolUse[].hooks[].command  --> match against *.sh filename
    +-- hooks.PostToolUse[].hooks[].command  --> match against *.sh filename
    +-- hooks.Stop[].hooks[].command         --> match against *.sh filename
    +-- (etc.)
    |
    v
parser.build_hook_dependencies()
    |  Produces: hook_events = { "PreToolUse": [], "PostToolUse": [], "Stop": ["post-command.sh", ...], ... }
    |
    v
entries.create_hooks_entries()
    |  Iterates ALL keys of hook_events, even those with empty hook arrays
    |  Looks up hook objects from structure.hooks by name
    |  Passes to format_hook_event() with hardcoded description map
    |
    v
Picker shows ALL configured events, regardless of whether they have manageable artifacts
```

**Current behavior for settings.json events**:

| Event | Hooks in settings.json | .sh files matched | Appears in picker? | Has manageable content? |
|-------|----------------------|-------------------|---------------------|------------------------|
| Stop | 3 hooks (all .sh refs) | 3 | Yes | Yes (3 .sh files) |
| SessionStart | 2 hooks (2 .sh, 1 external) | 2 | Yes | Yes (2 .sh files) |
| UserPromptSubmit | 2 hooks (all .sh refs) | 2 | Yes | Yes (2 .sh files) |
| SubagentStop | 1 hook (.sh ref) | 1 | Yes | Yes (1 .sh file) |
| Notification | 1 hook (.sh ref) | 1 | Yes | Yes (1 .sh file) |
| **PreToolUse** | 1 hook (inline bash) | 0 | **Yes** | **No** |
| **PostToolUse** | 1 hook (inline bash) | 0 | **Yes** | **No** |

PreToolUse and PostToolUse have hooks configured in settings.json, but those hooks are inline `bash -c '...'` commands, not `.sh` file references. There are no `.sh` files to edit, load, sync, or manage. The picker shows these events but selecting them opens nothing meaningful.

### 4. The "What is Manageable?" Question

The picker exists to **manage artifacts** -- files that can be edited, loaded locally, saved globally, synced, etc. An item should appear in the picker if and only if:

1. **There is an artifact file** that the user can interact with (edit, sync, load locally)
2. **The artifact actually exists** in either the local or global directory
3. **The entry provides a useful action** (Enter opens something, Ctrl-l loads something)

For hook events specifically, the question is: "Does this event have any associated `.sh` hook files that the user can manage?"

If the answer is "no" (as with inline hooks), the event should not appear in the picker, because:
- Pressing Enter does nothing (no hooks to open)
- The previewer shows "Registered Hooks: 0 hook(s)"
- Ctrl-l/Ctrl-u/Ctrl-s/Ctrl-e have nothing to act on
- The event's configuration lives in settings.json, which already has its own entry in [Root Files]

### 5. Hardcoded Lists Inventory

The following hardcoded lists exist in the picker codebase:

**A. Hook event descriptions (entries.lua lines 29-38)**:
```lua
local descriptions = {
  Stop = "After command completion",
  SessionStart = "When session begins",
  SessionEnd = "When session ends",
  SubagentStop = "After subagent completes",
  Notification = "Permission/idle events",
  PreToolUse = "Before tool execution",
  PostToolUse = "After tool execution",
  UserPromptSubmit = "When prompt submitted",
  PreCompact = "Before context compaction",
}
```

**B. Hook event descriptions (previewer.lua lines 320-329)** -- duplicated:
```lua
local event_descriptions = {
  Stop = "Triggered after command completion",
  SessionStart = "When Claude Code session begins",
  SessionEnd = "When Claude Code session ends",
  SubagentStop = "After subagent completes",
  Notification = "Permission or idle notification events",
  PreToolUse = "Before tool execution",
  PostToolUse = "After tool execution",
  UserPromptSubmit = "When user prompt submitted",
  PreCompact = "Before context compaction",
}
```

**C. Root file configuration (parser.lua lines 546-551)**:
```lua
local root_files_config = {
  { name = ".gitignore", description = "Git ignore patterns" },
  { name = "README.md", description = "Documentation" },
  { name = root_config_file, description = base_dir:sub(2) .. " configuration" },
  { name = settings_file, description = "Local settings" },
}
```

**D. Sync operations root file names (sync.lua lines 420-423)**:
```lua
local root_file_names
if base_dir == ".opencode" then
  root_file_names = { "OPENCODE.md", "settings.json", ".gitignore", "README.md", "QUICK-START.md" }
else
  root_file_names = { ".gitignore", "README.md", "CLAUDE.md", "settings.local.json" }
end
```

**E. Artifact type subdir maps (edit.lua, sync.lua)** -- duplicated in 3 places:
- `edit.lua` line 57-66 (save_artifact_to_global)
- `edit.lua` line 130-139 (load_artifact_locally)
- `sync.lua` line 568-581 (update_artifact_from_global)

### 6. Root Files Semi-Static List

The Root Files section uses a hardcoded list of 4 expected filenames rather than scanning the `.claude/` root directory. This means if new root-level files are added to the agent system (e.g., a `CONTEXT.md` or `config.yaml`), they would not appear until the hardcoded list is updated.

However, this is a minor issue because:
- Root files change infrequently
- The list is parameterized by `root_config_file` and `settings_file` from the shared config
- Scanning the root directory would pick up unrelated files

### 7. How Other Sections Stay Dynamic

The dynamic sections (Commands, Skills, Agents, etc.) all follow this pattern:

```
1. Scan local directory: scan.scan_directory(project_dir/base_dir/subdir, "*.ext")
2. Scan global directory: scan.scan_directory(global_dir/base_dir/subdir, "*.ext")
3. Merge: scan.merge_artifacts(local, global)
4. Only create entries if merged result is non-empty
5. Add heading entry only if entries exist
```

This pattern naturally ensures that:
- Empty directories produce no entries (no heading either)
- New files appear automatically
- Removed files disappear automatically
- Local files show `*` prefix, global files show space

### 8. Extensions as a Model for Dynamic Artifact Discovery

The Extensions section demonstrates a good pattern for dynamic artifact management:
- `extensions.list_available()` scans the filesystem for extension manifests
- Each extension declares what it provides (agents, commands, hooks, skills, context)
- The `build_extension_exclusions()` function in sync.lua reads these manifests to filter out extension-owned files from core sync
- The picker dynamically shows only what exists

This "manifest-driven discovery" pattern could be extended to hook events, where the presence of `.sh` files in the hooks directory (and their association with events from settings.json) determines visibility.

## Recommendations

### Immediate Fix (Phase 1 of implementation)

**Filter hook events to only show events with manageable artifacts.**

In `entries.create_hooks_entries()`, after resolving `event_hooks` from the hook name list, skip events where `event_hooks` is empty:

```lua
-- After line 521 (building event_hooks array)
-- Skip events with no manageable hook files
if #event_hooks == 0 then
  goto continue_event
end
-- ... rest of entry creation ...
::continue_event::
```

This is the minimal fix that solves the "phantom entries" problem. Events configured with only inline hooks will not appear because they have no `.sh` files to manage.

### Inline Hook Representation (Phase 2 - from research-001)

For the `*` marker and previewer to work correctly with inline hooks, implement the synthetic hook approach from research-001.md. However, this should be gated on whether the event has ANY manageable content:

- If an event has both .sh hooks AND inline hooks: show it, mark synthetic inline hooks in previewer
- If an event has ONLY inline hooks: do NOT show it (no manageable artifacts)

### Consolidate Hardcoded Descriptions (Phase 3 - optional refactor)

**Move hook event descriptions to a single source of truth.** Options:

**Option A: Extend `artifacts/registry.lua`** with a `HOOK_EVENT_DESCRIPTIONS` table:
```lua
M.HOOK_EVENT_DESCRIPTIONS = {
  Stop = { short = "After command completion", long = "Triggered after command completion" },
  SessionStart = { short = "When session begins", long = "When Claude Code session begins" },
  -- etc.
}
```

Both `entries.lua` and `previewer.lua` would reference `registry.HOOK_EVENT_DESCRIPTIONS[event_name]` instead of maintaining separate copies.

**Option B: Derive descriptions from settings.json** (not recommended):
The settings.json does not contain event descriptions. Claude Code's hook event types are a fixed set defined by the tool, not by the user. So descriptions must be maintained somewhere in the picker code.

**Recommendation**: Option A. Keep the descriptions in registry.lua as the single source. Even though hook event types are defined by Claude Code (not user-configurable), having one canonical place is better than two copies that can drift apart.

### Consolidate Subdir Maps (Phase 3 - optional refactor)

The `subdir_map` tables in `edit.lua` (2 copies) and `sync.lua` (1 copy) duplicate information already present in `registry.ARTIFACT_TYPES[type_name].subdirs`. These could be replaced with:

```lua
local type_config = registry.get_type(artifact_type)
local subdir = type_config and type_config.subdirs and type_config.subdirs[1]
```

This would eliminate the duplicated maps and ensure consistency when new artifact types are added to the registry.

### Summary of Hardcoded Elements and Recommendations

| Hardcoded Element | Location | Priority | Recommendation |
|-------------------|----------|----------|----------------|
| Hook event descriptions | entries.lua + previewer.lua (2 copies) | Medium | Consolidate to registry.lua |
| Root file names | parser.lua + sync.lua (2 copies) | Low | Acceptable (parameterized, rarely changes) |
| Subdir maps | edit.lua (2x) + sync.lua (1x) | Low | Could use registry.ARTIFACT_TYPES |
| Event descriptions for SessionEnd, PreCompact | entries.lua + previewer.lua | Low | These events exist in descriptions but never appear in settings.json -- harmless dead entries |

## Decisions

- **Hook event filtering**: Events with zero manageable hook files should be filtered out of the picker display
- **Description consolidation**: Hook event descriptions should be moved to a single location (registry.lua recommended)
- **Root files**: The semi-static root file list is acceptable and does not need to become fully dynamic
- **Architecture validation**: The rest of the picker sections (10 of 13) are already fully dynamic and require no changes
- **Inline hooks**: Events with ONLY inline hooks should not appear in the picker; events with mixed hooks should appear but mark inline hooks as non-editable

## Risks & Mitigations

- **Risk**: Filtering out events that users expect to see (PreToolUse configured but hidden)
  - **Mitigation**: Users can still see PreToolUse configuration by selecting the settings.json entry under [Root Files]. The picker is for managing artifacts, not viewing configuration.

- **Risk**: Future Claude Code hook events not appearing until descriptions are added
  - **Mitigation**: Events will still appear in the picker from settings.json parsing; they just will not have a description string. The format_hook_event function already handles unknown events with an empty description. If event descriptions are consolidated to registry.lua, new events would show with blank descriptions until updated.

- **Risk**: Registry consolidation breaking existing behavior
  - **Mitigation**: This is a refactor of data location only, not logic. Existing tests in registry_spec.lua provide coverage. The descriptions themselves do not change.

## Context Extension Recommendations

- **Topic**: Picker architecture and dynamic artifact management patterns
- **Gap**: No context file documents the picker's section-by-section data flow or the distinction between filesystem-scanned sections and config-derived sections
- **Recommendation**: Consider adding to `project/neovim/patterns/` a `picker-architecture.md` documenting the entry creation pipeline and how to add new artifact types

## Appendix

### Files Analyzed

| File | Lines | Purpose |
|------|-------|---------|
| `commands/picker.lua` | 21 | Facade delegating to init.lua with Claude config |
| `commands/picker/init.lua` | 284 | Telescope orchestration, keybindings |
| `commands/picker/display/entries.lua` | 802 | 11 section entry builders |
| `commands/picker/display/previewer.lua` | 804 | 14 type-specific previewers |
| `commands/picker/utils/scan.lua` | 206 | Filesystem scanning, merge logic |
| `commands/picker/utils/helpers.lua` | 166 | Formatting, file operations |
| `commands/picker/artifacts/registry.lua` | 279 | Artifact type configurations |
| `commands/picker/artifacts/metadata.lua` | 126 | Description extraction from files |
| `commands/picker/operations/sync.lua` | 649 | Load Core Agent System, update operations |
| `commands/picker/operations/edit.lua` | 231 | Load/save/edit file operations |
| `commands/picker/operations/terminal.lua` | (not read) | Claude Code terminal integration |
| `commands/parser.lua` | 767 | Command/hook/skill/agent parsing |
| `shared/picker/config.lua` | 92 | Parameterized Claude/OpenCode config |

### Search Queries Used

- Local: Glob patterns for `**/*.lua` in picker directories
- Local: Grep for `show_commands_picker`, `leader.ac`, `leader.ao`
- Local: Grep for hook event name strings across picker modules
- Local: Read of settings.json and settings.local.json

### Relationship to research-001.md

This report (research-002) is a supplemental research focusing on the broader architecture. The two reports are complementary:

| Aspect | research-001 | research-002 |
|--------|--------------|--------------|
| Scope | Inline hook detection bug | Broader picker architecture |
| Root cause | Regex only matches .sh files | Hook events derived from config, not filesystem |
| Fix approach | Synthetic hook entries | Filter events + consolidate hardcoded data |
| Implementation phases | Combined A+B approach | Phase 1 (filter) + Phase 2 (inline) + Phase 3 (refactor) |

Both reports should be used together when creating the implementation plan.
