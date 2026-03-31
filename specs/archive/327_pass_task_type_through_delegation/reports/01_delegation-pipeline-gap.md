# Research Report: Pass task_type Through Founder Delegation Pipeline

- **Task**: 327 - Pass task_type through founder delegation pipeline
- **Status**: [RESEARCHED]
- **Language**: meta
- **Session**: sess_1774948800_d7e327

## Summary

The `task_type` field is stored in state.json by all founder commands but never passed to the plan or implement agents. Both `skill-founder-plan` and `skill-founder-implement` construct a `task_context` object that omits `task_type`, forcing agents to infer report type from keyword matching on research content.

## Findings

### Current State: task_type Storage

All 6 founder commands store `task_type` in state.json:

| Command | task_type Value | Report Type Mapping |
|---------|----------------|---------------------|
| `/market` | `"market"` | market-sizing |
| `/analyze` | `"analyze"` | competitive-analysis |
| `/strategy` | `"strategy"` | gtm-strategy |
| `/legal` | `"legal"` | contract-review |
| `/project` | `"project"` | project-timeline |
| `/sheet` | `"sheet"` | cost-breakdown |

### Gap: task_type Not Passed to Agents

**skill-founder-plan/SKILL.md** (Stage 4, lines 101-121):
```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "market_sizing_fintech_payments",
    "description": "Market sizing: fintech payments",
    "language": "founder"
    // MISSING: "task_type": "market"
  }
}
```

**skill-founder-implement/SKILL.md** (Stage 4, lines 108-129):
```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "market_sizing_fintech_payments",
    "description": "Market sizing: fintech payments",
    "language": "founder"
    // MISSING: "task_type": "market"
  }
}
```

### Gap: Agents Use Keyword Matching Instead

**founder-plan-agent.md** (Stage 4, lines 237-249):
Report type is determined by keyword matching on research report content:
- Keywords like "TAM, SAM, SOM" -> market-sizing
- Keywords like "competitive, competitor" -> competitive-analysis
- Default: market-sizing if unclear

This is fragile and could misclassify tasks.

**founder-implement-agent.md** (Stage 2, lines 105-112):
Report type is extracted from the plan file, which itself was set by the keyword-matching approach above.

### Gap: Agent Parse Stages Don't Expect task_type

**founder-plan-agent.md** (Stage 1, lines 67-85):
```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "...",
    "description": "...",
    "language": "founder"
    // No task_type field documented
  }
}
```

**founder-implement-agent.md** (Stage 1, lines 82-102):
Same structure — no `task_type` field documented.

### Existing task_type Infrastructure

The context discovery system already understands `task_type` via `index-entries.json`:
- `load_when.task_types` field exists on 5 entries (legal-planning, project-planning, spreadsheet-frameworks, cost-forcing-questions, cost-breakdown.typ)
- Research routing already uses the composite key `founder:{task_type}` successfully
- Only the plan/implement pipeline is missing this data

## Required Changes

### File 1: skill-founder-plan/SKILL.md

**Location**: Stage 4 (Context Preparation), lines 101-121

**Change**: Extract `task_type` from state.json and add to `task_context`:

```bash
# Extract task_type from state.json
task_type=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .task_type // null' \
  specs/state.json)
```

Add to task_context JSON:
```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "market_sizing_fintech_payments",
    "description": "Market sizing: fintech payments",
    "language": "founder",
    "task_type": "market"
  }
}
```

### File 2: skill-founder-implement/SKILL.md

**Location**: Stage 4 (Context Preparation), lines 108-129

**Change**: Same extraction and inclusion pattern as above.

### File 3: founder-plan-agent.md

**Location**: Stage 1 (Parse Delegation Context), lines 67-85

**Change**: Document `task_type` field in expected input format.

**Location**: Stage 4 (Determine Report Type), lines 237-249

**Change**: Use `task_type` as primary report type determination, with keyword matching as fallback for legacy tasks without `task_type`.

Add task_type-to-report-type mapping table:

| task_type | report_type |
|-----------|-------------|
| market | market-sizing |
| analyze | competitive-analysis |
| strategy | gtm-strategy |
| legal | contract-review |
| project | project-timeline |
| sheet | cost-breakdown |
| (null/missing) | Fallback to keyword matching |

### File 4: founder-implement-agent.md

**Location**: Stage 1 (Parse Delegation Context), lines 82-102

**Change**: Document `task_type` field in expected input format. Agent already gets report type from the plan, but having `task_type` enables future format-aware decisions (e.g., tasks 328/329).

## Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing tasks without task_type | Low | Medium | Fallback to keyword matching when task_type is null |
| task_type value mismatch with report type | Low | Low | Explicit mapping table, validated at creation time |

## Recommendations

1. **Add task_type to both skills' Stage 4** — 2 insertions, same pattern
2. **Update plan agent Stage 4** — Use task_type as primary, keyword matching as fallback
3. **Update both agents' Stage 1** — Document task_type in expected input schema
4. **Do NOT remove keyword matching** — Keep as fallback for backward compatibility with tasks created before task_type was introduced
