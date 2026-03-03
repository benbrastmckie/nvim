# Typst Report Template

**Created**: 2026-02-27
**Purpose**: Template for technical reports in Typst

---

## Template Structure

```typst
// report.typ - Technical Report Template

// Package imports
#import "@preview/thmbox:0.1.0": *

// Document metadata
#set document(
  title: "Technical Report Title",
  author: "Author Name",
  date: datetime.today(),
)

// Page setup
#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
  header: context {
    if counter(page).get().first() > 1 [
      _Technical Report Title_
      #h(1fr)
      #counter(page).display("1 / 1", both: true)
    ]
  },
  footer: [],
)

// Text setup
#set text(
  font: "New Computer Modern",
  size: 11pt,
)

// Paragraph setup
#set par(justify: true, leading: 0.65em)

// Heading setup
#set heading(numbering: "1.1")
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  v(1em)
  text(size: 16pt, weight: "bold", it)
  v(0.5em)
}

// Code blocks
#show raw.where(block: true): block.with(
  fill: luma(245),
  inset: 10pt,
  radius: 4pt,
  width: 100%,
)

// Theorem environments
#let definition = thmbox("definition", "Definition", fill: rgb("#e8f4f8"))
#let remark = thmbox("remark", "Remark", fill: luma(248))

// Title page
#align(center)[
  #v(3cm)

  #text(size: 24pt, weight: "bold")[
    Technical Report Title
  ]

  #v(1cm)

  #text(size: 14pt)[
    Author Name
  ]

  #v(0.5cm)

  #text(size: 12pt)[
    Organization/Institution
  ]

  #v(1cm)

  #text(size: 12pt)[
    #datetime.today().display("[month repr:long] [day], [year]")
  ]

  #v(2cm)

  #line(length: 50%, stroke: 0.5pt)

  #v(0.5cm)

  #par(first-line-indent: 0em)[
    *Abstract.* #lorem(100)
  ]
]

#pagebreak()

// Table of contents
#outline(title: "Contents", indent: 2em)

#pagebreak()

// Main content
= Introduction

#lorem(100)

= Background

#lorem(100)

== Technical Details

#lorem(80)

= Methodology

#lorem(100)

= Results

#lorem(100)

= Conclusion

#lorem(50)

// Appendices
= Appendix A: Supplementary Material <appendix-a>

#lorem(50)

// Bibliography
#bibliography("references.bib")
```

## Features

- Title page with metadata
- Table of contents
- Page headers with page numbers
- Styled code blocks
- Appendix support
- Bibliography

## Usage Notes

1. Reports typically have more formal structure than articles
2. Include table of contents for longer documents
3. Use appendices for supplementary material
4. Consider version control in document metadata
