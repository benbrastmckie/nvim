# Typst Style Guide

## Document Setup

### Package Imports

Place package imports at the top of the main document:

```typst
// External packages from preview registry
#import "@preview/cetz:0.3.4"
#import "@preview/thmbox:0.3.0" as thmbox

// Local notation and template
#import "notation/project-notation.typ": *
#import "template.typ": thmbox-show, definition, theorem, lemma, remark, proof
```

### Document Metadata

Set document metadata early:

```typst
#set document(
  title: "Document Title",
  author: "Author Name",
)
```

---

## Typography Settings

### Font Configuration

Use New Computer Modern for LaTeX-like appearance:

```typst
#set text(font: "New Computer Modern", size: 11pt)
```

### Paragraph Settings

Match LaTeX paragraph behavior:

```typst
#set par(
  justify: true,
  leading: 0.55em,           // Line spacing
  spacing: 0.55em,           // Paragraph spacing
  first-line-indent: 1.8em,  // First-line indent
)
```

### Page Layout

Professional margins:

```typst
#set page(
  numbering: "1",
  number-align: center,
  margin: (x: 1.5in, y: 1.25in),
)
```

### Heading Configuration

```typst
#set heading(numbering: "1.1")
#show heading: set block(above: 1.4em, below: 1em)
```

---

## Show Rules

### Global Text Substitutions

Automatically style specific text:

```typst
// Bold "TM" throughout document
#show "TM": strong
```

### Link Styling

Style hyperlinks with a consistent color:

```typst
#let URLblue = rgb(0, 0, 150)
#show link: set text(fill: URLblue)
```

### URL Text Formatting

Use `raw()` for monospace URL display:

```typst
// URL with monospace text display
#link("https://www.example.com")[#raw("www.example.com")]

// Citation links
See #link("https://arxiv.org/abs/2401.12345")[#raw("arxiv.org/abs/2401.12345")]
```

### Theorem Environment Initialization

Enable thmbox theorem environments:

```typst
#show: thmbox-show
```

### Breakable Figures

Allow theorem boxes to break across pages:

```typst
#show figure.where(kind: "thmbox"): set block(breakable: true)
```

---

## Code Conventions

### File Organization

1. Package imports (external, then local)
2. Document metadata
3. Typography settings (`#set` rules)
4. Page layout
5. Show rules
6. Custom commands/functions
7. Content (title page, abstract, chapters)

### Naming Conventions

- **Files**: lowercase with hyphens (`shared-notation.typ`)
- **Functions**: snake_case for internal, camelCase avoided
- **Let bindings**: lowercase with descriptive names

### Comments

Use `//` for single-line comments:

```typst
// ============================================================================
// Section Header
// ============================================================================
```

---

## Math Mode

### Inline Math

```typst
The formula $phi.alt arrow.r psi$ represents implication.
```

### Display Math

```typst
$
  phi.alt, psi ::= p | bot | phi.alt arrow.r psi | square.stroked phi.alt
$
```

### Math Symbols

Use Typst symbol names (similar to Unicode names):
- `square.stroked` for box
- `diamond.stroked` for diamond
- `arrow.r` for right arrow
- `phi.alt` for Greek letters

---

## Tables

### Standard Table Format

```typst
#figure(
  table(
    columns: 4,
    stroke: none,
    table.hline(),
    table.header(
      [*Symbol*], [*Name*], [*Code*], [*Reading*],
    ),
    table.hline(),
    [$p$], [Atom], [`atom s`], [sentence letter],
    // ... more rows
    table.hline(),
  ),
  caption: none,
)
```

---

## Content Blocks

### Styled Block Pattern

Use `block()` for visually distinct content sections:

```typst
#let styled-section(title, body, ..metadata) = {
  block(
    width: 100%,
    inset: (left: 1.5em, y: 0.5em),
    above: 0.8em,
    below: 0.8em,
  )[
    #strong[#title]
    #v(0.3em)
    #body
  ]
}
```

**Key parameters**:
- `inset`: Internal padding (can be asymmetric: `(left: 1.5em, y: 0.5em)`)
- `above`/`below`: Spacing from surrounding content
- `width: 100%`: Ensure block spans full width

---

## List Environments

Typst provides three native list types.

### List Type Selection

| Pattern | Use When | Syntax |
|---------|----------|--------|
| Bullet list | Standalone items without term-definition structure | `- Item` |
| Numbered list | Ordered sequences, procedural steps | `+ Item` or `1. Item` |
| Term list | Term-definition pairs, labeled sections, metadata | `/ Term: Description` |

### Standard List Requirement

All bullet lists MUST use standard Typst list syntax (`- Item`). Manual list formatting breaks semantic structure and may cause rendering inconsistencies.

### Term List Syntax

The term list (description list) uses `/` prefix with colon separator:

```typst
/ Notation: We use standard mathematical notation throughout. Special symbols
  are defined when first introduced.

/ Prerequisites: Chapter 1 (Foundations).

/ Connection: Order theory underlies the state-space structure.
```

Descriptions can span multiple lines with hanging indent automatically applied.

### Term List Use Cases

**DO use term lists for:**
- Convention definitions (`/ Notation:`, `/ Exercises:`)
- Chapter metadata (`/ Prerequisites:`, `/ Connection:`)
- Glossary entries and definitions
- Any content with clear term-definition structure

**DO NOT use term lists for:**
- Items followed by display math blocks (use bold-prefix paragraphs instead)
- Standalone items without definitions (use bullet lists)
- Numbered sequences or procedural steps (use numbered lists)

---

## Custom Commands

### Horizontal Rule

```typst
#let HRule = line(length: 100%, stroke: 0.5pt)
```

### Semantic Functions

```typst
#let tuple(..args) = $lr(angle.l #args.pos().join(", ") angle.r)$
#let overset(base, top) = $limits(#base)^#top$
```

---

## Anti-Patterns

**Avoid**:
- Using `#show` rules in chapter files (keep in main document)
- Redefining standard functions without clear purpose
- Hardcoding colors (use named constants like `URLblue`)
- Mixing content with configuration in the same section

---

## Prose Conventions

### One Sentence Per Line

**Rule**: In Typst source files, place each sentence on its own line.

**Rationale**:
- Git diffs become more meaningful (one sentence change = one line change)
- Easier to reorder sentences
- Facilitates sentence-level review
- Avoids artificial line breaks mid-sentence

**Correct**:
```typst
This is the first sentence explaining the concept.
The second sentence provides additional detail.
Finally, we conclude with a summary statement.
```

**Incorrect**:
```typst
This is the first sentence explaining the concept. The second sentence
provides additional detail. Finally, we conclude with a summary
statement.
```

### Em-Dash Spacing

**Rule**: When using em-dashes (`---`), always follow them with a space.

**Correct**:
```typst
The formalism provides a foundation--- one that captures the essence.
```

**Incorrect**:
```typst
The formalism provides a foundation---one that captures the essence.
```

### No Rhetorical Questions

**Rule**: Do not use rhetorical questions in prose. Rephrase as declarative statements.

**Incorrect**:
```typst
Why do we need dependent types? Consider the following example...
```

**Correct**:
```typst
The need for dependent types becomes clear when we consider the following example...
```
