# Implementation Plan: Task #223

- **Task**: 223 - Improve /deck slide themes with polished examples and documentation
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**: [01_investor-pitch-themes.md](../reports/01_investor-pitch-themes.md)
- **Artifacts**: plans/02_implementation-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: general

## Overview

This plan creates polished investor pitch deck theme examples and comprehensive documentation for the present extension. The implementation integrates research findings on color palettes (Professional Blue, Premium Dark, Minimal Light, Growth Green), typography recommendations (Montserrat + Inter), and YC design principles. Each example will be a complete, compilable Typst file demonstrating a distinct visual style applied to a mock startup scenario.

### Research Integration

Key findings from 01_investor-pitch-themes.md integrated:
- Four polished color palettes with specific hex codes
- Typography: Montserrat + Inter (or Open Sans) pairing
- Touying simple theme as base (best YC alignment)
- YC design principles: Legibility, Simplicity, Obviousness
- Font sizes: 30pt body, 48pt titles minimum

## Goals & Non-Goals

**Goals**:
- Create 4 complete, compilable Typst example files demonstrating each theme
- Write comprehensive README.md documenting extension capabilities
- Provide clear visual descriptions and use-case guidance for each theme
- Enable users to quickly start with professional pitch deck designs

**Non-Goals**:
- Creating custom Typst packages (use existing touying)
- Supporting additional themes beyond the 4 researched palettes
- Building compilation automation or CI integration
- Creating animated or interactive examples

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Typst compilation errors | HIGH | MEDIUM | Test each example with `typst compile` before finalizing |
| Font availability | MEDIUM | LOW | Use web-safe fallbacks in examples; document font installation |
| Color accessibility | MEDIUM | LOW | Verify WCAG contrast ratios for all palettes (already validated in research) |
| Example content too generic | LOW | MEDIUM | Use realistic mock startup data (AI safety focus) |

## Implementation Phases

### Phase 1: Create Examples Directory Structure [COMPLETED]

**Goal**: Establish examples directory and create shared configuration module

**Tasks**:
- [ ] Create `.claude/extensions/present/examples/` directory
- [ ] Create `shared-config.typ` with common imports and utility functions
- [ ] Create `README.md` in examples/ explaining directory contents

**Timing**: 20 minutes

**Files to create**:
- `.claude/extensions/present/examples/README.md` - Index of examples
- `.claude/extensions/present/examples/shared-config.typ` - Shared Typst configuration

**Verification**:
- Directory structure exists
- shared-config.typ compiles without errors

---

### Phase 2: Professional Blue Theme Example [COMPLETED]

**Goal**: Create complete pitch deck example using Professional Blue palette

**Tasks**:
- [ ] Create `professional-blue-pitch.typ` with full 10-slide structure
- [ ] Apply color palette: #1a365d (Deep Navy), #2c5282 (Medium Blue), #4299e1 (Sky Blue)
- [ ] Configure Montserrat headlines + Inter body fonts
- [ ] Add speaker notes for each slide
- [ ] Verify compilation produces clean PDF

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/present/examples/professional-blue-pitch.typ`

**Mock Startup**: "SafeAI Labs" - AI safety research company

**Verification**:
- `typst compile professional-blue-pitch.typ` succeeds
- PDF displays correct colors and fonts
- All 10 slides render correctly

---

### Phase 3: Premium Dark Theme Example [COMPLETED]

**Goal**: Create complete pitch deck example using Premium Dark palette

**Tasks**:
- [ ] Create `premium-dark-pitch.typ` with full 10-slide structure
- [ ] Apply color palette: #1a1a2e (Dark Charcoal), #16213e (Deep Blue-Black), #d4a574 (Gold)
- [ ] Configure light text on dark background
- [ ] Add speaker notes for each slide
- [ ] Verify compilation produces clean PDF

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/present/examples/premium-dark-pitch.typ`

**Mock Startup**: "NeuralShield" - Enterprise AI security platform

**Verification**:
- `typst compile premium-dark-pitch.typ` succeeds
- PDF displays correct dark theme colors
- Gold accents visible and readable

---

### Phase 4: Minimal Light Theme Example [COMPLETED]

**Goal**: Create complete pitch deck example using Minimal Light palette

**Tasks**:
- [ ] Create `minimal-light-pitch.typ` with full 10-slide structure
- [ ] Apply color palette: #2d3748 (Charcoal), #4a5568 (Medium Gray), #3182ce (Blue)
- [ ] Configure maximum whitespace and clean typography
- [ ] Add speaker notes for each slide
- [ ] Verify compilation produces clean PDF

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/present/examples/minimal-light-pitch.typ`

**Mock Startup**: "ClearView Analytics" - Data analytics for startups

**Verification**:
- `typst compile minimal-light-pitch.typ` succeeds
- PDF displays clean, minimal aesthetic
- High contrast maintained throughout

---

### Phase 5: Growth Green Theme Example [COMPLETED]

**Goal**: Create complete pitch deck example using Growth Green palette

**Tasks**:
- [ ] Create `growth-green-pitch.typ` with full 10-slide structure
- [ ] Apply color palette: #047857 (Emerald), #065f46 (Dark Green), #34d399 (Light Green)
- [ ] Configure for sustainability/growth messaging
- [ ] Add speaker notes for each slide
- [ ] Verify compilation produces clean PDF

**Timing**: 30 minutes

**Files to create**:
- `.claude/extensions/present/examples/growth-green-pitch.typ`

**Mock Startup**: "GreenPath Energy" - Clean energy optimization platform

**Verification**:
- `typst compile growth-green-pitch.typ` succeeds
- PDF displays correct green palette
- Environmental/growth theme evident

---

### Phase 6: Create Extension README Documentation [COMPLETED]

**Goal**: Write comprehensive README.md for the present extension

**Tasks**:
- [ ] Create `.claude/extensions/present/README.md` with sections:
  - Extension overview and purpose
  - Available commands (/deck, /grant)
  - Theme gallery with visual descriptions
  - Quick start guide
  - Compilation instructions
  - Customization guide
  - Links to examples
- [ ] Document each theme with:
  - Visual description
  - Best use cases
  - Color palette hex codes
  - Font recommendations
- [ ] Add troubleshooting section for common issues

**Timing**: 45 minutes

**Files to create**:
- `.claude/extensions/present/README.md`

**Verification**:
- README renders correctly in GitHub/GitLab markdown preview
- All internal links resolve correctly
- Commands documented with usage examples

---

### Phase 7: Final Verification and Cleanup [COMPLETED]

**Goal**: Verify all examples compile and documentation is complete

**Tasks**:
- [ ] Compile all 4 example files and verify PDFs
- [ ] Verify README links point to correct example files
- [ ] Check that examples use consistent mock startup format
- [ ] Ensure speaker notes are present in all examples
- [ ] Verify font fallbacks work when custom fonts unavailable

**Timing**: 15 minutes

**Files to verify**:
- All `.claude/extensions/present/examples/*.typ`
- `.claude/extensions/present/README.md`

**Verification**:
- All 4 examples compile without errors
- PDFs display correctly
- README is comprehensive and accurate
- No broken links or references

## Testing & Validation

- [ ] All 4 theme examples compile with `typst compile`
- [ ] Generated PDFs display correct colors and fonts
- [ ] README.md renders correctly in markdown preview
- [ ] Internal links in README resolve to existing files
- [ ] Examples use consistent 10-slide YC structure
- [ ] Speaker notes present in all slides
- [ ] Color hex codes match research report specifications

## Artifacts & Outputs

- `.claude/extensions/present/examples/README.md` - Examples index
- `.claude/extensions/present/examples/shared-config.typ` - Shared configuration
- `.claude/extensions/present/examples/professional-blue-pitch.typ` - Blue theme example
- `.claude/extensions/present/examples/premium-dark-pitch.typ` - Dark theme example
- `.claude/extensions/present/examples/minimal-light-pitch.typ` - Light theme example
- `.claude/extensions/present/examples/growth-green-pitch.typ` - Green theme example
- `.claude/extensions/present/README.md` - Extension documentation
- `specs/223_improve_deck_themes_examples_documentation/summaries/03_implementation-summary.md` - Execution summary

## Rollback/Contingency

If implementation fails:
1. All changes are contained within `.claude/extensions/present/` directory
2. No existing functionality is modified (additive only)
3. Delete `examples/` directory and `README.md` to restore previous state
4. Git revert to pre-implementation commit if needed

If specific examples fail to compile:
1. Check Typst version compatibility (requires 0.11+)
2. Verify touying package version (0.6.3 specified)
3. Test with default system fonts before custom fonts
4. Fall back to simpler color configuration if gradient issues
