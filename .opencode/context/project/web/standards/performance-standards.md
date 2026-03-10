# Performance Standards

Performance targets and optimization requirements for the website.

## Core Web Vitals Targets

### Official Google Thresholds (2026)

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| LCP (Largest Contentful Paint) | < 2.5s | 2.5 - 4.0s | > 4.0s |
| INP (Interaction to Next Paint) | < 200ms | 200 - 500ms | > 500ms |
| CLS (Cumulative Layout Shift) | < 0.1 | 0.1 - 0.25 | > 0.25 |

### Aspirational Targets (website)

| Metric | Target | Rationale |
|--------|--------|-----------|
| LCP | < 2.0s | Astro zero-JS default makes sub-2s achievable |
| INP | < 100ms | Minimal client JS means near-instant interactions |
| CLS | < 0.08 | Static layout with explicit image dimensions |

### Metric Definitions

- **LCP**: Time until the largest visible content element renders. Affected by hero images, fonts, and server response time.
- **INP**: Worst-case latency between user interaction and visual response. Affected by JavaScript execution and DOM updates.
- **CLS**: Sum of unexpected layout shifts during page lifetime. Affected by images without dimensions, dynamic content injection, and late-loading fonts.

## Lighthouse Targets

| Category | Minimum | Target |
|----------|---------|--------|
| Performance | 95 | 98+ |
| Accessibility | 95 | 100 |
| Best Practices | 95 | 100 |
| SEO | 95 | 100 |

## Astro Performance Defaults

Astro provides strong performance out of the box:

- **Zero JavaScript by default**: No JS framework runtime shipped to client
- **Static HTML output**: Pre-rendered pages served from CDN edge
- **Built-in image optimization**: Automatic WebP/AVIF conversion via `<Image>`
- **Automatic dimension attributes**: Prevents CLS from images
- **CSS inlining**: Critical CSS embedded in `<head>`
- **Scope isolation**: Component CSS is scoped, no unused styles shipped

## Image Optimization

### Format Requirements

| Use Case | Format | Fallback |
|----------|--------|----------|
| Photographs | AVIF | WebP |
| Graphics/icons | SVG | PNG |
| Animated content | WebP animated | GIF |

### Size Budgets

| Image Type | Max File Size | Max Dimensions |
|------------|---------------|----------------|
| Hero/banner | 200 KB | 1920 x 1080 |
| Card thumbnail | 50 KB | 800 x 600 |
| Avatar/icon | 20 KB | 400 x 400 |
| Logo | 10 KB | SVG preferred |

### Implementation

Always use Astro's built-in `<Image>` component:

```astro
---
import { Image } from 'astro:assets';
import hero from '../assets/hero.jpg';
---
<!-- Astro auto-converts to WebP/AVIF, sets width/height attributes -->
<Image
  src={hero}
  alt="Description of image"
  width={1200}
  height={630}
  loading="eager"
  format="avif"
/>
```

For below-the-fold images, use lazy loading:

```astro
<Image
  src={thumbnail}
  alt="Description"
  width={400}
  height={300}
  loading="lazy"
  decoding="async"
/>
```

## Font Loading

### Strategy: Preload + font-display: swap

```html
<!-- In BaseLayout head -->
<link rel="preload" href="/fonts/inter-var.woff2" as="font" type="font/woff2" crossorigin />
```

```css
@font-face {
  font-family: "Inter";
  src: url("/fonts/inter-var.woff2") format("woff2");
  font-weight: 100 900;
  font-display: swap;
}
```

### Font Budget

- Maximum 2 font families (heading + body)
- Use variable fonts to reduce file count
- Total font payload: < 100 KB
- Subset fonts to Latin characters if full Unicode not needed

## CSS Optimization

### Critical CSS

Astro automatically inlines critical CSS. No manual configuration needed for:
- Component-scoped styles (via `<style>` tags in `.astro` files)
- Tailwind utilities used in the page

### Non-Critical CSS

For large custom CSS files, defer loading:

```astro
<link rel="preload" href="/styles/animations.css" as="style" onload="this.rel='stylesheet'" />
<noscript><link rel="stylesheet" href="/styles/animations.css" /></noscript>
```

### Tailwind v4 Optimizations

Tailwind v4 provides automatic optimization:
- Unused utilities are tree-shaken at build time
- Lightning CSS handles minification and vendor prefixing
- No PurgeCSS configuration needed

## JavaScript Budget

### Content Pages (blog posts, about, etc.)

- **Target**: 0 KB client JavaScript
- Astro ships zero JS by default for static pages
- Avoid `client:*` directives on content pages

### Interactive Pages (contact form, demos)

- **Target**: < 20 KB compressed JavaScript
- Use `client:visible` for below-fold interactivity
- Use `client:idle` for non-critical interactivity
- Prefer native HTML elements over JS widgets (e.g., `<details>` over accordion)

### Directive Selection

| Directive | When to Use | JS Impact |
|-----------|-------------|-----------|
| (none) | Static content | 0 KB |
| `client:visible` | Below-fold interactive | Deferred |
| `client:idle` | Non-critical interactive | Deferred |
| `client:load` | Critical interactive (forms) | Immediate |
| `client:only` | Client-only rendering | Full framework |

## Server Response Time

### Targets

| Metric | Target |
|--------|--------|
| TTFB (Time to First Byte) | < 200ms |
| Server response (static) | < 50ms |
| CDN cache hit ratio | > 95% |

### Cloudflare Pages Defaults

- Global CDN with edge caching
- Automatic cache invalidation on deploy
- Brotli compression enabled by default
- HTTP/3 support

## Build Performance

### Build Time Targets

| Project Size | Max Build Time |
|--------------|----------------|
| < 50 pages | < 30s |
| 50-200 pages | < 60s |
| 200+ pages | < 120s |

### Monitoring

Run Lighthouse in CI on every deployment:

```bash
# In CI pipeline
pnpm build
pnpm exec lighthouse http://localhost:4321 --output=json --output-path=./lighthouse.json
```
