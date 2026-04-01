# Slidev Deck Template

This document provides the complete Slidev template reference for generating investor pitch decks, following YC design principles (Legibility, Simplicity, Obviousness).

## Framework Overview

- **Engine**: Slidev (markdown-based presentation framework)
- **Theme**: seriph (clean, professional, customizable via themeConfig)
- **Aspect Ratio**: 16:9
- **CSS Framework**: Windi CSS (utility-first, bundled with Slidev)
- **Animations**: v-click, v-clicks, v-motion, v-mark (built-in)
- **Export**: `slidev export` (requires playwright-chromium for PDF)

## Headmatter Configuration

The first slide's YAML frontmatter configures the entire deck:

```yaml
---
theme: seriph
colorSchema: dark
aspectRatio: '16/9'
canvasWidth: 980
fonts:
  sans: Inter
  serif: Montserrat
transition: fade
themeConfig:
  primary: '#60a5fa'
download: true
---
```

### Key Fields

| Field | Purpose | Values |
|-------|---------|--------|
| `theme` | Slidev theme package | `seriph`, `default`, `apple-basic`, `dracula` |
| `colorSchema` | Light/dark mode | `dark`, `light` |
| `aspectRatio` | Slide dimensions | `'16/9'`, `'4/3'` |
| `canvasWidth` | Pixel width | `980` (default) |
| `fonts.sans` | Body font | `Inter`, `Roboto`, etc. |
| `fonts.serif` | Heading font | `Montserrat`, `Playfair Display`, etc. |
| `transition` | Default slide transition | `fade`, `slide-left`, `none` |
| `themeConfig.primary` | Accent color | Any hex color |
| `download` | Enable PDF download button | `true`, `false` |

## Annotated Full Template Example

```markdown
---
theme: seriph
colorSchema: dark
aspectRatio: '16/9'
canvasWidth: 980
fonts:
  sans: Inter
  serif: Montserrat
transition: fade
themeConfig:
  primary: '#60a5fa'
download: true
---

# Company Name

<div class="text-xl opacity-80">
One-line description of what you do
</div>

<div class="abs-br m-6 text-sm opacity-50">
Seed Round | April 2026
</div>

<style>
h1 { font-family: 'Montserrat'; font-size: 3.5em; font-weight: 700; }
</style>

<!-- Speaker: Brief intro. State company name, what you do, why you're here. -->

---
layout: statement
---

# The biggest problem statement here

<v-clicks>

- Evidence point 1 with specific data
- Evidence point 2 with user impact
- Evidence point 3 with market context

</v-clicks>

<!-- Speaker: Make the problem visceral. Pause between evidence reveals. -->

---
layout: two-cols
---

# Our Solution

<v-clicks>

- Benefit 1: Clear outcome
- Benefit 2: Clear outcome
- Benefit 3: Clear outcome

</v-clicks>

::right::

<div v-click class="mt-12">

### How It Works

Brief mechanism description in 1-2 sentences.

</div>

<!-- Speaker: Benefits first, mechanism second. Keep mechanism brief. -->

---
layout: fact
---

# Traction

<div class="grid grid-cols-3 gap-8 mt-8">
  <div v-motion :initial="{ scale: 0.8, opacity: 0, y: 40 }" :enter="{ scale: 1, opacity: 1, y: 0 }">
    <div class="text-4xl font-bold text-[var(--slidev-accent)]">$2.5M</div>
    <div class="text-sm opacity-70 mt-2">ARR</div>
  </div>
  <div v-motion :initial="{ scale: 0.8, opacity: 0, y: 40 }" :enter="{ scale: 1, opacity: 1, y: 0, transition: { delay: 300 } }">
    <div class="text-4xl font-bold text-[var(--slidev-accent)]">150%</div>
    <div class="text-sm opacity-70 mt-2">MoM Growth</div>
  </div>
  <div v-motion :initial="{ scale: 0.8, opacity: 0, y: 40 }" :enter="{ scale: 1, opacity: 1, y: 0, transition: { delay: 600 } }">
    <div class="text-4xl font-bold text-[var(--slidev-accent)]">10K</div>
    <div class="text-sm opacity-70 mt-2">Active Users</div>
  </div>
</div>

<!-- Speaker: Let the numbers speak. Pause between metric reveals. -->

---
layout: center
---

# The Ask

<div v-motion :initial="{ scale: 0, opacity: 0 }" :enter="{ scale: 1, opacity: 1, transition: { type: 'spring', stiffness: 300, damping: 20 } }" class="text-5xl font-bold text-[var(--slidev-accent)] mt-4">
$5M Seed Round
</div>

<v-clicks class="mt-8">

- 40% Engineering (core product)
- 30% Sales (GTM execution)
- 30% Operations (team growth)

</v-clicks>

<!-- Speaker: State the amount clearly. Walk through allocation. -->

---
layout: end
---

# Company Name

email@company.com | company.com
```

## Slide Separator Rules

- Slides are separated by `---` on its own line
- Blank lines before and after `---` are recommended
- The first `---` block is the headmatter (global config)
- Each subsequent `---` starts a new slide
- Per-slide frontmatter goes between `---` markers:

```markdown
---
layout: two-cols
class: text-center
---
```

## Speaker Notes Syntax

Speaker notes use HTML comments with the `Speaker:` prefix:

```markdown
<!-- Speaker: Key talking points for this slide. Keep to 1-2 sentences. -->
```

Speaker notes are visible in presenter mode but not in the exported PDF.

## Two-Column Layout

The `two-cols` layout uses the `::right::` slot separator:

```markdown
---
layout: two-cols
---

# Left Column Content

Content for the left side.

::right::

# Right Column Content

Content for the right side.
```

## Animation Guidelines

### v-click (Single Element)

```html
<div v-click>Appears on click</div>
<div v-click="2">Appears on second click</div>
```

### v-clicks (List Wrapper)

```html
<v-clicks>

- Item 1 (appears first)
- Item 2 (appears second)
- Item 3 (appears third)

</v-clicks>
```

### v-clicks Options

```html
<v-clicks depth="2">   <!-- propagate to nested lists -->
<v-clicks every="2">   <!-- group items per click -->
```

### v-motion (Physics Animation)

```html
<div
  v-motion
  :initial="{ y: 80, opacity: 0 }"
  :enter="{ y: 0, opacity: 1 }"
  :delay="200"
>
  Animated content
</div>
```

### v-mark (Emphasis)

```html
<span v-mark.underline.orange="{ at: 1 }">key phrase</span>
<span v-mark.circle.red="{ at: 2 }">important number</span>
<span v-mark.highlight.yellow="{ at: 3 }">highlighted text</span>
```

## Component Usage

### AutoFitText

```html
<AutoFitText :max="48" :min="24" class="text-[var(--slidev-accent)]">
  $2.5M ARR | 150% Growth
</AutoFitText>
```

### Custom Components

Copy from `.context/deck/components/` to the deck's `components/` directory:

```html
<MetricCard value="$2.5M" label="ARR" :delay="0" color="var(--slidev-accent)" />
<TeamMember name="Jane Doe" role="CEO" bio="10 years in AI" :delay="200" />
<TimelineItem date="Q1 2026" label="Launch" status="done" />
```

## Library Integration Patterns

### Reading Content from Library

The builder agent reads content files from `.context/deck/contents/` and fills `[SLOT: ...]` markers with research data:

```
.context/deck/contents/{slide_type}/{variant}.md
```

### Import Methods

**Method 1: src frontmatter** (for zero-customization slides):
```yaml
---
src: ../../.context/deck/contents/closing/closing-standard.md
---
```

**Method 2: Direct copy** (recommended for most slides):
Read the content file, replace `[SLOT: ...]` markers, paste into `slides.md`.

### Audit Comments

Add import comments to track content source:
```markdown
<!-- Imported from: .context/deck/contents/traction/traction-metrics.md -->
<!-- Slots filled: metric_1_value=$2.5M, metric_1_label=ARR, ... -->
```

## Scoped CSS Styles

Each slide can have a `<style>` block for scoped CSS:

```html
<style>
h1 { font-family: 'Montserrat'; font-size: 3em; font-weight: 700; }
.custom-class { color: var(--slidev-accent); }
</style>
```

Use CSS variables from the theme for consistency:
- `var(--slidev-bg)` -- background color
- `var(--slidev-text)` -- primary text color
- `var(--slidev-accent)` -- accent/primary color
- `var(--slidev-accent-light)` -- lighter accent variant

## Export Commands

```bash
# Development server
slidev slides.md

# Export to PDF (requires playwright-chromium)
slidev export slides.md --output deck.pdf

# Export with dark mode
slidev export slides.md --dark --output deck-dark.pdf
```

**Non-blocking pattern**: PDF export is optional. The `slides.md` file is always the primary artifact. If `slidev` or `playwright-chromium` is not installed, the deck is still valid and viewable.

## Design Checklist

Before generating slides, verify:

- [ ] Headmatter has all required fields (theme, colorSchema, fonts, themeConfig)
- [ ] Each slide has exactly 1 main idea
- [ ] Maximum 5 bullet points per slide
- [ ] Maximum 30 words body text per slide
- [ ] No nested lists
- [ ] Speaker notes on every slide
- [ ] `---` separators have blank lines around them
- [ ] CSS variables used for colors (not hardcoded hex)
- [ ] Content slots filled from research data
- [ ] Appendix slides have `hideInToc: true`

## Prohibited Patterns

- Do NOT use hardcoded colors -- use CSS variables
- Do NOT add more than 12 main slides
- Do NOT use nested bullet lists
- Do NOT include screenshots or embedded media without fallback
- Do NOT use `<script setup>` in slides.md (put logic in components)
- Do NOT modify theme source files -- use themeConfig and scoped CSS

---

## Related Context

- See `pitch-deck-structure.md` for 10-slide YC content requirements
- See `yc-compliance-checklist.md` for detailed compliance validation
- See `.context/deck/index.json` for the reusable content library
- See `.context/deck/themes/` for theme configuration files
