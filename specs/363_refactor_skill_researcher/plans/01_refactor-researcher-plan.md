# Implementation Plan: Refactor skill-researcher for centralized status updates

- **Task**: 363 - Refactor skill-researcher for centralized status updates
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: Task 362 (update-task-status.sh - completed)
- **Research Inputs**: None (direct codebase analysis)
- **Artifacts**: plans/01_refactor-researcher-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Refactor skill-researcher (SKILL.md) to replace its inline jq/Edit status update patterns in Stage 2 (preflight) and Stage 7 (postflight) with calls to the centralized `update-task-status.sh` script created in task 362. Also remove the redundant Stage 9 git commit section, since the command layer (skill-orchestrator / skill-git-workflow) handles commits. This reduces ~50 lines of fragile inline jq/sed/Edit instructions down to two script calls, improving maintainability and consistency across skills.

## Goals & Non-Goals

**Goals**:
- Replace Stage 2 inline jq + Edit preflight code with a single `update-task-status.sh preflight` call
- Replace Stage 7 inline jq + Edit postflight code with a single `update-task-status.sh postflight` call
- Remove Stage 9 (git commit) as it duplicates the command-layer commit
- Preserve all other stages (1, 3, 3a, 4, 5, 6, 8, 10, 11) unchanged
- Maintain the skill's error handling semantics (keep status on failure)

**Non-Goals**:
- Refactoring skill-implementer (separate task)
- Modifying the update-task-status.sh script itself
- Changing subagent delegation logic (Stages 4-5)
- Modifying artifact linking logic (Stage 8)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Script path wrong in SKILL.md instructions | M | L | Use relative path `.claude/scripts/update-task-status.sh` consistent with existing usage in skill-implementer Stage 2 |
| Postflight skip on failure breaks error handling | H | L | Preserve the conditional: only call postflight script when status is "researched" |
| Stage renumbering confusion | L | M | Keep stage numbers unchanged; just simplify content within existing stages |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Replace Stage 2 (Preflight) with script call [COMPLETED]

**Goal**: Replace the inline jq state.json update and Edit TODO.md instructions in Stage 2 with a single call to update-task-status.sh.

**Tasks**:
- [ ] Replace the Stage 2 body in SKILL.md: remove the jq command block (lines ~72-79) and the Edit TODO.md instruction (line ~82-83)
- [ ] Insert the replacement script call:
  ```bash
  .claude/scripts/update-task-status.sh preflight "$task_number" research "$session_id"
  ```
- [ ] Add error handling note: if the script exits non-zero, abort and keep current status
- [ ] Verify the stage description text still accurately describes what happens

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Stage 2 section (~lines 66-84)

**Verification**:
- Stage 2 contains only the script call (no inline jq or Edit instructions)
- Error handling semantics preserved (abort on failure)

---

### Phase 2: Replace Stage 7 (Postflight) and remove Stage 9 (Git Commit) [COMPLETED]

**Goal**: Replace the inline jq state.json update and Edit TODO.md instructions in Stage 7 with a script call, and remove Stage 9 entirely.

**Tasks**:
- [ ] Replace the Stage 7 body: remove the two jq command blocks (lines ~210-221 for status, ~219-221 for artifact number increment) and the Edit TODO.md instruction (line ~226)
- [ ] Insert the replacement script call (conditional on success):
  ```bash
  if [ "$status" = "researched" ]; then
    .claude/scripts/update-task-status.sh postflight "$task_number" research "$session_id"
  fi
  ```
- [ ] Keep the `next_artifact_number` increment as a separate jq step (the script does not handle artifact numbering)
- [ ] Keep the "On partial/failed" note unchanged
- [ ] Remove Stage 9 (Git Commit) entirely -- the command layer handles this via skill-git-workflow
- [ ] Renumber Stage 10 to Stage 9 (Cleanup) and Stage 11 to Stage 10 (Return Brief Summary)
- [ ] Update the "MUST NOT (Postflight Boundary)" section to reference the script instead of inline jq/Edit

**Timing**: 0.75 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Stage 7 (~lines 203-228), Stage 9 (~lines 282-294), Stage 10-11 renumbering, Postflight Boundary section

**Verification**:
- Stage 7 contains the script call plus artifact number increment (no inline status jq or Edit)
- Stage 9 (old git commit) is removed
- Remaining stages renumbered correctly
- Postflight Boundary section updated

---

### Phase 3: Verify changes with dry-run testing [COMPLETED]

**Goal**: Validate the refactored SKILL.md is internally consistent and the script calls are correct.

**Tasks**:
- [ ] Read the complete modified SKILL.md and verify all stage numbers are sequential
- [ ] Verify no orphan references to removed stages (e.g., "see Stage 9" should not appear)
- [ ] Run a dry-run test of the script to confirm the API matches:
  ```bash
  .claude/scripts/update-task-status.sh preflight 363 research sess_test --dry-run
  .claude/scripts/update-task-status.sh postflight 363 research sess_test --dry-run
  ```
- [ ] Verify the script output shows the expected status transitions (researching / researched)
- [ ] Confirm the SKILL.md still references the correct context files and tools

**Timing**: 0.25 hours

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Fix any issues found during verification

**Verification**:
- All stage numbers sequential (1 through 10)
- No dangling references to old stage numbers
- Dry-run output confirms correct status mapping
- SKILL.md passes manual review for consistency

## Testing & Validation

- [ ] Dry-run the preflight script call with a test task number
- [ ] Dry-run the postflight script call with a test task number
- [ ] Read final SKILL.md and confirm stage numbering is sequential
- [ ] Grep for removed patterns (inline jq status updates) to confirm they are gone
- [ ] Verify the artifact number increment jq block is preserved in Stage 7

## Artifacts & Outputs

- `plans/01_refactor-researcher-plan.md` (this file)
- `.claude/skills/skill-researcher/SKILL.md` (modified during implementation)

## Rollback/Contingency

The SKILL.md file is tracked in git. If the refactoring introduces issues, revert with:
```bash
git checkout HEAD -- .claude/skills/skill-researcher/SKILL.md
```
