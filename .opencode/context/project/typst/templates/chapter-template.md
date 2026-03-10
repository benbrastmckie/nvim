# Chapter Template

## Template

Copy and modify this template when creating new chapters:

```typst
// ============================================================================
// NN-{topic}.typ
// {Topic} chapter for Reference Manual
// ============================================================================

#import "../template.typ": *

= {Chapter Title}

{Brief introductory paragraph explaining the chapter's purpose and content.}

== {First Section}

{Section content...}

#definition("{Definition Name}")[
  {Definition content...}
]

== {Second Section}

{Section content...}

#theorem("{Theorem Name}")[
  {Theorem statement...}
]

#proof[
  {Proof content...}
]

== {Third Section}

{Additional content as needed...}
```

---

## File Naming

Format: `NN-{topic}.typ`

- `NN` = two-digit chapter number (00, 01, 02, ...)
- `{topic}` = lowercase topic name with hyphens

Examples:
- `00-introduction.typ`
- `01-syntax.typ`
- `02-semantics.typ`
- `03-proof-theory.typ`

---

## Chapter Structure Guidelines

### Import Statement

Always exactly one import:

```typst
#import "../template.typ": *
```

This provides:
- All notation commands (from shared/project notation)
- Theorem environments (definition, theorem, lemma, axiom, remark, proof)
- Color definitions (URLblue)

### Main Heading

One level-1 heading per chapter (the chapter title):

```typst
= Chapter Title
```

### Sections

Use level-2 headings for major sections:

```typst
== Section Name
```

### Subsections

Use level-3 headings sparingly:

```typst
=== Subsection Name
```

---

## Content Patterns

### Chapter Intro Metadata Block

Most chapters begin with an italic summary followed by Prerequisites and Connection metadata. Use term list syntax (`/ Term:`) for these enumerated prose items:

```typst
= Chapter Title

_This chapter develops the theory of..._

/ Prerequisites: Chapter 1 (Foundations).

/ Connection: The concepts in this chapter underlie...
```

**Key points:**
- Opening italic summary is a standalone paragraph (not a term list item)
- Use `/ Prerequisites:` and `/ Connection:` term list syntax
- Multi-line descriptions wrap naturally with hanging indent
- Separate each term list item with a blank line for readability

**Anti-pattern to avoid:**
```typst
*Prerequisites*: Chapter 1...  // Wrong: bold-prefix paragraph
```

### Opening Paragraph

Every chapter should begin with a brief overview:

```typst
= Syntax

This chapter defines the formula language. We begin with the
primitive constructors, then derive standard operators.
```

### Definition Blocks

```typst
#definition("Name")[
  Content in upright text.
  $
    formula &:= definition
  $
]
```

### Theorem/Lemma Blocks

```typst
#theorem("Name")[
  Statement in italic (automatic via theorem-style).
]

#proof[
  Proof content in upright text.
]
```

### Tables

```typst
#figure(
  table(
    columns: 4,
    stroke: none,
    table.hline(),
    table.header(
      [*Header1*], [*Header2*], [*Header3*], [*Header4*],
    ),
    table.hline(),
    [Cell1], [Cell2], [Cell3], [Cell4],
    // more rows...
    table.hline(),
  ),
  caption: none,  // or [Caption text]
)
```

---

## Example: Minimal Chapter

```typst
// ============================================================================
// 07-extensions.typ
// Extensions chapter for Reference Manual
// ============================================================================

#import "../template.typ": *

= Extensions

This chapter discusses potential extensions.

== Branching Time

One natural extension is to branching temporal structures.

#definition("Branching Frame")[
  A branching frame is a tuple $tuple(W, <)$ where $<$ is a tree order.
]

== Multi-Agent Modality

Another extension adds agent-indexed modalities.

#remark[
  Multi-agent extensions require careful treatment of common knowledge.
]
```

---

## Checklist for New Chapters

- [ ] File named `NN-{topic}.typ` with correct number
- [ ] Single import: `#import "../template.typ": *`
- [ ] One level-1 heading (chapter title)
- [ ] Opening paragraph explaining chapter purpose
- [ ] Chapter intro metadata block using `/ Term:` syntax (Prerequisites, Connection)
- [ ] No `#set` or `#show` rules (all in main document)
- [ ] No package imports (all through template.typ)
- [ ] Labels added to key definitions/theorems
- [ ] Added to main document's `#include` list

---

## Adding Chapter to Main Document

In `MainDocument.typ`, add an include statement:

```typst
#include "chapters/00-introduction.typ"
#include "chapters/01-syntax.typ"
// ...
#include "chapters/NN-{topic}.typ"  // New chapter
```

Keep includes in numerical order.
