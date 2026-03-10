# Typst Presentation Template

**Created**: 2026-02-27
**Purpose**: Template for presentations using Polylux

---

## Template Structure

```typst
// presentation.typ - Presentation Template

#import "@preview/polylux:0.3.1": *

// Theme configuration
#set page(
  paper: "presentation-16-9",
  margin: (x: 2cm, y: 1.5cm),
)

// Text setup
#set text(
  font: "New Computer Modern",
  size: 20pt,
)

// Custom colors
#let primary-color = rgb("#2c3e50")
#let accent-color = rgb("#3498db")

// Title slide style
#let title-slide(title, subtitle: none, author: none, date: none) = {
  polylux-slide[
    #align(center + horizon)[
      #block(
        fill: primary-color,
        inset: 2em,
        radius: 5pt,
      )[
        #text(fill: white, size: 32pt, weight: "bold")[#title]

        #if subtitle != none {
          v(0.5em)
          text(fill: white.darken(20%), size: 20pt)[#subtitle]
        }
      ]

      #v(2em)

      #if author != none {
        text(size: 18pt)[#author]
        v(0.3em)
      }

      #if date != none {
        text(size: 14pt, fill: gray)[#date]
      }
    ]
  ]
}

// Section slide style
#let section-slide(title) = {
  polylux-slide[
    #align(center + horizon)[
      #text(size: 36pt, weight: "bold", fill: primary-color)[#title]
    ]
  ]
}

// Content slide style
#let content-slide(title, body) = {
  polylux-slide[
    #text(size: 28pt, weight: "bold", fill: primary-color)[#title]
    #v(1em)
    #body
  ]
}

// Presentation content
#title-slide(
  "Presentation Title",
  subtitle: "A Subtitle",
  author: "Author Name",
  date: datetime.today().display("[month repr:long] [day], [year]"),
)

#section-slide("Introduction")

#content-slide("Overview")[
  - First point
  - Second point
  - Third point

  #v(1em)

  Key insight: #text(fill: accent-color)[important concept]
]

#content-slide("Methodology")[
  #grid(
    columns: 2,
    gutter: 2em,
    [
      *Left Column*
      - Item 1
      - Item 2
    ],
    [
      *Right Column*
      - Item 3
      - Item 4
    ],
  )
]

#content-slide("Results")[
  #figure(
    table(
      columns: 3,
      [Method], [Accuracy], [Time],
      [A], [95%], [1.2s],
      [B], [92%], [0.8s],
    ),
    caption: [Comparison of methods],
  )
]

#content-slide("Math Example")[
  The fundamental theorem states:

  $
    integral_a^b f(x) dif x = F(b) - F(a)
  $
]

#section-slide("Conclusion")

#content-slide("Summary")[
  - Main finding 1
  - Main finding 2
  - Future directions

  #v(2em)

  #align(center)[
    #text(size: 24pt, weight: "bold")[Questions?]
  ]
]
```

## Features

- 16:9 aspect ratio
- Custom title and section slides
- Two-column layouts
- Figure and table support
- Math equations
- Custom color scheme

## Compilation

```bash
typst compile presentation.typ

# Or watch mode
typst watch presentation.typ
```

## Tips

1. Keep slides minimal - one idea per slide
2. Use large font sizes (20pt+)
3. Limit bullet points to 3-5 per slide
4. Use visuals where possible
