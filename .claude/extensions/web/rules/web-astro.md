# Astro Web Development Rules

## Path Pattern

Applies to: `src/**/*.astro`, `src/**/*.ts`, `src/**/*.tsx`

## Coding Standards

### Indentation
- Use 2 spaces for indentation
- Never use tabs
- Maximum line length: 100 characters

### Naming Conventions

| Category | Convention | Example |
|----------|-----------|---------|
| Pages | `kebab-case.astro` | `about-us.astro` |
| Components | `PascalCase.astro` | `HeroSection.astro` |
| Layouts | `PascalCase.astro` | `BaseLayout.astro` |
| TypeScript files | `kebab-case.ts` | `site-config.ts` |
| Directories | `kebab-case/` | `blog-posts/` |
| Variables/functions | `camelCase` | `getUserData()` |
| Interfaces/Types | `PascalCase` | `interface Props` |
| Constants | `SCREAMING_SNAKE_CASE` | `SITE_TITLE` |

### Component Structure

Every `.astro` file has three sections:

```astro
---
// 1. FRONTMATTER (Component Script)
import Layout from '../layouts/Layout.astro';

interface Props {
  title: string;
  description?: string;
}

const { title, description = 'Default' } = Astro.props;
---

<!-- 2. HTML TEMPLATE -->
<Layout title={title}>
  <main>
    <h1>{title}</h1>
    <p>{description}</p>
  </main>
</Layout>

<!-- 3. SCOPED STYLES -->
<style>
  h1 {
    font-size: 2rem;
  }
</style>
```

## Astro Component Patterns

### Props

Always define `interface Props` and destructure from `Astro.props`:
```astro
---
interface Props {
  title: string;
  items: string[];
  class?: string;
}

const { title, items, class: className } = Astro.props;
---

<section class={className}>
  <h2>{title}</h2>
  <ul>
    {items.map((item) => <li>{item}</li>)}
  </ul>
</section>
```

### Client Directives (Islands)

| Directive | When to Use | Example |
|-----------|------------|---------|
| `client:load` | Must work immediately (nav menus) | `<SearchBar client:load />` |
| `client:idle` | Nice-to-have interactivity | `<Carousel client:idle />` |
| `client:visible` | Below fold, deferred | `<Newsletter client:visible />` |
| `client:media` | Screen-size dependent | `<Sidebar client:media="(min-width: 768px)" />` |
| `client:only` | No SSR, client-render only (rare) | `<Canvas client:only="react" />` |

### Scoped Styles

- `<style>` is scoped by default (compiled to unique class selectors)
- Use `<style is:global>` sparingly and only with justification
- Pass JS values to CSS with `define:vars`:
```astro
---
const color = '#4a90d9';
---
<style define:vars={{ color }}>
  h1 { color: var(--color); }
</style>
```

## TypeScript Standards

| Rule | Description |
|------|-------------|
| No `any` | Use `unknown` + type guards instead |
| Explicit return types | Functions must declare return types |
| `interface` over `type` | Prefer `interface` for object shapes (extendable) |
| `interface Props` | Always define in `.astro` frontmatter for components that accept props |
| Type-only imports | Use `import type { X }` for type-only imports |
| Nullish coalescing | Use `??` over logical OR for defaults |
| Optional chaining | Use `?.` for nullable access |
| Astro utility types | Use types from `astro/types` (e.g., `HTMLAttributes`) |

## Tailwind CSS Conventions

### Class Ordering

Follow box-model order (enforced by `prettier-plugin-tailwindcss`):

1. **Layout**: `block`, `flex`, `grid`, `relative`, `absolute`, `z-*`
2. **Sizing**: `w-*`, `h-*`, `min-w-*`, `max-w-*`
3. **Spacing**: `p-*`, `m-*`, `gap-*`, `space-*`
4. **Typography**: `text-*`, `font-*`, `leading-*`, `tracking-*`
5. **Visual**: `bg-*`, `border-*`, `rounded-*`, `shadow-*`, `opacity-*`
6. **Interactive**: `cursor-*`, `transition-*`, `hover:*`, `focus:*`
7. **Responsive**: `sm:*`, `md:*`, `lg:*`, `xl:*`
8. **Dark mode**: `dark:*`

### Tailwind CSS v4 Specifics

- CSS-first configuration: `@import "tailwindcss"` (no JS config file)
- Theme customization via `@theme` directive in CSS
- Automatic content detection (no `content` array needed)
- Enforce ordering with `prettier-plugin-tailwindcss`

## Accessibility Requirements

| Requirement | Implementation |
|-------------|---------------|
| Alt text | All `<Image>` must have descriptive `alt`; decorative images: `alt=""` |
| Semantic HTML | Use `<header>`, `<main>`, `<nav>`, `<footer>`, `<section>`, `<article>` |
| Heading hierarchy | Sequential `h1`-`h6`, one `h1` per page, no skipped levels |
| ARIA labels | `aria-label` / `aria-labelledby` for non-obvious interactive elements |
| Keyboard navigation | All interactive elements reachable via Tab, operable via Enter/Space |
| Color contrast | Text: 4.5:1 minimum; large text (18px+ bold, 24px+): 3:1 minimum |
| Focus visibility | Visible focus indicator on all interactive elements (WCAG 2.2 2.4.11) |
| Touch targets | Minimum 24x24 CSS pixels for interactive elements (WCAG 2.2 2.5.8) |
| Skip navigation | "Skip to main content" link as first focusable element |
| Reduced motion | Respect `prefers-reduced-motion` media query for all animations |
| Language attribute | `<html lang="en">` on root element |

## Performance Constraints

### Zero JS by Default
Content pages must ship zero client-side JavaScript. Only add `client:*` directives for truly interactive components.

### Image Optimization
- Always use `<Image>` from `astro:assets` (never raw `<img>`)
- Set explicit `width` and `height` to prevent CLS
- Use `loading="eager"` only for above-the-fold hero images
- All other images use default lazy loading

### Core Web Vitals Targets (2026)

| Metric | Target |
|--------|--------|
| LCP (Largest Contentful Paint) | < 2.0s |
| INP (Interaction to Next Paint) | < 150ms |
| CLS (Cumulative Layout Shift) | < 0.08 |

### Additional Performance Rules
- Preload critical assets with `<link rel="preload">`
- Use `font-display: swap` for web fonts
- Prefer CSS animations over JavaScript animations
- Minimize third-party scripts

## Build Commands

```bash
# Development server
pnpm dev

# Production build
pnpm build

# TypeScript + Astro diagnostics
pnpm check

# Preview production build locally
pnpm preview
```

## Do Not

- Use `any` type (use `unknown` + type guards)
- Use raw `<img>` tags (use `<Image>` from `astro:assets`)
- Add `client:*` directives to static content components
- Skip `alt` attributes on images
- Use `<style is:global>` without clear justification
- Skip heading levels (e.g., `h1` directly to `h3`)
- Use inline styles instead of Tailwind classes or scoped styles
- Omit `interface Props` in components that accept props
- Use `||` for defaults where `??` is appropriate
- Forget explicit `width`/`height` on images (causes CLS)
- Import client-side frameworks without a `client:*` directive
- Nest interactive elements (e.g., `<a>` inside `<button>`)

## Related Context

Load for detailed patterns:
- `@.claude/extensions/web/context/project/web/domain/astro-framework.md`
- `@.claude/extensions/web/context/project/web/domain/tailwind-v4.md`
- `@.claude/extensions/web/context/project/web/patterns/astro-component.md`
- `@.claude/extensions/web/context/project/web/patterns/accessibility-patterns.md`
- `@.claude/extensions/web/context/project/web/standards/performance-standards.md`
