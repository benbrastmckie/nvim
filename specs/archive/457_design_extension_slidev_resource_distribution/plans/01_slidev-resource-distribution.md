# Implementation Plan: Slidev Resource Distribution Strategy

- **Task**: 457 - Design extension-based slidev resource distribution strategy
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/457_design_extension_slidev_resource_distribution/reports/01_team-research.md
- **Artifacts**: plans/01_slidev-resource-distribution.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The present extension references founder's Slidev animations and CSS styles via broken null-path entries in `talk/index.json`, creating silent failures when agents attempt to load shared resources. This plan implements a two-phase fix: (1) replace null paths with cross-extension index entries that reference founder's deployed resources directly, declare the dependency in present's manifest, and normalize category naming; (2) implement dependency enforcement in the extension loader so that loading present auto-loads founder when needed. Definition of done: present's slide agents can discover and load founder's animations/styles through the standard context discovery pipeline, and the loader validates dependency availability.

### Research Integration

Team research (4 teammates) confirmed the shared resource surface is narrow (15 files, ~1,904 tokens across 6 animations and 9 CSS presets). The `dependencies` field exists in every manifest but has no enforcement. The null-path pattern in present's talk/index.json is actively broken. Two distribution patterns exist (founder's seed-copy vs. present's direct-reference) but cross-extension index entries resolve this by referencing deployed paths. Category naming is inconsistent (founder uses singular, present uses plural).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No direct roadmap items. This task addresses extension infrastructure quality (related to "Extension slim standard enforcement" in Phase 1 of ROADMAP.md) and prepares the dependency mechanism for future extension interoperability.

## Goals & Non-Goals

**Goals**:
- Replace null-path entries in present's `talk/index.json` with working path references
- Add cross-extension index entries to present's `index-entries.json` for founder's shared animations and styles
- Declare `"dependencies": ["founder"]` in present's `manifest.json`
- Normalize category names to singular form in present's `talk/index.json`
- Implement dependency validation in the extension loader (`init.lua`)
- Add auto-load or warning behavior when a dependency is missing

**Non-Goals**:
- Extract a `slidev-core` micro-extension (deferred until 3+ consumers exist)
- Modify founder's deck library structure or category names (founder is authoritative)
- Add epidemiology slide support (no current slidev content in epi)
- Implement `load_when.extensions_loaded` conditional context (out of scope)
- Change the seed-copy vs. direct-reference distribution patterns

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Cross-extension paths break if founder directory structure changes | H | L | Reference paths relative to the deployed context root; document path contract |
| Loader dependency enforcement blocks extension loading unexpectedly | M | M | Use warning-only mode by default; add `strict` option for enforcement |
| Index entry duplication if both founder and present declare same resources | M | M | Present entries use `source_extension: "founder"` comment; merge dedup by path |
| Category name normalization breaks existing present slide agents | M | L | Test all slide agent context queries after rename |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix Present Talk Index and Manifest [NOT STARTED]

**Goal**: Replace broken null-path references with working entries and declare the founder dependency.

**Tasks**:
- [ ] Edit `.claude/extensions/present/manifest.json` to set `"dependencies": ["founder"]`
- [ ] Edit `.claude/extensions/present/context/project/present/talk/index.json`:
  - Replace `"animations"` category (plural) with `"animation"` (singular) to match founder
  - Replace `"styles"` category (plural) with `"style"` (singular) to match founder
  - Replace `"path": null` for animations with `"path": "../../founder/deck/animations/"` (relative from talk directory to founder deck)
  - Replace `"path": null` for styles with `"path": "../../founder/deck/styles/"` (relative from talk directory to founder deck)
  - Remove the `"note"` fields that contained prose instructions
  - Add explicit item entries listing the 6 animations and 9 style files from founder
- [ ] Verify the relative paths resolve correctly from present's talk directory to founder's deck directory

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/manifest.json` -- add dependencies
- `.claude/extensions/present/context/project/present/talk/index.json` -- fix null paths, normalize categories

**Verification**:
- `jq '.dependencies' .claude/extensions/present/manifest.json` returns `["founder"]`
- `jq '.categories.animation.path' .claude/extensions/present/context/project/present/talk/index.json` returns a non-null path
- No `null` values remain in path fields of talk/index.json

---

### Phase 2: Add Cross-Extension Index Entries [NOT STARTED]

**Goal**: Make founder's shared animations and styles discoverable through present's index entries so that present's slide agents can load them via the standard context discovery pipeline.

**Tasks**:
- [ ] Add 6 animation index entries to `.claude/extensions/present/index-entries.json`, each pointing to `project/founder/deck/animations/{file}` with `load_when` targeting present's slide agents (`slides-research-agent`, `slidev-assembly-agent`, `slide-planner-agent`, `slide-critic-agent`) and the `/slides` command
- [ ] Add 9 style index entries (4 colors + 3 typography + 2 textures) to `.claude/extensions/present/index-entries.json`, each pointing to `project/founder/deck/styles/{subdir}/{file}` with the same `load_when` configuration
- [ ] Add a comment field or `"source_note"` to each cross-extension entry indicating the resource originates from the founder extension
- [ ] Verify entries use the correct normalized paths that `merge.lua:normalize_index_path()` will handle

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/index-entries.json` -- add 15 cross-extension entries

**Verification**:
- `jq '[.entries[] | select(.path | startswith("project/founder/deck/"))] | length' .claude/extensions/present/index-entries.json` returns 15
- Each new entry has valid `load_when` with present's slide agent names
- No duplicate paths exist between new entries and existing founder index entries (they serve different agent sets)

---

### Phase 3: Implement Loader Dependency Validation [NOT STARTED]

**Goal**: Add dependency checking to the extension loader so it validates (and optionally auto-loads) prerequisite extensions.

**Tasks**:
- [ ] Read `manifest.json` `dependencies` array during extension load in `lua/neotex/plugins/ai/shared/extensions/init.lua`
- [ ] Before processing merge targets, check if each dependency extension is already loaded (check state)
- [ ] If a dependency is not loaded, attempt auto-load: call the load function recursively for the missing dependency
- [ ] If auto-load fails (dependency not found on disk), emit `vim.notify` warning with severity `WARN` listing the missing dependency
- [ ] Add a guard against circular dependencies (track loading stack)
- [ ] Ensure unloading an extension does not unload its dependencies (dependencies may be independently selected)

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` -- add dependency resolution before load
- `lua/neotex/plugins/ai/shared/extensions/state.lua` -- add helper to check if extension is loaded (if not already present)

**Verification**:
- Loading present extension when founder is not loaded triggers auto-load of founder
- Loading present extension when founder is already loaded skips redundant load
- Loading an extension with no dependencies works unchanged
- Circular dependency (if artificially created) does not infinite-loop; produces a warning

---

### Phase 4: Integration Testing and Documentation [NOT STARTED]

**Goal**: Validate the full pipeline end-to-end and document the cross-extension sharing pattern.

**Tasks**:
- [ ] Test: load only present via `<leader>ac` picker -- verify founder is auto-loaded and shared resources appear in context discovery
- [ ] Test: load both founder and present -- verify no duplicate context entries loaded
- [ ] Test: unload present -- verify founder remains loaded if independently selected
- [ ] Test: query `jq` on merged `index.json` for slide agent context -- verify animations and styles from founder are discoverable
- [ ] Update `.claude/extensions/present/README.md` to document the founder dependency and shared resource pattern
- [ ] Add a brief section to `.claude/context/guides/extension-development.md` (or create a new pattern file) documenting cross-extension resource sharing via index entries and the `dependencies` manifest field

**Timing**: 30 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/present/README.md` -- add dependency documentation
- `.claude/context/guides/extension-development.md` -- add cross-extension sharing pattern (or new file if guide is large)

**Verification**:
- All manual test scenarios pass
- README documents the dependency relationship
- Extension development guide includes the cross-extension pattern

## Testing & Validation

- [ ] Present's talk/index.json has no null paths
- [ ] Present's manifest declares `"dependencies": ["founder"]`
- [ ] Cross-extension index entries resolve to existing founder files
- [ ] Extension loader auto-loads founder when present is loaded alone
- [ ] Loader handles missing dependencies gracefully (warning, not crash)
- [ ] Context discovery query for slide agents returns founder animations/styles
- [ ] No regression in existing founder `/deck` or present `/slides` commands
- [ ] Category names in present's talk/index.json use singular form matching founder

## Artifacts & Outputs

- `specs/457_design_extension_slidev_resource_distribution/plans/01_slidev-resource-distribution.md` (this plan)
- Modified: `.claude/extensions/present/manifest.json`
- Modified: `.claude/extensions/present/context/project/present/talk/index.json`
- Modified: `.claude/extensions/present/index-entries.json`
- Modified: `lua/neotex/plugins/ai/shared/extensions/init.lua`
- Modified: `.claude/extensions/present/README.md`
- Modified or new: cross-extension sharing documentation

## Rollback/Contingency

All changes are in version-controlled files. To revert:
1. `git checkout HEAD -- .claude/extensions/present/` restores all present extension files
2. `git checkout HEAD -- lua/neotex/plugins/ai/shared/extensions/init.lua` restores the loader
3. The dependency enforcement in Phase 3 uses warning-only mode, so even partial rollback (reverting only the loader) leaves the system functional -- cross-extension index entries work when both extensions are manually loaded
