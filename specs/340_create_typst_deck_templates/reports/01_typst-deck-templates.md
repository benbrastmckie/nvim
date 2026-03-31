# Research Report: Task #340

**Task**: 340 - Create reusable typst slide deck templates
**Started**: 2026-03-31T00:00:00Z
**Completed**: 2026-03-31T00:15:00Z
**Effort**: Medium
**Dependencies**: None
**Sources/Inputs**: Codebase exploration, existing deck-source.typ, present extension examples, founder extension templates, YC compliance docs
**Artifacts**: specs/340_create_typst_deck_templates/reports/01_typst-deck-templates.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Four complete example pitch decks already exist in `.claude/extensions/present/examples/` (minimal-light, professional-blue, premium-dark, growth-green) -- these are full 10-slide decks, not reusable templates
- The existing `deck-source.typ` at `/home/benjamin/Projects/Logos/Vision/strategy/02-deck/` uses touying 0.6.3 with the simple theme, minimal-light palette, and manual #slide[] syntax (not heading-based)
- Templates should be placed in `founder/context/project/founder/templates/typst/` alongside the existing `strategy-template.typ` (a document template, not a presentation template)
- Each template must be parameterizable (company name, content, palette colors) while being self-contained and compilable
- YC compliance requires: 24pt+ body text, 40pt+ titles, 16:9 aspect ratio, max 10 slides, max 5 bullets per slide, max 2 columns

## Context & Scope

Task 340 is the foundational task in a 5-task deck workflow integration (340-344). It provides the template files that the deck-planner (task 342) will reference during interactive style selection, and that the deck-builder (task 343) will use to generate final presentations. Templates must work independently of the agent system (compilable with `typst compile`) while also being structured for programmatic content insertion.

### Constraints

- Templates go in `founder/context/project/founder/templates/typst/` (founder extension owns deck workflow per task 344)
- Must use touying 0.6.3 (the version used throughout the project)
- Must comply with YC design principles (Legibility, Simplicity, Obviousness)
- Must be self-contained (no external imports beyond touying)
- Must be parameterizable for the deck-planner agent

## Findings

### Codebase Patterns

#### 1. Existing Example Decks (present/examples/)

Four complete example decks exist that demonstrate the four visual styles:

| File | Theme | Style | Mock Company |
|------|-------|-------|-------------|
| `minimal-light-pitch.typ` | simple | Charcoal/gray/blue on near-white | ClearView Analytics |
| `professional-blue-pitch.typ` | simple | Deep navy/medium blue/sky blue | SafeAI Labs |
| `premium-dark-pitch.typ` | simple | Dark charcoal/deep blue-black/gold on dark | NeuralShield |
| `growth-green-pitch.typ` | simple | Emerald/dark green/light green on mint | GreenPath Energy |

All four examples share a common structure:
- Import touying 0.6.3 with `themes.simple`
- Configure via `simple-theme.with()` with `aspect-ratio: "16-9"`, `config-info()`, `config-colors()`
- Set page fill for background color
- Set text font (Inter body, Montserrat headings) at 32pt base
- Override heading levels: level 1 at 48pt, level 2 at 40pt
- Define local color variables for use in content
- Use `== Slide Title` heading syntax (not `#slide[]`)
- Include `#speaker-note[...]` on every slide
- Follow 10-slide YC structure exactly

#### 2. Existing deck-source.typ (Production Deck)

The production Logos Laboratories deck uses a different approach:
- Uses `#slide[...]` block syntax (not heading-based)
- Uses 18pt body text (non-YC-compliant)
- Uses 3-column grids (non-YC-compliant)
- Uses decorative `#rect` elements (non-YC-compliant)
- Has more content-dense slides (research-focused, not typical startup)
- Defines palette colors at top as `#let` variables

Key insight: The production deck is content-specific to Logos and does NOT follow YC compliance. The templates should follow the cleaner pattern from the examples, not from deck-source.typ.

#### 3. Strategy Template Pattern (founder/templates/typst/)

The existing `strategy-template.typ` in the founder extension demonstrates the parameterizable template pattern:
- Defines a main function (`strategy-doc`) that accepts parameters (title, project, date, mode)
- Provides reusable component functions (callout, metric, comparison-block, etc.)
- Sets up page layout, typography, heading styles, table styles
- Uses a navy gradient palette with Libertinus Serif typography
- Is imported by other typst files as a library

This is the established pattern for founder templates. Deck templates should follow a similar approach: define a main function that sets up the presentation, with parameterizable colors, fonts, and metadata.

#### 4. Palette Color Definitions (from deck-agent.md)

The deck-agent already defines four palettes with exact color values:

| Palette | Primary | Secondary | Accent | Background | Text |
|---------|---------|-----------|--------|------------|------|
| minimal-light | #2d3748 | #4a5568 | #3182ce | #f7fafc | #1a202c |
| professional-blue | #1a365d | #2c5282 | #4299e1 | #ffffff | #1a202c |
| premium-dark | #1a1a2e | #16213e | #d4a574 | #0f0f1a | #e2e8f0 |
| growth-green | #047857 | #065f46 | #34d399 | #f0fdf4 | #1a202c |

#### 5. YC Compliance Requirements (from pitch-deck-structure.md, yc-compliance-checklist.md)

Hard limits that templates must enforce:
- **Slide count**: max 10 (excluding appendix)
- **Title font**: min 40pt
- **Body font**: min 24pt
- **Any element**: min 20pt absolute minimum
- **Bullets per slide**: max 5
- **Columns**: max 2
- **Contrast ratio**: 4.5:1 minimum
- **Animations**: none
- **Screenshots**: none

Slide structure (9+1):
1. Title -- company name + one-liner
2. Problem -- pain point
3. Solution -- how you solve it
4. Traction -- metrics/growth
5. Why Us / Why Now -- differentiation
6. Business Model -- revenue
7. Market Opportunity -- TAM/SAM/SOM
8. Team -- founders
9. The Ask -- funding amount + milestones
10. Closing -- contact + Q&A

### Recommendations

#### Template Architecture

**Option A: Function-based templates (like strategy-template.typ)**

Each template defines a `deck-template()` function that accepts parameters and configures the presentation. Other files import and use it.

```typst
// deck-minimal-light.typ
#let deck-minimal-light(
  title: "",
  subtitle: "",
  author: "",
  date: datetime.today(),
  doc,
) = {
  // Import and configure touying
  // Set colors, fonts, page
  doc
}
```

Pros: Clean separation, reusable, follows existing pattern
Cons: Touying's `#show:` pattern may not compose well with function wrapping

**Option B: Parameter-block templates (complete compilable files)**

Each template is a complete `.typ` file with `#let` parameter blocks at the top, placeholder content using `[TODO:]` markers, and all 10 slides pre-structured.

Pros: Self-contained, immediately compilable, easy to copy-and-modify
Cons: Less DRY, content mixed with configuration

**Option C: Hybrid -- shared base + per-style config**

A shared `deck-base.typ` defines the common structure (slide order, speaker note placeholders, typography rules). Per-style config files define only the palette and font overrides.

Pros: DRY, easy to add new styles
Cons: More complex, requires import chain

**Recommended: Option B (parameter-block templates)**

Rationale:
1. The deck-builder agent (task 343) will read the template and substitute content -- a complete file is easiest to process
2. Self-contained files are easiest to test (just `typst compile`)
3. The present/examples/ pattern already demonstrates this works well
4. The deck-planner (task 342) needs to present template options to users -- complete files with header comments are self-documenting
5. Touying's `#show:` theme pattern expects to wrap the entire document, making function composition difficult

#### Template Naming Convention

Place in `founder/context/project/founder/templates/typst/deck/`:
- `deck-minimal-light.typ`
- `deck-professional-blue.typ`
- `deck-premium-dark.typ`
- `deck-growth-green.typ`

Using a `deck/` subdirectory keeps them organized alongside existing strategy templates.

#### Template Structure (each file)

```
1. Header comment block (style name, colors, use case, typography)
2. Touying import
3. Parameterizable #let bindings (company, subtitle, author, palette colors)
4. Theme setup with config-info, config-colors, config-page
5. Typography settings (heading show rules, body text set)
6. 10 slide sections with:
   - Section comment separator
   - == heading
   - [TODO: ...] placeholder content following YC structure
   - #speaker-note[...] with presentation guidance
7. Optional appendix section template
```

#### Key Differences Between Templates

| Aspect | Minimal Light | Professional Blue | Premium Dark | Growth Green |
|--------|-------------|-------------------|-------------|-------------|
| Background | Near-white (#f7fafc) | White (#ffffff) | Dark (#0f0f1a) | Mint (#f0fdf4) |
| Text color | Dark (#1a202c) | Dark (#1a202c) | Light (#e2e8f0) | Dark (#1a202c) |
| Accent | Blue (#3182ce) | Sky blue (#4299e1) | Gold (#d4a574) | Light green (#34d399) |
| Headings | Charcoal | Deep navy | Gold on dark | Emerald |
| Best for | Data/analytics | Fintech/enterprise | Premium/luxury tech | Sustainability/health |
| Font | Inter + Montserrat | Inter + Montserrat | Inter + Montserrat | Inter + Montserrat |

#### Parameterization Strategy

Each template should have a clearly marked parameter section at the top:

```typst
// == PARAMETERS (modify these for your deck) ==================================
#let company-name = [Your Company Name]
#let company-subtitle = [One-line description of what you do]
#let author-name = [Founder Name]
#let funding-round = [Seed Round]
#let funding-date = datetime.today()
```

This allows the deck-builder agent to find and replace these values programmatically, while also allowing manual editing.

#### What Makes Templates "Self-Contained and Parameterizable"

Self-contained means:
- No imports beyond `@preview/touying:0.6.3`
- No reference to external files or images
- Compilable as-is with `typst compile template.typ`
- All colors, fonts, and layout defined within the file

Parameterizable means:
- Named `#let` bindings for all variable content
- Clear parameter section at top of file
- [TODO: ...] placeholders in content areas
- Speaker notes with guidance for content authors
- Comments documenting which sections the deck-builder agent should modify

## Decisions

1. **Use Option B (parameter-block templates)** -- complete compilable files, not function-based
2. **Place templates in `founder/context/project/founder/templates/typst/deck/`** -- new deck/ subdirectory
3. **Follow the present/examples/ pattern** (heading-based slides, not #slide[] blocks) as it is cleaner and YC-compliant
4. **Use the established 4-palette color scheme** from the deck-agent documentation
5. **Include appendix section template** (optional, after 10 main slides)
6. **All templates use Inter + Montserrat fonts** (consistent with existing examples)
7. **Do NOT copy patterns from deck-source.typ** -- it violates YC compliance (small fonts, 3-column grids, decorative rects)

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Touying API changes between versions | Templates break on update | Pin to 0.6.3, document version dependency |
| Font availability (Montserrat, Inter) | Compilation warnings or fallback fonts | Include font fallback chain in set text() |
| Templates too rigid for diverse startups | Deck-builder cannot customize enough | Use extensive [TODO:] placeholders, document customization points |
| Dark theme contrast issues | YC compliance failure on some projectors | Ensure 4.5:1 contrast ratio, test with gold-on-dark specifically |
| Template count mismatch with deck-agent palettes | Confusion in deck-planner | Create exactly 4 templates matching the 4 existing palettes |

## Appendix

### Search Queries Used
- Glob for `*founder*/**/*template*` in .claude/extensions
- Glob for `*deck*`, `*touying*`, `*pitch*`, `*yc*` in .claude/
- Read of deck-source.typ (production deck)
- Read of all four present/examples/ pitch decks
- Read of strategy-template.typ (founder template pattern)
- Read of pitch-deck-structure.md, touying-pitch-deck-template.md, yc-compliance-checklist.md
- Read of deck-agent.md, deck.md command
- Read of founder manifest.json
- Read of TODO.md tasks 340-344

### References
- `/home/benjamin/Projects/Logos/Vision/strategy/02-deck/deck-source.typ` -- existing production deck
- `.claude/extensions/present/examples/*.typ` -- four example pitch decks
- `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md` -- YC slide structure
- `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md` -- touying template patterns
- `.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md` -- compliance rules
- `.claude/extensions/present/agents/deck-agent.md` -- deck generation agent with palette definitions
- `.claude/extensions/founder/context/project/founder/templates/typst/strategy-template.typ` -- existing parameterizable template pattern
- `.claude/extensions/founder/manifest.json` -- founder extension structure

### File Inventory for Implementation

Files to create:
1. `founder/context/project/founder/templates/typst/deck/deck-minimal-light.typ`
2. `founder/context/project/founder/templates/typst/deck/deck-professional-blue.typ`
3. `founder/context/project/founder/templates/typst/deck/deck-premium-dark.typ`
4. `founder/context/project/founder/templates/typst/deck/deck-growth-green.typ`

All paths relative to `.claude/extensions/`.

### Template Skeleton Reference

Each template should follow this skeleton (actual content varies by palette):

```typst
// {Style Name} Theme - Reusable Pitch Deck Template
// Palette: {palette-name}
// Colors: {primary}, {secondary}, {accent}
// Typography: Montserrat headings, Inter body
// Best for: {use case description}
// Touying: 0.6.3 | Theme: simple | Aspect: 16:9
// YC Compliant: 24pt+ body, 40pt+ titles, max 10 slides, max 5 bullets

#import "@preview/touying:0.6.3": *
#import themes.simple: *

// == PARAMETERS ================================================================
#let company-name = [Your Company Name]
#let company-subtitle = [One-line description of what you do]
#let author-name = [Founder Name]
#let funding-round = [Seed Round]
#let funding-date = datetime.today()

// == PALETTE ===================================================================
#let palette-primary = rgb("{primary}")
#let palette-secondary = rgb("{secondary}")
#let palette-accent = rgb("{accent}")
#let palette-bg = rgb("{background}")
#let palette-text = rgb("{text}")

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
    primary: palette-primary,
    secondary: palette-secondary,
    neutral: palette-bg,
  ),
)

// == TYPOGRAPHY ================================================================
#set page(fill: palette-bg)
#set text(font: ("Inter", "Liberation Sans"), size: 32pt, fill: palette-text)
#show heading.where(level: 1): set text(
  font: ("Montserrat", "Liberation Sans"),
  size: 48pt, weight: "bold", fill: palette-primary,
)
#show heading.where(level: 2): set text(
  font: ("Montserrat", "Liberation Sans"),
  size: 40pt, weight: "bold", fill: palette-primary,
)

// ==============================================================================
// SLIDE 1: Title
// ==============================================================================
= #company-name
// ... [TODO:] content with speaker notes ...

// ... slides 2-10 ...

// ==============================================================================
// APPENDIX (optional -- add slides below as needed)
// ==============================================================================
```
