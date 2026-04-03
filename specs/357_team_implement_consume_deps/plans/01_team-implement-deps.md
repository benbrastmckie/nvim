# Implementation Plan: Update skill-team-implement to Consume Plan Dependencies

- **Task**: 357 - Update skill-team-implement to consume plan dependency analysis
- **Status**: [COMPLETED]
- **Effort**: 45 minutes
- **Dependencies**: 356 (completed)
- **Research Inputs**: specs/357_team_implement_consume_deps/reports/01_team-implement-deps.md
- **Artifacts**: plans/01_team-implement-deps.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Update skill-team-implement to read explicit dependency data from plans and handle Y-shaped dependency patterns. When a plan has trunk phases (single-phase waves) followed by branching waves (multi-phase waves), the system should execute trunk phases with a single agent first, then spawn parallel agents only when the dependency graph fans out. This ensures trunk work completes cleanly before parallel execution begins.

### Research Integration

From report 01_team-implement-deps.md: Stage 5 already expects explicit dependencies but had nothing to read. Stage 6 can read the wave table directly. Revision adds Stage 8 updates for Y-shaped execution pattern.

## Goals & Non-Goals

**Goals**:
- Update Stage 5 to prefer explicit `Depends on:` fields over heuristic inference
- Update Stage 6 to read wave table when present instead of computing waves
- Update Stage 8 to detect Y-shaped dependencies and execute trunk waves with a single agent before spawning parallel agents for branching waves
- Preserve fallback to heuristic inference for plans without dependency data

**Non-Goals**:
- Changing the debugger teammate logic (Stage 9)
- Modifying single-agent `/implement` behavior (only affects `--team` mode)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Parsing error on malformed wave table | L | L | Fallback to heuristic inference on parse failure |
| Over-serialization if Y-detection is too aggressive | L | M | Only treat single-phase waves as trunk when followed by multi-phase waves |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Update Stage 5 and Stage 6 [COMPLETED]

**Goal**: Replace heuristic-first approach with explicit-first approach for dependency parsing and wave calculation.

**Depends on**: none

**Tasks**:
- [ ] Update Stage 5 pseudocode to check for `**Depends on**:` fields first, fall back to file-overlap heuristics
- [ ] Update Stage 5 Dependency Analysis section to note explicit fields take priority
- [ ] Update Stage 6 to check for `**Dependency Analysis**` wave table first, fall back to computing waves
- [ ] Preserve existing heuristic logic as fallback (do not remove)

**Timing**: 20 minutes

**Files to modify**:
- `.claude/skills/skill-team-implement/SKILL.md` - Stage 5 and Stage 6

**Verification**:
- Stage 5 checks for explicit `Depends on` fields before falling back to heuristics
- Stage 6 checks for wave table before computing waves
- Existing heuristic fallback logic preserved

---

### Phase 2: Update Stage 8 for Y-Shaped Execution [COMPLETED]

**Goal**: When `--team` is used, detect Y-shaped dependency patterns and execute trunk waves sequentially with a single agent before spawning parallel agents for branching waves.

**Depends on**: 1

**Tasks**:
- [ ] Add trunk detection logic to Stage 8: a "trunk wave" is a single-phase wave that precedes a multi-phase wave
- [ ] Update wave execution loop: trunk waves execute with a single agent (no team spawning), branching waves spawn parallel teammates
- [ ] Add brief comment explaining the Y-shaped optimization pattern

**Timing**: 25 minutes

**Files to modify**:
- `.claude/skills/skill-team-implement/SKILL.md` - Stage 8

**Verification**:
- Stage 8 distinguishes trunk waves (single-phase) from branching waves (multi-phase)
- Trunk waves execute sequentially with single agent
- Branching waves spawn parallel teammates up to team_size
- Pattern only applies when `--team` is active

## Testing & Validation

- [ ] Stage 5 mentions parsing `**Depends on**:` fields as primary source
- [ ] Stage 6 mentions parsing `**Dependency Analysis**` table as primary source
- [ ] Stage 8 includes trunk wave detection and Y-shaped execution pattern
- [ ] Both Stage 5/6 document fallback to existing heuristic logic
- [ ] No stages other than 5, 6, 8 modified

## Artifacts & Outputs

- `.claude/skills/skill-team-implement/SKILL.md` (modified)

## Rollback/Contingency

Revert the Stage 5, 6, and 8 edits. The heuristic approach and uniform wave execution were the previous defaults and continue to work.
