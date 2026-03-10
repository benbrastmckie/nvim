# Tables and Figures in Typst

**Created**: 2026-02-27
**Purpose**: Creating tables and figures in Typst

---

## Basic Tables

### Simple Table

```typst
#table(
  columns: 3,
  [Header 1], [Header 2], [Header 3],
  [Row 1 Col 1], [Row 1 Col 2], [Row 1 Col 3],
  [Row 2 Col 1], [Row 2 Col 2], [Row 2 Col 3],
)
```

### Styled Table

```typst
#table(
  columns: (1fr, auto, auto),
  inset: 10pt,
  align: horizon,
  stroke: 0.5pt,

  // Header row (styled differently)
  table.header(
    [*Name*], [*Value*], [*Unit*],
  ),

  [Distance], [100], [m],
  [Time], [10], [s],
  [Speed], [10], [m/s],
)
```

## Advanced Tables (tablex)

```typst
#import "@preview/tablex:0.0.8": *

#tablex(
  columns: 4,
  auto-lines: false,

  // Custom styling
  map-hlines: h => (..h, stroke: 0.5pt),

  // Merged cells
  cellx(colspan: 2)[Merged Header],
  [Col 3], [Col 4],

  [1], [2], [3], [4],
)
```

## Figures

### Basic Figure

```typst
#figure(
  image("path/to/image.png", width: 80%),
  caption: [Description of the figure.],
) <fig:label>
```

### Figure with Table

```typst
#figure(
  table(
    columns: 2,
    [A], [B],
    [1], [2],
  ),
  caption: [A table figure.],
) <tbl:label>
```

### Referencing Figures

```typst
As shown in @fig:label...
See @tbl:label for details.
```

## Diagrams (cetz)

```typst
#import "@preview/cetz:0.3.2": *

#figure(
  canvas({
    import draw: *

    // Draw a circle
    circle((0, 0), radius: 1)

    // Draw a line
    line((-2, 0), (2, 0), stroke: blue)

    // Add label
    content((0, -1.5), [Center point])
  }),
  caption: [A simple diagram.],
)
```

## Commutative Diagrams (fletcher)

```typst
#import "@preview/fletcher:0.5.5": *

#figure(
  diagram(
    cell-size: 15mm,
    $A$ & $B$ \\
    $C$ & $D$ \\
  ),
  caption: [A commutative diagram.],
)
```

## Layout Options

### Side-by-Side Figures

```typst
#grid(
  columns: 2,
  gutter: 1em,
  figure(
    image("fig1.png"),
    caption: [Figure 1],
  ),
  figure(
    image("fig2.png"),
    caption: [Figure 2],
  ),
)
```

### Figure Placement

```typst
// Figures are placed inline by default
// Use placement for float-like behavior
#figure(
  placement: top,  // or bottom, auto
  ...,
)
```

## Numbering

```typst
// Custom figure numbering
#set figure(
  numbering: "1",
  supplement: [Figure],
)

// Per-kind numbering
#set figure.where(kind: table): set figure(supplement: [Table])
```
