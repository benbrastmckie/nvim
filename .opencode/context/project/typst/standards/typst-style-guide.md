# Typst Style Guide

**Created**: 2026-02-27
**Purpose**: Coding style conventions for Typst documents in this project

---

## General Principles

1. **Consistency**: Follow established patterns in existing documents
2. **Readability**: Clear structure over clever shortcuts
3. **Modularity**: Separate concerns into files
4. **Documentation**: Comment non-obvious code

## File Organization

### Naming Conventions

```
document-name.typ          # Main document (kebab-case)
notation/shared-notation.typ    # Notation modules
chapters/01-introduction.typ    # Numbered chapters
template.typ               # Project template
```

### Import Order

```typst
// 1. External packages
#import "@preview/thmbox:0.1.0": *
#import "@preview/fletcher:0.5.5": *

// 2. Local template
#import "template.typ": *

// 3. Notation modules
#import "notation/shared-notation.typ": *
#import "notation/theory-notation.typ": *
```

## Formatting

### Indentation

- Use 2 spaces for indentation
- Align related elements

```typst
#let theorem = thmbox(
  "theorem",
  "Theorem",
  fill: luma(240),
)
```

### Line Length

- Target 80-100 characters per line
- Break long function calls

```typst
// Good
#show heading.where(level: 1): it => {
  v(1em)
  text(size: 14pt, weight: "bold", it)
}

// Avoid very long lines
#show heading.where(level: 1): it => { v(1em); text(size: 14pt, weight: "bold", it) }
```

## Notation Definitions

### Standard Pattern

```typst
// notation/shared-notation.typ

// Section: Number Sets
#let R = math.bb("R")
#let N = math.bb("N")

// Section: Operators
#let implies = sym.arrow.r.double
```

### Naming Conventions

- Use descriptive names: `semanticBrackets` not `sb`
- Prefix related items: `modal-Box`, `modal-Diamond`
- Use camelCase for functions, kebab-case for files

## Labels and References

### Label Naming

```typst
// Pattern: type:name
= Introduction <ch:introduction>
== Background <sec:background>

#theorem("Completeness") <thm:completeness>
#definition("Model") <def:model>
```

### Referencing

```typst
// Use @ for references
See @ch:introduction for details.
By @thm:completeness, we have...
```

## Comments

### Documentation Comments

```typst
// =============================================================================
// THEOREM ENVIRONMENTS
// =============================================================================

// Main theorem box - used for primary results
#let theorem = thmbox("theorem", "Theorem", fill: luma(240))

// Lemma box - supporting results
#let lemma = thmbox("lemma", "Lemma", fill: luma(245))
```

### Inline Comments

```typst
#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),  // Standard academic margins
)
```

## Best Practices

1. **Pin package versions**: Always specify version in imports
2. **Avoid magic numbers**: Define constants for repeated values
3. **Test changes**: Compile after each significant change
4. **Use git**: Commit working states frequently
5. **Read compiler messages**: Typst errors are usually clear
