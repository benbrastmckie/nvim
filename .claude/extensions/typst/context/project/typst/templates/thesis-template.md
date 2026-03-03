# Typst Thesis Template

**Created**: 2026-02-27
**Purpose**: Template for thesis and dissertation documents

---

## Template Structure

```typst
// thesis.typ - Thesis Template

#import "@preview/thmbox:0.1.0": *

// Document metadata
#set document(
  title: "Thesis Title",
  author: "Student Name",
)

// Page setup
#set page(
  paper: "a4",
  margin: (inside: 3.5cm, outside: 2.5cm, y: 2.5cm),
  numbering: "1",
)

// Text setup
#set text(
  font: "New Computer Modern",
  size: 12pt,
)

// Paragraph setup
#set par(
  justify: true,
  leading: 1.5em,
  first-line-indent: 1.5em,
)

// Heading setup
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => {
  pagebreak()
  v(3em)
  text(size: 20pt, weight: "bold")[#it]
  v(2em)
}

// Chapter header
#show heading.where(level: 1): it => {
  pagebreak()
  align(center)[
    #v(3cm)
    #text(size: 14pt)[Chapter #counter(heading).display()]
    #v(1em)
    #text(size: 24pt, weight: "bold")[#it.body]
    #v(3cm)
  ]
}

// Theorem environments
#let theorem = thmbox("theorem", "Theorem", fill: luma(245))
#let lemma = thmbox("lemma", "Lemma", fill: luma(248))
#let definition = thmbox("definition", "Definition", fill: rgb("#e8f4f8"))
#let proposition = thmbox("proposition", "Proposition", fill: luma(245))
#let corollary = thmbox("corollary", "Corollary", fill: luma(248))
#let proof = thmbox("proof", "Proof", fill: none).with(numbering: none)

// Front matter (no page numbers initially)
#set page(numbering: none)

// Title page
#align(center)[
  #v(2cm)
  #text(size: 14pt)[UNIVERSITY NAME]
  #v(1cm)
  #text(size: 12pt)[Department of Subject]
  #v(3cm)
  #text(size: 24pt, weight: "bold")[
    Thesis Title: \
    A Very Long and Descriptive Title
  ]
  #v(3cm)
  #text(size: 14pt)[
    A thesis submitted for the degree of \
    *Doctor of Philosophy*
  ]
  #v(2cm)
  #text(size: 14pt)[
    Student Name \
    Student ID: 12345678
  ]
  #v(2cm)
  #text(size: 12pt)[
    Supervisor: Prof. Name \
    Co-supervisor: Dr. Name
  ]
  #v(2cm)
  #text(size: 12pt)[
    #datetime.today().display("[month repr:long] [year]")
  ]
]

#pagebreak()

// Abstract
#align(center)[
  #text(size: 16pt, weight: "bold")[Abstract]
]
#v(1em)

#lorem(200)

#pagebreak()

// Acknowledgments
#align(center)[
  #text(size: 16pt, weight: "bold")[Acknowledgments]
]
#v(1em)

#lorem(100)

#pagebreak()

// Table of contents
#set page(numbering: "i")
#counter(page).update(1)

#outline(
  title: "Contents",
  indent: 2em,
  depth: 3,
)

#pagebreak()

// List of figures
#outline(
  title: "List of Figures",
  target: figure.where(kind: image),
)

#pagebreak()

// List of tables
#outline(
  title: "List of Tables",
  target: figure.where(kind: table),
)

// Main matter
#set page(numbering: "1")
#counter(page).update(1)

= Introduction

#lorem(200)

== Motivation

#lorem(150)

== Contributions

#lorem(100)

= Background

#lorem(200)

== Related Work

#lorem(150)

= Methodology

#lorem(200)

#definition("Key Concept")[
  Definition of an important concept.
]

#theorem("Main Result")[
  Statement of the main theorem.
]

= Results

#lorem(200)

= Conclusion

#lorem(100)

// Back matter
#set heading(numbering: none)

= Bibliography
#bibliography("references.bib", title: none)

= Appendix A: Supplementary Material
#lorem(100)
```

## Features

- Proper front matter (title, abstract, acknowledgments)
- Roman numerals for preliminary pages
- Chapter-style headings
- Theorem environments
- List of figures/tables
- Appendices
- Bibliography

## Usage Notes

1. Adjust margins for binding (inside margin larger)
2. Use 1.5 or double line spacing as required
3. Include required institutional pages
4. Check citation style requirements
