# Founder Extension (v3.0)

Strategic business analysis tools for founders and entrepreneurs. Integrates forcing question patterns and decision frameworks inspired by Y Combinator office hours methodology and gstack.

## What's New in v3.0

- **Unified Phased Workflow**: All 9 commands (market, analyze, strategy, legal, project, deck, finance, sheet, consult) follow the same `/research -> /plan -> /implement` lifecycle
- **Project Command Updated**: `/project` now creates research reports instead of generating timelines directly
- **Per-Type Routing**: Complete routing table with 5 types across 3 phases (research, plan, implement)
- **Breaking Changes**: project-agent is now research-only; TRACK/REPORT modes move to `/implement`

## Overview

This extension provides nine commands for strategic business analysis:

| Command | Purpose | Output |
|---------|---------|--------|
| `/market` | TAM/SAM/SOM market sizing | Market sizing report |
| `/analyze` | Competitive landscape analysis | Competitive analysis with positioning map |
| `/strategy` | Go-to-market strategy | GTM strategy with 90-day plan |
| `/legal` | Contract review and legal counsel | Risk assessment, negotiation strategy |
| `/project` | Project timeline management | WBS, PERT estimates, Gantt timeline |
| `/deck` | Pitch deck creation | Slidev pitch deck with material synthesis |
| `/finance` | Financial analysis | Revenue verification, runway analysis |
| `/sheet` | Cost breakdown spreadsheets | Budget and cost analysis spreadsheets |
| `/meeting` | Investor meeting note processing | Structured meeting file with YAML frontmatter, CSV tracker update |
| `/consult` | Collaborative design consultation | Socratic dialogue with domain expert perspective |

## Installation

This extension is automatically available when loaded via the extension picker.

## MCP Tool Setup

The founder extension integrates MCP tools for enhanced data gathering.

### SEC EDGAR (No Setup Required)

SEC EDGAR provides access to public company filings (10-K, 10-Q, 8-K). No API key or configuration needed.

- **Fully free**, unlimited access to SEC public filings
- **Used by**: market-agent (for public company financials and market sizing)
- **Lazy loaded**: Only starts when market-agent is invoked

### Firecrawl (Free Tier - 500 credits/month)

Firecrawl enables full-page web scraping for competitor analysis.

**Setup**:
1. Visit https://firecrawl.dev/
2. Create a free account
3. Copy API key from dashboard
4. Add to shell profile:
   ```bash
   export FIRECRAWL_API_KEY="your-key-here"
   ```
5. Restart terminal or source your profile

**Capabilities**:
- `scrape`: Full page content as markdown
- `crawl`: Recursive site crawling
- `map`: Site structure mapping
- `extract`: LLM-powered data extraction

**Used by**: analyze-agent (for competitor website analysis)

**Note**: Firecrawl is optional. If API key is not configured, analyze-agent will fall back to WebSearch for competitor research.

## Commands

### /market

Market sizing analysis using TAM/SAM/SOM framework with forcing questions.

**Syntax**:
```bash
# Task workflow (default)
/market "fintech payments app"    # Create task and gather data
/market 234                       # Run research on existing task

# Legacy standalone mode
/market --quick fintech payments  # No task creation
```

**Modes**: VALIDATE, SIZE, SEGMENT, DEFEND

### /analyze

Competitive landscape analysis with positioning maps and battle cards.

**Syntax**:
```bash
# Task workflow (default)
/analyze "fintech competitors"    # Create task and gather data
/analyze 234                      # Run research on existing task

# Legacy standalone mode
/analyze --quick stripe,square    # No task creation
```

**Modes**: LANDSCAPE, DEEP, POSITION, BATTLE

### /strategy

Go-to-market strategy development with positioning and channel analysis.

**Syntax**:
```bash
# Task workflow (default)
/strategy "B2B SaaS launch"       # Create task and gather data
/strategy 234                     # Run research on existing task

# Legacy standalone mode
/strategy --quick B2B launch      # No task creation
```

**Modes**: LAUNCH, SCALE, PIVOT, EXPAND

### /legal

Contract review and legal counsel with risk assessment and negotiation strategy.

**Syntax**:
```bash
# Task workflow (default)
/legal "SaaS vendor agreement"    # Create task and gather data
/legal 256                        # Run research on existing task

# Legacy standalone mode
/legal --quick "contract.pdf"     # No task creation
```

**Modes**: REVIEW, NEGOTIATE, TERMS, DILIGENCE

### /project

Project timeline management with WBS, PERT estimation, and resource allocation.

**Syntax**:
```bash
# Task workflow (default)
/project "Mobile App Redesign"    # Create task and gather data
/project 234                      # Run research on existing task

# Legacy standalone mode
/project --quick PLAN             # No task creation
```

**Modes**: PLAN, TRACK, REPORT

### /deck

Pitch deck creation with material synthesis and slide mapping.

**Syntax**:
```bash
# Task workflow (default)
/deck "Seed round pitch for AI startup"  # Ask questions, create task
/deck 234                                # Resume research on existing task
/deck /path/to/context.md               # Use file as primary source

# Legacy standalone mode
/deck --quick "investor pitch"           # No task creation
```

### /finance

Financial analysis and verification with spreadsheet generation.

**Syntax**:
```bash
# Task workflow (default)
/finance "Q1 revenue verification"       # Ask forcing questions, create task
/finance 330                             # Resume research on existing task
/finance /path/to/projections.xlsx       # Use file as financial input

# Legacy standalone mode
/finance --quick "runway analysis"       # No task creation
```

### /sheet

Cost breakdown spreadsheet generation with forcing questions.

**Syntax**:
```bash
# Task workflow (default)
/sheet "Q1 product launch costs"         # Ask forcing questions, create task
/sheet 234                               # Resume research on existing task

# Legacy standalone mode
/sheet --quick BUDGET                    # No task creation
```

**Modes**: BUDGET, FORECAST, COMPARISON

### /meeting

Process investor meeting notes into structured meeting files with YAML frontmatter and CSV tracker updates.

**Syntax**:
```bash
# Process notes file directly
/meeting /path/to/notes.md

# Resume processing on existing task
/meeting 382

# Update CSV from existing structured meeting file
/meeting --update /path/to/meeting-file.md
```

Unlike other founder commands that use forcing questions, `/meeting` takes a file path directly and processes autonomously using web research to enrich the investor profile.

## Architecture

```
founder/
├── manifest.json              # Extension configuration (v3.0)
├── EXTENSION.md               # CLAUDE.md merge content
├── index-entries.json         # Context discovery entries
├── README.md                  # This file
│
├── commands/                  # Slash commands
│   ├── market.md             # /market command (task-integrated)
│   ├── analyze.md            # /analyze command (task-integrated)
│   ├── strategy.md           # /strategy command (task-integrated)
│   ├── legal.md              # /legal command (task-integrated)
│   ├── project.md            # /project command (task-integrated)
│   ├── deck.md               # /deck command (task-integrated)
│   ├── finance.md            # /finance command (task-integrated)
│   ├── sheet.md              # /sheet command (task-integrated)
│   └── consult.md            # /consult command (standalone immediate-mode)
│
├── skills/                    # Skill wrappers
│   ├── skill-market/         # Market sizing research
│   │   └── SKILL.md
│   ├── skill-analyze/        # Competitive analysis research
│   │   └── SKILL.md
│   ├── skill-strategy/       # GTM strategy research
│   │   └── SKILL.md
│   ├── skill-legal/          # Contract review research
│   │   └── SKILL.md
│   ├── skill-project/        # Project timeline research
│   │   └── SKILL.md
│   ├── skill-deck-research/  # Deck content research
│   │   └── SKILL.md
│   ├── skill-deck-plan/      # Deck planning
│   │   └── SKILL.md
│   ├── skill-deck-implement/ # Deck building
│   │   └── SKILL.md
│   ├── skill-finance/        # Financial analysis
│   │   └── SKILL.md
│   ├── skill-founder-spreadsheet/ # Cost breakdown spreadsheets
│   │   └── SKILL.md
│   ├── skill-meeting/        # Investor meeting processing
│   │   └── SKILL.md
│   ├── skill-consult/        # Design consultation routing
│   │   └── SKILL.md
│   ├── skill-founder-plan/   # Shared task planning
│   │   └── SKILL.md
│   └── skill-founder-implement/  # Shared task implementation
│       └── SKILL.md
│
├── agents/                    # Agent definitions
│   ├── market-agent.md       # Market sizing research agent
│   ├── analyze-agent.md      # Competitive analysis research agent
│   ├── strategy-agent.md     # GTM strategy research agent
│   ├── legal-council-agent.md    # Contract review research agent
│   ├── project-agent.md      # Project timeline research agent
│   ├── deck-research-agent.md   # Deck content research agent
│   ├── deck-planner-agent.md    # Deck planning agent
│   ├── deck-builder-agent.md    # Deck building agent
│   ├── finance-agent.md         # Financial analysis agent
│   ├── financial-analysis-agent.md # Financial analysis verification agent
│   ├── founder-spreadsheet-agent.md # Cost breakdown agent
│   ├── legal-analysis-agent.md  # Legal consultation design partner agent
│   ├── meeting-agent.md         # Investor meeting processing agent
│   ├── founder-plan-agent.md    # Shared planning agent
│   └── founder-implement-agent.md # Shared implementation agent
│
└── context/                   # Domain knowledge
    └── project/
        └── founder/
            ├── README.md
            ├── deck/          # Deck-specific context
            ├── domain/        # Business frameworks
            │   ├── business-frameworks.md
            │   ├── strategic-thinking.md
            │   └── legal-frameworks.md
            ├── patterns/      # Analysis patterns
            │   ├── forcing-questions.md
            │   ├── decision-making.md
            │   ├── mode-selection.md
            │   └── contract-review.md
            └── templates/     # Output templates
                ├── market-sizing.md
                ├── competitive-analysis.md
                ├── gtm-strategy.md
                └── contract-analysis.md
```

## Workflow

### Standard Phased Workflow (All Commands)

All commands follow the same lifecycle:

```
/{command} "description"
    |
    v
[1] Ask forcing questions, create task with forcing_data
    |  Status: [NOT STARTED]
    v
/research {N}
    |
    v
[2] Domain-specific research agent gathers data
    |  Status: [RESEARCHED]
    v
/plan {N}
    |
    v
[3] Shared planner creates implementation plan
    |  Status: [PLANNED]
    v
/implement {N}
    |
    v
[4] Shared implementer generates final artifact
    |  Status: [COMPLETED]
    v
Report in strategy/{type}-{slug}.md
Summary in specs/{NNN}_{SLUG}/summaries/
```

### Per-Type Research Agents

| Command | Research Agent | Specialization |
|---------|---------------|----------------|
| /market | market-agent | SEC EDGAR, TAM/SAM/SOM, bottom-up sizing |
| /analyze | analyze-agent | Firecrawl, competitor websites, positioning |
| /strategy | strategy-agent | Channel analysis, positioning, GTM |
| /legal | legal-council-agent | Contract review, risk assessment, escalation |
| /project | project-agent | WBS, PERT estimation, resource allocation |
| /deck | deck-research-agent | Material synthesis, slide mapping |
| /finance | finance-agent | Financial verification, runway analysis |
| /sheet | spreadsheet-agent | Cost breakdown, budget generation |
| /consult | legal-analysis-agent | Collaborative design consultation (--legal) |

### Legacy Workflow (--quick)

```
/{command} --quick [args]
    |
    v
skill-{type} -> {type}-agent
    |
    v
founder/{report-type}-{datetime}.md
```

## Key Patterns

### Forcing Questions

Every command uses forcing questions to extract specific, evidence-based information. Questions are asked one at a time, and vague answers are pushed back on.

**Anti-patterns detected and rejected**:
- "Everyone needs this" -> Push for specific customer
- "Many businesses" -> Push for named companies
- "The market is huge" -> Push for specific numbers with sources

### Mode-Based Operation

Each command offers 3-4 operational modes that give users explicit scope control. Mode selection happens early and affects all subsequent analysis.

### Completeness Principle

"When AI reduces marginal cost of completeness to near-zero, optimize for full implementation rather than shortcuts."

All commands evaluate multiple scenarios, not just the optimistic one.

### Decision Frameworks

- **Two-way doors**: Reversible decisions - move fast, 70% information
- **One-way doors**: Irreversible decisions - be rigorous, 90% information
- **Inversion**: Also ask "What makes us fail?"
- **Focus as subtraction**: Explicitly document what NOT to do

## Output Artifacts

### Task Mode

| Command | Report | Tracking |
|---------|--------|----------|
| /market | `strategy/market-sizing-{slug}.md` | `specs/{NNN}_{SLUG}/` |
| /analyze | `strategy/competitive-analysis-{slug}.md` | `specs/{NNN}_{SLUG}/` |
| /strategy | `strategy/gtm-strategy-{slug}.md` | `specs/{NNN}_{SLUG}/` |
| /legal | `strategy/contract-analysis-{slug}.md` | `specs/{NNN}_{SLUG}/` |
| /project | `strategy/timelines/{slug}.typ` | `specs/{NNN}_{SLUG}/` |

### Legacy Mode (--quick)

| Command | Artifact |
|---------|----------|
| /market --quick | `founder/market-sizing-{datetime}.md` |
| /analyze --quick | `founder/competitive-analysis-{datetime}.md` |
| /strategy --quick | `founder/gtm-strategy-{datetime}.md` |
| /legal --quick | `founder/contract-analysis-{datetime}.md` |
| /project --quick | `founder/project-timeline-{datetime}.typ` |

## References

- [gstack (Garry Tan)](https://github.com/garrytan/gstack) - Source of office hours and CEO review patterns
- [YC Library](https://www.ycombinator.com/library) - Startup principles
- [Business Model Canvas](https://www.strategyzer.com/canvas/business-model-canvas) - Framework reference
