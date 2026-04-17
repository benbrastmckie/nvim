# Teammate A Findings: Core-as-Extension Architecture
## Task 464 - Round 2 Research

**Focus**: Deep analysis of current extension architecture and design for making the core agent system a "core" extension with dependency support.

**Date**: 2026-04-16

---

## Key Findings

### 1. Complete Load Flow (Current Architecture)

The extension system has a clean, layered architecture across 6 modules:

```
manager.load(extension_name, opts)       [init.lua]
  |
  +-- Lookup extension dir from global_extensions_dir/  [manifest.lua]
  |   └── Read/validate manifest.json
  |
  +-- Read current state (project_dir/.claude/extensions.json) [state.lua]
  |
  +-- Self-loading guard (blocks global_dir == ~/.config/nvim)  [init.lua:214]
  |
  +-- Circular dependency detection (_loading_stack)            [init.lua:251-265]
  +-- Depth limit check (max_depth = 5)                        [init.lua:260-264]
  |
  +-- Resolve dependencies (recursive manager.load() calls)    [init.lua:268-296]
  |   └── Each dep loaded with confirm=false, force=opts.force
  |
  +-- Confirmation dialog (if confirm=true)                    [init.lua:303-355]
  |
  +-- [pcall-wrapped atomic section:]
  |   +-- copy_simple_files: agents, commands, rules           [loader.lua]
  |   +-- copy_skill_dirs: skills/ (recursive)                 [loader.lua]
  |   +-- copy_context_dirs: context/ (recursive)              [loader.lua]
  |   +-- copy_scripts: scripts/                               [loader.lua]
  |   +-- copy_data_dirs: data/ (merge-copy, no overwrites)    [loader.lua]
  |   |
  |   +-- Pre-load cleanup: remove_orphaned_index_entries()    [merge.lua]
  |   +-- Load core-index-entries.json (always)                [init.lua:436-447]
  |   +-- process_merge_targets():                             [init.lua:72-152]
  |       +-- inject_section() -> CLAUDE.md                    [merge.lua]
  |       +-- merge_settings() -> settings.local.json          [merge.lua]
  |       +-- append_index_entries() -> context/index.json     [merge.lua]
  |       +-- merge_opencode_agents() -> opencode.json         [merge.lua]
  |
  +-- On failure: rollback (remove_installed_files, reverse_merge_targets)
  |
  +-- Re-read state (deps may have written their own state entries)
  +-- mark_loaded() + state_mod.write()                        [state.lua]
  +-- verify_extension()                                       [verify.lua]
```

### 2. Complete Unload Flow

```
manager.unload(extension_name, opts)
  |
  +-- Read state; verify extension is loaded
  +-- Check for dependents (warn if other loaded extensions depend on this)
  +-- Confirmation dialog
  |
  +-- reverse_merge_targets():
  |   +-- remove_section() from CLAUDE.md
  |   +-- unmerge_settings() from settings.local.json
  |   +-- remove_index_entries_tracked() from context/index.json
  |   +-- unmerge_opencode_agents() from opencode.json
  |
  +-- Convert relative paths -> absolute
  +-- remove_installed_files() (only files explicitly tracked; data user-files preserved)
  +-- mark_unloaded() + state_mod.write()
```

### 3. Dependency System: Current State

The dependency system is **fully implemented** in init.lua. The key mechanisms:

```lua
-- In manager.load():
local loading_stack = opts._loading_stack or {}
local max_depth = 5

-- Circular detection: search loading_stack for current name
for _, stack_name in ipairs(loading_stack) do
  if stack_name == extension_name then
    return false, "Circular dependency detected: " .. cycle
  end
end

-- Depth limit
if #loading_stack >= max_depth then
  return false, "Dependency depth limit exceeded"
end

-- Resolve declared dependencies
local deps = ext_manifest.dependencies or {}
for _, dep_name in ipairs(deps) do
  state = state_mod.read(project_dir, config)  -- re-read after each dep
  if not state_mod.is_loaded(state, dep_name) then
    manager.load(dep_name, {
      confirm = false,       -- silent
      project_dir = project_dir,
      force = opts.force,
      _loading_stack = child_stack,  -- propagated
    })
  end
end
```

**Current status of `dependencies` field**: All 16 extensions have `"dependencies": []`. The infrastructure is in place but unused. Making extensions declare `"dependencies": ["core"]` would trigger auto-loading with zero code changes to the dependency logic.

### 4. Merge Targets Mechanism

Extensions use `merge_targets` in their manifest to inject content into shared files. Four merge types are supported:

| Type | Key | Mechanism | Reversible? |
|------|-----|-----------|-------------|
| Config markdown | `claudemd` or `opencode_md` | HTML comment markers in CLAUDE.md | Yes (remove_section) |
| Settings | `settings` | Deep-merge JSON, track added keys | Yes (unmerge_settings) |
| Context index | `index` | Append entries, deduplicate by path | Yes (remove_index_entries_tracked) |
| OpenCode agents | `opencode_json` | Add agent keys (no-overwrite) | Yes (unmerge_opencode_agents) |

The `section_id` for CLAUDE.md markers uses the pattern `extension_{name}` (e.g., `extension_nvim`).

### 5. Blocklist Mechanism for Sync Filtering

`manifest.aggregate_extension_artifacts(config)` reads ALL extension manifests (not just loaded ones) and builds a blocklist:

```lua
blocklist = {
  agents   = { ["neovim-research-agent.md"] = true, ... },
  skills   = { ["skill-neovim-research"]    = true, ... },
  commands = { ... },
  rules    = { ... },
  context  = { ... },  -- prefix directories like "project/neovim"
  scripts  = { ... },
  hooks    = { ... },
  data     = { ... },
}
```

This blocklist is applied in `sync.lua:scan_all_artifacts()` during sync. If a "core" extension existed with files in its `provides`, those files would be blocklisted from sync - the opposite of what we want (core files MUST be synced).

### 6. What Constitutes "Core" Today

Files/dirs in `~/.config/nvim/.claude/` that are NOT inside `extensions/`:

**Agents** (8 files):
- `code-reviewer-agent.md`, `general-implementation-agent.md`, `general-research-agent.md`, `meta-builder-agent.md`, `planner-agent.md`, `reviser-agent.md`, `spawn-agent.md`, `README.md`

**Skills** (16 directories):
- `skill-fix-it`, `skill-git-workflow`, `skill-implementer`, `skill-meta`, `skill-orchestrator`, `skill-planner`, `skill-refresh`, `skill-researcher`, `skill-reviser`, `skill-spawn`, `skill-status-sync`, `skill-tag`, `skill-team-implement`, `skill-team-plan`, `skill-team-research`, `skill-todo`

**Commands** (14 files):
- `errors.md`, `fix-it.md`, `implement.md`, `merge.md`, `meta.md`, `plan.md`, `refresh.md`, `research.md`, `review.md`, `revise.md`, `spawn.md`, `tag.md`, `task.md`, `todo.md`

**Rules** (6 files):
- `artifact-formats.md`, `error-handling.md`, `git-workflow.md`, `plan-format-enforcement.md`, `state-management.md`, `workflows.md`

**Scripts** (27 files):
- All files in `scripts/` including `export-to-markdown.sh`, `memory-retrieve.sh`, `validate-*.sh`, etc.

**Context**: 89 entries in `context/index.json`, organized under `architecture/`, `checkpoints/`, `formats/`, `guides/`, `meta/`, `orchestration/`, `patterns/`, `processes/`, `reference/`, `repo/`, `schemas/`, `standards/`, `templates/`, `troubleshooting/`, `workflows/`

**Other**: `hooks/`, `templates/`, `systemd/`, `docs/`, `utils/`

---

## Recommended Approach: "Skinny Core Extension" (Hybrid Model)

### The Core Bootstrap Problem

The fundamental tension: the extension loader lives *outside* the core artifact set (it's Neovim Lua code, not `.claude/` content). The loader reads manifests from `~/.config/nvim/.claude/extensions/`. So if core lives in `extensions/core/`, the loader can find and read it. **There is no circular bootstrap problem for reading the manifest.** The bootstrap problem is different: the loader's *behavior* is to copy files from extension dirs into target project dirs. For a "core" extension, we don't want to copy - core files already exist at the canonical locations.

### Option A: Core as a Declarative Manifest Only (Recommended)

Create `extensions/core/manifest.json` with:
1. **No `provides` section** (or empty provides) - prevents core files from being in the blocklist or copied
2. **Acts as a dependency anchor** - other extensions can `"dependencies": ["core"]`
3. **Has `merge_targets`** for CLAUDE.md content additions specific to the core system

```json
{
  "name": "core",
  "version": "1.0.0",
  "description": "Core agent system infrastructure (base dependency for all extensions)",
  "dependencies": [],
  "provides": {},
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_core"
    }
  }
}
```

**How loading would work**: When user loads "nvim", which has `"dependencies": ["core"]`:
1. Dep resolver finds "core" not loaded → calls `manager.load("core", {confirm: false, ...})`
2. Core manifest has empty `provides` → no files to copy
3. Core `merge_targets` injects its section into CLAUDE.md (core system instructions)
4. State marks "core" as loaded
5. "nvim" proceeds normally

**What "loading core" accomplishes**: The CLAUDE.md gets the core system instructional content (which may already be there via sync, but now it's tracked). The `extensions.json` records core as loaded.

### Option B: Core as a Reference Manifest with `core_paths`

Extend the manifest schema with a new field `"core_paths"` that points to existing files (no copying). This would require code changes to the loader to handle this new type. More complex, deferred to future work.

### Option C: Physical Restructuring (Not Recommended Now)

Move all core files into `extensions/core/{agents,skills,commands,...}/` and have the sync mechanism treat core files specially. This is the full "core-as-extension" vision but requires:
- Migrating 60+ files across agents/skills/commands/rules
- Changing sync.lua to handle core differently from other extensions
- Updating all `@`-reference paths throughout the system
- **Estimated effort: 40-60 hours; risk: high**

The Round 1 team research synthesis already concluded: "Core-as-extension is premature" (Teammates B and D consensus).

---

## Design: What changes are needed for Option A?

### 1. Create `extensions/core/` directory

```
.claude/extensions/core/
├── manifest.json          # See above - empty provides, one merge target
├── EXTENSION.md           # Content to inject into CLAUDE.md: the core system description
└── README.md             # Documentation
```

The `EXTENSION.md` would contain the current `.claude/CLAUDE.md` boilerplate about task management, status markers, etc. (excluding routing tables that are in CLAUDE.md itself).

### 2. Relax the self-loading guard (already identified in Round 1)

In `init.lua:214`:
```lua
-- Current: hard block
if project_dir == global_dir and not opts.force then
  return false, "Cannot load extensions into source directory..."
end

-- New: allow with notification (unless loading core, which should silently work)
if project_dir == global_dir then
  vim.schedule(function()
    vim.notify("Loading extension into source repository. Sync filtering is active.", vim.log.levels.INFO)
  end)
end
```

### 3. Ensure blocklist excludes "core" provides (trivially handled)

Since the core manifest has empty `provides`, `aggregate_extension_artifacts()` produces nothing for core, and the blocklist is unaffected. Core files continue to sync as always.

### 4. All other extensions declare `"dependencies": ["core"]`

No code changes needed - the dependency resolution logic already handles this. The user gets automatic "core" loading when any extension is loaded. This establishes the conceptual hierarchy without restructuring files.

### 5. Handle the "core not loadable into source" paradox

Wait - there's still an issue. If the self-loading guard is relaxed and core is loaded into the source repo, `state_mod.write()` would write `extensions.json` inside `~/.config/nvim/.claude/`. This file is currently NOT synced (not in sync.lua's artifact list). So core's loaded state in the source repo would not leak to target repos. **This is actually safe.**

---

## Dependency Chain Analysis

### Current State
All 16 extension manifests have `"dependencies": []`. Zero declared dependencies.

### Proposed State After Task 464

```
core (no dependencies)
  ^
  |-- memory
  |-- lean
  |-- nvim
  |-- python
  |-- latex
  |-- typst
  |-- nix
  |-- web
  |-- z3
  |-- epi
  |-- formal
  |-- founder
  |-- present
  |-- slidev
  |-- filetypes
  |-- epidemiology
```

With all 16 extensions declaring `"dependencies": ["core"]`, loading any one of them would silently auto-load core first.

### Circular Detection Works Correctly

If core somehow declared a dependency on another extension (it won't), the loading stack would catch it:
```
user loads "nvim"
  loading_stack = [] -> push "nvim" = ["nvim"]
  nvim.dependencies = ["core"]
  calls manager.load("core", {_loading_stack = ["nvim"]})
    loading_stack = ["nvim"] -> push "core" = ["nvim", "core"]
    core.dependencies = []
    no circulars, loads cleanly
```

The `max_depth = 5` limit is more than sufficient for this use case (max depth would be 2 with the proposed design).

### The Unload Scenario

When user unloads "core" while "nvim" is still loaded:
```lua
-- In manager.unload():
local dependents = {}
for _, loaded_name in ipairs(loaded_names) do
  if loaded_ext.manifest.dependencies contains "core" then
    table.insert(dependents, loaded_name)
  end
end
-- Shows warning: "Extension 'core' is required by: nvim, memory, lean, ..."
```

This warning already exists in the unload code. Users would need to unload all extensions before unloading core, or the warning would inform them.

---

## Critical Insight: The Sync Leakage Problem Remains Orthogonal

Even with a "core" extension, the primary issue from Round 1 remains:

1. **Extension sections in CLAUDE.md** leak into synced repos (need `strip_extension_sections()`)
2. **`update_artifact_from_global()` bypasses blocklist** (needs blocklist filtering)
3. **settings.json extension keys** may leak (needs sync-time filtering)

The core extension architecture does NOT solve these problems. They require the targeted fixes identified in Round 1. The core extension is an **organizational and semantic enhancement** - it establishes the hierarchy concept and enables loading in the source repo. The leak protection is a separate implementation layer.

---

## Evidence / Examples

### Current Extension Structure (nvim as reference)
```
.claude/extensions/nvim/
├── manifest.json                    # name, version, provides, merge_targets
├── EXTENSION.md                     # Content injected into CLAUDE.md
├── index-entries.json               # Context entries to merge into index.json
├── agents/
│   ├── neovim-research-agent.md
│   └── neovim-implementation-agent.md
├── skills/
│   ├── skill-neovim-research/
│   └── skill-neovim-implementation/
├── rules/
│   └── neovim-lua.md
└── context/
    └── project/neovim/
```

### Proposed Core Extension Structure (Option A)
```
.claude/extensions/core/
├── manifest.json                    # Empty provides, one merge_target
├── EXTENSION.md                     # Core system instructional content
└── README.md
```

No subdirectories needed since core has no `provides` to copy.

### How the Blocker (Self-Loading Guard) Prevents Current Usage

From `init.lua:212-219`:
```lua
local global_dir = vim.fn.expand("~/.config/nvim")
if project_dir == global_dir and not opts.force then
  return false, "Cannot load extensions into source directory (~/.config/nvim). " ..
    "Extensions loaded here would leak into core sync for all projects. " ..
    "Use opts.force = true to bypass this check (not recommended)."
end
```

This is a single if-check. Removing or relaxing it is a 3-line change.

---

## Confidence Level

**High** - Based on thorough reading of all 6 extension system modules (init.lua, loader.lua, merge.lua, state.lua, manifest.lua, verify.lua) plus sync.lua. All code paths traced directly from source.

**Key uncertainties**:
1. Whether the EXTENSION.md content for a "core" extension adds meaningful value (if core system is already fully described in CLAUDE.md, the section injection would be redundant)
2. Whether `extensions.json` leaking into the source repo's `.claude/` would cause issues if that file were ever inadvertently synced (it's not in the current sync list, but warrants confirmation)

**Recommended validation**: After implementing Option A, verify that:
1. Running sync from source repo does NOT include `extensions.json` in synced files
2. Loaded core's CLAUDE.md section does NOT appear in synced CLAUDE.md to target repos (requires the Round 1 strip_extension_sections() fix)
3. Unloading any extension that depends on core shows the appropriate dependent warning

---

## Summary of Proposed Changes

| Change | Location | Effort | Risk |
|--------|----------|--------|------|
| Create `extensions/core/` | New directory/files | Low (3 files) | None |
| Relax self-loading guard | `init.lua:214-230` | Low (5 lines) | Low |
| Update all 16 extension manifests | Each `manifest.json` | Low (add "core" to deps array) | None |
| Strip extension sections during sync | `sync.lua` (Phase 1 from Round 1) | Medium (30 lines) | Low |
| Blocklist filter `update_artifact_from_global` | `sync.lua` (Phase 1 from Round 1) | Medium (20 lines) | Low |

Total for enabling source repo loading: ~60 lines of code + 3 new files.
