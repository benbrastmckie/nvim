# Founder Extension (v2.0)

Strategic business analysis tools for founders and entrepreneurs. Integrates forcing question patterns and decision frameworks inspired by Y Combinator office hours methodology and gstack.

## What's New in v2.0

- **Task Integration**: Commands now create tasks and use `/plan` + `/implement` workflow
- **Three-Phase Workflow**: Context gathering, forcing questions, synthesis
- **Language-Based Routing**: `/plan` and `/implement` route to founder-specific skills
- **Report Output**: Strategy reports go to `strategy/` directory
- **Legacy Mode**: `--quick` flag preserves standalone behavior

## Overview

This extension provides three commands for strategic business analysis:

| Command | Purpose | Output |
|---------|---------|--------|
| `/market` | TAM/SAM/SOM market sizing | Market sizing report |
| `/analyze` | Competitive landscape analysis | Competitive analysis with positioning map |
| `/strategy` | Go-to-market strategy | GTM strategy with 90-day plan |

## Installation

This extension is automatically available when loaded via `<leader>ac` in Neovim.

## Commands

### /market

Market sizing analysis using TAM/SAM/SOM framework with forcing questions.

**Syntax**:
```bash
# Task workflow (default)
/market "fintech payments app"    # Create task and run workflow
/market 234                       # Operate on existing task
/market /path/to/context.md       # Use file as context

# Legacy standalone mode
/market --quick fintech payments  # No task creation
```

**Modes**:
- `VALIDATE`: Test assumptions with evidence gathering
- `SIZE`: Comprehensive TAM/SAM/SOM analysis
- `SEGMENT`: Deep dive into specific segments
- `DEFEND`: Investor-ready with conservative estimates

**Output**:
- Task mode: `strategy/market-sizing-{slug}.md`
- Legacy mode: `founder/market-sizing-{datetime}.md`

### /analyze

Competitive landscape analysis with positioning maps and battle cards.

**Syntax**:
```bash
# Task workflow (default)
/analyze "fintech competitors"    # Create task and run workflow
/analyze 234                      # Operate on existing task

# Legacy standalone mode
/analyze --quick stripe,square    # No task creation
```

**Modes**:
- `LANDSCAPE`: Map all competitors (direct, indirect, potential)
- `DEEP`: Detailed analysis of top 3-5 competitors
- `POSITION`: Find white space with 2x2 positioning map
- `BATTLE`: Generate battle cards for sales

**Output**:
- Task mode: `strategy/competitive-analysis-{slug}.md`
- Legacy mode: `founder/competitive-analysis-{datetime}.md`

### /strategy

Go-to-market strategy development with positioning and channel analysis.

**Syntax**:
```bash
# Task workflow (default)
/strategy "B2B SaaS launch"       # Create task and run workflow
/strategy 234                     # Operate on existing task

# Legacy standalone mode
/strategy --quick B2B launch      # No task creation
```

**Modes**:
- `LAUNCH`: Maximize splash for new product
- `SCALE`: Optimize engine for growth
- `PIVOT`: Find new wedge when current approach isn't working
- `EXPAND`: Enter adjacent markets

**Output**:
- Task mode: `strategy/gtm-strategy-{slug}.md`
- Legacy mode: `founder/gtm-strategy-{datetime}.md`

## Architecture

```
founder/
├── manifest.json              # Extension configuration (v2.0)
├── EXTENSION.md               # CLAUDE.md merge content
├── index-entries.json         # Context discovery entries
├── README.md                  # This file
│
├── commands/                  # Slash commands
│   ├── market.md             # /market command (task-integrated)
│   ├── analyze.md            # /analyze command (task-integrated)
│   └── strategy.md           # /strategy command (task-integrated)
│
├── skills/                    # Skill wrappers
│   ├── skill-market/         # Standalone market sizing
│   │   └── SKILL.md
│   ├── skill-analyze/        # Standalone competitive analysis
│   │   └── SKILL.md
│   ├── skill-strategy/       # Standalone GTM strategy
│   │   └── SKILL.md
│   ├── skill-founder-plan/   # Task planning with forcing questions
│   │   └── SKILL.md
│   └── skill-founder-implement/  # Execute plan and generate report
│       └── SKILL.md
│
├── agents/                    # Agent definitions
│   ├── market-agent.md       # Standalone market sizing agent
│   ├── analyze-agent.md      # Standalone competitive analysis agent
│   ├── strategy-agent.md     # Standalone GTM strategy agent
│   ├── founder-plan-agent.md     # Task planning agent
│   └── founder-implement-agent.md # Task implementation agent
│
└── context/                   # Domain knowledge
    └── project/
        └── founder/
            ├── README.md
            ├── domain/        # Business frameworks
            │   ├── business-frameworks.md
            │   └── strategic-thinking.md
            ├── patterns/      # Analysis patterns
            │   ├── forcing-questions.md
            │   ├── decision-making.md
            │   └── mode-selection.md
            └── templates/     # Output templates
                ├── market-sizing.md
                ├── competitive-analysis.md
                └── gtm-strategy.md
```

## Workflow

### Task Workflow (Default)

```
/market "fintech payments"
    |
    v
[1] Create task in state.json/TODO.md
    |
    v
[2] Run /plan (routes to skill-founder-plan)
    ├── Mode selection
    ├── Forcing questions (6-8 questions)
    └── Generate plan with gathered context
    |
    v
[3] Run /implement (routes to skill-founder-implement)
    ├── Load plan with context
    ├── Execute phases (TAM/SAM/SOM/Report)
    └── Generate report artifact
    |
    v
[4] Task completed
    ├── Report: strategy/market-sizing-{slug}.md
    └── Summary: specs/{NNN}_{SLUG}/summaries/
```

### Legacy Workflow (--quick)

```
/market --quick fintech payments
    |
    v
skill-market -> market-agent
    |
    v
founder/market-sizing-{datetime}.md
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

### Three-Phase Workflow (v2.0)

1. **Context Gathering**: Load file, task artifacts, or ask initial question
2. **Interactive Questions**: Forcing questions tailored to gathered context
3. **Synthesis**: Generate report using template

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

### Legacy Mode (--quick)

| Command | Artifact |
|---------|----------|
| /market --quick | `founder/market-sizing-{datetime}.md` |
| /analyze --quick | `founder/competitive-analysis-{datetime}.md` |
| /strategy --quick | `founder/gtm-strategy-{datetime}.md` |

## Migration from v1.0

| v1.0 Command | v2.0 Equivalent |
|--------------|-----------------|
| `/market fintech` | `/market --quick fintech` (standalone) |
| | `/market "fintech analysis"` (task workflow) |
| `/analyze stripe` | `/analyze --quick stripe` (standalone) |
| `/strategy launch` | `/strategy --quick launch` (standalone) |

**Key Changes**:
- Default behavior now creates tasks
- Use `--quick` for v1.0 behavior
- Reports go to `strategy/` (task) or `founder/` (--quick)
- Task tracking with status updates

## References

- [gstack (Garry Tan)](https://github.com/garrytan/gstack) - Source of office hours and CEO review patterns
- [YC Library](https://www.ycombinator.com/library) - Startup principles
- [Business Model Canvas](https://www.strategyzer.com/canvas/business-model-canvas) - Framework reference
