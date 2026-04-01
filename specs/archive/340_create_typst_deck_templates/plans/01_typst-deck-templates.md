# Implementation Plan: Task #340

- **Task**: 340 - Create reusable typst slide deck templates
- **Status**: [NOT STARTED]
- **Effort**: 3 hours
- **Dependencies**: None
- **Research Inputs**: specs/340_create_typst_deck_templates/reports/01_typst-deck-templates.md
- **Artifacts**: plans/01_typst-deck-templates.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create four reusable, self-contained typst pitch deck templates in the founder extension, each following a distinct visual style (minimal-light, professional-blue, premium-dark, growth-green). Templates use touying 0.6.3 with the simple theme, heading-based slide syntax, YC-compliant typography (32pt body, 48pt titles), and parameterizable `#let` bindings at the top for programmatic content insertion by the deck-builder agent. Each template is a complete compilable `.typ` file with 10 placeholder slides plus an appendix section.

### Research Integration

Research confirmed that the existing `present/examples/` pitch decks demonstrate the correct heading-based pattern with touying 0.6.3. The production `deck-source.typ` uses `#slide[]` block syntax with non-compliant font sizes and should NOT be followed. Templates should use Option B (parameter-block templates) -- complete compilable files with `#let` parameter sections at top. The four palette color schemes are already defined in the deck-agent documentation. Templates go in a new `deck/` subdirectory under the founder extension's typst templates.

## Goals & Non-Goals

**Goals**:
- Create 4 self-contained, compilable typst deck templates
- Enforce YC compliance (24pt+ body, 40pt+ titles, 16:9, max 10 slides)
- Make templates parameterizable with clearly marked `#let` bindings
- Include `[TODO:]` placeholder content and speaker note guidance on every slide
- Follow the established present/examples/ heading-based pattern

**Non-Goals**:
- Creating a shared base/utility library (research recommends self-contained files)
- Supporting themes other than touying's `simple` theme
- Including actual company content (templates are generic)
- Building the deck-planner or deck-builder agents (tasks 342-343)
- Supporting fonts beyond Inter + Montserrat (with Liberation Sans fallback)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Font unavailability (Montserrat, Inter) | Compilation warnings, fallback fonts | M | Include Liberation Sans fallback in font lists |
| Dark theme contrast below 4.5:1 | YC compliance failure | L | Use pre-validated palette colors from deck-agent |
| Touying heading syntax inconsistencies | Slide breaks in wrong places | L | Follow proven pattern from present/examples/ |
| Templates too rigid for deck-builder | Insufficient customization points | M | Use extensive `[TODO:]` markers and comment annotations |

## Implementation Phases

### Phase 1: Create deck directory and minimal-light template [NOT STARTED]

**Goal**: Establish the template directory and create the first (reference) template based on the minimal-light palette, which most closely matches the existing examples.

**Tasks**:
- [ ] Create directory `.claude/extensions/founder/context/project/founder/templates/typst/deck/`
- [ ] Create `deck-minimal-light.typ` with complete structure:
  - Header comment block (style name, colors, typography, use case, touying version)
  - Touying 0.6.3 import with `themes.simple`
  - Parameter section: company-name, company-subtitle, author-name, funding-round, funding-date
  - Palette section: primary (#2d3748), secondary (#4a5568), accent (#3182ce), bg (#f7fafc), text (#1a202c)
  - Theme setup: `simple-theme.with()` with aspect-ratio "16-9", config-info, config-colors
  - Typography: page fill, text 32pt Inter, heading.1 at 48pt Montserrat, heading.2 at 40pt Montserrat
  - 10 slides with `== Heading` syntax, `[TODO:]` placeholder content, `#speaker-note[]` guidance
  - Appendix section template
- [ ] Verify template compiles with `typst compile` (if typst available)

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-minimal-light.typ` - CREATE new file

**Verification**:
- File exists and is non-empty
- Contains all 10 slide sections (Title through Closing)
- Contains parameter section with `#let` bindings
- Contains YC-compliant font sizes (32pt body, 48pt h1, 40pt h2)
- Compiles without errors (if typst CLI available)

---

### Phase 2: Create professional-blue template [NOT STARTED]

**Goal**: Create the professional-blue template optimized for fintech/enterprise use cases, adapting the structure from Phase 1 with the deep navy color palette.

**Tasks**:
- [ ] Create `deck-professional-blue.typ` adapting the minimal-light structure with:
  - Header comment: professional-blue palette, fintech/enterprise use case
  - Palette: primary (#1a365d), secondary (#2c5282), accent (#4299e1), bg (#ffffff), text (#1a202c)
  - White background with deep navy headings
  - Same typography and slide structure as minimal-light
  - Adjusted speaker notes reflecting professional/enterprise tone
- [ ] Verify template compiles

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-professional-blue.typ` - CREATE new file

**Verification**:
- File exists with correct palette colors
- Background is white (#ffffff)
- All 10 slides present with professional tone in speaker notes
- Compiles without errors

---

### Phase 3: Create premium-dark template [NOT STARTED]

**Goal**: Create the premium-dark template with gold-on-dark styling for luxury/premium tech startups. This template requires extra attention to contrast ratios since it uses a dark background.

**Tasks**:
- [ ] Create `deck-premium-dark.typ` with:
  - Header comment: premium-dark palette, luxury/premium tech use case
  - Palette: primary (#1a1a2e), secondary (#16213e), accent (#d4a574), bg (#0f0f1a), text (#e2e8f0)
  - Dark background with light text -- reversed color scheme
  - Headings use gold accent (#d4a574) instead of primary (too similar to bg)
  - List markers and emphasis elements use gold accent
  - Same 10-slide structure
  - Speaker notes noting the premium/luxury presentation context
- [ ] Verify contrast: light text (#e2e8f0) on dark bg (#0f0f1a) exceeds 4.5:1
- [ ] Verify template compiles

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-premium-dark.typ` - CREATE new file

**Verification**:
- File exists with correct dark palette
- Heading fill uses accent (#d4a574) for visibility on dark bg
- Text fill is light (#e2e8f0) for readability
- All 10 slides present
- Compiles without errors

---

### Phase 4: Create growth-green template [NOT STARTED]

**Goal**: Create the growth-green template with emerald tones for sustainability, health, and climate tech startups.

**Tasks**:
- [ ] Create `deck-growth-green.typ` with:
  - Header comment: growth-green palette, sustainability/health/climate use case
  - Palette: primary (#047857), secondary (#065f46), accent (#34d399), bg (#f0fdf4), text (#1a202c)
  - Mint background with emerald headings
  - Same 10-slide structure
  - Speaker notes reflecting sustainability/impact context
- [ ] Verify template compiles

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-growth-green.typ` - CREATE new file

**Verification**:
- File exists with correct green palette
- Background is mint (#f0fdf4)
- All 10 slides present
- Compiles without errors

---

### Phase 5: Cross-template validation and consistency check [NOT STARTED]

**Goal**: Ensure all four templates are consistent in structure, parameterization, and YC compliance. Verify they are ready for the deck-planner (task 342) and deck-builder (task 343) to consume.

**Tasks**:
- [ ] Verify all 4 templates have identical structure (same slide order, same parameter names, same section comments)
- [ ] Verify all parameter sections use the same `#let` binding names (company-name, company-subtitle, author-name, funding-round, funding-date)
- [ ] Verify all templates have `[TODO:]` markers in content areas for deck-builder substitution
- [ ] Verify YC compliance across all templates: 32pt body, 48pt h1, 40pt h2, 16:9 aspect ratio
- [ ] Verify font fallback chains are consistent (Inter with Liberation Sans fallback for body, Montserrat with Liberation Sans fallback for headings)
- [ ] Compile all 4 templates (if typst available) to confirm no syntax errors
- [ ] Verify header comment blocks document palette name, colors, use case, and touying version

**Timing**: 15 minutes

**Files to modify**:
- No new files; review all 4 deck templates for consistency

**Verification**:
- All 4 files exist in `deck/` directory
- `grep` confirms identical parameter names across all templates
- `grep` confirms identical font size settings across all templates
- All templates compile successfully (if typst available)

## Testing & Validation

- [ ] All 4 template files exist in `.claude/extensions/founder/context/project/founder/templates/typst/deck/`
- [ ] Each template contains exactly 10 main slide sections plus appendix
- [ ] Each template has a clearly marked PARAMETERS section with 5 `#let` bindings
- [ ] Each template has a PALETTE section with 5 color definitions
- [ ] Font sizes are YC-compliant: 32pt body, 48pt h1, 40pt h2 (all above minimums)
- [ ] All templates use `aspect-ratio: "16-9"`
- [ ] All templates use `@preview/touying:0.6.3` import
- [ ] Each template has `#speaker-note[]` on every slide
- [ ] Premium-dark template uses light text on dark background (reversed scheme)
- [ ] All templates compile with `typst compile` without errors

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-minimal-light.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-professional-blue.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-premium-dark.typ`
- `.claude/extensions/founder/context/project/founder/templates/typst/deck/deck-growth-green.typ`

## Rollback/Contingency

All templates are new files in a new `deck/` subdirectory. Rollback is straightforward: delete the `deck/` directory. No existing files are modified. If a single template has issues, it can be individually deleted and recreated without affecting the others.
