# Research Report: Task #457

**Task**: 457 - Design extension-based slidev resource distribution strategy
**Started**: 2026-04-16T18:00:00Z
**Completed**: 2026-04-16T18:45:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**:
- Codebase: extension loader (`lua/neotex/plugins/ai/shared/extensions/init.lua`)
- Codebase: extension state tracker (`lua/neotex/plugins/ai/shared/extensions/state.lua`)
- Codebase: manifest parser (`lua/neotex/plugins/ai/shared/extensions/manifest.lua`)
- Codebase: picker init (`lua/neotex/plugins/ai/claude/commands/picker/init.lua`)
- Codebase: `manifest.json` files for present, founder, lean, and others
- Codebase: present's `talk/index.json` (null-path entries)
- Codebase: founder's deck animations and styles directories
- Prior research: `specs/457_design_extension_slidev_resource_distribution/reports/01_team-research.md`
- Prior plan: `specs/457_design_extension_slidev_resource_distribution/plans/01_slidev-resource-distribution.md`
- ROADMAP.md (Phase 1 priorities)
**Artifacts**:
- `specs/457_design_extension_slidev_resource_distribution/reports/02_slidev-dependency-research.md` (this file)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The existing plan (01) proposes making present depend directly on founder, fixing null paths and adding cross-extension index entries. This works but creates a tight coupling: present (academic talks) depends on founder (business strategy), which is semantically wrong.
- A better longer-term solution is a `slidev/` micro-extension that holds only the 15 shared slidev resources (6 animations, 9 CSS styles, ~1,904 tokens). Both founder and present would declare `"dependencies": ["slidev"]`.
- The extension loader (`init.lua`) currently has zero dependency awareness. The `manager.load()` function reads the manifest but ignores the `dependencies` field entirely. The picker (`picker/init.lua`) calls `exts.load()` without any dependency resolution.
- Implementing dependency auto-loading requires changes in exactly two locations: (1) the `manager.load()` function in `init.lua` to resolve dependencies before processing merge targets, and (2) the `state.lua` module to expose a helper for checking loaded status during the recursive load.
- Transitive dependency resolution and circular dependency detection are straightforward to implement with a loading-stack pattern. The existing `state_mod.is_loaded()` check provides the base case for recursion.
- The `slidev/` extension approach is cleaner than the plan-01 approach because it eliminates cross-domain coupling and establishes a reusable pattern for future shared resource micro-extensions.

## Context & Scope

This research investigates a longer-term architecture for task 457 that differs from the existing plan. The existing plan (01) treats the problem as "present needs founder's slidev resources" and solves it by making present depend on founder. This research evaluates an alternative: extracting the shared resources into a dedicated `slidev/` micro-extension that both founder and present depend on, plus implementing proper dependency resolution in the extension loader.

The investigation covers: (1) how the extension loader and picker currently work, (2) what the manifest schema looks like, (3) what shared resources exist, (4) how dependency resolution should work, and (5) how this improves on the existing plan.

### Roadmap Alignment

ROADMAP.md Phase 1 includes "Extension slim standard enforcement" which validates extensions against standards. Adding a `dependencies` enforcement mechanism aligns with this quality goal. The dependency system is infrastructure that enables cleaner extension composition.

## Findings

### 1. Extension Loader Architecture

The extension system is cleanly decomposed into five modules:

| Module | File | Responsibility |
|--------|------|----------------|
| `init.lua` | `shared/extensions/init.lua` | Public API: `manager.load()`, `manager.unload()`, `manager.reload()` |
| `manifest.lua` | `shared/extensions/manifest.lua` | Discover and validate `manifest.json` files |
| `state.lua` | `shared/extensions/state.lua` | Read/write `extensions.json` state tracking |
| `loader.lua` | `shared/extensions/loader.lua` | File copying, conflict checking, removal |
| `merge.lua` | `shared/extensions/merge.lua` | Index entry merging, section injection, settings merge |

The `manager.load()` function follows this sequence:
1. Find extension via `manifest_mod.get_extension()`
2. Check if already loaded via `state_mod.is_loaded()`
3. Show confirmation dialog (optional)
4. Copy files (agents, commands, rules, skills, context, scripts, data)
5. Clean stale index entries
6. Reload core index entries
7. Process merge targets (CLAUDE.md section, settings, index entries)
8. Update state and verify

**Key observation**: There is no step between #2 and #3 that reads or processes `dependencies`. The manifest's `dependencies` field is completely ignored during load.

### 2. Picker Extension Toggle

The picker (`picker/init.lua` lines 143-155) handles extensions with a simple toggle:

```lua
elseif selection.value.entry_type == "extension" then
  actions.close(prompt_bufnr)
  local exts = require(extensions_module)
  if ext.status == "active" or ext.status == "update-available" then
    exts.unload(ext.name, { confirm = true })
  else
    exts.load(ext.name, { confirm = true })
  end
```

The picker does not need changes for dependency support -- it calls `exts.load()` which is where dependency resolution should happen. The picker is a thin UI layer; all logic belongs in the manager.

### 3. Manifest Schema Analysis

All 14 extensions follow the same manifest structure:

```json
{
  "name": "string",
  "version": "semver",
  "description": "string",
  "task_type": "string",
  "dependencies": [],
  "provides": { ... },
  "routing": { ... },
  "merge_targets": { ... },
  "mcp_servers": { ... }
}
```

The `dependencies` field is present in every manifest as an empty array. The field was designed in anticipation of this need but never implemented. Required manifest fields per `manifest.lua` are only `name`, `version`, `description` -- `dependencies` is optional.

### 4. Shared Slidev Resources

Confirmed from the filesystem:

**Animations** (6 files in `founder/context/project/founder/deck/animations/`):
- `fade-in.md`, `slide-in-below.md`, `metric-cascade.md`, `rough-marks.md`, `staggered-list.md`, `scale-in-pop.md`

**Styles** (9 files in `founder/context/project/founder/deck/styles/`):
- Colors: `light-blue-corp.css`, `dark-blue-navy.css`, `dark-gold-premium.css`, `light-green-growth.css`
- Typography: `montserrat-inter.css`, `playfair-inter.css`, `inter-only.css`
- Textures: `grid-overlay.css`, `noise-grain.css`

Present's `talk/index.json` has null-path entries for `animations` and `styles` categories with prose notes like `"Reference .claude/extensions/founder/context/project/founder/deck/animations/ directly"`. These are broken -- agents cannot act on null paths.

### 5. Existing Plan (01) vs. Proposed Approach

**Plan 01 approach**: Present declares `"dependencies": ["founder"]`. Cross-extension index entries in present point to founder's deployed paths. Loader gets dependency validation.

**Proposed approach**: Create a `slidev/` micro-extension. Move animations and styles there. Both founder and present declare `"dependencies": ["slidev"]`. Loader gets dependency auto-loading.

| Aspect | Plan 01 | Proposed |
|--------|---------|----------|
| Coupling | present -> founder (cross-domain) | founder -> slidev, present -> slidev (shared base) |
| Semantics | Academic talks depend on business strategy | Both depend on shared slide primitives |
| Future extensions | Must depend on founder or duplicate | Depend on slidev directly |
| Resource location | Stays in founder's context dir | Moves to slidev's context dir |
| Breaking change | None for founder | Founder paths change (animations/styles move) |
| Effort | Lower (no new extension) | Higher (new extension + migration) |

The proposed approach is architecturally superior but requires more work. It also introduces a breaking change: founder's deck agents would need updated paths to animations and styles.

### 6. Dependency Resolution Design

#### 6.1 Manifest Schema Extension

The `dependencies` field already exists as `[]` in all manifests. No schema change needed -- just populate it:

```json
// slidev/manifest.json
{
  "name": "slidev",
  "version": "1.0.0",
  "description": "Shared Slidev presentation primitives (animations, CSS styles)",
  "task_type": null,
  "dependencies": [],
  ...
}

// present/manifest.json
{
  "dependencies": ["slidev"],
  ...
}

// founder/manifest.json
{
  "dependencies": ["slidev"],
  ...
}
```

The `task_type` for slidev should be `null` or omitted -- it is a resource-only extension with no routing or commands of its own.

#### 6.2 Loader Dependency Resolution

The dependency resolution should be inserted into `manager.load()` between the "already loaded" check and the confirmation dialog. Pseudocode:

```lua
-- After checking if already loaded, before confirmation dialog
local deps = ext_manifest.dependencies or {}
if #deps > 0 then
  local loading_stack = opts._loading_stack or {}

  -- Circular dependency check
  for _, dep_name in ipairs(deps) do
    for _, loading_name in ipairs(loading_stack) do
      if dep_name == loading_name then
        return false, "Circular dependency: " .. table.concat(loading_stack, " -> ") .. " -> " .. dep_name
      end
    end
  end

  -- Auto-load missing dependencies
  for _, dep_name in ipairs(deps) do
    if not state_mod.is_loaded(state, dep_name) then
      local dep_stack = vim.list_extend({}, loading_stack)
      table.insert(dep_stack, extension_name)
      local dep_ok, dep_err = manager.load(dep_name, {
        confirm = opts.confirm,
        project_dir = project_dir,
        _loading_stack = dep_stack,
      })
      if not dep_ok then
        return false, "Failed to load dependency '" .. dep_name .. "': " .. (dep_err or "unknown")
      end
    end
  end
end
```

Key design decisions:
- **Loading stack** passed via `opts._loading_stack` (private, underscore-prefixed) for circular detection
- **Recursive loading**: Dependencies load recursively through the same `manager.load()` path
- **Confirmation dialog**: Dependencies trigger their own confirmation dialogs (user sees what is being loaded)
- **Failure propagation**: If a dependency fails, the parent load also fails (before any files are copied)
- **Already-loaded skip**: `state_mod.is_loaded()` prevents redundant loads

#### 6.3 Transitive Dependencies

Transitive dependencies resolve naturally through recursion. If `A -> B -> C`:
1. Load A: discovers dependency B
2. Load B: discovers dependency C
3. Load C: no dependencies, loads normally
4. B continues loading
5. A continues loading

The loading stack `[A, B]` prevents C from depending on A or B (circular).

#### 6.4 Unload Behavior

Unloading should NOT cascade to dependencies. If the user unloads present, slidev should remain loaded because:
- It may be independently useful
- Founder also depends on it
- The user explicitly chose to load it (even if auto-loaded)

The unload path in `manager.unload()` does not need changes.

#### 6.5 Confirmation Dialog Enhancement

When dependencies will be auto-loaded, the confirmation dialog should mention them:

```
Load extension 'present' v1.0.0?

Research presentation support...

Dependencies to load: slidev
Files to install:
  agents: 9
  skills: 7
  ...
```

### 7. The `slidev/` Micro-Extension Structure

```
.claude/extensions/slidev/
  manifest.json
  EXTENSION.md           # Minimal (no CLAUDE.md section needed)
  index-entries.json     # 15 entries for animations + styles
  context/
    project/
      slidev/
        animation/
          fade-in.md
          slide-in-below.md
          metric-cascade.md
          rough-marks.md
          staggered-list.md
          scale-in-pop.md
        style/
          colors/
            light-blue-corp.css
            dark-blue-navy.css
            dark-gold-premium.css
            light-green-growth.css
          typography/
            montserrat-inter.css
            playfair-inter.css
            inter-only.css
          textures/
            grid-overlay.css
            noise-grain.css
```

The manifest would be minimal:

```json
{
  "name": "slidev",
  "version": "1.0.0",
  "description": "Shared Slidev presentation primitives: animations and CSS styles",
  "dependencies": [],
  "provides": {
    "context": ["project/slidev"]
  },
  "merge_targets": {
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  }
}
```

No agents, no skills, no commands, no routing. Pure resource extension.

### 8. Migration Path from Founder

Moving animations and styles from founder to slidev requires:

1. **Copy files** from `founder/context/project/founder/deck/animations/` and `founder/context/project/founder/deck/styles/` to `slidev/context/project/slidev/animation/` and `slidev/context/project/slidev/style/`
2. **Update founder's index-entries.json**: Change paths from `project/founder/deck/animations/...` to `project/slidev/animation/...` (these are loaded via merge, so they point to deployed paths)
3. **Update founder's deck/index.json**: Change animation and style paths to reference the slidev extension's deployed directory
4. **Remove original files** from founder (or keep as duplicates temporarily)
5. **Update present's talk/index.json**: Replace null paths with references to slidev's deployed paths

This is a coordinated change across three extensions. It should be a single implementation phase.

## Decisions

1. **Use `slidev/` (not `slidev-core/`)** as the extension directory name, per the task focus prompt. This is simpler and follows the pattern of other single-word extensions (lean, python, nix, web).

2. **No task_type for slidev** -- it is a resource-only extension. It provides context files but no agents, commands, or routing. It cannot be used as a task type.

3. **Dependency resolution in manager.load(), not picker** -- the picker is a thin UI layer. All dependency logic belongs in the load function where it can also be used by `manager.reload()` and programmatic loading.

4. **Non-cascading unload** -- unloading an extension does not unload its dependencies. Dependencies may be shared by multiple dependents or independently valuable.

5. **Confirmation dialog includes dependencies** -- users should see what additional extensions will be loaded before confirming.

6. **Category naming uses singular form** in slidev: `animation/`, `style/` (matching founder's existing convention per the team research findings).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking founder's deck agents (path changes) | H | H | Update all index entries atomically; test deck command after migration |
| Loading stack overflow from deep dependency chains | L | L | Limit recursion depth to 5; only 2 levels expected in practice |
| Slidev extension loaded when not needed (overhead) | L | M | Extension is resource-only (~1,904 tokens); negligible cost |
| Manifest validation rejects null task_type | M | L | Omit field entirely; it is not in REQUIRED_FIELDS |
| Existing deployed projects have stale paths after update | M | M | Document migration; extension reload handles re-deployment |

## Recommendations

### Recommended Implementation Phases

**Phase 1: Implement dependency resolution in loader** (highest value, enables everything else)
- Add dependency resolution to `manager.load()` in `init.lua`
- Add circular dependency detection with loading stack
- Enhance confirmation dialog to list dependencies
- No new extensions needed; test with manual `"dependencies": ["founder"]` in present

**Phase 2: Create slidev/ micro-extension**
- Create the extension directory structure
- Copy animations and styles from founder
- Create minimal manifest.json and index-entries.json
- Create EXTENSION.md (empty section, no CLAUDE.md injection needed)

**Phase 3: Migrate founder and present to depend on slidev**
- Update `founder/manifest.json`: add `"dependencies": ["slidev"]`
- Update founder's index-entries.json: repoint animation/style paths
- Update founder's deck/index.json: reference slidev paths
- Remove duplicated animation/style files from founder
- Update present's `talk/index.json`: replace null paths with slidev paths
- Update `present/manifest.json`: add `"dependencies": ["slidev"]`

**Phase 4: Integration testing and documentation**
- Test loading present alone (should auto-load slidev)
- Test loading founder alone (should auto-load slidev)
- Test loading both (slidev loaded once, no duplication)
- Update extension development guide with dependency patterns

### Comparison to Plan 01

The existing plan can still be executed as a quick fix (present -> founder dependency, cross-extension index entries). The `slidev/` approach is a superset that should replace plan 01 if the investment is acceptable. The key advantage is eliminating the semantic absurdity of academic talks depending on a business strategy extension just to get CSS animations.

## Context Extension Recommendations

- **Topic**: Extension dependency resolution
- **Gap**: No documentation exists for how the `dependencies` field should be used, or the dependency loading behavior
- **Recommendation**: Add a section to `.claude/context/guides/extension-development.md` documenting the dependency mechanism after implementation

## Appendix

### Files Examined

- `lua/neotex/plugins/ai/shared/extensions/init.lua` (664 lines) - Main extension manager
- `lua/neotex/plugins/ai/shared/extensions/state.lua` (239 lines) - State tracking
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` (263 lines) - Manifest parsing
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` (287 lines) - Extension picker UI
- `lua/neotex/plugins/editor/which-key.lua` - Keymap definitions
- `.claude/extensions/present/manifest.json` - Present manifest
- `.claude/extensions/founder/manifest.json` - Founder manifest
- `.claude/extensions/lean/manifest.json` - Example manifest for comparison
- `.claude/extensions/present/context/project/present/talk/index.json` - Broken null paths
- `specs/457_design_extension_slidev_resource_distribution/plans/01_slidev-resource-distribution.md` - Existing plan
- `specs/457_design_extension_slidev_resource_distribution/reports/01_team-research.md` - Prior team research
- `specs/ROADMAP.md` - Project roadmap

### Key Code Locations for Implementation

| Change | File | Location |
|--------|------|----------|
| Dependency resolution | `shared/extensions/init.lua` | `manager.load()`, after line 244 (state check), before line 250 (conflict check) |
| Confirmation dialog update | `shared/extensions/init.lua` | Lines 252-289 (add dependency info to message) |
| Loading stack option | `shared/extensions/init.lua` | `opts` parameter of `manager.load()` |
| No picker changes needed | `picker/init.lua` | Lines 143-155 unchanged |
| No state module changes needed | `shared/extensions/state.lua` | `is_loaded()` already sufficient |
