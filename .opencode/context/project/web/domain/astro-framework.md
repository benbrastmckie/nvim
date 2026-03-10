# Astro Framework Reference

Core concepts for the Astro web framework (v5 stable, v6 beta).

## .astro File Format

Every `.astro` file has two sections separated by code fences:

```astro
---
// Component Script (frontmatter)
// Runs at build time (SSG) or request time (SSR)
// Full access to Node.js APIs and npm packages
import BaseLayout from '../layouts/BaseLayout.astro';
import Card from '../components/Card.astro';

interface Props {
  title: string;
  description?: string;
}

const { title, description = "Default description" } = Astro.props;
const response = await fetch('https://api.example.com/data');
const data = await response.json();
---

<!-- Component Template -->
<!-- Renders to HTML, supports JSX-like expressions -->
<BaseLayout title={title}>
  <h1>{title}</h1>
  <p>{description}</p>
  {data.items.map((item) => (
    <Card title={item.name} />
  ))}
  <slot />
</BaseLayout>
```

Key rules:
- Frontmatter runs on the server, never in the browser
- Top-level `await` is allowed in frontmatter
- Template uses JSX-like syntax but outputs pure HTML
- No `useState`, no reactivity -- it is a template language, not a UI framework

## Islands Architecture

Astro ships zero JavaScript to the browser by default. Interactive components from UI frameworks (React, Svelte, Vue, etc.) are hydrated selectively.

### Client Directives

| Directive | When It Hydrates | Use For |
|-----------|-----------------|---------|
| `client:load` | Immediately on page load | Critical interactive UI (nav menus, forms) |
| `client:idle` | After page finishes loading | Below-fold interactive components |
| `client:visible` | When element enters viewport | Lazy components (carousels, comments) |
| `client:media={QUERY}` | When media query matches | Mobile-only or desktop-only components |
| `client:only={FRAMEWORK}` | Client-side only, no SSR | Components that cannot run on server |

```astro
---
import Counter from '../components/Counter.tsx';
import HeavyChart from '../components/Chart.tsx';
---

<!-- Hydrates immediately -->
<Counter client:load />

<!-- Hydrates when scrolled into view -->
<HeavyChart client:visible />

<!-- Hydrates only on mobile -->
<MobileMenu client:media="(max-width: 768px)" />
```

### When to Use Client Directives

- **No directive** (default): Component renders to static HTML, zero JS shipped
- **Use `client:load`**: User needs to interact with it immediately
- **Use `client:idle`**: Interactive but not immediately needed
- **Use `client:visible`**: Far down the page, might never be seen
- **Prefer no directive**: Most components on a content site need no interactivity

## Output Modes

### Static Site Generation (SSG) -- Default

```typescript
// astro.config.mjs
export default defineConfig({
  output: 'static',  // default, can omit
});
```

All pages pre-rendered at build time. Best for content sites.

### Server-Side Rendering (SSR)

```typescript
// astro.config.mjs
import cloudflare from '@astrojs/cloudflare';

export default defineConfig({
  output: 'server',
  adapter: cloudflare(),
});
```

All pages rendered on-demand per request.

### Hybrid Mode

```typescript
// astro.config.mjs
export default defineConfig({
  output: 'server',
  adapter: cloudflare(),
});
```

```astro
---
// src/pages/about.astro
// This page is pre-rendered at build time
export const prerender = true;
---
```

Default is server-rendered; opt individual pages into static with `export const prerender = true`.

## Built-in Components

### Image

```astro
---
import { Image } from 'astro:assets';
import heroImage from '../assets/hero.jpg';
---

<!-- Local image (optimized at build time) -->
<Image src={heroImage} alt="Hero banner" />

<!-- Remote image (specify dimensions) -->
<Image
  src="https://example.com/photo.jpg"
  alt="Remote photo"
  width={800}
  height={600}
/>
```

Features:
- Automatic WebP/AVIF conversion
- Width/height attributes set automatically (prevents CLS)
- Lazy loading by default
- Responsive `srcset` generation

### Content Rendering

```astro
---
import { render } from 'astro:content';
const { Content, headings } = await render(post);
---

<Content />
```

## Astro Global Object

Available in all `.astro` frontmatter:

| Property | Type | Description |
|----------|------|-------------|
| `Astro.props` | `Props` | Component props passed by parent |
| `Astro.params` | `object` | Dynamic route parameters |
| `Astro.url` | `URL` | Full URL of the current page |
| `Astro.request` | `Request` | The raw HTTP request (SSR only) |
| `Astro.redirect()` | `Response` | Redirect to another URL (SSR only) |
| `Astro.slots` | `object` | Check if named slots are provided |
| `Astro.cookies` | `AstroCookies` | Read/write cookies (SSR only) |
| `Astro.site` | `URL` | Site URL from config |
| `Astro.generator` | `string` | Astro version string |

```astro
---
const currentPath = Astro.url.pathname;
const { slug } = Astro.params;
const hasFooter = Astro.slots.has('footer');
---
```

## Routing

### File-Based Routing

```
src/pages/
├── index.astro          -> /
├── about.astro          -> /about
├── blog/
│   ├── index.astro      -> /blog
│   └── [slug].astro     -> /blog/:slug
└── [...slug].astro      -> /* (catch-all / 404)
```

### Dynamic Routes (SSG)

```astro
---
// src/pages/blog/[slug].astro
import { getCollection } from 'astro:content';

export async function getStaticPaths() {
  const posts = await getCollection('blog');
  return posts.map((post) => ({
    params: { slug: post.id },
    props: { post },
  }));
}

const { post } = Astro.props;
const { Content } = await render(post);
---

<Content />
```

### 404 Page

```astro
<!-- src/pages/404.astro -->
---
import BaseLayout from '../layouts/BaseLayout.astro';
---

<BaseLayout title="Not Found">
  <h1>404 - Page Not Found</h1>
</BaseLayout>
```

## Project Structure

```
src/
├── assets/           # Images, fonts (processed by build)
├── components/       # .astro and framework components
├── content/          # Content collections (markdown, MDX)
│   └── config.ts     # Collection schemas
├── data/             # Data files for content collections
├── layouts/          # Layout components
├── pages/            # File-based routes
├── styles/           # Global CSS
└── content.config.ts # Content collection definitions
```

## Configuration

```typescript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import cloudflare from '@astrojs/cloudflare';

export default defineConfig({
  site: 'https://example.com',
  output: 'static',
  integrations: [],
  vite: {
    plugins: [tailwindcss()],
  },
});
```

## Astro 5 vs Astro 6

| Feature | Astro 5 (Stable) | Astro 6 (Beta) |
|---------|-------------------|-----------------|
| Content Collections | Stable with loaders | Live Collections (promoted) |
| CSP Support | Experimental | Stable |
| Dev Server | Vite standard | Vite Environment API (workerd parity) |
| Node.js | 18+ | 22+ required |
| Cloudflare | Via adapter | First-class workerd runtime |
| `Astro.glob()` | Deprecated | Removed (use `import.meta.glob()`) |

**Recommendation**: Target Astro 5 APIs. Astro 6 changes are additive -- the same code works on both.
