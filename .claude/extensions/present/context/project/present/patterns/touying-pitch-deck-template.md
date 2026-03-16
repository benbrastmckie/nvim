# Touying Pitch Deck Template

This document provides a complete Touying 0.6.3 template optimized for investor pitch decks, following YC design principles (Legibility, Simplicity, Obviousness).

## Template Overview

- **Package**: touying 0.6.3
- **Theme**: simple (minimal, high-contrast, professional)
- **Aspect Ratio**: 16:9
- **Font Sizes**: Large (30pt body, 48pt titles)
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
#set text(size: 30pt)
#show heading.where(level: 1): set text(size: 48pt, weight: "bold")
#show heading.where(level: 2): set text(size: 40pt, weight: "bold")

// Title slide (generated automatically from config-info)
= Your Company Name

#speaker-note[
  Introduce yourself. State company name and one-line description.
  "We are [Company], and we [one-line description]."
]

== The Problem

#text(size: 36pt)[
  *[TODO: Clear articulation of the problem]*
]

- [TODO: Impact on real people or businesses]
- [TODO: Supporting data or statistics]

#speaker-note[
  Paint a vivid picture of the problem. Use specific examples.
  Make it relatable - investors should feel the pain.
]

== Our Solution

#text(size: 36pt)[
  *[TODO: Brief description of your solution]*
]

#v(1em)

#text(size: 28pt)[
  [TODO: How it addresses the problem. Focus on benefits, not features.]
]

#speaker-note[
  Show the transformation: before vs after.
  Keep it simple - one core idea per slide.
]

== Traction

#align(center)[
  #block(
    width: 90%,
    height: 60%,
    fill: rgb("#f0f0f0"),
    radius: 8pt,
    inset: 20pt,
  )[
    #align(center + horizon)[
      #text(size: 24pt, fill: rgb("#666"))[
        [TODO: Insert chart/graph showing key metrics]

        Use a line chart for growth over time,
        or bar chart for comparative metrics.
      ]
    ]
  ]
]

#text(size: 24pt)[
  *Key metric*: [TODO: X% growth MoM / $Y revenue / Z users]
]

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

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Revenue Streams*
    - [TODO: Primary revenue stream]
    - [TODO: Secondary if applicable]
  ],
  [
    *Unit Economics*
    - [TODO: Price point]
    - [TODO: Key margin/LTV metric]
  ],
)

#speaker-note[
  Keep it simple - one or two revenue streams.
  If you have early results, share them.
  Make the path to scale obvious.
]

== Market Opportunity

#align(center)[
  #stack(
    dir: ttb,
    spacing: 1em,
    [
      #circle(radius: 80pt, fill: rgb("#e8f4ea"), stroke: rgb("#4a9960"))[
        #align(center + horizon)[
          #text(size: 20pt)[*TAM*: [TODO: $X B]]
        ]
      ]
    ],
    [
      #circle(radius: 50pt, fill: rgb("#d0e8d4"), stroke: rgb("#4a9960"))[
        #align(center + horizon)[
          #text(size: 18pt)[*SAM*: [TODO]]
        ]
      ]
    ],
  )
]

#text(size: 24pt)[
  [TODO: Brief explanation of market sizing methodology]
]

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

    #text(size: 22pt)[
      [TODO: Relevant experience]
      - Previous role/company
      - Domain expertise
    ]
  ],
  [
    *[TODO: Founder 2 Name]*

    CTO / Co-founder

    #text(size: 22pt)[
      [TODO: Relevant experience]
      - Previous role/company
      - Technical background
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
  #text(size: 36pt)[
    *[Company Name]*
  ]

  #v(1em)

  #text(size: 28pt)[
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

### Two-Column Layouts

```typst
== Two Column Slide

#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Left Column*
    - Point 1
    - Point 2
  ],
  [
    *Right Column*
    - Point A
    - Point B
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

### Chart Placeholder Pattern

For the Traction slide, replace the placeholder with actual chart code:

```typst
// Using cetz for charts
#import "@preview/cetz:0.2.2"

#cetz.canvas({
  import cetz.plot
  import cetz.draw: *

  plot.plot(
    size: (10, 5),
    x-tick-step: 1,
    y-tick-step: 100,
    x-label: "Month",
    y-label: "Revenue ($K)",
    {
      plot.add(
        ((1, 10), (2, 25), (3, 45), (4, 80), (5, 120), (6, 200)),
        mark: "o",
        style: (stroke: rgb("#4a9960"), mark: (fill: rgb("#4a9960"))),
      )
    },
  )
})
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

- [ ] All text is readable at 24pt or larger
- [ ] Each slide has one main idea
- [ ] No jargon or unexplained acronyms
- [ ] Charts are simple with clear labels
- [ ] Team slide shows relevant experience only
- [ ] Ask slide has specific amount and milestones
- [ ] Total slides: 10 or fewer
- [ ] Tested with someone unfamiliar with the product

## Related Context

- See `pitch-deck-structure.md` for YC's recommended content and design principles
- See `presentation-slides.md` for general slide generation patterns
