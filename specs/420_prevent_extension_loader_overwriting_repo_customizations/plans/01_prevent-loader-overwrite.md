# Implementation Plan: Prevent Extension Loader Overwriting Repo Customizations

- **Task**: 420 - Prevent extension loader sync from overwriting repo-specific CLAUDE.md customizations
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/420_prevent_extension_loader_overwriting_repo_customizations/reports/01_extension-loader-sync.md
- **Artifacts**: plans/01_prevent-loader-overwrite.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The core sync operation (`sync.load_all_globally()`) performs a full-file overwrite of `.claude/CLAUDE.md` when syncing from the global source, destroying extension-injected sections and any repo-specific customizations. The fix applies a two-layer defense: (1) make `sync_files()` section-aware for CLAUDE.md so it preserves `<!-- SECTION -->` markers during overwrite, and (2) add a post-sync re-injection step that re-runs `process_merge_targets()` for all loaded extensions, providing defense-in-depth for all merge targets (CLAUDE.md, settings.json, index.json).

### Research Integration

Research report `01_extension-loader-sync.md` identified two independent mechanisms causing content loss. The recommended solution combines Approach 1 (section-aware sync) with Approach 4 (post-sync extension re-injection). The extension merge system (`merge.inject_section`) is well-designed and idempotent, so re-injection is safe. The implementation leverages existing `state.lua` and `manifest.lua` APIs to enumerate loaded extensions.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances **Agent System Quality** in Phase 1 of the roadmap. While not explicitly listed, it directly improves the reliability of the extension loader system, which underpins extension hot-reload and other Phase 2 items.

## Goals & Non-Goals

**Goals**:
- Preserve extension-injected `<!-- SECTION -->` blocks in CLAUDE.md during core sync
- Re-inject all merge targets (CLAUDE.md, settings.json, index.json) for loaded extensions after sync
- Handle edge cases: no extensions loaded, malformed markers, first-time sync (no local file)
- Work identically for both `.claude` and `.opencode` base_dir configurations

**Non-Goals**:
- Preserving arbitrary manual edits to CLAUDE.md outside section markers (out of scope; users should use extension mechanism or separate files)
- Changing the extension manifest format or merge.lua API
- Adding a diff/merge UI for sync conflicts

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Section markers malformed after manual editing | M | L | Validate marker pairs; skip orphaned markers gracefully |
| Re-injection duplicates content | M | L | `inject_section()` is already idempotent; replaces existing sections |
| Coupling sync.lua to extension system | M | M | Keep coupling minimal: sync.lua calls one public function that handles all re-injection |
| OpenCode path not tested | M | L | Ensure both `.claude` and `.opencode` configs pass through same code path |
| Performance regression from reading extensions.json on every sync | L | L | Reading one small JSON file is negligible compared to the file copy operations |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add Section Preservation to sync.lua [NOT STARTED]

**Goal**: Make the core sync preserve `<!-- SECTION -->` blocks when overwriting CLAUDE.md (and OPENCODE.md for the OpenCode path).

**Tasks**:
- [ ] Add `preserve_sections(content)` function to `sync.lua` that extracts all `<!-- SECTION: {id} -->...<!-- END_SECTION: {id} -->` blocks from a string
- [ ] Add `restore_sections(content, sections)` function that appends preserved section blocks to new content
- [ ] Modify `sync_files()` to detect when a file being synced is the config markdown file (CLAUDE.md or OPENCODE.md) and, before overwriting, read the local file, extract sections, write the global content, then restore sections
- [ ] Handle edge cases: local file does not exist (no sections to preserve), empty sections array (no-op), config file identified by matching against known names from `root_file_names`

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Add preserve/restore functions, modify `sync_files()` to use them for config markdown files

**Verification**:
- Section extraction regex correctly captures multi-line section content
- Overwriting CLAUDE.md with global content preserves existing section blocks
- Files other than CLAUDE.md/OPENCODE.md are synced normally (no regression)
- First-time sync (no local file) works without errors

---

### Phase 2: Add Post-Sync Extension Re-injection [NOT STARTED]

**Goal**: After `execute_sync()` completes, re-run merge targets for all loaded extensions to provide defense-in-depth for all merge target types.

**Tasks**:
- [ ] Create a public function `M.reinject_extensions(project_dir, config)` in `sync.lua` (or a new helper) that reads `extensions.json`, enumerates loaded extensions, and calls `process_merge_targets()` for each
- [ ] Import required modules: `state_mod`, `manifest_mod`, and the `process_merge_targets` function from `init.lua` (or extract it to a shared location if needed to avoid circular imports)
- [ ] Call `reinject_extensions()` at the end of `load_all_globally()` after `execute_sync()` returns, only when `merge_only == false` (full sync mode)
- [ ] Handle the case where no extensions are loaded (extensions.json missing or empty) gracefully

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Add re-injection call after `execute_sync()`
- Potentially extract `process_merge_targets()` to a shared utility if circular import issues arise between `sync.lua` and `init.lua`

**Verification**:
- After full sync with extensions loaded, CLAUDE.md contains all extension sections
- After full sync, settings.json retains extension-merged settings
- After full sync, index.json retains extension-appended entries
- "New only" (merge_only) sync does not trigger re-injection (no need since it skips replacements)
- No circular import errors at runtime

---

### Phase 3: Testing and Edge Case Validation [NOT STARTED]

**Goal**: Verify the fix works end-to-end across all scenarios and document the behavior.

**Tasks**:
- [ ] Test scenario: Load extension -> Sync all -> Verify extension sections preserved in CLAUDE.md
- [ ] Test scenario: Load extension -> Sync all -> Load another extension -> Verify both extensions present
- [ ] Test scenario: No extensions loaded -> Sync all -> Verify clean CLAUDE.md (no empty markers)
- [ ] Test scenario: First-time sync to empty project -> Verify CLAUDE.md created without errors
- [ ] Test scenario: Sync with "New only" option -> Verify CLAUDE.md not overwritten
- [ ] Verify OpenCode path works (`.opencode` base_dir, `OPENCODE.md` config file)
- [ ] Add inline code comments documenting the section-preservation behavior for future maintainers

**Timing**: 30 minutes

**Depends on**: 2

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Add documentation comments

**Verification**:
- All test scenarios pass
- No regression in existing sync behavior for non-config files
- Code comments explain the "why" of section preservation

## Testing & Validation

- [ ] Full sync with loaded extensions preserves all `<!-- SECTION -->` blocks in CLAUDE.md
- [ ] Full sync re-injects extension merge targets (settings.json, index.json)
- [ ] "New only" sync skips CLAUDE.md replacement and does not trigger re-injection
- [ ] First-time sync (no local CLAUDE.md) creates file without errors
- [ ] Sync with no loaded extensions works without errors
- [ ] OpenCode configuration path (`.opencode`, `OPENCODE.md`) works correctly
- [ ] No circular import errors between sync.lua and extension modules

## Artifacts & Outputs

- Modified `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` with section preservation and post-sync re-injection
- Potentially a shared utility if `process_merge_targets` needs extraction

## Rollback/Contingency

If the implementation causes issues, revert the changes to `sync.lua`. The original behavior (full overwrite) will be restored. Users can work around the issue by manually re-loading extensions after each sync via `<leader>ac`.
