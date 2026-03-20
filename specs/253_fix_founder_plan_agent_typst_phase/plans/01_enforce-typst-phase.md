# Implementation Plan: Task #253

- **Task**: 253 - Fix founder-plan-agent to enforce typst generation phase
- **Status**: [NOT STARTED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/253_fix_founder_plan_agent_typst_phase/reports/01_meta-research.md
- **Artifacts**: plans/01_enforce-typst-phase.md (this file)
- **Standards**:
  - .claude/context/core/formats/plan-format.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Fix the founder-plan-agent.md specification to always include a mandatory Phase 5 (Typst Document Generation) in generated plans. Currently the agent has Phase 5 as typst in the template, but the "Critical Requirements" section says "Always generate 4-phase structure" which contradicts the 5-phase template. The agent also lacks explicit enforcement language requiring Phase 5 to always be typst generation.

### Research Integration

**Research Report**: [01_meta-research.md](../reports/01_meta-research.md)

**Key Findings**:
- Agent spec shows Phase 5 as "Typst Document Generation" in template
- Critical Requirements section incorrectly states "Always generate 4-phase structure"
- Generated plans use varying Phase 5 names like "Documentation and Output" or "Report Generation"
- This causes implement agent to skip typst generation since phase is not explicitly named

## Goals & Non-Goals

**Goals**:
- Fix the agent specification to always generate Phase 5 as "Typst Document Generation"
- Update Critical Requirements to say "5-phase structure" instead of "4-phase"
- Add explicit enforcement language for typst phase requirement
- Ensure all report types (market-sizing, competitive-analysis, gtm-strategy) include typst phase

**Non-Goals**:
- Modifying the implement agent (it already respects plan phase names)
- Adding new features to the founder extension
- Changing typst template files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agent still generates variant phase names | Medium | Low | Add explicit MUST DO requirement with exact phase name |
| Breaking existing plans | Low | Very Low | Only affects new plan generation, existing plans unchanged |

## Implementation Phases

### Phase 1: Update Critical Requirements [NOT STARTED]

**Goal**: Fix the conflicting instruction from "4-phase" to "5-phase"

**Tasks**:
- [ ] Locate line 421-430 in founder-plan-agent.md (Critical Requirements section)
- [ ] Change "Always generate 4-phase structure" to "Always generate 5-phase structure with Phase 5 as Typst Document Generation"
- [ ] Add explicit MUST DO item: "Always name Phase 5 exactly 'Typst Document Generation'"

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Critical Requirements section

**Verification**:
- Critical Requirements section specifies 5-phase structure
- Phase 5 naming is explicitly required

---

### Phase 2: Add Phase Name Enforcement [NOT STARTED]

**Goal**: Add explicit enforcement language in the Phase Structure section to prevent variant names

**Tasks**:
- [ ] Locate Phase Structure by Report Type section (lines 279-300)
- [ ] Add bold enforcement note after each report type's phase list
- [ ] Add explicit text: "**Phase 5 MUST be named exactly 'Typst Document Generation'**"

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Phase Structure section

**Verification**:
- Each report type explicitly requires Phase 5 name
- No ambiguity about phase naming

---

### Phase 3: Verify Plan Template [NOT STARTED]

**Goal**: Ensure the plan template in Stage 5 has correct phase structure

**Tasks**:
- [ ] Review Stage 5: Generate Plan Artifact section (lines 187-277)
- [ ] Verify Phase 5 template is exactly "Typst Document Generation" (already correct per current file)
- [ ] Add comment or note reinforcing this phase is mandatory, not optional

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Stage 5 section (if needed)

**Verification**:
- Plan template shows exact Phase 5 name
- Template comment indicates phase is required

---

### Phase 4: Documentation and Summary [NOT STARTED]

**Goal**: Create implementation summary and verify changes

**Tasks**:
- [ ] Re-read modified file to verify all changes are consistent
- [ ] Verify no contradictions remain between template and requirements
- [ ] Create implementation summary

**Timing**: 15 minutes

**Files to modify**:
- `specs/253_fix_founder_plan_agent_typst_phase/summaries/01_enforce-typst-phase-summary.md` (new)

**Verification**:
- All changes are coherent
- No conflicting instructions remain
- Summary documents changes made

## Testing & Validation

- [ ] Grep for "4-phase" to ensure no instances remain
- [ ] Grep for "Phase 5" to verify consistent naming
- [ ] Review file for any remaining ambiguous language about phase structure

## Artifacts & Outputs

- `specs/253_fix_founder_plan_agent_typst_phase/plans/01_enforce-typst-phase.md` (this plan)
- `specs/253_fix_founder_plan_agent_typst_phase/summaries/01_enforce-typst-phase-summary.md` (after implementation)
- Modified: `.claude/extensions/founder/agents/founder-plan-agent.md`

## Rollback/Contingency

If changes cause issues with plan generation:
1. Revert founder-plan-agent.md to previous state via git
2. Review generated plans to understand actual agent behavior
3. Take more conservative approach to enforcement language
