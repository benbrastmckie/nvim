# Implementation Plan: Task #383

- **Task**: 383 - Simplify /plan command
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/383_simplify_plan_command/reports/01_simplify-plan-command.md
- **Artifacts**: plans/01_simplify-plan-command.md
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Simplify the /plan command to always create a fresh plan from any non-terminal task state, removing the current status restrictions that gate planning to only `not_started`, `researched`, or `partial`. When a prior plan exists, pass it to the planner-agent as reference context so it can learn from what worked or failed, but always produce a clean start. Research takes priority over any prior plan when both exist.

### Research Integration

Research report identifies three files requiring changes (plan.md, SKILL.md, planner-agent.md) and confirms `update-task-status.sh` needs no changes. Key findings: prior plan discovery follows the existing `research_path` pattern; artifact numbering should use file counting instead of `next_artifact_number - 1` to handle re-planning naturally; `/revise` should be preserved as a separate lightweight command.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Allow `/plan` to run from any non-terminal task state (only block `completed` and `abandoned`)
- Pass prior plan path through the full delegation chain (command -> skill -> agent)
- Add Stage 2a to planner-agent for loading prior plan as reference context
- Establish clear priority hierarchy: research > task description > prior plan > roadmap
- Use file-count-based artifact numbering for re-planning scenarios

**Non-Goals**:
- Modifying `/revise` command (it serves a different purpose: lightweight iteration)
- Changing `update-task-status.sh` (no changes needed per research)
- Modifying `state-management.md` rules (documentation-only, out of scope for this task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Prior plan biases fresh plans too heavily | M | M | Clear "reference only, not template" instructions in agent |
| Artifact numbering collision on re-plan | L | L | File counting ensures unique numbers |
| Multi-task batch validation too permissive | L | L | Only terminal states blocked, which is the correct behavior |
| Breaking existing /plan flow for standard cases | M | L | Changes are additive; standard researched->planned path unchanged |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

### Phase 1: Update planner-agent.md [NOT STARTED]

**Goal**: Add prior plan loading capability and priority hierarchy to the planner agent.

**Tasks**:
- [ ] Add `prior_plan_path` to Stage 1 delegation field extraction (line 31 area)
- [ ] Add new Stage 2a between Stage 2 (research) and Stage 2.5 (roadmap) for loading prior plan
- [ ] Stage 2a must include: Read prior plan, extract phase structure/effort/risks/what worked, note completed phases as validated approaches, store as reference only
- [ ] Stage 2a must include priority hierarchy documentation: (1) Research report, (2) Task description, (3) Prior plan reference, (4) Roadmap context
- [ ] Add "MUST NOT: Copy phases from prior plan into new plan" instruction
- [ ] Add "Prior Plan Reference" subsection to the plan template in Stage 5 (between Research Integration and Roadmap Alignment)
- [ ] Update Context References section to mention prior plan handling

**Timing**: 0.75 hours

**Depends on**: none

**Files to modify**:
- `.claude/agents/planner-agent.md` - Add `prior_plan_path` field extraction, new Stage 2a, update plan template, update context references

**Verification**:
- Stage 1 lists `prior_plan_path` as an extracted field
- New Stage 2a exists between Stage 2 and Stage 2.5
- Stage 2a includes priority hierarchy and "reference only" instructions
- Plan template in Stage 5 includes "Prior Plan Reference" section
- No existing stages are broken or renumbered incorrectly

---

### Phase 2: Update skill-planner SKILL.md [NOT STARTED]

**Goal**: Remove status gates, add prior plan discovery, change artifact numbering, and pass `prior_plan_path` in delegation context.

**Tasks**:
- [ ] Update Stage 1 status validation (lines 64-67): block both `completed` AND `abandoned` (currently only blocks `completed`)
- [ ] Update trigger conditions (lines 32-36): change "not_started, researched" to "any non-terminal state"
- [ ] Update Stage 3a artifact numbering (lines 110-136): replace `next_artifact_number - 1` logic with file-count-based numbering (`ls plans/*.md | wc -l` + 1)
- [ ] Add prior plan discovery to Stage 4 (after research_path gathering): glob `specs/{NNN}_{SLUG}/plans/*.md`, sort, take latest as `prior_plan_path`
- [ ] Add `prior_plan_path` field to the delegation context JSON in Stage 4 (lines 146-162)
- [ ] Keep the `next_artifact_number` note unchanged (plan still does NOT increment it)

**Timing**: 1.0 hour

**Depends on**: 1

**Files to modify**:
- `.claude/skills/skill-planner/SKILL.md` - Update status validation, trigger conditions, artifact numbering, add prior plan discovery, update delegation context

**Verification**:
- Status validation blocks `completed` and `abandoned`, allows all other states
- Artifact numbering uses file counting, not `next_artifact_number - 1`
- Delegation context JSON includes `prior_plan_path` field
- Prior plan discovery uses glob + sort pattern from research findings
- Existing postflight stages (7-11) are untouched

---

### Phase 3: Update plan.md command [NOT STARTED]

**Goal**: Remove status restrictions from the command layer and pass prior plan path through the delegation chain.

**Tasks**:
- [ ] Update CHECKPOINT 1 validation (lines 254-259): remove status restrictions, only block `completed` and `abandoned` terminal states
- [ ] Remove the `planned` state special handling (--force offer for revision)
- [ ] Remove the `implementing` state ABORT
- [ ] Add prior plan discovery to CHECKPOINT 1 Load Context (line 262-263 area): glob `specs/{NNN}_{SLUG}/plans/*.md`, sort, take latest
- [ ] Update MULTI-TASK DISPATCH Step 1 batch validation (lines 120-125): accept any non-terminal status instead of only `researched`, `not_started`, `partial`
- [ ] Update STAGE 2 DELEGATE skill args (lines 367-370): add `prior_plan_path={path}` to all three invocation variants (team, extension, default)
- [ ] Update Error Handling GATE IN Failure section (lines 481-484): change "Invalid status" to reflect new terminal-only restriction

**Timing**: 0.75 hours

**Depends on**: 2

**Files to modify**:
- `.claude/commands/plan.md` - Update CHECKPOINT 1 validation, multi-task validation, STAGE 2 args, error handling text

**Verification**:
- CHECKPOINT 1 only blocks `completed` and `abandoned`
- No mention of `--force` for revision in CHECKPOINT 1
- Multi-task batch validation accepts any non-terminal status
- All three skill invocation variants include `prior_plan_path`
- Prior plan discovery pattern matches the one added to SKILL.md

## Testing & Validation

- [ ] Review each modified file for internal consistency (no orphaned references to removed status gates)
- [ ] Verify the prior_plan_path flows correctly: plan.md discovers it -> passes in args -> SKILL.md receives and includes in delegation context -> planner-agent.md extracts and uses it
- [ ] Confirm artifact numbering logic in SKILL.md handles edge cases: no existing plans (count=0, artifact=1), one existing plan (count=1, artifact=2)
- [ ] Verify the delegation context JSON in SKILL.md matches the fields extracted in planner-agent.md Stage 1
- [ ] Check that no references to the old status restrictions remain in any of the three files

## Artifacts & Outputs

- Modified `.claude/agents/planner-agent.md` - New Stage 2a, prior plan reference in template
- Modified `.claude/skills/skill-planner/SKILL.md` - Relaxed status gates, file-count numbering, prior plan discovery
- Modified `.claude/commands/plan.md` - Relaxed status gates, prior plan path passthrough

## Rollback/Contingency

All three files are tracked in git. If implementation causes issues, revert the commit with `git revert <sha>`. The changes are purely to markdown specification files, so there is no runtime code to break. If the relaxed status gates cause unexpected behavior, the original restrictions can be restored by reverting just the CHECKPOINT 1 and Stage 1 validation sections.
