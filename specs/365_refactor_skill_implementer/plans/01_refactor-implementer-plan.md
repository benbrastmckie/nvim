# Implementation Plan: Task #365

- **Task**: 365 - Refactor skill-implementer for centralized status updates
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: Task 362 (update-task-status.sh)
- **Research Inputs**: None
- **Artifacts**: plans/01_refactor-implementer-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Refactor skill-implementer (SKILL.md) to replace inline state.json/TODO.md/plan-file status update code in Stage 2 (preflight) and Stage 7 (postflight) with calls to the centralized `update-task-status.sh` script created in task 362. The script handles state.json updates, TODO.md task entry and Task Order updates, and plan file updates in a single atomic call. Completion-specific fields (completion_summary, claudemd_suggestions, roadmap_items) remain inline in Stage 7 since they are implementer-specific and not covered by the centralized script.

### Research Integration

No formal research report exists. Analysis is based on direct comparison of the current SKILL.md code against the `update-task-status.sh` API.

## Goals & Non-Goals

**Goals**:
- Replace Stage 2 preflight inline status code (state.json jq, TODO.md Edit, plan file script call) with a single `update-task-status.sh preflight` call
- Replace Stage 7 postflight inline status code for the "implemented" and "partial" paths with `update-task-status.sh postflight` calls, keeping completion_summary/claudemd_suggestions/roadmap_items inline
- Reduce SKILL.md line count and maintenance surface for status updates
- Preserve all existing behavior (idempotency, error handling, partial status)

**Non-Goals**:
- Modifying other stages (1, 3, 3a, 4, 5, 5a, 6, 8, 9, 10, 11)
- Changing the update-task-status.sh script itself
- Refactoring completion_summary/claudemd_suggestions/roadmap_items handling into the script (these are implementer-specific)
- Modifying any other skills (skill-researcher, skill-planner)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Script handles "completed" but not "partial" postflight correctly | M | L | Verify script status mapping; "partial" path keeps status as "implementing" which means we skip the script call for partial and handle inline |
| Removing inline TODO.md Edit calls breaks verification step | M | L | The script handles TODO.md updates; remove the manual Edit instructions and verify step |
| Plan file update already handled by script but also called separately | L | M | Remove the standalone `update-plan-status.sh` call since the centralized script calls it internally |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

### Phase 1: Replace Stage 2 (Preflight) with Script Call [COMPLETED]

**Goal**: Replace all inline preflight status update code in Stage 2 with a single script invocation.

**Tasks**:
- [ ] Remove the state.json jq block (lines 73-81 equivalent) from Stage 2
- [ ] Remove the TODO.md Edit instructions (lines 84-93 equivalent) from Stage 2
- [ ] Remove the standalone `update-plan-status.sh` call (lines 97-99 equivalent) from Stage 2
- [ ] Replace with single script call: `.claude/scripts/update-task-status.sh preflight $task_number implement $session_id`
- [ ] Add note that the script handles state.json, TODO.md (task entry + Task Order), and plan file updates atomically
- [ ] Keep the Stage 2 heading and purpose description intact

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Replace Stage 2 body

**Verification**:
- Stage 2 contains only a single script call plus explanatory notes
- No inline jq, Edit, or update-plan-status.sh references remain in Stage 2
- The script call uses the correct arguments: `preflight`, `$task_number`, `implement`, `$session_id`

---

### Phase 2: Replace Stage 7 (Postflight) Status Code with Script Call [COMPLETED]

**Goal**: Replace inline postflight status update code in Stage 7 with script calls, while keeping completion-specific field updates inline.

**Tasks**:
- [ ] In the "implemented" path: replace state.json status/timestamp jq block (Step 1, lines 251-257) with `.claude/scripts/update-task-status.sh postflight $task_number implement $session_id`
- [ ] Remove the TODO.md Edit instructions for [IMPLEMENTING] -> [COMPLETED] (lines 282-293)
- [ ] Remove the TODO.md verification step (line 294) since the script handles it
- [ ] Remove the standalone `update-plan-status.sh` call for COMPLETED (lines 297-299)
- [ ] Remove the `update-recommended-order.sh` source/call if it is covered by the script (verify first; if not covered, keep it)
- [ ] Keep completion_summary jq block (Step 2, lines 261-265) inline - this is implementer-specific
- [ ] Keep claudemd_suggestions jq block (Step 3 meta path, lines 268-272) inline
- [ ] Keep roadmap_items jq block (Step 3 non-meta path, lines 275-279) inline
- [ ] In the "partial" path: keep status as "implementing" with resume_phase update inline (the script maps postflight:implement to "completed", not "partial", so we cannot use the script for partial)
- [ ] Remove the standalone `update-plan-status.sh` call for PARTIAL (line 324) - need to handle this separately since the script only does IMPLEMENTING or COMPLETED for implement
- [ ] Add note explaining why partial path remains inline (script does not support partial status)

**Timing**: 1.0 hours

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Restructure Stage 7 body

**Verification**:
- The "implemented" path starts with the script call, then applies completion_summary/claudemd_suggestions/roadmap_items inline
- The "partial" path remains fully inline with clear explanation
- The "failed" path remains unchanged
- No duplicate TODO.md or plan file update logic exists
- The `update-recommended-order.sh` call is preserved if not covered by the centralized script

---

### Phase 3: Review and Verify Changes [COMPLETED]

**Goal**: Ensure the refactored SKILL.md is correct, consistent, and complete.

**Tasks**:
- [ ] Re-read the entire SKILL.md to verify structural integrity
- [ ] Verify no orphaned references to removed code blocks
- [ ] Verify Stage 2 and Stage 7 code blocks are syntactically correct bash
- [ ] Confirm the script API arguments match update-task-status.sh expectations
- [ ] Verify that update-recommended-order.sh is handled correctly (kept if not in centralized script)
- [ ] Check that partial/failed paths still function correctly without the centralized script

**Timing**: 0.5 hours

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-implementer/SKILL.md` - Minor corrections if needed

**Verification**:
- Full SKILL.md read-through passes without logical inconsistencies
- All script calls use correct argument order and values
- Completion-specific fields are preserved inline
- Error handling paths are intact

## Testing & Validation

- [ ] Verify SKILL.md parses as valid markdown
- [ ] Verify all bash code blocks have correct syntax
- [ ] Confirm script call arguments match update-task-status.sh API: `<operation> <task_number> <target_status> <session_id>`
- [ ] Confirm completion_summary, claudemd_suggestions, and roadmap_items remain in Stage 7
- [ ] Confirm partial and failed paths are unbroken
- [ ] Dry-run mental walkthrough of preflight -> implement -> postflight flow

## Artifacts & Outputs

- Modified `.claude/skills/skill-implementer/SKILL.md` with centralized status update calls
- This plan file: `specs/365_refactor_skill_implementer/plans/01_refactor-implementer-plan.md`

## Rollback/Contingency

Revert the single file change with `git checkout HEAD -- .claude/skills/skill-implementer/SKILL.md`. No other files are modified.
