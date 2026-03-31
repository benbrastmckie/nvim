# Implementation Plan: Task #340 (Revised)

- **Task**: 340 - Create reusable typst slide deck templates
- **Status**: [COMPLETED]
- **Effort**: 3.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/340_create_typst_deck_templates/reports/01_typst-deck-templates.md, specs/340_create_typst_deck_templates/reports/02_dark-blue-template-standards.md
- **Artifacts**: plans/02_typst-deck-templates.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create four reusable, self-contained typst pitch deck templates in the founder extension, starting with a dark-blue primary template (user preference) that incorporates universal standards extracted from the production deck-source.typ. Each template uses touying 0.6.3 with the simple theme, heading-based slide syntax, YC-compliant typography (32pt body, 48pt h1, 40pt h2, nothing below 24pt), standardized margins (x:3em, top:2.5em, bottom:2em), accent-colored list markers, and a consistent 5-role color palette. This revised plan reorders Phase 1 to dark-blue (replacing minimal-light) and adds universal standards (margins, spacing rhythm, card pattern, detail text tiers) that were missing from the round 1 plan.

### Research Integration

Round 1 research established the template architecture (Option B: parameter-block templates), directory structure, 4-palette scheme, and YC compliance requirements. Round 2 research deep-analyzed deck-source.typ to extract universal standards: margin proportions (2.5:2:3), spacing rhythm (0.4/0.6/0.8em), accent-colored list markers, card/rect pattern with `palette-bg.darken(20%)`, and a richer typography scale with detail tiers (28pt, 26pt, 24pt). Round 2 also proposed the dark-blue palette (Tailwind Slate 800 bg `#1e293b`, Blue 400 accent `#60a5fa`) as the primary default template, distinct from both premium-dark and the production deck's charcoal.

## Goals & Non-Goals

**Goals**:
- Create 4 self-contained, compilable typst deck templates with dark-blue as the primary/default
- Apply universal standards (margins, spacing, list markers, card pattern, typography scale) to all templates
- Enforce YC compliance: 24pt minimum, 32pt body, 40pt h2, 48pt h1, 16:9, max 10 slides
- Make templates parameterizable with clearly marked `#let` bindings for deck-builder consumption
- Include `[TODO:]` placeholder content and `#speaker-note[]` guidance on every slide
- Include detail text tiers (28pt, 26pt, 24pt) for rich typographic hierarchy

**Non-Goals**:
- Creating a shared base/utility library (research recommends self-contained files)
- Supporting themes other than touying's `simple` theme
- Including actual company content (templates are generic with placeholders)
- Building the deck-planner or deck-builder agents (tasks 342-343)
- Replicating deck-source.typ's `#slide[]` block syntax (templates use heading-based `== Title`)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Font unavailability (Montserrat, Inter) | Compilation warnings, fallback fonts | M | Include Liberation Sans fallback in all font lists |
| Dark theme contrast below 4.5:1 | YC compliance failure | L | All dark palette colors pre-validated against WCAG AA (round 2 research) |
| 24pt minimum floor limits expressiveness | Less typographic variety | L | 6 tiers above 24pt (24, 26, 28, 32, 40, 48) provide rich hierarchy |
| Detail text at 28pt may overflow 2-column grids | Layout breaks | M | Test with typical content; enforce max 2 columns per YC |
| Templates too rigid for deck-builder | Insufficient customization | M | Extensive `[TODO:]` markers and comment annotations at every content insertion point |
| Dark-blue too similar to professional-blue | Confusion in selection | L | professional-blue uses WHITE bg; dark-blue uses `#1e293b` -- completely distinct |

## Implementation Phases

### Phase 1: Create deck directory and dark-blue template (primary) [COMPLETED]

**Goal**: Establish the template directory and create the dark-blue template as the primary/default reference template. This template incorporates all universal standards from round 2 research and serves as the reference for all subsequent templates.

**Tasks**:
- [ ] Create directory `.claude/extensions/founder/context/project/founder/templates/typst/deck/`
- [ ] Create `deck-dark-blue.typ` with complete structure:
  - Header comment block: dark-blue palette, general/default use case, touying 0.6.3, YC compliant
  - Touying 0.6.3 import with `themes.simple`
  - Parameter section: company-name, company-subtitle, author-name, funding-round, funding-date
  - Palette section (Tailwind Slate/Blue):
    - primary: `#e2e8f0` (Slate 200 -- titles)
    - secondary: `#94a3b8` (Slate 400 -- subtitles, metadata)
    - accent: `#60a5fa` (Blue 400 -- emphasis, links, markers)
    - bg: `#1e293b` (Slate 800 -- deep navy background)
    - text: `#cbd5e1` (Slate 300 -- body text)
  - Theme setup: `simple-theme.with()` with aspect-ratio "16-9", config-info, config-colors (including tertiary, neutral, neutral-lightest)
  - Page config with margins: `config-page(fill: palette-bg, margin: (x: 3em, top: 2.5em, bottom: 2em))`
  - Typography setup:
    - Body: `#set text(font: ("Inter", "Liberation Sans"), size: 32pt, fill: palette-text)`
    - Paragraph: `#set par(leading: 0.7em, justify: false)`
    - List markers: `#set list(marker: text(fill: palette-accent)[--], spacing: 0.6em)`
    - Heading level 1: 48pt bold Montserrat, palette-primary
    - Heading level 2: 40pt bold Montserrat, palette-primary
  - Comment documenting detail text sizes for use in slide content: 28pt (detail), 26pt (small), 24pt (footnote/citation)
  - Comment documenting spacing rhythm: 0.4em (after heading), 0.6em (after sub-heading), 0.8em (between blocks)
  - Comment documenting card pattern: `#rect(fill: palette-bg.darken(20%), radius: 6pt, inset: 14pt, width: 100%)`
  - Comment documenting table pattern: stroke, inset, fill, align settings
  - 10 slides with `== Heading` syntax:
    1. Title (company name centered, subtitle, tagline, metadata)
    2. Problem (pain point with emphasis line)
    3. Solution (how you solve it)
    4. Traction (metrics/growth)
    5. Why Us / Why Now (differentiation)
    6. Business Model (revenue)
    7. Market Opportunity (TAM/SAM/SOM)
    8. Team (founders)
    9. The Ask (funding + milestones)
    10. Closing (contact + Q&A)
  - `[TODO:]` placeholder content in every slide body
  - `#speaker-note[]` with presentation guidance on every slide
  - Appendix section template
- [ ] Verify template compiles with `typst compile` (if typst CLI available)

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-dark-blue.typ` - CREATE new file

**Verification**:
- File exists and is non-empty
- Contains all 10 slide sections (Title through Closing) plus appendix
- Contains parameter section with 5 `#let` bindings
- Contains palette section with 5 color definitions matching round 2 research values
- Contains margin specification `(x: 3em, top: 2.5em, bottom: 2em)`
- Contains `#set par(leading: 0.7em, justify: false)` and `#set list(marker: ...)`
- Font sizes are YC-compliant: 32pt body, 48pt h1, 40pt h2
- Compiles without errors (if typst CLI available)

---

### Phase 2: Create minimal-light template [COMPLETED]

**Goal**: Create the minimal-light template for data/analytics startups, adapting the dark-blue template structure with a light color scheme. All universal standards (margins, spacing, list markers) carry over.

**Tasks**:
- [ ] Create `deck-minimal-light.typ` adapting the dark-blue structure with:
  - Header comment: minimal-light palette, data/analytics use case
  - Palette:
    - primary: `#2d3748` (dark charcoal -- titles on light bg)
    - secondary: `#4a5568` (medium gray -- subtitles)
    - accent: `#3182ce` (blue -- emphasis, markers)
    - bg: `#f7fafc` (near-white -- page background)
    - text: `#1a202c` (near-black -- body text)
  - Same margins, spacing, list markers, typography as dark-blue
  - Card pattern adapted for light theme: `palette-bg.darken(5%)` instead of `darken(20%)`
  - Table stroke adapted: `palette-secondary.lighten(40%)` for lighter appearance
  - Same 10-slide structure with `[TODO:]` placeholders and `#speaker-note[]`
  - Speaker notes reflecting clean/analytical presentation tone
- [ ] Verify template compiles

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-minimal-light.typ` - CREATE new file

**Verification**:
- File exists with correct light palette colors
- Background is near-white (`#f7fafc`)
- Text fill is dark (`#1a202c`)
- All 10 slides present with analytical tone speaker notes
- Universal standards applied (margins, spacing, list markers)
- Compiles without errors

---

### Phase 3: Create premium-dark template [COMPLETED]

**Goal**: Create the premium-dark template with gold-on-dark styling for luxury/premium tech startups. Extra attention to contrast since headings use gold accent rather than primary (which would be too close to bg on this palette).

**Tasks**:
- [ ] Create `deck-premium-dark.typ` with:
  - Header comment: premium-dark palette, luxury/premium tech use case
  - Palette:
    - primary: `#1a1a2e` (deep purple-navy -- used for config-colors, NOT for heading fill)
    - secondary: `#16213e` (dark blue -- config-colors secondary)
    - accent: `#d4a574` (gold -- emphasis, markers, AND heading fill on this theme)
    - bg: `#0f0f1a` (near-black -- page background)
    - text: `#e2e8f0` (light gray -- body text)
  - Heading show rules override: use `palette-accent` (gold) for heading fill instead of `palette-primary`
  - List markers: gold-colored `--` using `palette-accent`
  - Card pattern: `palette-bg.darken(20%)` yields approximately `#0a0a12`
  - Same margins, spacing, typography scale as dark-blue
  - Same 10-slide structure
  - Speaker notes reflecting premium/luxury presentation context
- [ ] Verify contrast: `#e2e8f0` text on `#0f0f1a` bg (should exceed 4.5:1)
- [ ] Verify contrast: `#d4a574` gold on `#0f0f1a` bg (should exceed 4.5:1)
- [ ] Verify template compiles

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-premium-dark.typ` - CREATE new file

**Verification**:
- File exists with correct dark palette
- Heading fill uses accent `#d4a574` (gold) for visibility on near-black bg
- Text fill is light `#e2e8f0`
- All 10 slides present with premium tone speaker notes
- Universal standards applied
- Compiles without errors

---

### Phase 4: Create growth-green template [COMPLETED]

**Goal**: Create the growth-green template with emerald tones for sustainability, health, and climate tech startups.

**Tasks**:
- [ ] Create `deck-growth-green.typ` with:
  - Header comment: growth-green palette, sustainability/health/climate use case
  - Palette:
    - primary: `#047857` (emerald -- titles on light bg)
    - secondary: `#065f46` (dark green -- subtitles)
    - accent: `#34d399` (light green -- emphasis, markers)
    - bg: `#f0fdf4` (mint -- page background)
    - text: `#1a202c` (near-black -- body text)
  - Card pattern adapted for light theme: `palette-bg.darken(5%)`
  - Same margins, spacing, list markers, typography as other templates
  - Same 10-slide structure
  - Speaker notes reflecting sustainability/impact context
- [ ] Verify template compiles

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-growth-green.typ` - CREATE new file

**Verification**:
- File exists with correct green palette
- Background is mint (`#f0fdf4`)
- All 10 slides present with sustainability tone speaker notes
- Universal standards applied
- Compiles without errors

---

### Phase 5: Create professional-blue template and cross-template validation [COMPLETED]

**Goal**: Create the final template (professional-blue) and validate consistency across all 4 templates. This phase combines template creation with the validation pass since professional-blue is structurally similar to minimal-light.

**Tasks**:
- [ ] Create `deck-professional-blue.typ` with:
  - Header comment: professional-blue palette, fintech/enterprise use case
  - Palette:
    - primary: `#1a365d` (deep navy -- titles on white bg)
    - secondary: `#2c5282` (medium blue -- subtitles)
    - accent: `#4299e1` (sky blue -- emphasis, markers)
    - bg: `#ffffff` (white -- page background)
    - text: `#1a202c` (near-black -- body text)
  - Card pattern for light theme: `palette-bg.darken(5%)`
  - Same margins, spacing, list markers, typography
  - Same 10-slide structure
  - Speaker notes reflecting professional/enterprise tone
- [ ] Verify template compiles
- [ ] Cross-template validation:
  - All 4 templates have identical structure (same slide order, same parameter names, same section comments)
  - All parameter sections use same `#let` binding names (company-name, company-subtitle, author-name, funding-round, funding-date)
  - All templates have `[TODO:]` markers in content areas
  - All templates have matching margin specifications
  - All templates have matching `#set par(...)` and `#set list(...)` directives
  - All templates have identical font size settings (32pt body, 48pt h1, 40pt h2)
  - All templates use `@preview/touying:0.6.3` import
  - Each template has `#speaker-note[]` on every slide
  - Header comment blocks document palette name, colors, use case, touying version
- [ ] Compile all 4 templates to confirm no syntax errors (if typst available)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-professional-blue.typ` - CREATE new file
- Review all 4 deck templates for consistency (no modifications expected)

**Verification**:
- All 5 files exist in `deck/` directory (4 templates)
- Parameter names identical across all templates
- Font size settings identical across all templates
- Margin settings identical across all templates
- List marker and paragraph settings identical across all templates
- All templates compile successfully

## Testing & Validation

- [ ] All 4 template files exist in `.claude/extensions/founder/context/project/founder/templates/typst/deck/`
- [ ] Each template contains exactly 10 main slide sections plus appendix
- [ ] Each template has a clearly marked PARAMETERS section with 5 `#let` bindings
- [ ] Each template has a PALETTE section with 5 color definitions
- [ ] Font sizes are YC-compliant: 32pt body, 48pt h1, 40pt h2 (all above 24pt minimum)
- [ ] All templates use `aspect-ratio: "16-9"`
- [ ] All templates use `@preview/touying:0.6.3` import
- [ ] All templates use `config-page` with `margin: (x: 3em, top: 2.5em, bottom: 2em)`
- [ ] All templates include `#set par(leading: 0.7em, justify: false)`
- [ ] All templates include `#set list(marker: text(fill: palette-accent)[--], spacing: 0.6em)`
- [ ] Each template has `#speaker-note[]` on every slide
- [ ] Dark templates (dark-blue, premium-dark) use light text on dark background
- [ ] Light templates (minimal-light, professional-blue, growth-green) use dark text on light background
- [ ] Premium-dark headings use gold accent fill (not palette-primary)
- [ ] All templates compile with `typst compile` without errors
- [ ] Dark-blue is documented as the primary/default template in its header comment

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-dark-blue.typ` (primary/default)
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-minimal-light.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-premium-dark.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-growth-green.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-professional-blue.typ`

## Rollback/Contingency

All templates are new files in a new `deck/` subdirectory. Rollback is straightforward: delete the `deck/` directory (`rm -rf .claude/extensions/founder/context/project/founder/templates/typst/deck/`). No existing files are modified. If a single template has issues, it can be individually deleted and recreated without affecting the others.
