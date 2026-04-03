# Implementation Plan: Add Phase Dependency Analysis

- **Task**: 356 - Add phase dependency analysis to plan format and planner agent
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: specs/356_plan_phase_dependencies/reports/01_plan-phase-deps.md
- **Artifacts**: plans/01_plan-phase-deps.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Add structured phase dependency declarations to the plan format and planner agent. This closes the gap where the planner reasons about dependencies (Stage 4) but does not emit them, forcing skill-team-implement to infer dependencies heuristically from file overlap. The changes add a per-phase `**Depends on**:` field, a compact wave table in `## Implementation Phases`, and an optional `dependency_waves` field in plan_metadata -- all backward-compatible with existing plans.

### Research Integration

Key findings from report 01_plan-phase-deps.md:
- Plans currently have no explicit per-phase dependency declarations
- skill-team-implement Stage 5 expects "explicit dependencies from plan metadata" but none exist
- planner-agent Stage 4 reasons about dependencies but Stage 5 template drops them
- Proposed format: `**Depends on**: none | 1 | 1, 3` per phase + brief wave table
- Backward compatible: absence of field means sequential (current behavior)

## Goals & Non-Goals

**Goals**:
- Add `**Depends on**:` field to plan-format.md phase format specification
- Add Dependency Analysis wave table to `## Implementation Phases` section
- Add `dependency_waves` to plan_metadata schema
- Update planner-agent.md to generate dependency data (Stage 4 wave map, Stage 5 template, Stage 6 metadata)
- Update plan-format-enforcement.md checklist to include new field

**Non-Goals**:
- Modifying skill-team-implement (it already handles explicit dependencies; no changes needed)
- Making `Depends on` strictly required (absence means sequential, safe default)
- Changing existing plan files to add dependency information retroactively

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Inconsistency between per-phase fields and wave table | M | M | Planner-agent generates table from per-phase data; add verification note in Stage 6 |
| Planners produce over-serialized waves | L | M | Default sequential is safe; structured output encourages better analysis |
| Complex dependency graphs become unwieldy | L | L | Plans capped at 4-6 phases; table never exceeds 6 rows |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Plan Format Standard [COMPLETED]

**Goal**: Add dependency fields and wave table to plan-format.md and update the enforcement checklist.

**Depends on**: none

**Tasks**:
- [ ] Add `**Depends on:**` field to "Implementation Phases (format)" section after `**Timing:**`
- [ ] Document field convention: `none`, `1`, `1, 3`, and absence meaning sequential
- [ ] Add **Dependency Analysis** wave table format between `## Implementation Phases` heading and first `### Phase` heading
- [ ] Add `dependency_waves` field to plan_metadata schema with description and example
- [ ] Update Example Skeleton to include `**Depends on**:` and wave table
- [ ] Update plan-format-enforcement.md Phase Format section to include `**Depends on**:` (optional)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/context/formats/plan-format.md` - Add Depends on field spec, wave table format, plan_metadata schema update, skeleton update
- `.claude/rules/plan-format-enforcement.md` - Add Depends on to phase format checklist

**Verification**:
- plan-format.md contains `**Depends on**:` in phase format section
- plan-format.md contains Dependency Analysis table example
- plan_metadata schema includes `dependency_waves` field
- Example Skeleton shows both new elements
- plan-format-enforcement.md lists Depends on field

---

### Phase 2: Update Planner Agent Stages 4-5 [COMPLETED]

**Goal**: Update Stage 4 to build a wave map from dependency data, and Stage 5 template to emit `**Depends on**:` fields and the wave table.

**Depends on**: 1

**Tasks**:
- [ ] Add step 6 "Build Wave Map" to Stage 4 (Decompose into Phases) with algorithm description
- [ ] Add `**Depends on**:` field to each phase in the Stage 5 plan template
- [ ] Add Dependency Analysis wave table to Stage 5 template between `## Implementation Phases` heading and first `### Phase`
- [ ] Add brief guidance note about generating the table from per-phase dependency data

**Timing**: 45 minutes

**Files to modify**:
- `.claude/agents/planner-agent.md` - Stage 4 (add wave map step), Stage 5 (update template with Depends on + wave table)

**Verification**:
- Stage 4 contains "Build Wave Map" step with wave assignment algorithm
- Stage 5 template includes `**Depends on**:` in each phase block
- Stage 5 template includes Dependency Analysis table after `## Implementation Phases`

---

### Phase 3: Update Planner Agent Stage 6 and Verify [COMPLETED]

**Goal**: Update Stage 6 metadata to include dependency_waves, add consistency verification step, and validate all changes work together.

**Depends on**: 1

**Tasks**:
- [ ] Add `dependency_waves` to Stage 6b metadata fields description
- [ ] Add consistency verification note in Stage 6a: wave table must match per-phase Depends on fields
- [ ] Read all three modified files end-to-end to verify internal consistency
- [ ] Verify plan-format.md field names match planner-agent.md template exactly

**Timing**: 30 minutes

**Files to modify**:
- `.claude/agents/planner-agent.md` - Stage 6a (add dependency consistency check), Stage 6b (add dependency_waves to metadata fields)

**Verification**:
- Stage 6a mentions verifying consistency between wave table and per-phase Depends on fields
- Stage 6b lists dependency_waves as agent-specific metadata field
- Field names in plan-format.md match those in planner-agent.md template

## Testing & Validation

- [ ] plan-format.md contains all new elements: Depends on field spec, wave table format, dependency_waves schema
- [ ] planner-agent.md Stage 4 has Build Wave Map step
- [ ] planner-agent.md Stage 5 template includes Depends on and wave table
- [ ] planner-agent.md Stage 6 includes dependency_waves metadata and consistency check
- [ ] plan-format-enforcement.md includes Depends on in phase format
- [ ] Example Skeleton in plan-format.md demonstrates both sequential and parallel phases
- [ ] Backward compatibility preserved: no existing required fields removed or renamed

## Artifacts & Outputs

- `.claude/context/formats/plan-format.md` (modified)
- `.claude/agents/planner-agent.md` (modified)
- `.claude/rules/plan-format-enforcement.md` (modified)
- `specs/356_plan_phase_dependencies/plans/01_plan-phase-deps.md` (this plan)

## Rollback/Contingency

All changes are additive to existing format files. Revert by removing the added sections:
- Remove `**Depends on**:` field from plan-format.md phase format and skeleton
- Remove Dependency Analysis table from plan-format.md skeleton
- Remove `dependency_waves` from plan_metadata schema
- Remove Build Wave Map step from planner-agent.md Stage 4
- Remove dependency elements from planner-agent.md Stage 5 template
- Remove dependency_waves from planner-agent.md Stage 6
- Remove Depends on line from plan-format-enforcement.md

Git revert of the implementation commit would accomplish all of the above.
