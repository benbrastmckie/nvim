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

## Pagination and Element Choice

A `#figure` does not break across pages by default: a grid-shaped table wrapped in a figure
overflows the page and overlaps its own caption instead of continuing onto the next page. Before
reaching for a grid, decide whether a grid is even the right element for the content — see
`standards/semantic-element-usage.md`'s tabular/key-value entry for the operational choice rule
(a description-list / stacked shape for key-value content or for cells carrying long prose or
long unhyphenatable identifiers; a grid only for a genuinely narrow, scannable matrix).

When a grid genuinely is the right element and must span pages, make it breakable explicitly:

```typst
#show figure.where(kind: table): set block(breakable: true)
```

This `#show` rule must live at the document's top level, never inside the function that builds
the figure: a `#show` rule's scope is the remainder of the content it is woven into, not every
document that happens to `#import` the module defining that function. Wrapping it inside the
figure-building function instead compiles but breaks every reference to the figure's label with
`error: cannot reference styled`.

A breakable grid still needs two pagination decisions settled explicitly, not left to whatever
the default happens to do:

- **Header repeat**: pass `grid.header(repeat: true, ...)` even where `repeat` already defaults
  to `true` in the current Typst release — writing it out records the decision instead of
  leaving the next editor to know (or rediscover) the default.
- **Caption position**: confirm, for the Typst version in use, where the caption renders once the
  figure spans multiple pages (commonly once, after the final chunk, with no per-page repeat and
  no overlap), rather than assuming single-page behavior carries over unexamined.

### Mechanical Check: Not Added

`typst-element-lint.sh` is this extension's mechanical backstop for the placement rules in
`semantic-element-usage.md`, so whether it should also police the grid-vs-list choice above is a
live question, not one to leave unaddressed. The ruling is **not to add it**: the choice test
above ("does each cell render in roughly two lines or fewer at its own column width") is a
rendering-dependent judgment, not a structural grep over source lines the way heading-adjacency
placement is. Checking it mechanically would require compiling and measuring actual rendered
cell width — a different and heavier mechanism than this script's text-only line scanning — for a
defect class this extension has not yet observed recurring in practice, unlike the placement rule
the script already enforces, which codifies an already-observed real defect. Revisit this if a
genuinely unreadable grid is observed recurring, rather than adding the check speculatively now.

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
