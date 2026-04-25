# Implementation Plan: Task #493

- **Task**: 493 - planner_per_phase_roadmap_updates
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: Task 490 (wired --roadmap flag through /plan to planner-agent)
- **Research Inputs**: specs/493_planner_per_phase_roadmap_updates/reports/01_per-phase-roadmap.md
- **Artifacts**: plans/01_per-phase-roadmap.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace the Stage 2.6 section in `.claude/agents/planner-agent.md` with a strengthened three-level roadmap integration pattern. The current bookend pattern (passive review phase + final update phase) becomes: (a) an active first phase that updates confident items immediately, (b) a per-phase roadmap checklist item in every core phase, and (c) a renamed final reconciliation phase. This is a single-section text replacement in one file.

### Research Integration

The research report confirmed that only `.claude/agents/planner-agent.md` Stage 2.6 (lines 78-89) requires changes. No modifications to plan-format.md, roadmap-format.md, roadmap-update.md, or general-implementation-agent.md are needed. The implementation agent executes roadmap edits as standard Edit operations without special awareness. The report provides the complete replacement text.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation requested (roadmap_flag is false).

## Goals & Non-Goals

**Goals**:
- Strengthen Phase 1 from passive "Review and Snapshot" to active "Roadmap Assessment and Initial Update" that marks confident items
- Add a per-phase roadmap update checklist item to every core implementation phase
- Rename final phase to "Final ROADMAP.md Reconciliation" with verification duties

**Non-Goals**:
- Modifying plan-format.md or any other format file
- Changing the implementation agent's behavior
- Adding roadmap awareness to non-planner agents

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Per-phase roadmap steps add noise to simple phases | Low | Medium | Include "no items to update (verify)" for phases without roadmap items |
| Phase 1 updates items prematurely | Medium | Low | Phase 1 only marks items from completed dependencies; per-phase steps handle current-task completions |
| Replacement text misaligned with surrounding sections | Low | Low | Verify line boundaries match exactly before and after edit |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Replace Stage 2.6 in planner-agent.md [NOT STARTED]

**Goal**: Replace the current Stage 2.6 text with the three-level roadmap integration pattern from the research report.

**Tasks**:
- [ ] Read `.claude/agents/planner-agent.md` and locate Stage 2.6 (lines 78-89)
- [ ] Replace the entire Stage 2.6 section (from `### Stage 2.6:` header through the line before `### Stage 3:`) with the new three-level pattern containing: (a) "Roadmap Assessment and Initial Update" first phase, (b) per-phase roadmap step requirement for core phases, (c) "Final ROADMAP.md Reconciliation" last phase
- [ ] Verify the replacement preserves correct markdown heading levels and indentation
- [ ] Verify Stage 2.5 ending and Stage 3 beginning are not affected by the edit
- [ ] Read back the modified file to confirm the new Stage 2.6 reads correctly in context

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/agents/planner-agent.md` - Replace Stage 2.6 section (lines 78-89) with three-level roadmap integration pattern

**Verification**:
- Stage 2.6 header is present and correctly titled
- Three levels documented: (a) first phase, (b) per-phase step, (c) last phase
- First phase named "Roadmap Assessment and Initial Update" with active update behavior
- Per-phase step specifies `- [ ] Update ROADMAP.md: mark any items completed by this phase`
- Last phase named "Final ROADMAP.md Reconciliation"
- Surrounding stages (2.5 and 3) are unmodified

## Testing & Validation

- [ ] The modified planner-agent.md is valid markdown with no broken heading hierarchy
- [ ] Stage 2.6 contains all three levels of roadmap integration (first phase, per-phase, last phase)
- [ ] The `### Stage 2.5` and `### Stage 3` sections remain intact and unchanged
- [ ] The new text matches the research report recommendation (with any minor formatting adjustments)

## Artifacts & Outputs

- `.claude/agents/planner-agent.md` - Modified with new Stage 2.6

## Rollback/Contingency

Revert via `git checkout -- .claude/agents/planner-agent.md` to restore the original Stage 2.6 bookend pattern.
