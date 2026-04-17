# Implementation Plan: Task #462

- **Task**: 462 - Fix extension system step numbering
- **Status**: [COMPLETED]
- **Effort**: 0.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/462_fix_extension_system_step_numbering/reports/01_step-numbering-fix.md
- **Artifacts**: plans/01_step-numbering-fix.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Fix duplicate step numbering in `.claude/docs/architecture/extension-system.md`. The load flow has two steps numbered 3 and the unload flow has two steps numbered 3, caused by inserting dependency resolution steps without renumbering subsequent steps. The fix is mechanical: renumber 10 lines across two sections.

### Research Integration

Research report confirms exact line numbers and correct numbering. The Zed repository's already-fixed version serves as the authoritative reference. Load flow steps 3-9 become 3-10 (the first step 3 is correct; the second step 3 and all subsequent need incrementing by 1). Unload flow steps 3-5 become 3-6 (same pattern).

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted for this trivial documentation fix.

## Goals & Non-Goals

**Goals**:
- Renumber load flow steps to sequential 1-10
- Renumber unload flow steps to sequential 1-6
- Match the corrected numbering from the Zed repository reference

**Non-Goals**:
- Changing any step descriptions or content
- Modifying other sections of extension-system.md
- Updating any code or scripts

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Off-by-one in renumbering | L | L | Research report provides exact before/after for every line |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Renumber Steps [COMPLETED]

**Goal**: Fix all duplicate step numbers in both load and unload flows.

**Tasks**:
- [ ] Renumber load flow: change line 241 from `3.` to `4.`, line 249 from `4.` to `5.`, line 256 from `5.` to `6.`, line 259 from `6.` to `7.`, line 263 from `7.` to `8.`, line 264 from `8.` to `9.`, line 265 from `9.` to `10.`
- [ ] Renumber unload flow: change line 280 from `3.` to `4.`, line 281 from `4.` to `5.`, line 282 from `5.` to `6.`

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/docs/architecture/extension-system.md` - Renumber steps in Load/Unload Process section

**Verification**:
- Load flow steps are numbered 1 through 10 with no duplicates
- Unload flow steps are numbered 1 through 6 with no duplicates
- Step descriptions and content are unchanged

## Testing & Validation

- [ ] Load flow contains exactly steps 1-10 in sequence
- [ ] Unload flow contains exactly steps 1-6 in sequence
- [ ] No duplicate step numbers exist in either flow
- [ ] All step descriptions match the original content verbatim

## Artifacts & Outputs

- `.claude/docs/architecture/extension-system.md` (modified)

## Rollback/Contingency

Revert the single file via `git checkout -- .claude/docs/architecture/extension-system.md`.
