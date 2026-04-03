# Implementation Plan: Add Defensive Status Verification to /research and /plan GATE OUT

- **Task**: 366 - Add defensive status verification to /research and /plan GATE OUT
- **Status**: [IMPLEMENTING]
- **Effort**: 1 hour
- **Dependencies**: Tasks 362-365, 367 (all completed - centralized update-task-status.sh exists)
- **Research Inputs**: None (codebase analysis performed during planning)
- **Artifacts**: plans/01_defensive-gate-out-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `/implement` command already has defensive status verification in its CHECKPOINT 2: GATE OUT (steps 5 and 6 in implement.md). The `/research` and `/plan` commands lack this defensive correction logic -- their GATE OUT sections only confirm status but do not correct mismatches. This plan adds equivalent defensive verification to both commands, using the centralized `update-task-status.sh` script for corrections.

## Goals & Non-Goals

**Goals**:
- Add defensive state.json status verification to /research GATE OUT
- Add defensive TODO.md task entry status verification to /research GATE OUT
- Add defensive TODO.md Task Order status verification to /research GATE OUT
- Add the same three verifications to /plan GATE OUT
- Use `update-task-status.sh` for corrections (consistent with the centralized approach from tasks 362-365)

**Non-Goals**:
- Modifying the /implement GATE OUT (already has defensive checks)
- Changing how skills internally handle status updates
- Adding verification to multi-task dispatch paths (those delegate to per-task agents which run single-task checkpoints)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Script path wrong in markdown pseudocode | L | L | Copy exact path from implement.md reference |
| Inconsistent status marker format between commands | M | L | Use identical patterns across both files |
| Over-correction masking real skill failures | M | L | Only correct when skill reports success but state is wrong |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add Defensive Verification to /research GATE OUT [COMPLETED]

**Goal**: Expand CHECKPOINT 2: GATE OUT in `.claude/commands/research.md` to include defensive status correction logic matching the pattern in implement.md.

**Tasks**:
- [ ] Read current CHECKPOINT 2: GATE OUT in research.md (lines 379-393)
- [ ] Add step 4: "Verify state.json Status (Defensive)" -- check that state.json shows status "researched"; if not, run `update-task-status.sh postflight {N} research {session_id}`
- [ ] Add step 5: "Verify TODO.md Status (Defensive)" -- check that TODO.md task entry shows `[RESEARCHED]`; if still shows `[RESEARCHING]`, use Edit tool to correct both the task entry and the Task Order section
- [ ] Ensure defensive checks only run when skill reports success (not on failure/partial)

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/commands/research.md` - Expand CHECKPOINT 2: GATE OUT section with steps 4-5

**Verification**:
- CHECKPOINT 2: GATE OUT in research.md has 5 steps (original 3 + new 4-5)
- Step 4 checks state.json for "researched" status and corrects via update-task-status.sh
- Step 5 checks TODO.md for `[RESEARCHED]` marker and corrects via Edit tool
- Pattern matches implement.md steps 5-6 structurally

---

### Phase 2: Add Defensive Verification to /plan GATE OUT [COMPLETED]

**Goal**: Expand CHECKPOINT 2: GATE OUT in `.claude/commands/plan.md` to include defensive status correction logic matching the pattern in implement.md.

**Tasks**:
- [ ] Read current CHECKPOINT 2: GATE OUT in plan.md (lines 377-390)
- [ ] Add step 4: "Verify state.json Status (Defensive)" -- check that state.json shows status "planned"; if not, run `update-task-status.sh postflight {N} plan {session_id}`
- [ ] Add step 5: "Verify TODO.md Status (Defensive)" -- check that TODO.md task entry shows `[PLANNED]`; if still shows `[PLANNING]`, use Edit tool to correct both the task entry and the Task Order section
- [ ] Add step 6: "Verify Plan File Status (Defensive)" -- check that the plan file header shows `[NOT STARTED]` (the correct initial status for a newly created plan); if it shows something unexpected, log a warning
- [ ] Ensure defensive checks only run when skill reports success (not on failure/partial)

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/commands/plan.md` - Expand CHECKPOINT 2: GATE OUT section with steps 4-6

**Verification**:
- CHECKPOINT 2: GATE OUT in plan.md has 6 steps (original 3 + new 4-6)
- Step 4 checks state.json for "planned" status and corrects via update-task-status.sh
- Step 5 checks TODO.md for `[PLANNED]` marker and corrects via Edit tool
- Step 6 checks plan file status marker
- Pattern matches implement.md steps 5-6 structurally

---

### Phase 3: Verify Consistency Across Commands [COMPLETED]

**Goal**: Confirm all three commands (/research, /plan, /implement) have consistent defensive verification patterns in their GATE OUT checkpoints.

**Tasks**:
- [ ] Read all three GATE OUT sections side by side
- [ ] Verify state.json check uses same pattern (jq query + conditional correction)
- [ ] Verify TODO.md check uses same pattern (grep + Edit tool correction)
- [ ] Verify correction mechanism is consistent (update-task-status.sh for state.json, Edit tool for TODO.md)
- [ ] Verify all three commands guard defensive checks behind skill success condition
- [ ] Fix any inconsistencies found

**Timing**: 0.25 hours

**Depends on**: 1, 2

**Files to modify**:
- `.claude/commands/research.md` - Fix inconsistencies if found
- `.claude/commands/plan.md` - Fix inconsistencies if found

**Verification**:
- All three GATE OUT sections follow the same defensive pattern
- Status values are correct per command: researched, planned, completed
- Status markers are correct per command: [RESEARCHED], [PLANNED], [COMPLETED]
- Correction tools are consistent across all three commands

## Testing & Validation

- [ ] Read research.md GATE OUT and confirm defensive steps 4-5 exist
- [ ] Read plan.md GATE OUT and confirm defensive steps 4-6 exist
- [ ] Confirm state.json check pattern matches across all three commands
- [ ] Confirm TODO.md check pattern matches across all three commands
- [ ] Confirm update-task-status.sh is referenced correctly in correction paths

## Artifacts & Outputs

- Modified `.claude/commands/research.md` with defensive GATE OUT verification
- Modified `.claude/commands/plan.md` with defensive GATE OUT verification

## Rollback/Contingency

Revert changes to research.md and plan.md via `git checkout HEAD -- .claude/commands/research.md .claude/commands/plan.md`. The defensive checks are additive and do not alter existing behavior -- they only fire when a mismatch is detected.
