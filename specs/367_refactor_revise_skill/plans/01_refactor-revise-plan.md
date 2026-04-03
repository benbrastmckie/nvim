# Implementation Plan: Refactor /revise to Use Skill Delegation Pattern

- **Task**: 367 - Refactor /revise to use skill delegation pattern
- **Status**: [COMPLETED]
- **Effort**: 2.5 hours
- **Dependencies**: Task 362 (update-task-status.sh) -- completed
- **Research Inputs**: None
- **Artifacts**: plans/01_refactor-revise-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `/revise` command currently handles status updates with inline jq commands and Edit tool calls rather than delegating to a skill with proper preflight/postflight separation. This refactoring will: (1) create a `skill-reviser` thin wrapper skill following the same pattern as `skill-planner`, (2) update `/revise` to delegate to it, and (3) integrate `update-task-status.sh` for centralized status updates. The revise command has two branches (plan revision and description update), both of which need to route through the skill.

## Goals & Non-Goals

**Goals**:
- Create `skill-reviser/SKILL.md` following the thin-wrapper delegation pattern
- Replace inline jq status updates in `/revise` with calls to `update-task-status.sh`
- Maintain both plan-revision and description-update branches
- Preserve existing commit message conventions and error handling

**Non-Goals**:
- Changing the functional behavior of `/revise` (input/output contract stays the same)
- Adding new features to `/revise`
- Modifying `update-task-status.sh` itself (it already supports `plan` target_status)
- Creating a dedicated reviser-agent (revise is thin enough to stay as command + skill)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| update-task-status.sh does not support revise-specific transitions (e.g., implementing -> planned) | M | M | Use script for standard transitions; handle edge cases (blocked -> planned) with direct jq as fallback |
| Breaking the description-update branch (Stage 2B) during refactoring | M | L | Keep Stage 2B as a direct path in the skill since it does not involve status marker transitions |
| Skill-planner pattern is too heavyweight for revise's simpler flow | L | M | Adapt the pattern -- revise does not need subagent delegation, postflight markers, or artifact number calculation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Analyze Current Flow and Map Status Transitions [COMPLETED]

**Goal**: Document exactly which status transitions `/revise` performs and which can be handled by `update-task-status.sh`.

**Tasks**:
- [ ] Map all inline status updates in revise.md (Stage 2A lines 71-91, Stage 2B lines 109-119)
- [ ] Identify which transitions fit `update-task-status.sh` parameters (preflight/postflight + research/plan/implement)
- [ ] Document edge cases: revise can transition from `implementing`, `partial`, `blocked` to `planned` -- these are not standard preflight/postflight transitions
- [ ] Determine the adaptation strategy: use `postflight plan` for the final planned transition, handle non-standard source statuses with a guard or fallback

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- No files modified; analysis only

**Verification**:
- Written mapping of all status transitions with clear categorization into "handled by script" vs "needs fallback"

---

### Phase 2: Create skill-reviser/SKILL.md [COMPLETED]

**Goal**: Create the skill file that wraps the revise operation with proper preflight/postflight structure.

**Tasks**:
- [ ] Create `.claude/skills/skill-reviser/SKILL.md` with frontmatter (name, description, allowed-tools, model: opus)
- [ ] Define execution flow following the skill-planner pattern but adapted for revise:
  - Stage 1: Input validation (task lookup, status routing to plan-revision vs description-update)
  - Stage 2: Preflight -- no status change needed (revise does not have a "revising" status; the task is already in a valid state)
  - Stage 3: Execute plan revision (load current plan, analyze changes, create revised plan) or description update
  - Stage 4: Postflight status update using `update-task-status.sh postflight plan` for plan revision path
  - Stage 5: Artifact linking (same two-step jq pattern as skill-planner Stage 8)
  - Stage 6: Git commit
  - Stage 7: Return summary
- [ ] Handle the description-update branch (Stage 2B) as a simpler inline path within the skill -- it only updates state.json description field and TODO.md text, not status markers
- [ ] Include error handling section matching skill-planner conventions
- [ ] Add context references to return-metadata-file.md, jq-escaping-workarounds.md

**Timing**: 1.0 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-reviser/SKILL.md` - Create new file

**Verification**:
- SKILL.md follows the same structure as skill-planner/SKILL.md
- All stages are documented with code examples
- Both branches (plan revision and description update) are covered
- `update-task-status.sh` is called for the plan-revision postflight

---

### Phase 3: Refactor /revise Command to Delegate [COMPLETED]

**Goal**: Update the `/revise` command file to delegate to `skill-reviser` instead of performing work inline.

**Tasks**:
- [ ] Replace Stage 2A (plan revision) inline status updates (jq commands at lines 71-91) with delegation to skill-reviser
- [ ] Replace Stage 2B (description update) inline logic with delegation to skill-reviser
- [ ] Keep GATE IN (Checkpoint 1) in the command for argument parsing and initial validation
- [ ] Move GATE OUT (Checkpoint 2) verification logic into skill-reviser postflight
- [ ] Keep COMMIT (Checkpoint 3) in the skill-reviser (consistent with skill-planner)
- [ ] Update the command to invoke skill-reviser via the Skill tool or direct reference
- [ ] Update `.claude/CLAUDE.md` Skill-to-Agent Mapping table to add skill-reviser entry

**Timing**: 0.75 hours

**Depends on**: 2

**Files to modify**:
- `.claude/commands/revise.md` - Refactor to delegate to skill-reviser
- `.claude/CLAUDE.md` - Add skill-reviser to Skill-to-Agent Mapping table

**Verification**:
- revise.md no longer contains inline jq status updates
- revise.md delegates to skill-reviser for both branches
- CLAUDE.md Skill-to-Agent Mapping includes skill-reviser

---

### Phase 4: Verify Refactored Flow [COMPLETED]

**Goal**: Validate the refactored command works correctly for both branches.

**Tasks**:
- [ ] Trace through plan-revision path: verify preflight/postflight status transitions match original behavior
- [ ] Trace through description-update path: verify state.json and TODO.md updates match original behavior
- [ ] Verify git commit messages match original format
- [ ] Verify error handling paths (task not found, invalid status, missing plan) still work
- [ ] Verify `update-task-status.sh` integration: confirm `postflight plan` produces the correct `planned` status in both state.json and TODO.md
- [ ] Check for any references to the old inline pattern that need updating (e.g., context files, documentation)

**Timing**: 0.25 hours

**Depends on**: 3

**Files to modify**:
- None expected (fixes applied back to Phase 2/3 files if issues found)

**Verification**:
- Both branches produce identical state changes as the original implementation
- No orphaned inline jq status update patterns remain in revise.md

## Testing & Validation

- [ ] Dry-run `update-task-status.sh postflight 367 plan sess_test` to confirm it produces correct status
- [ ] Review skill-reviser/SKILL.md against skill-planner/SKILL.md for structural consistency
- [ ] Verify revise.md argument parsing and validation remain intact after refactoring
- [ ] Confirm CLAUDE.md Skill-to-Agent Mapping table is consistent with actual skill files

## Artifacts & Outputs

- `specs/367_refactor_revise_skill/plans/01_refactor-revise-plan.md` (this plan)
- `.claude/skills/skill-reviser/SKILL.md` (new skill file)
- `.claude/commands/revise.md` (refactored command)
- `.claude/CLAUDE.md` (updated mapping table)

## Rollback/Contingency

If the refactored `/revise` command produces incorrect behavior:
1. Revert `.claude/commands/revise.md` to the pre-refactoring version via `git checkout`
2. The skill-reviser directory can be deleted without affecting other components
3. CLAUDE.md mapping table entry can be removed
4. No other commands or skills depend on skill-reviser, so rollback is isolated
