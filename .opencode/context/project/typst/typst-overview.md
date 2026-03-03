# Typst Overview

**Created**: 2026-02-27
**Purpose**: Introduction to Typst typesetting system for the Logos project

---

## What is Typst?

Typst is a modern typesetting system designed as an alternative to LaTeX. It offers:

- **Faster compilation**: Single-pass rendering, no multi-pass builds
- **Modern syntax**: Function-based, consistent, easier to learn than LaTeX
- **Built-in package manager**: `@preview/` imports for community packages
- **Incremental compilation**: Real-time preview with `typst watch`

## Key Features

### Function-Based Syntax

```typst
// Typst uses functions instead of LaTeX commands
#set text(font: "New Computer Modern")
#show heading: set text(weight: "bold")

= First Section

This is a paragraph with *bold* and _italic_ text.
```

### Math Mode

```typst
// Inline math
The formula $x^2 + y^2 = r^2$ describes a circle.

// Display math
$
  integral_0^infinity e^(-x^2) dif x = sqrt(pi)/2
$
```

### Package Imports

```typst
// Import packages from Typst Universe
#import "@preview/thmbox:0.1.0": *
#import "@preview/cetz:0.3.2": *
```

## Project Usage

In the Logos project, Typst is used for:

1. **Bimodal Reference Manual**: `Theories/Bimodal/typst/BimodalReference.typ`
2. **Technical documentation**: Mathematical content with theorem environments
3. **Cross-referenced documents**: Links to Lean 4 source code

## Compilation

```bash
# Single-pass compilation
typst compile document.typ

# Watch mode for development
typst watch document.typ
```

## Comparison with LaTeX

| Feature | Typst | LaTeX |
|---------|-------|-------|
| Compilation | Single-pass | Multi-pass |
| Syntax | `#function()` | `\command{}` |
| Packages | `@preview/` | `\usepackage{}` |
| Bibliography | Built-in | Separate (bibtex/biber) |
| Learning curve | Lower | Higher |
| Maturity | Newer | Established |

## Resources

- [Official Documentation](https://typst.app/docs/)
- [Typst Universe](https://typst.app/universe/) - Package repository
- [Community Forum](https://forum.typst.app/)
- [GitHub Repository](https://github.com/typst/typst)
