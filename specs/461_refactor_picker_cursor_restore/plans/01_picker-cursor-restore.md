# Implementation Plan: Review and Refactor Picker Cursor Restoration

- **Task**: 461 - Review and refactor picker cursor restoration
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/461_refactor_picker_cursor_restore/reports/01_picker-cursor-restore.md
- **Artifacts**: plans/01_picker-cursor-restore.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: true

## Overview

Research confirmed that the cursor-restore implementation in the commands picker is correct and well-structured. The `register_completion_callback + vim.schedule + set_selection` approach is robust for descending sorting strategy, the `ext/actions.close` reorder is a valid safety improvement, and no shared helper extraction is warranted. This plan covers committing the existing uncommitted changes and adding an optional clarifying comment to the extension toggle block.

### Research Integration

Key findings from the research report:
- The name-based cursor restore in commands picker is correct for descending sort (index-based would fail)
- The extensions picker uses a different but equally valid index-based approach (ascending sort)
- Only the extension toggle close/reopen cycle benefits from cursor restore; other cycles (Ctrl-l, Ctrl-u, Ctrl-s, Load All) do not need it
- A shared helper is not warranted due to fundamentally different strategies at only two call sites
- OpenCode pickers delegate to the same code, so cursor restore works automatically

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Commit the existing correct cursor-restore implementation and close-reorder safety fix
- Add a brief inline comment explaining why only the extension toggle uses cursor restore

**Non-Goals**:
- Adding cursor restore to Ctrl-l, Ctrl-u, Ctrl-s, or Load All cycles
- Extracting a shared cursor-restore helper between commands and extensions pickers
- Modifying the extensions picker (already clean)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Comment adds noise without value | L | L | Keep it to 1-2 lines, factual, no over-documentation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add Clarifying Comment and Commit [NOT STARTED]

**Goal**: Add a brief comment at the extension toggle block explaining the cursor-restore rationale, then commit all uncommitted changes.

**Tasks**:
- [ ] Add a 1-2 line comment above the extension toggle block (line 166 area in init.lua) explaining that this is the only close/reopen cycle needing cursor restore because the extension list is stable across toggle operations, unlike artifact sync operations where the list changes
- [ ] Verify the entries.lua change (simplified extension status indicator) is correct and consistent
- [ ] Commit all three changes: cursor restore feature, close-reorder safety fix, status indicator simplification, and the new comment

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Add clarifying comment at extension toggle block

**Verification**:
- The comment accurately describes why only extension toggle uses cursor restore
- All uncommitted changes are committed in a single clean commit
- No functional changes introduced (comment-only modification)

## Testing & Validation

- [ ] Open the commands picker and toggle an extension to verify cursor restores to the toggled entry
- [ ] Verify Ctrl-l, Ctrl-u, Ctrl-s still work without cursor restore (return to top is expected)
- [ ] Verify the picker displays correctly with the simplified status indicators from entries.lua

## Artifacts & Outputs

- `specs/461_refactor_picker_cursor_restore/plans/01_picker-cursor-restore.md` (this plan)
- `specs/461_refactor_picker_cursor_restore/summaries/01_picker-cursor-restore-summary.md` (after implementation)
- Modified: `lua/neotex/plugins/ai/claude/commands/picker/init.lua` (comment addition)

## Rollback/Contingency

If the comment proves misleading or unnecessary, it can be removed in a single-line edit. The functional changes (cursor restore, close reorder, status indicator) are already validated by research and do not need rollback.
