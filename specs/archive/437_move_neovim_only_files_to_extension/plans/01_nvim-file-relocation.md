# Implementation Plan: Move Neovim-Only Files to Extension

- **Task**: 437 - Move neovim-only files to extension and add to .sync-exclude
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None (task 433 already completed)
- **Research Inputs**: specs/437_move_neovim_only_files_to_extension/reports/01_nvim-file-relocation.md
- **Artifacts**: plans/01_nvim-file-relocation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Move 2 neovim-specific guide files from core `.claude/docs/guides/` to the nvim extension at `.claude/extensions/nvim/context/project/neovim/guides/`, add index entries, and update all cross-references. This eliminates neovim contamination from the portable core and makes the guides discoverable through the extension's context index.

### Research Integration

Research report (`reports/01_nvim-file-relocation.md`) confirmed that only 2 of 5 candidate files are 100% neovim-specific: `neovim-integration.md` (33 nvim refs) and `tts-stt-integration.md` (22 nvim refs). The remaining 3 files are mixed-content and deferred to task 438 for genericization. No core `context/index.json` entries exist for these files, so only the extension's `index-entries.json` needs new entries.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

Advances roadmap item "Zero stale references to removed/renamed files in `.claude/`" under Success Metrics. Supports the broader goal of clean extension boundaries.

## Goals & Non-Goals

**Goals**:
- Move `neovim-integration.md` and `tts-stt-integration.md` to the nvim extension
- Add index entries so the files are discoverable via context queries
- Update all cross-references in `docs/README.md` and `README.md`

**Non-Goals**:
- Genericizing mixed-content files (task 438 scope)
- Modifying `.sync-exclude` path exclusions (files will no longer exist in core after move)
- Changing the content of the moved files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Broken cross-references after move | M | M | Systematic grep for both filenames before and after; research identified all 11 locations |
| Guides not discoverable after move | L | L | Add index-entries.json entries with appropriate load_when conditions |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Move Files and Add Index Entries [NOT STARTED]

**Goal**: Relocate both guide files to the nvim extension and register them in the extension index.

**Tasks**:
- [ ] Create `.claude/extensions/nvim/context/project/neovim/guides/` directory
- [ ] Move `.claude/docs/guides/neovim-integration.md` to `.claude/extensions/nvim/context/project/neovim/guides/neovim-integration.md`
- [ ] Move `.claude/docs/guides/tts-stt-integration.md` to `.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md`
- [ ] Add 2 entries to `.claude/extensions/nvim/index-entries.json` with path `project/neovim/guides/{filename}`, domain `project`, subdomain `neovim`, and appropriate `load_when` conditions matching existing guide patterns

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/nvim/context/project/neovim/guides/neovim-integration.md` - new file (moved)
- `.claude/extensions/nvim/context/project/neovim/guides/tts-stt-integration.md` - new file (moved)
- `.claude/extensions/nvim/index-entries.json` - add 2 entries
- `.claude/docs/guides/neovim-integration.md` - delete (moved)
- `.claude/docs/guides/tts-stt-integration.md` - delete (moved)

**Verification**:
- Both files exist at new locations with identical content
- Both original files are removed
- `index-entries.json` has 2 new entries and parses as valid JSON

---

### Phase 2: Update Cross-References [NOT STARTED]

**Goal**: Update all documentation files that reference the moved guides to point to the new extension paths or note extension availability.

**Tasks**:
- [ ] Update `.claude/docs/README.md` lines 18-19 (guide listing) to note files moved to nvim extension
- [ ] Update `.claude/docs/README.md` lines 56-57 (guide links) to point to new extension paths
- [ ] Update `.claude/README.md` line 188 (Related Documentation) to point to new extension path for neovim-integration.md
- [ ] Verify internal cross-references between the two moved files still work (they should, since both are co-located after move)
- [ ] Run grep for `neovim-integration.md` and `tts-stt-integration.md` across the codebase to confirm no remaining stale references

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/docs/README.md` - update 4 reference locations
- `.claude/README.md` - update 1 reference location

**Verification**:
- Grep for old paths returns zero matches outside of git history and plan/report files
- All updated references point to valid files

## Testing & Validation

- [ ] Both files exist at `.claude/extensions/nvim/context/project/neovim/guides/`
- [ ] Original files removed from `.claude/docs/guides/`
- [ ] `jq . .claude/extensions/nvim/index-entries.json` parses without error
- [ ] Grep for `docs/guides/neovim-integration.md` and `docs/guides/tts-stt-integration.md` returns no stale references in active files
- [ ] Content of moved files is byte-identical to originals

## Artifacts & Outputs

- plans/01_nvim-file-relocation.md (this file)
- summaries/01_nvim-file-relocation-summary.md (after implementation)

## Rollback/Contingency

Git revert the implementation commit to restore both files to `.claude/docs/guides/` and revert cross-reference changes. The move is a simple file relocation with reference updates, so rollback is straightforward.
