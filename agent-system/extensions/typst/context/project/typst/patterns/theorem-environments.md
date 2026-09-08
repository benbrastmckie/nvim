# Typst Theorem Environments

## Using thmbox Package

```typst
#import "@preview/thmbox:0.2.0": *

// Setup theorem environments
#show: thmbox-init

// Define environments
#let theorem = thmbox("thm", "Theorem", color: blue)
#let lemma = thmbox("lem", "Lemma", color: blue)
#let definition = thmbox("def", "Definition", color: green)
#let example = thmbox("ex", "Example", color: purple)
#let remark = thmbox("rem", "Remark", color: gray)
```

## Semantics

This file documents mechanics only — how to invoke each environment. What each environment is
*for*, how sparingly to reach for it, and where it may legally appear relative to headings and
results are governed by `standards/semantic-element-usage.md`. One rule from that file is
load-bearing enough to inline here: **a semantic element is never the first body content after a
heading** — every heading opens with prose, and the environments below come after it.

## Usage

### Basic Theorem
```typst
#theorem[
  Every vector space has a basis.
]
```

### Named Theorem
```typst
#theorem("Pythagorean")[
  In a right triangle, $a^2 + b^2 = c^2$.
]
```

### Labeled for Reference
```typst
#theorem("Completeness")[
  If $Gamma models phi$, then $Gamma tack phi$.
] <thm:completeness>

By @thm:completeness, ...
```

## Proofs

```typst
#proof[
  We proceed by induction.
  ...
  #qed
]
```

## Custom Styling

```typst
#let custom-theorem = thmbox(
  "thm",
  "Theorem",
  color: rgb("#1e90ff"),
  title-style: (weight: "bold"),
  body-style: (style: "italic"),
)
```

## Label Conventions

| Prefix | Environment |
|--------|-------------|
| `thm:` | Theorem |
| `lem:` | Lemma |
| `def:` | Definition |
| `cor:` | Corollary |
| `ex:` | Example |
| `rem:` | Remark |
