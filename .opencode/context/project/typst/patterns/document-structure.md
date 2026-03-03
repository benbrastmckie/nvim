# Typst Document Structure

**Created**: 2026-02-27
**Purpose**: Patterns for organizing Typst documents

---

## Main Document Organization

### Standard Layout

```typst
// document.typ - Main entry point

// 1. Package imports
#import "@preview/thmbox:0.1.0": *
#import "@preview/fletcher:0.5.5": *

// 2. Local imports
#import "template.typ": *
#import "notation/shared-notation.typ": *

// 3. Document setup
#set document(
  title: "Document Title",
  author: "Author Name",
)

// 4. Page setup
#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
)

// 5. Text setup
#set text(
  font: "New Computer Modern",
  size: 11pt,
)

// 6. Show rules
#show heading.where(level: 1): set text(size: 14pt)

// 7. Front matter
#include "chapters/00-introduction.typ"

// 8. Main content
#include "chapters/01-syntax.typ"
#include "chapters/02-semantics.typ"
```

## Chapter Structure

### Chapter Template

```typst
// chapters/01-chapter.typ

= Chapter Title <chapter-label>

#lorem(50)

== Section One <section-label>

Content here.

=== Subsection

More content.
```

## Modular Notation

### Shared Notation Module

```typst
// notation/shared-notation.typ

// Number sets
#let R = math.bb("R")
#let N = math.bb("N")
#let Z = math.bb("Z")

// Operators
#let implies = math.op("=>")
#let iff = math.op("<=>")

// Formatting
#let code(body) = raw(body, lang: "lean")
```

### Theory-Specific Notation

```typst
// notation/bimodal-notation.typ

// Modal operators
#let Box = math.class("unary", sym.ballot)
#let Diamond = math.class("unary", sym.lozenge)

// Semantic brackets
#let sem(body) = $bracket.l.double #body bracket.r.double$
```

## Import Patterns

### Selective Imports

```typst
// Import specific items
#import "@preview/thmbox:0.1.0": thmbox

// Import all
#import "@preview/thmbox:0.1.0": *
```

### Re-exports

```typst
// template.typ - Collect all project definitions
#import "@preview/thmbox:0.1.0": *

#let theorem = thmbox("theorem", "Theorem")
#let definition = thmbox("definition", "Definition")

// Export for use in chapters
// (chapters import template.typ)
```

## Best Practices

1. **Single entry point**: One main .typ file that includes others
2. **Modular notation**: Separate notation files by theory/domain
3. **Template file**: Central place for theorem definitions and show rules
4. **Consistent labeling**: Use `<label>` for cross-references
5. **Chapter organization**: One file per major section
