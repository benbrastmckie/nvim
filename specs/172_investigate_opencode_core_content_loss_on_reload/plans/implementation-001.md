# Implementation Plan: Fix OPENCODE.md Core Content Loss on Reload

- **Task**: 172 - Investigate OPENCODE.md core content loss on reload
- **Status**: [NOT STARTED]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Date**: 2026-03-10

## Overview

The root cause is an architectural gap: task OC_127 removed `OPENCODE.md` from the global `~/.config/nvim/.opencode/` directory, but extension manifests still target `.opencode/OPENCODE.md` for section injection. When `inject_section` in `merge.lua` encounters a missing target file, it creates an empty file with no core content. When all 11 extensions are reloaded, the result is an OPENCODE.md containing only extension sections and no core system documentation.

The fix creates a global `OPENCODE.md` source file (mirroring how `.claude/CLAUDE.md` works), then hardens `inject_section` to use core content as a seed when creating a new file. This two-pronged approach ensures both sync-based restoration and fresh-creation scenarios preserve core content.

### Research Integration

- Research report research-001.md identified the exact code path (merge.lua:139-141) and the OC_127 commit that introduced the gap
- Recommended Fix Option 1 (create global OPENCODE.md) with elements of Fix Option 2 (modify inject_section) for defense in depth

## Goals & Non-Goals

**Goals**:
- Create a global `~/.config/nvim/.opencode/OPENCODE.md` with core system documentation
- Ensure "Load Core Agent System" sync restores core content via the normal root_files mechanism
- Harden `inject_section` so it never creates an empty file when a README.md template exists
- Verify the fix survives full extension unload/reload cycles

**Non-Goals**:
- Changing extension manifests to target README.md instead of OPENCODE.md
- Adding marker-based core content detection (adds complexity without clear benefit)
- Modifying the extension load/unload sequencing logic

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Content drift between README.md and OPENCODE.md | Medium | Medium | Generate OPENCODE.md from README.md content; document the relationship |
| inject_section fallback reads wrong README.md | Low | Low | Use the target file's sibling README.md, matching existing directory structure |
| Extension reload timing race | Low | Low | inject_section is synchronous Lua; no concurrency risk |

## Implementation Phases

### Phase 1: Create Global OPENCODE.md Source File [NOT STARTED]

**Goal**: Establish `~/.config/nvim/.opencode/OPENCODE.md` as the canonical core content source, mirroring how `.claude/CLAUDE.md` works.

**Tasks**:
- [ ] Read current `~/.config/nvim/.opencode/README.md` to understand core content structure
- [ ] Create `~/.config/nvim/.opencode/OPENCODE.md` with the core system documentation from README.md, adapted for the OPENCODE.md role (agent system config file, not general documentation)
- [ ] Verify `sync.lua:248` already includes `"OPENCODE.md"` in the opencode root_file_names list (it does per research)
- [ ] Test that "Load Core Agent System" sync now copies OPENCODE.md to project directories

**Timing**: 1 hour

**Files to modify**:
- `~/.config/nvim/.opencode/OPENCODE.md` - Create new file with core system documentation

**Verification**:
- File exists at `~/.config/nvim/.opencode/OPENCODE.md`
- Content includes core sections (Quick Reference, Project Structure, Task Management, Command Reference, etc.)
- Running sync.lua's `scan_all_artifacts` with opencode config includes OPENCODE.md in root_files

---

### Phase 2: Harden inject_section Against Empty File Creation [NOT STARTED]

**Goal**: Modify `merge.lua:inject_section` to seed new files with core content from a sibling README.md when creating the target file for the first time.

**Tasks**:
- [ ] In `merge.lua:inject_section`, replace the empty-file creation (`write_file_string(target_path, "")`) with logic that reads a sibling README.md as seed content
- [ ] If no README.md exists in the same directory, fall back to empty string (preserving current behavior for edge cases)
- [ ] Add a comment explaining the defensive pattern and why it exists

**Timing**: 30 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` lines 139-141 - Replace empty file creation with README.md seed

**Verification**:
- When OPENCODE.md does not exist and an extension is loaded, the created file contains README.md content plus the extension section
- When OPENCODE.md already exists, behavior is unchanged (idempotent update path)
- When no README.md exists either, falls back to empty file (no crash)

---

### Phase 3: End-to-End Verification [NOT STARTED]

**Goal**: Confirm the fix survives the exact scenario that caused the original content loss: full extension unload followed by sequential reload of all 11 extensions.

**Tasks**:
- [ ] Run "Load Core Agent System" sync via `<leader>ao` to sync global OPENCODE.md to project
- [ ] Verify project OPENCODE.md contains core content
- [ ] Unload all extensions (simulating the reload trigger)
- [ ] Reload all 11 extensions sequentially
- [ ] Verify OPENCODE.md still contains core content plus all 11 extension sections
- [ ] Count lines to confirm content is not just extension sections (should be >600 lines, not ~542)
- [ ] Verify the backup file (OPENCODE.md.backup) also contains core content

**Timing**: 30 minutes

**Files to modify**:
- No files modified; verification only

**Verification**:
- OPENCODE.md line count after full reload cycle exceeds extension-only count (542 lines from research)
- Core sections (Quick Reference, Command Reference, etc.) are present after reload
- All 11 extension section markers are present after reload

## Testing & Validation

- [ ] Global OPENCODE.md exists and contains core system documentation
- [ ] "Load Core Agent System" sync successfully copies OPENCODE.md to project directories
- [ ] inject_section creates OPENCODE.md with core content when file is missing
- [ ] inject_section preserves existing content when file already exists
- [ ] Full extension reload cycle preserves core content
- [ ] Line count after reload > 600 (vs 542 extension-only baseline)

## Artifacts & Outputs

- `~/.config/nvim/.opencode/OPENCODE.md` - Global core content source file
- `lua/neotex/plugins/ai/shared/extensions/merge.lua` - Hardened inject_section
- `specs/172_investigate_opencode_core_content_loss_on_reload/plans/implementation-001.md` - This plan
- `specs/172_investigate_opencode_core_content_loss_on_reload/summaries/implementation-summary-20260310.md` - Completion summary

## Rollback/Contingency

If the fix causes issues:
1. Delete `~/.config/nvim/.opencode/OPENCODE.md` to revert to pre-fix state
2. Revert the `merge.lua` change (restore `write_file_string(target_path, "")`)
3. Manually reconstruct OPENCODE.md from README.md content plus extension sections (as done in tasks 170 and 171)
