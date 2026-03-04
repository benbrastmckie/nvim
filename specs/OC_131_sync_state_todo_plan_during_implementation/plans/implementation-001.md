# Implementation Plan: Task #131

**Task**: OC_131 - Synchronize state.json, TODO.md, and plan files during /implement execution
**Version**: 001
**Created**: 2026-03-04
**Language**: meta

## Overview

This plan strengthens the phase status synchronization across state.json, TODO.md, and plan files during implementation. The research identified that while the infrastructure exists (skill-status-sync, checkpoint patterns, postflight control), enforcement of phase status updates in plan files needs strengthening. The solution involves auditing current compliance, updating the `/implement` command specification, enhancing `skill-implementer` postflight verification, and testing the enhanced workflow.

## Phases

### Phase 1: Audit Current Implementation Compliance

**Status**: [COMPLETED]
**Completed**: 2026-03-04

**Objectives**:
1. Examine recent task implementations (OC_125-OC_130) to verify phase status updates in plan files
2. Identify patterns where phase statuses are correctly/incorrectly updated
3. Document gaps between specification and actual implementation behavior

**Files to examine**:
- `specs/125_epidemiology_r_extension/plans/implementation-001.md` - Check phase status markers
- `specs/126_fix_ao_picker_extension_loading_path/plans/implementation-001.md` - Check phase status markers
- `specs/127_migrate_opencode_md_to_readme_and_rename_quick_start_to_installation/plans/implementation-001.md` - Check phase status markers
- `specs/128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/plans/implementation-001.md` - Check phase status markers
- `specs/128_ensure_task_command_only_creates_tasks_and_never_implements_solutions_automatically/plans/implementation-002.md` - Check phase status markers
- `specs/130_make_opencode_self_contained/plans/implementation-001.md` - Check phase status markers
- `.opencode/commands/implement.md` - Current specification
- `.opencode/skills/skill-implementer/SKILL.md` - Current skill definition

**Steps**:
1. Read each plan file and note current phase status markers ([NOT STARTED], [IN PROGRESS], [COMPLETED], [PARTIAL])
2. Compare with expected progress based on task completion state
3. Identify any phases that should be [COMPLETED] but are still marked otherwise
4. Check implement.md Step 6 for explicit phase sync requirements
5. Check skill-implementer for phase verification in postflight

**Audit Results**:

**Task Compliance Summary:**
| Task | Status | Phase 1 | Phase 2 | Phase 3 | Phase 4 | Phase 5 |
|------|--------|---------|---------|---------|---------|---------|
| OC_125 | COMPLETED | [COMPLETED] | [COMPLETED] | [COMPLETED] | [COMPLETED] | - |
| OC_126 | COMPLETED | [COMPLETED] | [COMPLETED] | [COMPLETED] | [COMPLETED] | - |
| OC_127 | COMPLETED | [COMPLETED] | [COMPLETED] | [COMPLETED] | [COMPLETED] | [COMPLETED] |
| OC_128 | COMPLETED | [COMPLETED] | [COMPLETED] | [COMPLETED] | [COMPLETED] | - |
| OC_128-002 | COMPLETED | [COMPLETED] | [COMPLETED] | [COMPLETED] | [COMPLETED] | - |
| OC_130 | COMPLETED | [COMPLETED] | [COMPLETED] | [COMPLETED] | - | - |

**Compliance Rate**: 100% (27/27 phases correctly marked)

**Findings**:
1. **implement.md (command specification)**: Has explicit phase status update requirements in Step 6 (lines 70-79):
   - "Update phase status to `[IN PROGRESS]` in the plan file" 
   - "Update phase status to `[COMPLETED]` in the plan file"
   - Per-phase commit requirement exists

2. **skill-implementer/SKILL.md**: Lacks postflight phase verification
   - Only 4 stages: LoadContext, Preflight, Delegate, Postflight
   - No Stage 5 for verifying phase status consistency
   - Missing verification that plan.md phase markers match metadata.phases_completed

**Root Causes of Potential Non-Compliance**:
- No automated verification to catch out-of-sync phase statuses
- Relies entirely on agents to manually update phase markers
- No recovery mechanism when phase statuses don't match metadata

**Verification**:
- [✓] Audit report documenting findings for each task (OC_125-OC_130)
- [✓] Summary of compliance rate (100% of phases correctly marked)
- [✓] Identification of root causes for any non-compliance (skill-implementer lacks verification)

---

### Phase 2: Update /implement Command Specification

**Status**: [NOT STARTED]
**Estimated effort**: 1 hour

**Objectives**:
1. Strengthen Step 6 of `/implement` command to explicitly require phase status updates
2. Add detailed Phase Execution Requirements section
3. Emphasize that phase status in plan file is the source of truth for resume points

**Files to modify**:
- `.opencode/commands/implement.md` - Update Step 6 with explicit requirements

**Steps**:
1. Read current implement.md
2. Replace Step 6 with explicit phase execution protocol:
   - Mark phase starting: Update phase heading to `[IN PROGRESS]`
   - Execute steps: Perform all file operations and verification
   - Mark phase complete: Update phase heading to `[COMPLETED]`
   - Update partial_progress: Track phase completion in metadata
   - Per-phase commit: Commit with message `task OC_N phase P: name`
3. Add note: "Phase status in plan file is the source of truth for resume points"
4. Update the example workflow to show status transitions explicitly

**Verification**:
- [ ] implement.md updated with clear Phase Execution Requirements
- [ ] All status markers ([NOT STARTED] → [IN PROGRESS] → [COMPLETED]/[PARTIAL]) documented
- [ ] Per-phase commit requirement explicitly stated

---

### Phase 3: Enhance skill-implementer Postflight Verification

**Status**: [NOT STARTED]
**Estimated effort**: 1 hour

**Objectives**:
1. Add postflight verification stage to skill-implementer that checks phase status consistency
2. Verify that completed phases in plan file match metadata.phases_completed count
3. Add recovery mechanism to update plan file if phase statuses are out of sync

**Files to modify**:
- `.opencode/skills/skill-implementer/SKILL.md` - Add postflight verification stage

**Steps**:
1. Read current skill-implementer/SKILL.md
2. Add new Stage 5: Postflight Verification
   - Read plan file phases
   - Extract phase status markers
   - Compare with metadata.phases_completed count
   - If mismatch detected, update plan file phase statuses to match
   - Log warning if any corrections were made
3. Update execution flow to include verification stage
4. Add validation check: "Phase status markers match metadata.phases_completed"

**Verification**:
- [ ] skill-implementer updated with postflight verification stage
- [ ] Verification logic documented (read plan → compare → update if needed)
- [ ] Recovery mechanism for out-of-sync phases described

---

### Phase 4: Test Enhanced Workflow

**Status**: [NOT STARTED]
**Estimated effort**: 1 hour

**Objectives**:
1. Test the updated implementation workflow on a small sample task
2. Verify that phase status updates occur correctly during implementation
3. Confirm that skill-implementer postflight verification catches and corrects any issues

**Test approach**:
- Use a simple existing task or create a test task with minimal phases
- Execute /implement and verify each phase status transition
- Check that postflight verification correctly validates phase states

**Steps**:
1. Create a minimal test plan with 2 phases
2. Run /implement on the test task
3. Monitor phase status markers throughout execution
4. Verify that skill-implementer postflight checks and validates phase statuses
5. Confirm that final plan file shows correct [COMPLETED] markers

**Verification**:
- [ ] Test task implemented with correct phase status tracking
- [ ] Each phase properly marked [IN PROGRESS] → [COMPLETED]
- [ ] Postflight verification correctly validates phase consistency
- [ ] Resume functionality works correctly based on plan file status

---

### Phase 5: Document Phase Synchronization Protocol

**Status**: [NOT STARTED]
**Estimated effort**: 30 minutes

**Objectives**:
1. Create comprehensive documentation of the phase synchronization protocol
2. Document the complete workflow from status transition to verification
3. Provide examples of correct vs incorrect phase status usage

**Files to create**:
- `.opencode/docs/guides/phase-synchronization.md` - New documentation file

**Steps**:
1. Create documentation covering:
   - Overview of the three-file synchronization (state.json, TODO.md, plan.md)
   - Phase status lifecycle: [NOT STARTED] → [IN PROGRESS] → [COMPLETED]/[PARTIAL]
   - Responsibilities: command spec → agent → skill postflight verification
   - Resume behavior based on plan file status markers
   - Troubleshooting guide for phase sync issues
2. Include examples from updated implement.md and skill-implementer
3. Add troubleshooting section for common phase sync issues

**Verification**:
- [ ] Phase synchronization guide created and reviewed
- [ ] Documentation covers all three files (state.json, TODO.md, plan.md)
- [ ] Examples provided for correct implementation
- [ ] Troubleshooting guide includes common issues and solutions

---

## Dependencies

- None (all files to modify are in .opencode/ directory)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent compliance issues persist | High | Medium | Postflight verification in skill-implementer will catch and auto-correct phase status issues |
| Phase sync adds overhead to implementation | Low | Low | Verification is quick (just reading plan file and comparing counts) |
| Existing tasks have incorrect phase statuses | Medium | High | Can be fixed retroactively if needed; new tasks will follow correct protocol |
| Resume functionality breaks | High | Low | Extensive testing in Phase 4 ensures resume works correctly with new protocol |

## Success Criteria

- [ ] Phase 1: Audit report shows clear picture of current compliance (OC_125-OC_130)
- [ ] Phase 2: `/implement` command specification explicitly requires phase status updates
- [ ] Phase 3: `skill-implementer` includes postflight phase verification
- [ ] Phase 4: Test implementation demonstrates correct phase status tracking
- [ ] Phase 5: Phase synchronization protocol documented in `.opencode/docs/guides/`
- [ ] All three files (state.json, TODO.md, plan.md) remain synchronized during implementation
