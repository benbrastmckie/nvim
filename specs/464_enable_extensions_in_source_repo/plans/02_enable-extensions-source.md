# Implementation Plan: Enable Extensions in Source Repo

- **Task**: 464 - Enable extension loading in global source repository without sync leakage
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: None
- **Research Inputs**: specs/464_enable_extensions_in_source_repo/reports/01_team-research.md, specs/464_enable_extensions_in_source_repo/reports/02_team-research.md
- **Artifacts**: plans/02_enable-extensions-source.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The source repository (~/.config/nvim) cannot currently load extensions due to a self-loading guard that prevents sync contamination. Two rounds of research converged on a two-track approach: (1) fix the three concrete sync leak vectors so extensions can safely load in the source repo, and (2) create a virtual core manifest that formalizes the core-as-dependency relationship and enables a safer allow-list sync model. This plan decomposes the work into five phases across three dependency waves.

### Research Integration

Round 1 identified two real leak vectors (CLAUDE.md section injection, settings.local.json merge keys) plus the `update_artifact_from_global()` blocklist bypass. Round 2 converged on the virtual core manifest approach -- a `"virtual": true` manifest that describes existing core files without moving them, eliminating the bootstrap impossibility and 175+ file migration cost. The dependency resolution infrastructure (circular detection, depth limits, diamond deps) is fully implemented but unused since all 16 extensions have empty dependency arrays.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task is a prerequisite for several Phase 1 and Phase 2 roadmap items:
- **Extension hot-reload** (Phase 2): Requires extensions to load in the source repo for testing
- **Manifest-driven README generation** (Phase 1): Authors need live extension state to verify output
- **Extension slim standard enforcement** (Phase 1): Lint validation easier when extension is loaded
- **CI enforcement of doc-lint** (Phase 1): Needs local load/unload cycle to validate

## Goals & Non-Goals

**Goals**:
- Enable safe extension loading in the source repository (~/.config/nvim)
- Prevent all sync leakage vectors: CLAUDE.md sections, settings.local.json keys, individual file updates
- Create a virtual core manifest that formalizes the core dependency relationship
- Switch sync from blocklist to manifest-driven allow-list for inherently safer filtering

**Non-Goals**:
- Physical file reorganization (moving core files into extensions/core/)
- Version pinning or version constraints for core
- Optional/soft dependency support
- OpenCode parallel system changes (deferred)
- Extension hot-reload implementation

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Strip function removes legitimate content from CLAUDE.md | H | L | Use precise HTML comment markers (`<!-- SECTION: extension_* -->`); test with multiple loaded extensions |
| Allow-list is too restrictive, misses core files during sync | H | M | Phase 4 builds allow-list from actual `provides` entries; verify sync output matches current behavior before switching |
| Virtual core manifest breaks extension loader assumptions | M | L | The `"virtual": true` flag is new -- loader skips file copy for virtual extensions; isolated code path |
| `update_artifact_from_global()` blocklist changes break Ctrl-l updates | M | L | Add blocklist check only for extension-provided files; core files pass through unchanged |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4, 5 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Sync Leak Fixes [COMPLETED]

**Goal**: Close all three identified sync leak vectors so that extension artifacts loaded in the source repo cannot propagate to target repos during sync.

**Tasks**:
- [ ] Add `strip_extension_sections(content)` function to sync.lua that removes all `<!-- SECTION: extension_* -->...<!-- END_SECTION: extension_* -->` blocks from content
- [ ] Call `strip_extension_sections()` on CLAUDE.md content in `sync_files()` when the source file is a config markdown file (lines 258-269 area), stripping source-side sections before the target-side `preserve_sections`/`restore_sections` logic runs
- [ ] Add `strip_extension_settings(content, global_dir)` function that reads extensions.json merged_sections tracking to identify extension-merged keys, and strips them from settings.local.json content before sync
- [ ] Call `strip_extension_settings()` in `sync_files()` for settings.local.json (root_files sync path)
- [ ] Add blocklist filtering to `update_artifact_from_global()` -- call `aggregate_extension_artifacts()` and check the artifact name against the appropriate blocklist category before copying

**Timing**: 2 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Add strip functions, modify sync_files() and update_artifact_from_global()

**Verification**:
- Load an extension (e.g., nvim) in ~/.config/nvim with `force=true`
- Run full sync to a test project; verify CLAUDE.md in target has no `<!-- SECTION: extension_nvim -->` block
- Verify settings.local.json in target has no extension-merged MCP keys
- Verify Ctrl-l individual update of an extension-provided agent is blocked with appropriate message

---

### Phase 2: Virtual Core Manifest [COMPLETED]

**Goal**: Create the `extensions/core/manifest.json` with `"virtual": true` flag that describes the existing core agent system files without moving any of them.

**Tasks**:
- [ ] Create `.claude/extensions/core/` directory
- [ ] Create `.claude/extensions/core/manifest.json` with: name "core", version "1.0.0", `"virtual": true`, empty dependencies, and populated `provides` listing all core agents, skills, commands, rules, context directories, and scripts
- [ ] Enumerate actual core files for each provides category by diffing the full `.claude/` directory contents against all extension manifest `provides` entries
- [ ] Add `"virtual": true` handling to `manager.load()` in init.lua: when loading a virtual extension, skip file copy entirely (just record state), since files are already in place
- [ ] Add `"virtual": true` handling to `manager.unload()`: skip file removal for virtual extensions (prevent removing core files)
- [ ] Hide core extension from the picker UI (it should auto-load, not appear as user-selectable)

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/manifest.json` - New file: virtual core manifest
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Add virtual extension handling in load/unload
- `lua/neotex/plugins/ai/claude/commands/picker/` - Hide virtual extensions from picker display

**Verification**:
- `manifest.list_extensions()` returns core in the list
- `manager.load("core", {project_dir = test_dir})` succeeds without copying any files
- `manager.unload("core", {project_dir = test_dir})` succeeds without deleting any core files
- Core does not appear in the extension picker UI

---

### Phase 3: Relax Self-Loading Guard [COMPLETED]

**Goal**: Replace the hard block on loading extensions in the source repo with a notification, now that sync leak vectors are closed.

**Tasks**:
- [ ] Change the self-loading guard in `manager.load()` (lines 212-219) from returning an error to emitting a `vim.notify` warning at WARN level
- [ ] Remove the `opts.force` bypass since it is no longer needed -- all loads in source repo are safe
- [ ] Remove the force=true warning notification (lines 222-230) since the guard no longer blocks
- [ ] Use the configured `global_source_dir` from scan module instead of hardcoded `vim.fn.expand("~/.config/nvim")` for the comparison

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Modify self-loading guard (lines 212-230)

**Verification**:
- Loading an extension in ~/.config/nvim succeeds without `force=true`
- A WARN-level notification is displayed indicating source repo loading
- The guard uses the configured global source dir, not a hardcoded path

---

### Phase 4: Manifest-Driven Allow-List Sync [COMPLETED]

**Goal**: Switch `scan_all_artifacts()` from the current blocklist approach (exclude extension files) to an allow-list approach (sync only what core's `provides` declares), closing all unprotected category gaps.

**Tasks**:
- [ ] Add `get_core_provides(config)` function to manifest.lua that reads the core manifest and returns its `provides` map
- [ ] Add `build_allow_list(core_provides)` function that converts the core provides into a category-keyed set of allowed filenames
- [ ] Modify `scan_all_artifacts()` to use allow-list filtering when the core manifest exists: for each sync_scan call, pass the allow-list set for that category instead of the blocklist
- [ ] Ensure fallback: if core manifest does not exist or is not virtual, fall back to the existing blocklist behavior for backward compatibility
- [ ] Verify that currently-unprotected categories (docs, lib, tests, templates, systemd) are now covered -- only files listed in core's provides sync out

**Timing**: 1.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Add `get_core_provides()` function
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Modify `scan_all_artifacts()` to use allow-list when available

**Verification**:
- Full sync with core manifest present produces identical file set to current blocklist sync (no regression)
- Adding a test file to `.claude/docs/` that is NOT in core provides: verify it is excluded from sync
- Adding a file to core provides and syncing: verify it appears in target
- Removing core manifest: verify blocklist fallback works

---

### Phase 5: Extension Dependency on Core [COMPLETED]

**Goal**: Add `"dependencies": ["core"]` to all extension manifests so that loading any extension auto-loads core first, formalizing the dependency graph.

**Tasks**:
- [ ] Update all 15 non-core extension manifests to add `"core"` to their `dependencies` array
- [ ] Verify the dependency resolution path: loading nvim extension should trigger core auto-load first (silently, via the existing `confirm=false` dependency path)
- [ ] Verify circular detection still works: core has empty dependencies, so no cycle is possible
- [ ] Verify diamond dependency resolution: loading two extensions that both depend on core should load core once (existing re-read-state handles this)
- [ ] Run `check-extension-docs.sh` to verify no doc-lint regressions from manifest changes

**Timing**: 0.5 hours

**Depends on**: 2, 3

**Files to modify**:
- `.claude/extensions/epidemiology/manifest.json` - Add "core" dependency
- `.claude/extensions/latex/manifest.json` - Add "core" dependency
- `.claude/extensions/nix/manifest.json` - Add "core" dependency
- `.claude/extensions/nvim/manifest.json` - Add "core" dependency
- `.claude/extensions/python/manifest.json` - Add "core" dependency
- `.claude/extensions/typst/manifest.json` - Add "core" dependency
- `.claude/extensions/z3/manifest.json` - Add "core" dependency
- `.claude/extensions/formal/manifest.json` - Add "core" dependency
- `.claude/extensions/lean/manifest.json` - Add "core" dependency
- `.claude/extensions/filetypes/manifest.json` - Add "core" dependency
- `.claude/extensions/web/manifest.json` - Add "core" dependency
- `.claude/extensions/memory/manifest.json` - Add "core" dependency
- `.claude/extensions/slidev/manifest.json` - Add "core" dependency
- `.claude/extensions/present/manifest.json` - Add "core" dependency
- `.claude/extensions/founder/manifest.json` - Add "core" dependency

**Verification**:
- Loading any extension in a fresh project auto-loads core first
- Core appears in extensions.json as loaded after any extension load
- `check-extension-docs.sh` passes
- Loading two extensions: core loaded only once

## Testing & Validation

- [ ] Full sync from source repo (with extensions loaded) to a test project produces clean output with no extension artifacts
- [ ] CLAUDE.md in synced target contains no `<!-- SECTION: extension_* -->` blocks
- [ ] settings.local.json in synced target contains no extension-merged MCP server keys
- [ ] Ctrl-l individual update of extension-provided files is blocked
- [ ] Extension load in source repo works without `force=true`
- [ ] Virtual core extension loads without copying files and unloads without removing files
- [ ] Allow-list sync produces identical results to blocklist sync (no regression)
- [ ] All 15 extension manifests declare core dependency; auto-load works
- [ ] `check-extension-docs.sh` passes with zero errors

## Artifacts & Outputs

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Modified with strip functions, allow-list sync, blocklist in update_artifact_from_global
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Modified with virtual extension handling and relaxed guard
- `lua/neotex/plugins/ai/shared/extensions/manifest.lua` - Modified with get_core_provides()
- `.claude/extensions/core/manifest.json` - New virtual core manifest
- `.claude/extensions/*/manifest.json` (15 files) - Updated with core dependency

## Rollback/Contingency

If implementation causes regressions:
1. **Phase 1 rollback**: Revert strip functions; sync behavior returns to current (leaky but functional)
2. **Phase 2 rollback**: Delete `extensions/core/` directory; no other files were moved
3. **Phase 3 rollback**: Restore the hard guard in init.lua (re-block source loading)
4. **Phase 4 rollback**: Remove allow-list code; blocklist fallback is the default path
5. **Phase 5 rollback**: Remove "core" from all dependency arrays; extensions load independently again

Each phase is independently revertible. The fallback in Phase 4 ensures the system degrades gracefully if the core manifest is absent.
