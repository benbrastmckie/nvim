# Implementation Plan: Slidev Extension and Dependency Resolution

- **Task**: 457 - Design extension-based slidev resource distribution strategy
- **Status**: [NOT STARTED]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/457_design_extension_slidev_resource_distribution/reports/02_slidev-dependency-research.md, specs/457_design_extension_slidev_resource_distribution/reports/01_team-research.md
- **Artifacts**: plans/02_slidev-dependency-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The present extension references founder's Slidev animations and CSS styles via broken null-path entries, creating silent failures when agents attempt to load shared resources. Rather than coupling present directly to founder (semantically wrong -- academic talks should not depend on business strategy), this plan creates a `slidev/` micro-extension containing the 15 shared Slidev primitives (6 animations, 9 CSS styles, ~1,904 tokens) and implements dependency auto-loading in the extension loader so both founder and present can declare `"dependencies": ["slidev"]`. Definition of done: loading either founder or present via `<leader>ac` auto-loads the slidev dependency, shared resources are discoverable through standard context discovery, and circular dependency detection prevents loader hangs.

### Research Integration

- **02_slidev-dependency-research.md**: Confirmed the loader (`init.lua`) ignores the `dependencies` field entirely. Identified the exact injection point in `manager.load()` between the "already loaded" check and the confirmation dialog. Provided pseudocode for loading-stack circular detection. Mapped all 15 shared resources and proposed the `slidev/` directory structure.
- **01_team-research.md**: Confirmed the null-path pattern is actively broken (4 teammates). Measured the shared resource surface at 476 lines / ~1,904 tokens. Found that the `dependencies` field exists in all 14 manifests but has zero enforcement. Identified category naming inconsistency (founder: singular, present: plural).

### Prior Plan Reference

Plan 01 proposed making present depend directly on founder and using cross-extension index entries. This was architecturally inferior -- it couples an academic domain (present) to a business domain (founder). Plan 01 estimated 3 hours for 4 phases. This plan supersedes plan 01 with the `slidev/` micro-extension approach, which adds ~2 hours for the new extension creation and resource migration but produces a cleaner architecture. Plan 01's Phase 3 (loader dependency validation) informed this plan's Phase 1 design.

### Roadmap Alignment

- "Extension slim standard enforcement" (Phase 1) -- the dependency resolution mechanism adds structural validation to the extension system, aligning with quality enforcement goals.

## Goals & Non-Goals

**Goals**:
- Create a `slidev/` resource-only micro-extension with 6 animations and 9 CSS style presets
- Implement dependency auto-loading in `manager.load()` using the existing `dependencies` manifest field
- Add circular dependency detection via a loading-stack pattern
- Update founder and present manifests to declare `"dependencies": ["slidev"]`
- Migrate shared resources from founder to slidev and update all path references
- Enhance the confirmation dialog to show dependency information
- Fix present's broken null-path entries in `talk/index.json`

**Non-Goals**:
- Version constraints on dependencies (unnecessary for internal extensions)
- Cascading unload (unloading present should not unload slidev)
- Deep dependency chain support beyond 2 levels (only 1 level needed in practice)
- Changes to the seed-copy vs. direct-reference distribution patterns
- Extracting Vue components (founder-specific, no overlap with present)
- Adding a `load_when.extensions_loaded` conditional context mechanism

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking founder's deck agents after path migration | H | H | Update all index entries and deck/index.json atomically in a single phase; verify with jq queries |
| Circular dependency in loader causes infinite recursion | H | L | Loading stack with depth limit of 5; tested with artificial circular case |
| Confirmation dialog surprise when dependencies auto-load | M | M | Show dependency names in confirmation message before user confirms |
| Manifest validation rejects slidev's null/missing task_type | M | L | Omit task_type entirely; it is not in REQUIRED_FIELDS per manifest.lua |
| Stale deployed paths after extension reload | M | M | Extension reload re-deploys all files; document that reload is needed |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |
| 4 | 5 | 4 |

Phases within the same wave can execute in parallel.

### Phase 1: Implement Dependency Resolution in Extension Loader [NOT STARTED]

**Goal**: Add dependency auto-loading to `manager.load()` so that loading an extension with declared dependencies automatically loads those dependencies first.

**Tasks**:
- [ ] In `lua/neotex/plugins/ai/shared/extensions/init.lua`, locate `manager.load()` (after the `state_mod.is_loaded()` check, before the confirmation dialog)
- [ ] Read the `dependencies` array from the extension manifest (`ext_manifest.dependencies or {}`)
- [ ] For each dependency, check if already loaded via `state_mod.is_loaded()`
- [ ] If not loaded, recursively call `manager.load()` with `opts._loading_stack` for circular detection
- [ ] Implement circular dependency detection: before loading a dependency, check if it appears in the loading stack; if so, return an error message showing the cycle
- [ ] Add a recursion depth limit of 5 (configurable) to prevent runaway chains
- [ ] Propagate dependency load failures: if a dependency fails to load, the parent extension also fails (before copying any files)
- [ ] Update the confirmation dialog (lines 252-289) to include dependency names when dependencies will be auto-loaded (e.g., "Dependencies to load: slidev")
- [ ] Ensure `manager.unload()` does NOT cascade to dependencies (verify current behavior is already correct)

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` -- dependency resolution in `manager.load()`, confirmation dialog enhancement

**Verification**:
- Manually set `"dependencies": ["founder"]` in present's manifest and verify loading present triggers founder auto-load
- Verify loading an extension with empty dependencies works unchanged
- Create a test circular dependency and confirm it produces an error, not a hang
- Verify unloading present does not unload founder

---

### Phase 2: Create the slidev/ Micro-Extension [NOT STARTED]

**Goal**: Create a resource-only extension containing shared Slidev animation patterns and CSS style presets.

**Tasks**:
- [ ] Create directory structure:
  ```
  .claude/extensions/slidev/
    manifest.json
    EXTENSION.md
    index-entries.json
    context/project/slidev/
      animation/
      style/colors/
      style/typography/
      style/textures/
  ```
- [ ] Create `manifest.json` with: name "slidev", version "1.0.0", description, empty dependencies, provides context, merge_targets for index entries. Omit task_type (resource-only).
- [ ] Create `EXTENSION.md` with minimal content (no CLAUDE.md section injection needed since there are no agents, commands, or routing)
- [ ] Copy 6 animation files from `founder/context/project/founder/deck/animations/` to `slidev/context/project/slidev/animation/`:
  - `fade-in.md`, `slide-in-below.md`, `metric-cascade.md`, `rough-marks.md`, `staggered-list.md`, `scale-in-pop.md`
- [ ] Copy 9 CSS files from `founder/context/project/founder/deck/styles/` to `slidev/context/project/slidev/style/`:
  - Colors: `light-blue-corp.css`, `dark-blue-navy.css`, `dark-gold-premium.css`, `light-green-growth.css`
  - Typography: `montserrat-inter.css`, `playfair-inter.css`, `inter-only.css`
  - Textures: `grid-overlay.css`, `noise-grain.css`
- [ ] Create `index-entries.json` with 15 entries (6 animations + 9 styles), tagged with `load_when` for both deck agents (founder) and slide agents (present): `deck-assembly-agent`, `deck-planner-agent`, `slidev-assembly-agent`, `slide-planner-agent`, `slide-critic-agent`
- [ ] Verify manifest passes validation by checking against REQUIRED_FIELDS in `manifest.lua`

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/slidev/manifest.json` -- new file
- `.claude/extensions/slidev/EXTENSION.md` -- new file
- `.claude/extensions/slidev/index-entries.json` -- new file
- `.claude/extensions/slidev/context/project/slidev/animation/*.md` -- 6 new files (copied from founder)
- `.claude/extensions/slidev/context/project/slidev/style/**/*.css` -- 9 new files (copied from founder)

**Verification**:
- `jq '.name' .claude/extensions/slidev/manifest.json` returns "slidev"
- `jq '.entries | length' .claude/extensions/slidev/index-entries.json` returns 15
- All 15 resource files exist and match their founder originals
- Extension appears in the `<leader>ac` picker

---

### Phase 3: Migrate Founder and Present to Depend on slidev [NOT STARTED]

**Goal**: Update both founder and present manifests to declare the slidev dependency, repoint all path references from founder's deck directory to slidev's deployed paths, and fix present's broken null-path entries.

**Tasks**:
- [ ] Update `founder/manifest.json`: set `"dependencies": ["slidev"]`
- [ ] Update `founder/index-entries.json`: change animation/style entry paths from `project/founder/deck/animations/...` to `project/slidev/animation/...` and `project/founder/deck/styles/...` to `project/slidev/style/...`
- [ ] Update founder's `deck/index.json`: repoint animation and style paths to reference slidev's directory structure
- [ ] Remove the original animation and style files from `founder/context/project/founder/deck/animations/` and `founder/context/project/founder/deck/styles/` (now in slidev)
- [ ] Update `present/manifest.json`: set `"dependencies": ["slidev"]`
- [ ] Update present's `talk/index.json`: replace null-path entries with working paths to `project/slidev/animation/` and `project/slidev/style/`, normalize category names to singular form (`animation` not `animations`, `style` not `styles`), remove prose `"note"` fields
- [ ] Update present's `index-entries.json`: add entries pointing to slidev's deployed animation and style paths with `load_when` targeting present's slide agents
- [ ] Verify no remaining null paths in present's talk/index.json

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/founder/manifest.json` -- add dependency
- `.claude/extensions/founder/index-entries.json` -- repoint paths
- `.claude/extensions/founder/context/project/founder/deck/index.json` -- repoint paths
- `.claude/extensions/founder/context/project/founder/deck/animations/` -- remove 6 files
- `.claude/extensions/founder/context/project/founder/deck/styles/` -- remove 9 files (and subdirs)
- `.claude/extensions/present/manifest.json` -- add dependency
- `.claude/extensions/present/context/project/present/talk/index.json` -- fix null paths, normalize categories
- `.claude/extensions/present/index-entries.json` -- add cross-extension entries

**Verification**:
- `jq '.dependencies' .claude/extensions/founder/manifest.json` returns `["slidev"]`
- `jq '.dependencies' .claude/extensions/present/manifest.json` returns `["slidev"]`
- No files remain in `founder/context/project/founder/deck/animations/` or `founder/context/project/founder/deck/styles/`
- No null path values in present's `talk/index.json`
- Category names in present's `talk/index.json` use singular form

---

### Phase 4: Picker Preview and Unload Safety [NOT STARTED]

**Goal**: Enhance the extension picker to show dependency information in the preview panel and prevent unloading extensions that have active dependents.

**Tasks**:
- [ ] In `lua/neotex/plugins/ai/shared/extensions/picker.lua`, add a "Dependencies" line to the preview showing the extension's declared dependencies (read from manifest)
- [ ] Add a "Required by" line showing which loaded extensions depend on this extension (reverse lookup from loaded manifests)
- [ ] In `lua/neotex/plugins/ai/shared/extensions/merge.lua` or `init.lua` (wherever unload is handled), check if any loaded extension depends on the extension being unloaded
- [ ] If dependents exist, show a warning listing them and ask for confirmation (e.g., "Extension 'slidev' is required by: founder, present. Unload anyway?")
- [ ] If user confirms, proceed with unload but do not cascade

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/picker.lua` -- dependency info in preview
- `lua/neotex/plugins/ai/shared/extensions/init.lua` -- unload safety check in `manager.unload()`

**Verification**:
- Preview for "present" shows "Dependencies: slidev"
- Preview for "slidev" shows "Required by: founder, present" (when both are loaded)
- Attempting to unload slidev while founder is loaded shows a warning
- Confirming the warning allows the unload to proceed

---

### Phase 5: Integration Testing and Documentation [NOT STARTED]

**Goal**: Validate the full dependency pipeline end-to-end and document the dependency mechanism for future extension authors.

**Tasks**:
- [ ] Test: load present via `<leader>ac` -- verify slidev is auto-loaded first, shared resources appear in context discovery
- [ ] Test: load founder via `<leader>ac` -- verify slidev is auto-loaded first, deck agents still find animations and styles
- [ ] Test: load both founder and present -- verify slidev is loaded once (no duplication or double-load)
- [ ] Test: unload present, verify slidev and founder remain loaded
- [ ] Test: unload slidev while founder is loaded -- verify warning appears
- [ ] Test: query merged `index.json` for slide/deck agent context entries -- verify both animations and styles are discoverable
- [ ] Update `.claude/extensions/slidev/README.md` (create) documenting the extension purpose and resource catalog
- [ ] Add a "Dependencies" section to the extension development guide (`.claude/context/guides/extension-development.md` or a new pattern file) documenting: how to declare dependencies, auto-loading behavior, circular detection, unload safety

**Timing**: 30 minutes

**Depends on**: 4

**Files to modify**:
- `.claude/extensions/slidev/README.md` -- new file documenting the extension
- `.claude/context/guides/extension-development.md` -- add dependency documentation section (or new file if guide is too large)

**Verification**:
- All 6 test scenarios pass
- README.md exists for slidev extension
- Extension development guide documents the dependency mechanism

## Testing & Validation

- [ ] Loading present alone auto-loads slidev
- [ ] Loading founder alone auto-loads slidev
- [ ] Loading both extensions loads slidev only once
- [ ] Circular dependency detection produces error message, not infinite loop
- [ ] Present's talk/index.json has zero null-path entries
- [ ] Founder's deck agents can discover animations and styles through slidev paths
- [ ] Present's slide agents can discover animations and styles through slidev paths
- [ ] Unloading an extension does not cascade to its dependencies
- [ ] Unloading a dependency shows warning listing active dependents
- [ ] Extension picker preview shows dependency information
- [ ] No regression in existing `/deck` or `/slides` commands
- [ ] Category names in present's talk/index.json use singular form matching founder

## Artifacts & Outputs

- `specs/457_design_extension_slidev_resource_distribution/plans/02_slidev-dependency-plan.md` (this plan)
- New: `.claude/extensions/slidev/` micro-extension (manifest, EXTENSION.md, index-entries, 15 resource files)
- Modified: `lua/neotex/plugins/ai/shared/extensions/init.lua` (dependency resolution, unload safety)
- Modified: `lua/neotex/plugins/ai/shared/extensions/picker.lua` (preview enhancements)
- Modified: `.claude/extensions/founder/manifest.json`, `index-entries.json`, `deck/index.json`
- Modified: `.claude/extensions/present/manifest.json`, `index-entries.json`, `talk/index.json`
- Removed: `.claude/extensions/founder/context/project/founder/deck/animations/` (6 files, moved to slidev)
- Removed: `.claude/extensions/founder/context/project/founder/deck/styles/` (9 files, moved to slidev)
- New: `.claude/extensions/slidev/README.md`
- Updated: Extension development guide with dependency documentation

## Rollback/Contingency

All changes are in version-controlled files. To revert:
1. `git checkout HEAD -- .claude/extensions/founder/` restores founder's original animations and styles
2. `git checkout HEAD -- .claude/extensions/present/` restores present's original manifest and index
3. `git checkout HEAD -- lua/neotex/plugins/ai/shared/extensions/` restores the loader
4. Delete `.claude/extensions/slidev/` entirely (new extension, no prior state)

The dependency resolution in Phase 1 is backward-compatible: extensions with empty `"dependencies": []` are unaffected. Partial rollback (reverting only Phase 3 resource migration while keeping Phase 1 loader changes) is safe since the loader simply skips empty dependency arrays.
