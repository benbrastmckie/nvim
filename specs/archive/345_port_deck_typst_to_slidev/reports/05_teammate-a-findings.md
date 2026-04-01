# Teammate A Findings: Reusable Deck Construction Protocols and Slide Patterns

**Task**: 345 - Port /deck command-skill-agent from Typst to Slidev
**Date**: 2026-04-01
**Focus**: Deck construction protocols, component library structure, deck modes

---

## Executive Summary

This report designs a protocol system for building reusable, pattern-based pitch decks in Slidev. The core insight is that Slidev's component model (auto-imported Vue components + UnoCSS shortcuts + named layouts) maps cleanly to a "protocol library" where each slide type is a reusable recipe. The 4 existing deck modes (INVESTOR, UPDATE, INTERNAL, PARTNERSHIP) translate directly to protocol sequences. The addon system provides the right distribution mechanism for the component library.

**Confidence levels**: HIGH = confirmed from Slidev docs; MEDIUM = inferred from patterns; LOW = design recommendation pending validation.

---

## 1. Slidev Component and Layout System (Confirmed Foundations)

**Confidence: HIGH**

### 1.1 Auto-Import System

Slidev uses `unplugin-vue-components` for zero-import component usage. Any `.vue` file placed in `components/` is immediately available in slides:

```
deck-project/
├── components/
│   ├── MetricCard.vue      # <MetricCard value="$2M" label="ARR" />
│   ├── TeamMember.vue      # <TeamMember name="Jane" role="CEO" />
│   ├── TimelineItem.vue    # <TimelineItem date="Q1 2025" event="Launch" />
│   └── ComparisonCol.vue   # <ComparisonCol title="Before" color="red" />
├── layouts/
│   ├── metric-grid.vue     # layout: metric-grid
│   ├── problem-solution.vue # layout: problem-solution
│   └── team-showcase.vue   # layout: team-showcase
├── styles/
│   └── index.css           # Global CSS + UnoCSS shortcuts
├── global-bottom.vue       # Persistent footer (page number, logo)
└── slides.md
```

Components are referenced in markdown with no imports:
```html
<MetricCard value="$2M" label="Annual Revenue" :animate="true" />
```

### 1.2 Layout System

Custom layouts go in `layouts/` as Vue SFCs. They receive slide content via `<slot/>` and named slots for multi-section layouts:

```vue
<!-- layouts/two-panel.vue -->
<template>
  <div class="slidev-layout two-panel grid grid-cols-2 h-full">
    <div class="panel-left p-12">
      <slot name="left" />
    </div>
    <div class="panel-right p-12 border-l border-white/10">
      <slot name="right" />
    </div>
  </div>
</template>
```

Used in slides.md with slot sugar syntax:
```markdown
---
layout: two-panel
---

::left::
## The Problem
...

::right::
## The Solution
...
```

### 1.3 Global Layers

Five layer files provide cross-slide persistence. Listed top-to-bottom in z-order:

| File | Scope | Use Case |
|------|-------|----------|
| `global-top.vue` | All slides | Watermark, mode badge |
| `global-bottom.vue` | All slides | Footer: page count, logo, progress bar |
| `slide-top.vue` | Per-slide instance | Per-slide overlays |
| `slide-bottom.vue` | Per-slide instance | Per-slide annotations |
| `custom-nav-controls.vue` | Nav area | Custom presenter controls |

**Footer pattern** (global-bottom.vue):
```vue
<template>
  <footer
    v-if="$nav.currentLayout !== 'cover' && $nav.currentLayout !== 'end'"
    class="absolute bottom-0 right-0 p-4 text-xs opacity-40 flex gap-4"
  >
    <span>{{ $nav.currentPage }} / {{ $nav.total }}</span>
  </footer>
</template>
```

### 1.4 UnoCSS Design Tokens

`uno.config.ts` at project root enables custom design shortcuts that can be applied as classes anywhere:

```typescript
import { defineConfig } from 'unocss'

export default defineConfig({
  shortcuts: {
    // Layout primitives
    'slide-base': 'relative h-full w-full overflow-hidden',
    'slide-center': 'flex items-center justify-center h-full',

    // Typography scale
    'text-display': 'font-serif text-6xl font-bold tracking-tight text-slate-50',
    'text-heading': 'font-serif text-4xl font-semibold text-slate-100',
    'text-subhead': 'font-sans text-2xl text-slate-300',
    'text-body': 'font-sans text-xl text-slate-400 leading-relaxed',
    'text-label': 'font-sans text-base text-slate-500 uppercase tracking-wider',

    // Accent and brand
    'text-accent': 'text-blue-400',
    'text-accent-2': 'text-violet-400',
    'border-accent': 'border-blue-400/30',

    // Card primitives
    'card-base': 'rounded-xl border border-white/10 bg-white/5 backdrop-blur-sm p-8',
    'card-metric': 'card-base text-center flex flex-col items-center gap-2',

    // Section divider
    'section-line': 'w-16 h-0.5 bg-blue-400/60 mb-6',
  },
})
```

### 1.5 Global Context Available in Components

Components and global layers can access:

| Variable | Type | Usage |
|----------|------|-------|
| `$nav.currentPage` | number | Current slide number |
| `$nav.currentLayout` | string | Active layout name |
| `$nav.total` | number | Total slide count |
| `$slidev.configs` | object | Project headmatter config |
| `$frontmatter` | object | Current slide frontmatter |
| `$clicks` | number | Click count on current slide |
| `$renderContext` | string | 'slide' / 'presenter' / 'overview' |

---

## 2. Deck Construction Protocols

**Confidence: HIGH (patterns); MEDIUM (specific implementations)**

A "protocol" is a standardized recipe combining: layout + frontmatter + animation directives + CSS classes + content slots. Each protocol is self-contained and reusable across deck modes.

---

### Protocol 1: Cover Protocol

**Purpose**: Opening title slide with company name, tagline, and round/date.

**Layout**: `cover` (built-in) or custom `cover-hero`

**Frontmatter**:
```yaml
---
layout: cover
background: /images/hero-backdrop.jpg
class: text-white
transition: fade
---
```

**Template**:
```html
<!-- Gradient overlay over background image -->
<div class="absolute inset-0 bg-gradient-to-br from-black/85 via-blue-950/50 to-black/75" />

<div
  class="relative z-10 flex flex-col gap-6"
  v-motion
  :initial="{ y: 30, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { duration: 800 } }"
>
  <div class="section-line" />
  <h1 class="text-display">{{ $frontmatter.company }}</h1>
  <p class="text-subhead opacity-80">{{ $frontmatter.tagline }}</p>
</div>

<div
  class="abs-br m-10 text-body opacity-50"
  v-motion
  :initial="{ opacity: 0 }"
  :enter="{ opacity: 0.5, transition: { delay: 600 } }"
>
  {{ $frontmatter.round }} · {{ $frontmatter.date }}
</div>
```

**Content Slots**:
- `company`: Company name (required)
- `tagline`: One-line description (required)
- `round`: Funding round label (e.g., "Seed Round")
- `date`: Date string (e.g., "April 2026")

**Animation**: Single enter motion -- whole block fades up, round/date delayed fade.

---

### Protocol 2: Problem Statement Protocol

**Purpose**: State the pain point clearly, make it visceral and relatable.

**Layout**: `statement` (built-in) or `image-right` for evidentiary image

**Frontmatter**:
```yaml
---
layout: statement
transition: slide-left
---
```

**Template** (layout: statement):
```html
<div class="text-center max-w-3xl mx-auto">
  <p class="text-label mb-6 text-accent">The Problem</p>
  <h2 class="text-heading mb-8">
    <span v-mark.highlight="{ color: 'rgba(239,68,68,0.2)', at: 1 }">
      {{ $frontmatter.problem_headline }}
    </span>
  </h2>

  <v-clicks>
    <p class="text-body mb-4">{{ $frontmatter.evidence_1 }}</p>
    <p class="text-body mb-4">{{ $frontmatter.evidence_2 }}</p>
    <p class="text-body opacity-60">{{ $frontmatter.evidence_3 }}</p>
  </v-clicks>
</div>
```

**Template** (layout: image-right, for photo evidence):
```markdown
---
layout: image-right
image: /images/problem-context.jpg
transition: slide-left
---

<p class="text-label text-accent mb-4">The Problem</p>

## Problem headline here

<v-clicks>

- Evidence point one
- Evidence point two

</v-clicks>
```

**Animation**: `v-mark.highlight` on headline at click 1; `v-clicks` for evidence points.

**Content Slots**: `problem_headline`, `evidence_1-3`, optional image.

---

### Protocol 3: Solution Protocol

**Purpose**: Show before/after transformation. Two-panel layout contrasting old vs new.

**Layout**: Custom `solution-contrast` (two-col with visual divide)

**Frontmatter**:
```yaml
---
layout: two-cols
transition: slide-left
class: solution-slide
---
```

**Template**:
```markdown
::default::
<p class="text-label text-slate-500 mb-4 line-through">Before</p>

<div class="card-base opacity-60 border-red-900/30">
  <p class="text-body">{{ problem_state }}</p>
</div>

::right::
<div v-click>
  <p class="text-label text-accent mb-4">After · Our Approach</p>
  <div class="card-base border-blue-400/30">
    <p class="text-body">{{ solution_state }}</p>
  </div>
  <p class="text-label mt-6 text-accent">
    <span v-mark.circle>{{ key_benefit }}</span>
  </p>
</div>
```

**Animation**: Right panel `v-click` reveal; `v-mark.circle` on key benefit after reveal.

**Content Slots**: `problem_state`, `solution_state`, `key_benefit`.

---

### Protocol 4: Metric Reveal Protocol

**Purpose**: Present KPIs with staggered dramatic reveal. Maximum investor impact.

**Layout**: `center` (built-in) or custom `metric-grid`

**Frontmatter**:
```yaml
---
layout: center
transition: fade
---
```

**Template** (3-metric grid):
```html
<p class="text-label text-center text-accent mb-12">Traction</p>

<div class="grid grid-cols-3 gap-12">
  <div v-click class="card-metric">
    <div
      v-motion
      :initial="{ y: 24, opacity: 0, scale: 0.9 }"
      :enter="{ y: 0, opacity: 1, scale: 1, transition: { type: 'spring', stiffness: 300 } }"
    >
      <span class="text-display text-blue-400">
        <span v-mark.circle>{{ metric_1_value }}</span>
      </span>
      <p class="text-label mt-2">{{ metric_1_label }}</p>
    </div>
  </div>

  <div v-click class="card-metric">
    <div
      v-motion
      :initial="{ y: 24, opacity: 0, scale: 0.9 }"
      :enter="{ y: 0, opacity: 1, scale: 1, transition: { type: 'spring', stiffness: 300, delay: 100 } }"
    >
      <span class="text-display text-blue-400">
        <span v-mark.circle>{{ metric_2_value }}</span>
      </span>
      <p class="text-label mt-2">{{ metric_2_label }}</p>
    </div>
  </div>

  <div v-click class="card-metric">
    <div
      v-motion
      :initial="{ y: 24, opacity: 0, scale: 0.9 }"
      :enter="{ y: 0, opacity: 1, scale: 1, transition: { type: 'spring', stiffness: 300, delay: 200 } }"
    >
      <span class="text-display text-blue-400">
        <span v-mark.circle>{{ metric_3_value }}</span>
      </span>
      <p class="text-label mt-2">{{ metric_3_label }}</p>
    </div>
  </div>
</div>
```

**Reusable `MetricCard.vue` component** (preferred over inline template):

```vue
<!-- components/MetricCard.vue -->
<script setup>
defineProps({
  value: String,      // "$2M"
  label: String,      // "Annual Revenue"
  delay: { type: Number, default: 0 },
  color: { type: String, default: 'text-blue-400' }
})
</script>

<template>
  <div class="card-metric">
    <div
      v-motion
      :initial="{ y: 24, opacity: 0, scale: 0.9 }"
      :enter="{
        y: 0, opacity: 1, scale: 1,
        transition: { type: 'spring', stiffness: 300, delay }
      }"
    >
      <span :class="['text-display', color]">{{ value }}</span>
      <p class="text-label mt-2">{{ label }}</p>
    </div>
  </div>
</template>
```

Used in slides:
```html
<div class="grid grid-cols-3 gap-12">
  <div v-click><MetricCard value="$2M" label="ARR" :delay="0" /></div>
  <div v-click><MetricCard value="340%" label="YoY Growth" :delay="100" /></div>
  <div v-click><MetricCard value="50K+" label="API Calls/Day" :delay="200" /></div>
</div>
```

**Animation**: Each card `v-click` triggered; spring physics on enter; `v-mark.circle` on values.

---

### Protocol 5: Team Grid Protocol

**Purpose**: Show founders/team with photos, titles, and brief bios.

**Layout**: Custom `team-showcase` layout or inline grid

**Frontmatter**:
```yaml
---
layout: center
transition: slide-left
---
```

**Reusable `TeamMember.vue` component**:

```vue
<!-- components/TeamMember.vue -->
<script setup>
defineProps({
  name: String,
  role: String,
  bio: String,
  photo: { type: String, default: null },
  delay: { type: Number, default: 0 }
})
</script>

<template>
  <div
    v-motion
    :initial="{ y: 20, opacity: 0 }"
    :enter="{ y: 0, opacity: 1, transition: { delay } }"
    class="card-base flex flex-col items-center text-center gap-4"
  >
    <img v-if="photo" :src="photo" :alt="name"
      class="w-24 h-24 rounded-full object-cover border-2 border-blue-400/30" />
    <div v-else class="w-24 h-24 rounded-full bg-blue-400/20 flex items-center justify-center">
      <span class="text-2xl font-bold text-blue-400">{{ name[0] }}</span>
    </div>
    <div>
      <p class="text-subhead font-semibold">{{ name }}</p>
      <p class="text-label text-accent mt-1">{{ role }}</p>
      <p class="text-body opacity-60 mt-3 text-sm">{{ bio }}</p>
    </div>
  </div>
</template>
```

**Slide template**:
```html
<p class="text-label text-accent mb-8">The Team</p>

<div class="grid grid-cols-2 gap-8">
  <div v-click>
    <TeamMember
      name="Jane Chen"
      role="CEO & Co-founder"
      bio="Ex-Google, 10 years ML infrastructure"
      photo="/images/jane.jpg"
      :delay="0"
    />
  </div>
  <div v-click>
    <TeamMember
      name="Alex Kim"
      role="CTO & Co-founder"
      bio="PhD Stanford NLP, 3 successful exits"
      photo="/images/alex.jpg"
      :delay="100"
    />
  </div>
</div>
```

---

### Protocol 6: Market Size Protocol

**Purpose**: Visualize TAM/SAM/SOM or market opportunity scale.

**Layout**: `two-cols` or custom `market-visual`

**Template** (concentric circles approach):
```html
<p class="text-label text-accent mb-8">Market Opportunity</p>

<div class="grid grid-cols-2 gap-12 items-center">
  <!-- Visual: nested rings (pure CSS) -->
  <div class="relative flex items-center justify-center h-64">
    <div v-click class="absolute w-64 h-64 rounded-full border-2 border-blue-400/20 flex items-center justify-center">
      <span class="text-label text-slate-500">TAM</span>
    </div>
    <div v-click class="absolute w-44 h-44 rounded-full border-2 border-blue-400/40 bg-blue-400/5 flex items-center justify-center">
      <span class="text-label text-slate-400">SAM</span>
    </div>
    <div v-click class="absolute w-24 h-24 rounded-full bg-blue-400/20 border-2 border-blue-400 flex items-center justify-center">
      <span class="text-label text-blue-300">SOM</span>
    </div>
  </div>

  <!-- Numbers column -->
  <div class="flex flex-col gap-6">
    <div v-click class="card-base">
      <p class="text-label text-slate-500">Total Addressable Market</p>
      <p class="text-heading text-accent">$120B</p>
    </div>
    <div v-click class="card-base">
      <p class="text-label text-slate-500">Serviceable Market</p>
      <p class="text-heading">$18B</p>
    </div>
    <div v-click class="card-base">
      <p class="text-label text-slate-500">Initial Target</p>
      <p class="text-heading">$2.4B</p>
    </div>
  </div>
</div>
```

---

### Protocol 7: Timeline Protocol

**Purpose**: Show roadmap, milestones, or company history progressively.

**Layout**: `default` with custom CSS timeline

**Reusable `TimelineItem.vue` component**:

```vue
<!-- components/TimelineItem.vue -->
<script setup>
defineProps({
  date: String,
  label: String,
  description: String,
  status: { type: String, default: 'past' }, // 'past' | 'current' | 'future'
})
</script>

<template>
  <div class="flex gap-6 items-start">
    <div class="flex flex-col items-center">
      <div :class="[
        'w-4 h-4 rounded-full border-2 mt-1 shrink-0',
        status === 'current' ? 'bg-blue-400 border-blue-400' :
        status === 'past' ? 'bg-blue-400/40 border-blue-400/40' :
        'bg-transparent border-slate-600'
      ]" />
      <div class="w-px flex-1 bg-slate-700 mt-1" />
    </div>
    <div class="pb-8">
      <p class="text-label" :class="status === 'current' ? 'text-accent' : 'text-slate-500'">
        {{ date }}
      </p>
      <p class="text-subhead font-semibold mt-1">{{ label }}</p>
      <p v-if="description" class="text-body opacity-60 mt-1">{{ description }}</p>
    </div>
  </div>
</template>
```

**Slide template**:
```html
<p class="text-label text-accent mb-8">Roadmap</p>

<v-clicks>
  <TimelineItem date="Q3 2024" label="Beta Launch" status="past" />
  <TimelineItem date="Q1 2025" label="$1M ARR" status="past" />
  <TimelineItem date="Q2 2025" label="Seed Round" status="current"
    description="$3M raised, Series A in 18 months" />
  <TimelineItem date="Q4 2025" label="Enterprise Contracts" status="future" />
</v-clicks>
```

---

### Protocol 8: Quote/Testimonial Protocol

**Purpose**: Customer voice, investor endorsement, or key quote for credibility.

**Layout**: `quote` (built-in) or `statement`

**Template** (using built-in `quote` layout):
```markdown
---
layout: quote
author: "Sarah Johnson, VP Engineering at Fortune 500 Co."
transition: fade
---

"This cut our inference costs by 60% in the first month. It was the
easiest infrastructure decision we've made all year."
```

**Enhanced template** (centered with animation):
```html
<div
  class="flex flex-col items-center justify-center h-full max-w-3xl mx-auto text-center"
  v-motion
  :initial="{ opacity: 0, y: 20 }"
  :enter="{ opacity: 1, y: 0, transition: { duration: 700 } }"
>
  <div class="text-5xl text-blue-400/40 mb-6 font-serif">"</div>
  <p class="text-heading font-medium italic leading-relaxed">
    {{ quote_text }}
  </p>
  <div class="mt-8 flex items-center gap-4" v-click>
    <div class="w-12 h-0.5 bg-blue-400/40" />
    <p class="text-label text-accent">{{ attribution }}</p>
  </div>
</div>
```

---

### Protocol 9: Comparison Protocol

**Purpose**: Before/after or competitor comparison with `v-switch` for sequential reveal.

**Layout**: `two-cols` with custom divider, or `v-switch` sequential

**Template (v-switch approach)**:
```html
<p class="text-label text-accent mb-8">Why Us</p>

<v-switch>
  <template #1>
    <!-- State 1: Competitor landscape -->
    <div class="grid grid-cols-3 gap-6">
      <ComparisonCol
        v-for="competitor in competitors"
        :title="competitor.name"
        :points="competitor.weaknesses"
        color="red"
      />
    </div>
  </template>
  <template #2>
    <!-- State 2: Our position -->
    <div class="grid grid-cols-3 gap-6">
      <ComparisonCol
        v-for="(item, i) in comparison"
        :title="item.name"
        :points="item.points"
        :color="i === 1 ? 'blue' : 'slate'"
        :highlight="i === 1"
      />
    </div>
  </template>
</v-switch>
```

**`ComparisonCol.vue` component**:
```vue
<!-- components/ComparisonCol.vue -->
<script setup>
defineProps({
  title: String,
  points: Array,
  color: { type: String, default: 'slate' },
  highlight: { type: Boolean, default: false }
})
</script>

<template>
  <div :class="['card-base', highlight ? 'border-blue-400/60 bg-blue-400/10' : '']">
    <p :class="['text-subhead font-semibold mb-4', highlight ? 'text-accent' : '']">
      {{ title }}
    </p>
    <ul class="flex flex-col gap-2">
      <li v-for="point in points" class="flex gap-2 text-body">
        <span :class="color === 'red' ? 'text-red-400' : color === 'blue' ? 'text-blue-400' : 'text-slate-400'">
          {{ color === 'red' ? '×' : '✓' }}
        </span>
        {{ point }}
      </li>
    </ul>
  </div>
</template>
```

---

### Protocol 10: Demo/Screenshot Protocol

**Purpose**: Show product interface with callout annotations.

**Layout**: `image` (full bleed) or `image-right` with commentary

**Template** (image-right with v-click annotations):
```markdown
---
layout: image-right
image: /images/product-screenshot.png
transition: slide-left
---

<p class="text-label text-accent mb-6">The Product</p>

<v-clicks>

- **One-line inference API** — deploy any model in 90 seconds
- **Auto-scaling** — from 0 to 10K req/s with no config
- **Cost optimizer** — routes to cheapest model meeting your SLA

</v-clicks>
```

**Template** (full-bleed with overlay arrows using `Arrow` built-in):
```html
<div class="relative h-full">
  <img src="/images/dashboard-full.png" class="w-full h-full object-contain" />

  <div v-click class="absolute top-1/4 left-1/3">
    <Arrow x1="0" y1="0" x2="-60" y2="-30" color="#60a5fa" />
    <div class="card-base absolute -top-16 -left-8 text-sm w-40">
      Real-time metrics
    </div>
  </div>
</div>
```

---

### Protocol 11: Ask/CTA Protocol

**Purpose**: State the funding ask with allocation breakdown. Final action slide.

**Layout**: `center` or custom `ask-slide`

**Template**:
```html
<div class="text-center max-w-2xl mx-auto">
  <p class="text-label text-accent mb-4">The Ask</p>

  <div
    class="text-display mb-4"
    v-motion
    :initial="{ scale: 0.8, opacity: 0 }"
    :enter="{ scale: 1, opacity: 1, transition: { type: 'spring', stiffness: 200 } }"
  >
    <span v-mark.circle>Raising $3M</span>
  </div>

  <p class="text-subhead opacity-60 mb-12">Seed Round · SAFE Note · 20% discount</p>

  <div class="grid grid-cols-3 gap-6" >
    <div v-click class="card-base text-center">
      <p class="text-heading text-accent">60%</p>
      <p class="text-label mt-2">Engineering</p>
    </div>
    <div v-click class="card-base text-center">
      <p class="text-heading text-accent">25%</p>
      <p class="text-label mt-2">GTM</p>
    </div>
    <div v-click class="card-base text-center">
      <p class="text-heading text-accent">15%</p>
      <p class="text-label mt-2">Operations</p>
    </div>
  </div>
</div>
```

---

### Protocol 12: Section Divider Protocol

**Purpose**: Visual chapter markers for structured decks with appendix.

**Layout**: `section` (built-in)

**Template**:
```markdown
---
layout: section
background: linear-gradient(135deg, rgba(59,130,246,0.08) 0%, transparent 60%), #0a0a1a
transition: slide-left | slide-right
---

# Traction
```

---

## 3. Slide Component Library Structure

**Confidence: HIGH (file structure); MEDIUM (versioning approach)**

### 3.1 Recommended Directory Layout

```
deck-project/
├── slides.md                    # Main presentation (headmatter + slides)
│
├── components/                  # Auto-imported Vue components
│   ├── cards/
│   │   ├── MetricCard.vue       # Single KPI metric display
│   │   ├── StatCard.vue         # Simple labeled statistic
│   │   └── HighlightCard.vue    # Key insight callout
│   ├── team/
│   │   └── TeamMember.vue       # Person profile card
│   ├── timeline/
│   │   └── TimelineItem.vue     # Timeline entry
│   ├── comparison/
│   │   └── ComparisonCol.vue    # Competitor comparison column
│   └── market/
│       └── MarketRing.vue       # TAM/SAM/SOM ring diagram
│
├── layouts/                     # Custom named layouts
│   ├── cover-hero.vue           # Enhanced cover with full-bleed image
│   ├── metric-grid.vue          # 3-up KPI grid layout
│   ├── team-showcase.vue        # Team photo grid layout
│   ├── ask-slide.vue            # Ask/CTA layout with allocation grid
│   └── section-accent.vue      # Section divider with accent color
│
├── public/
│   └── images/                  # Slide images (backdrop, product, team)
│
├── styles/
│   └── index.css                # Global dark theme + typography
│
├── global-bottom.vue            # Footer: page numbers
├── uno.config.ts                # Design tokens + shortcut classes
├── vite.config.ts               # Optional Vite extensions
└── slides.md
```

### 3.2 Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Components | PascalCase, noun-first | `MetricCard.vue`, `TeamMember.vue` |
| Layouts | kebab-case, noun-first | `metric-grid.vue`, `cover-hero.vue` |
| CSS shortcuts | kebab-case, semantic | `card-base`, `text-display`, `text-accent` |
| Images | kebab-case, descriptive | `hero-backdrop.jpg`, `product-demo.png` |
| Protocol names | TitleCase + "Protocol" | `MetricRevealProtocol`, `TeamGridProtocol` |

### 3.3 Component Design Principles

1. **Props for content, slots for structure**: Pass text/values as props; use slots for complex inner structure.
2. **Delay prop for stagger**: Each animated component takes an optional `delay` prop (milliseconds) for coordinated staggering.
3. **Fallback for missing assets**: `TeamMember` shows an initials circle if no photo provided.
4. **No Slidev-internal imports**: Components use standard Vue 3; no `@slidev/client` imports unless necessary (they break in non-Slidev contexts).
5. **CSS via UnoCSS shortcuts**: Components use shortcut class names (`card-base`, `text-label`) rather than raw Tailwind to allow global theme changes.

### 3.4 Addon vs Local Components

**Use local components** (`components/` directory) for:
- Project-specific branded components (custom logo, brand colors)
- One-off slides unique to this deck
- Prototyping new patterns

**Use an addon** (npm package) for:
- Components shared across multiple deck projects
- Layouts/components you want to version independently
- Team-wide component standards

**Creating a distributable addon** (`slidev-addon-deck-protocols`):
```json
// package.json
{
  "name": "slidev-addon-deck-protocols",
  "version": "1.0.0",
  "keywords": ["slidev-addon", "slidev"],
  "main": "index.ts"
}
```

```yaml
# slides.md headmatter
---
addons:
  - slidev-addon-deck-protocols
---
```

The addon can provide: `components/`, `layouts/`, `styles/`, and `uno.config.ts` extensions. Non-JS files (`.vue`, `.ts`) can be published directly without pre-compilation -- Slidev compiles them at use time.

**Local dev testing**:
```yaml
---
addons:
  - ./   # Uses current directory as addon
---
```

### 3.5 Versioning Approach

**Confidence: MEDIUM**

For a local project library, use standard file versioning. For a distributed addon:

- Tag releases with semver: `1.0.0`, `1.1.0`, etc.
- Breaking layout/prop changes = major version bump
- New components = minor version bump
- Style fixes = patch version bump
- Keep a `CHANGELOG.md` in the addon root

---

## 4. Deck Modes Mapped to Slidev

**Confidence: HIGH (structure); MEDIUM (exact protocol sequences)**

The existing system defines 4 deck modes: INVESTOR, UPDATE, INTERNAL, PARTNERSHIP. Here is how each maps to protocol sequences and Slidev frontmatter configuration.

---

### Mode 1: INVESTOR (Full Pitch Deck)

**Slides**: 10 (YC structure)
**Transitions**: `fade` globally, `slide-left` between sections
**Protocols**: Cover → Problem → Solution → Traction (Metric Reveal) → Why Now → Business Model → Market Size → Team Grid → Ask → End

```yaml
# Headmatter (slides.md)
---
theme: seriph
colorSchema: dark
transition: fade
fonts:
  sans: Inter
  serif: Playfair Display
  mono: JetBrains Mono
themeConfig:
  primary: '#60a5fa'
aspectRatio: '16/9'
canvasWidth: 980
---
```

**Slide sequence**:

| # | Slide | Protocol | Layout |
|---|-------|----------|--------|
| 1 | Cover | Cover Protocol | `cover` |
| 2 | Problem | Problem Statement | `statement` or `image-right` |
| 3 | Solution | Solution Protocol | `two-cols` |
| 4 | Traction | Metric Reveal | `center` |
| 5 | Why Now | Statement | `statement` |
| 6 | Business Model | Bullet/Card list | `default` |
| 7 | Market | Market Size Protocol | `center` |
| 8 | Team | Team Grid Protocol | `center` |
| 9 | Ask | Ask/CTA Protocol | `center` |
| 10 | Contact | Section Divider / End | `end` |

**YC Design Rules Applied**:
- Max 5 bullets per slide (enforced by content, not code)
- No nested lists
- All text ≥ 24pt (enforced via UnoCSS `text-body` = `text-xl`)
- Titles ≥ 40pt (enforced via `text-heading` = `text-4xl`)

---

### Mode 2: LIGHTNING (5-Slide Talk)

**Slides**: 5
**Transitions**: `slide-left` throughout (fast, forward momentum)
**Duration target**: 5 minutes (1 min/slide)

**Compression strategy**: Collapse INVESTOR 10 slides to 5 by merging related slides.

| # | Slide | Maps To | Protocol |
|---|-------|---------|----------|
| 1 | Title + Problem | Slides 1+2 | Cover with problem subtext |
| 2 | Solution + Demo | Slides 3+product | Demo/Screenshot with key points |
| 3 | Traction | Slide 4 | Metric Reveal (3 metrics only) |
| 4 | Team + Model | Slides 6+8 | Two-cols: left=model, right=team |
| 5 | Ask | Slide 9 | Ask/CTA (simplified) |

**Headmatter variation**:
```yaml
---
theme: seriph
colorSchema: dark
transition: slide-left
canvasWidth: 980
---
```

**Note**: Lightning decks should use `v-clicks` sparingly — with 1 min/slide, progressive reveals create pressure. Prefer full-reveal layouts with strong visual hierarchy instead.

---

### Mode 3: DEMO (Technical Focus)

**Slides**: 8-12 (flexible)
**Transitions**: `slide-left` for flow, `fade` for demo screens
**Audience**: Technical buyers, developers, enterprise evaluators

**Protocol sequence**:

| # | Slide | Protocol | Notes |
|---|-------|----------|-------|
| 1 | Cover | Cover Protocol | Product-focused tagline |
| 2 | Problem | Problem Statement | More technical framing |
| 3 | Architecture | Custom (code + diagram) | `two-cols`: diagram left, bullets right |
| 4 | Demo 1 | Demo/Screenshot | First key workflow |
| 5 | Magic Move | Code Protocol | Before/after with Shiki Magic Move |
| 6 | Demo 2 | Demo/Screenshot | Second key workflow |
| 7 | Performance | Metric Reveal | Benchmarks as metrics |
| 8 | Integration | Timeline (horizontal) | Integration path / onboarding |
| 9 | Team/Creds | Team Grid (minimal) | Technical credibility focus |
| 10 | Next Steps | Ask/CTA (adapted) | Trial/pilot CTA instead of raise |

**Unique to DEMO mode**:
- Shiki Magic Move for code transformations:
````markdown
```python magic-move
# Before: Traditional approach
model = OpenAI(model="gpt-4")
response = model.chat(messages)
cost = $0.03 * tokens

# After: Our approach
model = OurAPI(model="best-available")
response = model.chat(messages, optimize_cost=True)
cost = $0.006 * tokens  # 5x cheaper, same quality
```
````
- `iframe` or `iframe-right` layout for live product embeds
- `SlidevVideo` component for screen recordings

---

### Mode 4: ONE-PAGER (Single Slide Summary)

**Slides**: 1
**Purpose**: Executive summary, leave-behind, email attachment
**Challenge**: Dense content must remain readable (all YC font minimums still apply)

**Approach**: Use `full` layout with CSS grid for maximum information density.

```yaml
---
layout: full
canvasWidth: 1200    # Wider canvas for dense layout
colorSchema: dark
---
```

```html
<div class="grid grid-cols-3 grid-rows-3 gap-4 h-full p-8 text-sm">
  <!-- Header: spans full width -->
  <div class="col-span-3 flex justify-between items-center pb-4 border-b border-white/10">
    <div>
      <h1 class="text-3xl font-bold font-serif">{{ company }}</h1>
      <p class="text-slate-400 mt-1">{{ tagline }}</p>
    </div>
    <div class="text-right">
      <p class="text-accent font-bold text-2xl">{{ round }}</p>
      <p class="text-slate-500 text-sm">{{ date }}</p>
    </div>
  </div>

  <!-- Row 2: Problem | Solution | Traction -->
  <div class="card-base">
    <p class="text-label text-accent mb-3">Problem</p>
    <p class="text-body text-sm">{{ problem }}</p>
  </div>
  <div class="card-base">
    <p class="text-label text-accent mb-3">Solution</p>
    <p class="text-body text-sm">{{ solution }}</p>
  </div>
  <div class="card-base">
    <p class="text-label text-accent mb-3">Traction</p>
    <div class="grid grid-cols-2 gap-2">
      <StatCard v-for="m in metrics" :value="m.value" :label="m.label" />
    </div>
  </div>

  <!-- Row 3: Market | Team | Ask -->
  <div class="card-base">
    <p class="text-label text-accent mb-3">Market</p>
    <p class="text-heading text-accent">{{ tam }}</p>
    <p class="text-body text-sm opacity-60">{{ market_context }}</p>
  </div>
  <div class="card-base">
    <p class="text-label text-accent mb-3">Team</p>
    <div class="flex flex-col gap-1">
      <p v-for="member in team" class="text-body text-sm">
        <span class="font-semibold">{{ member.name }}</span>
        <span class="opacity-60"> · {{ member.role }}</span>
      </p>
    </div>
  </div>
  <div class="card-base border-blue-400/40">
    <p class="text-label text-accent mb-3">The Ask</p>
    <p class="text-heading text-accent">{{ ask_amount }}</p>
    <p class="text-body text-sm opacity-60 mt-2">{{ ask_use }}</p>
  </div>
</div>
```

**One-pager constraints**:
- No animations (single slide, no clicks)
- Font minimum: 16pt (relaxed from 24pt -- document mode, not projection)
- Use `canvasWidth: 1200` for denser layout
- Export as PNG/PDF with `slidev export --format png`

---

## 5. Protocol-to-Mode Mapping Matrix

**Confidence: HIGH**

| Protocol | INVESTOR | LIGHTNING | DEMO | ONE-PAGER |
|----------|:--------:|:---------:|:----:|:---------:|
| Cover | ✓ | ✓ | ✓ | (inline) |
| Problem Statement | ✓ | ✓ (merged) | ✓ | (inline) |
| Solution | ✓ | ✓ (merged) | ✓ | (inline) |
| Metric Reveal | ✓ | ✓ | ✓ (benchmarks) | (StatCard grid) |
| Team Grid | ✓ | (skip/minimal) | ✓ (minimal) | (inline) |
| Market Size | ✓ | (skip) | (skip) | (inline) |
| Timeline | (appendix) | (skip) | ✓ (onboarding) | (skip) |
| Quote/Testimonial | (optional) | (skip) | (optional) | (skip) |
| Comparison | (optional) | (skip) | ✓ | (skip) |
| Demo/Screenshot | (skip) | ✓ | ✓✓ | (skip) |
| Ask/CTA | ✓ | ✓ (simplified) | ✓ (trial CTA) | (inline) |
| Section Divider | (optional) | (skip) | (optional) | (skip) |

---

## 6. Animation Design Principles for Pitch Decks

**Confidence: HIGH**

These principles should inform the deck-builder-agent when generating slide markdown.

### 6.1 Animation Budget by Deck Mode

| Mode | Animation Budget | Rationale |
|------|-----------------|-----------|
| INVESTOR | Rich (v-click + v-motion) | Controlled pacing, presenter-driven |
| LIGHTNING | Minimal (v-click only) | Time pressure, no motion distractions |
| DEMO | Medium + code-specific | Magic Move for code, minimal elsewhere |
| ONE-PAGER | None | Single slide, no interaction |

### 6.2 v-click vs v-motion

- **v-click**: Use for sequential reveal of bullet points and cards. One concept per click.
- **v-motion**: Use for entrance animations on key numbers and heroes. Pair with v-click via `v-click + v-motion (:enter with delay)`.
- **v-mark**: Use sparingly on 1-2 KEY metrics per deck (circle or highlight). Over-use destroys impact.
- **v-switch**: Use only for Comparison Protocol (A vs B state transitions).

### 6.3 Stagger Timing

Standard stagger delays (milliseconds):
- First item: `0`
- Second item: `100`
- Third item: `200`
- Maximum items in staggered group: 4 (beyond this, use `v-clicks` with default timing)

### 6.4 Transition Selection by Slide Type

| Slide Type | Transition | Rationale |
|-----------|------------|-----------|
| Cover slide | `fade` | Gentle, no direction implied |
| Sequential content | `slide-left` | Forward narrative momentum |
| Section dividers | `slide-left \| slide-right` | Bidirectional navigation |
| Demo screens | `fade` | Screen changes feel like product UI |
| Closing/end | `fade` | Peaceful, contemplative |

---

## 7. Key Technical Findings

**Confidence: HIGH**

### 7.1 Component Auto-Import

Slidev's `unplugin-vue-components` handles auto-import -- no manual imports needed in slide markdown. Components placed in `components/` are immediately available by PascalCase name.

### 7.2 Multiple Addons Supported

Unlike themes (one per project), multiple addons can be loaded simultaneously. A `slidev-addon-deck-protocols` package could provide all components/layouts while leaving the theme choice open to the user.

### 7.3 No Pre-compilation Needed

Vue SFC files (`.vue`) in an addon are published as-is and compiled by Slidev at use time. This simplifies addon authoring -- no build step required for component distribution.

### 7.4 UnoCSS Shortcuts are Additive

Each project's `uno.config.ts` shortcuts are merged, not replaced. An addon can provide base shortcuts (`card-base`, `text-label`) and the project can extend or override them.

### 7.5 Global Context Access

Components and global layers can access `$nav`, `$slidev.configs`, and `$frontmatter` without imports. This enables smart conditional rendering (e.g., hide footer on cover/end layouts).

### 7.6 Arrow Component Built-In

Slidev includes an `<Arrow>` built-in component for diagram annotations. Accepts `x1/y1/x2/y2` coordinates and `color`. Ideal for demo screenshot callouts without external SVG dependencies.

---

## 8. Gaps and Open Questions

### Gap 1: Chart/Graph Component (HIGH PRIORITY)

The YC Traction slide calls for a chart (line/bar). Slidev has no built-in chart component. Options:

1. **`slidev-addon-stem`** -- includes Plotly.js integration (MEDIUM confidence it covers simple charts)
2. **Chart.js via `setup/main.ts`** -- register globally as `<ChartLine>` component
3. **SVG-only approach** -- pure CSS bar charts using grid columns (no dependency, simpler)
4. **`vue-chartjs`** -- lightweight Vue wrapper for Chart.js

**Recommendation**: Use a simple CSS-only bar chart for traction (avoids dependencies) with an optional upgrade path to Chart.js for complex datasets.

### Gap 2: Typst Template Color Palettes

The existing system has 5 Typst templates with distinct color palettes. The Slidev port needs equivalent CSS theme variants. The `themeConfig.primary` in seriph theme handles one color; full palette variants require separate `uno.config.ts` shortcuts or CSS custom properties.

**Recommendation**: Define 3-5 CSS variable sets as named "palettes" switchable via frontmatter `class:` attribute.

### Gap 3: Animation Timing in INVESTOR vs LIGHTNING

The deck-builder-agent needs to know which deck mode it's building to apply the correct animation budget. This should be stored in `forcing_data.mode` and passed as a context variable.

### Gap 4: One-Pager Font Minimum Relaxation

YC font rules specify 24pt minimum. The one-pager mode physically cannot fit all content at 24pt. The agent rules need a documented exception: "ONE-PAGER mode relaxes font minimums to 16pt (document viewing context, not projected)."

---

## 9. Summary and Recommendations

### For the Implementation Plan

1. **Define protocols first** (this document) -- protocols are the atomic units all modes compose from.
2. **Build component library** -- `MetricCard`, `TeamMember`, `TimelineItem`, `ComparisonCol` are the 4 core components. `StatCard` needed for one-pager.
3. **Design 5 custom layouts** -- `cover-hero`, `metric-grid`, `team-showcase`, `ask-slide`, `section-accent` cover all 4 modes.
4. **Write `uno.config.ts`** -- design tokens are the foundation; all components depend on them.
5. **Write `styles/index.css`** -- global dark theme from report 04 (already researched).
6. **Port deck-builder-agent** -- agent generates slide markdown using protocol templates, not raw Slidev syntax.

### Confidence Assessment

| Finding | Confidence | Basis |
|---------|-----------|-------|
| Component auto-import via `components/` | HIGH | Official Slidev docs confirmed |
| Layout system via `layouts/` named slots | HIGH | Official docs + source examples |
| Global layers (global-bottom.vue) | HIGH | Official docs confirmed |
| UnoCSS shortcuts via `uno.config.ts` | HIGH | Official docs confirmed |
| Addon system (multi-addon support) | HIGH | Official docs confirmed |
| Protocol designs (animation patterns) | MEDIUM | Inferred from docs, not battle-tested |
| One-pager dense grid approach | MEDIUM | Designed here, not from existing template |
| Chart.js integration approach | LOW | Not yet validated against Slidev internals |

---

## Sources

- [Slidev Components Guide](https://sli.dev/guide/component)
- [Slidev Directory Structure](https://sli.dev/custom/directory-structure)
- [Slidev Layouts Guide](https://sli.dev/guide/write-layout)
- [Slidev Built-in Layouts](https://sli.dev/builtin/layouts)
- [Slidev Built-in Components](https://sli.dev/builtin/components)
- [Slidev Global Layers](https://sli.dev/features/global-layers)
- [Slidev Global Context](https://sli.dev/guide/global-context)
- [Slidev Animations](https://sli.dev/guide/animations.html)
- [Slidev Addon System](https://sli.dev/guide/theme-addon)
- [Slidev Write Addons](https://sli.dev/guide/write-addon)
- [Slidev UnoCSS Config](https://sli.dev/custom/config-unocss)
- [Slidev Components System DeepWiki](https://deepwiki.com/slidevjs/slidev/4.3-components-system)
- [GitHub: slidev-addon-components](https://github.com/estruyf/slidev-addon-components)
- [GitHub: Slidev Addons Topic](https://github.com/topics/slidev-addon)
- [YC Pitch Deck Structure](https://www.ycombinator.com/library/2u-how-to-build-your-seed-round-pitch-deck)
- Existing codebase: `/home/benjamin/.config/nvim/.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md`
- Existing codebase: `/home/benjamin/.config/nvim/.claude/extensions/founder/commands/deck.md`
- Existing research: `specs/345_port_deck_typst_to_slidev/reports/04_slidev-themes-research.md`
