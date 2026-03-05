# Research Report: Plan Metadata Status Synchronization Gap

**Task**: OC_138 - Fix plan metadata status synchronization  
**Report**: research-001.md  
**Date**: 2026-03-06  
**Status**: [COMPLETED]

---

## Executive Summary

A critical gap has been identified in the status synchronization protocol. When tasks are implemented and marked as completed, the plan file's metadata status (line 4) is NOT being updated, while state.json and TODO.md are correctly synchronized. This creates a three-way inconsistency that has persisted despite multiple attempts to fix it.

## The Three-Way Inconsistency Problem

### Files That Should Be Synchronized

1. **specs/state.json** - Task status field: `"completed"` ✅
2. **specs/TODO.md** - Task status marker: `[COMPLETED]` ✅
3. **specs/OC_NNN_*/plans/implementation-NNN.md** - Plan metadata status: `[NOT STARTED]` ❌

### Example: Task OC_136

After completion:
- **state.json**: `"status": "completed"` ✅ (updated)
- **TODO.md**: `- **Status**: [COMPLETED]` ✅ (updated)
- **implementation-003.md line 4**: `- **Status**: [NOT STARTED]` ❌ (NOT updated!)

## Root Cause Analysis

### The Missing Third Location

The current synchronization protocol (documented in `phase-synchronization.md`) only addresses TWO of the three locations:

**Current Protocol (Lines 114-123 of phase-synchronization.md)**:
```
When all phases are finished:
1. Update state.json: status → "completed"
2. Update TODO.md: [IMPLEMENTING] → [COMPLETED]
3. Create summary artifact
4. Final commit
```

**Missing**: Step to update plan file line 4 from `[NOT STARTED]` to `[COMPLETED]`

### Why This Happens

The plan file has **TWO LEVELS** of status:
1. **Plan-level status** (line 4): `- **Status**: [NOT STARTED]` - The plan's overall status
2. **Phase-level statuses** (within phases): `### Phase N: Name [COMPLETED]` - Individual phase progress

The synchronization protocol (and skill-implementer Stage 5 verification) only checks **phase-level statuses**, completely ignoring the **plan-level status** on line 4.

### Where Updates Should Happen

1. **skill-implementer/SKILL.md Postflight stage** (lines 76-77):
   ```
   4. **Postflight**: Read metadata file and update state + TODO using {file_metadata}
   ```
   Missing: Update plan file line 4 status

2. **Phase synchronization protocol** (lines 114-125):
   Missing: Update plan metadata status

3. **general-implementation-agent** (if it handles completion):
   Missing: Update plan file metadata status

## Evidence from OC_136

**After implementation**:
- state.json: `"status": "completed"` (updated correctly)
- TODO.md: `[COMPLETED]` (updated correctly)  
- implementation-003.md line 4: `[NOT STARTED]` (NOT updated!)

**This discrepancy appears in**:
- specs/OC_136_design_and_implement_remember_command_for_intelligent_memory_management/plans/implementation-003.md line 4

**All phases show [COMPLETED]**:
- Phase 1: Vault Structure and Configuration [COMPLETED]
- Phase 2: Basic /remember Command... [COMPLETED]
- Phase 3: MCP Server Integration... [COMPLETED]
- Phase 4: Integration Testing and Documentation [COMPLETED]

But the plan's overall status (line 4) still says [NOT STARTED]

## Why Previous Fixes Failed

1. **OC_131** (sync_state_todo_plan_during_implementation): Only synchronized state.json and TODO.md
2. **OC_133** (fix_planner_agent_format): Fixed format compliance but not status synchronization
3. **skill-implementer verification**: Only checks phase statuses, not plan metadata status

All previous attempts addressed the phase-level statuses or the two-file synchronization (state.json + TODO.md), but **missed the plan file's metadata status on line 4**.

## Required Fix

### Option 1: Update Synchronization Protocol (Recommended)

Modify the phase synchronization protocol in `docs/guides/phase-synchronization.md`:

**Section 3: Implementation Complete (Lines 114-125)**

Add step 3:
```
3. Update plan file line 4: [NOT STARTED] → [COMPLETED]
```

### Option 2: Update skill-implementer

Add to skill-implementer/SKILL.md Stage 4 (Postflight):
- Read plan file path from metadata
- Update line 4 status from [NOT STARTED] to [COMPLETED]
- Use sed or Edit tool to change the status

### Option 3: Update general-implementation-agent

Add completion step to agent specification:
- When marking task complete, update all three locations
- Use regex: `- \*\*Status\*\*: \[(NOT STARTED|IN PROGRESS)\]` → `- **Status**: [COMPLETED]`

## Synchronization Matrix

| When | state.json | TODO.md | Plan File Line 4 | Phase Statuses |
|------|-----------|---------|------------------|----------------|
| /implement starts | "implementing" | [IMPLEMENTING] | Should be [NOT STARTED] | Each phase [NOT STARTED] → [IN PROGRESS] |
| Phase completes | No change | No change | No change | [IN PROGRESS] → [COMPLETED] |
| /implement completes | "completed" | [COMPLETED] | **Should be [COMPLETED]** ❌ | Each phase [COMPLETED] |

## Verification Checklist for Fix

- [ ] When task completes, line 4 of plan file shows [COMPLETED]
- [ ] When task completes, TODO.md shows [COMPLETED]  
- [ ] When task completes, state.json shows "completed"
- [ ] All three are updated atomically in the same commit
- [ ] Resume behavior still works (checks phase statuses)

## Files to Modify

1. **docs/guides/phase-synchronization.md** - Add plan metadata status to synchronization protocol
2. **skills/skill-implementer/SKILL.md** - Add plan file status update to Postflight stage
3. **agent/subagents/general-implementation-agent.md** - Add plan status update to completion logic

## Impact

This fix ensures that:
1. Plan files accurately reflect overall task status
2. No confusion when resuming (plan says [NOT STARTED] but phases are [COMPLETED])
3. Consistency across all three synchronization points
4. Future implementations automatically stay synchronized

## References

- **phase-synchronization.md**: Current protocol (missing plan metadata status)
- **skill-implementer/SKILL.md**: Stage 4-5 (missing plan status update)
- **OC_136 implementation-003.md**: Example of the discrepancy
- **OC_131**: Previous attempt at synchronization (incomplete)

## Notes

The fix should be backward-compatible:
- Existing plan files with wrong status won't break
- Next implementation will correct the status
- Phase statuses remain the source of truth for resume behavior
