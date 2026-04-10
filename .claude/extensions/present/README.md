# Present Extension

Research presentation support for Claude Code. Provides grant writing, budget planning, timeline management, funding analysis, and academic talk generation.

## Table of Contents

- [Overview](#overview)
- [Commands](#commands)
- [Related Files](#related-files)

## Overview

The present extension provides research presentation capabilities:

| Feature | Command | Purpose |
|---------|---------|---------|
| Grant Writing | `/grant` | Structured proposal development with funder research |
| Budget Planning | `/budget` | Grant budget spreadsheet generation (XLSX) with Excel formulas |
| Timeline Management | `/timeline` | Research project timeline planning with WBS/PERT/Gantt |
| Funding Analysis | `/funds` | Research funding landscape and portfolio analysis |
| Academic Talks | `/slides` | Slidev-based research presentation generation |

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

Supports modes: MODULAR, DETAILED, NSF, FOUNDATION, SBIR.

### /timeline - Timeline Management

Research project timeline planning with WBS, PERT scheduling, and regulatory milestones.

```bash
/timeline "5-year R01 timeline with 3 specific aims"
/timeline 502                  # Resume timeline planning
```

Includes regulatory milestone tracking (IRB, IACUC, DSMB), reporting periods, and effort allocation.

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
```

Modes: CONFERENCE, SEMINAR, DEFENSE, POSTER, JOURNAL_CLUB.

**Note**: This command was previously named `/talk`. For PPTX slide file conversion (not research talk creation), use `/convert --format=beamer` in the `filetypes` extension.

## Related Files

- [EXTENSION.md](EXTENSION.md) - Full extension documentation with skill-agent mappings
- [context/project/present/domain/](context/project/present/domain/) - Domain knowledge files
- [context/project/present/patterns/](context/project/present/patterns/) - Pattern and template files
- [context/project/present/talk/](context/project/present/talk/) - Talk library (patterns, templates, components, themes)
