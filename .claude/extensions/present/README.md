# Present Extension

Presentation and proposal development tools for Claude Code. Provides structured grant writing workflows and professional investor pitch deck generation using Typst.

## Table of Contents

- [Overview](#overview)
- [Commands](#commands)
- [Pitch Deck Generation](#pitch-deck-generation)
  - [Theme Gallery](#theme-gallery)
  - [Quick Start](#quick-start)
  - [Compilation](#compilation)
  - [Customization Guide](#customization-guide)
- [Grant Writing](#grant-writing)
- [Troubleshooting](#troubleshooting)
- [Examples](#examples)

## Overview

The present extension provides two main capabilities:

| Feature | Command | Purpose |
|---------|---------|---------|
| Pitch Decks | `/deck` | Generate YC-style investor presentations in Typst |
| Grant Writing | `/grant` | Structured proposal development with funder research |

**Requirements**:
- Typst 0.11+ for presentation compilation
- touying 0.6.3 package (auto-installed by Typst)

## Commands

### /deck - Pitch Deck Generation

Generate investor pitch decks following YC design principles.

```bash
# Create a pitch deck task
/deck "AI safety startup seeking seed funding"

# Generate from existing company description
/deck startup-info.md

# Specify output location
/deck "Description" --output presentations/seed-deck.typ
```

### /grant - Grant Writing

Structured proposal development for research funding.

```bash
# Create a grant task
/grant "Research NIH R01 funding for AI safety project"

# Draft narrative sections
/grant 500 --draft "Focus on methodology"

# Develop budget
/grant 500 --budget "Include travel for 3 conferences"

# Revise existing grant
/grant --revise 500 "Update based on reviewer feedback"
```

## Pitch Deck Generation

### Theme Gallery

Four professional themes optimized for investor presentations:

#### Professional Blue

Best for: Fintech, enterprise B2B, professional services

| Element | Color | Hex |
|---------|-------|-----|
| Primary | Deep Navy | #1a365d |
| Secondary | Medium Blue | #2c5282 |
| Accent | Sky Blue | #4299e1 |
| Background | White | #ffffff |
| Text | Dark Gray | #1a202c |

Visual characteristics:
- High-contrast, traditional corporate aesthetic
- Conveys trust, stability, and professionalism
- Excellent readability in all lighting conditions

[View example](examples/professional-blue-pitch.typ)

---

#### Premium Dark

Best for: Premium products, luxury brands, sophisticated tech

| Element | Color | Hex |
|---------|-------|-----|
| Primary | Dark Charcoal | #1a1a2e |
| Secondary | Deep Blue-Black | #16213e |
| Accent | Gold | #d4a574 |
| Background | Near Black | #0f0f1a |
| Text | Light Gray | #e2e8f0 |

Visual characteristics:
- Sleek, modern dark mode aesthetic
- Gold accents create premium, sophisticated feel
- High impact for in-person presentations

[View example](examples/premium-dark-pitch.typ)

---

#### Minimal Light

Best for: Data-focused, analytics, enterprise software

| Element | Color | Hex |
|---------|-------|-----|
| Primary | Charcoal | #2d3748 |
| Secondary | Medium Gray | #4a5568 |
| Accent | Blue | #3182ce |
| Background | Off-White | #f7fafc |
| Text | Dark Gray | #1a202c |

Visual characteristics:
- Maximum whitespace, clean typography
- Neutral palette keeps focus on content
- Professional but approachable

[View example](examples/minimal-light-pitch.typ)

---

#### Growth Green

Best for: Sustainability, health, environmental tech, cleantech

| Element | Color | Hex |
|---------|-------|-----|
| Primary | Emerald | #047857 |
| Secondary | Dark Green | #065f46 |
| Accent | Light Green | #34d399 |
| Background | Mint White | #f0fdf4 |
| Text | Dark Gray | #1a202c |

Visual characteristics:
- Fresh, optimistic aesthetic
- Environmental and growth associations
- Differentiates from typical blue/gray decks

[View example](examples/growth-green-pitch.typ)

### Quick Start

1. **Copy an example** to your project:
   ```bash
   cp ~/.config/nvim/.claude/extensions/present/examples/professional-blue-pitch.typ ./my-pitch.typ
   ```

2. **Replace placeholders**: Search for `[TODO: ...]` and fill in your content

3. **Compile**:
   ```bash
   typst compile my-pitch.typ
   ```

### Compilation

```bash
# Single compilation
typst compile deck.typ

# Watch mode (auto-recompile on save)
typst watch deck.typ

# Specify output name
typst compile deck.typ presentation.pdf
```

### Customization Guide

#### Changing Theme Colors

All themes use consistent color variable patterns. Modify the color definitions at the top of the file:

```typst
// Define your custom palette
#let primary = rgb("#YOUR_HEX")
#let secondary = rgb("#YOUR_HEX")
#let accent = rgb("#YOUR_HEX")

// For dark themes, also set page background
#set page(fill: rgb("#YOUR_BACKGROUND"))
```

#### Font Configuration

Examples use Montserrat + Inter pairing. To change fonts:

```typst
// Typography settings
#set text(font: "Your Body Font", size: 30pt)
#show heading.where(level: 1): set text(
  font: "Your Heading Font",
  size: 48pt,
  weight: "bold"
)
```

**Recommended pairings**:
| Headlines | Body | Style |
|-----------|------|-------|
| Montserrat | Inter | Modern geometric |
| Playfair Display | Lato | Classic + modern |
| Poppins | Inter | Friendly, accessible |
| Raleway | Roboto | Elegant minimal |

**Font fallbacks**: If custom fonts are unavailable, Typst uses system defaults. Install fonts via:
- macOS: `brew install font-montserrat font-inter`
- Linux: Download from Google Fonts to `~/.local/share/fonts/`
- NixOS: `fonts.packages = with pkgs; [ montserrat inter ];`

#### Adding Charts

Replace chart placeholders with actual data using cetz:

```typst
#import "@preview/cetz:0.2.2"

#cetz.canvas({
  import cetz.plot

  plot.plot(
    size: (10, 5),
    x-tick-step: 1,
    y-tick-step: 100,
    x-label: "Month",
    y-label: "Revenue ($K)",
    {
      plot.add(
        ((1, 10), (2, 25), (3, 45), (4, 80), (5, 120), (6, 200)),
        mark: "o",
        style: (stroke: rgb("#4a9960")),
      )
    },
  )
})
```

#### Slide Animations

Use sparingly for emphasis:

```typst
== Slide with Reveals

- First point

#pause

- Second point (appears on click)

#pause

- Third point
```

#### Two-Column Layouts

```typst
#grid(
  columns: (1fr, 1fr),
  gutter: 2em,
  [
    *Left Column*
    - Point 1
    - Point 2
  ],
  [
    *Right Column*
    - Point A
    - Point B
  ],
)
```

### YC Design Principles

All themes follow Y Combinator's three core principles:

1. **Legibility**: 30pt minimum body text, 48pt titles, high contrast
2. **Simplicity**: One idea per slide, minimal text, ample whitespace
3. **Obviousness**: Clear visual hierarchy, data-driven claims, no jargon

### Slide Structure

Standard 10-slide YC format:

| # | Slide | Purpose |
|---|-------|---------|
| 1 | Title | Company name and one-liner |
| 2 | Problem | Pain point with evidence |
| 3 | Solution | Your approach (benefits, not features) |
| 4 | Traction | Key metrics and growth |
| 5 | Why Us/Now | Unique insight and timing |
| 6 | Business Model | Revenue and unit economics |
| 7 | Market | TAM/SAM/SOM with methodology |
| 8 | Team | Relevant experience only |
| 9 | The Ask | Amount, use of funds, milestones |
| 10 | Thank You | Contact info, next steps |

## Grant Writing

See [EXTENSION.md](EXTENSION.md) for complete grant writing documentation.

Quick reference:
```bash
/grant "Description"           # Create task
/research N                    # Research funders
/grant N --draft              # Draft narrative
/grant N --budget             # Develop budget
/plan N                       # Create implementation plan
/implement N                  # Assemble materials
```

## Troubleshooting

### Compilation Errors

**"Package not found: touying"**
```bash
# Typst auto-downloads packages on first use
# Ensure internet connection and retry
typst compile deck.typ
```

**"Unknown font family"**

Install missing fonts or use fallbacks:
```typst
// Replace specific font with system fallback
#set text(font: "sans-serif")
```

### Display Issues

**Colors look different in PDF**

PDF viewers render colors differently. Test in your actual presentation environment.

**Text appears small**

Ensure 16:9 aspect ratio and minimum font sizes:
```typst
#show: simple-theme.with(
  aspect-ratio: "16-9",
)
#set text(size: 30pt)  // Minimum for readability
```

### Common Mistakes

- Text smaller than 24pt (unreadable from distance)
- More than 3-4 bullet points per slide
- Multiple ideas on one slide
- Using jargon without explanation
- Missing speaker notes

## Examples

Complete, compilable examples in [examples/](examples/):

| File | Theme | Mock Startup |
|------|-------|--------------|
| professional-blue-pitch.typ | Professional Blue | SafeAI Labs (AI safety) |
| premium-dark-pitch.typ | Premium Dark | NeuralShield (security) |
| minimal-light-pitch.typ | Minimal Light | ClearView Analytics (data) |
| growth-green-pitch.typ | Growth Green | GreenPath Energy (cleantech) |

Each example includes:
- Complete 10-slide structure
- Speaker notes for every slide
- Realistic mock startup data
- Proper color and typography configuration

## Related Files

- [EXTENSION.md](EXTENSION.md) - Full extension documentation
- [examples/README.md](examples/README.md) - Examples index
- [examples/shared-config.typ](examples/shared-config.typ) - Shared utilities
- [context/project/present/patterns/touying-pitch-deck-template.md](context/project/present/patterns/touying-pitch-deck-template.md) - Base template
- [context/project/present/patterns/pitch-deck-structure.md](context/project/present/patterns/pitch-deck-structure.md) - YC guidelines
