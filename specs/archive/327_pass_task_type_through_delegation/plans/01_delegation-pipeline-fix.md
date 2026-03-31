# Implementation Plan: Pass task_type Through Founder Delegation Pipeline

- **Task**: 327 - Pass task_type through founder delegation pipeline
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: reports/01_delegation-pipeline-gap.md
- **Artifacts**: plans/01_delegation-pipeline-fix.md (this file)
- **Standards**: plan-format.md, artifact-formats.md
- **Type**: meta

## Overview

Add `task_type` field to the delegation context passed from skills to agents. Four files need updating: two skills (senders) and two agents (receivers). The plan agent also needs its Stage 4 updated to use `task_type` for report type determination instead of keyword matching.

### Research Integration

**Research Report**: [01_delegation-pipeline-gap.md](../reports/01_delegation-pipeline-gap.md)

**Key Findings**: task_type is stored in state.json by all 6 founder commands but omitted from the task_context in both skill-founder-plan and skill-founder-implement. Agents infer report type via keyword matching, which is fragile.

**task_type -> report_type mapping**:
| task_type | report_type |
|-----------|-------------|
| market | market-sizing |
| analyze | competitive-analysis |
| strategy | gtm-strategy |
| legal | contract-review |
| project | project-timeline |
| sheet | cost-breakdown |

## Goals & Non-Goals

**Goals**:
- Pass task_type from state.json through skills to agents
- Use task_type as primary report type determination in plan agent
- Preserve backward compatibility for tasks without task_type

**Non-Goals**:
- Changing output formats (that's tasks 328/329)
- Modifying research skills or command files
- Removing keyword matching (kept as fallback)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Legacy tasks missing task_type | Low | Medium | Null-safe extraction, keyword matching fallback |
| Agent ignores new field | Low | Low | Document in Stage 1 schema |

## Implementation Phases

### Phase 1: Update Skills (Senders) [COMPLETED]

**Goal**: Add task_type extraction and inclusion in both founder skills' Stage 4

**Tasks**:
- [ ] In `skill-founder-plan/SKILL.md` Stage 4 (line ~101): Add task_type extraction from state.json using jq, add `"task_type"` field to `task_context` JSON
- [ ] In `skill-founder-implement/SKILL.md` Stage 4 (line ~108): Same change as above

**Exact change for both files** — add extraction before context JSON:
```bash
# Extract task_type from state.json (null-safe)
task_type=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .task_type // null' \
  specs/state.json)
```

Then add to task_context:
```json
"task_type": "market"
```

**Timing**: 15 minutes

### Phase 2: Update Agents (Receivers) [COMPLETED]

**Goal**: Document task_type in agent input schemas and use it for report type determination

**Tasks**:
- [ ] In `founder-plan-agent.md` Stage 1 (line ~67): Add `"task_type": "market"` to documented task_context schema
- [ ] In `founder-plan-agent.md` Stage 4 (line ~237): Replace keyword-first approach with task_type-first lookup, keeping keyword matching as fallback
- [ ] In `founder-implement-agent.md` Stage 1 (line ~82): Add `"task_type": "market"` to documented task_context schema

**Plan agent Stage 4 replacement**:
```markdown
### Stage 4: Determine Report Type

**Primary**: Use task_type from delegation context (if present):

| task_type | Report Type | Template |
|-----------|-------------|----------|
| market | market-sizing | market-sizing.md |
| analyze | competitive-analysis | competitive-analysis.md |
| strategy | gtm-strategy | gtm-strategy.md |
| legal | contract-review | contract-analysis.md |
| project | project-timeline | project-timeline.md |
| sheet | cost-breakdown | cost-breakdown.md |

**Fallback** (when task_type is null — legacy tasks): Identify report type from research report header or content:

| Keywords | Report Type |
|----------|-------------|
| market, sizing, TAM, SAM, SOM | market-sizing |
| competitive, competitor, analysis | competitive-analysis |
| GTM, go-to-market, strategy, launch | gtm-strategy |
| contract, legal, review, clause | contract-review |
| project, timeline, WBS, PERT | project-timeline |
| cost, budget, runway, burn | cost-breakdown |

Default to market-sizing if unclear.
```

**Timing**: 20 minutes

### Phase 3: Validation [COMPLETED]

**Goal**: Verify changes are consistent and complete

**Tasks**:
- [ ] Verify all 4 files have consistent task_context schema (same fields in same order)
- [ ] Verify task_type is null-safe in both skills (jq `// null` pattern)
- [ ] Verify plan agent Stage 4 has both primary (task_type) and fallback (keyword) paths
- [ ] Verify implement agent Stage 1 documents but does not break existing report_type extraction from plan

**Timing**: 10 minutes

## Testing & Validation

- [ ] All 4 files have `task_type` in documented task_context schema
- [ ] Skills extract task_type with null-safe jq pattern
- [ ] Plan agent uses task_type as primary report type determination
- [ ] Keyword matching preserved as fallback when task_type is null
- [ ] No changes to output format or paths (deferred to tasks 328/329)

## Artifacts & Outputs

- plans/01_delegation-pipeline-fix.md (this plan)
- Modified: `.claude/extensions/founder/skills/skill-founder-plan/SKILL.md`
- Modified: `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md`
- Modified: `.claude/extensions/founder/agents/founder-plan-agent.md`
- Modified: `.claude/extensions/founder/agents/founder-implement-agent.md`

## Rollback/Contingency

If implementation fails:
1. Changes are additive (new field) — existing functionality unaffected
2. Null-safe extraction means missing task_type causes no errors
3. Keyword matching fallback ensures no regression for existing tasks
