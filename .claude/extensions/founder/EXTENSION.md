## Founder Extension (v2.1)

Strategic business analysis tools for founders and entrepreneurs. Integrates forcing question patterns and decision frameworks inspired by Y Combinator office hours methodology.

### Pre-Task Forcing Questions (v2.1 NEW)

Commands now ask essential forcing questions BEFORE creating tasks:

```
/market "fintech payments"
  -> Mode selection (VALIDATE, SIZE, SEGMENT, DEFEND)
  -> Problem definition question
  -> Target entity question
  -> Geographic scope question
  -> Price point question (optional)
  -> Task created with forcing_data stored
```

This workflow reverses the previous pattern (task first, questions during research) to gather essential data upfront, creating richer task entries and enabling more focused research.

### Task Integration (v2.0+)

Commands integrate with the task system by default:
- Ask forcing questions BEFORE task creation (new in v2.1)
- Create tasks with `task_type` field for type-based routing
- Store forcing_data in task metadata
- Use `/research`, `/plan`, and `/implement` workflow with founder-specific routing
- Store artifacts in `specs/{NNN}_{SLUG}/` for tracking
- Reports output to `strategy/` directory
- Support `--quick` flag for legacy standalone mode

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/market` | `/market "fintech payments"` | Ask forcing questions, create task (stops at [NOT STARTED]) |
| `/market` | `/market 234` | Run research on existing task |
| `/market` | `/market --quick [args]` | Legacy standalone mode |
| `/analyze` | `/analyze "competitor landscape"` | Ask forcing questions, create task (stops at [NOT STARTED]) |
| `/strategy` | `/strategy "B2B launch"` | Ask forcing questions, create task (stops at [NOT STARTED]) |

### Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task, stop at [NOT STARTED] |
| Task number | Load existing task, run research, stop at [RESEARCHED] |
| File path | Read file for context, ask questions, create task |
| `--quick [args]` | Legacy standalone mode (no task creation) |

### Workflow (v2.1)

The standard four-stage workflow:

```
/market "description"   -> Asks forcing questions, creates task with data, stops at [NOT STARTED]
/research {N}           -> Uses forcing_data, completes research, stops at [RESEARCHED]
/plan {N}               -> Reads research report, creates implementation plan
/implement {N}          -> Executes plan, generates strategy/market-sizing-*.md
```

Alternative: Resume existing task (skips STAGE 0 forcing questions):
```
/market {N}             -> Runs research on existing task, stops at [RESEARCHED]
```

### task_type Field (v2.1 NEW)

Tasks created by founder commands include a `task_type` field for finer-grained routing:

| Command | task_type | Research Skill |
|---------|-----------|----------------|
| /market | market | skill-market |
| /analyze | analyze | skill-analyze |
| /strategy | strategy | skill-strategy |

When `/research {N}` is invoked on a founder task with `task_type` set, routing uses the composite key `founder:{task_type}` to select the appropriate skill.

### Forcing Data Storage

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

### Skill-to-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-market | market-agent | Market sizing research (uses forcing_data) |
| skill-analyze | analyze-agent | Competitive analysis (uses forcing_data) |
| skill-strategy | strategy-agent | GTM strategy (uses forcing_data) |
| skill-founder-plan | founder-plan-agent | Task planning with forcing questions |
| skill-founder-implement | founder-implement-agent | Execute plan and generate report |

### Language-Based Routing

Tasks with `language: founder` route to founder-specific skills:

| Workflow | Routing Key | Skill | Agent |
|----------|-------------|-------|-------|
| `/research` (task_type: market) | founder:market | skill-market | market-agent |
| `/research` (task_type: analyze) | founder:analyze | skill-analyze | analyze-agent |
| `/research` (task_type: strategy) | founder:strategy | skill-strategy | strategy-agent |
| `/research` (no task_type) | founder | skill-market | market-agent |
| `/plan` | founder | skill-founder-plan | founder-plan-agent |
| `/implement` | founder | skill-founder-implement | founder-implement-agent |

### Output Locations

| Mode | Report Location | Tracking Artifacts |
|------|-----------------|-------------------|
| Task workflow | `strategy/{report-type}-{slug}.md` | `specs/{NNN}_{SLUG}/` |
| Legacy (--quick) | `founder/{report-type}-{datetime}.md` | None |

### Context Files

| Path | Purpose |
|------|---------|
| `context/project/founder/domain/business-frameworks.md` | TAM/SAM/SOM, business model canvas |
| `context/project/founder/domain/strategic-thinking.md` | CEO cognitive patterns, YC principles |
| `context/project/founder/patterns/forcing-questions.md` | Forcing question framework |
| `context/project/founder/patterns/decision-making.md` | Two-way doors, inversion, focus as subtraction |
| `context/project/founder/patterns/mode-selection.md` | Operational modes pattern |
| `context/project/founder/templates/market-sizing.md` | TAM/SAM/SOM template |
| `context/project/founder/templates/competitive-analysis.md` | Competitor analysis template |
| `context/project/founder/templates/gtm-strategy.md` | Go-to-market template |

### MCP Tool Integration

Founder extension integrates external MCP tools for enhanced data gathering:

| MCP Server | Agent | Purpose | Setup |
|------------|-------|---------|-------|
| sec-edgar | market-agent | Public company SEC filings (10-K, 10-Q, 8-K) | None required |
| firecrawl | analyze-agent | Full page web scraping, competitor analysis | Requires FIRECRAWL_API_KEY |

**Lazy Loading**: MCP servers only start when their assigned agent is invoked. Other agents (strategy-agent, founder-plan-agent, founder-implement-agent) do not load any MCP servers.

**Setup**: See README.md for Firecrawl API key configuration.

### Key Patterns

**Pre-Task Forcing Questions** (v2.1): Essential questions asked BEFORE task creation, storing data in task metadata for use during research.

**Forcing Questions**: One question per AskUserQuestion, explicit push-back on vague answers. Specificity is the only currency.

**Mode-Based Operation**: Commands offer 3-4 operational modes giving user explicit scope control (e.g., LAUNCH, SCALE, PIVOT, EXPAND).

**Three-Phase Workflow**: (1) Context gathering, (2) Interactive forcing questions, (3) Synthesis/Report generation.

**Completeness Principle**: Always model multiple scenarios/options. AI makes marginal cost of completeness near-zero.

**Decision Frameworks**:
- Two-way doors (reversible): Move fast
- One-way doors (irreversible): Be rigorous
- Inversion: Also ask "What makes us fail?"
- Focus as subtraction: Explicitly document what NOT to do

### Migration from v2.0

| v2.0 Pattern | v2.1 Equivalent |
|--------------|-----------------|
| `/market "fintech"` -> task created -> /research asks questions | `/market "fintech"` -> questions asked -> task created with data |
| No task_type field | task_type: "market", "analyze", or "strategy" |
| `/research` uses language routing | `/research` uses task_type routing when available |
| forcing_data gathered during research | forcing_data gathered at command invocation (STAGE 0) |

### Migration from v1.0

| v1.0 Pattern | v2.1 Equivalent |
|--------------|-----------------|
| `/market fintech` | `/market --quick fintech` (standalone) |
| | `/market "fintech analysis"` (task workflow with pre-task questions) |
| Artifact in `founder/` | Artifact in `strategy/` (task) or `founder/` (--quick) |
| No task tracking | Full task lifecycle with forcing_data storage |
