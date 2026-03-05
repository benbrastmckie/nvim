# Implementation Plan: Stage-Progressive Context Loading in skill-planner

- **Task**: OC_139 - Implement stage-progressive loading demonstration in skill-planner
- **Status**: [NOT STARTED]
- **Effort**: 3 hours (3 phases × 1 hour each)
- **Dependencies**: OC_137 (completed)
- **Research Inputs**: 
  - [research-001.md](../reports/research-001.md) - Initial POC for progressive context loading
  - [research-002.md](../reports/research-002.md) - Systematic review of 11 skills with 2026 best practices
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**:
  - .opencode/context/core/formats/plan-format.md
  - .opencode/context/core/standards/status-markers.md
  - .opencode/context/core/standards/documentation-standards.md
  - .opencode/context/core/workflows/task-breakdown.md
- **Type**: markdown

## Overview

This implementation demonstrates stage-progressive context loading in skill-planner as a proof-of-concept for the progressive disclosure pattern. Currently, skill-planner loads all context files (status-markers.md, plan-format.md, task-breakdown.md) in Stage 1, but only status-markers.md is needed for preflight validation. Format specifications are only required in Stage 3 when creating the actual plan.

The implementation splits context loading across stages: minimal context in Stage 1 (for validation), full context in Stage 3 (for plan creation). This reduces initial context window usage by ~40-50% and establishes a pattern applicable to other skills.

## Goals & Non-Goals

**Goals**:
- Implement stage-progressive context loading in skill-planner
- Reduce Stage 1 context by 40-50% (from ~600 to ~200 lines)
- Maintain backward compatibility with existing behavior
- Create a replicable pattern for other skills (skill-implementer, skill-meta)
- Validate context reduction through measurement

**Non-Goals**:
- Modify planner-agent.md (the agent that creates plans)
- Change plan format or output structure
- Implement system-wide changes to all skills (this is POC only)
- Add complex conditional logic or configuration systems

## Risks & Mitigations

- **Risk**: Context not available when planner-agent needs it
  **Mitigation**: Stage 3 loads all format context before delegation; explicit timing in execution stages

- **Risk**: Validation errors due to missing context
  **Mitigation**: Keep status-markers.md in Stage 1; only defer format specs to Stage 3

- **Risk**: Breaking existing /plan command behavior
  **Mitigation**: Comprehensive testing with existing tasks; rollback plan via git revert

- **Risk**: Increased SKILL.md complexity
  **Mitigation**: Clear stage naming; inline comments; documentation update in context-loading-best-practices.md

## Implementation Phases

### Phase 1: Setup and Baseline Measurement [NOT STARTED]

**Goal**: Establish baseline metrics and prepare implementation environment

**Tasks**:
- [ ] Read current skill-planner/SKILL.md to understand existing structure
- [ ] Count current context lines loaded in Stage 1 (plan-format.md + status-markers.md + task-breakdown.md)
- [ ] Document baseline: total lines, file count, loading pattern
- [ ] Verify no pending changes in git workspace
- [ ] Create backup of current SKILL.md

**Timing**: 1 hour

### Phase 2: Implement Stage-Progressive Loading [NOT STARTED]

**Goal**: Modify skill-planner/SKILL.md to implement stage-progressive context loading

**Tasks**:
- [ ] Modify `<context_injection>` to load only status-markers.md initially
- [ ] Update Stage 1 name from "LoadContext" to "LoadMinimalContext"
- [ ] Keep Stage 2 (Preflight) unchanged - validates using status-markers
- [ ] Insert new Stage 3: "LoadFormatContext" that reads plan-format.md and task-breakdown.md
- [ ] Rename current Stage 3 to Stage 4: "Delegate" (planner-agent with full context)
- [ ] Update Stage 4 (Postflight) to Stage 5 if needed
- [ ] Ensure all stage IDs are sequential (1, 2, 3, 4, 5)
- [ ] Update execution flow documentation in SKILL.md
- [ ] Add comments explaining stage-progressive pattern

**Timing**: 1.5 hours

**Files Modified**:
- `.opencode/skills/skill-planner/SKILL.md`

### Phase 3: Testing and Validation [NOT STARTED]

**Goal**: Verify implementation works correctly and measure context reduction

**Tasks**:
- [ ] Test /plan OC_140 (or another researched task) to verify plan creation still works
- [ ] Verify context reduction: count lines in Stage 1 vs original
- [ ] Check that status validation still works (should fail on invalid status)
- [ ] Verify plan format compliance (uses plan-format.md correctly)
- [ ] Test error handling (what happens if context file missing)
- [ ] Document actual context reduction achieved
- [ ] Update TODO.md to mark phases complete
- [ ] Run git diff to review all changes

**Timing**: 0.5 hours

## Testing & Validation

- [ ] Plan creation works correctly for researched tasks
- [ ] Status validation still functions (test with invalid status)
- [ ] Plan format compliance maintained (verify against plan-format.md)
- [ ] Context reduction measured and documented
- [ ] No errors in skill execution flow
- [ ] Backward compatibility verified

## Artifacts & Outputs

- `.opencode/skills/skill-planner/SKILL.md` - Modified with stage-progressive loading
- `summaries/implementation-summary-YYYYMMDD.md` - Implementation summary with metrics
- Updated context-loading-best-practices.md (reference to new pattern)

## Rollback/Contingency

If implementation causes issues:

1. **Immediate rollback**: `git checkout .opencode/skills/skill-planner/SKILL.md`
2. **Verify rollback**: Test /plan command on a task
3. **Document issue**: Note what failed in implementation summary
4. **Alternative approach**: If stage-progressive loading causes problems, consider keeping all context in Stage 1 but documenting the opportunity cost

**Safety checks before rollback**:
- Ensure no other tasks in progress using /plan
- Verify git state is clean except for SKILL.md changes
- Confirm backup of original SKILL.md exists

## Success Criteria

1. Stage 1 context reduced by 40-50% (from ~600 to ~200-300 lines)
2. /plan command continues to work correctly
3. Plan format compliance maintained
4. Pattern documented for replication to other skills
5. No breaking changes to existing workflow

## References

- OC_137 Phase 7: Initial progressive disclosure analysis
- OC_139 research-001.md: POC research for skill-planner
- OC_139 research-002.md: Systematic review of all skills
- context-loading-best-practices.md: Current best practices guide
- skill-planner/SKILL.md: Target file for modification
