# Implementation Plan: Add Memory Candidate Emission to Agents and Return Metadata

- **Task**: 446 - Add memory candidate emission to agents and return metadata
- **Status**: [IMPLEMENTING]
- **Effort**: 2.5 hours
- **Dependencies**: Task #445 (completed)
- **Research Inputs**: specs/446_add_memory_candidate_emission_agents_return_metadata/reports/01_memory-emission-research.md
- **Artifacts**: plans/01_memory-emission-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Extend the agent-to-skill data pipeline to include structured memory candidates. The return metadata schema gets a new optional `memory_candidates` array field. Each of the three core agents (research, implementation, planner) receives a new emission stage that generates 0-3 structured candidates based on their work. Skill postflight in skill-researcher and skill-implementer propagates these candidates from `.return-meta.json` into the task's state.json entry using append semantics. No memory files are written -- candidates are stored as data for later `/todo` processing (task 447).

### Research Integration

The research report (01_memory-emission-research.md) identified:
- Clear insertion points in each agent's stage-based execution flow
- The `memory_candidates` field belongs at the `.return-meta.json` top level (not nested in `completion_data`) because all agent types emit candidates, not just implementation agents
- Skill postflight propagation follows the existing `completion_data` jq extraction pattern
- Append semantics are needed in state.json so research and implementation candidates coexist
- Planner agent skill postflight propagation is unnecessary (0-1 candidates, non-terminal status)

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Define the `memory_candidates` array schema in return-metadata-file.md
- Add memory candidate emission stages to all three core agents
- Propagate candidates from `.return-meta.json` to state.json via skill postflight (researcher and implementer)
- Use append semantics so candidates accumulate across research and implementation phases

**Non-Goals**:
- Writing actual memory files (task 447 scope)
- `/todo` consumption of structured candidates (task 447 scope)
- Memory scoring, distillation, or maintenance (tasks 449+)
- Validation or enforcement of candidate quality (confidence field enables downstream filtering)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Schema change breaks existing metadata parsing | Low | Very Low | Field is optional; all jq reads use `// []` fallback |
| Agents emit low-quality candidates | Low | Medium | Confidence field enables three-tier filtering in task 447 |
| state.json grows with unused candidates | Low | Low | `/todo` consumes and removes candidates during archival |
| jq escaping issues (Issue #1132) | Medium | Low | Use standard `| not` patterns; no `!=` operators needed |
| Agent emission instructions ignored by LLM | Low | Medium | Emission is optional (0-3); absence is valid behavior |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Schema Extension [COMPLETED]

**Goal**: Define the `memory_candidates` array in return-metadata-file.md and document the state.json field addition.

**Tasks**:
- [ ] Add `memory_candidates` to the field table in return-metadata-file.md as an optional top-level array
- [ ] Document the candidate object schema: `content` (string, max ~300 tokens), `category` (enum: TECHNIQUE|PATTERN|CONFIG|WORKFLOW|INSIGHT), `source_artifact` (path string), `confidence` (float 0-1), `suggested_keywords` (array of strings)
- [ ] Add an example showing 1-2 candidates in the metadata example block
- [ ] Document `memory_candidates` as an optional field on state.json task entries in state-management-schema.md

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/formats/return-metadata-file.md` -- Add field definition, schema, and example
- `.claude/context/reference/state-management-schema.md` -- Add `memory_candidates` as optional task field

**Verification**:
- return-metadata-file.md contains `memory_candidates` in the field table
- Candidate object schema is fully specified with all 5 fields
- state-management-schema.md documents the field on task entries

---

### Phase 2: Agent Emission Stages [NOT STARTED]

**Goal**: Add memory candidate emission instructions to all three core agent definitions.

**Tasks**:
- [ ] Add new stage to general-research-agent.md between "Synthesize Findings" (Stage 4) and "Create Research Report" (Stage 5) -- renumber subsequent stages
- [ ] Instruct research agent to emit 0-3 candidates for novel findings: unexpected patterns, reusable configurations, workflow insights
- [ ] Add new stage to general-implementation-agent.md between "Create Implementation Summary" (Stage 6) and "Write Metadata File" (Stage 7) -- renumber subsequent stages
- [ ] Instruct implementation agent to emit 0-3 candidates for reusable patterns, configuration discoveries, debugging techniques
- [ ] Add new stage to planner-agent.md between "Create Plan File" (Stage 5) and "Verify Plan and Write Metadata File" (Stage 6) -- renumber subsequent stages
- [ ] Instruct planner agent to emit 0-1 candidates only when planning reveals architectural patterns or dependency insights
- [ ] In each agent, update the metadata-writing stage to include `memory_candidates` in the `.return-meta.json` output
- [ ] Include guidance on confidence scoring: >= 0.8 for clearly reusable patterns/configs, 0.5-0.8 for potentially useful techniques/workflows, < 0.5 for speculative insights

**Timing**: 1 hour

**Depends on**: 1

**Files to modify**:
- `.claude/agents/general-research-agent.md` -- New emission stage, metadata update
- `.claude/agents/general-implementation-agent.md` -- New emission stage, metadata update
- `.claude/agents/planner-agent.md` -- New emission stage, metadata update

**Verification**:
- Each agent has a clearly labeled memory emission stage at the correct insertion point
- Stage numbers are consistent after renumbering
- Metadata-writing stages include `memory_candidates` array in the JSON output
- Confidence scoring guidance is present in each agent

---

### Phase 3: Skill Postflight Propagation [NOT STARTED]

**Goal**: Update skill-researcher and skill-implementer to extract `memory_candidates` from `.return-meta.json` and propagate to state.json with append semantics.

**Tasks**:
- [ ] In skill-researcher SKILL.md Stage 6 (Parse Subagent Return), add jq extraction: `memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")`
- [ ] In skill-researcher, add propagation step after Stage 7 to append candidates to state.json task entry
- [ ] In skill-implementer SKILL.md Stage 6, add same jq extraction for `memory_candidates`
- [ ] In skill-implementer, add propagation step to append candidates to state.json task entry
- [ ] Use append semantics in both skills: merge new candidates with existing `memory_candidates` array on the task entry rather than overwriting
- [ ] Include the safe jq append pattern from research: existing candidates `// []` + new candidates

**Timing**: 1 hour

**Depends on**: 2

**Files to modify**:
- `.claude/skills/skill-researcher/SKILL.md` -- Add extraction and propagation steps
- `.claude/skills/skill-implementer/SKILL.md` -- Add extraction and propagation steps

**Verification**:
- Both skills extract `memory_candidates` with `// []` fallback
- Propagation uses append semantics (not overwrite)
- jq commands follow safe patterns (no `!=` operator)
- A task that goes through research then implementation accumulates candidates from both

## Testing & Validation

- [ ] Verify return-metadata-file.md schema is complete and internally consistent
- [ ] Verify all three agent files have correct stage numbering after insertion
- [ ] Verify each agent's metadata-writing stage includes `memory_candidates` in JSON output
- [ ] Verify skill-researcher extraction and propagation steps are syntactically correct
- [ ] Verify skill-implementer extraction and propagation steps match researcher pattern
- [ ] Verify state-management-schema.md documents the new field
- [ ] Grep all modified files for `!=` operator to ensure jq safety compliance

## Artifacts & Outputs

- `specs/446_add_memory_candidate_emission_agents_return_metadata/plans/01_memory-emission-plan.md` (this plan)
- `specs/446_add_memory_candidate_emission_agents_return_metadata/summaries/01_memory-emission-summary.md` (after implementation)
- Modified files:
  - `.claude/context/formats/return-metadata-file.md`
  - `.claude/context/reference/state-management-schema.md`
  - `.claude/agents/general-research-agent.md`
  - `.claude/agents/general-implementation-agent.md`
  - `.claude/agents/planner-agent.md`
  - `.claude/skills/skill-researcher/SKILL.md`
  - `.claude/skills/skill-implementer/SKILL.md`

## Rollback/Contingency

All changes are additive -- the `memory_candidates` field is optional with `// []` fallback everywhere. To revert: remove the emission stages from the three agents, remove extraction/propagation from the two skills, and remove the field documentation from return-metadata-file.md and state-management-schema.md. No data migration or cleanup needed since no memory files are created by this task.
