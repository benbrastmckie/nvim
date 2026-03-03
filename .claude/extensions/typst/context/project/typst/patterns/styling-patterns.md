# Typst Styling Patterns

**Created**: 2026-02-27
**Purpose**: Common styling techniques for Typst documents

---

## Set Rules

Set rules change default properties for elements:

```typst
// Text styling
#set text(font: "New Computer Modern", size: 11pt)

// Paragraph styling
#set par(justify: true, leading: 0.65em)

// Page layout
#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm),
  numbering: "1",
)

// Heading numbering
#set heading(numbering: "1.1")
```

## Show Rules

Show rules transform how elements are rendered:

```typst
// Style all headings
#show heading: set text(font: "Linux Libertine")

// Style specific heading levels
#show heading.where(level: 1): it => {
  pagebreak(weak: true)
  v(1em)
  text(size: 18pt, weight: "bold", it)
  v(0.5em)
}

// Style inline code
#show raw.where(block: false): box.with(
  fill: luma(240),
  inset: (x: 3pt, y: 0pt),
  outset: (y: 3pt),
  radius: 2pt,
)
```

## Typography

### Font Setup

```typst
// Professional font stack
#set text(
  font: "New Computer Modern",
  fallback: true,
)

// Headings in different font
#show heading: set text(font: "Linux Libertine")
```

### Math Font

```typst
// Use New Computer Modern Math
#show math.equation: set text(font: "New Computer Modern Math")
```

## Color Schemes

### Theorem Environment Colors

```typst
#let theorem-blue = rgb("#e8f4f8")
#let definition-gray = luma(245)
#let example-green = rgb("#e8f8e8")
```

### Link Styling

```typst
#show link: set text(fill: blue.darken(20%))
#show link: underline
```

## Lists

### Custom Bullets

```typst
#set list(marker: ([--], [>], [*]))
```

### Numbered Lists

```typst
#set enum(numbering: "1.a.i")
```

## Tables

### Styled Tables

```typst
#set table(
  stroke: 0.5pt + gray,
  inset: 6pt,
)

#show table.cell.where(y: 0): set text(weight: "bold")
```

## Spacing

### Vertical Spacing

```typst
// After theorems
#show: theorem.with(spacing: 1em)

// Between sections
#show heading.where(level: 1): it => {
  v(2em)
  it
  v(1em)
}
```

### Paragraph Spacing

```typst
#set par(
  justify: true,
  first-line-indent: 1em,
  spacing: 0.65em,
)
```

## Best Practices

1. **Group related rules**: Keep set/show rules together at document start
2. **Use consistent colors**: Define color constants
3. **Test readability**: Check output at different sizes
4. **Consider print**: Avoid light colors if printing expected
5. **Document custom rules**: Comment non-obvious styling
