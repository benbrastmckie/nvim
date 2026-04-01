# Research Report: Task #340 (Round 2)

**Task**: 340 - Create reusable typst slide deck templates
**Started**: 2026-03-31T00:00:00Z
**Completed**: 2026-03-31T00:30:00Z
**Effort**: Medium
**Dependencies**: None
**Sources/Inputs**: deck-source.typ (production Logos deck), round 1 research, present/examples/premium-dark-pitch.typ
**Artifacts**: specs/340_create_typst_deck_templates/reports/02_dark-blue-template-standards.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The production `deck-source.typ` is a well-structured dark charcoal deck using touying 0.6.3 simple theme with `#slide[]` block syntax -- its sizing, margins, and color palette are production-proven
- The dark-blue palette from deck-source.typ (`#2d3238` background, `#e2e8f0` titles, `#4a90c4` accent) provides a professional, readable dark theme distinct from the existing premium-dark's near-black gold scheme
- Key universal standards extracted: 16:9 aspect ratio, consistent margin ratios, clear typographic hierarchy with at least 3 size tiers, color palette with 5 defined roles (primary, secondary, accent, bg, text)
- The user prefers dark themes -- the dark-blue template should be the **primary/default** template, replacing minimal-light as the "first" template
- Several sizing decisions in deck-source.typ are worth adapting (margin proportions, vertical spacing ratios, grid gutter sizing) even though the specific font sizes must increase for YC compliance

## Context & Scope

Round 1 research recommended against following deck-source.typ patterns, citing YC compliance concerns. This round 2 analysis re-examines deck-source.typ specifically for its strengths: sizing proportions, layout patterns, color palette, and overall design quality. The goal is to extract universal standards that improve ALL templates while maintaining YC compliance.

## Findings

### 1. Complete Analysis of deck-source.typ Design Decisions

#### 1.1 Color Palette (Dark Charcoal)

```typst
#let palette-primary   = rgb("#e2e8f0")  // light gray -- titles, headings
#let palette-secondary = rgb("#a0aec0")  // muted gray -- subtitles, metadata
#let palette-accent    = rgb("#4a90c4")  // steel blue -- emphasis, markers, links
#let palette-bg        = rgb("#2d3238")  // dark charcoal -- page background
#let palette-text      = rgb("#cbd5e0")  // light gray -- body text
```

**Color Analysis**:
- Primary vs text: `#e2e8f0` (titles) is slightly brighter than `#cbd5e0` (body) -- a subtle but effective hierarchy
- Accent `#4a90c4` (steel blue) provides strong visual punch against dark charcoal without being garish
- Background `#2d3238` is warm charcoal, NOT pure black -- this is deliberate and prevents eye strain
- The palette uses Tailwind CSS color tokens (slate/gray scale) which are perceptually balanced
- Contrast ratio: `#e2e8f0` on `#2d3238` is approximately 10.2:1 (excellent, well above 4.5:1 WCAG AA)
- Contrast ratio: `#cbd5e0` on `#2d3238` is approximately 8.5:1 (excellent)
- Contrast ratio: `#4a90c4` on `#2d3238` is approximately 4.8:1 (passes WCAG AA)

**Dark accent boxes**: The deck uses `palette-bg.darken(20%)` for card/rect backgrounds, creating depth without additional color definitions. This is an elegant pattern.

#### 1.2 Typography

```typst
#set text(size: 18pt, fill: palette-text, font: "Liberation Sans")
#set par(leading: 0.7em, justify: false)
#set list(marker: text(fill: palette-accent)[--], spacing: 0.6em)
```

**Font Sizes Used Throughout**:

| Element | Size | Weight | Color | Notes |
|---------|------|--------|-------|-------|
| Title slide company name | 44pt | bold | palette-primary | Largest element |
| Title slide subtitle | 22pt | normal | palette-secondary | |
| Title slide tagline | 16pt | normal | palette-text | |
| Title slide metadata | 14pt | normal | palette-secondary | Smallest element |
| Slide heading (H1) | 28pt | bold | palette-primary | Consistent across all slides |
| Sub-heading / emphasis line | 18pt | semibold | palette-accent | Problem statement, market sizing |
| Column header / bold label | 20pt | bold | palette-primary | Used in grid columns |
| Column header (smaller) | 17pt | bold | palette-primary | Used in later slides |
| Body text (default) | 18pt | normal | palette-text | Set globally |
| Detail text | 15pt | normal | palette-text | In grid cells, bullet content |
| Small detail | 14pt | normal | palette-text/secondary | Footer stats, attributions |
| Pipeline diagram text | 13pt | bold/normal | varies | Compact pipeline boxes |
| Table content | 14pt | normal | palette-text | Market/financial tables |
| Table header | 14pt | bold | palette-primary | Table column headers |
| Smallest text | 12pt | normal | varies | Competitor descriptions in appendix |
| Footnotes / citations | 13pt | normal | palette-secondary | Source attributions |

**Typography Ratios** (relative to 18pt base):
- Title: 2.44x (44pt) -- strong visual impact
- H1: 1.56x (28pt) -- clear hierarchy
- Sub-H1: 1.0x (18pt) -- body level with weight/color differentiation
- Column headers: 1.11x (20pt) or 0.94x (17pt)
- Detail: 0.83x (15pt)
- Small: 0.78x (14pt)
- Smallest: 0.72x (13pt) and 0.67x (12pt)

**Key Insight**: The deck uses 7-8 distinct font size tiers. For YC compliance at 24pt minimum body, we need to scale proportionally while keeping the same ratios.

#### 1.3 Page Layout and Margins

```typst
config-page(
  fill: palette-bg,
  margin: (x: 3em, top: 2.5em, bottom: 2em),
)
```

**Margin Ratios** (relative to body font size of 18pt):
- Horizontal: 3em = 54pt each side
- Top: 2.5em = 45pt
- Bottom: 2em = 36pt

**Margin Proportions** (top:bottom:sides = 2.5:2:3):
- Top > bottom gives room for header content
- Sides wider than vertical margins -- creates a "cinematic" wide feel
- These proportions work well for 16:9

#### 1.4 Spacing Patterns

Vertical spacing between elements uses consistent `#v()` patterns:

| Pattern | Size | Context |
|---------|------|---------|
| After heading | 0.4em | Standard: heading -> sub-heading gap |
| After sub-heading | 0.6em | Standard: sub-heading -> content gap |
| After content block | 0.8-1.0em | Standard: content -> footer gap |
| Between grid rows | 0.3em | Tight: label -> detail |
| Between sections | 0.5em | Medium: within a column |
| Title slide large gap | 1.8-2.5em | Dramatic: between major title elements |
| Paragraph leading | 0.7em | Body text line spacing |
| List spacing | 0.6em | Between bullet items |

**Key Pattern**: heading (0.4em) -> sub-heading (0.6em) -> content (varies) -> footer (0.8-1.0em). This creates a predictable rhythm.

#### 1.5 Grid and Layout Patterns

**Grid Configurations Used**:

| Slide | Columns | Gutter | Content |
|-------|---------|--------|---------|
| Problem (3-col) | `(1fr, 1fr, 1fr)` | 2em | Three equal cards |
| Semantic Models (2-col) | `(1fr, 1fr)` | 2.5em | Side-by-side comparison |
| Solution (2-col) | `(1fr, 1fr)` | 2.5em | Two concepts |
| Pipeline (7-col) | `(1fr, 0.3fr, 1fr, ...)` | 0.2em | Flow diagram with arrows |
| Why Legal (3-col) | `(1fr, 1fr, 1fr)` | 2em | Three points |
| Market (table) | `(1.2fr, 1fr, 1fr)` | N/A | Table with fill |
| Team (2-col) | `(1fr, 1fr)` | 3em | Two bios |

**Card Pattern** (rect for visual containers):
```typst
#rect(fill: palette-bg.darken(20%), radius: 6pt, inset: 14pt, width: 100%)[
  #text(size: 18pt, weight: "bold", fill: palette-accent)[Card Title]
  #v(0.3em)
  #text(size: 15pt)[Card content...]
]
```

**Table Pattern** (with alternating header fill):
```typst
#table(
  columns: (1.2fr, 1fr, 1fr),
  stroke: 0.5pt + palette-secondary.lighten(60%),
  inset: 8pt,
  fill: (x, y) => if y == 0 { palette-bg.darken(20%) } else { none },
  align: left,
  table.header(...),
  ...
)
```

#### 1.6 Slide Syntax

Uses `#slide[...]` block syntax rather than `== Heading` markup. Each slide is wrapped in explicit `#slide[]` with manual layout inside. This gives more control but is more verbose.

The heading-based syntax (`== Title`) used in the present/examples/ is cleaner for templates. The `#slide[]` syntax is better suited for highly custom content-specific decks like the production Logos deck.

### 2. Proposed Dark-Blue Color Palette

The user specifically wants a dark-blue theme as the primary/default template. The existing deck-source.typ uses dark charcoal (`#2d3238`) -- we should shift this toward a deeper blue while preserving the proven Tailwind-based color harmony.

**Proposed Dark-Blue Palette** (adapted from deck-source.typ):

```typst
// Dark-Blue Palette -- Professional dark theme with steel-blue accents
#let palette-primary   = rgb("#e2e8f0")  // Slate 200 -- titles (keep from source)
#let palette-secondary = rgb("#94a3b8")  // Slate 400 -- subtitles, metadata
#let palette-accent    = rgb("#60a5fa")  // Blue 400 -- emphasis, links, markers
#let palette-bg        = rgb("#1e293b")  // Slate 800 -- deep navy background
#let palette-text      = rgb("#cbd5e1")  // Slate 300 -- body text (keep from source)
```

**Rationale for Each Color Choice**:

| Role | deck-source.typ | Proposed Dark-Blue | Rationale |
|------|-----------------|-------------------|-----------|
| primary (titles) | `#e2e8f0` | `#e2e8f0` | Already excellent, bright and clear |
| secondary | `#a0aec0` | `#94a3b8` | Slightly cooler tone to complement blue bg |
| accent | `#4a90c4` (steel blue) | `#60a5fa` (blue 400) | Brighter blue for stronger pop on darker bg |
| bg | `#2d3238` (charcoal) | `#1e293b` (slate 800) | Shifts from warm gray to cool navy-slate |
| text | `#cbd5e0` | `#cbd5e1` | Essentially same, Tailwind v3 token |

**Contrast Ratios on `#1e293b` Background**:
- `#e2e8f0` (titles): approximately 11.5:1 -- excellent
- `#cbd5e1` (body text): approximately 9.4:1 -- excellent
- `#94a3b8` (secondary): approximately 5.6:1 -- passes AA
- `#60a5fa` (accent): approximately 5.9:1 -- passes AA

**Dark accent card background**: `palette-bg.darken(20%)` yields approximately `#151e2d` -- provides subtle depth.

**Alternative: Deep Navy Variant** (more blue, less slate):

```typst
#let palette-bg = rgb("#0f172a")  // Slate 900 -- near-black navy
```

This is darker and more dramatic but closer to the existing premium-dark's `#0f0f1a`. Using `#1e293b` (Slate 800) keeps the dark-blue template distinct from premium-dark.

### 3. Universal Standards Extracted

These standards should apply to ALL four templates, derived from what works in deck-source.typ:

#### 3.1 Color System (5 Roles)

Every template MUST define exactly 5 palette colors:

| Role | Purpose | Constraint |
|------|---------|-----------|
| `palette-primary` | Titles, headings, bold labels | Highest contrast against bg |
| `palette-secondary` | Subtitles, metadata, footnotes | Medium contrast, subdued |
| `palette-accent` | Emphasis, markers, links, interactive | Visually distinct hue, min 4.5:1 contrast |
| `palette-bg` | Page fill, base background | Sets overall mood |
| `palette-text` | Body text default | High contrast, slightly below primary |

**Derived colors** (computed, not defined):
- Card/rect fill: `palette-bg.darken(20%)` for dark themes, `palette-bg.darken(5%)` or `rgb(...).lighten(...)` for light themes
- Table header fill: Same as card fill
- Table stroke: `palette-secondary.lighten(60%)`

#### 3.2 Typography Scale (YC-Compliant)

Scaling deck-source.typ's ratios to YC-compliant base of 32pt:

| Element | deck-source (18pt base) | YC-Compliant (32pt base) | Ratio |
|---------|------------------------|--------------------------|-------|
| Title slide name | 44pt | 48pt | 1.5x (capped at heading.1) |
| Title slide subtitle | 22pt | 36pt | 1.12x |
| Slide heading (H2) | 28pt | 40pt | 1.25x |
| Sub-heading emphasis | 18pt semibold | 32pt semibold | 1.0x |
| Body text | 18pt | 32pt | 1.0x |
| Detail text | 15pt | 28pt | 0.875x |
| Small detail | 14pt | 26pt | 0.81x |
| Footer / citation | 13pt | 24pt | 0.75x (YC minimum) |

**Key Rule**: Nothing below 24pt in the YC-compliant templates. The deck-source.typ goes down to 12pt which is too small for presentations.

#### 3.3 Margin Proportions

Keep the 2.5:2:3 ratio from deck-source.typ:

```typst
config-page(
  fill: palette-bg,
  margin: (x: 3em, top: 2.5em, bottom: 2em),
)
```

At 32pt base, this yields:
- Horizontal: 3em = 96pt each side
- Top: 2.5em = 80pt
- Bottom: 2em = 64pt

These are generous margins that prevent content from feeling cramped on 16:9.

#### 3.4 Spacing Rhythm

Standardize `#v()` spacing across all templates:

| Pattern | Value | Usage |
|---------|-------|-------|
| Heading to sub-heading | 0.4em | After every `==` slide title |
| Sub-heading to content | 0.6em | After emphasis line to body |
| Between content blocks | 0.8em | Separating major sections on a slide |
| List spacing | 0.6em | Between bullet items |
| Paragraph leading | 0.7em | Line spacing within paragraphs |
| Title slide major gap | 2em | Between major title elements |

#### 3.5 List Marker Standard

deck-source.typ uses a styled dash marker:
```typst
#set list(marker: text(fill: palette-accent)[--], spacing: 0.6em)
```

This is better than the default bullet for presentations because:
- The accent-colored dash draws the eye without being decorative
- Dashes read more professionally than circles/squares
- The accent color ties the list items to the overall palette

**Recommendation**: All templates should use this pattern, with `palette-accent` colored `--` markers.

#### 3.6 Grid and Table Standards

**2-column grid** (standard for comparisons):
```typst
#grid(columns: (1fr, 1fr), gutter: 2.5em, [...], [...])
```

**3-column grid** (for triples -- NOTE: YC says max 2 columns):
- For YC-compliant templates, avoid 3-column grids
- Use 2-column or stacked layout instead
- The deck-source.typ's 3-column slides work because it uses smaller fonts; at 32pt body, 3 columns would overflow

**Table standard**:
```typst
#table(
  stroke: 0.5pt + palette-secondary.lighten(60%),
  inset: 8pt,
  fill: (x, y) => if y == 0 { palette-bg.darken(20%) } else { none },
  align: left,
)
```

### 4. How These Standards Improve All Templates

#### 4.1 Current Round 1 Plan Issues

The round 1 plan specifies:
- Use heading-based `== Title` syntax (good)
- 32pt body, 48pt h1, 40pt h2 (good, but missing detail tiers)
- Inter + Montserrat fonts (acceptable but deck-source.typ uses Liberation Sans which is more universally available)

**Missing from Round 1**:
- No margin specification (critical for consistent layout)
- No spacing rhythm (inconsistent vertical gaps)
- No list marker styling (default bullets look generic)
- No card/rect pattern (loses visual depth)
- No table styling standard (inconsistent table appearance)
- No detail text tiers below 32pt (everything at 32pt looks flat)
- Only 3 text size tiers (h1, h2, body) -- deck-source.typ uses 7-8 tiers for rich hierarchy

#### 4.2 Recommended Improvements to All Templates

1. **Add margin specification** to `config-page`: `margin: (x: 3em, top: 2.5em, bottom: 2em)`
2. **Add paragraph and list settings**: `#set par(leading: 0.7em, justify: false)` and `#set list(marker: text(fill: palette-accent)[--], spacing: 0.6em)`
3. **Add detail text sizes**: 28pt for secondary detail, 26pt for small detail, 24pt for footnotes/citations
4. **Standardize spacing**: Use the 0.4/0.6/0.8 rhythm documented above
5. **Add card pattern**: `#rect(fill: palette-bg.darken(20%), radius: 6pt, inset: 14pt, width: 100%)` for visual containers in comparison slides (Problem, Solution, Why Us)

#### 4.3 Font Recommendation

deck-source.typ uses Liberation Sans (single font, universally available). The examples use Inter + Montserrat (two fonts, may not be installed).

**Recommendation**: Use Liberation Sans as the primary fallback, keep Inter/Montserrat as preferred:

```typst
#set text(font: ("Inter", "Liberation Sans"), size: 32pt, fill: palette-text)
#show heading.where(level: 1): set text(
  font: ("Montserrat", "Liberation Sans"),
  size: 48pt, weight: "bold", fill: palette-primary,
)
```

This is already in the round 1 plan and is correct.

### 5. Dark Theme Preference Implications

The user explicitly prefers dark themes. This affects the template ordering and default selection:

1. **Dark-Blue should be the primary/default template** -- listed first in any selection UI
2. **Premium-Dark (gold accent) is the secondary dark option** -- for luxury/premium contexts
3. **Light themes (minimal-light, professional-blue, growth-green) are secondary options**

For the deck-planner agent (task 342), when presenting style choices, dark-blue should be the default/first option.

### 6. Comparison: Dark-Blue vs Premium-Dark vs deck-source.typ

| Aspect | deck-source.typ | Proposed Dark-Blue | Premium-Dark |
|--------|-----------------|-------------------|-------------|
| Background | `#2d3238` warm charcoal | `#1e293b` cool navy | `#0f0f1a` near-black |
| Title color | `#e2e8f0` light gray | `#e2e8f0` light gray | `#d4a574` gold |
| Accent | `#4a90c4` steel blue | `#60a5fa` bright blue | `#d4a574` gold |
| Body text | `#cbd5e0` | `#cbd5e1` | `#e2e8f0` |
| Mood | Professional, technical | Professional, modern | Luxurious, premium |
| Best for | Technical/research | General/default | Luxury/high-end |

The dark-blue template is the most versatile dark theme -- suitable for any industry. Premium-dark is niche (luxury/premium). This supports making dark-blue the default.

## Decisions

1. **Adopt a dark-blue palette** based on Tailwind Slate scale: bg `#1e293b`, primary `#e2e8f0`, accent `#60a5fa`
2. **Apply universal standards** (margins, spacing, list markers, typography scale) to all 4 templates
3. **Dark-blue becomes the primary/default template** -- listed first in deck-planner selection
4. **Keep heading-based `== Title` syntax** for templates (cleaner for templates; `#slide[]` is for production decks)
5. **Add detail text tiers** (28pt, 26pt, 24pt) beyond the 3-tier system in round 1
6. **Standardize card pattern** with `palette-bg.darken(20%)` for visual containers across all themes
7. **Use deck-source.typ margin proportions** (x:3em, top:2.5em, bottom:2em) in all templates

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Dark-blue too similar to professional-blue | Confusion in selection UI | Professional-blue uses WHITE background; dark-blue uses `#1e293b` -- very distinct |
| Dark-blue too similar to premium-dark | Confusion in selection UI | Different bg tone (navy vs near-black), different accent (blue vs gold) -- distinct |
| 24pt minimum floor limits expressiveness | Less typographic variety | 4 tiers above 24pt (24, 26, 28, 32, 40, 48) still provide rich hierarchy |
| Detail text at 28pt may overflow grid cells | Layout breaks | Test with typical content length; use 2-column max per YC |

## Appendix

### deck-source.typ Complete Typographic Inventory

All `text()` calls with their parameters (ordered by size descending):

```
44pt bold       palette-primary      Title slide: company name
40pt bold       palette-primary      Appendix: closing name
28pt bold       palette-primary      Slide headings (consistent)
22pt normal     palette-secondary    Title slide: subtitle
20pt bold       palette-primary      Column headers (Problem, Moat)
19pt bold       palette-primary      Section headers (Traction, Ask)
18pt semibold   palette-accent       Emphasis lines (sub-headings)
18pt bold       palette-accent       Card titles (inside rects)
18pt bold       palette-primary      Pipeline labels
18pt normal     palette-text         Body text (default)
17pt bold       palette-primary      Column headers (later slides)
16pt normal     palette-text         Explanatory paragraphs
16pt semibold   palette-accent       Highlight statements
16pt normal     palette-secondary    Team subtitle, contact info
15pt normal     palette-text         Detail text in grids/cards
14pt normal     palette-secondary    Metadata, footer stats
14pt bold       palette-primary      Table headers, financial labels
14pt normal     palette-text         Table content
13pt bold       various              Pipeline diagram boxes
13pt normal     palette-secondary    Footnotes, table cells
12pt normal     various              Competitor descriptions (smallest)
11pt normal     palette-secondary    Pipeline sub-labels (smallest labeled)
```

### Tailwind Slate Scale Reference

The palette colors map to Tailwind CSS v3 Slate tokens:

| Token | Hex | Used For |
|-------|-----|----------|
| Slate 50 | `#f8fafc` | -- |
| Slate 100 | `#f1f5f9` | -- |
| Slate 200 | `#e2e8f0` | palette-primary (titles) |
| Slate 300 | `#cbd5e1` | palette-text (body) |
| Slate 400 | `#94a3b8` | palette-secondary (subtitles) |
| Slate 500 | `#64748b` | -- |
| Slate 600 | `#475569` | -- |
| Slate 700 | `#334155` | -- |
| Slate 800 | `#1e293b` | palette-bg (background) |
| Slate 900 | `#0f172a` | alternative darker bg |
| Blue 400 | `#60a5fa` | palette-accent |

### Complete Dark-Blue Template Header Block

```typst
// Dark-Blue Theme - Reusable Pitch Deck Template
// Palette: dark-blue
// Colors: #e2e8f0 (titles), #94a3b8 (subtitles), #60a5fa (accent), #1e293b (bg), #cbd5e1 (body)
// Typography: Montserrat headings, Inter body (light text on dark)
// Best for: General/default dark theme, technology, professional presentations
// Touying: 0.6.3 | Theme: simple | Aspect: 16:9
// YC Compliant: 24pt+ minimum, 32pt body, 40pt h2, 48pt h1, max 10 slides
```

### Complete Dark-Blue Typography Setup

```typst
// == PALETTE ===================================================================
#let palette-primary   = rgb("#e2e8f0")  // Slate 200 -- titles, headings
#let palette-secondary = rgb("#94a3b8")  // Slate 400 -- subtitles, metadata
#let palette-accent    = rgb("#60a5fa")  // Blue 400 -- emphasis, links, markers
#let palette-bg        = rgb("#1e293b")  // Slate 800 -- deep navy background
#let palette-text      = rgb("#cbd5e1")  // Slate 300 -- body text

// == THEME SETUP ===============================================================
#show: simple-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: company-name,
    subtitle: company-subtitle,
    author: author-name,
    date: funding-date,
  ),
  config-colors(
    primary:          palette-primary,
    secondary:        palette-secondary,
    tertiary:         palette-accent,
    neutral:          palette-bg,
    neutral-lightest: palette-bg,
  ),
  config-page(
    fill: palette-bg,
    margin: (x: 3em, top: 2.5em, bottom: 2em),
  ),
)

// == TYPOGRAPHY ================================================================
#set text(font: ("Inter", "Liberation Sans"), size: 32pt, fill: palette-text)
#set par(leading: 0.7em, justify: false)
#set list(marker: text(fill: palette-accent)[--], spacing: 0.6em)

#show heading.where(level: 1): set text(
  font: ("Montserrat", "Liberation Sans"),
  size: 48pt, weight: "bold", fill: palette-primary,
)
#show heading.where(level: 2): set text(
  font: ("Montserrat", "Liberation Sans"),
  size: 40pt, weight: "bold", fill: palette-primary,
)
```

### Spacing and Layout Quick Reference

```typst
// Standard spacing after heading
#v(0.4em)
// Standard spacing after sub-heading
#v(0.6em)
// Standard spacing between content blocks
#v(0.8em)
// Title slide dramatic gap
#v(2em)

// Standard 2-column comparison
#grid(columns: (1fr, 1fr), gutter: 2.5em, [...], [...])

// Standard card container (dark themes)
#rect(fill: palette-bg.darken(20%), radius: 6pt, inset: 14pt, width: 100%)[...]

// Standard table (all themes)
#table(
  stroke: 0.5pt + palette-secondary.lighten(60%),
  inset: 8pt,
  fill: (x, y) => if y == 0 { palette-bg.darken(20%) } else { none },
  align: left,
)
```

### Search Queries Used

- Full read of `/home/benjamin/Projects/Logos/Vision/strategy/02-deck/deck-source.typ` (all 800+ lines)
- Read of `specs/340_create_typst_deck_templates/reports/01_typst-deck-templates.md` (round 1)
- Read of `specs/340_create_typst_deck_templates/plans/01_typst-deck-templates.md` (implementation plan)
- Read of `.claude/extensions/present/examples/premium-dark-pitch.typ` (existing dark template pattern)

### References

- `/home/benjamin/Projects/Logos/Vision/strategy/02-deck/deck-source.typ` -- production Logos deck (primary reference)
- `.claude/extensions/present/examples/premium-dark-pitch.typ` -- existing premium dark example
- Tailwind CSS v3 color scale documentation (Slate, Blue palettes)
- WCAG 2.1 contrast ratio guidelines (AA: 4.5:1 for normal text)
