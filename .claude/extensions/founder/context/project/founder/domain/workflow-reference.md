# Founder Extension Workflow Reference

## Pre-Task Forcing Questions

Commands ask essential forcing questions BEFORE creating tasks:

```
/market "fintech payments"
  -> Mode selection (VALIDATE, SIZE, SEGMENT, DEFEND)
  -> Problem definition question
  -> Target entity question
  -> Geographic scope question
  -> Price point question (optional)
  -> Task created with forcing_data stored
```

This workflow gathers essential data upfront, creating richer task entries and enabling more focused research.

```
/legal "SaaS vendor agreement"
  -> Mode selection (REVIEW, NEGOTIATE, TERMS, DILIGENCE)
  -> Contract type question
  -> Primary concern question
  -> Position question
  -> Financial exposure question
  -> Task created with forcing_data stored
  -> Escalation assessment (self-serve / attorney review)
```

## Unified Phased Workflow (v3.0)

All 5 commands follow the same standard lifecycle:

```
/{command} "description"   -> Asks forcing questions, creates task, stops at [NOT STARTED]
/research {N}              -> Domain-specific research agent, stops at [RESEARCHED]
/plan {N}                  -> Shared planner (content-aware), creates plan
/implement {N}             -> Shared implementer (type-aware), generates final artifact
```

The differentiation is at the **research** phase where each command has a specialized agent. Planning and implementation use shared agents that detect the task type from the research report content.

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task, stop at [NOT STARTED] |
| Task number | Load existing task, run research, stop at [RESEARCHED] |
| File path | Read file for context, ask questions, create task |
| `--quick [args]` | Legacy standalone mode (no task creation) |

## Legal Command Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **REVIEW** | Risk assessment | Identify problematic clauses, red flags, missing protections |
| **NEGOTIATE** | Position building | Counter-terms, leverage points, BATNA/ZOPA analysis |
| **TERMS** | Term sheet review | Key terms, market benchmarks, standard vs non-standard |
| **DILIGENCE** | Due diligence | Comprehensive review for transaction, IP, liability, R&W |

## task_type Field

Tasks created by founder commands include a `task_type` field for finer-grained routing:

| Command | task_type | Research Skill |
|---------|-----------|----------------|
| /market | market | skill-market |
| /analyze | analyze | skill-analyze |
| /strategy | strategy | skill-strategy |
| /legal | legal | skill-legal |
| /project | project | skill-project |

When `/research {N}` is invoked on a founder task with `task_type` set, routing uses the composite key `founder:{task_type}` to select the appropriate skill.

## Language-Based Routing (Full Table)

| Workflow | Routing Key | Skill | Agent |
|----------|-------------|-------|-------|
| `/research` (task_type: market) | founder:market | skill-market | market-agent |
| `/research` (task_type: analyze) | founder:analyze | skill-analyze | analyze-agent |
| `/research` (task_type: strategy) | founder:strategy | skill-strategy | strategy-agent |
| `/research` (task_type: legal) | founder:legal | skill-legal | legal-council-agent |
| `/research` (task_type: project) | founder:project | skill-project | project-agent |
| `/research` (no task_type) | founder | skill-market | market-agent |
| `/plan` (task_type: market) | founder:market | skill-founder-plan | founder-plan-agent |
| `/plan` (task_type: analyze) | founder:analyze | skill-founder-plan | founder-plan-agent |
| `/plan` (task_type: strategy) | founder:strategy | skill-founder-plan | founder-plan-agent |
| `/plan` (task_type: legal) | founder:legal | skill-founder-plan | founder-plan-agent |
| `/plan` (task_type: project) | founder:project | skill-founder-plan | founder-plan-agent |
| `/plan` (no task_type) | founder | skill-founder-plan | founder-plan-agent |
| `/implement` (task_type: market) | founder:market | skill-founder-implement | founder-implement-agent |
| `/implement` (task_type: analyze) | founder:analyze | skill-founder-implement | founder-implement-agent |
| `/implement` (task_type: strategy) | founder:strategy | skill-founder-implement | founder-implement-agent |
| `/implement` (task_type: legal) | founder:legal | skill-founder-implement | founder-implement-agent |
| `/implement` (task_type: project) | founder:project | skill-founder-implement | founder-implement-agent |
| `/implement` (no task_type) | founder | skill-founder-implement | founder-implement-agent |

## Forcing Data Storage

Pre-gathered forcing data is stored in task metadata:

```json
{
  "task_type": "market",
  "forcing_data": {
    "mode": "SIZE",
    "problem": "Mid-market SaaS struggle with deploy coordination",
    "target_entity": "VP Engineering at 50-200 employee SaaS companies",
    "geography": "US initially, North America expansion",
    "price_point": "$500/month/team",
    "gathered_at": "2026-03-18T10:00:00Z"
  }
}
```

Research agents use this data and only ask follow-up questions for missing details.

## Output Locations

| Mode | Report Location | Tracking Artifacts |
|------|-----------------|-------------------|
| Task workflow | `strategy/{report-type}-{slug}.md` | `specs/{NNN}_{SLUG}/` |
| Legacy (--quick) | `founder/{report-type}-{datetime}.md` | None |

## Key Patterns

**Pre-Task Forcing Questions**: Essential questions asked BEFORE task creation, storing data in task metadata for use during research.

**Forcing Questions**: One question per AskUserQuestion, explicit push-back on vague answers. Specificity is the only currency.

**Mode-Based Operation**: Commands offer 3-4 operational modes giving user explicit scope control (e.g., LAUNCH, SCALE, PIVOT, EXPAND).

**Completeness Principle**: Always model multiple scenarios/options. AI makes marginal cost of completeness near-zero.

**Decision Frameworks**:
- Two-way doors (reversible): Move fast
- One-way doors (irreversible): Be rigorous
- Inversion: Also ask "What makes us fail?"
- Focus as subtraction: Explicitly document what NOT to do

## MCP Tool Integration

Founder extension integrates external MCP tools for enhanced data gathering:

| MCP Server | Agent | Purpose | Setup |
|------------|-------|---------|-------|
| sec-edgar | market-agent | Public company SEC filings (10-K, 10-Q, 8-K) | None required |
| firecrawl | analyze-agent | Full page web scraping, competitor analysis | Requires FIRECRAWL_API_KEY |

**Lazy Loading**: MCP servers only start when their assigned agent is invoked. Other agents (strategy-agent, legal-council-agent, project-agent, founder-plan-agent, founder-implement-agent) do not load any MCP servers.

**Setup**: See README.md for Firecrawl API key configuration.
