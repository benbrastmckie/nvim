# Research Report: Task #355

**Task**: Update founder extension README and deck documentation
**Date**: 2026-04-02
**Mode**: Team Research (2 teammates)

## Summary

The founder extension has two README files requiring documentation work: `context/project/founder/README.md` (exists but outdated, ~86 lines) and `context/project/founder/deck/README.md` (completely empty, 0 bytes). The extension is a comprehensive business analysis toolkit (v3.0) with 8 commands, 12 skills, 12 agents, and a rich deck content library with 40+ files across 6 categories. Both teammates independently confirmed the same gaps with high confidence.

## Key Findings

### 1. deck/README.md is Empty (Critical)

The file at `.claude/extensions/founder/context/project/founder/deck/README.md` is 0 bytes. The deck sub-domain is the most complex part of the founder extension, containing:

- **themes/** (5): dark-blue, growth-green, minimal-light, premium-dark, professional-blue
- **patterns/** (5): yc-10-slide, lightning-5-slide, product-demo, investor-update, partnership-proposal
- **animations/** (6): fade-in, metric-cascade, rough-marks, scale-in-pop, slide-in-below, staggered-list
- **styles/** (9): 4 color schemes, 3 typography presets, 2 textures
- **components/** (4): MetricCard, TeamMember, TimelineItem, ComparisonCol (Vue)
- **contents/** (22+): Slide content templates across 11 topic directories (cover, problem, solution, traction, market, team, ask, business-model, why-us-now, closing, appendix)
- **index.json** (477 lines): Machine-readable library catalog for agent navigation

### 2. context/project/founder/README.md is Outdated (High Priority)

The existing README (~86 lines) was written for an earlier version. Gaps include:

- **Commands table incomplete**: Lists only 4 of 8 commands (missing `/deck`, `/legal`, `/project`, `/finance`)
- **Directory structure wrong**: Does not show `deck/` subdirectory; omits many domain, pattern, and template files added in v3.0
- **Missing domain files**: `financial-analysis.md`, `legal-frameworks.md`, `timeline-frameworks.md`, `workflow-reference.md`, `migration-guide.md`, `spreadsheet-frameworks.md`
- **Missing pattern files**: `contract-review.md`, `legal-planning.md`, `project-planning.md`, `financial-forcing-questions.md`, `cost-forcing-questions.md`, `pitch-deck-structure.md`, `slidev-deck-template.md`, `yc-compliance-checklist.md`
- **Missing template files**: `financial-analysis.md` and 7 Typst templates in `templates/typst/`
- **No deck navigation link**: No reference to `deck/README.md`
- **No context discovery section**: `index-entries.json` mechanism not explained

### 3. Extension Architecture (Reference)

**Commands (8)**:

| Command | Skill | Agent | Domain |
|---------|-------|-------|--------|
| `/market` | skill-market | market-agent | TAM/SAM/SOM market sizing |
| `/analyze` | skill-analyze | analyze-agent | Competitive landscape |
| `/strategy` | skill-strategy | strategy-agent | Go-to-market strategy |
| `/legal` | skill-legal | legal-council-agent | Contract review |
| `/project` | skill-project | project-agent | Project timeline |
| `/finance` | skill-finance | finance-agent | Financial analysis |
| `/sheet` | skill-spreadsheet | spreadsheet-agent | Cost breakdowns |
| `/deck` | skill-deck-* | deck-*-agent | Pitch deck creation |

**Deck Pipeline** (3-skill dedicated workflow):
- Research: `skill-deck-research` -> `deck-research-agent` (synthesizes materials, maps to slide structure)
- Plan: `skill-deck-plan` -> `deck-planner-agent` (interactive library selection via AskUserQuestion)
- Implement: `skill-deck-implement` -> `deck-builder-agent` (assembles Slidev deck from library)

**Non-Deck Pipeline** (shared skills):
- Research: domain-specific skill (skill-market, skill-analyze, etc.)
- Plan: `skill-founder-plan` -> `founder-plan-agent`
- Implement: `skill-founder-implement` -> `founder-implement-agent`

**Routing** (from `/task` keyword detection):
- "deck", "slide", "presentation", "pitch deck" -> `founder:deck`
- "spreadsheet", "sheet", "excel" -> `founder:sheet`
- "finance", "financial", "revenue", "burn rate" -> `founder:finance`
- "market size", "tam", "sam", "som" -> `founder:market`
- "competitive", "competitor" -> `founder:analyze`
- "strategy", "strategic", "roadmap" -> `founder:strategy`
- "legal", "contract", "agreement" -> `founder:legal`
- "project plan", "timeline", "milestone" -> `founder:project`
- "founder", "go-to-market", "gtm" -> `founder`

### 4. Deck Library Architecture

**Seed vs Runtime Copy Pattern**:
- Seed (read-only): `.claude/extensions/founder/context/project/founder/deck/`
- Runtime (mutable): `.context/deck/` -- copied on first use, agents write back new content

**Content Slot System**: Content files use structured comment-header metadata with `[SLOT: ...]` markers that agents fill from research data:
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

**Agent Navigation**: Agents load `deck/index.json` (indexed in `index-entries.json`), which provides category metadata, entry descriptions with tags, and file paths. The README should be a human-readable companion to this machine-readable index.

### 5. Documentation Conventions (from Cross-Reference)

**Rich README pattern** (used by web, nix, neovim extensions):
1. H1 title with domain name
2. Short description paragraph
3. `## Directory Structure` -- annotated code-block tree
4. `## Loading Strategy` -- task-type-based guidance
5. `## Configuration Assumptions` -- prerequisites, versions
6. `## Key Concepts` -- 3-5 domain concepts with subsections
7. `## Agent Context Loading` -- table mapping task types to files

**Formatting rules**:
- No YAML frontmatter in README files
- H1 title, H2 major sections, H3 subsections
- Tables for mappings (commands, skills, agents)
- Backtick inline code for paths, commands, skill names
- No emojis

**No other extension has a context sub-domain README** -- the `deck/` directory is unique in having both `index.json` and a README slot.

## Synthesis

### Conflicts Resolved

None. Both teammates independently reached the same conclusions about the gaps and recommended similar content outlines. Teammate A focused on exhaustive structure analysis; Teammate B focused on cross-referencing and documentation patterns. Findings are fully complementary.

### Gaps Identified

None significant. Between both teammates, all files in the extension were examined and all cross-references in the command system were traced.

### Recommendations

#### deck/README.md (New Content -- Priority: Critical)

Follow the rich README pattern with these sections:

1. **`# Deck Library`** -- title + 2-sentence purpose
2. **`## Overview`** -- what the library enables, relationship to `index.json`, seed vs runtime copy
3. **`## Directory Structure`** -- full annotated tree (all 6 categories)
4. **`## Categories`** -- subsections for each of the 6 categories:
   - Themes (5) -- table: id, name, color_schema, mood, use case
   - Patterns (5) -- table: id, name, slide_count, deck_modes
   - Animations (6) -- table: id, name, trigger, complexity
   - Styles (9) -- table: id, name, type (colors/typography/texture)
   - Components (4) -- table: component, props, usage context
   - Contents (22+) -- table: id, slide_type, deck_modes
5. **`## Content Slot System`** -- how `[SLOT: ...]` markers work
6. **`## Agent Navigation`** -- how agents use index.json to select library items
7. **`## Import Methods`** -- `src` frontmatter vs direct copy
8. **`## Extending the Library`** -- write-back mechanism for new content
9. **`## Related Context`** -- links to pitch-deck-structure.md, slidev-deck-template.md, yc-compliance-checklist.md
10. **`## Navigation`** -- back-link to `../README.md`

#### context/project/founder/README.md (Update -- Priority: High)

1. Update directory structure tree to include all current files
2. Add `deck/` subdirectory with link to `deck/README.md`
3. Update commands table from 4 to all 8 commands
4. Add context discovery section explaining `index-entries.json`
5. Add missing domain, pattern, and template file references

## Teammate Contributions

| Teammate | Angle | Status | Confidence |
|----------|-------|--------|------------|
| A | Primary documentation audit | completed | high |
| B | Cross-reference and patterns | completed | high |

## Source Files Examined

- `manifest.json` (extension configuration)
- All 8 command files in `.claude/extensions/founder/commands/`
- `index-entries.json` (31 context entries)
- `deck/index.json` (477-line library catalog)
- Both target README files
- 8+ extension READMEs for pattern reference
- Documentation policy standards
- Deck-specific skills (deck-research, deck-plan, deck-implement)
- Deck-specific agents (deck-research-agent, deck-planner-agent, deck-builder-agent)
