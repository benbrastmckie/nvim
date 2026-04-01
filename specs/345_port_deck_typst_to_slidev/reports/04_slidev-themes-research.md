# Slidev Themes Research: Dark, Minimal, AI Startup Aesthetic

**Task**: 345 - Port /deck command-skill-agent from Typst to Slidev
**Date**: 2026-04-01
**Focus**: Themes with dark minimal aesthetic, rich backdrop images, elegant transitions/animations

---

## Executive Summary

Slidev's theme ecosystem includes 5 official themes and 30+ community themes. For an AI startup pitch deck requiring a dark minimal aesthetic with rich backdrop imagery and elegant animations, the best approach is **theme: seriph** (or **theme: dracula**) combined with custom scoped CSS for background textures, gradients, and overlays. Slidev's animation system -- v-click, v-motion, v-mark, view-transition, and Shiki Magic Move -- provides a comprehensive toolkit for elegant, click-driven reveals that far exceed what Typst/Touying offered.

---

## 1. Official Themes

| Theme | Style | Dark Mode | Best For |
|-------|-------|-----------|----------|
| **default** | Clean, minimal, system fonts | Yes (`colorSchema: dark`) | Generic presentations |
| **seriph** | Elegant serif typography (Playfair Display) | Yes | Pitch decks, storytelling, AI demos |
| **apple-basic** | Apple Keynote-inspired, B&W | Light only | Product launches, Apple-style |
| **shibainu** | Playful, Shiba Inu mascot | Yes | Developer talks, fun presentations |
| **bricks** | Structured, modular | Yes | Technical architecture talks |

### Recommendation: **seriph** as the base

`seriph` is the strongest fit for AI startup decks because:
- Native dark mode with rich color customization via `themeConfig.primary`
- Serif headings (Playfair Display) provide gravitas and premium feel
- Clean body text (Inter or custom sans) for readability
- Supports all 20 built-in layouts including `cover`, `fact`, `statement`
- Full `background` frontmatter support for per-slide images
- Created by Anthony Fu (Slidev creator), so it's the most maintained

---

## 2. Community Themes Worth Considering

### Dark/Minimal Themes

| Theme | Package | Style | Notes |
|-------|---------|-------|-------|
| **dracula** | `slidev-theme-dracula` | Dracula color palette (purple/green/pink on dark) | Iconic dark theme, developer-friendly, great for AI/tech |
| **geist** | `slidev-theme-geist` | Vercel/Next.js inspired, ultra-minimal | Very clean, modern tech aesthetic, dark mode |
| **purplin** | `slidev-theme-purplin` | Purple gradient backgrounds | Rich visual gradients, demo at slidev-theme-purplin.netlify.app |
| **neversink** | `slidev-theme-neversink` | Academic/conference, highly customizable | 20+ custom layouts, color schemes, good structure |
| **light-icons** | `slidev-theme-light-icons` | Elegant with embedded icon set | Light-weighted icons collection, clean design |

### Other Notable Themes

| Theme | Style |
|-------|-------|
| **vuetiful** | Vue-branded, multi-column layouts |
| **academic** | Research/paper presentations |
| **penguin** | Clean developer theme |
| **unicorn** | Vibrant, colorful |
| **mokkapps** | Personal brand template |
| **eloc** | Minimalist with custom layouts |
| **zhozhoba** | Modern dark with gradients |
| **aliyun** | Alibaba Cloud branding |

---

## 3. Background Images and Textures

Slidev supports rich backdrop imagery through multiple mechanisms:

### 3.1 Per-Slide Background Images

```yaml
---
layout: cover
background: /images/ai-neural-dark.jpg
class: text-white
---

# Your AI Company

Building the future of intelligence
```

The `background` frontmatter property accepts:
- Local images from `public/` directory: `background: /images/hero.jpg`
- Remote URLs: `background: https://source.unsplash.com/...`
- CSS values: `background: linear-gradient(135deg, #0f0f23 0%, #1a1a3e 100%)`

### 3.2 Image-Specific Layouts

| Layout | Description |
|--------|-------------|
| `image` | Full-screen background image, `backgroundSize: cover` |
| `image-left` | Image fills left half, content on right |
| `image-right` | Image fills right half, content on left |

```yaml
---
layout: image-right
image: /images/ai-visualization.jpg
class: text-white
---

# The Problem

Current solutions fail at scale...
```

### 3.3 Dark Gradient + Texture Overlays (Custom CSS)

For the richest visual texture against a dark background, use scoped CSS with gradient overlays:

```yaml
---
layout: default
class: dark-textured
---

# Traction

<style>
.dark-textured {
  background:
    linear-gradient(135deg, rgba(15, 15, 35, 0.95), rgba(26, 26, 62, 0.9)),
    url('/images/grid-pattern.svg');
  background-size: cover;
}
</style>
```

### 3.4 Global Background Texture (styles/index.css)

For a consistent dark textured backdrop across all slides:

```css
/* styles/index.css */
.slidev-layout {
  background:
    radial-gradient(ellipse at 20% 50%, rgba(59, 130, 246, 0.08) 0%, transparent 50%),
    radial-gradient(ellipse at 80% 20%, rgba(139, 92, 246, 0.06) 0%, transparent 50%),
    linear-gradient(180deg, #0a0a1a 0%, #0f0f2e 50%, #0a0a1a 100%);
}

/* Subtle grid texture overlay */
.slidev-layout::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(255,255,255,0.02) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,0.02) 1px, transparent 1px);
  background-size: 50px 50px;
  pointer-events: none;
}
```

### 3.5 Noise/Grain Texture

```css
/* Subtle film grain effect */
.slidev-layout::after {
  content: '';
  position: absolute;
  inset: 0;
  opacity: 0.03;
  background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 256 256' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noise'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='4' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noise)'/%3E%3C/svg%3E");
  pointer-events: none;
}
```

---

## 4. Transitions and Animations

### 4.1 Slide Transitions

Set globally in headmatter or per-slide in frontmatter:

```yaml
# Global (headmatter)
---
transition: fade
---

# Per-slide
---
transition: slide-left
---
```

**Built-in transitions**:

| Transition | Effect | Best For |
|-----------|--------|----------|
| `fade` | Crossfade | Elegant, subtle (recommended for pitch decks) |
| `fade-out` | Fade out then fade in | Dramatic reveals |
| `slide-left` | Slide from right to left | Sequential flow, forward progress |
| `slide-right` | Slide from left to right | Backwards/comparison |
| `slide-up` | Slide from bottom to top | Building momentum |
| `slide-down` | Slide from top to bottom | De-escalation |
| `view-transition` | CSS View Transitions API | Smooth morphing between slides (experimental) |

**Bidirectional transitions** (different for forward/backward):
```yaml
transition: slide-left | slide-right
```

**Custom CSS transitions**:
```css
/* Elegant zoom-fade for AI demo slides */
.my-zoom-fade-enter-active,
.my-zoom-fade-leave-active {
  transition: all 0.6s cubic-bezier(0.16, 1, 0.3, 1);
}
.my-zoom-fade-enter-from {
  opacity: 0;
  transform: scale(0.96);
}
.my-zoom-fade-leave-to {
  opacity: 0;
  transform: scale(1.04);
}
```

### 4.2 Click Animations (v-click)

Progressive reveal system tied to presenter clicks:

```html
<!-- Basic: appear on click -->
<div v-click>Appears on next click</div>

<!-- Hide on click (reverse) -->
<div v-click.hide>Disappears on click</div>

<!-- Numbered ordering -->
<div v-click="1">First</div>
<div v-click="3">Third</div>
<div v-click="2">Second</div>

<!-- Animate all children sequentially -->
<v-clicks>

- Point one
- Point two
- Point three

</v-clicks>

<!-- Range: visible between clicks 2 and 5 -->
<div v-click="[2, 5]">Temporary</div>
```

**v-after** -- appears simultaneously with previous v-click:
```html
<div v-click>I appear first</div>
<div v-after>I appear at the same time</div>
```

**v-switch** -- multi-slot conditional display:
```html
<v-switch>
  <template #1>Show on click 1</template>
  <template #2>Show on click 2</template>
  <template #3>Show on click 3</template>
</v-switch>
```

### 4.3 Motion Animations (v-motion)

Powered by @vueuse/motion -- full CSS transform animations:

```html
<div
  v-motion
  :initial="{ x: -80, opacity: 0 }"
  :enter="{ x: 0, opacity: 1, transition: { delay: 200 } }"
  :leave="{ x: 80, opacity: 0 }"
>
  Slides in from left, exits right
</div>

<!-- Click-triggered motion stages -->
<div
  v-motion
  :initial="{ y: 100, opacity: 0 }"
  :enter="{ y: 0, opacity: 1 }"
  :click-1="{ scale: 1.2, color: '#60a5fa' }"
  :click-2="{ x: 200 }"
>
  Enters, then scales on click 1, moves right on click 2
</div>
```

**Motion properties**: `x`, `y`, `scale`, `rotate`, `opacity`, `color`, plus full CSS transform support with spring/easing options.

### 4.4 Rough Notation Marks (v-mark)

Hand-drawn annotation effects for emphasis:

```html
<!-- Underline (default) -->
<span v-mark>important text</span>

<!-- Circle -->
<span v-mark.circle>$2M ARR</span>

<!-- Highlight (marker effect) -->
<span v-mark.highlight="{ color: 'rgba(96, 165, 250, 0.3)' }">key metric</span>

<!-- Box -->
<span v-mark.box>critical insight</span>

<!-- Strike-through -->
<span v-mark.strike-through>old approach</span>

<!-- Click-triggered -->
<span v-mark="3">appears on click 3</span>
```

Mark types: `underline`, `circle`, `highlight`, `strike-through`, `box`, `bracket`, `crossed-off`.

### 4.5 Shiki Magic Move (Code Animations)

Smooth morphing between code blocks:

````markdown
````md magic-move
```python
# Before
model = GPT4()
response = model.generate(prompt)
```

```python
# After: Our approach
model = OurModel(context_window="1M")
response = model.generate(prompt, stream=True)
pipeline = model.chain(response, refinement_step)
```
````
````

The code block smoothly morphs between states on click, with syntax highlighting preserved.

### 4.6 View Transitions (Experimental)

CSS View Transitions API for smooth cross-slide element morphing:

```yaml
---
transition: view-transition
---
```

```html
<!-- Same view-transition-name on elements across slides creates morph effect -->
<h1 style="view-transition-name: title">Company Name</h1>
```

---

## 5. Recommended Configuration for AI Startup Pitch Deck

### 5.1 Complete Headmatter Template

```yaml
---
theme: seriph
title: "Your AI Company"
author: "Founder Name"
info: "Series A Pitch Deck"
colorSchema: dark
aspectRatio: "16/9"
canvasWidth: 980
fonts:
  sans: Inter
  serif: Playfair Display
  mono: JetBrains Mono
transition: fade
themeConfig:
  primary: '#60a5fa'
exportFilename: ai-company-deck
download: true
defaults:
  layout: default
---
```

### 5.2 Global Dark Textured Styling (styles/index.css)

```css
/* Deep space background with subtle color accents */
:root {
  --slidev-slide-container-background: #0a0a1a;
}

.slidev-layout {
  background:
    radial-gradient(ellipse at 15% 80%, rgba(59, 130, 246, 0.07) 0%, transparent 50%),
    radial-gradient(ellipse at 85% 20%, rgba(139, 92, 246, 0.05) 0%, transparent 50%),
    radial-gradient(ellipse at 50% 50%, rgba(20, 20, 50, 1) 0%, rgba(10, 10, 26, 1) 100%);
  color: #e2e8f0;
}

/* Subtle grid texture */
.slidev-layout::before {
  content: '';
  position: absolute;
  inset: 0;
  background-image:
    linear-gradient(rgba(255,255,255,0.015) 1px, transparent 1px),
    linear-gradient(90deg, rgba(255,255,255,0.015) 1px, transparent 1px);
  background-size: 60px 60px;
  pointer-events: none;
  z-index: 0;
}

/* Typography hierarchy */
h1 {
  font-family: 'Playfair Display', serif;
  font-size: 3em;
  font-weight: 700;
  color: #f1f5f9;
  letter-spacing: -0.02em;
}

h2 {
  font-family: 'Playfair Display', serif;
  font-size: 2.2em;
  font-weight: 600;
  color: #e2e8f0;
}

p, li {
  font-size: 1.4em;
  color: #94a3b8;
  line-height: 1.6;
}

/* Accent color for highlights */
.text-accent {
  color: #60a5fa;
}

/* Smooth click animation override */
.slidev-vclick-target {
  transition: all 0.4s cubic-bezier(0.16, 1, 0.3, 1);
}
```

### 5.3 Example Cover Slide with Backdrop

```yaml
---
layout: cover
background: /images/neural-network-dark.jpg
class: text-white
---

<div class="absolute inset-0 bg-gradient-to-br from-black/80 via-blue-950/60 to-black/80" />

<div class="relative z-10">

# Your AI Company

<p class="text-xl opacity-80 mt-4">
Redefining intelligence at scale
</p>

<div class="abs-br m-8 text-sm opacity-60">
Series A | April 2026
</div>

</div>
```

### 5.4 Example Traction Slide with Animations

```yaml
---
layout: center
transition: fade
---

# Traction

<div class="grid grid-cols-3 gap-12 mt-12">
  <div v-click class="text-center">
    <div v-motion :initial="{ y: 20, opacity: 0 }" :enter="{ y: 0, opacity: 1 }">
      <span class="text-5xl font-bold text-blue-400" v-mark.circle>$2M</span>
      <p class="text-lg opacity-60 mt-2">Annual Revenue</p>
    </div>
  </div>
  <div v-click class="text-center">
    <div v-motion :initial="{ y: 20, opacity: 0 }" :enter="{ y: 0, opacity: 1, transition: { delay: 100 } }">
      <span class="text-5xl font-bold text-blue-400" v-mark.circle>340%</span>
      <p class="text-lg opacity-60 mt-2">YoY Growth</p>
    </div>
  </div>
  <div v-click class="text-center">
    <div v-motion :initial="{ y: 20, opacity: 0 }" :enter="{ y: 0, opacity: 1, transition: { delay: 200 } }">
      <span class="text-5xl font-bold text-blue-400" v-mark.circle>50K+</span>
      <p class="text-lg opacity-60 mt-2">API Calls / Day</p>
    </div>
  </div>
</div>

<style>
.slidev-layout {
  background:
    radial-gradient(ellipse at 50% 0%, rgba(59, 130, 246, 0.1) 0%, transparent 60%),
    #0a0a1a;
}
</style>
```

---

## 6. Theme Comparison Matrix (Dark Aesthetic)

| Criterion | seriph (dark) | dracula | geist | purplin | Custom CSS only |
|-----------|:---:|:---:|:---:|:---:|:---:|
| Dark mode native | Yes | Yes | Yes | Yes | Yes |
| Background images | Yes | Yes | Limited | Gradient | Yes |
| Serif headings | Yes | No | No | No | Manual |
| themeConfig colors | Yes | Limited | Yes | Limited | N/A |
| Premium/elegant feel | High | Medium | High | Medium | Depends |
| Maintenance/updates | Official | Community | Community | Community | Self |
| Layout variety | 20 built-in | 20 built-in | 20 built-in | 20 built-in + custom | 20 built-in |
| Animation support | Full | Full | Full | Full | Full |
| AI/tech aesthetic | Strong | Strong | Very Strong | Medium | Flexible |

---

## 7. Verdict and Recommendations

### Primary: `theme: seriph` + Custom Dark CSS

**Why**: Seriph provides the elegant serif typography that conveys authority and premium quality for investor presentations. Combined with custom dark CSS (section 5.2-5.3), you get:
- Rich textured dark backgrounds with subtle grid/noise overlays
- Full backdrop image support per slide via `background:` frontmatter
- All 20 layouts including `cover`, `fact`, `statement`, `two-cols`
- Complete animation system (v-click, v-motion, v-mark)
- Elegant `fade` or custom zoom-fade transitions
- Google Fonts integration (Inter, Playfair Display, JetBrains Mono)

### Alternative: `theme: geist` for Ultra-Modern Tech

If you prefer a more Vercel/Next.js-inspired clean tech look over serif elegance, `geist` provides an ultra-minimal dark aesthetic aligned with modern AI/developer tooling.

### Alternative: `theme: dracula` for Developer-Facing Decks

If the audience is technical (developer tools, API products), Dracula's iconic purple-on-dark palette is instantly recognizable and signals "built for developers."

### Background Image Strategy

For rich backdrop textures:
1. **Cover/closing slides**: Full-bleed images via `background:` frontmatter with gradient overlays
2. **Content slides**: Subtle CSS gradients + grid texture via global `styles/index.css`
3. **Section dividers**: `layout: section` with per-slide background images
4. **Data slides**: Clean dark gradient (no image) to maximize readability

### Animation Strategy for Pitch Decks

Keep animations purposeful -- they should guide attention, not distract:
1. **Slide transitions**: `fade` globally, `slide-left` for sequential sections
2. **Content reveals**: `v-clicks` for bullet lists (one point at a time)
3. **Metrics/KPIs**: `v-motion` with staggered delays for dramatic reveal
4. **Key terms**: `v-mark.circle` or `v-mark.highlight` for emphasis
5. **Code demos**: Shiki Magic Move for before/after comparisons
6. **Avoid**: Over-animating every element, complex Vue components, heavy v-motion chains

---

## 8. Source References

- Slidev Theme Gallery: https://sli.dev/resources/theme-gallery
- Slidev Animations: https://sli.dev/guide/animations
- Slidev Syntax: https://sli.dev/guide/syntax
- Slidev Layouts: https://sli.dev/builtin/layouts
- Slidev Font Config: https://sli.dev/custom/config-fonts
- Slidev Theme Addon: https://sli.dev/guide/theme-addon
- Official Themes Repo: https://github.com/slidevjs/themes
- Slidev Dracula: https://github.com/jd-solanki/slidev-theme-dracula
- Slidev Geist: https://www.npmjs.com/package/slidev-theme-geist
- Slidev Purplin: https://slidev-theme-purplin.netlify.app
- Slidev Neversink: https://gureckis.github.io/slidev-theme-neversink
- Shiki Magic Move: https://github.com/shikijs/shiki-magic-move
- v-mark / Rough Notation: https://sli.dev/guide/animations (v0.48+)
- @vueuse/motion: https://motion.vueuse.org
- NPM Theme Search: https://www.npmjs.com/search?q=keywords:slidev-theme
