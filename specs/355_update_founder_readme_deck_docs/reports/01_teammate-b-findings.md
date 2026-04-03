# Teammate B Findings: Cross-Reference and Documentation Patterns

Task: 355 - Update founder extension README and deck documentation
Focus: Cross-reference analysis and documentation patterns

---

## Key Findings

1. **The deck sub-domain README is completely empty** (0 bytes). The `deck/README.md` file exists but contains no content. This is the primary documentation gap to fix.

2. **The top-level founder README is comprehensive** (v3.0, 390 lines) but has an **outdated Architecture section** - the directory tree omits several files that exist in `context/project/founder/`:
   - Omits `deck/` subdirectory entirely in the tree
   - Omits `domain/migration-guide.md`, `domain/workflow-reference.md`, `domain/spreadsheet-frameworks.md`, `domain/financial-analysis.md`, `domain/timeline-frameworks.md`
   - Omits `patterns/legal-planning.md`, `patterns/project-planning.md`, `patterns/financial-forcing-questions.md`, `patterns/cost-forcing-questions.md`, `patterns/pitch-deck-structure.md`, `patterns/slidev-deck-template.md`, `patterns/yc-compliance-checklist.md`
   - Omits `templates/financial-analysis.md` and all `templates/typst/` files
   - Omits `context/project/founder/README.md` reference

3. **The context/project/founder/README.md is outdated** - its directory tree shows only 3 domain files and omits the actual 7 that exist. It also does not mention the `deck/` subdirectory or new commands (`/deck`, `/finance`, `/sheet`).

4. **The deck library is a rich, well-structured sub-domain** with its own `index.json` (477 lines), 5+ themes, 5+ patterns, 6+ animation types, 4 Vue components, 11 slide content topic directories, 4 style categories (colors, typography, textures). This warrants thorough README documentation.

5. **No other extension has a README at the context sub-domain level** - the `deck/` subdirectory is unique in having both an `index.json` and a dedicated `README.md` slot (currently empty), making this a novel documentation scope.

---

## Cross-Reference Analysis

### How founder is referenced in core command routing

The founder extension integrates with core `/research`, `/plan`, `/implement`, and `/task` commands via language-based routing.

**In `/research`** (`/home/benjamin/.config/nvim/.claude/commands/research.md`):
- `founder` → `skill-market`
- `founder:deck` → `skill-deck-research`
- `founder:analyze` → `skill-analyze`
- `founder:strategy` → `skill-strategy`
- `founder:{sub-type}` → compound key lookup, falls back to `skill-market`

**In `/plan`** (`/home/benjamin/.config/nvim/.claude/commands/plan.md`):
- `founder` → `skill-founder-plan`
- `founder:deck` → `skill-deck-plan`
- `founder:{sub-type}` → falls back to `skill-founder-plan`

**In `/implement`** (`/home/benjamin/.config/nvim/.claude/commands/implement.md`):
- `founder` → `skill-founder-implement`
- `founder:deck` → `skill-deck-implement`
- `founder:{sub-type}` → falls back to `skill-founder-implement`

**In `/task`** (`/home/benjamin/.config/nvim/.claude/commands/task.md`), keyword routing assigns `founder:{task_type}` based on description:
- "deck", "slide", "presentation", "pitch deck" → `founder:deck`
- "spreadsheet", "sheet", "excel" → `founder:sheet`
- "finance", "financial", "revenue", "burn rate" → `founder:finance`
- "market size", "tam", "sam", "som" → `founder:market`
- "competitive", "competitor" → `founder:analyze`
- "strategy", "strategic", "roadmap" → `founder:strategy`
- "legal", "contract", "agreement" → `founder:legal`
- "project plan", "timeline", "milestone" → `founder:project`
- "founder", "go-to-market", "gtm" → `founder`

**In CLAUDE.md**: founder is listed as an "Extension Language" with note that routing entries merge from `manifest.json` when loaded.

### Skill-to-Agent mapping (from manifest.json and EXTENSION.md)

| Skill | Agent | Phase |
|-------|-------|-------|
| skill-market | market-agent | research |
| skill-analyze | analyze-agent | research |
| skill-strategy | strategy-agent | research |
| skill-legal | legal-council-agent | research |
| skill-project | project-agent | research |
| skill-spreadsheet | spreadsheet-agent | research |
| skill-finance | finance-agent | research |
| skill-deck-research | deck-research-agent | research |
| skill-founder-plan | founder-plan-agent | plan |
| skill-deck-plan | deck-planner-agent | plan |
| skill-founder-implement | founder-implement-agent | implement |
| skill-deck-implement | deck-builder-agent | implement |

### Context index entries (from index-entries.json)

The `index-entries.json` has 31 entries. Deck-specific entries:
- `project/founder/patterns/pitch-deck-structure.md` (150 lines) - loaded for deck-research-agent, deck-planner-agent, deck-builder-agent
- `project/founder/patterns/slidev-deck-template.md` (260 lines) - loaded for all 3 deck agents
- `project/founder/patterns/yc-compliance-checklist.md` (100 lines) - loaded for all 3 deck agents
- `project/founder/deck/index.json` (477 lines) - loaded for deck-planner-agent, deck-builder-agent, deck-research-agent

**Notably absent from index-entries.json**: No entries for the deck library's content files, themes, animations, styles, components, or patterns (inside `deck/`). Those are discovered via `deck/index.json` which is itself indexed.

---

## Documentation Patterns from Other Extensions

### Observed README structures across extensions

**Rich READMEs (web, nix, neovim)** - best exemplar pattern:
1. H1 title with domain name
2. Short description paragraph
3. `## Directory Structure` - full annotated tree with file descriptions
4. `## Loading Strategy` - task-type-based guidance (e.g., "Load for component work:", "Load for deployment work:")
5. `## Configuration Assumptions` - prerequisites, versions, tooling
6. `## Key Concepts` - 3-5 domain concepts with subsections
7. `## Agent Context Loading` - table mapping task types to required files

**Minimal READMEs (latex, lean, python)** - lighter pattern:
1. H1 title
2. Short description
3. `## Structure` - bulleted list of subdirectories
4. `## Key Files` - list of most important files with purpose
5. `## For Research` / `## For Implementation` - brief loading guidance

**Single-concept READMEs (epidemiology)** - flat pattern:
1. H1 title + description
2. `## Core Concepts` - bulleted list
3. Domain-specific sections (Modeling Approaches, Tooling, Workflow)
4. No loading strategy section

**Extension-level READMEs (founder, present)**:
- `founder/README.md`: Very comprehensive. Has Overview table, Installation, MCP Tool Setup, per-command documentation, Architecture tree, Workflow diagrams, Key Patterns, Output Artifacts, References
- `present/README.md`: Simpler - Table of Contents, Overview, Commands, Related Files

### Section naming conventions

Consistent across rich READMEs:
- `## Directory Structure` with code block tree
- `## Loading Strategy` with bolded task-type headers
- `## Agent Context Loading` with Markdown table
- `## Key Concepts` with `###` subsections

### Metadata/frontmatter

Context README files do NOT use YAML frontmatter. Only skill SKILL.md files use YAML frontmatter (`name:`, `description:`, `allowed-tools:`). README files are plain Markdown with H1 title.

### Relationship to manifest.json

READMEs do not replicate manifest.json content verbatim. The manifest provides machine-readable routing; READMEs provide human-readable guidance. Cross-references to commands use inline code (e.g., `` `/deck` ``).

---

## Deck Sub-Domain Analysis

### Current state: deck/README.md is empty

The file `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/deck/README.md` exists but is 0 bytes.

### Deck library structure (from directory listing)

```
deck/
├── README.md              (EMPTY - needs documentation)
├── index.json             (477 lines - library sub-index for agents)
├── animations/            (6 files: fade-in, metric-cascade, rough-marks, scale-in-pop, slide-in-below, staggered-list)
├── components/            (4 Vue files: ComparisonCol, MetricCard, TeamMember, TimelineItem)
├── contents/              (11 topic directories, 2 variants each = 22+ slide markdown files)
│   ├── appendix/          (appendix-competition, appendix-financials, appendix-roadmap)
│   ├── ask/               (ask-centered, ask-milestone)
│   ├── business-model/    (biz-model-pricing, biz-model-saas)
│   ├── closing/           (closing-cta, closing-standard)
│   ├── cover/             (cover-hero, cover-standard)
│   ├── market/            (market-narrative, market-tam-sam-som)
│   ├── problem/           (problem-statement, problem-story)
│   ├── solution/          (solution-demo, solution-two-col)
│   ├── team/              (team-grid, team-two-col)
│   ├── traction/          (traction-chart, traction-metrics)
│   └── why-us-now/        (why-us-moat, why-us-now-split)
├── patterns/              (5 JSON files: investor-update, lightning-5-slide, partnership-proposal, product-demo, yc-10-slide)
├── styles/
│   ├── colors/            (4 CSS: dark-blue-navy, dark-gold-premium, light-blue-corp, light-green-growth)
│   ├── textures/          (2 CSS: grid-overlay, noise-grain)
│   └── typography/        (3 CSS: inter-only, montserrat-inter, playfair-inter)
└── themes/                (5 JSON: dark-blue, growth-green, minimal-light, premium-dark, professional-blue)
```

### How the deck library is used

From `slidev-deck-template.md` (the key reference pattern file):
- Agents read theme JSONs for Slidev headmatter configuration
- Agents copy content files from `contents/{slide_type}/{variant}.md` and fill `[SLOT: ...]` markers
- Vue components from `components/` are copied to the deck's `components/` directory
- CSS files from `styles/` provide composable design tokens
- `patterns/` JSONs define slide sequences for different deck types

Content files use a consistent comment metadata header:
```
<!-- CONTENT: {id}
     SLIDE_TYPE: {type}
     LAYOUT: {slidev_layout}
     COMPATIBLE_MODES: {modes}
     CONTENT_SLOTS: {slots}
     ANIMATIONS: {animation_type}
     IMPORT: Use src frontmatter or copy directly
     LAST_UPDATED: {date}
-->
```

### How agents navigate the deck library

Agents load `deck/index.json` (indexed in `index-entries.json` as required for deck agents). The index provides:
- Category metadata (6 categories: theme, pattern, animation, style, content, component)
- Entry-level descriptions with tags and preview data
- File paths relative to the `deck/` directory

This means the `deck/README.md` serves as a **human-readable companion to `deck/index.json`** - the README should explain the library structure, usage patterns, and how an agent navigates it, while `index.json` provides the machine-readable catalog.

---

## Other Founder Sub-Domains

The founder context directory at `context/project/founder/` has these subdirectories:

1. **`deck/`** - Only subdomain with both `index.json` AND a (currently empty) `README.md`. Unique status.
2. **`domain/`** - 7 `.md` files (business-frameworks, financial-analysis, legal-frameworks, migration-guide, spreadsheet-frameworks, strategic-thinking, timeline-frameworks, workflow-reference). No README.
3. **`patterns/`** - 10+ `.md` files (forcing-questions, decision-making, mode-selection, contract-review, legal-planning, project-planning, financial-forcing-questions, cost-forcing-questions, pitch-deck-structure, slidev-deck-template, yc-compliance-checklist). No README.
4. **`templates/`** - 4 `.md` files + `typst/` subdirectory with 7 `.typ` files. No README.

**Pattern**: Only `deck/` has a dedicated README slot. Other subdirectories (`domain/`, `patterns/`, `templates/`) do not have READMEs. The top-level `context/project/founder/README.md` serves as the entry-point overview for all subdirectories.

---

## Recommended Documentation Style

Based on the analysis of all extension READMEs and the specific needs of the founder extension, here are style recommendations:

### For `context/project/founder/deck/README.md` (primary gap)

Follow the **rich README pattern** (web, nix, neovim style) because:
- The deck library is complex with 6 categories and 40+ files
- Agents need loading guidance to navigate efficiently
- The deck sub-domain has dedicated agents (3) and skills (3)

Recommended sections:
1. `# Deck Library` - title + 2-sentence purpose description
2. `## Overview` - what the library enables, relationship to `index.json`
3. `## Directory Structure` - annotated tree of all subdirectories
4. `## Library Categories` - table with category name, description, file count, usage
5. `## Agent Usage Patterns` - how agents navigate: load index.json first, query categories, select entries
6. `## Content Slot System` - how `[SLOT: ...]` markers work, filling pattern
7. `## Import Methods` - `src` frontmatter vs. direct copy patterns
8. `## Design Constraints` - key rules (max 12 slides, CSS variables, no nested lists)
9. `## Related Context` - links to pitch-deck-structure.md, slidev-deck-template.md, yc-compliance-checklist.md

### For `context/project/founder/README.md` (update needed)

Update the directory tree to reflect actual file structure. Add `deck/` subdirectory entry. Add missing domain/patterns/templates files.

### For top-level `founder/README.md` (update needed)

Update the Architecture section directory tree to include:
- `deck/` subdirectory with brief annotation
- Missing context files in the domain/, patterns/, templates/ sections
- `/finance` and `/sheet` commands with their agents in the Per-Type Research Agents table

### Formatting conventions to follow
- No YAML frontmatter in README files
- H1 for title, H2 for major sections, H3 for subsections
- Tables for command/skill/agent mappings
- Code blocks with `bash` or `markdown` language hints
- Backtick inline code for file paths, commands, and skill names
- Bold for section headers within loading strategy

---

## Confidence Level

**High** for:
- Current state of deck/README.md (confirmed empty, 0 bytes)
- Cross-reference analysis (directly read command files)
- Documentation patterns (read 8+ extension READMEs)
- Deck library structure (direct directory listing + file reads)
- Index-entries.json analysis (read complete file)

**Medium** for:
- What specific content the deck/README.md should prioritize (depends on Teammate A's findings about what agents actually need)
- Whether the founder/README.md and context/project/founder/README.md updates are in scope for this task or just the deck README
