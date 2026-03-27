# Implementation Plan: Task #309 (Revision 2)

- **Task**: 309 - unified_artifact_numbering_research
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/309_unified_artifact_numbering_research/reports/01_unified-numbering-research.md
- **Artifacts**: plans/02_unified-numbering-with-teams.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false
- **Previous Version**: plans/01_unified-numbering-implementation.md

## Overview

Implement unified artifact numbering across the agent system, where all artifact types (reports, plans, summaries) share a single sequence number per task. Research drives sequence advancement while plan and summary inherit the current research number.

**Revision Note**: This version adds team mode naming conventions where parallel teammates use the same artifact number with a letter suffix (a, b, c, d), and the synthesis report uses the base number.

### Research Integration

Key findings from 01_unified-numbering-research.md:
- Add `next_artifact_number` field to task entries in state.json (initial value: 1)
- Research increments the field after use; plan/summary use (current - 1)
- Backward compatibility via directory scanning when field is missing
- 10+ files need updates across documentation, skills, and agents

### Team Mode Extension

**Single-agent mode**: `{NN}_{slug}.md`
- Example: `01_initial-research.md`, `01_implementation-plan.md`

**Team mode** (parallel teammates):
- Teammate reports: `{NN}_{teammate-letter}-findings.md`
  - Example: `01_teammate-a-findings.md`, `01_teammate-b-findings.md`, `01_teammate-c-findings.md`
- Synthesis report: `{NN}_{slug}.md` (same number, no letter)
  - Example: `01_team-research.md`

**Key principle**: All artifacts from the same research round share the same base number. Letter suffixes distinguish parallel work within a round.

## Goals & Non-Goals

**Goals**:
- Unified artifact numbering where research, plan, and summary share the same sequence number within a round
- Research operations advance the sequence; plan/summary reuse the current number
- Team mode uses letter suffixes (a, b, c, d) for parallel teammates within same round
- Synthesis artifacts use base number without suffix
- Backward compatibility for existing tasks without the new field
- Clear delegation of artifact number from skills to agents

**Non-Goals**:
- Changing existing artifact file names (historical artifacts remain unchanged)
- Complex migration of existing task state (scanning fallback handles legacy tasks)
- Per-type sequence tracking (rejected in research as overly complex)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Backward compat issues | H | M | Scanning fallback + verify with existing tasks |
| Off-by-one errors in numbering | M | M | Clear documentation of "use then increment" vs "current-1" semantics |
| Team letter collision | L | L | Sequential assignment (a, b, c, d) |
| Spawn agent hardcoded value | H | H | Explicit update in Phase 4 |

## Implementation Phases

### Phase 1: Documentation Updates [COMPLETED]

**Goal**: Establish the schema and rules for unified artifact numbering (including team mode) before code changes

**Tasks**:
- [ ] Update `.claude/context/reference/state-management-schema.md` to add `next_artifact_number` field documentation
- [ ] Update `.claude/rules/artifact-formats.md` to change from "Per-Type Sequential Numbering" to "Unified Sequential Numbering"
- [ ] Add team mode naming conventions to artifact-formats.md

**Timing**: 30 minutes

**Files to modify**:
- `.claude/context/reference/state-management-schema.md` - Add field schema, semantics, and examples
- `.claude/rules/artifact-formats.md` - Update numbering section with unified approach + team mode

**Verification**:
- Documentation clearly explains the unified numbering semantics
- Team mode naming (`{NN}_{letter}-findings.md`) is documented
- Research/plan/summary inheritance rules are explicit
- Backward compatibility via scanning is documented

---

### Phase 2: Single-Agent Skill Updates [COMPLETED]

**Goal**: Update single-agent skills to read/write `next_artifact_number` and pass correct artifact number to agents

**Tasks**:
- [ ] Update `skill-researcher` to read `next_artifact_number`, pass to agent, then increment in postflight
- [ ] Update `skill-planner` to read `next_artifact_number`, calculate (current-1), pass to agent
- [ ] Update `skill-implementer` to read `next_artifact_number`, calculate (current-1), pass to agent

**Timing**: 45 minutes

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` - Add preflight read, delegation context extension, postflight increment
- `.claude/skills/skill-planner/SKILL.md` - Add preflight read (current-1), delegation context extension
- `.claude/skills/skill-implementer/SKILL.md` - Add preflight read (current-1), delegation context extension

**Verification**:
- Skills correctly extract `next_artifact_number` from state.json
- Research skill increments after use; plan/implement skills use (current-1)
- Delegation context includes `artifact_number` field
- Backward compatibility scanning logic is included when field is missing

---

### Phase 3: Team Skill Updates [COMPLETED]

**Goal**: Update team skills to pass artifact number with letter suffixes to teammates

**Tasks**:
- [ ] Update `skill-team-research` to pass `artifact_number` and `teammate_letter` to each teammate
- [ ] Update `skill-team-plan` to pass `artifact_number` and `teammate_letter` to each teammate
- [ ] Update `skill-team-implement` to pass `artifact_number` and `teammate_letter` to each teammate
- [ ] Update `.claude/utils/team-wave-helpers.md` with artifact naming patterns

**Timing**: 45 minutes

**Files to modify**:
- `.claude/skills/skill-team-research/SKILL.md` - Pass artifact_number + letter (a, b, c, d) to teammates
- `.claude/skills/skill-team-plan/SKILL.md` - Pass artifact_number + letter to teammates
- `.claude/skills/skill-team-implement/SKILL.md` - Pass artifact_number + letter to teammates
- `.claude/utils/team-wave-helpers.md` - Add team artifact naming helpers

**Delegation Context for Teammates**:
```json
{
  "artifact_number": 1,
  "teammate_letter": "a",
  "artifact_pattern": "{NN}_{letter}-findings.md"
}
```

**Synthesis Uses Base Number**:
```json
{
  "artifact_number": 1,
  "artifact_pattern": "{NN}_{slug}.md"
}
```

**Verification**:
- Team skills assign sequential letters (a, b, c, d) to teammates
- Teammates receive artifact_number and teammate_letter in delegation context
- Synthesis report uses base number without letter suffix
- Only research team skill increments next_artifact_number (not plan/implement teams)

---

### Phase 4: Agent Updates [COMPLETED]

**Goal**: Update agents to use the artifact number (and optional letter) passed via delegation context

**Tasks**:
- [ ] Update `general-research-agent.md` to use provided `artifact_number` in report path
- [ ] Update `planner-agent.md` to use provided `artifact_number` in plan path
- [ ] Update `general-implementation-agent.md` to use provided `artifact_number` in summary path
- [ ] Update `spawn-agent.md` to use provided `artifact_number` instead of hardcoded 02
- [ ] Update agents to handle optional `teammate_letter` for team mode

**Timing**: 45 minutes

**Files to modify**:
- `.claude/agents/general-research-agent.md` - Use `artifact_number` + optional `teammate_letter`
- `.claude/agents/planner-agent.md` - Use `artifact_number` + optional `teammate_letter`
- `.claude/agents/general-implementation-agent.md` - Use `artifact_number` + optional `teammate_letter`
- `.claude/agents/spawn-agent.md` - Remove hardcoded 02, use passed number

**Verification**:
- Agents extract `artifact_number` and `teammate_letter` from delegation context
- Single-agent mode: `{NN}_{slug}.md`
- Team mode: `{NN}_{letter}-findings.md` for teammates, `{NN}_{slug}.md` for synthesis
- Spawn agent no longer assumes first research is 01

---

### Phase 5: Command Updates [COMPLETED]

**Goal**: Ensure /revise command maintains same-round semantics

**Tasks**:
- [ ] Update `.claude/commands/revise.md` to document that plan revision stays in same round
- [ ] Verify revise does not trigger artifact number changes

**Timing**: 15 minutes

**Files to modify**:
- `.claude/commands/revise.md` - Document same-round semantics for plan revisions

**Verification**:
- /revise documentation clarifies it creates a new plan version within the same artifact round
- No artifact number increment occurs during revision

---

### Phase 6: Verification and Testing [COMPLETED]

**Goal**: Verify the complete flow works end-to-end

**Tasks**:
- [ ] Verify backward compatibility by checking existing tasks without `next_artifact_number`
- [ ] Trace through single-agent multi-round scenario
- [ ] Trace through team mode scenario with 3 teammates
- [ ] Review all changes for consistency

**Timing**: 15 minutes

**Verification**:
- Existing tasks work correctly (scanning fallback)
- Single-agent: 01_report -> 01_plan -> 01_summary -> 02_report -> 02_plan -> 02_summary
- Team mode: 01_teammate-a-findings + 01_teammate-b-findings + 01_teammate-c-findings -> 01_team-research -> 01_plan

## Testing & Validation

**Single-Agent Mode**:
- [ ] Existing tasks without `next_artifact_number` still work (backward compat)
- [ ] New task with /research creates 01_report and sets next_artifact_number=2
- [ ] Subsequent /plan uses 01_plan (not 02_plan)
- [ ] Subsequent /implement uses 01_summary (not 02_summary)
- [ ] After blocker, new /research creates 02_report and sets next_artifact_number=3
- [ ] /revise stays in same round (does not change artifact number)
- [ ] /spawn uses correct artifact number, not hardcoded 02

**Team Mode**:
- [ ] /research --team creates: 01_teammate-a-findings, 01_teammate-b-findings, 01_team-research
- [ ] All teammate artifacts share same base number (01)
- [ ] Synthesis report uses base number without letter (01_team-research)
- [ ] next_artifact_number incremented once (to 2) after team research completes
- [ ] Subsequent /plan --team creates: 01_teammate-a-plan, 01_teammate-b-plan, 01_team-plan
- [ ] Plan team uses same round number as research (01, not 02)

## Artifacts & Outputs

- `.claude/context/reference/state-management-schema.md` - Updated with `next_artifact_number` field
- `.claude/rules/artifact-formats.md` - Updated with unified numbering + team mode naming
- `.claude/skills/skill-researcher/SKILL.md` - Updated with read/increment logic
- `.claude/skills/skill-planner/SKILL.md` - Updated with (current-1) logic
- `.claude/skills/skill-implementer/SKILL.md` - Updated with (current-1) logic
- `.claude/skills/skill-team-research/SKILL.md` - Updated with team artifact numbering
- `.claude/skills/skill-team-plan/SKILL.md` - Updated with team artifact numbering
- `.claude/skills/skill-team-implement/SKILL.md` - Updated with team artifact numbering
- `.claude/utils/team-wave-helpers.md` - Updated with artifact naming helpers
- `.claude/agents/general-research-agent.md` - Updated to use passed artifact number + letter
- `.claude/agents/planner-agent.md` - Updated to use passed artifact number + letter
- `.claude/agents/general-implementation-agent.md` - Updated to use passed artifact number + letter
- `.claude/agents/spawn-agent.md` - Updated to use passed artifact number
- `.claude/commands/revise.md` - Updated with same-round semantics

## Rollback/Contingency

If unified numbering causes issues:
1. Revert skill changes (skills stop passing `artifact_number`)
2. Revert agent changes (agents resume independent numbering)
3. Remove `next_artifact_number` field from schema (optional, field can remain unused)
4. Existing artifacts remain unchanged - only new artifact naming affected
