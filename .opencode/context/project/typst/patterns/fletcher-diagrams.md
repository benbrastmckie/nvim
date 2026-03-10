# Fletcher Diagram Patterns

## Overview

Fletcher is a Typst package for creating diagrams with arrows, boxes, and edges. It is built on CeTZ and provides high-level abstractions for flowcharts, commutative diagrams, and dependency graphs.

### Package Import

```typst
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge
```

**Version pinning**: Always pin the version to avoid breaking changes.

---

## Core API

### diagram()

Container for all diagram elements.

```typst
#fletcher.diagram(
  cell-size: (14mm, 10mm),    // Grid cell dimensions
  spacing: (12pt, 18pt),      // Gap between cells (x, y)
  node-stroke: 0.5pt,         // Default node border
  node-fill: none,            // Default node fill
  node-corner-radius: 3pt,    // Default corner radius
  edge-stroke: 0.7pt,         // Line thickness
  edge-corner-radius: 5pt,    // Rounded edge corners
  mark-scale: 80%,            // Arrow head size

  // nodes and edges go here
)
```

### node()

Creates a labeled box at a grid position.

```typst
node(
  (row, col),                 // Grid position (row, column)
  [Content],                  // Label content
  name: <label>,              // Named reference for edges
  shape: rect,                // rect, circle, diamond, pill, hexagon
  fill: blue.lighten(80%),    // Background color
  stroke: 0.5pt + blue,       // Border (thickness + color)
  corner-radius: 4pt,         // Rounded corners
  width: 2.8cm,               // Fixed width
  height: auto,               // Height (auto by default)
  inset: 6pt,                 // Internal padding
)
```

**Grid coordinates**: `(row, col)` where row increases downward, column increases rightward. Fractional values work for fine positioning.

### edge()

Connects nodes with arrows.

```typst
edge(
  <from>,                     // Source node name
  <to>,                       // Target node name
  "->",                       // Arrow direction marker
  stroke: 0.7pt,              // Line styling
  label: [text],              // Edge label (optional)
  label-pos: 0.5,             // Position along edge (0-1)
  bend: 0deg,                 // Curve angle
)
```

**Arrow markers**:
- `"->"` - Arrow to target
- `"<-"` - Arrow from target
- `"<->"` - Bidirectional
- `"--"` - No arrows (plain line)

**Dashed edges** for partial dependencies:
```typst
edge(<ch1>, <ch4>, "->", stroke: (dash: "dashed"))
```

---

## Common Patterns

### Color-Coded Node Groups

For dependency diagrams with grouped nodes:

```typst
#let topic-node(pos, number, title, name, group: 1) = {
  let colors = (
    blue.lighten(80%),    // Group 1
    green.lighten(80%),   // Group 2
    orange.lighten(80%)   // Group 3
  )
  node(
    pos,
    align(center)[*#number* \ #text(size: 0.85em)[#title]],
    name: name,
    fill: colors.at(group - 1),
    stroke: 0.5pt + colors.at(group - 1).darken(40%),
    corner-radius: 4pt,
    width: 2.8cm,
    inset: 6pt,
  )
}
```

### Dependency Flowchart

For topic dependency visualization:

```typst
#let dependency-diagram() = {
  figure(
    fletcher.diagram(
      spacing: (14pt, 20pt),
      edge-stroke: 0.7pt,
      edge-corner-radius: 5pt,
      mark-scale: 80%,

      // Group 1: Foundations (blue)
      topic-node((0, 0), 1, [Foundations], <ch1>, group: 1),
      topic-node((0, 1), 2, [Basics], <ch2>, group: 1),
      topic-node((0, 2), 3, [Theory], <ch3>, group: 1),

      // Group 2: Applications (green)
      topic-node((1, 0.5), 4, [Applied 1], <ch4>, group: 2),
      topic-node((1, 1.5), 5, [Applied 2], <ch5>, group: 2),

      // Solid edges = required dependencies
      edge(<ch1>, <ch2>, "->"),
      edge(<ch1>, <ch3>, "->"),
      edge(<ch2>, <ch5>, "->"),

      // Dashed edges = partial dependencies
      edge(<ch1>, <ch4>, "->", stroke: (dash: "dashed")),

      // Labeled edges for section-specific deps
      edge(<ch2>, <ch4>, "->", label: [Sec 4.4], label-pos: 0.6),
    ),
    caption: [Dependencies. Solid arrows = required; dashed = partial.]
  )
}
```

### Edge Routing

Fletcher auto-routes edges, but manual hints help with complex diagrams:

```typst
// Force edge to go right then down
edge(<a>, <b>, "->", vertices: ((0, 1), (1, 1)))

// Bend edge to avoid overlaps
edge(<a>, <c>, "->", bend: 20deg)
```

---

## Accessibility Considerations

### Stroke Differentiation

For colorblind readers, distinguish edges by stroke style, not just color:

```typst
// Required dependency: solid line
edge(<ch1>, <ch2>, "->", stroke: 0.8pt)

// Partial dependency: dashed line
edge(<ch1>, <ch4>, "->", stroke: (dash: "dashed", thickness: 0.8pt))

// Optional dependency: dotted line
edge(<ch1>, <ch7>, "->", stroke: (dash: "dotted", thickness: 0.8pt))
```

### Caption Descriptions

Always explain visual encoding in the figure caption:

```typst
caption: [Solid arrows indicate required prerequisites;
          dashed arrows indicate partial dependencies.
          Colors: blue (Foundations), green (Applications),
          orange (Advanced).]
```

### Grayscale Testing

Verify diagrams remain readable in grayscale by:
1. Using distinct stroke styles (solid/dashed/dotted)
2. Ensuring sufficient contrast between fill colors
3. Including redundant text labels where helpful

---

## Legend Components

Complex diagrams benefit from explicit legends.

### Dependency Diagram Legend

```typst
#let dependency-legend() = {
  block(
    width: 100%,
    stroke: 0.5pt + gray.lighten(40%),
    inset: 8pt,
    radius: 4pt,
  )[
    *Legend*
    #v(4pt)
    #grid(
      columns: (auto, 1fr, auto, 1fr),
      gutter: 8pt,
      // Edge types
      line(length: 1.5cm, stroke: 0.7pt), [Required],
      line(length: 1.5cm, stroke: (dash: "dashed", thickness: 0.7pt)), [Partial],
      // Group colors
      rect(width: 1em, height: 1em, fill: blue.lighten(80%), stroke: 0.5pt), [Group I],
      rect(width: 1em, height: 1em, fill: green.lighten(80%), stroke: 0.5pt), [Group II],
    )
  ]
}
```

---

## Integration with CeTZ

Fletcher builds on CeTZ, so both can coexist:

```typst
#import "@preview/cetz:0.3.4"
```

Fletcher diagrams can be placed inside CeTZ canvases if needed, though this is rarely necessary. For simple flowcharts, use Fletcher directly.

---

## References

- [Fletcher on Typst Universe](https://typst.app/universe/package/fletcher/)
- [Fletcher GitHub](https://github.com/Jollywatt/typst-fletcher)
- [CeTZ Documentation](https://cetz-package.github.io/)
