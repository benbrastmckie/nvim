# Tailwind CSS v4 Reference

CSS-first configuration and utility class system for Tailwind CSS v4.

## CSS-First Configuration

Tailwind v4 uses CSS directives instead of a JavaScript config file:

```css
/* src/styles/global.css */
@import "tailwindcss";

@theme {
  --color-primary: oklch(0.72 0.11 178);
  --color-secondary: oklch(0.65 0.15 260);
  --color-accent: oklch(0.75 0.18 60);
  --color-surface: oklch(0.98 0.01 260);
  --color-surface-dark: oklch(0.15 0.02 260);

  --font-heading: "Inter", sans-serif;
  --font-body: "Source Sans 3", sans-serif;
  --font-mono: "JetBrains Mono", monospace;

  --radius-card: 0.75rem;
  --radius-button: 0.5rem;
}
```

This replaces `tailwind.config.js`. No JavaScript config file needed.

## @theme Directive

The `@theme` block defines design tokens as CSS custom properties. Tailwind generates utility classes from the namespace prefix.

### Namespace Reference

| Namespace | Generates Utilities | Example Token | Example Class |
|-----------|-------------------|---------------|---------------|
| `--color-*` | Color utilities | `--color-primary` | `bg-primary`, `text-primary` |
| `--font-*` | Font family | `--font-heading` | `font-heading` |
| `--text-*` | Font size + line height | `--text-xl` | `text-xl` |
| `--font-weight-*` | Font weight | `--font-weight-bold` | `font-bold` |
| `--tracking-*` | Letter spacing | `--tracking-wide` | `tracking-wide` |
| `--leading-*` | Line height | `--leading-relaxed` | `leading-relaxed` |
| `--spacing-*` | Spacing/sizing | `--spacing-4` | `p-4`, `m-4`, `gap-4`, `w-4` |
| `--breakpoint-*` | Responsive variants | `--breakpoint-md` | `md:*` |
| `--radius-*` | Border radius | `--radius-lg` | `rounded-lg` |
| `--shadow-*` | Box shadows | `--shadow-md` | `shadow-md` |
| `--animate-*` | Animations | `--animate-spin` | `animate-spin` |
| `--ease-*` | Timing functions | `--ease-out` | `ease-out` |
| `--container-*` | Container queries | `--container-sm` | `@sm:*` |

### Overriding Defaults

Clear default theme values and define your own:

```css
@theme {
  /* Remove all default colors */
  --color-*: initial;

  /* Define custom palette */
  --color-brand: #1a1a2e;
  --color-accent: #e94560;
  --color-muted: #6b7280;
  --color-background: #ffffff;
  --color-foreground: #111827;
}
```

### Extending Defaults

Add custom values alongside Tailwind defaults:

```css
@theme {
  /* Keeps all default colors, adds these */
  --color-brand: oklch(0.55 0.15 250);
  --color-brand-light: oklch(0.75 0.12 250);
  --color-brand-dark: oklch(0.35 0.18 250);
}
```

## Using Theme Variables in CSS

Theme tokens are standard CSS custom properties:

```css
@import "tailwindcss";

@theme {
  --color-primary: oklch(0.72 0.11 178);
}

/* Use in custom CSS */
.custom-element {
  background-color: var(--color-primary);
  border: 1px solid color-mix(in oklch, var(--color-primary) 50%, transparent);
}
```

## Dark Mode

Tailwind v4 uses the `dark:` variant, driven by the `prefers-color-scheme` media query by default:

```html
<div class="bg-white dark:bg-gray-900">
  <h1 class="text-gray-900 dark:text-gray-100">Title</h1>
  <p class="text-gray-600 dark:text-gray-400">Description</p>
</div>
```

### Manual Dark Mode Toggle

To use class-based dark mode (toggle via JavaScript):

```css
@import "tailwindcss";
@variant dark (&:where(.dark, .dark *));
```

Then toggle the `dark` class on `<html>`:

```html
<html class="dark">
  <body class="bg-white dark:bg-gray-900">
    <!-- Dark mode active -->
  </body>
</html>
```

## Responsive Design

### Default Breakpoints

| Breakpoint | Width | Class Prefix |
|------------|-------|-------------|
| sm | 40rem (640px) | `sm:` |
| md | 48rem (768px) | `md:` |
| lg | 64rem (1024px) | `lg:` |
| xl | 80rem (1280px) | `xl:` |
| 2xl | 96rem (1536px) | `2xl:` |

Mobile-first: utilities apply at the breakpoint and above.

```html
<!-- Full width on mobile, 2 columns on md, 3 on lg -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
  <div>Item</div>
</div>
```

### Custom Breakpoints

```css
@theme {
  --breakpoint-xs: 30rem;
  --breakpoint-3xl: 112rem;
}
```

## Key v4 Changes from v3

| v3 Pattern | v4 Pattern |
|-----------|-----------|
| `tailwind.config.js` | `@theme { }` in CSS |
| `@tailwind base;` `@tailwind components;` `@tailwind utilities;` | `@import "tailwindcss";` |
| `theme.extend.colors` | `--color-*` in `@theme` |
| `content: ['./src/**/*.{astro,tsx}']` | Automatic content detection |
| `@apply` (still works) | Direct utility classes preferred |
| PostCSS + JS config | Lightning CSS + Rust engine |

### Performance Improvements
- 5x faster full builds (Lightning CSS + Rust)
- 100x faster incremental rebuilds
- 35% smaller install footprint
- Automatic content detection (no glob config)

## Container Queries

```html
<div class="@container">
  <div class="@sm:flex @md:grid @md:grid-cols-2">
    <!-- Responds to container width, not viewport -->
  </div>
</div>
```

## Astro Integration

Install as a Vite plugin (not an Astro integration):

```bash
pnpm add tailwindcss @tailwindcss/vite
```

```typescript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  vite: {
    plugins: [tailwindcss()],
  },
});
```

Import the CSS file in your base layout:

```astro
---
// src/layouts/BaseLayout.astro
---

<html>
  <head>
    <link rel="stylesheet" href="/src/styles/global.css" />
  </head>
  <body>
    <slot />
  </body>
</html>
```
