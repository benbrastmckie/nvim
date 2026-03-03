# Astro Framework Guide

**Scope**: Astro 5.x development patterns for static sites

## Core Concepts

**Islands Architecture**: Ship zero JavaScript by default. Hydrate selectively.

**Content Collections**: Type-safe Markdown/MDX with Zod schemas.

**File-Based Routing**: Pages in `src/pages/` become routes automatically.

## Component Structure

```astro
---
// Frontmatter: TypeScript code runs at build time
interface Props {
  title: string;
  description?: string;
}

const { title, description } = Astro.props;
---

<!-- Template: HTML with JSX-like expressions -->
<section>
  <h1>{title}</h1>
  {description && <p>{description}</p>}
  <slot />
</section>

<!-- Scoped styles: compiled to unique selectors -->
<style>
  h1 {
    color: var(--color-primary);
  }
</style>
```

## Page Creation

```astro
---
import BaseLayout from "../layouts/BaseLayout.astro";

const pageTitle = "About Us";
---

<BaseLayout title={pageTitle}>
  <main>
    <h1>{pageTitle}</h1>
    <p>Content here</p>
  </main>
</BaseLayout>
```

## Layout Pattern

```astro
---
interface Props {
  title: string;
  description?: string;
}

const { title, description } = Astro.props;
---

<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>{title}</title>
    {description && <meta name="description" content={description} />}
  </head>
  <body>
    <slot />
  </body>
</html>
```

## Client Directives

Use the most restrictive directive possible:

- `client:load` - Must work immediately
- `client:idle` - Nice to have, after page idle
- `client:visible` - Below fold, when visible
- `client:media="(min-width: 768px)"` - Screen-size dependent

## Image Optimization

```astro
---
import { Image } from "astro:assets";
import heroImage from "../assets/hero.jpg";
---

<!-- Above fold: eager loading -->
<Image src={heroImage} alt="Hero banner" width={1200} height={600} loading="eager" />

<!-- Below fold: default lazy loading -->
<Image src={heroImage} alt="Team photo" width={800} height={400} />
```

## Key Rules

- Always define `interface Props` for components that accept props
- Use `<Image>` from `astro:assets` (never raw `<img>`)
- Add `client:*` directives only when interactivity is required
- Use semantic HTML: `<header>`, `<main>`, `<nav>`, `<footer>`
- One `<h1>` per page, no skipped heading levels
