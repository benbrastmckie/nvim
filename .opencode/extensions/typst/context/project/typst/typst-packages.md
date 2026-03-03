# Typst Packages

**Created**: 2026-02-27
**Purpose**: Overview of key Typst packages used in the project

---

## Package Management

Typst packages are imported from the `@preview/` namespace:

```typst
#import "@preview/package-name:version": *
```

Packages are automatically downloaded on first use.

## Core Packages

### thmbox - Theorem Environments

**Import**: `#import "@preview/thmbox:0.1.0": *`

Creates LaTeX-style theorem environments.

```typst
#let theorem = thmbox("theorem", "Theorem", fill: luma(240))
#let lemma = thmbox("lemma", "Lemma", fill: luma(245))
#let definition = thmbox("definition", "Definition", fill: rgb("#e8f4f8"))

#theorem("Pythagoras")[
  In a right triangle: $a^2 + b^2 = c^2$
]
```

### cetz - Diagrams

**Import**: `#import "@preview/cetz:0.3.2": *`

TikZ-like drawing library for diagrams.

```typst
#canvas({
  import draw: *
  circle((0, 0), radius: 1)
  line((0, 0), (1, 0))
})
```

### fletcher - Arrow Diagrams

**Import**: `#import "@preview/fletcher:0.5.5": *`

Commutative diagrams and flowcharts.

```typst
#diagram(
  node((0, 0), $A$),
  node((1, 0), $B$),
  edge((0, 0), (1, 0), "->"),
)
```

### tablex - Advanced Tables

**Import**: `#import "@preview/tablex:0.0.8": *`

Extended table functionality.

```typst
#tablex(
  columns: 3,
  [Header 1], [Header 2], [Header 3],
  [Cell 1], [Cell 2], [Cell 3],
)
```

### polylux - Presentations

**Import**: `#import "@preview/polylux:0.3.1": *`

Beamer-like presentations.

```typst
#polylux-slide[
  = Slide Title
  Content here
]
```

## Project-Specific Usage

### Bimodal Reference Manual

```typst
// BimodalReference.typ
#import "@preview/thmbox:0.1.0": *
#import "@preview/fletcher:0.5.5": *

// Define theorem environments
#let theorem = thmbox("theorem", "Theorem")
#let definition = thmbox("definition", "Definition")
```

## Package Discovery

Find packages at [Typst Universe](https://typst.app/universe/):

- Browse by category (math, science, layout, etc.)
- Check version compatibility
- Read documentation and examples

## Package Versions

Always pin specific versions for reproducibility:

```typst
// Good - pinned version
#import "@preview/thmbox:0.1.0": *

// Avoid - may break with updates
#import "@preview/thmbox": *
```

## Creating Local Packages

For project-specific functionality:

```typst
// notation/shared-notation.typ
#let R = math.bb("R")
#let N = math.bb("N")

// Main document
#import "notation/shared-notation.typ": *
```
