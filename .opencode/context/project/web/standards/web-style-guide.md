# Web Style Guide

Coding conventions for the website built with Astro, Tailwind CSS v4, and TypeScript.

## File Naming

- Use `kebab-case` for all files and directories
- Astro components and pages: `my-component.astro`, `about-us.astro`
- TypeScript files: `site-config.ts`, `content-utils.ts`
- CSS files: `global.css`, `fonts.css`
- Content files: `my-blog-post.md`, `team-member.yaml`

```
# Good
src/components/hero-section.astro
src/pages/about-us.astro
src/styles/global.css
src/content/blog/first-post.md

# Bad
src/components/HeroSection.astro
src/pages/AboutUs.astro
src/content/blog/FirstPost.md
```

## Component Naming

- Use `PascalCase` for component references in templates
- The file is `kebab-case`, the import/usage is `PascalCase`

```astro
---
import HeroSection from '../components/hero-section.astro';
import BaseLayout from '../layouts/base-layout.astro';
import BlogCard from '../components/blog-card.astro';
---
<BaseLayout>
  <HeroSection />
  <BlogCard />
</BaseLayout>
```

## Directory Structure

```
src/
├── components/          # Reusable Astro components
│   ├── ui/             # Generic UI elements (buttons, cards)
│   ├── layout/         # Layout pieces (header, footer, nav)
│   └── sections/       # Page sections (hero, features, CTA)
├── content/            # Content collections
│   └── blog/           # Blog posts (markdown)
├── data/               # Static data files (JSON, YAML)
├── layouts/            # Page layouts (base, blog, docs)
├── pages/              # File-based routing
│   └── blog/           # Blog routes
├── styles/             # Global CSS
│   └── global.css      # Tailwind imports and @theme
└── content.config.ts   # Content collection schemas
public/                 # Static assets (copied as-is)
├── fonts/              # Web fonts
├── images/             # Static images
└── favicon.svg         # Favicon
```

## TypeScript Conventions

### Strict Mode

Always use Astro's strict TypeScript preset:

```json
{
  "extends": "astro/tsconfigs/strict"
}
```

### Type Annotations

- Always define `interface Props` for component props
- Use explicit return types on utility functions
- Use Zod schemas for content collection validation

```astro
---
interface Props {
  title: string;
  description?: string;
  tags: string[];
}
const { title, description = "Default description", tags } = Astro.props;
---
```

```typescript
// Utility function with explicit types
function formatDate(date: Date): string {
  return date.toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });
}
```

### Avoid `any`

Use `unknown` and narrow with type guards instead of `any`:

```typescript
// Good
function processData(input: unknown): string {
  if (typeof input === "string") return input;
  if (typeof input === "number") return String(input);
  throw new Error("Unsupported type");
}

// Bad
function processData(input: any): string {
  return input.toString();
}
```

## CSS / Tailwind Class Ordering

Order Tailwind utility classes by category. Use this sequence:

1. **Layout**: `flex`, `grid`, `block`, `inline`, `hidden`
2. **Positioning**: `relative`, `absolute`, `fixed`, `sticky`
3. **Box model**: `w-*`, `h-*`, `p-*`, `m-*`
4. **Typography**: `text-*`, `font-*`, `leading-*`, `tracking-*`
5. **Visual**: `bg-*`, `border-*`, `rounded-*`, `shadow-*`
6. **Interactivity**: `cursor-*`, `hover:*`, `focus:*`
7. **Responsive**: `sm:*`, `md:*`, `lg:*`

```html
<!-- Good: ordered by category -->
<div class="flex items-center gap-4 w-full p-6 text-lg font-medium bg-white rounded-lg shadow-md hover:shadow-lg md:p-8">

<!-- Bad: random order -->
<div class="shadow-md p-6 hover:shadow-lg flex bg-white md:p-8 text-lg w-full font-medium rounded-lg items-center gap-4">
```

### Long Class Lists

For elements with many utilities, break across lines in the template:

```astro
<section
  class:list={[
    "flex flex-col items-center",
    "w-full max-w-4xl mx-auto",
    "px-6 py-16",
    "text-center",
    "bg-white dark:bg-gray-900",
  ]}
>
```

## Import Ordering

Group imports in this order, separated by blank lines:

1. **Astro built-ins**: `astro:content`, `astro:assets`
2. **Layouts**: `../layouts/*`
3. **Components**: `../components/*`
4. **Utilities/data**: `../utils/*`, `../data/*`
5. **Types**: type-only imports

```astro
---
import { getCollection } from 'astro:content';
import { Image } from 'astro:assets';

import BaseLayout from '../layouts/base-layout.astro';

import HeroSection from '../components/sections/hero-section.astro';
import BlogCard from '../components/ui/blog-card.astro';

import { formatDate } from '../utils/dates';
import siteConfig from '../data/site-config';

import type { CollectionEntry } from 'astro:content';
---
```

## Comment Conventions

### Astro Frontmatter

Use `//` for inline comments in the frontmatter script:

```astro
---
// Fetch all published blog posts, sorted by date
const posts = (await getCollection('blog'))
  .filter((post) => !post.data.draft)
  .sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf());
---
```

### HTML Template

Use HTML comments for structural markers, but prefer self-documenting markup:

```astro
<!-- Main content area -->
<main id="main-content">
  <slot />
</main>
```

### CSS

Use `/* */` comments for section headers in global.css:

```css
@import "tailwindcss";

/* === Theme Configuration === */
@theme {
  --color-primary: oklch(0.72 0.11 178);
}

/* === Custom Component Styles === */
@layer components {
  /* ... */
}
```

## Code Formatting

- Use 2 spaces for indentation in all files (.astro, .ts, .css, .json)
- Maximum line length: 100 characters (soft limit)
- Trailing commas in multi-line constructs
- Semicolons required in TypeScript
- Double quotes for strings in TypeScript and HTML attributes
- Single quotes for CSS values only when required

```json
// .prettierrc (project config)
{
  "semi": true,
  "singleQuote": false,
  "tabWidth": 2,
  "trailingComma": "all",
  "printWidth": 100
}
```

## Content Files

### Markdown Frontmatter

Use consistent frontmatter fields across content types:

```markdown
---
title: "Post Title"
description: "Brief description for SEO and previews"
pubDate: 2026-02-05
updatedDate: 2026-02-05
draft: false
tags: ["web", "astro"]
---
```

### Image References

Always use descriptive alt text and specify dimensions when possible:

```astro
---
import { Image } from 'astro:assets';
import heroImage from '../assets/hero.jpg';
---
<Image src={heroImage} alt="Your Organization headquarters at sunset" width={1200} height={630} />
```
