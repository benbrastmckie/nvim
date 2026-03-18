// Shared configuration for investor pitch deck examples
// Common imports and utility functions for consistent theming

#import "@preview/touying:0.6.3": *
#import themes.simple: *

// Color palette definitions
// Professional Blue
#let professional-blue = (
  primary: rgb("#1a365d"),
  secondary: rgb("#2c5282"),
  accent: rgb("#4299e1"),
  background: rgb("#ffffff"),
  text: rgb("#1a202c"),
)

// Premium Dark
#let premium-dark = (
  primary: rgb("#1a1a2e"),
  secondary: rgb("#16213e"),
  accent: rgb("#d4a574"),
  background: rgb("#0f0f1a"),
  text: rgb("#e2e8f0"),
)

// Minimal Light
#let minimal-light = (
  primary: rgb("#2d3748"),
  secondary: rgb("#4a5568"),
  accent: rgb("#3182ce"),
  background: rgb("#f7fafc"),
  text: rgb("#1a202c"),
)

// Growth Green
#let growth-green = (
  primary: rgb("#047857"),
  secondary: rgb("#065f46"),
  accent: rgb("#34d399"),
  background: rgb("#f0fdf4"),
  text: rgb("#1a202c"),
)

// Typography configuration
// Recommended: Montserrat for headings, Inter for body text
// Fallback to system fonts if custom fonts are unavailable

#let configure-typography(
  heading-font: "Montserrat",
  body-font: "Inter",
  base-size: 30pt,
  heading-size: 48pt,
  subheading-size: 40pt,
) = {
  set text(font: body-font, size: base-size)
  show heading.where(level: 1): set text(font: heading-font, size: heading-size, weight: "bold")
  show heading.where(level: 2): set text(font: heading-font, size: subheading-size, weight: "bold")
}

// Chart placeholder utility
// Use this when actual data is not yet available
#let chart-placeholder(
  width: 90%,
  height: 60%,
  fill-color: rgb("#f0f0f0"),
  label: "Chart placeholder",
) = {
  align(center)[
    #block(
      width: width,
      height: height,
      fill: fill-color,
      radius: 8pt,
      inset: 20pt,
    )[
      #align(center + horizon)[
        #text(size: 24pt, fill: rgb("#666"))[
          #label
        ]
      ]
    ]
  ]
}

// Metric display for traction slides
#let metric-display(
  value: "100K",
  label: "Users",
  color: rgb("#1a365d"),
) = {
  block(
    fill: color.lighten(90%),
    radius: 8pt,
    inset: 16pt,
  )[
    #align(center)[
      #text(size: 48pt, weight: "bold", fill: color)[#value]
      #v(0.5em)
      #text(size: 20pt, fill: color.darken(20%))[#label]
    ]
  ]
}

// Two-column layout helper
#let two-columns(left, right, gutter: 2em) = {
  grid(
    columns: (1fr, 1fr),
    gutter: gutter,
    left,
    right,
  )
}

// Team member card
#let team-member(
  name: "Founder Name",
  role: "CEO / Co-founder",
  experience: [],
) = {
  block[
    *#name*

    #role

    #text(size: 22pt)[
      #experience
    ]
  ]
}

// Contact slide footer
#let contact-footer(
  email: "founder@company.com",
  website: "company.com",
) = {
  align(center)[
    #v(1em)
    #text(size: 28pt)[
      #email

      #website
    ]
  ]
}
