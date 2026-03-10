# Astro Layout Patterns

Patterns for building layout components that wrap pages.

## BaseLayout Pattern

The foundational layout wrapping all pages:

```astro
---
// src/layouts/BaseLayout.astro
interface Props {
  title: string;
  description?: string;
  image?: string;
  noIndex?: boolean;
}

const {
  title,
  description = "Your Site Name - Building great web experiences.",
  image = "/og-default.png",
  noIndex = false,
} = Astro.props;

const canonicalUrl = new URL(Astro.url.pathname, Astro.site);
---

<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <link rel="sitemap" href="/sitemap-index.xml" />

    <!-- SEO -->
    <title>{title}</title>
    <meta name="description" content={description} />
    <link rel="canonical" href={canonicalUrl} />
    {noIndex && <meta name="robots" content="noindex,nofollow" />}

    <!-- Open Graph -->
    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:image" content={new URL(image, Astro.site)} />
    <meta property="og:url" content={canonicalUrl} />
    <meta property="og:type" content="website" />

    <!-- Twitter -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={title} />
    <meta name="twitter:description" content={description} />
    <meta name="twitter:image" content={new URL(image, Astro.site)} />

    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />

    <!-- Styles -->
    <link rel="stylesheet" href="/src/styles/global.css" />

    <!-- Head slot for page-specific additions -->
    <slot name="head" />
  </head>
  <body class="min-h-screen bg-background text-foreground font-body antialiased">
    <a href="#main-content" class="skip-link">Skip to main content</a>
    <slot name="header" />
    <main id="main-content">
      <slot />
    </main>
    <slot name="footer" />
  </body>
</html>
```

## Nested Layouts

### PageLayout (Adds Navigation and Footer)

```astro
---
// src/layouts/PageLayout.astro
import BaseLayout from './BaseLayout.astro';
import Header from '@components/Header.astro';
import Footer from '@components/Footer.astro';

interface Props {
  title: string;
  description?: string;
  image?: string;
}

const { title, description, image } = Astro.props;
---

<BaseLayout title={title} description={description} image={image}>
  <Header slot="header" />
  <slot />
  <Footer slot="footer" />
</BaseLayout>
```

### BlogLayout (Blog Post Wrapper)

```astro
---
// src/layouts/BlogLayout.astro
import PageLayout from './PageLayout.astro';
import { formatDate } from '@utils/dates';
import type { CollectionEntry } from 'astro:content';

interface Props {
  post: CollectionEntry<'blog'>;
}

const { post } = Astro.props;
const { title, description, pubDate, author, tags } = post.data;
---

<PageLayout title={title} description={description}>
  <article class="max-w-3xl mx-auto px-4 py-12">
    <header class="mb-8">
      <h1 class="text-4xl font-heading font-bold mb-4">{title}</h1>
      <div class="flex items-center gap-4 text-muted">
        <time datetime={pubDate.toISOString()}>{formatDate(pubDate)}</time>
        <span>by {author}</span>
      </div>
      {tags.length > 0 && (
        <div class="flex gap-2 mt-4">
          {tags.map((tag) => (
            <span class="px-2 py-1 bg-surface rounded text-sm">{tag}</span>
          ))}
        </div>
      )}
    </header>

    <div class="prose prose-lg">
      <slot />
    </div>
  </article>
</PageLayout>
```

## Head Management

### Page-Specific Head Tags

Pages can inject into `<head>` via the `head` named slot:

```astro
---
// src/pages/blog/[slug].astro
import BlogLayout from '@layouts/BlogLayout.astro';
---

<BlogLayout post={post}>
  <!-- Inject structured data into head -->
  <script slot="head" type="application/ld+json" set:html={JSON.stringify({
    "@context": "https://schema.org",
    "@type": "BlogPosting",
    "headline": post.data.title,
    "datePublished": post.data.pubDate.toISOString(),
  })} />

  <Content />
</BlogLayout>
```

### SEO Meta Pattern

```astro
---
// src/components/SEO.astro
interface Props {
  title: string;
  description: string;
  image?: string;
  type?: 'website' | 'article';
  publishedDate?: Date;
}

const {
  title,
  description,
  image,
  type = 'website',
  publishedDate,
} = Astro.props;

const canonicalUrl = new URL(Astro.url.pathname, Astro.site);
---

<title>{title}</title>
<meta name="description" content={description} />
<link rel="canonical" href={canonicalUrl} />

<meta property="og:title" content={title} />
<meta property="og:description" content={description} />
<meta property="og:type" content={type} />
<meta property="og:url" content={canonicalUrl} />
{image && <meta property="og:image" content={new URL(image, Astro.site)} />}
{publishedDate && (
  <meta property="article:published_time" content={publishedDate.toISOString()} />
)}
```

## Layout Hierarchy

```
BaseLayout (html/head/body, meta, fonts, styles)
├── PageLayout (header + footer)
│   ├── BlogLayout (article wrapper, post metadata)
│   ├── DocsLayout (sidebar navigation, table of contents)
│   └── (pages use PageLayout directly)
└── MinimalLayout (no nav/footer, for landing pages)
```

**Rule**: Every page uses at least `BaseLayout`. Most pages use `PageLayout`. Specialized content types get their own layout extending `PageLayout`.

## Slot-Based Layout Customization

```astro
---
// src/layouts/SplitLayout.astro
import PageLayout from './PageLayout.astro';

interface Props {
  title: string;
  description?: string;
  sidebarPosition?: 'left' | 'right';
}

const { title, description, sidebarPosition = 'right' } = Astro.props;
---

<PageLayout title={title} description={description}>
  <div class:list={[
    'max-w-6xl mx-auto px-4 py-12 grid gap-8',
    sidebarPosition === 'left'
      ? 'md:grid-cols-[300px_1fr]'
      : 'md:grid-cols-[1fr_300px]',
  ]}>
    {sidebarPosition === 'left' && (
      <aside class="order-first">
        <slot name="sidebar" />
      </aside>
    )}
    <div>
      <slot />
    </div>
    {sidebarPosition === 'right' && (
      <aside>
        <slot name="sidebar" />
      </aside>
    )}
  </div>
</PageLayout>
```

## Markdown Layout via Frontmatter

Markdown files can specify their layout:

```markdown
---
layout: ../../layouts/BlogLayout.astro
title: "My Blog Post"
pubDate: 2026-02-01
---

Content rendered inside the layout's default slot.
```

The frontmatter fields are available as `Astro.props.frontmatter` in the layout.

**Note**: Content collections with `render()` are preferred over the `layout` frontmatter approach. Use `render()` for type safety and more control.
