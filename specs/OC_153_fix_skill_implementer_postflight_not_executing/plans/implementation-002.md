# Implementation Plan: Fix Skill Implementer Postflight Not Executing

- **Task**: 153 - fix_skill_implementer_postflight_not_executing
- **Status**: [NOT STARTED]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: reports/research-001.md, reports/research-002.md
- **Artifacts**: plans/implementation-002.md (this file)
- **Standards**:
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/standards/documentation-standards.md
  - .opencode/context/core/standards/task-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Fix the critical issue where task status is not updated to [COMPLETED] after implementation finishes. The root cause is that commands delegate to skills via the `skill` tool, which only loads skill definitions without executing preflight/postflight workflows. Commands must execute status updates themselves before delegating to agents and after agents complete.

### Research Integration

This plan implements the findings from research-001.md and research-002.md, which identified that:

1. The `skill` tool loads SKILL.md content but does NOT execute workflows
2. Commands currently SKIP preflight/postflight execution - this is the bug
3. Commands incorrectly expect skills to execute workflows, but skills only define them
4. The orchestrator manually compensates for missing postflight (observed in OC_153)
5. OC_151 demonstrates the issue conclusively - status stuck at "planning" despite completion
6. Commands must execute preflight (status → "in_progress") BEFORE delegating to agents
7. Commands must execute postflight (status → "completed", link artifacts) AFTER agents return
8. Three command files need updates: implement.md, plan.md, research.md

## Goals & Non-Goals

**Goals**:
- Update `.opencode/commands/implement.md` with proper preflight/postflight execution
- Update `.opencode/commands/plan.md` with proper preflight/postflight execution
- Update `.opencode/commands/research.md` with proper preflight/postflight execution
- Clarify skill documentation to indicate they are context definitions only
- Remediate OC_151 status (currently stuck in "planning")
- Verify all commands work correctly with end-to-end test

**Non-Goals**:
- Modify the `skill` tool behavior (it works as designed)
- Rewrite skill SKILL.md files (only add clarification notes)
- Modify the orchestrator routing logic
- Create new tools or infrastructure

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Multiple command files need similar updates | High | Certain | Create reusable pattern, apply systematically |
| Testing all commands takes time | Medium | High | Start with implement.md, verify, then replicate |
| Breaking existing functionality | High | High | Test on non-critical task (OC_152) first; incremental rollout |
| Partial fix leaves some commands broken | Medium | Medium | Comprehensive testing checklist in Phase 5 |
| OC_151 remediation fails | Medium | Low | Manual status update with direct file edits |

## Implementation Phases

### Phase 1: implement.md Command Update [COMPLETED]

**Goal**: Commands incorrectly expect skills to execute postflight - add explicit command-level execution using skill-status-sync skill

**Tasks**:
- [ ] Read current `.opencode/commands/implement.md` structure
- [ ] Add Preflight stage (Step 5): Update status to "implementing" before delegation
- [ ] Update Delegation stage (Step 6): Call skill-implementer via Task tool
- [ ] Add Postflight stage (Step 7): Read .return-meta.json, update status to "completed", link artifacts
- [ ] Document the new workflow with clear examples
- [ ] Add error handling for failed status updates

**Timing**: 1.5 hours

**Dependencies**: None

**Verification**:
- [ ] implement.md contains preflight stage that updates status to "implementing"
- [ ] implement.md contains postflight stage that reads .return-meta.json
- [ ] implement.md updates status to "completed" after successful implementation
- [ ] implement.md links artifacts to state.json and TODO.md

### Phase 2: plan.md Command Update [IN PROGRESS]

**Goal**: Apply same preflight/postflight pattern to plan.md

**Tasks**:
- [ ] Read current `.opencode/commands/plan.md` structure
- [ ] Add Preflight stage: Update status to "planning" before delegation to planner-agent
- [ ] Update Delegation stage: Call planner-agent via Task tool
- [ ] Add Postflight stage: Read .return-meta.json, update status to "planned", link plan artifact
- [ ] Use status values: preflight="planning", postflight="planned", plan marker=[PLANNED]

**Timing**: 45 minutes

**Dependencies**: Phase 1 complete (use same pattern)

**Verification**:
- [ ] plan.md contains preflight with status="planning"
- [ ] plan.md contains postflight with status="planned"
- [ ] plan.md links created plan file to TODO.md

### Phase 3: research.md Command Update [NOT STARTED]

**Goal**: Apply same preflight/postflight pattern to research.md

**Tasks**:
- [ ] Read current `.opencode/commands/research.md` structure
- [ ] Add Preflight stage: Update status to "researching" before delegation
- [ ] Update Delegation stage: Call researcher-agent via Task tool
- [ ] Add Postflight stage: Read .return-meta.json, update status to "researched", link research report
- [ ] Use status values: preflight="researching", postflight="researched", plan marker=[RESEARCHED]

**Timing**: 45 minutes

**Dependencies**: Phase 2 complete (use same pattern)

**Verification**:
- [ ] research.md contains preflight with status="researching"
- [ ] research.md contains postflight with status="researched"
- [ ] research.md links created research report to TODO.md

### Phase 4: Skill Documentation Updates [NOT STARTED]

**Goal**: Clarify skill files to indicate they are context definitions only

**Tasks**:
- [ ] Update `.opencode/skills/skill-implementer/SKILL.md`: Add note that workflow is documentation only
- [ ] Update `.opencode/skills/skill-planner/SKILL.md`: Add note that workflow is documentation only
- [ ] Update `.opencode/skills/skill-researcher/SKILL.md`: Add note that workflow is documentation only
- [ ] Add warning banner at top of each SKILL.md file

**Timing**: 30 minutes

**Dependencies**: None

**Verification**:
- [ ] Each skill file has clear notice: "This file defines context injection patterns only"
- [ ] Each skill file states: "Commands must execute status updates, not this skill"

### Phase 5: OC_151 Status Remediation [NOT STARTED]

**Goal**: Fix OC_151 which is stuck in "planning" status despite being completed

**Tasks**:
- [ ] Read current OC_151 state in specs/state.json
- [ ] Read current OC_151 entry in specs/TODO.md
- [ ] Read OC_151 plan file to verify all phases completed
- [ ] Update specs/state.json: "planning" → "completed"
- [ ] Update specs/TODO.md: [PLANNING] → [COMPLETED]
- [ ] Update plan file header: [NOT STARTED] → [COMPLETED]
- [ ] Add artifact links to TODO.md for OC_151

**Timing**: 30 minutes

**Dependencies**: None (can run in parallel with Phase 4)

**Verification**:
- [ ] specs/state.json OC_151 status is "completed"
- [ ] specs/TODO.md OC_151 shows [COMPLETED]
- [ ] OC_151 plan file header shows [COMPLETED]
- [ ] Artifact links present in TODO.md

### Phase 6: End-to-End Testing [NOT STARTED]

**Goal**: Verify the complete workflow works for all three commands

**Tasks**:
- [ ] Create test task (OC_154 or use OC_152 if available)
- [ ] Test `/research` command: Verify status transitions to [RESEARCHED] without manual intervention
- [ ] Test `/plan` command: Verify status transitions to [PLANNED] without manual intervention
- [ ] Test `/implement` command: Verify status transitions to [COMPLETED] without manual intervention
- [ ] Verify all files updated: state.json, TODO.md, plan file
- [ ] Document any issues found and create follow-up tasks

**Timing**: 30 minutes

**Dependencies**: Phases 1-5 complete

**Verification**:
- [ ] All three commands update status correctly
- [ ] Status updates happen without manual orchestrator intervention
- [ ] Artifacts are linked in state.json
- [ ] Artifacts are linked in TODO.md
- [ ] No manual intervention needed for status updates

## Testing & Validation

### Unit Tests (Manual)

- [ ] Verify implement.md preflight logic: status updates to "implementing"
- [ ] Verify implement.md postflight logic: reads .return-meta.json correctly
- [ ] Verify plan.md uses correct status values (planning/planned)
- [ ] Verify research.md uses correct status values (researching/researched)

### Integration Tests (End-to-End)

- [ ] Create new task and run full workflow: research → plan → implement
- [ ] Verify status progression: not_started → researching → researched → planning → planned → implementing → completed
- [ ] Verify artifact linking at each stage
- [ ] Verify OC_151 remediation worked correctly

### Validation Checklist

- [ ] All command files updated with preflight/postflight
- [ ] All skill files have clarification documentation
- [ ] OC_151 status remediated
- [ ] End-to-end test passes
- [ ] Status updates happen automatically without orchestrator intervention
- [ ] No regressions in existing functionality

## Artifacts & Outputs

1. **Modified Command Files**:
   - `.opencode/commands/implement.md` (with preflight/postflight)
   - `.opencode/commands/plan.md` (with preflight/postflight)
   - `.opencode/commands/research.md` (with preflight/postflight)

2. **Modified Skill Documentation**:
   - `.opencode/skills/skill-implementer/SKILL.md` (with clarification note)
   - `.opencode/skills/skill-planner/SKILL.md` (with clarification note)
   - `.opencode/skills/skill-researcher/SKILL.md` (with clarification note)

3. **Remediated Task Files**:
   - `specs/state.json` (OC_151 status fixed)
   - `specs/TODO.md` (OC_151 entry updated)
   - `specs/OC_151_*/plans/implementation-001.md` (header updated)

4. **This Plan**:
   - `specs/OC_153_fix_skill_implementer_postflight_not_executing/plans/implementation-002.md`

## Rollback/Contingency

### If implement.md Update Fails
1. Restore from git: `git checkout -- .opencode/commands/implement.md`
2. Analyze failure reason
3. Try Option 2 (Direct Status Management) instead of Option 1

### If OC_151 Remediation Fails
1. Document current state
2. Manually edit files using direct file operations
3. Verify changes with cat/head commands

### If End-to-End Test Fails
1. Check which command failed
2. Review that command's preflight/postflight logic
3. Fix and retest individually before full workflow test

### General Rollback Strategy
- All changes are to markdown files in .opencode/
- Use git to restore any file: `git checkout -- <filepath>`
- Changes are isolated to command documentation and skill docs
- No impact on core application code

## Success Criteria

1. **Functional**: All three commands (/research, /plan, /implement) automatically update task status
2. **OC_151 Remediated**: OC_151 shows [COMPLETED] in all files
3. **No Manual Intervention**: Status updates happen without user manually editing files
4. **Status Updates Without Orchestrator Intervention**: Commands execute postflight automatically - no manual compensation needed
5. **Artifacts Linked**: Created artifacts appear in TODO.md and state.json
6. **Documentation Clear**: Skill files clearly state they are context definitions only
7. **Tested**: End-to-end workflow test passes successfully

## Notes

### Current Bug Behavior

**Commands currently SKIP postflight execution**. This is the core bug being fixed:

1. Command delegates to skill
2. Skill loads definition but does NOT execute workflow
3. Subagent completes work
4. **Command does NOT execute postflight** (status remains in_progress)
5. Orchestrator manually compensates (seen in OC_153 execution)

### Pattern to Follow (from research-001.md)

**Preflight Stage** (Before Delegation):
```markdown
### 5. Execute Preflight

Update status to "implementing" BEFORE delegating to agent:
1. Call skill-status-sync skill to update state.json to "implementing"
2. Update specs/TODO.md to [IMPLEMENTING]
3. Validate status was updated
```

**Delegation Stage**:
```markdown
### 6. Delegate to Agent

Call Task tool with subagent_type="general-implementation-agent" to execute phases
```

**Postflight Stage** (After Agent Returns):
```markdown
### 7. Execute Postflight

After agent returns:
1. Read .return-meta.json for artifacts and status
2. Call skill-status-sync to update state.json to "completed"
3. Update specs/TODO.md to [COMPLETED]
4. Link artifacts in state.json
5. Add artifact links to TODO.md
6. Create git commit
```

### Status Value Mapping

| Command | Preflight Status | Postflight Status | Plan Marker |
|---------|------------------|-------------------|-------------|
| /research | researching | researched | [RESEARCHED] |
| /plan | planning | planned | [PLANNED] |
| /implement | implementing | completed | [COMPLETED] |

## Revision History

- **implementation-001.md**: Initial plan based on research-001.md
- **implementation-002.md** (this file): Revised based on research-002.md validation
  - Added explicit documentation of current bug (commands SKIP postflight)
  - Upgraded "breaking existing functionality" risk from Medium to High
  - Added success criterion: "Status updates without manual orchestrator intervention"
  - Clarified Phase 1 goal to document the bug explicitly
  - Updated Research Inputs to reference both research-001.md and research-002.md
