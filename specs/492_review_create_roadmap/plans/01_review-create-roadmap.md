# Implementation Plan: Fix Contradictory Error Handling Note in review.md

- **Task**: 492 - review_create_roadmap
- **Status**: [COMPLETED]
- **Effort**: 0.25 hours
- **Dependencies**: None
- **Research Inputs**: specs/492_review_create_roadmap/reports/01_review-create-roadmap.md
- **Artifacts**: plans/01_review-create-roadmap.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Line 116 of `.claude/commands/review.md` contains an error handling note that says "If ROADMAP.md doesn't exist or fails to parse" -- but the creation-if-missing logic at lines 69-80 guarantees the file exists by that point. The fix is to remove the "doesn't exist or" clause so the note only covers the parse-failure case.

### Research Integration

Research report `01_review-create-roadmap.md` confirmed that:
- Creation-if-missing logic already exists at lines 69-80 of review.md
- The default template matches the /todo template exactly
- The only remaining issue is the contradictory wording at line 116

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consultation needed for this task.

## Goals & Non-Goals

**Goals**:
- Remove the contradictory "doesn't exist or" clause from line 116 of review.md

**Non-Goals**:
- Adding or modifying creation-if-missing logic (already exists)
- Changing the default ROADMAP.md template
- Any other review.md modifications

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Wording change introduces ambiguity | L | L | Keep the sentence structure, only remove the contradictory clause |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Fix Error Handling Note [BLOCKED]

**Goal**: Remove contradictory "doesn't exist or" clause from the error handling note at line 116.

**Tasks**:
- [ ] Edit line 116 of `.claude/commands/review.md`
- [ ] Change "If ROADMAP.md doesn't exist or fails to parse" to "If ROADMAP.md fails to parse"

**Timing**: 0.25 hours

**Depends on**: none

**Files to modify**:
- `.claude/commands/review.md` - Remove "doesn't exist or" from error handling note at line 116

**Verification**:
- Line 116 no longer references a missing file scenario
- The rest of review.md is unchanged
- The creation-if-missing block at lines 69-80 remains intact

## Testing & Validation

- [ ] Verify line 116 reads: "If ROADMAP.md fails to parse, log warning and continue review without roadmap integration."
- [ ] Verify no other lines were modified

## Artifacts & Outputs

- `specs/492_review_create_roadmap/plans/01_review-create-roadmap.md` (this plan)
- `.claude/commands/review.md` (modified file)

## Rollback/Contingency

Revert the single line change with `git checkout .claude/commands/review.md` if needed.
