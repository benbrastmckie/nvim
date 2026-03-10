# Astro Content Collections Patterns

Patterns for defining, querying, and rendering type-safe content collections.

## Defining Collections

### Basic Collection with Glob Loader

```typescript
// src/content.config.ts
import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const blog = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/data/blog" }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    pubDate: z.coerce.date(),
    draft: z.boolean().default(false),
  }),
});

export const collections = { blog };
```

### Multiple Collections

```typescript
// src/content.config.ts
const blog = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/data/blog" }),
  schema: z.object({
    title: z.string(),
    description: z.string().max(200),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    author: z.string().default('Team'),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
  }),
});

const team = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/data/team" }),
  schema: z.object({
    name: z.string(),
    role: z.string(),
    bio: z.string(),
    order: z.number(),
  }),
});

export const collections = { blog, team };
```

### Content File Format

```markdown
<!-- src/data/blog/first-post.md -->
---
title: "Our First Blog Post"
description: "Announcing the launch of our new website."
pubDate: 2026-02-01
author: "Team"
tags: ["announcement", "company"]
---

The body of the blog post written in Markdown.

## Heading

More content here.
```

## Querying Collections

### Get All Entries

```astro
---
import { getCollection } from 'astro:content';

// Get all entries
const allPosts = await getCollection('blog');

// Filter by property
const publishedPosts = await getCollection('blog', ({ data }) => {
  return data.draft !== true;
});
---
```

### Get Single Entry

```astro
---
import { getEntry } from 'astro:content';

// By ID (filename without extension)
const post = await getEntry('blog', 'first-post');

if (!post) {
  return Astro.redirect('/404');
}
---
```

### Sorting

```astro
---
import { getCollection } from 'astro:content';

const posts = await getCollection('blog', ({ data }) => !data.draft);

// Sort by date (newest first)
const sortedPosts = posts.sort(
  (a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf()
);

// Sort by custom field
const teamMembers = await getCollection('team');
const sortedTeam = teamMembers.sort(
  (a, b) => a.data.order - b.data.order
);
---
```

### Filtering with Multiple Criteria

```astro
---
import { getCollection } from 'astro:content';

// Published posts with a specific tag
const techPosts = await getCollection('blog', ({ data }) => {
  return !data.draft && data.tags.includes('technology');
});

// Active projects only
const activeProjects = await getCollection('projects', ({ data }) => {
  return data.status === 'active';
});

// Featured items
const featured = await getCollection('projects', ({ data }) => {
  return data.featured;
});
---
```

### Pagination

```astro
---
// src/pages/blog/[...page].astro
import type { GetStaticPaths } from 'astro';
import { getCollection } from 'astro:content';

export const getStaticPaths = (async ({ paginate }) => {
  const posts = await getCollection('blog', ({ data }) => !data.draft);
  const sorted = posts.sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf());
  return paginate(sorted, { pageSize: 10 });
}) satisfies GetStaticPaths;

const { page } = Astro.props;
// page.data, page.currentPage, page.lastPage, page.url.prev, page.url.next
---
```

## Rendering Content

### Basic Render

```astro
---
import { getEntry, render } from 'astro:content';

const post = await getEntry('blog', 'first-post');
const { Content, headings } = await render(post);
---

<article>
  <h1>{post.data.title}</h1>
  <Content />
</article>
```

### With Custom Components

```astro
---
import { render } from 'astro:content';
import CustomImage from '@components/CustomImage.astro';
import Callout from '@components/Callout.astro';

const { Content } = await render(post);
---

<Content components={{ img: CustomImage, blockquote: Callout }} />
```

### Extracting Headings (Table of Contents)

```astro
---
import { render } from 'astro:content';

const { Content, headings } = await render(post);
// headings: { depth: number; slug: string; text: string }[]
---

<nav aria-label="Table of contents">
  <ul>
    {headings
      .filter((h) => h.depth <= 3)
      .map((h) => (
        <li style={`margin-left: ${(h.depth - 1) * 1}rem`}>
          <a href={`#${h.slug}`}>{h.text}</a>
        </li>
      ))}
  </ul>
</nav>

<Content />
```

## Static Route Generation

### Single Collection Routes

```astro
---
// src/pages/blog/[slug].astro
import { getCollection, render } from 'astro:content';
import BlogLayout from '@layouts/BlogLayout.astro';

export async function getStaticPaths() {
  const posts = await getCollection('blog', ({ data }) => !data.draft);
  return posts.map((post) => ({
    params: { slug: post.id },
    props: { post },
  }));
}

const { post } = Astro.props;
const { Content } = await render(post);
---

<BlogLayout post={post}>
  <Content />
</BlogLayout>
```

### Tag Pages

```astro
---
// src/pages/blog/tag/[tag].astro
import { getCollection } from 'astro:content';

export async function getStaticPaths() {
  const posts = await getCollection('blog', ({ data }) => !data.draft);
  const tags = [...new Set(posts.flatMap((post) => post.data.tags))];
  return tags.map((tag) => ({
    params: { tag },
    props: { posts: posts.filter((p) => p.data.tags.includes(tag)) },
  }));
}

const { tag } = Astro.params;
const { posts } = Astro.props;
---

<h1>Posts tagged "{tag}"</h1>
{posts.map((post) => (
  <article>
    <a href={`/blog/${post.id}`}>{post.data.title}</a>
  </article>
))}
```

## Schema Patterns

### Image Schema with Astro Assets

```typescript
const blog = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/data/blog" }),
  schema: ({ image }) => z.object({
    title: z.string(),
    heroImage: image().optional(),
  }),
});
```

### Reusable Schema Parts

```typescript
const seoFields = {
  title: z.string().max(60),
  description: z.string().max(160),
};

const blog = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/data/blog" }),
  schema: z.object({
    ...seoFields,
    pubDate: z.coerce.date(),
    author: z.string(),
    draft: z.boolean().default(false),
  }),
});
```
