# Research Report: Task #186

**Task**: 186 - filter_extension_artifacts_from_core_sync
**Started**: 2026-03-11T00:00:00Z
**Completed**: 2026-03-11T00:30:00Z
**Effort**: 1-2 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis (scan.lua, sync.lua, manifest.lua, state.lua, loader.lua, init.lua, config.lua, extension manifests)
**Artifacts**: specs/186_filter_extension_artifacts_from_core_sync/reports/research-001.md
**Standards**: report-format.md

## Executive Summary

- Extension artifacts (agents, skills, commands) are symlinked into the global `.claude/` directory but the sync operation does not distinguish them from core artifacts, causing extension-provided files to leak into every synced project
- Symlink detection is the simplest, most reliable filtering mechanism for `.claude/` (all extension artifacts are symlinks)
- For `.opencode/`, the problem does not currently exist (no extension artifacts in global directory)
- A manifest-based blocklist provides the most robust cross-system solution as a fallback or primary approach
- The sync comment "Sources are already clean (no extension artifacts)" in sync.lua is incorrect

## Context & Scope

The "Load Core Agent System" picker action (`sync.lua:load_all_globally()`) syncs artifacts from the global nvim config (`~/.config/nvim/.claude/`) to target projects. The sync scans all subdirectories (agents, skills, commands, rules, etc.) and copies everything it finds. Extension artifacts are symlinked into the global directory when extensions are loaded locally (in the global nvim config). The glob-based scanner follows symlinks, treating them as regular files.

### Problem Scope

**Affected artifact types** (confirmed with symlinks present):
- `agents/` - 9 extension agents out of 13 total (69% are extension artifacts)
- `skills/` - 11 extension skills out of 20 total (55% are extension artifacts)
- `commands/` - 7 extension commands (convert.md, deck.md, lake.md, lean.md, slides.md, table.md, tag.md)

**Not affected** (no extension symlinks present):
- `rules/` - Extension rules stay in extension directories, not symlinked to global
- `scripts/` - No extension symlinks
- `lib/`, `docs/`, `tests/`, `hooks/`, `templates/`, `context/`, `systemd/`, `settings/` - No extension symlinks

**Core agents** (should be synced): general-implementation-agent.md, general-research-agent.md, meta-builder-agent.md, planner-agent.md

**Core skills** (should be synced): skill-fix-it, skill-git-workflow, skill-implementer, skill-meta, skill-orchestrator, skill-planner, skill-refresh, skill-researcher, skill-status-sync

## Findings

### Codebase Patterns

#### 1. Sync Flow Architecture

```
sync.lua:load_all_globally()
  -> scan_all_artifacts(global_dir, project_dir, config)
    -> scan_directory_for_sync() for each artifact type
      -> vim.fn.glob() (follows symlinks)
  -> execute_sync() -> sync_files() -> helpers.read_file/write_file
```

The filtering insertion point is in `scan_all_artifacts()` or `scan_directory_for_sync()`.

#### 2. Extension Loading Creates Symlinks (for .claude/)

When extensions are loaded into the global nvim config via the extension manager, `copy_simple_files()` in `loader.lua` copies files. However, the actual files in the global `.claude/agents/` etc. are symlinks pointing to `../extensions/{ext}/agents/{file}`. This means either:
- The extension loader was changed to use symlinks after the copy code was written, or
- There is a separate mechanism (possibly a shell script or manual setup) that creates symlinks

Regardless of how they got there, the current state is: **all extension artifacts in the global directory are symlinks**.

#### 3. Existing Exclude Pattern Infrastructure

`scan_directory_for_sync()` already accepts an `exclude_patterns` parameter (line 50-51 of scan.lua):
```lua
--- @param exclude_patterns table|nil Optional array of relative path strings to exclude
```
This is currently used only for context files (CONTEXT_EXCLUDE_PATTERNS in sync.lua lines 13-16). The same pattern could be extended to pass a blocklist to other artifact scans.

#### 4. Manifest Provides Structure

All extension manifests have a consistent `provides` field structure:
```json
{
  "provides": {
    "agents": ["agent-name.md"],
    "skills": ["skill-name"],
    "commands": ["command.md"],
    "rules": ["rule.md"],
    "context": ["project/subdir"],
    "scripts": ["script.sh"],
    "hooks": []
  }
}
```

The `manifest.list_extensions(config)` function can aggregate all manifests. Valid categories are defined in `VALID_PROVIDES` in manifest.lua.

#### 5. Extension State Tracking

`state.lua` tracks `installed_files` (relative paths of all files installed by an extension) and `installed_dirs`. However, extensions.json does NOT exist in the global nvim config directory (confirmed - the global config is the source, not a target). State tracking is only for target projects.

#### 6. .opencode/ Is Not Affected

The `.opencode/` global directory contains only core agents (6 files, all regular, no symlinks). Extension agents are not symlinked there. This may be because `.opencode` extensions are loaded differently, or simply because the user has not loaded `.opencode` extensions globally.

### Solution Options Analysis

#### Option A: Symlink Detection (Recommended for .claude/)

**Mechanism**: Filter out files where `vim.fn.resolve(path) ~= path` (symlinks resolve to different paths).

**Pros**:
- Zero-configuration; no manifest parsing needed
- Extremely fast (single stat call per file)
- 100% accurate for current state of the global directory
- No new dependencies or infrastructure

**Cons**:
- Only works for `.claude/` where symlinks are used
- Fragile if symlink convention changes (e.g., if files become copies)
- Does not work for `.opencode/` (though currently not needed)

**Implementation**: Add a `skip_symlinks` parameter to `scan_directory_for_sync()`:
```lua
-- In the loop over all_files:
if skip_symlinks and vim.fn.resolve(global_file) ~= global_file then
  goto continue
end
```

#### Option B: Manifest-Based Blocklist (Recommended as primary or fallback)

**Mechanism**: Aggregate all `provides` entries from all extension manifests, build a set of filenames to exclude, pass to `scan_directory_for_sync()` via `exclude_patterns`.

**Pros**:
- Works for both `.claude/` and `.opencode/`
- Robust against file type changes (symlink vs copy)
- Uses existing infrastructure (`manifest.list_extensions()`, `exclude_patterns` parameter)
- Self-documenting (blocklist derived from manifest data)

**Cons**:
- Requires scanning all manifests at sync time (I/O overhead, though minimal - ~12 JSON files)
- Needs a new utility function to aggregate provides into a blocklist
- Must handle skills differently (directories, not files)

**Implementation**: New function in manifest.lua:
```lua
function M.aggregate_extension_artifacts(config)
  local blocklist = {
    agents = {},   -- {"lean-research-agent.md", ...}
    skills = {},   -- {"skill-lean-research", ...}
    commands = {}, -- {"lake.md", ...}
    rules = {},
    scripts = {},
    hooks = {},
    context = {},
  }
  local extensions = M.list_extensions(config)
  for _, ext in ipairs(extensions) do
    if ext.manifest.provides then
      for category, files in pairs(ext.manifest.provides) do
        if blocklist[category] then
          for _, f in ipairs(files) do
            table.insert(blocklist[category], f)
          end
        end
      end
    end
  end
  return blocklist
end
```

Then in `scan_all_artifacts()`, pass the relevant blocklist entries as `exclude_patterns`.

#### Option C: Extension State-Based Blocklist

**Mechanism**: Read `extensions.json` from the global config directory, extract `installed_files` for all loaded extensions, build blocklist.

**Pros**:
- Tracks exactly what was actually installed (not just what manifests declare)
- Could handle edge cases where installed files differ from manifest

**Cons**:
- `extensions.json` does NOT exist in the global config directory (confirmed)
- Would need to be created/maintained for the global config
- Installed files are recorded as relative paths for target projects, not the global source
- Adds dependency on a state file that may not exist
- **Not viable without additional infrastructure**

#### Option D: Hybrid Approach (Symlink + Manifest Fallback)

**Mechanism**: Use symlink detection as primary filter (fast path), fall back to manifest-based blocklist for non-symlinked files or for `.opencode/`.

**Pros**:
- Best of both worlds: fast + robust
- Handles edge cases where symlinks are broken or mixed with copies

**Cons**:
- More complex implementation
- May over-filter if both mechanisms are active simultaneously

### Recommendations

**Recommended approach: Option B (Manifest-Based Blocklist)** as the primary mechanism.

Rationale:
1. Works uniformly across both `.claude/` and `.opencode/` systems
2. Uses existing infrastructure (`manifest.list_extensions()`, `exclude_patterns`)
3. Does not depend on file system conventions (symlinks)
4. Self-documenting and maintainable
5. Minimal I/O overhead (~12 small JSON files)

**Alternative: Option A (Symlink Detection)** as a simpler first implementation if speed is critical.

### Implementation Architecture

The recommended changes are:

1. **manifest.lua**: Add `aggregate_extension_artifacts(config)` utility function
2. **scan.lua**: No changes needed (already supports `exclude_patterns`)
3. **sync.lua**:
   - Import manifest and config modules
   - Call `aggregate_extension_artifacts()` at start of `scan_all_artifacts()`
   - Pass relevant exclude lists to each `sync_scan()` call
   - Update the comment "Sources are already clean" to reflect the filtering

### Insertion Points (Exact)

**In `sync.lua:scan_all_artifacts()`** (line 161):
```lua
function M.scan_all_artifacts(global_dir, project_dir, config)
  local base_dir = (config and config.base_dir) or ".claude"
  local artifacts = {}

  -- NEW: Build extension artifact blocklist
  local ext_config = require("neotex.plugins.ai.shared.extensions.config")
  local sys_config = base_dir == ".opencode" and ext_config.opencode(global_dir) or ext_config.claude(global_dir)
  local manifest_mod = require("neotex.plugins.ai.shared.extensions.manifest")
  local blocklist = manifest_mod.aggregate_extension_artifacts(sys_config)

  -- Helper to scan with base_dir and blocklist threaded through
  local function sync_scan(subdir, ext, recursive, exclude)
    -- Merge existing excludes with blocklist for this subdir category
    local merged_exclude = exclude or {}
    -- ... add blocklist entries for matching category
    return scan.scan_directory_for_sync(global_dir, project_dir, subdir, ext, recursive, merged_exclude, base_dir)
  end
```

**Category-to-subdir mapping** for blocklist application:
| Manifest category | Sync subdir | Notes |
|---|---|---|
| agents | "agents" (or config.agents_subdir) | Filenames directly |
| skills | "skills" | Directory names, need pattern match |
| commands | "commands" | Filenames directly |
| rules | "rules" | Filenames directly |
| scripts | "scripts" | Filenames directly |
| hooks | "hooks" | Filenames directly |
| context | "context" | Directory prefixes (e.g., "project/neovim") |

## Edge Cases

### 1. Partially Loaded Extension
If an extension manifest declares files in `provides` but the symlinks/files do not exist in the global directory, the blocklist will simply not match anything. No harm done - the exclude pattern just has no effect.

### 2. Core Artifact with Same Name as Extension Artifact
Unlikely given naming conventions (e.g., `lean-research-agent.md` is clearly extension-specific). If it occurred, the manifest-based approach would incorrectly exclude the core artifact. **Mitigation**: Extension manifests should only list files they actually provide. Could add a validation step that cross-checks blocklist against known core artifacts.

### 3. Context Files (Merged via index.json)
Extension context files are stored under `extensions/{ext}/context/` and are NOT symlinked into the global `context/` directory (confirmed - global context/project/ only has hooks, meta, processes, repo). Context is handled via merge targets (index-entries.json merged into index.json). The sync operation copies context files from global directory, but since extension contexts are not there, no filtering is needed for context.

### 4. Rules Filtering
Extension rules (e.g., neovim-lua.md, lean4.md) are NOT symlinked into the global `.claude/rules/` directory. They stay in extension directories. No filtering needed for rules.

### 5. Skills Filtering (Directory-Based)
Skills are directories (e.g., `skills/skill-lean-research/`), not individual files. The `exclude_patterns` mechanism works on relative file paths within the scanned directory. For skills, the exclude pattern would need to match against the directory name prefix. For example, if scanning `skills/skill-lean-research/skill-lean-research.md`, the relative path is `skill-lean-research/skill-lean-research.md` and the exclude pattern `skill-lean-research` would need prefix matching, not exact string matching.

**Solution**: Modify `scan_directory_for_sync` to support prefix-based exclusion, or filter the results in `scan_all_artifacts()` after scanning.

### 6. Commands Synced but No Route
Even if extension commands (e.g., `/lake`, `/lean`) are synced to a project, they would fail at runtime because the extension agents/skills they depend on are not loaded. This is the user-facing symptom of the bug.

## Decisions

- **Option B (Manifest-Based Blocklist)** is the recommended primary approach
- The `aggregate_extension_artifacts()` function should be added to `manifest.lua` (shared module)
- The blocklist should be computed once per `scan_all_artifacts()` call, not per-scan
- Skills filtering requires either prefix matching in `scan_directory_for_sync` or post-scan filtering
- No changes needed for `.opencode/` currently, but the solution should work for both systems

## Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Performance regression from manifest scanning | Low | Low | 12 small JSON files, cached by OS |
| False positive filtering (core artifact matched) | Very Low | High | Cross-validate blocklist against known core artifacts |
| Skill directory filtering complexity | Medium | Medium | Post-scan filtering as simpler alternative |
| Extension manifest format changes | Low | Medium | validate() already enforces schema |
| Symlinks removed in future (breaking Option A) | Medium | N/A | Using Option B, not dependent on symlinks |

## Appendix

### Files Examined
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Directory scanning, exclude_patterns support
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Sync orchestration, scan_all_artifacts
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Manifest parsing, list_extensions
- `lua/neotex/plugins/ai/shared/extensions/state.lua` - Extension state tracking
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - File copy engine
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Extension manager public API
- `lua/neotex/plugins/ai/shared/extensions/config.lua` - Configuration schema
- `.claude/extensions/nvim/manifest.json` - Example manifest
- `.claude/extensions/lean/manifest.json` - Example manifest with scripts
- `.claude/extensions/latex/manifest.json` - Example manifest
- `.opencode/extensions/nvim/manifest.json` - OpenCode manifest for comparison

### Key Measurements
- Total agents in global .claude/: 13 (4 core, 9 extension)
- Total skills in global .claude/: 20 (9 core, 11 extension)
- Total extension commands symlinked: 7
- Total extension manifests to scan: 12 (.claude), 13 (.opencode)
- Extensions with provides.agents: 11 of 12
- Extensions with provides.skills: 11 of 12
