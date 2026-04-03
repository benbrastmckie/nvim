# Implementation Plan: Update skill-team-implement to Consume Plan Dependencies

- **Task**: 357 - Update skill-team-implement to consume plan dependency analysis
- **Status**: [NOT STARTED]
- **Effort**: 30 minutes
- **Dependencies**: 356 (completed)
- **Research Inputs**: specs/357_team_implement_consume_deps/reports/01_team-implement-deps.md
- **Artifacts**: plans/01_team-implement-deps.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Update skill-team-implement Stage 5 and Stage 6 to prefer explicit dependency data from plans (the `**Depends on**:` fields and `**Dependency Analysis**` wave table added in task 356), with fallback to heuristic inference for backward compatibility with older plans.

### Research Integration

From report 01_team-implement-deps.md: Stage 5 already expects explicit dependencies but had nothing to read. Stage 6 can read the wave table directly. Single file modification.

## Goals & Non-Goals

**Goals**:
- Update Stage 5 to prefer explicit `Depends on:` fields over heuristic inference
- Update Stage 6 to read wave table when present instead of computing waves
- Preserve fallback to heuristic inference for plans without dependency data

**Non-Goals**:
- Changing any other stages of skill-team-implement
- Modifying the wave execution logic (Stage 7-8)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Parsing error on malformed wave table | L | L | Fallback to heuristic inference on parse failure |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Update Stage 5 and Stage 6 [NOT STARTED]

**Goal**: Replace heuristic-first approach with explicit-first approach in both stages.

**Depends on**: none

**Tasks**:
- [ ] Update Stage 5 pseudocode to check for `**Depends on**:` fields first, fall back to file-overlap heuristics
- [ ] Update Stage 5 Dependency Analysis section to note explicit fields take priority
- [ ] Update Stage 6 to check for `**Dependency Analysis**` wave table first, fall back to computing waves
- [ ] Preserve existing heuristic logic as fallback (do not remove)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/skills/skill-team-implement/SKILL.md` - Stage 5 and Stage 6

**Verification**:
- Stage 5 checks for explicit `Depends on` fields before falling back to heuristics
- Stage 6 checks for wave table before computing waves
- Existing heuristic fallback logic preserved

## Testing & Validation

- [ ] Stage 5 mentions parsing `**Depends on**:` fields as primary source
- [ ] Stage 6 mentions parsing `**Dependency Analysis**` table as primary source
- [ ] Both stages document fallback to existing heuristic logic
- [ ] No other stages modified

## Artifacts & Outputs

- `.claude/skills/skill-team-implement/SKILL.md` (modified)

## Rollback/Contingency

Revert the Stage 5 and Stage 6 edits. The heuristic approach was the previous default and continues to work.
