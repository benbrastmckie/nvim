# Implementation Plan: Refactor skill-planner for centralized status updates

- **Task**: 364 - Refactor skill-planner for centralized status updates
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: Task 362 (update-task-status.sh must exist)
- **Research Inputs**: None
- **Artifacts**: plans/01_refactor-planner-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Refactor `.claude/skills/skill-planner/SKILL.md` to replace inline jq/Edit status update patterns in Stage 2 (preflight) and Stage 7 (postflight) with calls to the centralized `.claude/scripts/update-task-status.sh` script created in task 362. The script handles state.json updates, TODO.md task entry status markers, and TODO.md Task Order section status markers atomically, eliminating duplicated logic and ensuring consistency.

## Goals & Non-Goals

**Goals**:
- Replace Stage 2 inline jq + Edit pattern with a single script call
- Replace Stage 7 inline jq + Edit pattern with a single script call
- Preserve all other stages unchanged (1, 3, 3a, 4, 5, 6, 8, 9, 10, 11)
- Maintain the same error handling semantics (preflight failure stops execution, postflight failure is logged)

**Non-Goals**:
- Refactoring other skills (skill-researcher, skill-implementer) -- those are separate tasks
- Modifying the update-task-status.sh script itself
- Changing the subagent delegation or artifact linking logic

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Script path incorrect in SKILL.md | M | L | Use relative path from PROJECT_ROOT; verify with ls before commit |
| Error code semantics differ from inline pattern | M | L | Script exits 0 on success, 2 on state.json failure, 3 on TODO.md failure -- map to existing error handling |
| Stage 7 partial/failed branch not handled | H | L | Keep conditional logic: only call script when status is "planned"; preserve "keep as planning" fallback |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Replace Stage 2 (Preflight) with script call [COMPLETED]

**Goal**: Replace the inline jq state.json update and Edit TODO.md instruction in Stage 2 with a single call to `update-task-status.sh preflight`.

**Tasks**:
- [ ] Replace the Stage 2 `jq` code block (lines 78-85 of SKILL.md) with a bash call to `.claude/scripts/update-task-status.sh preflight $task_number plan $session_id`
- [ ] Remove the "Update TODO.md" Edit instruction that follows the jq block (line 88)
- [ ] Add a note that the script handles state.json, TODO.md task entry, and TODO.md Task Order atomically
- [ ] Add error handling: if script exits non-zero, return error and stop execution

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-planner/SKILL.md` - Replace Stage 2 content

**Verification**:
- Stage 2 section contains only the script call, no inline jq
- No Edit tool instruction for TODO.md status in Stage 2
- Error handling preserves "stop on failure" semantics

---

### Phase 2: Replace Stage 7 (Postflight) with script call [COMPLETED]

**Goal**: Replace the inline jq state.json update and Edit TODO.md instruction in Stage 7 with a conditional call to `update-task-status.sh postflight`.

**Tasks**:
- [ ] Replace the Stage 7 `jq` code block (lines 225-232 of SKILL.md) with a bash call to `.claude/scripts/update-task-status.sh postflight $task_number plan $session_id`
- [ ] Remove the "Update TODO.md" Edit instruction (line 235)
- [ ] Preserve the conditional: only call script when subagent status is "planned"; on partial/failed, keep status as "planning" (no script call needed since no status change)
- [ ] Add error handling: if script exits non-zero, log warning but continue (postflight errors are non-blocking for artifact linking and git commit)

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-planner/SKILL.md` - Replace Stage 7 content

**Verification**:
- Stage 7 section contains only the conditional script call, no inline jq
- No Edit tool instruction for TODO.md status in Stage 7
- Partial/failed branch preserved unchanged
- Error handling is non-blocking (log and continue)

---

### Phase 3: Verify and validate changes [COMPLETED]

**Goal**: Ensure the refactored SKILL.md is internally consistent and the script references are correct.

**Tasks**:
- [ ] Read the full modified SKILL.md and verify no remaining inline jq status-update patterns in Stages 2 and 7
- [ ] Verify the script path `.claude/scripts/update-task-status.sh` exists and is executable
- [ ] Verify Stage 8 (artifact linking) jq patterns are untouched -- these are NOT status updates and should remain inline
- [ ] Verify the error handling section still references appropriate error types
- [ ] Verify the "MUST NOT" section at the end remains accurate

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- None (read-only verification)

**Verification**:
- No inline jq patterns for status updates remain in Stages 2 or 7
- Script file exists at expected path
- All other stages unchanged
- SKILL.md is internally consistent

## Testing & Validation

- [ ] Verify `.claude/scripts/update-task-status.sh` exists and is executable
- [ ] Read modified SKILL.md and confirm Stage 2 uses script call instead of inline jq
- [ ] Read modified SKILL.md and confirm Stage 7 uses script call instead of inline jq
- [ ] Confirm Stage 8 artifact-linking jq is preserved (not a status update)
- [ ] Confirm no references to removed Edit-based TODO.md status updates remain in Stages 2 or 7

## Artifacts & Outputs

- `specs/364_refactor_skill_planner/plans/01_refactor-planner-plan.md` (this file)
- `.claude/skills/skill-planner/SKILL.md` (modified, implementation artifact)

## Rollback/Contingency

Revert with `git checkout HEAD -- .claude/skills/skill-planner/SKILL.md` to restore the inline jq/Edit patterns. The centralized script is additive and does not need rollback.
