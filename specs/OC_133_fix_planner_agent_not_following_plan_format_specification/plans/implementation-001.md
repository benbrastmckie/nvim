# Implementation Plan: Task #133

**Task**: OC_133 - Fix planner agent not following plan-format.md specification
**Version**: 001
**Created**: 2026-03-04
**Language**: meta
**Status**: [NOT STARTED]
**Effort**: 3 hours
**Dependencies**: None
**Research Inputs**: specs/OC_133_fix_planner_agent_not_following_plan_format_specification/reports/research-001.md
**Artifacts**: plans/implementation-001.md
**Standards**: .opencode/context/core/formats/plan-format.md, .opencode/context/core/standards/status-markers.md, .opencode/context/core/standards/documentation-standards.md
**Type**: meta
**Lean Intent**: false

## Overview

The research identified that planner-agent.md contains Stage 5 template and Stage 6a verification instructions that systematically produce plan files which contradict plan-format.md requirements. This plan fixes the root cause by updating planner-agent.md to align its templates and verification with the format standard. The changes focus on: (1) fixing phase heading format to include status markers, (2) removing incorrect `**Status**: [STATUS]` metadata lines, (3) correcting field names from `**Objectives**:`/`**Estimated effort**:` to `**Goal**:`/`**Timing**:`, and (4) removing `---` separators between phases.

## Goals & Non-Goals

**Goals**:
- Update planner-agent.md Stage 5 template to match plan-format.md exactly
- Fix planner-agent.md Stage 6a verification instructions to check correct patterns
- Remove incorrect example templates from planner-agent.md that show wrong format
- Test the corrected template by running /plan on a sample task

**Non-Goals**:
- Modifying skill-planner SKILL.md (context injection is already working correctly)
- Changing plan-format.md specification (the standard is correct, the agent is wrong)
- Updating any existing plan files (let them be as-is; focus on fixing future plans)
- Adding automated validation scripts beyond clear template instructions

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Template changes initially confuse the agent | Low | Medium | Clear instructions in agent definition to follow template exactly, not use old examples |
| Agent still produces wrong format due to learned patterns | Medium | Medium | Stage 6a verification explicitly checks and rejects non-compliant output |
| Verification instructions still ambiguous | Low | Medium | Use explicit examples showing correct vs incorrect patterns |
| Context window limits with longer instructions | Low | Low | Template is concise; only fixing specific mismatches |

## Implementation Phases

### Phase 1: Fix planner-agent.md Stage 5 Template [COMPLETED]

**Goal**: Replace Stage 5 template section to match plan-format.md exactly

**Tasks**:
- [ ] Read current planner-agent.md Stage 5 (lines 237-270)
- [ ] Rewrite template to show correct format:
  - Heading: `### Phase N: {Name} [NOT STARTED]`
  - **Goal**: field (not **Objectives**)
  - **Tasks**: checklist (keep this, it's correct)
  - **Timing**: field (not **Estimated effort**)
  - NO `---` separator after phase
  - NO separate `**Status**: [STATUS]` line
- [ ] Remove **Files to modify** and **Verification** from phase template (these go in Overview section, not phases)
- [ ] Verify the new template matches plan-format.md Example Skeleton exactly

**Timing**: 1 hour

**Files to modify**:
- `.opencode/agent/subagents/planner-agent.md` - Update Stage 5 template (lines 237-270)

**Verification**:
- [ ] Template includes status marker IN HEADING: `### Phase N: Name [STATUS]`
- [ ] Template uses **Goal**: (not Objectives)
- [ ] Template uses **Timing**: (not Estimated effort)
- [ ] Template has NO `**Status**: [STATUS]` line
- [ ] Template has NO `---` separator between phases

---

### Phase 2: Fix planner-agent.md Stage 6a Verification [COMPLETED]

**Goal**: Update verification instructions to explicitly check for correct patterns

**Tasks**:
- [ ] Read current planner-agent.md Stage 6a (lines 276-303)
- [ ] Rewrite verification section with explicit checks:
  - Check phase headings match pattern: `### Phase N: Name [STATUS]`
  - Check NO separate `**Status**: [STATUS]` lines exist anywhere
  - Check fields are **Goal**, **Tasks**, **Timing** (not Objectives, Estimated effort)
  - Check NO `---` separators between phases
- [ ] Add "Correct vs Incorrect" examples in verification section
- [ ] Ensure verification says: "If any required field or section is missing or incorrect, fix the plan file before writing success metadata"

**Timing**: 45 minutes

**Files to modify**:
- `.opencode/agent/subagents/planner-agent.md` - Update Stage 6a verification (lines 276-303)

**Verification**:
- [ ] Verification explicitly checks for status marker IN HEADING
- [ ] Verification explicitly rejects `**Status**: [STATUS]` lines
- [ ] Verification checks field names (**Goal**, **Timing**, not alternatives)
- [ ] Verification includes before/after examples of correct format

---

### Phase 3: Fix Example Templates in planner-agent.md [COMPLETED]

**Goal**: Remove or correct example templates that show wrong format

**Tasks**:
- [ ] Find example templates in planner-agent.md showing wrong format (around line 15-19)
- [ ] Update example to show CORRECT format:
  ```markdown
  ### Phase 1: Foundation & Formats [COMPLETED]
  
  **Goal**: Replace deprecated format files
  
  **Tasks**:
  - [ ] Read .claude format file
  - [ ] Write to .opencode location
  
  **Timing**: 1 hour
  ```
- [ ] Check Critical Requirements section (lines 420-432) for any format-related items
- [ ] Add explicit requirement: "Phase headings MUST include status marker: ### Phase N: Name [STATUS]"
- [ ] Add explicit requirement: "Must NOT use separate `**Status**: [STATUS]` lines"

**Timing**: 30 minutes

**Files to modify**:
- `.opencode/agent/subagents/planner-agent.md` - Fix example templates and Critical Requirements

**Verification**:
- [ ] Example templates show correct heading format with [STATUS]
- [ ] Example templates use **Goal** and **Timing**
- [ ] Example templates have no `**Status**: [STATUS]` line
- [ ] Critical Requirements explicitly forbid wrong patterns

---

### Phase 4: Test Corrected Template [IN PROGRESS]

**Goal**: Verify the corrected planner-agent produces compliant plan files

**Tasks**:
- [ ] Create a test task with simple description (e.g., "Create a simple documentation file")
- [ ] Run `/plan` on the test task
- [ ] Inspect generated plan file for compliance:
  - Phase headings have format: `### Phase N: Name [NOT STARTED]`
  - NO separate `**Status**: [STATUS]` lines
  - Fields are **Goal**, **Tasks**, **Timing**
  - NO `---` separators between phases
- [ ] If plan is non-compliant, identify which instruction wasn't followed
- [ ] Iterate if needed to ensure template works correctly

**Timing**: 45 minutes

**Test approach**:
- Use a minimal existing task or create task OC_134 as test
- Run `/plan OC_134` and inspect output
- Document any remaining issues found during testing

**Verification**:
- [ ] Test plan file has correct phase heading format
- [ ] Test plan file has NO separate status metadata lines
- [ ] Test plan file uses correct field names
- [ ] Test plan file has no phase separators

---

## Testing & Validation

- [ ] Phase 1 complete: Stage 5 template matches plan-format.md exactly
- [ ] Phase 2 complete: Stage 6a verification explicitly checks all format requirements
- [ ] Phase 3 complete: Example templates show correct format only
- [ ] Phase 4 complete: Test plan generation produces compliant output

## Artifacts & Outputs

- `.opencode/agent/subagents/planner-agent.md` - Updated with correct templates and verification

## Rollback/Contingency

If the updated template causes issues:
1. Keep original planner-agent.md backed up
2. If new template fails, revert to original and identify remaining issues
3. The changes are additive (more explicit instructions), so minimal risk of breaking existing functionality

## Success Criteria

- [ ] planner-agent.md Stage 5 template produces phase headings with status markers IN the heading
- [ ] planner-agent.md Stage 5 template produces NO separate `**Status**: [STATUS]` lines
- [ ] planner-agent.md Stage 5 template uses **Goal** and **Timing** (not alternatives)
- [ ] planner-agent.md Stage 6a verification explicitly checks for correct format
- [ ] planner-agent.md example templates show only correct format
- [ ] Running `/plan` on test task produces plan-format-compliant output
