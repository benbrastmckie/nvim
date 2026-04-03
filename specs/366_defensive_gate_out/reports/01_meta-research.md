# Research Report: Task #366

**Task**: 366 - Add defensive status verification to /research and /plan GATE OUT
**Generated**: 2026-04-03
**Source**: /meta interview (auto-generated)
**Status**: Pre-populated from interview context

---

## Context Summary

**Purpose**: Add defensive correction logic to /research and /plan GATE OUT checkpoints, matching what /implement already has
**Scope**: .claude/commands/research.md, .claude/commands/plan.md
**Affected Components**: /research command, /plan command
**Domain**: meta
**Language**: meta

## Task Requirements

The /implement command (implement.md) has robust defensive verification at GATE OUT (CHECKPOINT 2):
- Step 5: Verifies plan file status was updated to [COMPLETED]
- Step 6: Verifies TODO.md status was updated, auto-corrects if still [IMPLEMENTING]

The /research and /plan commands lack this defensive verification. They only say "Verify Status Updated - Confirm status is now X in state.json" with no corrective action.

### Changes Needed

**research.md CHECKPOINT 2: GATE OUT** - Add after existing step 3:

```
4. **Verify TODO.md Status (Defensive)**
   Check that task entry shows [RESEARCHED] and Task Order shows correct status.
   If still [RESEARCHING], apply correction via Edit.

5. **Verify state.json Status (Defensive)**
   If state.json still shows "researching", apply correction via jq.
```

**plan.md CHECKPOINT 2: GATE OUT** - Add after existing step 3:

```
4. **Verify TODO.md Status (Defensive)**
   Check that task entry shows [PLANNED] and Task Order shows correct status.
   If still [PLANNING], apply correction via Edit.

5. **Verify state.json Status (Defensive)**
   If state.json still shows "planning", apply correction via jq.

6. **Verify Plan File Status (Defensive)**
   If plan file exists and status is not [PLANNED], call update-plan-status.sh.
```

### Why This Matters

If a skill's postflight fails (jq error, Edit match failure, loop guard timeout), the task can be left in an in-progress state ([RESEARCHING], [PLANNING]) indefinitely. The command-level GATE OUT is the last chance to catch and correct this before returning to the user.

## Integration Points

- **Component Type**: Command modification
- **Affected Area**: .claude/commands/
- **Action Type**: Modify existing
- **Related Files**:
  - `.claude/commands/research.md`
  - `.claude/commands/plan.md`
  - `.claude/commands/implement.md` (reference implementation)
  - `.claude/scripts/update-task-status.sh` (from Task 362, can use for corrections)

## Dependencies

- Task #363: Refactor skill-researcher (should be done first so we know what the skill does vs what GATE OUT needs to verify)
- Task #364: Refactor skill-planner (same reason)

## Interview Context

### Effort Assessment
- **Estimated Effort**: 1 hour (Small)
- **Complexity Notes**: Straightforward - copying the pattern from implement.md's GATE OUT and adapting for research/plan status values

---

*This research report was auto-generated during task creation via /meta command.*
*For deeper investigation, run `/research 366 [focus]` with a specific focus prompt.*
