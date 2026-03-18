# Research Report: Task #223

**Task**: 223 - Improve /deck slide themes with polished examples and documentation
**Started**: 2026-03-17T12:00:00Z
**Completed**: 2026-03-17T12:30:00Z
**Effort**: 2-3 hours (research complete, implementation pending)
**Dependencies**: Existing Touying pitch deck template (already exists)
**Sources/Inputs**: WebSearch, WebFetch, codebase analysis
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Modern investor pitch decks emphasize **minimalism, bold typography, and strategic color use** over flashy design
- Y Combinator's three design principles (Legibility, Simplicity, Obviousness) remain the gold standard for VC presentations
- Touying provides 6 built-in themes plus community extensions; **calmly-touying** and **minimal-presentation** are most suitable for investor decks
- Color psychology strongly favors **blue-based palettes** (trust, stability) with selective accent colors
- Font pairing best practices: **sans-serif headlines + complementary body fonts** (Montserrat + Open Sans, Lato + Roboto)
- The existing Touying template in the codebase follows sound principles but lacks polished theme examples

## Context & Scope

This research investigates best practices for polished investor pitch deck visual themes, specifically:
1. Current design trends for VC presentations (2025-2026)
2. Color schemes and typography that communicate professionalism and trust
3. Typst/Touying-compatible theme implementations
4. Examples from successful startup pitch decks

## Findings

### 1. Design Trends for Investor Pitch Decks (2026)

Based on Visible.vc's 11 presentation design trends:

| Trend | Description | VC Relevance |
|-------|-------------|--------------|
| **Large Bold Typography** | Oversized fonts for headlines, 40pt+ titles | HIGH - ensures legibility, creates visual hierarchy |
| **Gradient Color Schemes** | Blending 2+ colors for depth | MEDIUM - modern feel, use sparingly |
| **Minimalism** | Ample whitespace, simple palettes, concise text | CRITICAL - investors prefer clarity |
| **Asymmetrical Layout** | Off-center elements for visual interest | LOW - can appear chaotic for formal presentations |
| **Redefined Data Visualization** | Infographics, timelines over basic charts | HIGH - traction slides benefit greatly |
| **Custom Fonts** | Brand-aligned typography | MEDIUM - for established brand identity |

**Key Insight**: Investors spend an average of **3 minutes 44 seconds** reviewing a deck, with only **10 seconds per slide**. Design must communicate instantly.

### 2. Color Psychology for Investor Presentations

#### Recommended Primary Palettes

| Color | Psychology | Best For | Example Use |
|-------|------------|----------|-------------|
| **Deep Blue** (#1a365d, #2c5282) | Trust, stability, intelligence | Fintech, enterprise B2B | Primary background or accents |
| **Navy + White** | Sophistication, clarity | Professional services | High-contrast clean look |
| **Charcoal + Gold** (#1a1a2e + #d4a574) | Premium, elegant | Luxury, high-end products | Accent highlights |
| **Soft Gray + Emerald** (#f5f5f5 + #047857) | Growth, sustainability | Cleantech, health | Environmental messaging |

#### Color Combinations to Avoid

- Light text on light backgrounds (readability failure)
- More than 3-4 colors (visual overwhelm)
- Neon or clashing combinations (distraction)
- Red as primary color (signals danger in Western contexts)

#### Successful Examples

**Airbnb (2008 deck)**: Calming blue background with warm lifestyle photography - communicated trust and reliability.

**Buffer**: Transparency-driven design with clean blues - reinforced trust theme.

### 3. Typography Best Practices

#### Recommended Font Pairings

| Headlines | Body | Style | Best For |
|-----------|------|-------|----------|
| **Montserrat** | Open Sans | Modern geometric | Tech startups |
| **Playfair Display** | Lato | Classic + modern | Premium brands |
| **Futura** | Source Sans Pro | Bold futuristic | Innovation-focused |
| **Poppins** | Inter | Friendly, accessible | Consumer apps |
| **Raleway** | Roboto | Elegant minimal | Design-focused |

#### Size Guidelines (YC Standard)

- **Titles**: 48pt minimum (readable from back of room)
- **Headlines**: 40pt minimum
- **Body text**: 30pt minimum (never below 24pt)
- **Captions/labels**: 24pt minimum

#### Typography Rules

1. **Limit to 2 font families** - one for headings, one for body
2. **Sans-serif preferred** for digital presentations
3. **High contrast** - dark text on light background (or inverse)
4. **Consistent hierarchy** - establish and maintain visual weight

### 4. Touying Theme Analysis

#### Built-in Themes

| Theme | Style | VC Suitability | Notes |
|-------|-------|----------------|-------|
| **Simple** | Minimal, high-contrast | EXCELLENT | Follows YC principles |
| **Metropolis** | Modern urban | GOOD | Professional, contemporary |
| **Dewdrop** | Fresh, clean | MODERATE | May appear casual |
| **University** | Academic | LOW | Too formal for startups |
| **Aqua** | Water-themed | LOW | Thematic, not universal |
| **Stargazer** | Dark mode, astronomy | MODERATE | Good for tech demos |

#### Recommended Community Themes

**calmly-touying** (Best for investor decks):
- Moloch-inspired design (academic elegance)
- 4 color themes: Tomorrow (programmer-friendly), Warm Amber (premium), Paper (high-contrast), Dracula (dark)
- Golden ratio spacing
- 30+ reusable components
- Light/dark variants

Configuration:
```typst
#show: calmly.with(
  config-info(title: [Company Name], author: [Founder]),
  colortheme: "tomorrow",  // or "warm-amber", "paper", "dracula"
  variant: "light",
  progress: "foot",  // progress bar position
)
```

**minimal-presentation**:
- MIT-0 license
- Default 20pt text, 2.9em titles
- Lato font family
- 16:9 and 4:3 aspect ratios
- Simple configuration

### 5. Analysis of Successful Pitch Decks

#### Common Design Patterns

| Company | Design Approach | Key Lesson |
|---------|-----------------|------------|
| **Airbnb** | Basic, efficient, no fluff | Simplicity wins - let content shine |
| **Uber** | Rough, visually unimpressive | Conviction > aesthetics |
| **Buffer** | Transparent, data-driven | Authenticity builds trust |
| **Facebook** | Data-focused, no financials | Growth metrics > revenue projections |
| **LinkedIn** | Audience-tailored, serious | Know your investors |

#### Universal Principles

1. **Economy of design** - no long paragraphs, stock photos, or visual clutter
2. **Data grounding** - real numbers validate the story
3. **One idea per slide** - avoid information overload
4. **Visual breathing room** - whitespace is strategic

### 6. Existing Codebase Analysis

The current implementation at `.claude/extensions/present/context/project/present/patterns/` includes:

**touying-pitch-deck-template.md** (397 lines):
- Uses simple theme (correct choice)
- 30pt body, 48pt titles (follows YC guidelines)
- Includes speaker notes
- Has chart placeholder patterns
- Dark theme variant documented

**pitch-deck-structure.md** (254 lines):
- Documents YC's 9+1 slide structure
- Three design principles (Legibility, Simplicity, Obviousness)
- Anti-patterns documented
- Layout notes for special slides

**Gaps Identified**:
1. No polished visual theme examples with color palettes
2. No font pairing recommendations
3. No gradient/modern aesthetic options
4. No comparison of theme options
5. No screenshot/preview guidance

## Recommendations

### Immediate Improvements

1. **Add Theme Examples Section** to touying-pitch-deck-template.md:
   - Professional Blue theme (deep blue + white)
   - Premium Dark theme (charcoal + gold accents)
   - Minimal Light theme (white + subtle gray)
   - Growth Green theme (soft gray + emerald)

2. **Document Color Palettes** with specific hex codes:
   ```typst
   // Professional Blue
   primary: rgb("#1a365d")
   secondary: rgb("#2c5282")
   accent: rgb("#4299e1")
   background: rgb("#ffffff")
   text: rgb("#1a202c")
   ```

3. **Add Font Configuration Examples**:
   ```typst
   #set text(font: "Inter", size: 30pt)
   #show heading.where(level: 1): set text(font: "Montserrat", weight: "bold")
   ```

4. **Create Theme Comparison Table** showing visual differences

5. **Add calmly-touying Integration** as alternative to simple theme

### Documentation Enhancements

- Add visual preview descriptions for each theme
- Include "when to use" guidance for theme selection
- Document gradient implementation for modern aesthetic
- Add data visualization styling recommendations

## Decisions

- **Primary recommendation**: Continue using Touying simple theme as base
- **Enhancement path**: Add color palette variations rather than new themes
- **Font strategy**: Document Inter + Montserrat as default pairing
- **Modern elements**: Add optional gradient backgrounds as enhancement

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Over-design distracts from content | HIGH | Emphasize YC minimalism principles |
| Custom fonts not available | MEDIUM | Document fallback system fonts |
| Gradients render poorly in PDF | MEDIUM | Test export formats |
| Color accessibility issues | MEDIUM | Include WCAG contrast ratios |

## Context Extension Recommendations

- **Topic**: Typst/Touying theme customization patterns
- **Gap**: No systematic documentation of color palette configuration
- **Recommendation**: Create `touying-theme-customization.md` with palette recipes

## Appendix

### Search Queries Used

1. "best investor pitch deck design themes 2025 2026 VC presentation visual styles"
2. "startup pitch deck typography color schemes modern minimalist design"
3. "Y Combinator Sequoia pitch deck template design examples"
4. "Typst presentation themes Touying slides modern design"
5. "pitch deck design principles investor presentation best practices visual hierarchy"
6. "successful startup pitch deck color palette hex codes blue professional typography"
7. "Airbnb pitch deck Uber pitch deck Buffer pitch deck design visual style analysis"

### References

- [11 Presentation Design Trends for Startup Pitch Decks in 2026 - Visible.vc](https://visible.vc/blog/startup-presentation-design-trends/)
- [Introduction to Touying](https://touying-typ.github.io/docs/intro)
- [calmly-touying - Typst Universe](https://typst.app/universe/package/calmly-touying)
- [minimal-presentation - Typst Universe](https://typst.app/universe/package/minimal-presentation/)
- [How to design a better pitch deck - YC Startup Library](https://www.ycombinator.com/library/4T-how-to-design-a-better-pitch-deck)
- [How to build your seed round pitch deck - YC Startup Library](https://www.ycombinator.com/library/2u-how-to-build-your-seed-round-pitch-deck)
- [18 Best Pitch Decks From Real-Life Startups - Visme](https://visme.co/blog/best-pitch-decks/)
- [Pitch Deck Colors: How to Choose - FasterCapital](https://fastercapital.com/content/Pitch-deck-colors--How-to-choose-and-use-colors-that-are-consistent-and-appealing.html)
- [Best 10 VC Pitch Decks - Kruze Consulting](https://kruzeconsulting.com/blog/top-5-venture-capital-pitch-decks/)
- [30 Best Startup Pitch Deck Examples - Whitepage Studio](https://www.whitepage.studio/blog/30-inspiring-startup-pitch-decks-unlock-secrets-to-investor-success)

### Proposed Color Palettes (Hex Codes)

#### Professional Blue
```
Primary:    #1a365d (Deep Navy)
Secondary:  #2c5282 (Medium Blue)
Accent:     #4299e1 (Sky Blue)
Background: #ffffff (White)
Text:       #1a202c (Dark Gray)
```

#### Premium Dark
```
Primary:    #1a1a2e (Dark Charcoal)
Secondary:  #16213e (Deep Blue-Black)
Accent:     #d4a574 (Gold)
Background: #0f0f1a (Near Black)
Text:       #e2e8f0 (Light Gray)
```

#### Minimal Light
```
Primary:    #2d3748 (Charcoal)
Secondary:  #4a5568 (Medium Gray)
Accent:     #3182ce (Blue)
Background: #f7fafc (Off-White)
Text:       #1a202c (Dark Gray)
```

#### Growth Green
```
Primary:    #047857 (Emerald)
Secondary:  #065f46 (Dark Green)
Accent:     #34d399 (Light Green)
Background: #f0fdf4 (Mint White)
Text:       #1a202c (Dark Gray)
```
