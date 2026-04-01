# Teammate C Findings: Animation Library, Styling System, and Integration Architecture

**Task**: 345 - Port /deck command-skill-agent from Typst to Slidev
**Date**: 2026-04-01
**Teammate**: C — Animation Library, Styling System, Integration Architecture

---

## Executive Summary

This report provides: (1) a comprehensive animation pattern library covering all major Slidev animation mechanisms; (2) a composable styling preset system for dark AI startup decks; (3) reusable Vue component designs for pitch deck slide types; (4) the definitive Slidev project directory structure and integration architecture; and (5) build/export pipeline details with CI/CD patterns. All findings are based on official Slidev documentation (sli.dev), @vueuse/motion docs, and community resources.

---

## 1. Animation Pattern Library

### 1.1 Core Animation Mechanisms

Slidev provides four orthogonal animation systems that compose together:

| System | Mechanism | Purpose |
|--------|-----------|---------|
| `v-click` / `v-clicks` | Click-step visibility | Progressive content reveal |
| `v-motion` | @vueuse/motion transforms | Spatial/physics animations |
| `v-mark` | Rough Notation | Hand-drawn emphasis marks |
| `transition:` frontmatter | Vue Transition + View Transitions API | Slide-to-slide transitions |

**Confidence: High** — All four are official, stable APIs.

---

### 1.2 Entrance Animation Patterns

#### Pattern A: Fade-In (Simplest)

**Category**: Entrance  
**Mechanism**: CSS override on `.slidev-vclick-target`  
**When to use**: Default for bullet lists, when spatial movement would distract  
**When NOT to use**: Cover slides (use motion instead), data reveals (use cascade)

```css
/* styles/index.css — global default */
.slidev-vclick-target {
  transition: opacity 0.5s cubic-bezier(0.16, 1, 0.3, 1);
}
.slidev-vclick-hidden {
  opacity: 0;
}
```

```html
<v-clicks>

- Problem statement
- Market size
- Our solution

</v-clicks>
```

**Performance**: Excellent — pure CSS opacity, GPU-composited.

---

#### Pattern B: Slide-In from Below

**Category**: Entrance  
**Mechanism**: `v-motion` + `v-click` combined  
**When to use**: Individual feature cards, team members, key points needing emphasis  
**When NOT to use**: Dense lists (too much visual noise)

```html
<div v-click v-motion
  :initial="{ y: 40, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { duration: 500, easing: 'cubic-bezier(0.16,1,0.3,1)' } }"
>
  Feature highlight
</div>
```

**Performance**: Good — y-transform is GPU-composited. Avoid animating layout properties like `height` or `margin`.

---

#### Pattern C: Scale-In (Pop-In)

**Category**: Entrance  
**Mechanism**: `v-motion`  
**When to use**: Modal-style reveals, key metrics, call-to-action elements  
**When NOT to use**: Consecutive slides of content (fatigue)

```html
<div v-motion
  :initial="{ scale: 0.85, opacity: 0 }"
  :enter="{ scale: 1, opacity: 1, transition: { type: 'spring', stiffness: 300, damping: 20 } }"
>
  <span class="text-6xl font-bold">$12M</span>
</div>
```

**Performance**: Good — scale is GPU-composited. Spring physics feel natural for numbers.

---

#### Pattern D: Blur-In

**Category**: Entrance  
**Mechanism**: CSS override on `.slidev-vclick-target` with filter  
**When to use**: Premium "focus" reveals, section transitions  
**When NOT to use**: Elements with complex child content (filter can cause sub-pixel issues)

```css
/* Per-slide scoped style */
<style>
.blur-reveal.slidev-vclick-target {
  transition: all 0.6s cubic-bezier(0.16, 1, 0.3, 1);
}
.blur-reveal.slidev-vclick-hidden {
  opacity: 0;
  filter: blur(8px);
  transform: scale(0.98);
}
</style>
```

```html
<div v-click class="blur-reveal">
  AI-powered insight
</div>
```

**Performance**: Medium — `filter: blur` triggers a compositing layer but is more expensive than opacity/transform alone. Limit to 1-2 elements per slide.

---

### 1.3 Data Reveal Patterns

#### Pattern E: Staggered Metric Cascade

**Category**: Data reveal  
**Mechanism**: `v-motion` with staggered `delay` transitions on sequential `v-click` steps  
**When to use**: KPI slides, traction slides with 3-4 metrics  
**When NOT to use**: More than 4 metrics (too long; split into two slides)

```html
<div class="grid grid-cols-3 gap-12 mt-8">
  <div v-click class="text-center"
    v-motion
    :initial="{ y: 30, opacity: 0 }"
    :enter="{ y: 0, opacity: 1, transition: { delay: 0, duration: 600 } }"
  >
    <div class="text-5xl font-bold text-blue-400">$2M</div>
    <div class="text-sm text-slate-400 mt-2">ARR</div>
  </div>

  <div v-click class="text-center"
    v-motion
    :initial="{ y: 30, opacity: 0 }"
    :enter="{ y: 0, opacity: 1, transition: { delay: 100, duration: 600 } }"
  >
    <div class="text-5xl font-bold text-blue-400">340%</div>
    <div class="text-sm text-slate-400 mt-2">YoY Growth</div>
  </div>

  <div v-click class="text-center"
    v-motion
    :initial="{ y: 30, opacity: 0 }"
    :enter="{ y: 0, opacity: 1, transition: { delay: 200, duration: 600 } }"
  >
    <div class="text-5xl font-bold text-blue-400">50K+</div>
    <div class="text-sm text-slate-400 mt-2">API Calls/Day</div>
  </div>
</div>
```

---

#### Pattern F: Animated Counter (NumberFlow)

**Category**: Data reveal  
**Mechanism**: `<NumberFlow>` Vue component from `@number-flow/vue`  
**When to use**: Live demo slides, "before/after" number comparisons, dramatic metric reveals  
**When NOT to use**: Static slides, presentations where interactivity seems odd

```bash
# Add to project
npm add @number-flow/vue
```

```vue
<!-- components/AnimatedMetric.vue -->
<script setup>
import NumberFlow from '@number-flow/vue'
import { ref, onMounted } from 'vue'

const props = defineProps({
  value: { type: Number, required: true },
  prefix: { type: String, default: '' },
  suffix: { type: String, default: '' },
  format: { type: Object, default: () => ({}) },
  delay: { type: Number, default: 0 }
})

const displayValue = ref(0)

onMounted(() => {
  setTimeout(() => {
    displayValue.value = props.value
  }, props.delay)
})
</script>

<template>
  <NumberFlow
    :value="displayValue"
    :prefix="prefix"
    :suffix="suffix"
    :format="format"
    :transform-timing="{ duration: 800, easing: 'ease-out' }"
    :spin-timing="{ duration: 600 }"
  />
</template>
```

Usage in slide:
```html
<AnimatedMetric :value="2000000" prefix="$" :format="{ notation: 'compact' }" />
<!-- Displays: $2M (animates from 0) -->
```

**Performance**: Good — NumberFlow uses CSS animations internally. `@respectMotionPreference` defaults to true.

---

#### Pattern G: Chart Build (Sequential Bar Reveal)

**Category**: Data reveal  
**Mechanism**: `v-click` with CSS height transition  
**When to use**: Revenue growth charts, market share visualization  
**When NOT to use**: Complex charts requiring interaction (use embedded iframe instead)

```vue
<!-- components/BarChart.vue -->
<script setup>
defineProps({
  bars: {
    type: Array, // [{ label, value, maxValue, color }]
    required: true
  }
})
</script>

<template>
  <div class="flex items-end gap-4 h-48">
    <div
      v-for="(bar, i) in bars"
      :key="i"
      v-click
      class="flex flex-col items-center gap-2"
    >
      <div class="text-xs text-slate-400">{{ bar.label }}</div>
      <div
        class="w-16 rounded-t transition-all duration-700"
        :style="{
          height: `${(bar.value / bar.maxValue) * 100}%`,
          backgroundColor: bar.color || '#60a5fa'
        }"
        v-motion
        :initial="{ scaleY: 0, originY: 1 }"
        :enter="{ scaleY: 1, transition: { delay: i * 150, duration: 600 } }"
      />
      <div class="text-sm font-bold">{{ bar.value }}</div>
    </div>
  </div>
</template>
```

---

### 1.4 Emphasis Animation Patterns

#### Pattern H: Rough Notation Marks (v-mark)

**Category**: Emphasis  
**Mechanism**: `v-mark` directive  
**When to use**: Circle key metrics, highlight terms, underline claims  
**When NOT to use**: Decorating entire paragraphs (too noisy)

```html
<!-- Available mark types -->
<span v-mark.circle="{ color: '#60a5fa', strokeWidth: 2 }">$2M ARR</span>
<span v-mark.highlight="{ color: 'rgba(96, 165, 250, 0.25)' }">market leader</span>
<span v-mark.underline="{ color: '#a78bfa' }">10x faster</span>
<span v-mark.box="{ color: '#34d399' }">critical advantage</span>
<span v-mark.strike-through="{ color: '#f87171' }">legacy approach</span>
<span v-mark.bracket="{ color: '#fbbf24' }">key insight</span>

<!-- Click-triggered (triggers on click N, not on slide entry) -->
<span v-mark="3">appears circled on click 3</span>

<!-- Combined with v-click for full control -->
<span v-click v-mark.circle>Appears AND gets circled on same click</span>
```

**Performance**: Excellent — SVG-drawn, very lightweight.

---

#### Pattern I: Pulse Glow (CSS)

**Category**: Emphasis  
**Mechanism**: CSS `@keyframes` animation  
**When to use**: Drawing attention to a single element that persists on screen  
**When NOT to use**: Multiple elements simultaneously (chaos)

```vue
<!-- components/GlowPulse.vue -->
<template>
  <div class="glow-pulse" :style="{ '--glow-color': color }">
    <slot />
  </div>
</template>

<script setup>
defineProps({
  color: { type: String, default: '#60a5fa' }
})
</script>

<style scoped>
.glow-pulse {
  animation: pulse-glow 2.5s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

@keyframes pulse-glow {
  0%, 100% {
    text-shadow:
      0 0 10px var(--glow-color),
      0 0 20px var(--glow-color),
      0 0 40px var(--glow-color);
    opacity: 1;
  }
  50% {
    text-shadow:
      0 0 5px var(--glow-color),
      0 0 10px var(--glow-color);
    opacity: 0.85;
  }
}
</style>
```

---

### 1.5 Sequence Patterns

#### Pattern J: Staggered List (v-clicks with depth)

**Category**: Sequence  
**Mechanism**: `v-clicks` component with `depth` prop  
**When to use**: Bullet-point slides, feature lists, agenda slides  
**When NOT to use**: Non-hierarchical content

```html
<!-- Reveal top-level items one at a time -->
<v-clicks>

- First point
- Second point
- Third point

</v-clicks>

<!-- Reveal nested items with depth control -->
<v-clicks depth="2">

- Category A
  - Item 1
  - Item 2
- Category B
  - Item 3

</v-clicks>

<!-- Reveal every N children (e.g., pairs) -->
<v-clicks every="2">
  <div>Pair 1 item A</div>
  <div>Pair 1 item B</div>
  <div>Pair 2 item A</div>
  <div>Pair 2 item B</div>
</v-clicks>
```

---

#### Pattern K: Cascade Grid (Staggered Entrance)

**Category**: Sequence  
**Mechanism**: `v-motion` with index-based delay, wrapped in `v-clicks`  
**When to use**: Feature grids, team photo grids, partner logo clouds  
**When NOT to use**: Linear content that reads top-to-bottom

```html
<div class="grid grid-cols-3 gap-6">
  <div
    v-for="(item, i) in items"
    :key="i"
    v-click
    v-motion
    :initial="{ opacity: 0, scale: 0.9 }"
    :enter="{
      opacity: 1,
      scale: 1,
      transition: { delay: i * 80, duration: 400, type: 'spring', stiffness: 400, damping: 25 }
    }"
    class="p-4 rounded-lg border border-slate-700 bg-slate-800/50"
  >
    {{ item.name }}
  </div>
</div>
```

---

#### Pattern L: Typewriter (CSS Animation)

**Category**: Sequence  
**Mechanism**: CSS `steps()` animation  
**When to use**: Code reveals, terminal-style text, demo slides with "typing" effect  
**When NOT to use**: Long paragraphs (impractical), any text needing to be selectable during animation

```vue
<!-- components/Typewriter.vue -->
<template>
  <span class="typewriter" :style="{ '--chars': text.length, '--duration': `${text.length * 0.06}s` }">
    {{ text }}
  </span>
</template>

<script setup>
defineProps({ text: { type: String, required: true } })
</script>

<style scoped>
.typewriter {
  display: inline-block;
  overflow: hidden;
  white-space: nowrap;
  border-right: 2px solid currentColor;
  width: 0;
  animation:
    typing var(--duration) steps(var(--chars)) forwards,
    blink 0.75s step-end infinite;
}

@keyframes typing {
  from { width: 0 }
  to { width: 100% }
}

@keyframes blink {
  from, to { border-color: transparent }
  50% { border-color: currentColor }
}
</style>
```

---

### 1.6 Slide Transition + Element Animation Combinations

**Confidence: High**

The key rule: slide `transition:` and element `v-motion`/`v-click` are independent. When slide transitions fire, `initial`/`enter` states reset for the incoming slide. Coordinate them via `transition.delay` on `v-motion` to let the slide transition complete before elements animate.

```yaml
---
transition: fade  # 300ms fade
---
```

```html
<!-- Add 350ms delay so fade completes before elements cascade in -->
<div v-motion
  :initial="{ y: 20, opacity: 0 }"
  :enter="{ y: 0, opacity: 1, transition: { delay: 350, duration: 500 } }"
>
  Headline
</div>
```

**Recommended pairings**:

| Slide Transition | Element Animation | Use Case |
|-----------------|-------------------|----------|
| `fade` (300ms) | `v-motion` y-enter with 350ms delay | Default for most slides |
| `slide-left` | `v-motion` x-enter (same direction) | Sequential sections |
| `view-transition` | CSS `view-transition-name` on hero element | Cross-slide morphing |
| Custom zoom-fade | `v-motion` scale-enter | High-impact reveal slides |

---

### 1.7 View Transition (Cross-Slide Element Morphing)

**Confidence: Medium** — Feature works but has known interaction with v-click; test carefully.

The View Transitions API allows elements with the same `view-transition-name` to morph between slides. Known issue: when `transition: view-transition` is set globally, the morph fires on every click step, not just slide changes. Mitigation: use `view-transition` only on slides where it's needed, not globally.

```yaml
---
# On the source slide
transition: view-transition
---

<h1 style="view-transition-name: company-name">NeuralCo</h1>
<p style="view-transition-name: company-tagline">Intelligence at scale</p>
```

```yaml
---
# On the destination slide
---

<h2 style="view-transition-name: company-name">NeuralCo</h2>
<!-- Title morphs from h1 to h2 -->
```

---

## 2. Styling Preset System

### 2.1 Design Approach

All presets are composable CSS files placed in `styles/presets/`. The `styles/index.css` imports selected presets. Per-slide `<style>` blocks use scoped CSS to override for specific slides.

```
styles/
├── index.css           # Imports selected presets
└── presets/
    ├── colors/
    │   ├── dark-blue.css
    │   ├── dark-purple.css
    │   ├── dark-green.css
    │   └── dark-warm.css
    ├── typography/
    │   ├── serif-heading.css
    │   ├── mono-heading.css
    │   └── all-sans.css
    └── textures/
        ├── grid-overlay.css
        ├── noise-grain.css
        └── gradient-radial.css
```

---

### 2.2 Color Palette Presets

#### `styles/presets/colors/dark-blue.css`

```css
/* Dark Blue — Default AI startup palette */
:root {
  --color-bg-base: #0a0a1a;
  --color-bg-secondary: #0f0f2e;
  --color-accent-primary: #60a5fa;   /* blue-400 */
  --color-accent-secondary: #a78bfa; /* violet-400 */
  --color-text-primary: #f1f5f9;
  --color-text-secondary: #94a3b8;
  --color-text-muted: #475569;
  --color-border: rgba(96, 165, 250, 0.15);
}

.slidev-layout {
  background:
    radial-gradient(ellipse at 15% 80%, rgba(59, 130, 246, 0.07) 0%, transparent 50%),
    radial-gradient(ellipse at 85% 20%, rgba(139, 92, 246, 0.05) 0%, transparent 50%),
    linear-gradient(180deg, var(--color-bg-base) 0%, var(--color-bg-secondary) 100%);
  color: var(--color-text-primary);
}
```

#### `styles/presets/colors/dark-purple.css`

```css
/* Dark Purple — Premium/luxury AI aesthetic */
:root {
  --color-bg-base: #0d0a1a;
  --color-bg-secondary: #12102a;
  --color-accent-primary: #a78bfa;   /* violet-400 */
  --color-accent-secondary: #f472b6; /* pink-400 */
  --color-text-primary: #f5f3ff;
  --color-text-secondary: #a78bfa;
  --color-text-muted: #6d55a0;
  --color-border: rgba(167, 139, 250, 0.2);
}

.slidev-layout {
  background:
    radial-gradient(ellipse at 20% 30%, rgba(139, 92, 246, 0.12) 0%, transparent 50%),
    radial-gradient(ellipse at 80% 70%, rgba(244, 114, 182, 0.06) 0%, transparent 50%),
    linear-gradient(180deg, var(--color-bg-base) 0%, var(--color-bg-secondary) 100%);
  color: var(--color-text-primary);
}
```

#### `styles/presets/colors/dark-green.css`

```css
/* Dark Green — Biopharma / sustainability / data science */
:root {
  --color-bg-base: #030a0a;
  --color-bg-secondary: #071a0f;
  --color-accent-primary: #34d399;   /* emerald-400 */
  --color-accent-secondary: #60a5fa; /* blue-400 */
  --color-text-primary: #ecfdf5;
  --color-text-secondary: #6ee7b7;
  --color-text-muted: #34d39980;
  --color-border: rgba(52, 211, 153, 0.2);
}

.slidev-layout {
  background:
    radial-gradient(ellipse at 30% 70%, rgba(16, 185, 129, 0.1) 0%, transparent 50%),
    linear-gradient(180deg, var(--color-bg-base) 0%, var(--color-bg-secondary) 100%);
  color: var(--color-text-primary);
}
```

#### `styles/presets/colors/dark-warm.css`

```css
/* Dark Warm — Fintech / consumer / brand-forward */
:root {
  --color-bg-base: #0f0a05;
  --color-bg-secondary: #1a1005;
  --color-accent-primary: #fb923c;   /* orange-400 */
  --color-accent-secondary: #fbbf24; /* amber-400 */
  --color-text-primary: #fef3c7;
  --color-text-secondary: #d97706;
  --color-text-muted: #92400e;
  --color-border: rgba(251, 146, 60, 0.2);
}

.slidev-layout {
  background:
    radial-gradient(ellipse at 70% 20%, rgba(251, 146, 60, 0.08) 0%, transparent 50%),
    linear-gradient(180deg, var(--color-bg-base) 0%, var(--color-bg-secondary) 100%);
  color: var(--color-text-primary);
}
```

---

### 2.3 Typography Pairings

#### `styles/presets/typography/serif-heading.css`

Pairs with Google Fonts in headmatter: `fonts: { sans: 'Inter', serif: 'Playfair Display', mono: 'JetBrains Mono' }`

```css
h1, h2 {
  font-family: 'Playfair Display', Georgia, serif;
  letter-spacing: -0.02em;
  font-weight: 700;
  color: var(--color-text-primary, #f1f5f9);
}

h1 { font-size: 3em; line-height: 1.1; }
h2 { font-size: 2.2em; line-height: 1.2; }
h3 { font-size: 1.5em; }

p, li, .body-text {
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 1.3em;
  line-height: 1.65;
  color: var(--color-text-secondary, #94a3b8);
}

code, kbd, pre {
  font-family: 'JetBrains Mono', 'Fira Code', monospace;
}
```

#### `styles/presets/typography/mono-heading.css`

For dev-tool or SaaS product decks:

```css
h1, h2, h3 {
  font-family: 'JetBrains Mono', 'Fira Code', monospace;
  font-weight: 700;
  letter-spacing: -0.03em;
  color: var(--color-text-primary, #f1f5f9);
}

h1 { font-size: 2.8em; }
h2 { font-size: 2em; }

p, li {
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 1.3em;
  line-height: 1.65;
}
```

---

### 2.4 Background Texture Presets

#### `styles/presets/textures/grid-overlay.css`

```css
.slidev-layout::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(255, 255, 255, 0.015) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255, 255, 255, 0.015) 1px, transparent 1px);
  background-size: 60px 60px;
  pointer-events: none;
  z-index: 0;
}
```

#### `styles/presets/textures/noise-grain.css`

```css
.slidev-layout::after {
  content: '';
  position: absolute;
  inset: 0;
  opacity: 0.035;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E");
  pointer-events: none;
  z-index: 0;
}
```

#### `styles/presets/textures/gradient-radial.css`

A stronger radial "spotlight" for high-drama slides:

```css
.slidev-layout {
  background:
    radial-gradient(ellipse 80% 60% at 50% 0%, rgba(var(--glow-rgb, 59 130 246) / 0.12) 0%, transparent 70%),
    var(--color-bg-base, #0a0a1a);
}
```

Usage: set `--glow-rgb: 139 92 246` per slide for different accent glows.

---

### 2.5 Composing Presets

`styles/index.css`:

```css
/* 1. Pick your color palette */
@import './presets/colors/dark-blue.css';

/* 2. Pick your typography */
@import './presets/typography/serif-heading.css';

/* 3. Pick your texture(s) */
@import './presets/textures/grid-overlay.css';
@import './presets/textures/noise-grain.css';

/* 4. Global overrides */
.slidev-vclick-target {
  transition: all 0.45s cubic-bezier(0.16, 1, 0.3, 1);
}
.slidev-vclick-hidden {
  opacity: 0;
  transform: translateY(8px);
}
```

**Per-slide override** example (scoped CSS, Vue-scoped, no leakage):

```markdown
---
layout: cover
background: /images/hero.jpg
---

# The Future of AI

<style>
.slidev-layout {
  /* override global gradient for this slide only */
  background: linear-gradient(135deg, rgba(10,10,26,0.9) 0%, rgba(26,10,46,0.85) 100%),
              url('/images/hero.jpg') center/cover;
}
h1 {
  font-size: 4em;
  background: linear-gradient(135deg, #f1f5f9, #a78bfa);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}
</style>
```

---

### 2.6 UnoCSS Configuration

**Confidence: High** — UnoCSS is the default CSS engine since Slidev v0.42.0.

Create `uno.config.ts` at project root:

```typescript
import { defineConfig } from 'unocss'

export default defineConfig({
  shortcuts: {
    // Deck-specific shortcuts
    'text-accent': 'text-blue-400',
    'text-muted': 'text-slate-400',
    'card-dark': 'bg-slate-800/50 border border-slate-700 rounded-xl p-6',
    'metric-number': 'text-5xl font-bold text-blue-400 tabular-nums',
    'metric-label': 'text-sm text-slate-400 mt-2 uppercase tracking-widest',
    'slide-title': 'text-4xl font-serif font-bold text-slate-100',
    'slide-subtitle': 'text-xl text-slate-400 font-light',
    'grid-2': 'grid grid-cols-2 gap-8',
    'grid-3': 'grid grid-cols-3 gap-6',
    'abs-br': 'absolute bottom-0 right-0',
    'abs-bl': 'absolute bottom-0 left-0',
  },
  theme: {
    colors: {
      accent: '#60a5fa',
      'accent-2': '#a78bfa',
    }
  },
  safelist: [
    // Safelist dynamic classes used in components
    'text-blue-400', 'text-violet-400', 'text-emerald-400', 'text-orange-400',
    'bg-blue-400/10', 'bg-violet-400/10',
  ]
})
```

UnoCSS utility classes work directly in slide Markdown HTML:

```html
<div class="card-dark grid-2">
  <div class="metric-number">$2M</div>
  <div class="metric-label">ARR</div>
</div>
```

---

## 3. Custom Vue Components for Pitch Decks

All components live in `components/` and are auto-imported by `unplugin-vue-components`. No import statements needed in slide Markdown.

**Confidence: High** — Auto-import from `components/` is official and stable.

---

### 3.1 MetricCard

```vue
<!-- components/MetricCard.vue -->
<script setup>
import { ref, onMounted } from 'vue'

const props = defineProps({
  value: { type: String, required: true },      // e.g. "$2M" or "340%"
  label: { type: String, required: true },
  sublabel: { type: String, default: '' },
  color: { type: String, default: 'blue-400' }, // Tailwind color name
  animate: { type: Boolean, default: true },
  delay: { type: Number, default: 0 }           // ms
})

const visible = ref(false)
onMounted(() => {
  setTimeout(() => { visible.value = true }, props.delay)
})
</script>

<template>
  <div
    class="text-center p-6 rounded-xl border border-slate-700/50 bg-slate-800/30 backdrop-blur-sm"
    v-motion
    :initial="animate ? { y: 20, opacity: 0 } : {}"
    :enter="animate ? { y: 0, opacity: 1, transition: { delay, duration: 600 } } : {}"
  >
    <div :class="`text-5xl font-bold text-${color} tabular-nums`">
      {{ value }}
    </div>
    <div class="text-base text-slate-300 mt-3 font-medium">{{ label }}</div>
    <div v-if="sublabel" class="text-xs text-slate-500 mt-1">{{ sublabel }}</div>
  </div>
</template>
```

Usage:
```html
<div class="grid grid-cols-3 gap-8">
  <MetricCard v-click value="$2M" label="ARR" sublabel="Annual Recurring Revenue" :delay="0" />
  <MetricCard v-click value="340%" label="YoY Growth" color="violet-400" :delay="100" />
  <MetricCard v-click value="50K+" label="API Calls/Day" color="emerald-400" :delay="200" />
</div>
```

---

### 3.2 TeamGrid

```vue
<!-- components/TeamGrid.vue -->
<script setup>
defineProps({
  members: {
    type: Array, // [{ name, role, image, linkedin? }]
    required: true
  },
  cols: { type: Number, default: 3 }
})
</script>

<template>
  <div :class="`grid grid-cols-${cols} gap-8`">
    <div
      v-for="(member, i) in members"
      :key="i"
      v-click
      v-motion
      :initial="{ opacity: 0, scale: 0.92 }"
      :enter="{ opacity: 1, scale: 1, transition: { delay: i * 100, duration: 400 } }"
      class="text-center"
    >
      <img
        :src="member.image"
        :alt="member.name"
        class="w-24 h-24 rounded-full mx-auto object-cover border-2 border-slate-600"
      />
      <div class="text-base font-semibold text-slate-200 mt-3">{{ member.name }}</div>
      <div class="text-sm text-slate-400">{{ member.role }}</div>
      <a
        v-if="member.linkedin"
        :href="member.linkedin"
        class="text-xs text-blue-400 mt-1 inline-block hover:underline"
        target="_blank"
      >LinkedIn</a>
    </div>
  </div>
</template>
```

Usage:
```html
<TeamGrid :members="[
  { name: 'Jane Doe', role: 'CEO / Co-founder', image: '/team/jane.jpg', linkedin: 'https://...' },
  { name: 'John Smith', role: 'CTO / Co-founder', image: '/team/john.jpg' },
  { name: 'Alice Chen', role: 'Head of AI', image: '/team/alice.jpg' }
]" />
```

---

### 3.3 TimelineItem

```vue
<!-- components/TimelineItem.vue -->
<script setup>
defineProps({
  year: { type: String, required: true },
  title: { type: String, required: true },
  description: { type: String, default: '' },
  active: { type: Boolean, default: false },
  last: { type: Boolean, default: false }
})
</script>

<template>
  <div class="flex gap-4" v-click v-motion :initial="{ x: -20, opacity: 0 }" :enter="{ x: 0, opacity: 1 }">
    <!-- Node column -->
    <div class="flex flex-col items-center">
      <div
        :class="[
          'w-4 h-4 rounded-full border-2 shrink-0 mt-1',
          active ? 'bg-blue-400 border-blue-400' : 'bg-transparent border-slate-500'
        ]"
      />
      <div v-if="!last" class="w-px flex-1 bg-slate-700 mt-1" />
    </div>

    <!-- Content column -->
    <div class="pb-6">
      <div class="text-xs text-slate-500 uppercase tracking-widest">{{ year }}</div>
      <div :class="['text-base font-semibold', active ? 'text-blue-400' : 'text-slate-200']">
        {{ title }}
      </div>
      <div v-if="description" class="text-sm text-slate-400 mt-1">{{ description }}</div>
    </div>
  </div>
</template>
```

Usage:
```html
<TimelineItem year="2022" title="Founded" description="Series Seed, $1.5M" />
<TimelineItem year="2023" title="Product Launch" description="First 100 customers" />
<TimelineItem year="2024" title="Series A" description="$12M raise, 50 employees" active />
<TimelineItem year="2025" title="Enterprise" description="Fortune 500 pipeline" :last="true" />
```

---

### 3.4 ComparisonTable

```vue
<!-- components/ComparisonTable.vue -->
<script setup>
defineProps({
  headers: { type: Array, required: true }, // ['Feature', 'Us', 'Competitor A', 'Competitor B']
  rows: {
    type: Array, // [{ feature, values: [true/false/'text', ...] }]
    required: true
  },
  highlightCol: { type: Number, default: 1 } // 1-based, column to highlight as "Us"
})
</script>

<template>
  <table class="w-full text-sm border-collapse">
    <thead>
      <tr>
        <th
          v-for="(h, i) in headers"
          :key="i"
          :class="[
            'py-3 px-4 text-left font-semibold border-b border-slate-700',
            i === highlightCol ? 'text-blue-400 bg-blue-400/5' : 'text-slate-400'
          ]"
        >{{ h }}</th>
      </tr>
    </thead>
    <tbody>
      <tr
        v-for="(row, ri) in rows"
        :key="ri"
        v-click
        class="border-b border-slate-800/50 hover:bg-slate-800/20 transition-colors"
      >
        <td class="py-3 px-4 text-slate-300 font-medium">{{ row.feature }}</td>
        <td
          v-for="(val, vi) in row.values"
          :key="vi"
          :class="['py-3 px-4 text-center', vi + 1 === highlightCol ? 'bg-blue-400/5' : '']"
        >
          <span v-if="val === true" class="text-emerald-400 text-lg">✓</span>
          <span v-else-if="val === false" class="text-red-400/70 text-lg">✗</span>
          <span v-else class="text-slate-300">{{ val }}</span>
        </td>
      </tr>
    </tbody>
  </table>
</template>
```

---

### 3.5 QuoteBlock

```vue
<!-- components/QuoteBlock.vue -->
<script setup>
defineProps({
  quote: { type: String, required: true },
  author: { type: String, required: true },
  role: { type: String, default: '' },
  avatar: { type: String, default: '' }
})
</script>

<template>
  <blockquote
    v-motion
    :initial="{ opacity: 0, y: 20 }"
    :enter="{ opacity: 1, y: 0, transition: { duration: 600 } }"
    class="relative p-8 rounded-2xl bg-slate-800/40 border border-slate-700/50"
  >
    <span class="absolute top-4 left-6 text-6xl text-blue-400/30 font-serif leading-none">"</span>
    <p class="text-xl text-slate-200 font-light italic leading-relaxed relative z-10 mt-4">
      {{ quote }}
    </p>
    <footer class="flex items-center gap-3 mt-6">
      <img
        v-if="avatar"
        :src="avatar"
        class="w-10 h-10 rounded-full object-cover border border-slate-600"
      />
      <div>
        <div class="text-sm font-semibold text-slate-200">{{ author }}</div>
        <div v-if="role" class="text-xs text-slate-500">{{ role }}</div>
      </div>
    </footer>
  </blockquote>
</template>
```

---

### 3.6 LogoCloud

```vue
<!-- components/LogoCloud.vue -->
<script setup>
defineProps({
  logos: {
    type: Array, // [{ src, alt, url? }]
    required: true
  },
  label: { type: String, default: 'Trusted by' },
  cols: { type: Number, default: 5 }
})
</script>

<template>
  <div>
    <p v-if="label" class="text-xs text-slate-500 uppercase tracking-widest text-center mb-6">
      {{ label }}
    </p>
    <div
      :class="`grid grid-cols-${cols} gap-8 items-center`"
    >
      <a
        v-for="(logo, i) in logos"
        :key="i"
        v-click
        :href="logo.url || '#'"
        :target="logo.url ? '_blank' : ''"
        class="flex items-center justify-center opacity-40 hover:opacity-70 transition-opacity"
      >
        <img :src="logo.src" :alt="logo.alt" class="max-h-8 max-w-[120px] object-contain grayscale" />
      </a>
    </div>
  </div>
</template>
```

---

### 3.7 FeatureList

```vue
<!-- components/FeatureList.vue -->
<script setup>
defineProps({
  features: {
    type: Array, // [{ icon?, title, description? }]
    required: true
  },
  stagger: { type: Boolean, default: true }
})
</script>

<template>
  <ul class="space-y-4">
    <li
      v-for="(feat, i) in features"
      :key="i"
      v-click
      v-motion
      :initial="{ x: -16, opacity: 0 }"
      :enter="{ x: 0, opacity: 1, transition: { delay: stagger ? i * 80 : 0, duration: 400 } }"
      class="flex items-start gap-4"
    >
      <span
        v-if="feat.icon"
        class="text-xl mt-0.5 shrink-0"
      >{{ feat.icon }}</span>
      <div v-else class="w-1.5 h-1.5 rounded-full bg-blue-400 mt-2.5 shrink-0" />
      <div>
        <span class="text-slate-200 font-medium">{{ feat.title }}</span>
        <span v-if="feat.description" class="text-slate-400 text-sm ml-2">{{ feat.description }}</span>
      </div>
    </li>
  </ul>
</template>
```

---

### 3.8 CTASlide

```vue
<!-- components/CTASlide.vue -->
<script setup>
defineProps({
  headline: { type: String, default: "Let's build together" },
  subtext: { type: String, default: '' },
  email: { type: String, default: '' },
  website: { type: String, default: '' },
  deck: { type: String, default: '' }
})
</script>

<template>
  <div class="text-center space-y-8">
    <h1
      v-motion
      :initial="{ y: -20, opacity: 0 }"
      :enter="{ y: 0, opacity: 1, transition: { duration: 600 } }"
      class="text-5xl font-serif font-bold text-slate-100"
    >
      {{ headline }}
    </h1>

    <p
      v-if="subtext"
      v-motion
      :initial="{ opacity: 0 }"
      :enter="{ opacity: 1, transition: { delay: 200, duration: 600 } }"
      class="text-xl text-slate-400"
    >
      {{ subtext }}
    </p>

    <div
      v-motion
      :initial="{ y: 20, opacity: 0 }"
      :enter="{ y: 0, opacity: 1, transition: { delay: 400, duration: 600 } }"
      class="flex flex-col items-center gap-3 text-slate-300"
    >
      <a v-if="email" :href="`mailto:${email}`" class="text-blue-400 hover:underline text-lg">
        {{ email }}
      </a>
      <a v-if="website" :href="website" target="_blank" class="text-slate-400 hover:text-slate-200">
        {{ website }}
      </a>
      <span v-if="deck" class="text-sm text-slate-500">Deck: {{ deck }}</span>
    </div>
  </div>
</template>
```

---

## 4. Integration Architecture

### 4.1 Complete Project Structure

**Confidence: High** — Based on official `sli.dev/custom/directory-structure` documentation.

```
deck/
├── slides.md                    # Main deck (frontmatter + slide content)
├── package.json                 # Dependencies
├── uno.config.ts                # UnoCSS shortcuts, theme, safelist
├── vite.config.ts               # Vite plugin extensions (optional)
│
├── styles/
│   ├── index.css                # Global styles — imports presets
│   └── presets/
│       ├── colors/              # Color palette presets
│       │   ├── dark-blue.css
│       │   ├── dark-purple.css
│       │   └── ...
│       ├── typography/          # Typography presets
│       │   ├── serif-heading.css
│       │   └── ...
│       └── textures/            # Background texture presets
│           ├── grid-overlay.css
│           └── ...
│
├── components/                  # Auto-imported Vue components
│   ├── MetricCard.vue
│   ├── TeamGrid.vue
│   ├── TimelineItem.vue
│   ├── ComparisonTable.vue
│   ├── QuoteBlock.vue
│   ├── LogoCloud.vue
│   ├── FeatureList.vue
│   ├── CTASlide.vue
│   ├── BarChart.vue
│   ├── AnimatedMetric.vue
│   ├── GlowPulse.vue
│   └── Typewriter.vue
│
├── layouts/                     # Custom slide layouts (optional)
│   ├── two-cols-asymmetric.vue  # 40/60 split
│   ├── section-divider.vue      # Full-bleed section break
│   └── centered-narrow.vue      # Max-width centered for statements
│
├── public/                      # Static assets (served at /)
│   ├── images/
│   │   ├── hero.jpg
│   │   ├── team/
│   │   └── logos/
│   └── fonts/                   # Self-hosted fonts (optional)
│
├── snippets/                    # Code snippets for magic-move
│   ├── before.py
│   └── after.py
│
├── setup/
│   └── main.ts                  # Vue app setup (register plugins)
│
├── global-bottom.vue            # Footer / progress bar (all slides)
└── global-top.vue               # Watermark / branding (all slides)
```

---

### 4.2 Component Auto-Import

Slidev uses `unplugin-vue-components` to auto-discover any `.vue` file in `components/`. No imports needed in slide Markdown:

```markdown
<!-- This just works — no import statement -->
<MetricCard value="$2M" label="ARR" />
```

Nested directories are also supported:
```
components/
  charts/
    BarChart.vue     → <ChartsBarChart /> or configure prefix
  pitch/
    MetricCard.vue   → <PitchMetricCard />
```

---

### 4.3 Custom Layouts

Layouts are Vue SFCs in `layouts/`. They receive slide content via `<slot />` and named slots:

```vue
<!-- layouts/two-cols-asymmetric.vue -->
<template>
  <div class="slidev-layout grid" style="grid-template-columns: 2fr 3fr; gap: 2rem; align-items: center;">
    <div class="left-col">
      <slot name="left" />
    </div>
    <div class="right-col">
      <slot />
    </div>
  </div>
</template>
```

Usage with "Slot Sugar" syntax:

```markdown
---
layout: two-cols-asymmetric
---

::left::

## The Problem

Legacy systems fail at scale.

::default::

![Architecture diagram](/images/arch.png)
```

---

### 4.4 Global Layer Files

**`global-bottom.vue`** — Persistent footer/progress bar:

```vue
<!-- global-bottom.vue -->
<script setup>
import { useNav } from '@slidev/client'
const nav = useNav()
</script>

<template>
  <!-- Hide on cover and blank layouts -->
  <footer
    v-if="!['cover', 'blank', 'center'].includes(nav.currentLayout)"
    class="absolute bottom-0 left-0 right-0 flex items-center justify-between px-8 py-3 text-xs text-slate-600"
  >
    <span>YourCo Confidential</span>
    <span>{{ nav.currentPage }} / {{ nav.total }}</span>
  </footer>
</template>
```

**`global-top.vue`** — Branding watermark:

```vue
<!-- global-top.vue -->
<script setup>
import { useNav } from '@slidev/client'
const nav = useNav()
</script>

<template>
  <div
    v-if="nav.currentLayout !== 'cover'"
    class="absolute top-4 right-6 flex items-center gap-2 opacity-30"
  >
    <img src="/images/logo-small.svg" class="h-5" />
  </div>
</template>
```

---

### 4.5 Vue App Setup (`setup/main.ts`)

```typescript
// setup/main.ts
import { defineAppSetup } from '@slidev/types'
import NumberFlow from '@number-flow/vue'

export default defineAppSetup(({ app }) => {
  // Register globally (alternative to auto-import)
  app.component('NumberFlow', NumberFlow)

  // Register Vue plugins
  // app.use(SomePlugin)
})
```

---

### 4.6 Global Styles Architecture (`styles/index.css`)

```css
/* styles/index.css */

/* 1. Color palette */
@import './presets/colors/dark-blue.css';

/* 2. Typography */
@import './presets/typography/serif-heading.css';

/* 3. Textures */
@import './presets/textures/grid-overlay.css';
@import './presets/textures/noise-grain.css';

/* 4. Scoped to .slidev-layout to prevent leakage into presenter UI */
.slidev-layout {
  /* Ensure content is above texture overlays */
  position: relative;
}

.slidev-layout > * {
  position: relative;
  z-index: 1;
}

/* 5. Click animation defaults */
.slidev-vclick-target {
  transition: all 0.45s cubic-bezier(0.16, 1, 0.3, 1);
}

.slidev-vclick-hidden {
  opacity: 0;
  transform: translateY(6px);
  pointer-events: none;
}

/* 6. Utility classes for pitch deck patterns */
.metric-highlight {
  background: linear-gradient(135deg, var(--color-accent-primary), var(--color-accent-secondary));
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}

.section-label {
  font-size: 0.7em;
  letter-spacing: 0.15em;
  text-transform: uppercase;
  color: var(--color-accent-primary);
  opacity: 0.8;
}
```

---

### 4.7 Complete Headmatter Template

```yaml
---
theme: seriph
title: "YourCo — Series A"
author: "Jane Doe"
info: "Confidential investor presentation"
colorSchema: dark
aspectRatio: "16/9"
canvasWidth: 980
fonts:
  sans: Inter
  serif: Playfair Display
  mono: JetBrains Mono
  provider: google
transition: fade
themeConfig:
  primary: '#60a5fa'
exportFilename: yourco-series-a
download: true
defaults:
  layout: default
  transition: fade
addons: []
---
```

---

## 5. Build and Export Pipeline

**Confidence: High** — Based on official `sli.dev/guide/exporting` and `sli.dev/builtin/cli`.

### 5.1 Development

```bash
slidev slides.md
# Opens at http://localhost:3030
# Hot-module replacement on save
# Presenter view at http://localhost:3030/presenter
# Export UI at http://localhost:3030/export (v0.50+)
```

### 5.2 Export to PDF

```bash
# Requires: npm add -D playwright-chromium
slidev export slides.md

# With click steps as separate pages
slidev export slides.md --with-clicks

# Dark mode, custom output, with PDF table of contents
slidev export slides.md --dark --output deck-dark.pdf --with-toc

# Specific slides only
slidev export slides.md --range "1,3-5,8"

# Higher resolution (default is 1x)
slidev export slides.md --scale 2

# Wait for animations to settle (ms)
slidev export slides.md --wait 500 --timeout 60000
```

### 5.3 Export to PPTX / PNG

```bash
# PPTX (slides become images — no interactivity)
slidev export slides.md --format pptx

# PNG (one image per slide)
slidev export slides.md --format png --output ./screenshots/

# Markdown (PNG images embedded in .md)
slidev export slides.md --format md
```

### 5.4 Build SPA

```bash
# Default: outputs to dist/
slidev build slides.md

# With embedded PDF download button
slidev build slides.md --download

# Custom output directory and base path (for sub-path hosting)
slidev build slides.md --out public/deck --base /deck/

# Strip speaker notes from public build
slidev build slides.md --without-notes

# Build multiple decks
slidev build *.md
```

### 5.5 `package.json` Scripts

```json
{
  "scripts": {
    "dev": "slidev slides.md --open",
    "build": "slidev build slides.md",
    "export": "slidev export slides.md",
    "export:clicks": "slidev export slides.md --with-clicks --output deck-steps.pdf",
    "export:pptx": "slidev export slides.md --format pptx",
    "screenshot": "slidev export slides.md --format png --output screenshots/"
  },
  "devDependencies": {
    "@slidev/cli": "^0.50.0",
    "@slidev/theme-seriph": "latest",
    "playwright-chromium": "^1.0.0"
  },
  "dependencies": {
    "@number-flow/vue": "^0.5.0"
  }
}
```

### 5.6 GitHub Actions CI/CD

```yaml
# .github/workflows/deploy.yml
name: Deploy Slidev Deck

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright
        run: npx playwright install chromium

      - name: Export PDF
        run: npm run export

      - name: Build SPA
        run: npm run build -- --base /deck/

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./dist
```

### 5.7 Performance Benchmarks (Estimated)

**Confidence: Low** — No official benchmarks found; these are estimates based on similar Vite/Vue SPA builds.

| Operation | Estimated Time | File Size |
|-----------|---------------|-----------|
| `slidev dev` cold start | 2-5s | N/A |
| `slidev build` (20 slides) | 15-30s | ~5-15 MB dist/ |
| `slidev export` PDF (20 slides) | 30-90s (Playwright) | ~3-8 MB PDF |
| `slidev export` --with-clicks | 60-180s | ~8-20 MB PDF |

PDF export time scales with complexity of animations and number of click steps. Use `--timeout 60000` for complex decks with many `v-motion` elements.

---

## 6. Addon System for Packaging Reusable Pieces

**Confidence: High**

For the agent system, pitch deck components should be packaged as a local addon (not published to npm). This allows sharing the component library across multiple decks.

### 6.1 Local Addon Structure

```
pitch-deck-addon/           # Can live at ../ relative to each deck project
├── package.json
├── components/
│   ├── MetricCard.vue
│   ├── TeamGrid.vue
│   └── ... (all components above)
├── layouts/
│   ├── two-cols-asymmetric.vue
│   └── section-divider.vue
└── styles/
    ├── index.css
    └── presets/
        └── ...
```

`package.json` for the addon:
```json
{
  "name": "slidev-addon-pitch-deck",
  "version": "1.0.0",
  "keywords": ["slidev-addon", "slidev"],
  "slidev": {
    "components": "./components",
    "layouts": "./layouts",
    "styles": "./styles/index.css"
  }
}
```

Reference in each deck's `slides.md`:
```yaml
---
addons:
  - ../pitch-deck-addon   # Relative path to local addon
---
```

### 6.2 What Addons Can and Cannot Do

| Can provide | Cannot do |
|-------------|-----------|
| Custom components | Override core Slidev config |
| New layouts | Override existing layout names from theme |
| Style CSS files | Apply wildcard global styles (use theme for that) |
| UnoCSS config extensions | Replace theme |
| Vite plugin config | Add conflicting presets |
| Code snippets | — |

---

## 7. Key Integration Decisions for Agent System

### 7.1 Recommended Stack

| Layer | Choice | Rationale |
|-------|--------|-----------|
| Theme | `seriph` | Best dark mode, serif typography, officially maintained |
| CSS engine | UnoCSS (built-in) | Tailwind-compatible, customizable shortcuts |
| Motion | `@vueuse/motion` (built-in) | No extra dep; spring physics, click-state binding |
| Number animation | `@number-flow/vue` | Clean dep, accessible, Intl formatting |
| Component packaging | Local addon | Reuse across decks without npm publishing |
| Export | `playwright-chromium` | Only PDF/PPTX/PNG dependency; CI-compatible |

### 7.2 Agent Template Generation Pattern

When the `/deck` command generates a new pitch deck, it should:

1. Copy the `pitch-deck-addon/` directory to the output location (or reference it via relative path)
2. Generate `slides.md` with:
   - Full headmatter (theme, fonts, transition, exportFilename)
   - `addons: ['../pitch-deck-addon']` reference
   - Per-section slide templates using `<MetricCard>`, `<TeamGrid>`, etc.
3. Generate `styles/index.css` importing the selected color preset + typography preset
4. Generate `uno.config.ts` with pitch deck shortcuts
5. Generate `package.json` with scripts for dev/build/export

### 7.3 Template Slide Catalog

| Slide Type | Layout | Key Components |
|------------|--------|----------------|
| Cover | `cover` + background image | `CTASlide`, gradient overlay |
| Problem | `default` or `two-cols` | `v-clicks` bullet list |
| Solution | `default` | `FeatureList`, `v-mark.circle` on key terms |
| Traction | `center` | `MetricCard` × 3, staggered `v-click` |
| Team | `default` | `TeamGrid` |
| Timeline | `default` | `TimelineItem` × N |
| Comparison | `default` | `ComparisonTable` |
| Testimonial | `center` | `QuoteBlock` |
| Partners | `center` | `LogoCloud` |
| Code Demo | `default` | Shiki Magic Move |
| Ask / CTA | `center` or `cover` | `CTASlide` |

---

## 8. Source References

- Slidev Animation Docs: https://sli.dev/guide/animations
- Slidev Components Guide: https://sli.dev/guide/component
- Slidev Directory Structure: https://sli.dev/custom/directory-structure
- Slidev UnoCSS Config: https://sli.dev/custom/config-unocss
- Slidev Addon Development: https://sli.dev/guide/write-addon
- Slidev Layout Writing: https://sli.dev/guide/write-layout
- Slidev Slide-Scoped Styles: https://sli.dev/features/slide-scope-style
- Slidev Global Layers: https://sli.dev/features/global-layers
- Slidev Exporting: https://sli.dev/guide/exporting
- Slidev Build/Hosting: https://sli.dev/guide/hosting
- Slidev CLI Reference: https://sli.dev/builtin/cli
- Slidev Build with PDF: https://sli.dev/features/build-with-pdf
- Slidev Built-in Components: https://sli.dev/builtin/components
- @vueuse/motion Variants: https://motion.vueuse.org/features/variants/
- @vueuse/motion useSpring: https://motion.vueuse.org/api/use-spring/
- NumberFlow Vue: https://number-flow.barvian.me/vue/
- Animation & Transitions DeepWiki: https://deepwiki.com/slidevjs/slidev/4.2-animation-and-transitions
- estruyf/slidev-addon-components: https://github.com/estruyf/slidev-addon-components
