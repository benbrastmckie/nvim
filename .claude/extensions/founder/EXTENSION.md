## Founder Extension (v3.0)

Strategic business analysis tools for founders and entrepreneurs. Integrates forcing question patterns and decision frameworks inspired by Y Combinator office hours methodology.

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-market | market-agent | Market sizing research (uses forcing_data) |
| skill-analyze | analyze-agent | Competitive analysis research (uses forcing_data) |
| skill-strategy | strategy-agent | GTM strategy research (uses forcing_data) |
| skill-legal | legal-council-agent | Contract review research (uses forcing_data) |
| skill-project | project-agent | Project timeline research: WBS, PERT, resources |
| skill-spreadsheet | spreadsheet-agent | Cost breakdown spreadsheet generation (uses forcing_data) |
| skill-finance | finance-agent | Financial analysis and verification (uses forcing_data) |
| skill-founder-plan | founder-plan-agent | Shared task planning (content-aware) |
| skill-founder-implement | founder-implement-agent | Shared task implementation (type-aware) |

### Commands

| Command | Usage | Description |
|---------|-------|-------------|
| `/market` | `/market "fintech payments"` | Market sizing with forcing questions |
| `/analyze` | `/analyze "competitor landscape"` | Competitive analysis with forcing questions |
| `/strategy` | `/strategy "B2B launch"` | GTM strategy with forcing questions |
| `/legal` | `/legal "SaaS vendor agreement"` | Contract review with forcing questions |
| `/project` | `/project "Mobile App Redesign"` | Project timeline with forcing questions |
| `/sheet` | `/sheet "Q1 launch costs"` | Cost breakdown spreadsheet with forcing questions |
| `/finance` | `/finance "Q1 revenue verification"` | Financial analysis and verification with forcing questions |

All commands accept: description string (create task), task number (run research), file path (read context), or `--quick` (legacy standalone).

### Language Routing

Tasks with `language: founder` use `task_type` for research routing (`founder:{task_type}`). Planning and implementation use shared founder agents regardless of task_type.
