# Typst vs LaTeX Comparison

**Created**: 2026-02-27
**Purpose**: Guide for transitioning between Typst and LaTeX

---

## Syntax Comparison

### Document Setup

**LaTeX**:
```latex
\documentclass[12pt]{article}
\usepackage{amsmath}
\begin{document}
...
\end{document}
```

**Typst**:
```typst
#set text(size: 12pt)
#set page(paper: "a4")
...
```

### Headings

**LaTeX**:
```latex
\section{Title}
\subsection{Subtitle}
```

**Typst**:
```typst
= Title
== Subtitle
```

### Lists

**LaTeX**:
```latex
\begin{itemize}
  \item First
  \item Second
\end{itemize}
```

**Typst**:
```typst
- First
- Second
```

### Math

**LaTeX**:
```latex
$x^2 + y^2 = z^2$
\begin{equation}
  \int_0^\infty e^{-x} dx = 1
\end{equation}
```

**Typst**:
```typst
$x^2 + y^2 = z^2$
$
  integral_0^infinity e^(-x) dif x = 1
$
```

### Theorems

**LaTeX**:
```latex
\newtheorem{theorem}{Theorem}
\begin{theorem}
  Statement here.
\end{theorem}
```

**Typst** (with thmbox):
```typst
#import "@preview/thmbox:0.1.0": *
#let theorem = thmbox("theorem", "Theorem")

#theorem[Statement here.]
```

## Feature Comparison

| Feature | LaTeX | Typst |
|---------|-------|-------|
| **Build time** | Slow (multi-pass) | Fast (single-pass) |
| **Error messages** | Cryptic | Clear |
| **Package ecosystem** | Huge (CTAN) | Growing (Universe) |
| **Customization** | Very flexible | Flexible |
| **Bibliography** | Separate tool | Built-in |
| **PDF/A output** | Requires setup | Native support |
| **Scripting** | Limited | Full language |

## Migration Tips

### When to Use Typst

- New documentation projects
- Projects requiring fast iteration
- Documents with complex scripting needs
- Single-author or small team projects

### When to Use LaTeX

- Collaborating with LaTeX users
- Submitting to journals requiring LaTeX
- Using specialized LaTeX packages not yet in Typst
- Legacy documents with heavy LaTeX customization

### Common Migration Patterns

1. **Math notation**: Most LaTeX math works in Typst with minor adjustments
2. **Theorems**: Use `@preview/thmbox` for amsthm-like environments
3. **Diagrams**: Use `@preview/cetz` for tikz-like diagrams
4. **Bibliography**: Convert .bib files directly (mostly compatible)
5. **Tables**: Typst tables are simpler but less flexible

## Resources

- [Typst for LaTeX Users](https://typst.app/docs/guides/guide-for-latex-users/)
- [Symbol Cheat Sheet](https://typst.app/docs/reference/symbols/)
