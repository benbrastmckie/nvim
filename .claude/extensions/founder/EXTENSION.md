## Founder Extension (v2.0)

Strategic business analysis tools for founders and entrepreneurs. Integrates forcing question patterns and decision frameworks inspired by Y Combinator office hours methodology.

### Task Integration (v2.0)

Commands now integrate with the task system by default:
- Create tasks automatically when invoked with description or file
- Use `/plan` and `/implement` workflow with founder-specific routing
- Store artifacts in `specs/{NNN}_{SLUG}/` for tracking
- Reports output to `strategy/` directory
- Support `--quick` flag for legacy standalone mode

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/market` | `/market "fintech payments"` | TAM/SAM/SOM market sizing (creates task) |
| `/market` | `/market 234` | Operate on existing task |
| `/market` | `/market --quick [args]` | Legacy standalone mode |
| `/analyze` | `/analyze "competitor landscape"` | Competitive analysis (creates task) |
| `/strategy` | `/strategy "B2B launch"` | GTM strategy (creates task) |

### Input Types

| Input | Behavior |
|-------|----------|
| Description string | Create task, run /plan, run /implement |
| Task number | Load existing task, run /plan, run /implement |
| File path | Read file for context, create task, run workflow |
| `--quick [args]` | Legacy standalone mode (no task creation) |

### Skill-to-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-market | market-agent | Standalone market sizing (--quick) |
| skill-analyze | analyze-agent | Standalone competitive analysis (--quick) |
| skill-strategy | strategy-agent | Standalone GTM strategy (--quick) |
| skill-founder-plan | founder-plan-agent | Task planning with forcing questions |
| skill-founder-implement | founder-implement-agent | Execute plan and generate report |

### Language-Based Routing

Tasks with `language: founder` route to founder-specific skills:

| Workflow | Skill | Agent |
|----------|-------|-------|
| `/plan` | skill-founder-plan | founder-plan-agent |
| `/implement` | skill-founder-implement | founder-implement-agent |

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

### Key Patterns

**Forcing Questions**: One question per AskUserQuestion, explicit push-back on vague answers. Specificity is the only currency.

**Mode-Based Operation**: Commands offer 3-4 operational modes giving user explicit scope control (e.g., LAUNCH, SCALE, PIVOT, EXPAND).

**Three-Phase Workflow**: (1) Context gathering, (2) Interactive forcing questions, (3) Synthesis/Report generation.

**Completeness Principle**: Always model multiple scenarios/options. AI makes marginal cost of completeness near-zero.

**Decision Frameworks**:
- Two-way doors (reversible): Move fast
- One-way doors (irreversible): Be rigorous
- Inversion: Also ask "What makes us fail?"
- Focus as subtraction: Explicitly document what NOT to do

### Migration from v1.0

| v1.0 Pattern | v2.0 Equivalent |
|--------------|-----------------|
| `/market fintech` | `/market --quick fintech` (standalone) |
| | `/market "fintech analysis"` (task workflow) |
| Artifact in `founder/` | Artifact in `strategy/` (task) or `founder/` (--quick) |
| No task tracking | Full task lifecycle with status tracking |
