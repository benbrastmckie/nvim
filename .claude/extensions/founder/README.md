# Founder Extension

Strategic business analysis tools for founders and entrepreneurs. Integrates forcing question patterns and decision frameworks inspired by Y Combinator office hours methodology and gstack.

## Overview

This extension provides three commands for strategic business analysis:

| Command | Purpose | Output |
|---------|---------|--------|
| `/market` | TAM/SAM/SOM market sizing | Market sizing artifact |
| `/analyze` | Competitive landscape analysis | Competitive analysis with positioning map |
| `/strategy` | Go-to-market strategy | GTM strategy with 90-day plan |

## Installation

This extension is automatically available when loaded via `<leader>ac` in Neovim.

## Commands

### /market

Market sizing analysis using TAM/SAM/SOM framework with forcing questions.

**Syntax**:
```
/market                          # Interactive mode
/market fintech payments         # With industry/segment hints
/market --mode VALIDATE          # Specific mode
```

**Modes**:
- `VALIDATE`: Test assumptions with evidence gathering
- `SIZE`: Comprehensive TAM/SAM/SOM analysis
- `SEGMENT`: Deep dive into specific segments
- `DEFEND`: Investor-ready with conservative estimates

**Output**: `founder/market-sizing-{datetime}.md`

### /analyze

Competitive landscape analysis with positioning maps and battle cards.

**Syntax**:
```
/analyze                         # Interactive mode
/analyze stripe,square,adyen     # Specific competitors
/analyze --mode BATTLE           # Generate battle cards
```

**Modes**:
- `LANDSCAPE`: Map all competitors (direct, indirect, potential)
- `DEEP`: Detailed analysis of top 3-5 competitors
- `POSITION`: Find white space with 2x2 positioning map
- `BATTLE`: Generate battle cards for sales

**Output**: `founder/competitive-analysis-{datetime}.md`

### /strategy

Go-to-market strategy development with positioning and channel analysis.

**Syntax**:
```
/strategy                        # Interactive mode
/strategy B2B SaaS launch        # With context hints
/strategy --mode LAUNCH          # Specific mode
```

**Modes**:
- `LAUNCH`: Maximize splash for new product
- `SCALE`: Optimize engine for growth
- `PIVOT`: Find new wedge when current approach isn't working
- `EXPAND`: Enter adjacent markets

**Output**: `founder/gtm-strategy-{datetime}.md`

## Architecture

```
founder/
├── manifest.json          # Extension configuration
├── EXTENSION.md           # CLAUDE.md merge content
├── index-entries.json     # Context discovery entries
├── README.md              # This file
│
├── commands/              # Slash commands
│   ├── market.md         # /market command
│   ├── analyze.md        # /analyze command
│   └── strategy.md       # /strategy command
│
├── skills/                # Skill wrappers
│   ├── skill-market/     # Market sizing skill
│   │   └── SKILL.md
│   ├── skill-analyze/    # Competitive analysis skill
│   │   └── SKILL.md
│   └── skill-strategy/   # GTM strategy skill
│       └── SKILL.md
│
├── agents/                # Agent definitions
│   ├── market-agent.md   # Market sizing agent
│   ├── analyze-agent.md  # Competitive analysis agent
│   └── strategy-agent.md # GTM strategy agent
│
└── context/               # Domain knowledge
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

All artifacts are written to the `founder/` directory:

| Command | Artifact | Content |
|---------|----------|---------|
| /market | `market-sizing-{datetime}.md` | TAM/SAM/SOM with concentric circles |
| /analyze | `competitive-analysis-{datetime}.md` | Landscape, profiles, positioning map, battle cards |
| /strategy | `gtm-strategy-{datetime}.md` | Positioning, channels, 90-day plan |

## References

- [gstack (Garry Tan)](https://github.com/garrytan/gstack) - Source of office hours and CEO review patterns
- [YC Library](https://www.ycombinator.com/library) - Startup principles
- [Business Model Canvas](https://www.strategyzer.com/canvas/business-model-canvas) - Framework reference
