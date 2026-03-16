# Implementation Plan: Task #217

- **Task**: 217 - Revise grant workflow order and address other improvements
- **Status**: [COMPLETE]
- **Effort**: 2-3 hours
- **Dependencies**: None
- **Research Inputs**: [01_grant-improvements.md](../reports/01_grant-improvements.md)
- **Artifacts**: plans/02_workflow-improvements.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

This plan addresses workflow order inconsistencies and related improvements in the grant extension. The primary issue is that draft and budget phases appear after plan in documented workflows, but logically should precede planning since they are exploratory activities that inform plan creation.

### Research Integration

Integrated findings from `01_grant-improvements.md`:
- Workflow order documented incorrectly in 3 locations
- Routing table mismatch (plan -> proposal_draft?)
- Missing prerequisite validation
- Status transition ambiguity (draft/budget both set "planned")

## Goals & Non-Goals

**Goals**:
- Correct workflow order in all documented locations (draft/budget before plan)
- Clarify routing table documentation
- Add context-aware "Next Step" guidance
- Improve validation for draft mode prerequisites

**Non-Goals**:
- Adding new status values (draft_completed, budget_completed) - out of scope for this task
- Adding `/grant N --status` command - separate feature request
- Changing progress_track workflow - deprecated feature
- Modifying manifest.json routing - requires separate verification

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing user workflows | Medium | Low | Changes are documentation-only, no code changes |
| Missing an update location | Low | Medium | Systematic phase-by-phase verification |
| Incorrect routing table interpretation | Medium | Medium | Document current behavior, note for future investigation |

## Implementation Phases

### Phase 1: Update grant.md Workflow Order [COMPLETED]

**Goal**: Correct workflow order in main command documentation

**Tasks**:
- [ ] Update Task Creation Output (lines 137-143) to show draft/budget before plan
- [ ] Update Output Formats section (lines 444-456) to show draft/budget before plan
- [ ] Correct routing table (lines 415-420) to clarify /plan behavior
- [ ] Add prerequisite validation note for --draft mode (after line 177)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md`

**Verification**:
- Grep for "Recommended workflow" and verify order shows: research -> draft -> budget -> plan -> implement

---

### Phase 2: Update EXTENSION.md Workflow Order [COMPLETED]

**Goal**: Correct workflow order in user-facing extension documentation

**Tasks**:
- [ ] Update Recommended Workflow section (lines 127-134) to show draft/budget before plan
- [ ] Update Task Creation Mode example (lines 31-38) to show correct workflow
- [ ] Verify Core Command Integration table (lines 114-118) describes actual behavior

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/EXTENSION.md`

**Verification**:
- Grep for "Recommended workflow" and verify order shows: create -> research -> draft -> budget -> plan -> implement

---

### Phase 3: Update Next Step Guidance [COMPLETED]

**Goal**: Make "Next:" suggestions context-aware

**Tasks**:
- [ ] Update Draft Mode output (line 213) to suggest budget next, then plan after both complete
- [ ] Update Budget Mode output (line 260) to suggest plan (not implement)
- [ ] Add note in Output Formats explaining the workflow sequence

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/commands/grant.md`

**Verification**:
- Verify draft output suggests: "Next: /grant {N} --budget, then /plan {N}"
- Verify budget output suggests: "Next: /plan {N}"

---

### Phase 4: Update SKILL.md Return Messages [COMPLETED]

**Goal**: Align skill return messages with corrected workflow

**Tasks**:
- [ ] Update Proposal Draft Success message (lines 497-500) to recommend budget then plan
- [ ] Update Budget Development Success message (lines 503-511) to recommend plan next
- [ ] Verify status mapping table accurately reflects behavior (lines 317-329)

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/skills/skill-grant/SKILL.md`

**Verification**:
- Verify draft success recommends: "Run /grant {N} --budget next"
- Verify budget success recommends: "Run /plan {N} to create implementation plan"

---

### Phase 5: Update grant-agent.md Documentation [COMPLETED]

**Goal**: Align agent documentation with corrected workflow

**Tasks**:
- [ ] Review Stage 4: Execute Workflow section for any workflow order references
- [ ] Verify assemble workflow validation prereqs (lines 296-301) match expected flow
- [ ] Update any example returns that show workflow order

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/agents/grant-agent.md`

**Verification**:
- Confirm agent documentation aligns with corrected workflow

---

### Phase 6: Final Verification [COMPLETED]

**Goal**: Verify all changes are consistent across files

**Tasks**:
- [ ] Grep all modified files for "workflow" to find any missed references
- [ ] Verify no conflicting workflow orders remain
- [ ] Run a conceptual walkthrough of the complete grant flow

**Timing**: 15 minutes

**Verification**:
- All files show: research -> draft -> budget -> plan -> implement
- No conflicting documentation remains

## Testing & Validation

- [ ] Grep test: `grep -rn "Recommended workflow" .claude/extensions/present/` shows consistent order
- [ ] Grep test: `grep -rn "Next:" .claude/extensions/present/commands/grant.md` shows correct suggestions
- [ ] Manual review: Read through each updated section to verify coherence

## Artifacts & Outputs

- plans/02_workflow-improvements.md (this file)
- Modified: `.claude/extensions/present/commands/grant.md`
- Modified: `.claude/extensions/present/EXTENSION.md`
- Modified: `.claude/extensions/present/skills/skill-grant/SKILL.md`
- Modified: `.claude/extensions/present/agents/grant-agent.md`
- summaries/03_workflow-improvements-summary.md (post-implementation)

## Rollback/Contingency

All changes are documentation-only. To rollback:
1. Use `git checkout HEAD~1 -- .claude/extensions/present/` to restore all modified files
2. No runtime behavior changes, so no additional rollback needed

## Implementation Notes

### Correct Workflow Order

The correct workflow should be documented as:
```
1. /grant "Description" - Create task
2. /research N - Research funders
3. /grant N --draft - Draft narrative (exploratory)
4. /grant N --budget - Develop budget (exploratory)
5. /plan N - Create plan informed by drafts
6. /implement N - Assemble to grants/{N}_{slug}/
```

**Rationale**: Draft and budget are exploratory phases that inform planning. The plan should:
- Be aware of what sections have been drafted
- Incorporate budget constraints into scope
- Reference existing artifacts in planning decisions

### Routing Table Clarification

The current routing table in grant.md shows `/plan N` routing to `skill-grant (proposal_draft)`. This appears to be a documentation error. The actual behavior should be verified, but for this task, clarify the documentation to indicate that /plan creates an implementation plan (not a proposal draft).

### Future Improvements (Out of Scope)

These improvements were identified in research but are out of scope for this task:
- Adding draft_status/budget_status tracking fields
- Adding `/grant N --status` command
- Validating prerequisite artifacts before draft/budget/assemble
- Making routing explicit in manifest.json
