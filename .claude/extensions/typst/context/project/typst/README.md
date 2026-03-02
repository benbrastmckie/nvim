# Typst Context

This directory contains context files for Typst document development.

## Structure

- `patterns/` - Theorem environments, cross-references, diagrams
- `standards/` - Style guide, notation conventions
- `tools/` - Compilation guide

## Key Files

- `standards/typst-style-guide.md` - Formatting conventions
- `patterns/theorem-environments.md` - thmbox setup and usage
- `patterns/cross-references.md` - Labels and refs
- `tools/compilation-guide.md` - Build processes

## Typst vs LaTeX

| Aspect | Typst | LaTeX |
|--------|-------|-------|
| Compilation | Single pass | Multiple passes |
| Speed | Very fast | Slower |
| Syntax | Modern, `#` prefix | Backslash macros |
| Package import | `#import` | `\usepackage` |
| Scripting | Native | Limited |
| Error messages | Clear | Often cryptic |

## For Research

Load: `standards/typst-style-guide.md`, `patterns/theorem-environments.md`

## For Implementation

Load: `tools/compilation-guide.md`, `patterns/cross-references.md`
