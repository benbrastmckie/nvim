# Document Structure

## Project Document Layout

### Directory Structure

```
project/typst/
├── MainDocument.typ          # Main document
├── template.typ              # Shared template (theorem environments)
├── notation/
│   ├── shared-notation.typ   # Common notation
│   └── project-notation.typ  # Project-specific notation
└── chapters/
    ├── 00-introduction.typ
    ├── 01-topic-one.typ
    ├── 02-topic-two.typ
    └── ...
```

### File Naming

- **Main document**: `MainDocument.typ` (e.g., `Reference.typ`)
- **Chapters**: Two-digit prefix `NN-{topic}.typ` (e.g., `01-syntax.typ`)
- **Notation**: `{project}-notation.typ` or `shared-notation.typ`
- **Template**: `template.typ` (shared across chapters)

---

## Main Document Structure

### Organization

The main document follows this structure:

```typst
// ============================================================================
// 1. Package Imports
// ============================================================================
#import "@preview/cetz:0.3.4"
#import "@preview/thmbox:0.3.0" as thmbox
#import "notation/project-notation.typ": *
#import "template.typ": thmbox-show, definition, theorem, ...

// ============================================================================
// 2. Document Configuration
// ============================================================================
#set document(title: "...", author: "...")
#set text(font: "New Computer Modern", size: 11pt)
#set heading(numbering: "1.1")
#set par(justify: true, leading: 0.55em, ...)
#set page(numbering: "1", margin: ...)

// ============================================================================
// 3. Show Rules
// ============================================================================
#show heading: set block(above: 1.4em, below: 1em)
#show: thmbox-show
#show link: set text(fill: URLblue)
#show figure.where(kind: "thmbox"): set block(breakable: true)

// ============================================================================
// 4. Custom Commands
// ============================================================================
#let HRule = line(length: 100%, stroke: 0.5pt)

// ============================================================================
// 5. Title Page
// ============================================================================
#page(numbering: none)[
  // Title, author, date, primary references
]

// ============================================================================
// 6. Abstract and Table of Contents
// ============================================================================
#page(numbering: none)[
  // Abstract
  // Table of contents with outline()
]

#pagebreak()

// ============================================================================
// 7. Content Includes
// ============================================================================
#include "chapters/00-introduction.typ"
#include "chapters/01-topic-one.typ"
#include "chapters/02-topic-two.typ"
// ...
```

### Title Page Pattern

```typst
#page(numbering: none)[
  #v(2cm)
  #align(center)[
    #HRule
    #v(0.4cm)
    #text(size: 24pt, weight: "bold")[Document Title]
    #v(0.2cm)
    #HRule
    #v(.5cm)

    #text(size: 18pt, style: "italic")[Subtitle]
    #v(1cm)

    #text(size: 12pt, style: "italic")[Author Name]
    #v(0.0cm)
    #link("https://...")[#raw("www.example.com")]
    #v(0.0cm)
    --- #datetime.today().display("[month repr:long] [day], [year]") ---
    #v(1cm)

    #v(1fr)

    #text(size: 11pt, weight: "bold")[Primary Reference:]
    #v(0.3cm)
    #link("https://...")[_"Paper Title"_], Author, Year.
    #v(1cm)
  ]
]
```

### Abstract and TOC Pattern

```typst
#page(numbering: none)[
  #align(center)[
    #text(size: 14pt, weight: "bold")[Abstract]
  ]
  #v(0.5em)

  Abstract text here...

  #v(1cm)
  // Style TOC entries
  #show outline.entry.where(level: 1): it => {
    v(0.5em)
    strong(it)
  }
  #outline(title: "Contents", indent: auto)
]
```

---

## Chapter Structure

### Standard Chapter Format

```typst
// ============================================================================
// NN-{topic}.typ
// {Topic} chapter for Reference Manual
// ============================================================================

#import "../template.typ": *

= Chapter Title

== Section Title

Content text...

#definition("Definition Name")[
  Definition content...
]

#theorem("Theorem Name")[
  Theorem statement...
]

#proof[
  Proof content...
]

== Another Section

More content...
```

### Chapter Guidelines

1. **Single import**: Only `#import "../template.typ": *`
2. **Level-1 heading**: One `=` heading per chapter (chapter title)
3. **Level-2 headings**: `==` for major sections
4. **Level-3 headings**: `===` for subsections (use sparingly)
5. **No configuration**: No `#set` or `#show` rules in chapters
6. **No package imports**: All imports go through template.typ

---

## Template Structure

### template.typ Organization

```typst
// ============================================================================
// template.typ
// Shared template with theorem environments for all chapters
// ============================================================================

#import "@preview/thmbox:0.3.0" as thmbox
#import "notation/project-notation.typ": *

// Color definitions
#let URLblue = rgb(0, 0, 150)

// thmbox initialization
#let thmbox-show = thmbox.thmbox-init()

// Custom theorem styles (AMS aesthetic)
#let theorem-style = (
  fill: none,
  stroke: none,
  bodyfmt: it => emph(it),
)

#let definition-style = (
  fill: none,
  stroke: none,
)

// Re-export thmbox environments with custom styling
#let definition = thmbox.definition.with(..definition-style)
#let theorem = thmbox.theorem.with(..theorem-style)
#let lemma = thmbox.lemma.with(..theorem-style)
#let remark = thmbox.remark.with(..remark-style)
#let proof = thmbox.proof
```

### What Goes in template.typ

- Theorem environment definitions
- Color constants (URLblue)
- thmbox initialization function
- Custom styles for theorem environments
- Re-exports of notation (via import chain)

### What Does NOT Go in template.typ

- Document metadata (`#set document`)
- Page settings (`#set page`)
- Typography settings (`#set text`, `#set par`)
- Show rules (`#show ...`)
- Content

---

## Content Organization

### Typical Chapter Sequence

1. **00-introduction.typ** - Overview, motivation, structure guide
2. **01-foundations.typ** - Basic definitions, primitives
3. **02-core-theory.typ** - Main definitions, truth conditions
4. **03-metatheory.typ** - Key theorems, proofs
5. **04-extensions.typ** - Additional material
6. **05-notes.typ** - Implementation notes, references

### Cross-Chapter References

Use Typst's label and reference system:

```typst
// In one chapter
#theorem("Important Result") <thm-important>

// In another chapter
See @thm-important for details.
```

---

## Best Practices

1. **Keep chapters self-contained**: Each chapter should be readable independently
2. **Use consistent naming**: Match file names to content topics
3. **Minimize dependencies**: Chapters depend only on template.typ
4. **Document structure in introduction**: First chapter explains document organization
5. **Group related content**: Use sections and subsections logically
