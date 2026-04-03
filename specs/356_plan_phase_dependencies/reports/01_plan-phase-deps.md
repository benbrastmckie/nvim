# Research Report: Task #356

**Task**: 356 - Add phase dependency analysis to plan format and planner agent
**Started**: 2026-04-03T00:00:00Z
**Completed**: 2026-04-03T00:30:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of plan-format.md, planner-agent.md, skill-team-implement/SKILL.md, task-breakdown.md, team-wave-helpers.md, existing plans
**Artifacts**: specs/356_plan_phase_dependencies/reports/01_plan-phase-deps.md (this file)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Plans currently have no explicit per-phase dependency declarations or wave analysis; skill-team-implement must infer dependencies from implicit file overlap signals, which is fragile and undocumented.
- Adding a `**Depends on**:` field per phase and a brief `## Dependency Analysis` section to the plan format would give skill-team-implement (and single-agent implement) authoritative dependency data to read directly.
- The planner-agent already reasons about dependencies in Stage 4 ("Define Dependencies") but does not emit them in any structured way; a small addition to Stage 5 would close this gap.
- Backward compatibility is straightforward: absence of `**Depends on**:` means "depends on all prior phases sequentially" (current implicit behavior).

## Context and Scope

The focus prompt asks for a way to express branching dependencies in plans -- specifically when a trunk phase must complete first, after which multiple phases can run in parallel waves. This is critical for skill-team-implement, which currently relies on heuristic inference (Stage 5 of SKILL.md) rather than explicit declarations in the plan.

Files examined:
- `.claude/context/formats/plan-format.md` -- plan artifact standard (134 lines)
- `.claude/agents/planner-agent.md` -- planner agent definition (235 lines)
- `.claude/skills/skill-team-implement/SKILL.md` -- team implementation skill (613 lines)
- `.claude/context/workflows/task-breakdown.md` -- task decomposition guidelines (271 lines)
- `.claude/utils/team-wave-helpers.md` -- reusable wave coordination patterns (401 lines)
- `specs/355_update_founder_readme_deck_docs/plans/01_founder-readme-deck-docs.md` -- recent real plan (138 lines)
- `.claude/rules/plan-format-enforcement.md` -- plan format checklist

## Findings

### 1. Current State: No Explicit Dependencies in Plans

The plan-format.md defines per-phase fields: `Goal`, `Tasks`, `Timing`, `Owner` (optional). There is no `Depends on` field. The writing guidance says "Be explicit about dependencies and external inputs" but provides no structured way to do this at the phase level.

The task-breakdown.md template has a per-task `Dependencies` field (e.g., "task 1.1", "Phase 1 complete"), but this is for individual tasks within phases, not for phase-to-phase dependencies.

Real plans (e.g., task 355) use sequential phase numbering and no dependency markers. Phase 2 implicitly depends on Phase 1 being complete.

### 2. Current State: skill-team-implement Infers Dependencies

skill-team-implement Stage 5 ("Analyze Phase Dependencies") uses three heuristic signals:
1. "Explicit dependencies from plan metadata" -- but no such metadata currently exists in plans
2. "Implicit dependencies from file modifications (phases modifying same files are dependent)"
3. "Cross-phase imports or references"

In practice, only heuristics 2 and 3 work, since heuristic 1 has nothing to read. This means team-implement must scan file lists to guess dependencies, which is unreliable for phases that have conceptual (not file-based) dependencies.

### 3. Current State: planner-agent Reasons About Dependencies But Does Not Emit Them

planner-agent Stage 4 ("Decompose into Phases") step 4 says "Define Dependencies: What must be done first? What blocks what? What's the critical path?" -- but Stage 5 ("Create Plan File") contains no dependency-related fields in the template output. The reasoning happens but the output is lost.

### 4. Proposed Changes to plan-format.md

#### 4a. Add `**Depends on**:` per-phase field

Add to the "Implementation Phases (format)" section, after `**Timing:**`:

```
- **Depends on:** Phase numbers this phase requires (e.g., "1", "1, 2", or "none")
```

Convention:
- `none` -- phase has no dependencies, can run immediately
- `1` -- depends on Phase 1
- `1, 3` -- depends on Phases 1 and 3
- Absence of the field means "depends on all prior phases" (sequential, backward-compatible default)

#### 4b. Add `## Dependency Analysis` section

Place this section immediately after `## Implementation Phases` heading and before the first `### Phase` heading. It should be brief -- a compact wave table showing execution order.

Proposed format:

```markdown
## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.
```

This format is:
- Brief (3-6 lines for most plans)
- Parseable by skill-team-implement (simple markdown table)
- Shows branching clearly (Wave 2 has multiple phases after trunk Phase 1)
- Shows convergence clearly (Wave 3 waits for both Phase 2 and 3)

For simple sequential plans (all phases depend on prior), the table degenerates to one phase per wave, which is still valid and clear.

#### 4c. Add to plan_metadata schema

Add an optional `dependency_waves` field to the `plan_metadata` object in state.json:

```json
{
  "phases": 4,
  "dependency_waves": [
    [1],
    [2, 3],
    [4]
  ],
  "total_effort_hours": 6,
  "complexity": "medium"
}
```

This gives skill-team-implement a machine-readable source in state.json as an alternative to parsing the markdown table.

### 5. Proposed Changes to planner-agent.md

#### 5a. Update Stage 4 to produce dependency data

Add a sub-step after "Define Dependencies" in Stage 4:

```
6. **Build Wave Map**
   - Group phases into waves based on dependency graph
   - Wave 1: phases with depends_on = "none"
   - Wave N: phases whose dependencies are all in waves < N
   - Record wave assignments for plan output
```

#### 5b. Update Stage 5 plan template

Add `**Depends on**:` field to each phase in the template. Add the Dependency Analysis table immediately after the `## Implementation Phases` heading.

#### 5c. Update Stage 6 metadata

Include `dependency_waves` in the plan_metadata written to state.json.

### 6. Proposed Changes to skill-team-implement

No changes required to skill-team-implement itself. The existing Stage 5 ("Analyze Phase Dependencies") already expects "explicit dependencies from plan metadata" as its first heuristic. Once plans include `**Depends on**:` fields and the dependency analysis table, Stage 5 will have authoritative data to read. The existing Stage 6 ("Calculate Implementation Waves") can read the wave table directly rather than computing it.

However, a minor update to Stage 5 would improve clarity: add a note that when the plan contains a Dependency Analysis table, use it directly rather than inferring. This is optional since the current pseudocode already handles explicit dependencies.

### 7. Example: 5-Phase Plan with Branching Dependencies

Consider a plan to add authentication to a web app:

```markdown
## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4, 5 | 2; 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Database Schema and User Model [NOT STARTED]

**Goal**: Create the foundational user table and ORM model.
**Tasks**:
- [ ] Create migration for users table
- [ ] Implement User model with password hashing
**Timing**: 1 hour
**Depends on**: none
**Files to modify**:
- `models/user.js`
- `migrations/001_users.sql`

---

### Phase 2: Login and Session Management [NOT STARTED]

**Goal**: Implement login endpoint and JWT session handling.
**Tasks**:
- [ ] Create auth controller with login endpoint
- [ ] Implement JWT token generation and validation
**Timing**: 1.5 hours
**Depends on**: 1
**Files to modify**:
- `controllers/auth.js`
- `utils/jwt.js`

---

### Phase 3: Registration Flow [NOT STARTED]

**Goal**: Implement user registration with email validation.
**Tasks**:
- [ ] Create registration endpoint
- [ ] Add email format validation
**Timing**: 1 hour
**Depends on**: 1
**Files to modify**:
- `controllers/auth.js`
- `utils/validation.js`

---

### Phase 4: Password Reset [NOT STARTED]

**Goal**: Token-based password reset via email.
**Tasks**:
- [ ] Generate and store reset tokens
- [ ] Create reset request and confirmation endpoints
- [ ] Send reset emails
**Timing**: 1.5 hours
**Depends on**: 2
**Files to modify**:
- `utils/tokens.js`
- `controllers/auth.js`
- `services/email.js`

---

### Phase 5: Integration Tests [NOT STARTED]

**Goal**: End-to-end test coverage for all auth flows.
**Tasks**:
- [ ] Test login flow
- [ ] Test registration flow
- [ ] Test password reset flow
**Timing**: 1 hour
**Depends on**: 3
**Files to modify**:
- `tests/auth.test.js`
```

In this example:
- Phase 1 is the trunk -- everything depends on it
- After Phase 1, Phases 2 and 3 can run in parallel (Wave 2)
- After Phase 2, Phase 4 can run; after Phase 3, Phase 5 can run (Wave 3, parallel)
- skill-team-implement reads the table directly: spawn 1 agent for Wave 1, then 2 agents for Wave 2, then 2 agents for Wave 3

### 8. Backward Compatibility

- **Existing plans without `Depends on` fields**: The convention that absence means "depends on all prior phases" preserves current sequential behavior. skill-team-implement already falls back to sequential when no explicit dependencies are found.
- **Existing plans without Dependency Analysis table**: skill-team-implement continues using heuristic inference (file overlap). No breakage.
- **plan_metadata without `dependency_waves`**: Treated as absent/null. skill-team-implement computes waves itself. The existing `plan-format.md` already documents "Backward Compatibility" patterns for missing fields.
- **Single-agent /implement**: Ignores dependency information entirely -- it always executes phases sequentially. No impact.

## Decisions

- The Dependency Analysis should be a subsection within `## Implementation Phases` (not a separate top-level section) to keep it close to the phases it describes.
- Use a markdown table format (not a text diagram) for parseability.
- Use `--` (not "none") for phases with no blockers in the "Blocked by" column, to distinguish from the per-phase `Depends on: none` field.
- The `Depends on` field uses phase numbers only (not phase names) for brevity and machine readability.
- Make the `Depends on` field recommended but not strictly required -- absence means sequential, which is the safe default.

## Risks and Mitigations

- **Risk**: Planners may not correctly identify parallelizable phases, leading to over-serialized waves. **Mitigation**: The planner-agent prompt already asks about dependencies; making the output structured will encourage better analysis. The default (sequential) is safe.
- **Risk**: Complex dependency graphs could make the table unwieldy. **Mitigation**: Plans are capped at 4-6 phases (per complexity guidelines), so the table will never exceed 6 rows.
- **Risk**: Inconsistency between per-phase `Depends on` fields and the summary table. **Mitigation**: The planner should generate the table from the per-phase data. Add a verification step to Stage 6 of planner-agent.

## Appendix

### Files to Modify

1. `.claude/context/formats/plan-format.md` -- Add `Depends on` field, Dependency Analysis section, update skeleton
2. `.claude/agents/planner-agent.md` -- Update Stage 4 (wave map), Stage 5 (template), Stage 6 (metadata)
3. `.claude/rules/plan-format-enforcement.md` -- Add `Depends on` to phase format checklist
4. `.claude/context/formats/plan-format.md` (plan_metadata schema) -- Add `dependency_waves` field
5. `.claude/skills/skill-team-implement/SKILL.md` -- Optional: add note to prefer explicit dependencies over heuristic

### Search Queries Used

- Glob: `specs/*/plans/*.md` -- found 8 existing plans
- Grep: `depend|wave|parallel|sequential` in skill-team-implement and general-implementation-agent
- Read: plan-format.md, planner-agent.md, skill-team-implement/SKILL.md, task-breakdown.md, team-wave-helpers.md, task 355 plan
