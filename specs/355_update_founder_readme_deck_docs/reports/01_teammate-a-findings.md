# Teammate A Findings: Documentation Audit for Task 355

**Focus**: Primary Documentation Audit - Current state of README files and founder extension structure

---

## Key Findings

1. **deck/README.md is completely empty** - 0 bytes, not even a stub. This is the most critical gap.
2. **context/project/founder/README.md is significantly outdated** - It documents an earlier version of the extension that was missing major features added in v3.0.
3. **The founder extension is large and complex** - 8 commands, 12 skills, 12 agents, and a rich deck library sub-system that is entirely undocumented at the README level.
4. **The deck sub-domain is the most complex undocumented area** - It has its own 6-category content library (themes, patterns, animations, styles, components, contents) with 40+ indexed entries.
5. **Format conventions exist** - The nvim extension README provides a clear pattern to follow; the documentation policy is available at `.claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md`.

---

## Current State of README.md

**File**: `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/README.md`

**Lines**: 86

**Status**: Exists but significantly outdated and incomplete.

### What it currently covers:
- Overview paragraph mentioning YC office hours and gstack inspiration
- Directory structure (incomplete - missing many files added in v3.0)
- Key Concepts: Forcing Questions, Decision Frameworks, Operational Modes
- Related Commands table (only 4 of 8 commands listed: /market, /analyze, /strategy, /sheet)
- Usage example showing @-reference loading pattern
- References section

### What it is missing:
- No mention of `/deck`, `/legal`, `/project`, `/finance` commands
- Directory structure does not show the `deck/` subdirectory at all
- No mention of the deck sub-domain content library
- Missing domain files: `financial-analysis.md`, `legal-frameworks.md`, `timeline-frameworks.md`, `workflow-reference.md`, `migration-guide.md`
- Missing pattern files: `contract-review.md`, `legal-planning.md`, `pitch-deck-structure.md`, `slidev-deck-template.md`, `yc-compliance-checklist.md`, `project-planning.md`, `financial-forcing-questions.md`, `cost-forcing-questions.md`
- Missing template files: `financial-analysis.md` and 7 Typst templates not listed
- No navigation link to `deck/README.md`
- No mention of `index-entries.json` context discovery
- The workflow reference table for Related Commands is stale (only 4 of 8 commands)

---

## Current State of deck/README.md

**File**: `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/deck/README.md`

**Lines**: 0 (file is completely empty - 0 bytes)

**Status**: Placeholder file that was never populated.

### What it needs to cover (based on directory analysis):
The `deck/` directory contains 6 categories of content with 40+ entries:
- **themes/**: 5 themes (dark-blue, minimal-light, premium-dark, growth-green, professional-blue)
- **patterns/**: 5 deck structural patterns (yc-10-slide, lightning-5-slide, product-demo, investor-update, partnership-proposal)
- **animations/**: 6 animation patterns (fade-in, slide-in-below, metric-cascade, rough-marks, staggered-list, scale-in-pop)
- **styles/**: 9 CSS style presets (4 color schemes, 3 typography, 2 textures)
- **components/**: 4 Vue components (MetricCard, TeamMember, TimelineItem, ComparisonCol)
- **contents/**: 22 slide content templates across 10 slide types (cover, problem, solution, traction, market, team, ask, business-model, why-us-now, closing, appendix)
- **index.json**: Library sub-index with all 40+ entries categorized

---

## Extension Structure Analysis

The founder extension (v3.0) is a comprehensive business analysis toolkit:

### Commands (8 total)
| Command | Purpose | Deck-specific? |
|---------|---------|----------------|
| `/market` | TAM/SAM/SOM market sizing | No |
| `/analyze` | Competitive landscape analysis | No |
| `/strategy` | Go-to-market strategy | No |
| `/legal` | Contract review and legal counsel | No |
| `/project` | Project timeline management | No |
| `/deck` | Pitch deck creation | YES |
| `/finance` | Financial analysis | No |
| `/sheet` | Cost breakdown spreadsheets | No |

### Skills (12 total)
- `skill-market`, `skill-analyze`, `skill-strategy`, `skill-legal`, `skill-project`, `skill-spreadsheet`, `skill-finance` - One per domain command
- `skill-deck-research` - Deck-specific: material synthesis → research report
- `skill-deck-plan` - Deck-specific: interactive library selection (pattern, theme, content, ordering)
- `skill-deck-implement` - Deck-specific: generates final Slidev deck
- `skill-founder-plan` - Shared planning for non-deck founder tasks
- `skill-founder-implement` - Shared implementation for non-deck founder tasks

### Agents (12 total)
- Domain agents: market-agent, analyze-agent, strategy-agent, legal-council-agent, project-agent, spreadsheet-agent, finance-agent
- Deck agents: deck-research-agent, deck-planner-agent, deck-builder-agent
- Shared: founder-plan-agent, founder-implement-agent

### Routing Logic
All 8 commands route through the standard `/research -> /plan -> /implement` lifecycle.

**Non-deck tasks**: Use shared `skill-founder-plan` / `skill-founder-implement` for plan and implement phases, domain-specific skill for research.

**Deck tasks** (`task_type: deck`): Have dedicated 3-skill pipeline:
- Research: `skill-deck-research` → `deck-research-agent` (synthesizes source materials, maps to 10-slide structure)
- Plan: `skill-deck-plan` → `deck-planner-agent` (interactive: picks pattern/theme/content/ordering via AskUserQuestion)
- Implement: `skill-deck-implement` → `deck-builder-agent` (assembles Slidev deck from library content)

### Context Discovery (index-entries.json)
- 31 entries mapped to agents, languages, task_types, and commands
- Deck-specific entries: `pitch-deck-structure.md`, `slidev-deck-template.md`, `yc-compliance-checklist.md`, `deck/index.json`
- All deck entries load for agents: `deck-research-agent`, `deck-planner-agent`, `deck-builder-agent`

### MCP Tool Integration
- **SEC EDGAR**: Used by market-agent for public company financials (no key required)
- **Firecrawl**: Used by analyze-agent for web scraping (free tier, API key needed)

### Library Architecture (deck sub-domain)
The deck system uses a **seed + runtime copy** architecture:
- Seed (read-only): `.claude/extensions/founder/context/project/founder/deck/`
- Runtime copy (mutable): `.context/deck/` - copied on first use, agents write back new content

### Output Artifacts
- Non-deck founder tasks: `strategy/{type}-{slug}.md` (markdown) or `.typ` (Typst PDF)
- Deck tasks: `strategy/{slug}-deck/` directory containing:
  - `slides.md` - Slidev presentation source
  - `styles/index.css` - Composed CSS
  - `components/` - Vue components
  - `package.json` - npm config for `@slidev/cli`
  - `{slug}-deck.pdf` - Exported PDF (if slidev installed)

---

## Documentation Gaps Identified

### README.md Gaps (Priority: High)
1. **Commands table incomplete** - Missing `/deck`, `/legal`, `/project`, `/finance`
2. **Directory structure wrong** - Does not show `deck/`, missing many domain/pattern/template files
3. **No deck sub-domain section** - The entire deck workflow is absent
4. **Deck/ subdirectory not linked** - No navigation link to `deck/README.md`
5. **Domain section missing files** - `financial-analysis.md`, `legal-frameworks.md`, `timeline-frameworks.md`, `workflow-reference.md`
6. **Patterns section missing files** - 8+ pattern files not listed
7. **Templates section missing** - Multiple Typst templates, financial-analysis, market-sizing not documented
8. **No mention of context discovery** - `index-entries.json` and how agents load context not explained
9. **No mention of MCP tools** - SEC EDGAR and Firecrawl integration not documented here
10. **Operational modes incomplete** - Only mentions generic modes, should list per-command modes

### deck/README.md Gaps (Priority: Critical)
The file is entirely empty. All content is missing:
1. **Purpose and overview** - What is the deck library, why it exists
2. **Seed vs runtime copy pattern** - `.claude/extensions/founder/.../deck/` vs `.context/deck/`
3. **Library categories** - All 6 categories explained
4. **Themes** - 5 themes with color schema and use-case guidance
5. **Patterns** - 5 deck structural patterns with slide counts
6. **Animations** - 6 animation patterns with complexity ratings
7. **Styles** - Color, typography, texture CSS presets
8. **Components** - 4 Vue components with props documentation
9. **Contents** - 22 content templates with slot documentation
10. **index.json structure** - How agents query the library
11. **How to extend the library** - Library write-back mechanism
12. **Integration with agent workflow** - How deck-builder-agent uses the library

---

## Recommended Content Outline

### README.md (Updated)

```
# Founder Context

Brief description (updated to mention 8 commands, v3.0).

## Overview

## Directory Structure

founder/
├── README.md
├── deck/                   # Deck library sub-domain
├── domain/                 # Business frameworks (all 7 files)
├── patterns/               # Analysis patterns (all 11 files)
├── templates/              # Output templates (md + typst/)
└── [index-entries.json via extension]

## Commands

Full table of all 8 commands with context used.

## Key Concepts

### Forcing Questions (keep existing content)
### Decision Frameworks (keep existing content)
### Operational Modes (keep existing content)
### Deck Sub-Domain
Brief introduction pointing to deck/README.md.

## Context Discovery

Explain index-entries.json and load_when mechanism.

## Usage

(keep existing @-reference example, update paths)

## Subdirectories

- [deck/](deck/README.md) - Slidev pitch deck content library

## References
```

### deck/README.md (New)

```
# Deck Library

Purpose: Reusable Slidev presentation components for pitch deck generation.

## Overview

The deck library is a modular content system used by the /deck workflow.
Explains seed vs runtime copy architecture.

## Library Structure

deck/
├── index.json         # Sub-index for agent queries
├── themes/            # 5 Slidev theme presets
├── patterns/          # 5 structural deck patterns
├── animations/        # 6 animation pattern definitions
├── styles/            # 9 CSS presets (colors/typography/textures)
├── components/        # 4 Vue components
└── contents/          # 22 slide content templates (10 slide types)

## Categories

### Themes (5)
Table: id, name, color_schema, mood, use case

### Patterns (5)
Table: id, name, slide_count, deck_modes, audience

### Animations (6)
Table: id, name, trigger, complexity

### Styles (9)
Table: id, name, type (colors/typography/texture)

### Components (4)
Table: component, props, usage context

### Contents (22 across 10 slide types)
Table: id, slide_type, deck_modes, content_slots

## Index Structure (index.json)

How to query the library (agent usage pattern).

## Seed vs Runtime Copy

Explains .claude/extensions/.../deck/ vs .context/deck/.

## Library Write-Back

New content created during /implement is saved back to library.

## Integration

How deck-builder-agent uses library (stage references).

## Navigation

[<- Founder Context](../README.md)
```

---

## Confidence Level

**High**

The full extension structure has been read including:
- manifest.json (v3.0 complete)
- All 8 command files
- All relevant skill files (deck-research, deck-plan, deck-implement)
- All 3 deck agents (research, planner, builder)
- deck/index.json (complete library catalog)
- index-entries.json (complete context discovery)
- Current state of both README files
- Extension README.md (for format reference)
- Documentation policy (for style guidelines)

The gaps are definitively identified. There are no ambiguities about what content is missing.
