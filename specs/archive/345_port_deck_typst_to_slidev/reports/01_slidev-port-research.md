# Research Report: Port /deck from Typst to Slidev

**Task**: 345 - Port /deck command-skill-agent from Typst to Slidev
**Date**: 2026-03-31
**Status**: Complete

---

## 1. Current System Analysis

### Architecture Overview

The `/deck` system in the `founder/` extension consists of:

| Component | File | Purpose |
|-----------|------|---------|
| Command | `extensions/founder/commands/deck.md` | Entry point with 4 modes (INVESTOR/UPDATE/INTERNAL/PARTNERSHIP) |
| Skill (research) | `extensions/founder/skills/skill-deck-research/SKILL.md` | Routes to deck-research-agent |
| Skill (plan) | `extensions/founder/skills/skill-deck-plan/SKILL.md` | Routes to deck-planner-agent |
| Skill (implement) | `extensions/founder/skills/skill-deck-implement/SKILL.md` | Routes to deck-builder-agent |
| Agent (research) | `extensions/founder/agents/deck-research-agent.md` | Material synthesis, slide mapping |
| Agent (plan) | `extensions/founder/agents/deck-planner-agent.md` | Template/content/ordering selection |
| Agent (build) | `extensions/founder/agents/deck-builder-agent.md` | Typst generation and compilation |
| Pattern | `context/project/founder/patterns/pitch-deck-structure.md` | YC 10-slide structure |
| Pattern | `context/project/founder/patterns/touying-pitch-deck-template.md` | Touying 0.6.3 reference |
| Templates (5) | `context/project/founder/templates/typst/deck/deck-*.typ` | Color-themed Typst templates |
| Manifest | `extensions/founder/manifest.json` | Routing and registration |

### Current Workflow

```
/deck "description"
  -> STAGE 0: Forcing questions (purpose, materials, context)
  -> Create task with forcing_data
  -> STOP: "Next: /research {N}"

/research {N}
  -> deck-research-agent: Ingest materials, map to 10 slides, gap analysis
  -> Output: Research report with per-slide content + [MISSING] markers

/plan {N}
  -> deck-planner-agent: 3 interactive questions
     Q1: Template (5 color palettes)
     Q2: Slide selection (multi-select main vs appendix)
     Q3: Ordering strategy (YC Standard / Story-First / Traction-Led)
  -> Output: Plan with "Deck Configuration" section

/implement {N}
  -> deck-builder-agent: Select template, substitute content, compile
  -> Output: strategy/{slug}-deck.typ + optional .pdf
```

### Key Design Principles (Preserve)

1. **Pre-task forcing questions** - Gather data before task creation
2. **Material synthesis over interaction** - Research agent reads materials, asks max 1-2 follow-ups
3. **Early metadata pattern** - All agents write metadata at Stage 0 for recovery
4. **Non-blocking compilation** - Build failure doesn't block task completion
5. **YC 10-slide structure** - Standard pitch deck format
6. **Separation of concerns** - Research (read), Plan (configure), Build (generate)

### Current Typst Template Structure

Each `.typ` template defines:
- 5 `#let` parameters: company-name, company-subtitle, author-name, funding-round, funding-date
- 5 palette colors: primary, secondary, accent, bg, text
- Touying 0.6.3 simple theme, 16:9 aspect
- Typography: Montserrat H1/H2 (48pt/40pt), Inter body (32pt)
- 10 slides with `[TODO:]` markers for content substitution
- Appendix section

---

## 2. Slidev Documentation Summary

### Source Links

- Syntax: https://sli.dev/guide/syntax
- Animations: https://sli.dev/guide/animations
- Themes/Addons: https://sli.dev/guide/theme-addon
- Components: https://sli.dev/guide/component
- Layouts: https://sli.dev/guide/layout
- AI Guide: https://sli.dev/guide/work-with-ai
- AI Skill Repository: https://github.com/slidevjs/slidev/tree/main/skills/slidev

### 2.1 Core Syntax

**Slide separation**: `---` with blank lines before/after.

**Headmatter** (first frontmatter block, configures entire deck):
```yaml
---
theme: seriph
title: My Deck
author: Name
aspectRatio: 16/9
canvasWidth: 980
colorSchema: dark
fonts:
  sans: Inter
  serif: Montserrat
transition: slide-left
defaults:
  layout: default
themeConfig:
  primary: '#5d8392'
addons: []
---
```

**Per-slide frontmatter**:
```yaml
---
layout: two-cols
background: /path/to/image.jpg
transition: fade
clicks: 5
class: my-class
---
```

**Presenter notes**: HTML comments at end of slide (`<!-- notes here -->`).

**Code blocks**: Shiki highlighting, line highlighting (`{2,3}`), click-based (`{1|2-3|all}`), line numbers, max height, Monaco editor (`{monaco}`), runnable (`{monaco-run}`), TwoSlash type annotations, code groups, Shiki Magic Move for animated transitions.

**LaTeX**: Inline `$E = mc^2$`, block `$$...$$`.

**Diagrams**: Mermaid (` ```mermaid `), PlantUML (` ```plantuml `).

**Scoped CSS**: `<style>` tags auto-scoped per slide. Global: `styles/index.css`.

**Slide importing**: `src: ./pages/intro.md` in frontmatter.

### 2.2 Animation System

**v-click**: `<div v-click>` appears on next click. Supports relative (`+1`, `-1`), absolute (`3`), ranges (`[2,5]`), hide modifier (`.hide`).

**v-after**: Appears simultaneously with previous v-click.

**v-clicks**: Applies v-click to all children. Props: `depth`, `every`.

**v-switch**: Multi-slot conditional: `<template #1>`, `<template #2>`.

**v-motion**: Motion animations via @vueuse/motion with `:initial`, `:enter`, `:click-1` variants.

**Slide transitions**: `fade`, `fade-out`, `slide-left/right/up/down`, `view-transition`. Bidirectional: `slide-left | slide-right`.

**v-mark**: Hand-drawn annotations (underline, circle, highlight, strike-through, box) with Rough Notation.

### 2.3 Themes and Addons

**Using themes**: `theme: seriph` in headmatter. Auto-installed on dev server start. Official themes: `seriph`, `default`, `apple-basic`, `bricks`, `dracula`, etc.

**Theme config**: `themeConfig:` in headmatter for theme-specific options.

**Addons**: `addons: [excalidraw, '@slidev/plugin-notes']`.

**Eject**: `slidev theme eject` extracts to local `theme/` for customization.

### 2.4 Built-in Layouts (20)

| Layout | Use Case | Notable Props |
|--------|----------|---------------|
| `default` | Standard content | - |
| `center` | Centered content | - |
| `cover` | Title/cover (auto for slide 1) | - |
| `intro` | Introduction | - |
| `end` | Final slide | - |
| `section` | Section divider | - |
| `quote` | Quotation | - |
| `statement` | Bold assertion | - |
| `fact` | Data/statistic prominence | - |
| `full` | Full screen, no padding | - |
| `none` | Blank canvas | - |
| `two-cols` | Two columns | Slots: default (left), `::right::` |
| `two-cols-header` | Header + two columns | Slots: default, `::left::`, `::right::` |
| `image` | Full-screen image | `image`, `backgroundSize` |
| `image-left` | Image left, content right | `image`, `class` |
| `image-right` | Image right, content left | `image`, `class` |
| `iframe` | Full-screen iframe | `url` |
| `iframe-left` | Iframe left, content right | `url`, `class` |
| `iframe-right` | Iframe right, content left | `url`, `class` |

**Slot syntax**: `::right::`, `::left::` shorthand for named slots.

### 2.5 Built-in Components

Key components for pitch decks:
- `Arrow` / `VDragArrow` - Visual connectors
- `AutoFitText` - Auto-scaling text (useful for metrics/stats)
- `LightOrDark` - Theme-conditional rendering
- `Transform` - CSS transform wrapper (`scale`, `origin`)
- `SlidevVideo` / `Youtube` - Media embedding
- `Toc` - Table of contents

### 2.6 AI Skill System

**Installation**: `npx skills add slidevjs/slidev`

**Structure**: `skills/slidev/` contains:
- `SKILL.md` - Master skill definition
- `references/` - 50+ detailed reference files organized by category

**Reference categories**: core (10), code (7), editor (6), diagrams (3), layout (6), animation (3), style (3), syntax (4), presenter (4), build (4), API (1), tools (1).

**Key reference files for pitch deck port**:
- `core-syntax.md` - Slide structure basics
- `core-headmatter.md` - Deck-wide configuration
- `core-frontmatter.md` - Per-slide configuration
- `core-layouts.md` - Layout system
- `core-animations.md` - Click animations
- `core-components.md` - Built-in components
- `core-exporting.md` - PDF/PPTX export
- `layout-slots.md` - Named slot syntax
- `style-scoped.md` - Per-slide styling
- `core-global-context.md` - Template variables ($nav, $slidev, etc.)

### 2.7 CLI and Export

```bash
# Development
pnpm create slidev          # Create new project
slidev [entry.md]           # Dev server

# Build
slidev build                # SPA output
slidev export               # PDF (requires playwright-chromium)
slidev export --format pptx # PowerPoint
slidev export --format png  # PNG per slide
slidev export --format md   # Markdown cleanup
```

---

## 3. Typst-to-Slidev Mapping

### Template Parameters

| Typst Parameter | Slidev Equivalent |
|----------------|-------------------|
| `#let company-name` | Headmatter `title:` or custom variable |
| `#let company-subtitle` | Headmatter `info:` or slide content |
| `#let author-name` | Headmatter `author:` |
| `#let funding-round` | Custom frontmatter or slide content |
| `#let funding-date` | Headmatter `date:` or computed |

### Color Palettes -> Themes

| Typst Template | Slidev Approach |
|---------------|-----------------|
| deck-dark-blue.typ | `theme: seriph` + `colorSchema: dark` + `themeConfig: { primary: '#60a5fa' }` |
| deck-minimal-light.typ | `theme: seriph` + `colorSchema: light` + `themeConfig: { primary: '#3182ce' }` |
| deck-premium-dark.typ | `theme: seriph` + `colorSchema: dark` + custom CSS |
| deck-growth-green.typ | `theme: seriph` + `themeConfig: { primary: '#38a169' }` |
| deck-professional-blue.typ | `theme: seriph` + `themeConfig: { primary: '#2b6cb0' }` |

Alternatively, create a custom Slidev theme or use ejected theme with full control.

### Slide Structure Mapping

| Typst Slide | Slidev Layout | Notes |
|-------------|---------------|-------|
| 1. Title | `layout: cover` | Company name as H1, subtitle, tagline |
| 2. Problem | `layout: default` or `layout: statement` | Pain point + 3 bullets |
| 3. Solution | `layout: two-cols` | Description + feature grid via `::right::` |
| 4. Traction | `layout: fact` | 3 key metrics, large font via `AutoFitText` |
| 5. Why Us/Now | `layout: two-cols` | Two-column grid |
| 6. Business Model | `layout: default` | Pricing, unit economics |
| 7. Market (TAM/SAM/SOM) | `layout: default` | Can use Mermaid for visualization |
| 8. Team | `layout: two-cols` | Founder grid |
| 9. The Ask | `layout: center` or `layout: statement` | Raise amount, milestones |
| 10. Closing | `layout: end` | Company name, tagline, contact |

### Typography Mapping

| Typst | Slidev |
|-------|--------|
| Montserrat 48pt H1 | `fonts: { sans: 'Montserrat' }` + CSS `h1 { font-size: 3em }` |
| Montserrat 40pt H2 | CSS `h2 { font-size: 2.5em }` |
| Inter 32pt body | `fonts: { mono: 'Inter' }` + CSS |
| Min 20pt | Enforced via scoped CSS or theme |

### Compilation Mapping

| Typst | Slidev |
|-------|--------|
| `typst compile deck.typ` | `slidev export deck.md` (requires playwright-chromium) |
| Output: `.pdf` | Output: `.pdf` (default), `.pptx`, `.png` |
| Non-blocking | Non-blocking (same pattern) |

---

## 4. Port Strategy

### Files to Create (New)

1. **Slidev markdown templates** (5) in `context/project/founder/templates/slidev/deck/`
   - `deck-dark-blue.md`
   - `deck-minimal-light.md`
   - `deck-premium-dark.md`
   - `deck-growth-green.md`
   - `deck-professional-blue.md`

2. **Slidev pattern file** replacing touying reference:
   - `context/project/founder/patterns/slidev-deck-template.md`

### Files to Modify

3. **deck-builder-agent.md** - Emit `.md` instead of `.typ`, run `slidev export` instead of `typst compile`, update template loading logic
4. **deck-planner-agent.md** - Update template descriptions (Slidev themes instead of color palettes), adjust ordering to use Slidev frontmatter
5. **deck-research-agent.md** - Minor: update output markers from `[TODO:]` to match new template format
6. **skill-deck-implement/SKILL.md** - Update artifact extensions (.md, .pdf instead of .typ, .pdf)
7. **deck.md command** - Minimal changes (workflow is preserved)
8. **manifest.json** - Update context references if template paths change
9. **pitch-deck-structure.md** - Update typography references from pt sizes to CSS/Slidev equivalents

### Files to Remove

10. **touying-pitch-deck-template.md** - Replaced by slidev-deck-template.md
11. **5 `.typ` template files** - Replaced by `.md` templates

### Preserved (No Changes)

- Forcing questions workflow
- 4 deck modes (INVESTOR/UPDATE/INTERNAL/PARTNERSHIP)
- YC 10-slide structure
- Material synthesis approach
- Early metadata pattern
- Non-blocking compilation
- 3-question planning flow (template, slides, ordering)
- Skill routing and preflight/postflight patterns

---

## 5. Slidev Skill Adaptation

The official Slidev skill (`skills/slidev/`) provides a comprehensive reference system with 50+ files. For the `/deck` port, the most relevant adaptation is:

### Embedding Slidev Knowledge in deck-builder-agent

Rather than installing the full Slidev skill, embed the critical syntax rules directly in:
1. **deck-builder-agent.md** - Core syntax rules for generating valid Slidev markdown
2. **slidev-deck-template.md** - Pattern file with Slidev-specific conventions

### Key Rules to Embed

```
- Slides separated by --- with blank lines
- First slide frontmatter = headmatter (deck-wide config)
- Per-slide frontmatter for layout, class, transition
- Named slots via ::right::, ::left:: syntax
- v-click for progressive reveal
- Scoped <style> for per-slide custom styling
- slidev export for PDF generation (requires playwright-chromium)
- AutoFitText component for metrics/stats
- theme + themeConfig for color customization
```

---

## 6. Risk Assessment

| Risk | Mitigation |
|------|------------|
| Slidev not installed on user's system | Same non-blocking pattern as typst - .md output is always valid |
| playwright-chromium needed for PDF export | Document as optional dependency, graceful skip |
| Theme limitations vs custom Typst templates | Use ejected theme or heavy scoped CSS for precise control |
| Font size enforcement harder in web | Use scoped CSS with !important or custom theme |
| Less precise layout control than Typst | Slidev's layout system + CSS flexbox covers pitch deck needs |

---

## 7. References

### Slidev Official Documentation
- Syntax Guide: https://sli.dev/guide/syntax
- Animation System: https://sli.dev/guide/animations
- Themes and Addons: https://sli.dev/guide/theme-addon
- Components: https://sli.dev/guide/component
- Layouts: https://sli.dev/guide/layout
- AI Development: https://sli.dev/guide/work-with-ai

### Slidev AI Skill
- Repository: https://github.com/slidevjs/slidev/tree/main/skills/slidev
- SKILL.md: https://github.com/slidevjs/slidev/blob/main/skills/slidev/SKILL.md
- 50+ reference files in `skills/slidev/references/`

### Current System Files
- Command: `.claude/extensions/founder/commands/deck.md`
- Skills: `.claude/extensions/founder/skills/skill-deck-{research,plan,implement}/SKILL.md`
- Agents: `.claude/extensions/founder/agents/deck-{research,planner,builder}-agent.md`
- Patterns: `.claude/extensions/founder/context/project/founder/patterns/`
- Templates: `.claude/extensions/founder/context/project/founder/templates/typst/deck/`
- Manifest: `.claude/extensions/founder/manifest.json`
