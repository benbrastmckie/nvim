# Typst Context

**Created**: 2026-02-27
**Purpose**: Context files for Typst document implementation tasks

---

## Overview

Typst is a modern typesetting system used in this project for technical documentation, primarily for the Bimodal logic reference manual at `Theories/Bimodal/typst/`.

### Key Characteristics

- **Single-pass compilation** via `typst compile` (no multi-pass like LaTeX)
- **Package management** via `@preview/` imports (e.g., thmbox, cetz)
- **Modular structure** with `#import` and `#include` statements
- **LaTeX-like typography** via New Computer Modern font

### Project Usage

Primary document: `Theories/Bimodal/typst/BimodalReference.typ`

Structure:
```
Theories/Bimodal/typst/
  BimodalReference.typ      # Main document
  template.typ              # Theorem environments (thmbox)
  notation/
    shared-notation.typ   # Common notation across theories
    bimodal-notation.typ  # Bimodal-specific notation
  chapters/
    00-introduction.typ
    01-syntax.typ
    02-semantics.typ
    ...
```

---

## Context Files

### Domain Overview
- **typst-overview.md** - Introduction to Typst
- **typst-vs-latex.md** - Comparison and migration guide
- **typst-packages.md** - Package ecosystem overview

### Patterns
- **document-structure.md** - Main document and chapter organization
- **styling-patterns.md** - Set rules, show rules, typography
- **bibliography.md** - Citations and references
- **tables-and-figures.md** - Tables, figures, diagrams
- **math-typesetting.md** - Mathematical notation

### Templates
- **article-template.md** - Academic article template
- **report-template.md** - Technical report template
- **presentation-template.md** - Slides with Polylux
- **thesis-template.md** - Thesis/dissertation template

### Standards
- **typst-style-guide.md** - Coding conventions
- **compilation-standards.md** - Build workflow standards
- **package-usage.md** - Package management guidelines

### Tools
- **compilation-guide.md** - `typst compile` and `typst watch` usage

---

## Loading Strategy

For Typst implementation tasks, load:
1. This README.md (overview)
2. Relevant patterns based on task
3. Template if creating new document
4. Compilation guide for verification

---

## Differences from LaTeX

| Aspect | LaTeX | Typst |
|--------|-------|-------|
| Compilation | Multi-pass (pdflatex x3) | Single-pass |
| Bibliography | bibtex/biber separate | Built-in |
| Packages | `\usepackage{}` | `#import "@preview/"` |
| Syntax | Commands `\cmd{}` | Functions `#cmd()` |
| Math mode | `$...$` or `\[...\]` | `$...$` |
| Show rules | N/A | `#show: rule` |
