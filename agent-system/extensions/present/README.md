# Present Extension

Research presentation support for Claude Code. Provides grant writing, budget planning, timeline management, funding analysis, and academic talk generation.

## Overview

The present extension provides research presentation capabilities through five commands that follow the standard research -> plan -> implement dispatch cycle:

| Feature | Command | Purpose |
|---------|---------|---------|
| Grant Writing | `/grant` | Structured proposal development with funder research |
| Budget Planning | `/budget` | Grant budget spreadsheet generation (XLSX) with Excel formulas |
| Timeline Management | `/timeline` | Research project timeline planning with WBS/PERT/Gantt |
| Funding Analysis | `/funds` | Research funding landscape and portfolio analysis |
| Academic Talks | `/slides` | Slidev-based research presentation generation |

## Installation

This extension is automatically available when loaded via the extension picker. Loading `present` also auto-loads its `slidev` dependency for animation patterns and CSS style presets.

## Architecture

```
present/
├── manifest.json              # Extension configuration
├── EXTENSION.md               # CLAUDE.md merge content
├── index-entries.json         # Context discovery entries
├── settings-fragment.json     # Scoped MCP permission grants (merged into .claude/settings.local.json)
├── README.md                  # This file
│
├── commands/                  # Slash commands
│   ├── grant.md              # /grant command
│   ├── budget.md             # /budget command
│   ├── timeline.md           # /timeline command
│   ├── funds.md              # /funds command
│   └── slides.md             # /slides command
│
├── skills/                    # Skill wrappers
│   ├── skill-grant/          # Grant research and drafting
│   │   └── SKILL.md
│   ├── skill-budget/         # Budget spreadsheet generation
│   │   └── SKILL.md
│   ├── skill-timeline/       # Timeline planning
│   │   └── SKILL.md
│   ├── skill-funds/          # Funding analysis
│   │   └── SKILL.md
│   ├── skill-slides/         # Talk material synthesis and assembly
│   │   └── SKILL.md
│   ├── skill-slide-planning/ # Slide plan with design questions
│   │   └── SKILL.md
│   └── skill-slide-critic/   # Interactive slide critique
│       └── SKILL.md
│
├── agents/                    # Agent definitions
│   ├── grant-agent.md        # Grant proposal research agent
│   ├── budget-agent.md       # Budget spreadsheet agent
│   ├── timeline-agent.md     # Timeline planning agent
│   ├── funds-agent.md        # Funding analysis agent
│   ├── slides-research-agent.md  # Talk material synthesis agent
│   ├── pptx-assembly-agent.md    # PowerPoint assembly agent
│   ├── slidev-assembly-agent.md  # Slidev assembly agent
│   ├── slide-planner-agent.md    # Slide planning agent
│   └── slide-critic-agent.md     # Slide critique agent
│
└── context/                   # Domain knowledge
    └── project/
        └── present/
            ├── domain/        # Grant writing, funding concepts
            ├── patterns/      # Proposal and slide patterns
            └── talk/          # Talk library
                ├── patterns/      # Slide structures per mode
                ├── content-templates/ # Slidev markdown templates
                ├── components/    # Vue components (FigurePanel, etc.)
                └── themes/        # Academic-clean, clinical-teal
```

## Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-grant | grant-agent | opus | Grant proposal research and drafting |
| skill-budget | budget-agent | opus | Grant budget spreadsheet generation (XLSX) |
| skill-timeline | timeline-agent | opus | Research project timeline planning |
| skill-funds | funds-agent | opus | Research funding landscape analysis |
| skill-slides | slides-research-agent | opus | Research talk material synthesis |
| skill-slides | pptx-assembly-agent | opus | PowerPoint presentation assembly |
| skill-slides | slidev-assembly-agent | opus | Slidev presentation assembly |
| skill-slide-planning | slide-planner-agent | opus | Slide plan with design questions |
| skill-slide-critic | slide-critic-agent | opus | Interactive slide critique with rubric evaluation |

## Language Routing

| Task Type | Research Skill | Implementation Skill | Tools |
|-----------|----------------|---------------------|-------|
| `present:grant` | `skill-grant` | `skill-grant` | WebSearch, WebFetch, Read, Write, Edit |
| `present:budget` | `skill-budget` | `skill-budget` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `present:timeline` | `skill-timeline` | `skill-timeline` | WebSearch, WebFetch, Read, Write, Edit |
| `present:funds` | `skill-funds` | `skill-funds` | WebSearch, WebFetch, Read, Write, Edit, Bash |
| `present:slides` | `skill-slides` | `skill-slides` | WebSearch, WebFetch, Read, Write, Edit |

## Talk Modes

| Mode | Duration | Slides | Use Case |
|------|----------|--------|----------|
| CONFERENCE | 15-20 min | 12-18 | Conference platform presentations |
| SEMINAR | 45-60 min | 30-45 | Departmental seminars, job talks |
| DEFENSE | 30-60 min | 25-40 | Grant defense, thesis defense |
| POSTER | N/A | 1 | Poster session presentations |
| JOURNAL_CLUB | 15-30 min | 10-15 | Paper review for journal club |

## Commands

### /grant - Grant Writing

Structured proposal development for research funding.

```bash
/grant "Research NIH R01 funding for AI safety project"
/grant 500 --draft "Focus on methodology"
/grant 500 --budget "Include travel for 3 conferences"
/grant --revise 500 "Update based on reviewer feedback"
```

### /budget - Budget Planning

Grant budget spreadsheet generation with native Excel formulas.

```bash
/budget "NIH R01 5-year budget with 3 PIs and equipment"
/budget 501                    # Resume budget generation
```

Modes: MODULAR, DETAILED, NSF, FOUNDATION, SBIR.

### /timeline - Timeline Management

Research project timeline planning with WBS, PERT scheduling, and regulatory milestones.

```bash
/timeline "5-year R01 timeline with 3 specific aims"
/timeline 502                  # Resume timeline planning
```

### /funds - Funding Analysis

Research funding landscape analysis with four analysis modes.

```bash
/funds "Analyze NIH funding landscape for computational biology"
/funds 503                     # Resume funding analysis
```

Modes: LANDSCAPE, PORTFOLIO, JUSTIFY, GAP.

### /slides - Academic Talks

Slidev-based research presentation generation from source materials.

```bash
/slides "Conference talk on machine learning for drug discovery"
/slides 504                      # Resume talk generation
/slides /path/to/paper.pdf       # Use file as primary source
/slides N --critic [path|prompt] # Critique slides with interactive feedback
```

Modes: CONFERENCE, SEMINAR, DEFENSE, POSTER, JOURNAL_CLUB.

**Note**: This command was previously named `/talk`. For PPTX slide file conversion (not research talk creation), use `/convert --format=beamer` in the `filetypes` extension.

## Workflow

All commands follow the standard phased workflow:

```
/{command} "description"
    |
    v
[1] Ask forcing questions, create task
    |  Status: [NOT STARTED]
    v
/orchestrate {N} --research
    |
    v
[2] Domain-specific research agent gathers data
    |  Status: [RESEARCHED]
    v
/orchestrate {N} --plan
    |
    v
[3] Planner creates implementation plan
    |  Status: [PLANNED]
    v
/orchestrate {N} --implement
    |
    v
[4] Domain agent generates final artifact
    |  Status: [COMPLETED]
```

## Output Artifacts

| Command | Artifact | Format |
|---------|----------|--------|
| `/grant` | Grant narrative sections | Markdown/Typst |
| `/budget` | Budget spreadsheet | XLSX with Excel formulas |
| `/timeline` | Project timeline | Typst with Gantt charts |
| `/funds` | Funding analysis report | Markdown |
| `/slides` | Research presentation | Slidev markdown |

## Dependencies

- **slidev** ([../slidev/README.md](../slidev/README.md)) - Shared animation patterns and CSS style presets used by `/slides`

## References

- [EXTENSION.md](EXTENSION.md) - Full extension documentation with skill-agent mappings
- [context/project/present/domain/](context/project/present/domain/) - Domain knowledge files
- [context/project/present/patterns/](context/project/present/patterns/) - Pattern and template files
- [context/project/present/talk/](context/project/present/talk/) - Talk library (patterns, templates, components, themes)
