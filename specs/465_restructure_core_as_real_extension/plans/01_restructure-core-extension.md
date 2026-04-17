# Implementation Plan: Restructure Core Agent System as Real Extension

- **Task**: 465 - Restructure core agent system as a real extension
- **Status**: [NOT STARTED]
- **Effort**: 8 hours
- **Dependencies**: Task 464 (manifest-driven allow-list sync) completed
- **Research Inputs**: reports/01_team-research.md
- **Artifacts**: plans/01_restructure-core-extension.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Restructure the core agent system from a virtual extension (manifest-only descriptor with `"virtual": true`) into a real, physical extension at `.claude/extensions/core/`. This involves moving ~208 files (agents, commands, rules, skills, scripts, hooks, context, docs, templates) from their current locations in `.claude/` into `.claude/extensions/core/`, adding missing loader capabilities (hooks copy), fixing guards that depend on the virtual flag, updating the sync system to source core files from the extension directory, and implementing CLAUDE.md as a computed artifact. Done when: the core extension loads and unloads like any other extension, sync sources files from `extensions/core/`, and CLAUDE.md is generated from loaded extensions.

### Research Integration

Team research (4 teammates) confirmed: (1) no bootstrap problem exists between the Lua loader and agent system, (2) the virtual flag was transitional, (3) hooks copy support is missing from the loader, (4) `get_core_provides()` guard breaks without virtual flag, (5) sync system needs to read from `extensions/core/` after migration, (6) CLAUDE.md should become a computed artifact, (7) `utils/` directory is an orphan needing manifest inclusion.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No specific ROADMAP.md items are advanced by this meta task. This is infrastructure work that improves the extension system uniformity.

## Goals & Non-Goals

**Goals**:
- Physically migrate all core agent system files into `.claude/extensions/core/`
- Eliminate the `"virtual": true` flag and all virtual-specific code paths
- Add hooks copy support to the extension loader
- Update sync to source core from `extensions/core/` instead of `.claude/` root
- Implement CLAUDE.md as a fully generated/computed artifact
- Ensure existing repos can migrate cleanly

**Non-Goals**:
- Converting `core-index-entries.json` from a static fixture (follow-up task)
- Refactoring the extension loader beyond what is needed for core migration
- Changing the extension picker UI or workflow
- Supporting partial core loading or core sub-modules

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Sync system regression -- files stop syncing to target repos | H | M | Test sync in a scratch repo before and after migration; keep git history for rollback |
| Self-loading guard -- loading core in source repo creates duplicate files | H | L | Guard already relaxed (WARN only); verify sync-leak protection remains active |
| CLAUDE.md generation misses sections from existing extensions | M | M | Diff generated output against current CLAUDE.md; test with multiple extensions loaded |
| hooks copy breaks shell permissions | M | L | Model on existing `copy_scripts` pattern which already handles permissions |
| Existing repos with core files but no extensions.json entry break | M | M | Smart conflict detection; document migration path |
| git mv of ~208 files creates large, hard-to-review commit | L | H | Split migration into category-by-category commits within one phase |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Loader Foundation -- Hooks Copy and Guard Fixes [COMPLETED]

**Goal**: Add missing hooks copy support to the loader and fix the `get_core_provides()` guard so it works without the virtual flag.

**Tasks**:
- [ ] Add `copy_hooks()` function to `lua/neotex/plugins/ai/shared/extensions/loader.lua`, modeled on `copy_scripts` (flat `.sh` files, preserve execute permissions)
- [ ] Add `copy_hooks` call in `lua/neotex/plugins/ai/shared/extensions/init.lua` load function, between scripts and data copy steps
- [ ] Fix `get_core_provides()` in `lua/neotex/plugins/ai/shared/extensions/manifest.lua` -- change guard from checking `not core.manifest.virtual` to checking whether `core.manifest.provides` exists
- [ ] Add `utils` to manifest.json `VALID_PROVIDES` if needed, or decide to migrate `utils/team-wave-helpers.md` into `context/` (preferred: move to `context/reference/team-wave-helpers.md`)
- [ ] Add `docs` and `templates` to manifest.json provides categories in `VALID_PROVIDES` array in manifest.lua
- [ ] Add `copy_docs` and `copy_templates` functions to loader.lua (or reuse `copy_simple_files` with appropriate category names)
- [ ] Update `check_conflicts()` in loader.lua to include hooks, docs, and templates categories
- [ ] Test hooks copy with a non-core extension that has hooks (manual verification)

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/loader.lua` - Add copy_hooks, extend check_conflicts
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Fix get_core_provides guard, add VALID_PROVIDES entries
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Add copy_hooks call in load function

**Verification**:
- `get_core_provides()` returns provides map when `virtual` flag is absent but `provides` exists
- Hooks copy function exists and handles `.sh` files with execute permissions
- `VALID_PROVIDES` includes `hooks`, `docs`, `templates`

---

### Phase 2: Physical File Migration [NOT STARTED]

**Goal**: Move all ~208 core files from `.claude/` root directories into `.claude/extensions/core/` using `git mv` to preserve history.

**Tasks**:
- [ ] Create the target directory structure under `.claude/extensions/core/`: `agents/`, `commands/`, `rules/`, `skills/`, `scripts/`, `hooks/`, `context/`, `docs/`, `templates/`
- [ ] `git mv` agents: `.claude/agents/*.md` to `.claude/extensions/core/agents/`
- [ ] `git mv` commands: `.claude/commands/*.md` to `.claude/extensions/core/commands/`
- [ ] `git mv` rules: `.claude/rules/*.md` to `.claude/extensions/core/rules/`
- [ ] `git mv` skills: `.claude/skills/skill-*` directories to `.claude/extensions/core/skills/`
- [ ] `git mv` scripts: `.claude/scripts/*.sh` (and subdirs like `lint/`) to `.claude/extensions/core/scripts/`
- [ ] `git mv` hooks: `.claude/hooks/*.sh` to `.claude/extensions/core/hooks/`
- [ ] `git mv` context: `.claude/context/` subdirectories listed in manifest provides to `.claude/extensions/core/context/`
- [ ] `git mv` docs: `.claude/docs/` to `.claude/extensions/core/docs/`
- [ ] `git mv` templates: `.claude/templates/` to `.claude/extensions/core/templates/`
- [ ] Move `.claude/utils/team-wave-helpers.md` to `.claude/extensions/core/context/reference/team-wave-helpers.md` and update references in team skills
- [ ] Update `manifest.json`: add `docs` and `templates` to provides, add `utils` content path or reference path, remove any files that should not be in provides
- [ ] Create `EXTENSION.md` for core extension (~60 lines): name, purpose, provides summary, usage notes
- [ ] Verify all files are accounted for: compare file count before/after migration

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- All files under `.claude/agents/`, `.claude/commands/`, `.claude/rules/`, `.claude/skills/`, `.claude/scripts/`, `.claude/hooks/`, `.claude/context/`, `.claude/docs/`, `.claude/templates/` (moved, not modified)
- `.claude/extensions/core/manifest.json` - Update provides, add docs/templates
- `.claude/extensions/core/EXTENSION.md` - New file
- `.claude/utils/team-wave-helpers.md` - Moved to context/reference/
- Team skill files referencing utils path - Update paths

**Verification**:
- File count in `.claude/extensions/core/` matches expected ~208
- `git status` shows renames, not deletes+adds
- No broken symlinks or dangling references in manifest provides

---

### Phase 3: Manifest and Virtual Flag Removal [NOT STARTED]

**Goal**: Update the core manifest to remove `"virtual": true` and add `merge_targets` for CLAUDE.md generation. Remove virtual fast-path code from the loader.

**Tasks**:
- [ ] Update `.claude/extensions/core/manifest.json`: remove `"virtual": true`, add `merge_targets.claudemd` with source/target/section_id fields
- [ ] Remove virtual fast-path in `lua/neotex/plugins/ai/shared/extensions/init.lua` load function (lines around `if ext_manifest.virtual then`)
- [ ] Remove virtual fast-path in `lua/neotex/plugins/ai/shared/extensions/init.lua` unload function (lines around `if extension and extension.manifest and extension.manifest.virtual then`)
- [ ] Add unload protection: in the unload function, block unloading core when other extensions with `dependencies: ["core"]` are loaded (extend the existing dependents check to be a hard block for core, not just a warning)
- [ ] Update picker display to show core as a real extension (it may already work; verify)
- [ ] Clean up any remaining `virtual` references in comments or documentation

**Timing**: 1.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/core/manifest.json` - Remove virtual, add merge_targets
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Remove virtual fast-paths, add unload protection
- `lua/neotex/plugins/ai/shared/extensions/picker.lua` - Verify core display (may need no changes)

**Verification**:
- `manifest.json` has no `virtual` field
- Loading core extension copies files (no virtual short-circuit)
- Unloading core is blocked when dependents are loaded
- `grep -r "virtual" lua/neotex/plugins/ai/shared/extensions/` returns zero meaningful hits

---

### Phase 4: Sync System Update [NOT STARTED]

**Goal**: Update `scan_all_artifacts()` in sync.lua to source core files from `.claude/extensions/core/` instead of `.claude/` root directories.

**Tasks**:
- [ ] In `sync.lua:scan_all_artifacts()`, update the scanning logic: when sourcing from the global directory, scan paths like `{global_dir}/.claude/extensions/core/{category}/` instead of `{global_dir}/.claude/{category}/`
- [ ] Verify the allow-list filtering still works correctly with the new source paths
- [ ] Update the `sync_scan` helper to handle the new path structure for core categories
- [ ] Ensure non-core categories (root files, settings) still sync from their current locations
- [ ] Test that `load_all_globally()` correctly syncs core files from the extension directory
- [ ] Verify `.syncprotect` mechanism still works with new paths
- [ ] Update any hardcoded path references in sync-related scan utilities
- [ ] Test sync in both directions: global-to-project and verify file integrity

**Timing**: 1.5 hours

**Depends on**: 2

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Update scan paths for core categories (~15 category scan calls in lines 766-870)
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - May need path adjustments

**Verification**:
- `scan_all_artifacts()` returns the same file list (by name) as before migration
- Sync to a fresh project directory produces correct `.claude/` structure
- Allow-list and blocklist filtering produce correct results

---

### Phase 5: Computed CLAUDE.md Generation [NOT STARTED]

**Goal**: Implement CLAUDE.md as a fully generated artifact composed from loaded extensions, replacing the section-injection approach.

**Tasks**:
- [ ] Create a CLAUDE.md header/shell template in `.claude/extensions/core/templates/claudemd-header.md` containing only the static preamble (project name, basic structure)
- [ ] Implement `generate_claudemd()` function in `lua/neotex/plugins/ai/shared/extensions/merge.lua` that:
  - Starts from the header template
  - Iterates loaded extensions in dependency order
  - Appends each extension's `merge_targets.claudemd.source` content
  - Writes the result to `.claude/CLAUDE.md`
- [ ] Create core's CLAUDE.md source fragment (the current `.claude/CLAUDE.md` content, minus any extension-injected sections)
- [ ] Wire `generate_claudemd()` into the load/unload lifecycle so CLAUDE.md is regenerated after any extension state change
- [ ] Update existing extensions' `merge_targets.claudemd` to use the new computed model (they already have source files; verify compatibility)
- [ ] Remove section-injection code from merge.lua (`inject_section`, `remove_section`) or keep as deprecated fallback
- [ ] Test with multiple extensions loaded: verify CLAUDE.md contains all sections in correct order
- [ ] Test with extension unload: verify CLAUDE.md is regenerated without the unloaded extension's section

**Timing**: 1.5 hours

**Depends on**: 4

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Add generate_claudemd function
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Wire generation into load/unload lifecycle
- `.claude/extensions/core/templates/claudemd-header.md` - New template file
- `.claude/extensions/core/merge-sources/claudemd.md` - Core CLAUDE.md content as source fragment

**Verification**:
- Generated CLAUDE.md matches expected content for various extension combinations
- Loading/unloading extensions updates CLAUDE.md deterministically
- No section markers (`<!-- SECTION: -->`) in generated output
- Diff between generated and current CLAUDE.md shows only expected structural changes

---

### Phase 6: Migration Support and Cleanup [NOT STARTED]

**Goal**: Handle existing repos that have core files in `.claude/` but no `extensions.json` entry, and clean up any remaining artifacts from the virtual approach.

**Tasks**:
- [ ] Create a migration detection function: check if `.claude/agents/` exists with core files but `extensions.json` does not list core as loaded
- [ ] Implement migration behavior in the load function: when loading core into a repo that already has core files, detect conflicts and offer to replace (or skip existing files)
- [ ] Update the sync operation: when syncing to a repo with old-style core files, migrate them to the extension-managed pattern
- [ ] Remove `core-index-entries.json` loading code from init.lua if it becomes unnecessary (or keep as static fixture per research recommendation)
- [ ] Clean up any remaining virtual-related code, comments, or documentation
- [ ] Update `.claude/extensions/core/manifest.json` provides arrays to final state
- [ ] Update `.claude/README.md` or project documentation to reflect the new architecture
- [ ] Run end-to-end test: fresh repo, load core, load additional extension, sync, verify

**Timing**: 1 hour

**Depends on**: 5

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Migration detection in load
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Migration path in sync
- `.claude/extensions/core/manifest.json` - Final provides state
- `.claude/README.md` - Documentation update (if exists in extension)

**Verification**:
- Fresh repo: `load core` -> all 208 files appear in `.claude/`
- Existing repo with old-style files: `load core` -> files are managed correctly, no duplicates
- Full sync from global to fresh project produces working agent system
- All extensions that depend on core still load correctly

## Testing & Validation

- [ ] Verify file count: `extensions/core/` contains ~208 files matching manifest provides
- [ ] Load core in fresh repo: all expected files appear in `.claude/` directories
- [ ] Unload core (no dependents): all loader-managed files are removed
- [ ] Unload core (with dependents): operation is blocked with clear error
- [ ] Sync to fresh project: produces identical working `.claude/` structure
- [ ] CLAUDE.md generation: matches expected output with 0, 1, and 3 extensions loaded
- [ ] Hooks copy: `.sh` files have execute permissions after load
- [ ] `get_core_provides()` returns correct map without virtual flag
- [ ] Existing repos with old-style core files: migration works without data loss
- [ ] All existing extensions still load/unload correctly after core restructure

## Artifacts & Outputs

- `specs/465_restructure_core_as_real_extension/plans/01_restructure-core-extension.md` (this file)
- `specs/465_restructure_core_as_real_extension/summaries/01_restructure-core-extension-summary.md` (after implementation)
- `.claude/extensions/core/` - Complete physical extension with all files
- `.claude/extensions/core/EXTENSION.md` - Extension documentation
- `.claude/extensions/core/manifest.json` - Updated manifest without virtual flag
- Updated Lua modules: loader.lua, init.lua, manifest.lua, merge.lua, sync.lua

## Rollback/Contingency

- All file moves use `git mv` preserving full history; `git revert` of the migration commit restores original structure
- Virtual fast-path removal is isolated to two code blocks in init.lua; reverting those changes restores virtual behavior
- CLAUDE.md generation can be bypassed by restoring the static CLAUDE.md file from git history
- If sync breaks in production repos, users can manually run the old sync path by reverting the sync.lua changes
- The `core-index-entries.json` static fixture is kept as a fallback throughout the migration
