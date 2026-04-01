# Research Report: Reusable Slidev Deck Library System

**Task**: 345 - Port /deck command-skill-agent from Typst to Slidev
**Date**: 2026-04-01
**Mode**: Team Research (3 teammates)
**Session**: sess_1775057835_fb672f

---

## Executive Summary

This report synthesizes research from three parallel investigations into designing a reusable Slidev deck construction system. The system comprises five interconnected layers: (1) **deck construction protocols** — 12 standardized recipes that combine layout, animation, styling, and content slots; (2) **animation pattern library** — 12 categorized animation patterns with usage guidelines and performance notes; (3) **composable styling presets** — mix-and-match color palettes, typography pairings, and background textures; (4) **reusable Vue components** — 8 auto-imported components for common pitch deck elements; and (5) **a searchable JSON index** with a 6-step deck-planner agent workflow that guides users from aesthetic choices through content ordering to plan generation.

The core architectural insight is that Slidev's component auto-import system, UnoCSS shortcut tokens, and addon packaging create a natural fit for a protocol-based library. Protocols are the atomic units; deck modes (INVESTOR, LIGHTNING, DEMO, ONE-PAGER) are protocol sequences; the index makes everything searchable by the deck-planner agent.

---

## 1. Deck Construction Protocols

**Source**: Teammate A | **Confidence**: HIGH (patterns confirmed from Slidev docs)

### 1.1 Protocol Concept

A "protocol" is a standardized recipe combining: layout + frontmatter + animation directives + CSS classes + content slots. Each protocol is self-contained, reusable across deck modes, and stored as a markdown file in the deck library.

### 1.2 Protocol Inventory (12 Protocols)

| # | Protocol | Layout | Animation | Content Slots |
|---|----------|--------|-----------|---------------|
| 1 | **Cover** | `cover` | v-motion entrance (y+opacity, 800ms) | company, tagline, round, date |
| 2 | **Problem Statement** | `statement` / `image-right` | v-mark.highlight on headline; v-clicks for evidence | problem_headline, evidence_1-3 |
| 3 | **Solution** | `two-cols` | v-click right panel; v-mark.circle on benefit | problem_state, solution_state, key_benefit |
| 4 | **Metric Reveal** | `center` | v-click + v-motion spring stagger (0/100/200ms delay) | metric_{1-3}_value, metric_{1-3}_label |
| 5 | **Team Grid** | `center` | v-click per member; v-motion stagger | name, role, bio, photo (per member) |
| 6 | **Market Size** | `two-cols` | v-click concentric circles + numbers | tam, sam, som, market_context |
| 7 | **Timeline** | `default` | v-clicks sequential reveal | date, label, description, status per item |
| 8 | **Quote/Testimonial** | `quote` / `statement` | v-motion fade-up; v-click attribution | quote_text, attribution |
| 9 | **Comparison** | `two-cols` / v-switch | v-switch for state transitions | competitors[], comparison[] |
| 10 | **Demo/Screenshot** | `image-right` / `image` | v-clicks for callout points; Arrow annotations | image, callout_points[] |
| 11 | **Ask/CTA** | `center` | v-motion spring on amount; v-click allocation grid | ask_amount, terms, allocation[] |
| 12 | **Section Divider** | `section` | slide-left | section_title |

### 1.3 Protocol File Format

Each protocol is stored as a markdown file documenting:
- Name, purpose, and best-for tags
- Required layout(s) and frontmatter YAML
- Complete HTML/markdown template with animation directives
- Content slots with types and required/optional flags
- CSS classes used (referencing UnoCSS shortcuts)
- Usage example

### 1.4 Reusable Vue Components

8 components serve as building blocks within protocols:

| Component | Props | Used By Protocols |
|-----------|-------|-------------------|
| `MetricCard` | value, label, delay, color | Metric Reveal, Ask/CTA |
| `TeamMember` | name, role, bio, photo, delay | Team Grid |
| `TimelineItem` | date, label, description, status | Timeline |
| `ComparisonCol` | title, points, color, highlight | Comparison |
| `QuoteBlock` | text, author, role | Quote/Testimonial |
| `LogoCloud` | logos[] | Demo, partnerships |
| `FeatureList` | features[] with icon | Solution |
| `BarChart` | bars[] with value/label/color | Traction (Demo mode) |

All components are auto-imported from `components/` — no import statements needed in slide markdown.

### 1.5 Custom Layouts (5)

| Layout | Slots | Used By |
|--------|-------|---------|
| `cover-hero` | default | Cover (enhanced with full-bleed image) |
| `metric-grid` | default | Metric Reveal (3-up grid) |
| `team-showcase` | default | Team Grid |
| `ask-slide` | default | Ask/CTA with allocation |
| `section-accent` | default | Section Divider with accent |

---

## 2. Animation Pattern Library

**Source**: Teammate C | **Confidence**: HIGH

### 2.1 Animation Categories (12 Patterns)

| ID | Name | Category | Mechanism | Complexity | Best For |
|----|------|----------|-----------|------------|----------|
| A | Fade-In | Entrance | CSS `.slidev-vclick-target` | low | Bullet lists, default |
| B | Slide-In Below | Entrance | v-motion y-axis | low | Feature cards, key points |
| C | Scale-In Pop | Entrance | v-motion spring scale | medium | Key metrics, CTA |
| D | Blur-In | Entrance | CSS filter:blur override | medium | Premium focus reveals |
| E | Metric Cascade | Data | v-motion staggered delay | medium | KPI slides (3-4 metrics) |
| F | Counter Animate | Data | @number-flow/vue | medium | Live demos, before/after |
| G | Chart Build | Data | v-click + CSS height | medium | Revenue growth bars |
| H | Rough Marks | Emphasis | v-mark (7 types) | low | Key terms, metrics |
| I | Pulse Glow | Emphasis | CSS @keyframes | low | Single persistent element |
| J | Staggered List | Sequence | v-clicks depth/every | low | Bullet lists, agendas |
| K | Cascade Grid | Sequence | v-motion index-based delay | medium | Feature grids, logos |
| L | Typewriter | Sequence | CSS steps() | medium | Code reveals, terminal |

### 2.2 Critical Timing Rule

When combining slide transitions with element animations, add ~350ms delay to v-motion `enter` to let the slide transition complete:

```html
<!-- Slide uses transition: fade (300ms) -->
<div v-motion
  :initial="{ y: 20, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { delay: 350 } }"
>
```

### 2.3 View Transition Caveat

**Known issue**: When `transition: view-transition` is set globally, the morph fires on every click step, not just slide changes. Use view-transition only on specific slides, not globally.

### 2.4 Animation Budget by Deck Mode

| Mode | Budget | Allowed Mechanisms |
|------|--------|-------------------|
| INVESTOR | Rich | v-click + v-motion + v-mark (all) |
| LIGHTNING | Minimal | v-click only (time pressure) |
| DEMO | Medium + code | Shiki Magic Move, minimal motion |
| ONE-PAGER | None | No animations (single slide) |

---

## 3. Composable Styling Preset System

**Source**: Teammate C | **Confidence**: HIGH

### 3.1 Architecture

Presets are composable CSS files in `styles/presets/`. The `styles/index.css` imports selected presets. Per-slide `<style>` blocks override for specific slides.

```
styles/
├── index.css              # Imports selected presets
└── presets/
    ├── colors/            # 4 palettes
    │   ├── dark-blue.css  # AI startup default
    │   ├── dark-purple.css # Premium/luxury
    │   ├── dark-green.css # Biopharma/sustainability
    │   └── dark-warm.css  # Fintech/consumer
    ├── typography/         # 3 pairings
    │   ├── serif-heading.css  # Playfair Display + Inter
    │   ├── mono-heading.css   # JetBrains Mono + Inter
    │   └── all-sans.css       # Inter throughout
    └── textures/           # 3 overlays
        ├── grid-overlay.css   # Subtle grid lines
        ├── noise-grain.css    # Film grain SVG
        └── gradient-radial.css # Spotlight glow
```

### 3.2 Composition Pattern

```css
/* styles/index.css */
@import './presets/colors/dark-blue.css';
@import './presets/typography/serif-heading.css';
@import './presets/textures/grid-overlay.css';
@import './presets/textures/noise-grain.css';

.slidev-vclick-target {
  transition: all 0.45s cubic-bezier(0.16, 1, 0.3, 1);
}
```

### 3.3 UnoCSS Design Tokens

All components use shortcut class names rather than raw Tailwind, enabling global theme changes:

```typescript
// uno.config.ts
shortcuts: {
  'text-display': 'font-serif text-6xl font-bold tracking-tight text-slate-50',
  'text-heading': 'font-serif text-4xl font-semibold text-slate-100',
  'text-body': 'font-sans text-xl text-slate-400 leading-relaxed',
  'text-label': 'font-sans text-base text-slate-500 uppercase tracking-wider',
  'text-accent': 'text-blue-400',
  'card-base': 'rounded-xl border border-white/10 bg-white/5 backdrop-blur-sm p-8',
  'card-metric': 'card-base text-center flex flex-col items-center gap-2',
}
```

---

## 4. Deck Library Index and Agent Search System

**Source**: Teammate B | **Confidence**: HIGH

### 4.1 Index Schema

A `deck-library/index.json` file catalogs all library entries across 5 categories:

| Category | Key Fields | Query Axes |
|----------|-----------|------------|
| `protocol` | content_slots, required_layouts, compatible_themes | content_type, visual_style, deck_mode |
| `animation` | animation_type, complexity, syntax_example | complexity, best_for, deck_mode |
| `preset` | color_scheme, font_pairing, base_theme | mood, visual_style, color_schema |
| `template` | protocol_id, preset_id, content_slots | slide_type, visual_style |
| `structure` | slide_sequence, required_protocols | deck_mode, audience |

Each entry uses controlled vocabularies to prevent tag drift. Example protocol entry:

```json
{
  "id": "protocol-metric-callout",
  "path": "deck-library/protocols/metric-callout.md",
  "category": "protocol",
  "subcategory": "data-reveal",
  "name": "Metric Callout",
  "tags": {
    "visual_style": ["minimal", "data-focused"],
    "content_type": ["traction", "financials"],
    "deck_mode": ["pitch", "demo"],
    "animation_complexity": "medium"
  },
  "required_layouts": ["fact", "center"],
  "content_slots": ["metric_value", "metric_label", "context_note"],
  "compatible_themes": ["seriph", "default", "dracula"]
}
```

### 4.2 Deck Structure Entries

Structures define slide sequences for each deck mode with protocol hints:

```json
{
  "id": "structure-yc-10-slide",
  "category": "structure",
  "name": "YC 10-Slide",
  "deck_mode": "pitch",
  "slide_sequence": [
    {"position": 1, "slide_type": "cover",    "protocol_hint": "protocol-cover-statement"},
    {"position": 2, "slide_type": "problem",   "protocol_hint": "protocol-problem-framing"},
    {"position": 3, "slide_type": "solution",  "protocol_hint": "protocol-solution-reveal"},
    {"position": 4, "slide_type": "market",    "protocol_hint": "protocol-market-size"},
    {"position": 5, "slide_type": "biz-model", "protocol_hint": "protocol-revenue-table"},
    {"position": 6, "slide_type": "traction",  "protocol_hint": "protocol-metric-callout"},
    {"position": 7, "slide_type": "team",      "protocol_hint": "protocol-team-two-col"},
    {"position": 8, "slide_type": "competition","protocol_hint": "protocol-comparison-matrix"},
    {"position": 9, "slide_type": "financials", "protocol_hint": "protocol-metric-callout"},
    {"position": 10,"slide_type": "ask",       "protocol_hint": "protocol-ask-statement"}
  ]
}
```

### 4.3 Index Location

```
.claude/extensions/founder/context/project/founder/deck-library/index.json
```

Discoverable via the existing extension context loader with `load_when.agents: ["deck-planner-agent", "deck-builder-agent"]`.

---

## 5. Deck-Planner Agent Workflow (6 Steps)

**Source**: Teammate B | **Confidence**: HIGH

The current 3-step workflow expands to 6 steps. Steps 1-3 are new (library-aware); Steps 4-6 match the existing stages. A `--quick` flag skips Steps 1-3 for backward compatibility.

### Step 1: Style Selection (NEW)

Agent queries presets by mood/aesthetic. User picks one via AskUserQuestion (single-select).

**Narrows**: compatible themes for subsequent protocol filtering.

### Step 2: Deck Structure Selection (NEW)

Agent queries structures by deck_mode. User picks one (single-select).

**Narrows**: defines slide_sequence and protocol_hints for Step 3.

### Step 3: Pattern Selection (NEW)

Agent shows default protocol per slide position with alternatives. User selects overrides (multi-select grouped by slide).

**Produces**: `protocol_manifest` — mapping of position -> protocol_id.

### Step 4: Slide Content Assignment (existing)

Content from research report mapped to content slots. User assigns main vs appendix.

### Step 5: Slide Ordering (existing)

YC Standard / Story-First / Traction-Led ordering options.

### Step 6: Plan Generation (existing, extended)

Produces implementation plan + standalone deck summary markdown.

### Intermediate State (Full)

```json
{
  "stage": "complete",
  "selected_preset": {"id": "preset-dark-blue-navy", "base_theme": "seriph"},
  "selected_structure": {"id": "structure-yc-10-slide", "deck_mode": "pitch"},
  "protocol_manifest": {
    "1": {"protocol_id": "protocol-cover-statement", "slide_type": "cover"},
    "6": {"protocol_id": "protocol-metric-callout", "slide_type": "traction"}
  },
  "main_slides": [1, 2, 3, 4, 5, 6, 7, 10],
  "appendix_slides": [8, 9],
  "ordering": "YC Standard"
}
```

State is written to `.return-meta.json` after each AskUserQuestion for interruption recovery.

---

## 6. Deck Summary Markdown Format

**Source**: Teammate B | **Confidence**: MEDIUM

A standalone `{NN}-deck-summary.md` file with 7 sections serves both human review and agent re-ingestion:

1. **Styling Decisions** — preset, theme, colors, fonts with rationale column
2. **Protocol Selections** — per-slide protocol with justification
3. **Animation Choices** — per-slide animation ID, type, complexity
4. **Slide Manifest & Content Slots** — slot -> value mappings per slide
5. **Content Gaps** — missing data with handling strategy (placeholder/appendix/fallback)
6. **Build/Export Instructions** — self-contained reproduction steps
7. **Revision Notes** — change tracking from original plan

---

## 7. Project Directory Structure

**Source**: Teammates A + C | **Confidence**: HIGH

```
deck-project/
├── slides.md              # Main deck (assembled from templates)
├── package.json           # Dependencies
├── uno.config.ts          # Design tokens + shortcut classes
├── components/            # Auto-imported Vue components
│   ├── cards/
│   │   ├── MetricCard.vue
│   │   └── StatCard.vue
│   ├── team/
│   │   └── TeamMember.vue
│   ├── timeline/
│   │   └── TimelineItem.vue
│   ├── comparison/
│   │   └── ComparisonCol.vue
│   └── market/
│       └── MarketRing.vue
├── layouts/               # Custom named layouts
│   ├── cover-hero.vue
│   ├── metric-grid.vue
│   ├── team-showcase.vue
│   ├── ask-slide.vue
│   └── section-accent.vue
├── styles/
│   ├── index.css          # Global styles (imports presets)
│   └── presets/           # Composable style presets
├── public/
│   └── images/            # Slide images
├── global-bottom.vue      # Footer: page numbers, logo
└── snippets/              # Code snippets for magic-move
```

### Build/Export

- `slidev slides.md` — dev server with hot reload
- `slidev export --format pdf --with-clicks --scale 2` — PDF export (requires playwright-chromium)
- `slidev build` — static SPA for hosting
- Estimated export: 30-90s for 20-slide deck

---

## 8. Deck Mode Mappings

**Source**: Teammate A | **Confidence**: HIGH

### Protocol-to-Mode Matrix

| Protocol | INVESTOR | LIGHTNING | DEMO | ONE-PAGER |
|----------|:--------:|:---------:|:----:|:---------:|
| Cover | ✓ | ✓ | ✓ | (inline) |
| Problem | ✓ | ✓ (merged) | ✓ | (inline) |
| Solution | ✓ | ✓ (merged) | ✓ | (inline) |
| Metric Reveal | ✓ | ✓ | ✓ (benchmarks) | (StatCard) |
| Team Grid | ✓ | (minimal) | ✓ (minimal) | (inline) |
| Market Size | ✓ | (skip) | (skip) | (inline) |
| Timeline | (appendix) | (skip) | ✓ (onboarding) | (skip) |
| Quote | (optional) | (skip) | (optional) | (skip) |
| Comparison | (optional) | (skip) | ✓ | (skip) |
| Demo/Screenshot | (skip) | ✓ | ✓✓ | (skip) |
| Ask/CTA | ✓ | ✓ (simplified) | ✓ (trial CTA) | (inline) |
| Section Divider | (optional) | (skip) | (optional) | (skip) |

### Mode-Specific Constraints

- **INVESTOR**: 10 slides, `fade` transition, max 5 bullets, fonts ≥ 24pt
- **LIGHTNING**: 5 slides, `slide-left`, v-click only (no v-motion), 1 min/slide
- **DEMO**: 8-12 slides, Shiki Magic Move for code, iframe embeds
- **ONE-PAGER**: 1 slide, no animations, `canvasWidth: 1200`, fonts ≥ 16pt (relaxed)

---

## 9. Conflicts Resolved

### Conflict 1: Component naming (Teammates A vs C)

Teammate A named the comparison component `ComparisonCol`; Teammate C proposed `ComparisonTable`. **Resolution**: Use `ComparisonCol` for the per-column element (matches v-switch pattern) and no separate `ComparisonTable` wrapper — the protocol template handles the grid layout directly.

### Conflict 2: Chart approach (Teammates A vs C)

Teammate A recommended CSS-only bar charts for simplicity; Teammate C documented `@number-flow/vue` for animated counters and a `BarChart.vue` component with v-motion. **Resolution**: Include both. CSS-only `BarChart.vue` for static presentations; `AnimatedMetric` with @number-flow/vue as an optional upgrade for demo mode. The animation budget rule determines which is used.

### Conflict 3: Deck modes naming (Teammate A vs B)

Teammate A used INVESTOR/LIGHTNING/DEMO/ONE-PAGER; Teammate B used structure IDs like `structure-yc-10-slide`. **Resolution**: Both coexist — mode names are user-facing labels in the planner workflow; structure IDs are machine-readable index keys. The mapping is 1:1.

---

## 10. Gaps Identified

| Gap | Severity | Recommended Action |
|-----|----------|-------------------|
| Chart/graph component | Medium | Start with CSS-only BarChart; upgrade path to Chart.js |
| Typst template color palette mapping | Medium | Map 5 existing templates to preset entries |
| `view-transition` + v-click interaction | Low | Use per-slide only, document caveat |
| Index schema validation | Low | Create `index.schema.json` before populating entries |
| Addon packaging decision | Low | Start local (`components/`); package as addon when reused across 2+ decks |

---

## 11. Implementation Recommendations

1. **Start with index schema** (`deck-library/index.schema.json`) — define controlled vocabularies before populating entries to prevent tag drift
2. **Seed with minimal set**: 5 presets, 10 protocols, 3 structures, 5 animations — matching existing template count
3. **Build core components first**: `MetricCard`, `TeamMember`, `TimelineItem`, `ComparisonCol` are the 4 most-used
4. **Write `uno.config.ts` design tokens** — all components depend on shortcut classes
5. **Implement 6-step planner workflow** with `--quick` bypass for backward compatibility
6. **Store intermediate state** to `.return-meta.json` for interruption recovery
7. **Generate deck summary** as standalone file alongside the plan

---

## Teammate Contributions

| Teammate | Angle | Status | Key Deliverables |
|----------|-------|--------|-----------------|
| A | Protocols & Patterns | completed | 12 protocols, 8 components, 5 layouts, 4 mode mappings |
| B | Index & Agent Search | completed | Index schema (5 categories), 6-step workflow, 7 jq queries, deck summary format |
| C | Animation & Styling | completed | 12 animation patterns, 4 color palettes, 3 typography pairings, 3 textures, project structure |

---

## Sources

### Slidev Official Documentation
- [Component Guide](https://sli.dev/guide/component)
- [Directory Structure](https://sli.dev/custom/directory-structure)
- [Layouts Guide](https://sli.dev/guide/write-layout)
- [Built-in Layouts](https://sli.dev/builtin/layouts)
- [Built-in Components](https://sli.dev/builtin/components)
- [Global Layers](https://sli.dev/features/global-layers)
- [Animations](https://sli.dev/guide/animations)
- [Theme Gallery](https://sli.dev/resources/theme-gallery)
- [Addon System](https://sli.dev/guide/theme-addon)
- [Write Addons](https://sli.dev/guide/write-addon)
- [UnoCSS Config](https://sli.dev/custom/config-unocss)
- [Font Config](https://sli.dev/custom/config-fonts)

### Community & Tools
- [Slidev Dracula Theme](https://github.com/jd-solanki/slidev-theme-dracula)
- [Slidev Addon Components](https://github.com/estruyf/slidev-addon-components)
- [Shiki Magic Move](https://github.com/shikijs/shiki-magic-move)
- [@vueuse/motion](https://motion.vueuse.org)
- [@number-flow/vue](https://www.npmjs.com/package/@number-flow/vue)
- [DeepWiki: Slidev Animations](https://deepwiki.com/slidevjs/slidev/4.2-animation-and-transitions)

### AI Presentation Tools (Design Patterns)
- [Gamma.app](https://gamma.app/) — step-wise selection workflow
- [Beautiful.ai SmartSlides](https://www.beautiful.ai/smart-slides) — content-driven slide categorization
- [Presenton](https://github.com/presenton/presenton) — open-source AI presentation generator

### Existing Codebase
- `specs/345_port_deck_typst_to_slidev/reports/04_slidev-themes-research.md`
- `.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md`
- `.claude/extensions/founder/commands/deck.md`
- `.claude/context/index.json`
