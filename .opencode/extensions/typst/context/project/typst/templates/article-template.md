# Typst Article Template

**Created**: 2026-02-27
**Purpose**: Template for academic articles in Typst

---

## Template Structure

```typst
// article.typ - Article Template

// Package imports
#import "@preview/thmbox:0.1.0": *

// Document metadata
#set document(
  title: "Article Title",
  author: ("Author One", "Author Two"),
  keywords: ("keyword1", "keyword2"),
)

// Page setup
#set page(
  paper: "us-letter",
  margin: (x: 1in, y: 1in),
  numbering: "1",
)

// Text setup
#set text(
  font: "New Computer Modern",
  size: 11pt,
)

// Paragraph setup
#set par(
  justify: true,
  leading: 0.65em,
  first-line-indent: 1em,
)

// Heading setup
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => {
  v(1em)
  text(size: 14pt, weight: "bold", it)
  v(0.5em)
}

// Theorem environments
#let theorem = thmbox("theorem", "Theorem", fill: luma(240))
#let lemma = thmbox("lemma", "Lemma", fill: luma(245))
#let definition = thmbox("definition", "Definition", fill: rgb("#e8f4f8"))
#let example = thmbox("example", "Example", fill: rgb("#f8f8e8"))

// Title block
#align(center)[
  #text(size: 18pt, weight: "bold")[Article Title]

  #v(0.5em)

  #text(size: 12pt)[
    Author One#super[1], Author Two#super[2]
  ]

  #v(0.3em)

  #text(size: 10pt, style: "italic")[
    #super[1]Institution One \
    #super[2]Institution Two
  ]
]

#v(1em)

// Abstract
#par(first-line-indent: 0em)[
  *Abstract.* #lorem(80)
]

#v(1em)

// Main content starts here
= Introduction

#lorem(100)

= Background

#lorem(100)

== Related Work

#lorem(80)

= Main Results

#theorem("Main Theorem")[
  Statement of the main theorem.
]

#lemma[
  Supporting lemma.
]

= Conclusion

#lorem(50)

// Bibliography
#bibliography("references.bib")
```

## Usage

1. Copy template to your project
2. Replace placeholder content
3. Add your bibliography file
4. Compile with `typst compile article.typ`

## Customization Points

- **Fonts**: Change `font` in `#set text`
- **Colors**: Modify theorem `fill` colors
- **Margins**: Adjust `margin` in `#set page`
- **Numbering**: Change `numbering` patterns
