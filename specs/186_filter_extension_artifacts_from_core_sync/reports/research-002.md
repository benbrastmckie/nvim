# Research Report: Task #186 (Follow-up)

**Task**: 186 - filter_extension_artifacts_from_core_sync
**Started**: 2026-03-11T00:00:00Z
**Completed**: 2026-03-11T01:00:00Z
**Effort**: 2-4 hours (implementation)
**Dependencies**: None
**Sources/Inputs**: Codebase analysis (sync.lua, loader.lua, manifest.lua, merge.lua, state.lua, init.lua, config.lua, scan.lua, picker.lua, extension manifests), web research on copy-based extension patterns
**Artifacts**: specs/186_filter_extension_artifacts_from_core_sync/reports/research-002.md
**Standards**: report-format.md

## Executive Summary

- The current system uses symlinks in the global directory to expose extension artifacts, but the loader code uses file copies -- the symlinks exist as a side effect of loading extensions *into the global nvim config itself* (which is both source and target)
- A copy-based approach that eliminates ALL symlinks requires restructuring how extensions are activated in the global directory: instead of symlinking extension files into `.claude/agents/`, `.claude/skills/`, etc., the sync operation should read extension manifests and copy files directly from `extensions/{name}/` subdirectories
- The key design insight is: the global `.claude/` core directories (agents/, skills/, commands/) should contain ONLY core artifacts -- extension artifacts live exclusively in `extensions/` and are deployed on-demand via the extension loader
- The existing extension loader (`shared/extensions/loader.lua` + `init.lua`) already implements a complete copy-based deployment system with state tracking, conflict detection, merge targets, and atomic rollback -- it just needs to also be used for the global directory itself
- A unified "agent loader" design combines core sync + extension loading into a single picker flow

## Context & Scope

### Problem Restatement

Research-001 identified that extension artifacts leak into core sync because the global `.claude/` directory contains symlinks from extensions. The previous research recommended manifest-based blocklisting. This follow-up research explores a more fundamental redesign: **eliminate symlinks entirely** and use a purely copy-based architecture for both core system sync and extension deployment.

### Current Architecture (With Symlinks)

```
~/.config/nvim/.claude/
  agents/
    general-research-agent.md          (regular file - core)
    planner-agent.md                   (regular file - core)
    lean-research-agent.md             (symlink -> ../extensions/lean/agents/)
    web-research-agent.md              (symlink -> ../extensions/web/agents/)
  skills/
    skill-researcher/                  (regular dir - core)
    skill-lean-research/               (symlink -> ../extensions/lean/skills/)
  commands/
    research.md                        (regular file - core)
    lake.md                            (symlink -> ../extensions/lean/commands/)
  extensions/
    lean/
      manifest.json
      agents/lean-research-agent.md    (source of truth)
      skills/skill-lean-research/      (source of truth)
      commands/lake.md                 (source of truth)
    nvim/
      manifest.json
      agents/...
```

### Target Architecture (No Symlinks)

```
~/.config/nvim/.claude/
  agents/
    general-research-agent.md          (regular file - core ONLY)
    planner-agent.md                   (regular file - core ONLY)
    meta-builder-agent.md              (regular file - core ONLY)
    general-implementation-agent.md    (regular file - core ONLY)
  skills/
    skill-researcher/                  (regular dir - core ONLY)
    skill-planner/                     (regular dir - core ONLY)
    ...                                (core skills ONLY)
  commands/
    research.md                        (regular file - core ONLY)
    plan.md                            (regular file - core ONLY)
    ...                                (core commands ONLY)
  extensions/
    lean/                              (extension source of truth - unchanged)
    nvim/                              (extension source of truth - unchanged)
```

## Findings

### 1. Why Symlinks Exist in the Global Directory

The extension loader (`shared/extensions/loader.lua`) uses `copy_file()` -- not symlinks. However, when extensions are loaded *into the global nvim config* (i.e., when `project_dir == global_dir`), the `load_all_globally()` check in `sync.lua:288` prevents self-sync but does NOT prevent extension loading.

The symlinks are created by a mechanism outside the Lua code -- likely a manual setup script or a previous version of the loader. The current loader writes regular file copies when loading extensions into target projects.

**Key insight**: The symlinks in the global directory are an artifact, not a feature. Removing them and preventing their recreation solves the core problem.

### 2. Existing Copy Infrastructure (Already Complete)

The copy-based extension deployment system is already fully implemented:

| Component | Location | Purpose |
|-----------|----------|---------|
| `loader.copy_simple_files()` | shared/extensions/loader.lua:90 | Copy agents, commands, rules |
| `loader.copy_skill_dirs()` | shared/extensions/loader.lua:130 | Copy skill directories recursively |
| `loader.copy_context_dirs()` | shared/extensions/loader.lua:181 | Copy context preserving structure |
| `loader.copy_scripts()` | shared/extensions/loader.lua:231 | Copy scripts with permissions |
| `loader.copy_data_dirs()` | shared/extensions/loader.lua:269 | Merge-copy data directories |
| `merge.inject_section()` | shared/extensions/merge.lua:137 | Inject CLAUDE.md sections |
| `merge.merge_settings()` | shared/extensions/merge.lua:266 | Merge settings.json fragments |
| `merge.append_index_entries()` | shared/extensions/merge.lua:362 | Append index.json entries |
| `state.mark_loaded()` | shared/extensions/state.lua | Track installed files for unload |
| `loader.remove_installed_files()` | shared/extensions/loader.lua:398 | Clean removal with empty dir cleanup |
| `loader.check_conflicts()` | shared/extensions/loader.lua:329 | Pre-load conflict detection |
| `verify.verify_extension()` | shared/extensions/verify.lua | Post-load verification |

The entire extension load/unload/reload lifecycle is copy-based with atomic rollback on failure.

### 3. Core Sync Architecture

The `sync.lua:scan_all_artifacts()` function scans the global directory and copies everything. It uses `scan.scan_directory_for_sync()` which follows symlinks (via `vim.fn.glob()`), treating extension symlinks as regular files.

**Current flow**:
```
User triggers "Load Core Agent System" (<leader>ac picker)
  -> sync.load_all_globally()
    -> scan_all_artifacts(global_dir, project_dir)
      -> scan_directory_for_sync() for each artifact type  [scans ALL files including symlinks]
    -> execute_sync()  [copies everything]
```

**Required flow (no symlinks)**:
```
User triggers "Load Core Agent System"
  -> sync.load_all_globally()
    -> scan_all_artifacts(global_dir, project_dir)
      -> scan_directory_for_sync() for each artifact type  [scans only regular files]
    -> execute_sync()  [copies only core artifacts]
```

### 4. Design: Unified Agent Loader

The unified loader combines core sync and extension management into a coherent system with three operations:

#### Operation 1: Load Core System (Clean Sync)

**What it does**: Copies ONLY core artifacts from global `.claude/` to target project.

**How it works**: Two approaches to ensure only core files are copied:

**Approach A: Symlink Filtering (Quick Fix)**
Add a `skip_symlinks` flag to `scan_directory_for_sync()`:
```lua
-- In scan.lua:scan_directory_for_sync()
if skip_symlinks then
  -- vim.fn.resolve() returns the real path; if different from input, it's a symlink
  if vim.fn.resolve(global_file) ~= global_file then
    goto continue
  end
end
```

Pros: Single-line change, zero new dependencies, instant fix.
Cons: Only works while symlinks exist; does not prevent future symlink creation.

**Approach B: Manifest-Based Exclusion (Robust)**
Build an exclusion set from all extension manifests, pass to `scan_directory_for_sync()`:
```lua
-- In sync.lua:scan_all_artifacts()
local ext_blocklist = build_extension_blocklist(global_dir, base_dir)
-- Pass blocklist entries as exclude_patterns per category
```

Pros: Works regardless of file type (symlink, copy, hardlink).
Cons: Requires scanning ~12 manifest files (minimal overhead).

**Approach C: Clean Global Directory (Best Long-Term)**
Remove all symlinks from global `.claude/` directories and prevent their recreation. The global `.claude/agents/`, `.claude/skills/`, `.claude/commands/` would contain ONLY core artifacts.

Pros: Simplest mental model, no filtering logic needed.
Cons: Requires a one-time cleanup and ensuring the extension system never writes to core directories when `project_dir == global_dir`.

**Recommended: Approach C + B as safety net.**

#### Operation 2: Load Extensions (Copy Deployment)

**What it does**: Copies extension artifacts from `extensions/{name}/` to target project's `.claude/`.

**How it works**: Already implemented via `shared/extensions/init.lua:manager.load()`. No changes needed. The extension picker (`extensions/picker.lua`) provides a UI for load/unload/reload.

#### Operation 3: Load All (Core + Selected Extensions)

**What it does**: One-shot setup combining core sync + extension loading.

**How it works**: New picker flow:
1. Sync core artifacts (Operation 1)
2. Present extension picker with multi-select
3. Load selected extensions (Operation 2 per extension)
4. Report combined results

### 5. Clean Global Directory Strategy

To eliminate symlinks from the global directory:

**Step 1: Remove existing symlinks**
```bash
# Find and remove symlinks in core directories
find ~/.config/nvim/.claude/agents/ -type l -delete
find ~/.config/nvim/.claude/skills/ -type l -delete
find ~/.config/nvim/.claude/commands/ -type l -delete
```

**Step 2: Prevent future symlink creation**

The extension loader already uses `copy_file()`, not symlinks. The symlinks must have been created by something else. Possible sources:
- Manual shell commands
- A previous version of the setup
- A git hook or CI script

Add a guard in the extension loader to skip loading when `project_dir == global_dir`:
```lua
-- In shared/extensions/init.lua:manager.load()
if project_dir == global_dir then
  -- Loading extensions into the global directory would pollute core dirs
  -- Extensions are already accessible via extensions/ subdirectory
  return false, "Cannot load extensions into the global source directory"
end
```

This guard mirrors the existing check in `sync.lua:288`:
```lua
if project_dir == global_dir then
  helpers.notify("Already in the global directory", "INFO")
  return 0
end
```

### 6. Index Regeneration for Target Projects

When syncing core + extensions to a target project, `index.json` needs to reflect the deployed artifacts. The current approach:

1. Core sync copies `context/index.json` from global (contains core entries only)
2. Extension load merges entries via `merge.append_index_entries()` per extension

This two-phase approach works correctly with the copy-based system. No changes needed.

However, if the global `index.json` has been contaminated by extension entries (from loading extensions in the global dir), it should be regenerated:

**Index regeneration approach**:
- Read all `index-entries.json` from loaded extensions
- Read core `index.json` (without extension entries)
- Merge extension entries into core index
- Write result to target project

The existing `merge.append_index_entries()` already does this correctly.

### 7. Extension Manifest and Dependency Resolution

Current manifest schema supports dependencies:
```json
{
  "name": "lean",
  "dependencies": [],
  "provides": { ... },
  "merge_targets": { ... }
}
```

All current extensions have `"dependencies": []`. For future use, dependency resolution would:
1. Build a dependency graph from all manifests
2. Topologically sort (Kahn's algorithm, already used in `/meta` command)
3. Load in dependency order

The manifest schema is already extensible enough. No changes needed for dependency resolution infrastructure.

### 8. File Copying Strategies for Maintainability

The existing `loader.lua` copy engine handles:
- File content read/write (via `helpers.read_file/write_file`)
- Directory creation (via `helpers.ensure_directory`)
- Permission preservation for `.sh` files
- Recursive directory scanning
- Merge-copy semantics for data directories (skip existing)

**Improvement opportunities**:

**A. Content hashing for change detection**
Instead of always overwriting, compute SHA256 of source and target. Only copy if different:
```lua
local function file_hash(path)
  local result = vim.fn.system("sha256sum " .. vim.fn.shellescape(path))
  return result:match("^(%S+)")
end
```
This reduces unnecessary writes and makes sync operations idempotent.

**B. Batch operations log**
Track all operations (copy, skip, replace) in a structured log for debugging:
```lua
local ops_log = {
  { action = "copy", source = "...", target = "...", reason = "new" },
  { action = "skip", source = "...", target = "...", reason = "identical" },
  { action = "replace", source = "...", target = "...", reason = "modified" },
}
```

**C. Dry-run mode**
Add `opts.dry_run` parameter to preview operations before executing:
```lua
function manager.load(extension_name, opts)
  opts = opts or {}
  if opts.dry_run then
    return loader.preview_operations(ext_manifest, source_dir, target_dir)
  end
  -- ... actual load
end
```

### 9. Unified Agent Loader Design

The unified loader combines the picker actions into a coherent workflow:

```
                    Unified Agent Loader
                    ====================

    ┌──────────────────────────────────────────────────┐
    │                  Picker Entry                     │
    │                                                  │
    │  [1] Load Core Agent System                      │
    │  [2] Manage Extensions                           │
    │  [3] Load Core + Extensions (Full Setup)         │
    │  [4] Sync Status                                 │
    └──────────────────────────────────────────────────┘
                         │
           ┌─────────────┼─────────────┐
           ▼             ▼             ▼
    ┌──────────┐  ┌──────────┐  ┌──────────────────┐
    │ Core     │  │Extension │  │ Full Setup        │
    │ Sync     │  │ Picker   │  │                   │
    │          │  │          │  │ 1. Core sync      │
    │ Copy     │  │ Load     │  │ 2. Extension      │
    │ from     │  │ Unload   │  │    selection      │
    │ global   │  │ Reload   │  │ 3. Load selected  │
    │ core     │  │ Verify   │  │ 4. Verify all     │
    │ only     │  │          │  │                   │
    └──────────┘  └──────────┘  └──────────────────┘
```

**Implementation**: The picker entry point already exists in `commands/picker/init.lua:94` for "Load All". The extension picker exists in `extensions/picker.lua`. These need to be connected via a unified entry or enhanced picker categories.

### 10. Addressing the Self-Loading Anti-Pattern

The root cause of the symlink problem is loading extensions into the global directory itself. The global directory serves as the **source of truth** for core artifacts. Extensions should not be loaded there because:

1. It contaminates core directories with extension files
2. The sync operation then copies extension files to every project
3. There is no `extensions.json` in the global dir (confirmed), so state tracking is absent
4. The symlinks were created by an unknown mechanism, not the Lua loader

**Solution**: Block extension loading when `project_dir == global_dir`:

```lua
-- In shared/extensions/init.lua:manager.load()
local global_dir = require("neotex.plugins.ai.claude.commands.picker.utils.scan").get_global_dir()
if project_dir == global_dir then
  return false, "Cannot load extensions into source directory (extensions are deployed from here)"
end
```

For the global nvim config itself, extensions are already accessible because the extension manager reads manifests from `extensions/` -- the files do not need to be in `agents/`, `skills/`, or `commands/` for Claude Code to find them when working in the nvim config repo.

## Decisions

1. **Copy-only architecture**: No symlinks anywhere. Extension artifacts live exclusively in `extensions/{name}/` and are deployed via copy.

2. **Clean global directory**: Remove all existing symlinks from global `.claude/agents/`, `.claude/skills/`, `.claude/commands/`. Add guard to prevent loading extensions into global dir.

3. **Manifest-based exclusion as safety net**: Even after cleaning symlinks, add blocklist filtering in `scan_all_artifacts()` to prevent any future contamination.

4. **Preserve existing extension loader**: The `shared/extensions/` infrastructure is already copy-based and well-designed. No structural changes needed.

5. **Unified picker flow**: Combine core sync and extension management into a coherent "Full Setup" option.

6. **Index regeneration**: Use existing `merge.append_index_entries()` approach -- core sync copies base index, extension loading merges entries.

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Removing symlinks breaks nvim config workflows | Low | Medium | Extensions accessible via `extensions/` dir; Claude Code reads manifests directly |
| Guard prevents legitimate self-loading use case | Very Low | Low | Guard includes clear error message; can be overridden with `opts.force` |
| Manifest blocklist misses an artifact | Low | Medium | Combined with clean directory (no symlinks to miss) |
| Core artifact accidentally deleted during cleanup | Low | High | Cleanup script only targets symlinks (`-type l`), not regular files |
| Extension loader behavior changes affect existing projects | Low | Medium | Changes only affect global dir guard; target project loading unchanged |

## Implementation Recommendations

### Phase 1: Clean Global Directory (Quick Win)
1. Remove symlinks from global `.claude/agents/`, `.claude/skills/`, `.claude/commands/`
2. Add self-loading guard to `shared/extensions/init.lua`
3. Verify core sync now only copies core artifacts
4. Test extension loading in a separate project still works

### Phase 2: Manifest-Based Safety Net
1. Add `aggregate_extension_artifacts()` to `shared/extensions/manifest.lua`
2. Add symlink skip flag to `scan_directory_for_sync()` (defense in depth)
3. Apply blocklist in `sync.scan_all_artifacts()`
4. Update sync.lua module comment ("Sources are already clean" is incorrect)

### Phase 3: Unified Loader Enhancement
1. Add "Full Setup" option to picker combining core sync + extension selection
2. Add dry-run mode for preview before deployment
3. Add content hashing for efficient change detection
4. Add sync status reporting

## Appendix

### Files Examined
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Core sync orchestration
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Directory scanning with exclude support
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Extension manager (load/unload/reload)
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - Copy engine with rollback
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Manifest parsing and listing
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Merge strategies (CLAUDE.md, settings, index, opencode)
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - Extension state tracking
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - System configuration schema
- `lua/neotex/plugins/ai/shared/extensions/verify.lua` - Post-load verification
- `lua/neotex/plugins/ai/claude/extensions/picker.lua` - Extension management picker
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Main picker entry point
- `.claude/extensions/lean/manifest.json` - Complex manifest example
- `.claude/extensions/nvim/manifest.json` - Standard manifest example
- `.claude/extensions/filetypes/manifest.json` - Multi-agent manifest example
- `.claude/extensions/web/manifest.json` - Web extension manifest

### Key Measurements
- Core agents: 4 regular files (general-implementation, general-research, meta-builder, planner)
- Extension agent symlinks: 9 (lean:2, filetypes:5, web:2)
- Core skills: 9 regular directories
- Extension skill symlinks: 12 (lean:4, filetypes:4, web:3, nix:0, python:0, etc.)
- Core commands: 11 regular files
- Extension command symlinks: 7 (lean:2, filetypes:4, web:1)
- Total extension manifests: 11

### Web Research References
- [Plugin Architecture Design Pattern](https://www.devleader.ca/2023/09/07/plugin-architecture-design-pattern-a-beginners-guide-to-modularity/)
- [OpenStack Stevedore Plugin Patterns](https://docs.openstack.org/stevedore/latest/user/essays/pycon2013.html)
- [Azure DevOps Extension Manifest](https://learn.microsoft.com/en-us/azure/devops/extend/develop/manifest?view=azure-devops)
- [OCI Image Manifest and Content-Addressable Storage](https://distribution.github.io/distribution/spec/manifest-v2-2/)
