# Touying Pitch Deck Template

This document provides a complete Touying 0.6.3 template optimized for investor pitch decks, following YC design principles (Legibility, Simplicity, Obviousness).

## Template Overview

- **Package**: touying 0.6.3
- **Theme**: simple (minimal, high-contrast, professional)
- **Aspect Ratio**: 16:9
- **Font Sizes**: Large (32pt body, 48pt titles)
- **Colors**: Dark text on light background

## Complete Template

```typst
#import "@preview/touying:0.6.3": *
#import themes.simple: *

// Configure the simple theme with large fonts and high contrast
#show: simple-theme.with(
  aspect-ratio: "16-9",
  config-info(
    title: [Your Company Name],
    subtitle: [One-line description of what you do],
    author: [Founder Name],
    date: datetime.today(),
  ),
)

// Override font sizes for legibility
#set text(size: 32pt)
#show heading.where(level: 1): set text(size: 48pt, weight: "bold")
#show heading.where(level: 2): set text(size: 40pt, weight: "bold")

// Title slide (generated automatically from config-info)
= Your Company Name

#speaker-note[
  Introduce yourself. State company name and one-line description.
  "We are [Company], and we [one-line description]."
]

== The Problem

#text(size: 32pt)[
  *[TODO: Clear articulation of the problem]*
]

- [TODO: Impact on real people or businesses]
- [TODO: Supporting data or statistics]

#speaker-note[
  Paint a vivid picture of the problem. Use specific examples.
  Make it relatable - investors should feel the pain.
]

== Our Solution

#text(size: 32pt)[
  *[TODO: Brief description of your solution]*

  [TODO: How it addresses the problem. Focus on benefits, not features.]
]

#speaker-note[
  Show the transformation: before vs after.
  Keep it simple - one core idea per slide.
]

== Traction

*Key Metrics*

- [TODO: Primary metric with number] (X% growth MoM)
- [TODO: Secondary metric with number]
- [TODO: Third metric if applicable]

#v(1em)

[TODO: Insert simple chart image if available, or describe growth trajectory]

#speaker-note[
  Lead with the visual. Let the chart speak first.
  Provide context: "This represents X months of growth."
  Highlight the trend, not just current numbers.
]

== Why Us / Why Now

*Unique Insight*
- [TODO: What makes your approach unique]
- [TODO: Why this is possible/needed now]

#v(1em)

*Competitive Advantage*
- [TODO: Sustainable advantage that's hard to copy]

#speaker-note[
  Explain your unfair advantage.
  Market timing: regulatory changes, technology shifts.
  Show the insight others have missed.
]

== Business Model

*Revenue Streams*
- [TODO: Primary revenue stream]
- [TODO: Secondary if applicable]

#v(1em)

*Unit Economics*
- [TODO: Price point]
- [TODO: Key margin/LTV metric]

#speaker-note[
  Keep it simple - one or two revenue streams.
  If you have early results, share them.
  Make the path to scale obvious.
]

== Market Opportunity

*Total Addressable Market (TAM)*: [TODO: $X B]

*Serviceable Addressable Market (SAM)*: [TODO: $X M]

*Serviceable Obtainable Market (SOM)*: [TODO: $X M]

#v(1em)

[TODO: Brief explanation of market sizing methodology]

#speaker-note[
  Use credible data sources.
  Bottom-up calculations are more convincing than top-down.
  Show the opportunity is large but achievable.
]

== Team

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *[TODO: Founder 1 Name]*

    CEO / Co-founder

    #text(size: 28pt)[
      [TODO: Key relevant experience]
    ]
  ],
  [
    *[TODO: Founder 2 Name]*

    CTO / Co-founder

    #text(size: 28pt)[
      [TODO: Key relevant experience]
    ]
  ],
)

#speaker-note[
  Focus on relevant domain expertise.
  Highlight previous startup experience if applicable.
  Show complementary skill sets.
]

== The Ask

#text(size: 40pt, weight: "bold")[
  Raising: $[TODO: X]M
]

#v(1em)

*Use of Funds*
- [TODO: %] Product development
- [TODO: %] Go-to-market
- [TODO: %] Team expansion
- [TODO: %] Operations

#v(1em)

*18-Month Milestones*
- [TODO: Milestone 1]
- [TODO: Milestone 2]

#speaker-note[
  Be specific about the amount.
  Milestones should be achievable and measurable.
  Show clear path from funds to outcomes.
]

== Thank You

#align(center)[
  #text(size: 40pt)[
    *[Company Name]*
  ]

  #v(1em)

  #text(size: 32pt)[
    [TODO: founder@company.com]

    [TODO: company.com]
  ]
]

#speaker-note[
  Open for questions.
  Have appendix slides ready for deep dives.
]
```

## Template Customization

### Changing Theme Colors

```typst
// For dark theme (white text on dark background)
#show: simple-theme.with(
  aspect-ratio: "16-9",
  config-colors(
    primary: rgb("#ffffff"),
    secondary: rgb("#cccccc"),
    neutral: rgb("#1a1a2e"),
  ),
)

#set page(fill: rgb("#1a1a2e"))
#set text(fill: rgb("#ffffff"))
```

### Using Alternative Themes

```typst
// Metropolis theme (modern, professional)
#import themes.metropolis: *
#show: metropolis-theme.with(aspect-ratio: "16-9")

// Stargazer theme (dark mode)
#import themes.stargazer: *
#show: stargazer-theme.with(aspect-ratio: "16-9")
```

### Adding Animations (Use Sparingly)

```typst
== Slide with Reveals

- First point

#pause

- Second point (appears on click)

#pause

- Third point (appears on click)
```

### Two-Column Layouts (Team Slide Only)

Two-column layouts should ONLY be used for the Team slide where showing founders side-by-side is natural. For all other slides, use single-column layouts for clarity.

```typst
// ONLY for Team slide
#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Founder 1*
    #text(size: 28pt)[Key experience]
  ],
  [
    *Founder 2*
    #text(size: 28pt)[Key experience]
  ],
)
```

### Inserting Images

```typst
== Slide with Image

#align(center)[
  #image("path/to/image.png", width: 80%)
]

Caption or description below.
```

## Compilation

```bash
# Compile to PDF
typst compile pitch-deck.typ

# Watch mode (recompile on save)
typst watch pitch-deck.typ
```

## Design Checklist

Before presenting, verify:

- [ ] All text is 28pt or larger (32pt body, 48pt titles)
- [ ] Each slide has one main idea
- [ ] No multi-column layouts (except Team slide)
- [ ] No decorative panels, cards, or colored boxes
- [ ] No jargon or unexplained acronyms
- [ ] Charts are simple images (no inline chart code)
- [ ] Team slide shows relevant experience only
- [ ] Ask slide has specific amount and milestones
- [ ] Total slides: 10 or fewer
- [ ] Tested with someone unfamiliar with the product

## Prohibited Patterns (DO NOT USE)

The following patterns violate YC design principles and should NOT be used in pitch decks:

### Font Sizes Below 28pt

**DO NOT USE** font sizes smaller than 28pt. Small text is unreadable during presentations and signals lack of confidence.

```typst
// PROHIBITED - too small
#text(size: 24pt)[...]
#text(size: 22pt)[...]
#text(size: 20pt)[...]
#text(size: 18pt)[...]
```

**Rationale**: YC recommends "legibility over density" - every word must be readable from the back of the room.

### Multi-Column Grids (Except Team Slide)

**DO NOT USE** grid layouts for content slides. Multi-column layouts split attention and reduce readability.

```typst
// PROHIBITED - grid for content
#grid(
  columns: (1fr, 1fr),
  [Left content],
  [Right content],
)
```

**Exception**: Team slide may use two columns for founder bios.

**Rationale**: YC recommends "one idea per slide" - grids encourage cramming multiple ideas.

### Decorative Panels and Cards

**DO NOT USE** block elements with fill colors, borders, or radius for visual decoration.

```typst
// PROHIBITED - decorative boxes
#block(
  fill: rgb("#f0f0f0"),
  radius: 8pt,
  inset: 20pt,
)[content]

// PROHIBITED - metric cards
#rect(fill: blue.lighten(80%))[Metric: $X]
```

**Rationale**: YC recommends "clarity over aesthetics" - decorative elements distract from content.

### Nested Circles for Market Sizing

**DO NOT USE** TAM/SAM/SOM circles or concentric visualizations.

```typst
// PROHIBITED - circle stacks
#circle(radius: 80pt, fill: green.lighten(80%))[TAM]
#circle(radius: 50pt, fill: green.lighten(60%))[SAM]
```

**Rationale**: These visualizations rarely communicate scale accurately and waste slide space. Use simple text with numbers instead.

### Complex Chart Code

**DO NOT USE** inline cetz or other charting libraries. Complex chart code is fragile and hard to maintain.

```typst
// PROHIBITED - inline chart code
#cetz.canvas({
  import cetz.plot
  plot.plot(size: (10, 5), ...)
})
```

**Instead**: Use pre-generated chart images or simple text descriptions of metrics.

**Rationale**: Chart code breaks frequently with package updates and distracts from slide content.

### Nested Align Patterns

**DO NOT USE** deeply nested alignment wrappers.

```typst
// PROHIBITED - nested alignment
#align(center)[
  #align(horizon)[
    #align(center)[content]
  ]
]
```

**Rationale**: Nested alignment creates unnecessary complexity. Use simple single-level alignment.

## Related Context

- See `pitch-deck-structure.md` for YC's recommended content and design principles
- See `presentation-slides.md` for general slide generation patterns
