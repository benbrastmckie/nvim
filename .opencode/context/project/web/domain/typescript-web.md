# TypeScript in Astro

TypeScript configuration and patterns for type-safe Astro development.

## tsconfig.json Setup

Astro provides TypeScript presets:

```json
{
  "extends": "astro/tsconfigs/strict",
  "include": [".astro/types.d.ts", "**/*"],
  "exclude": ["dist"],
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@components/*": ["./src/components/*"],
      "@layouts/*": ["./src/layouts/*"],
      "@content/*": ["./src/content/*"],
      "@styles/*": ["./src/styles/*"],
      "@assets/*": ["./src/assets/*"],
      "@utils/*": ["./src/utils/*"]
    }
  }
}
```

### Available Presets

| Preset | Strictness | Use When |
|--------|-----------|----------|
| `astro/tsconfigs/base` | Minimal | Quick prototyping |
| `astro/tsconfigs/strict` | Standard strict | **Recommended for projects** |
| `astro/tsconfigs/strictest` | Maximum | Mission-critical code |

**Always use `strict`** for production websites.

## Type-Safe Component Props

### Interface Pattern

```astro
---
interface Props {
  title: string;
  description?: string;
  tags: string[];
  variant?: 'primary' | 'secondary' | 'accent';
  href?: string;
}

const {
  title,
  description,
  tags,
  variant = 'primary',
  href,
} = Astro.props;
---

<div class:list={['card', `card--${variant}`]}>
  <h2>{title}</h2>
  {description && <p>{description}</p>}
  {href && <a href={href}>Read more</a>}
  <ul>
    {tags.map((tag) => <li>{tag}</li>)}
  </ul>
</div>
```

### Complex Props

```astro
---
interface SocialLink {
  platform: 'github' | 'twitter' | 'linkedin';
  url: string;
  label: string;
}

interface Props {
  name: string;
  role: string;
  avatar: ImageMetadata;
  social: SocialLink[];
}

const { name, role, avatar, social } = Astro.props;
---
```

## Built-in Type Utilities

### HTMLAttributes

Type-safe HTML element attributes:

```astro
---
import type { HTMLAttributes } from 'astro/types';

interface Props extends HTMLAttributes<'a'> {
  variant?: 'primary' | 'ghost';
}

const { variant = 'primary', ...attrs } = Astro.props;
---

<a class:list={['btn', `btn--${variant}`]} {...attrs}>
  <slot />
</a>
```

### ComponentProps

Reference another component's prop types:

```typescript
import type { ComponentProps } from 'astro/types';
import Card from '../components/Card.astro';

type CardProps = ComponentProps<typeof Card>;
```

### Route Type Inference

```astro
---
// src/pages/blog/[slug].astro
import type {
  InferGetStaticParamsType,
  InferGetStaticPropsType,
} from 'astro';
import { getCollection, render } from 'astro:content';

export async function getStaticPaths() {
  const posts = await getCollection('blog');
  return posts.map((post) => ({
    params: { slug: post.id },
    props: { post },
  }));
}

type Params = InferGetStaticParamsType<typeof getStaticPaths>;
type Props = InferGetStaticPropsType<typeof getStaticPaths>;

const { slug } = Astro.params as Params;
const { post } = Astro.props;
const { Content } = await render(post);
---
```

### Content Collection Types

```typescript
import type { CollectionEntry } from 'astro:content';

// Type for a blog post entry
type BlogPost = CollectionEntry<'blog'>;

// In component props
interface Props {
  post: CollectionEntry<'blog'>;
  relatedPosts: CollectionEntry<'blog'>[];
}
```

## Content Collection Schemas with Zod

```typescript
// src/content.config.ts
import { defineCollection } from 'astro:content';
import { glob } from 'astro/loaders';
import { z } from 'astro/zod';

const blog = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/data/blog" }),
  schema: z.object({
    title: z.string().max(100),
    description: z.string().max(200),
    pubDate: z.coerce.date(),
    updatedDate: z.coerce.date().optional(),
    author: z.string().default('Team'),
    tags: z.array(z.string()).default([]),
    draft: z.boolean().default(false),
    heroImage: z.string().optional(),
  }),
});

const team = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/data/team" }),
  schema: z.object({
    name: z.string(),
    role: z.string(),
    bio: z.string(),
    avatar: z.string(),
    order: z.number(),
  }),
});

export const collections = { blog, team };
```

### Common Zod Patterns

```typescript
import { z } from 'astro/zod';

// Enum values
z.enum(['draft', 'published', 'archived'])

// Coerce string to date
z.coerce.date()

// URL validation
z.string().url()

// Constrained strings
z.string().min(1).max(200)

// Nested objects
z.object({
  width: z.number(),
  height: z.number(),
})

// Discriminated unions
z.discriminatedUnion('type', [
  z.object({ type: z.literal('text'), content: z.string() }),
  z.object({ type: z.literal('image'), src: z.string(), alt: z.string() }),
])
```

## Import Aliases

Use `@` prefixed aliases instead of relative paths:

```astro
---
// Instead of: import Card from '../../../../components/Card.astro';
import Card from '@components/Card.astro';
import BaseLayout from '@layouts/BaseLayout.astro';
import { formatDate } from '@utils/dates';
---
```

Aliases are defined in `tsconfig.json` `paths` and Astro resolves them automatically.

## Type Checking

### CLI Command

```bash
# Type-check all .astro and .ts files
astro check

# Type-check then build
astro check && astro build
```

### CI Pipeline

```yaml
# Example GitHub Actions step
- name: Type check
  run: pnpm astro check

- name: Build
  run: pnpm build
```

## env.d.ts

Global type declarations for the project:

```typescript
// src/env.d.ts
/// <reference path="../.astro/types.d.ts" />

// Extend ImportMetaEnv for custom env variables
interface ImportMetaEnv {
  readonly PUBLIC_SITE_URL: string;
  readonly PUBLIC_API_BASE: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
```

The `/// <reference path="../.astro/types.d.ts" />` line is generated by `astro sync` and provides types for content collections, image imports, and other Astro-specific features.

## TypeScript in Astro Components vs .ts Files

| Feature | .astro frontmatter | .ts files |
|---------|-------------------|-----------|
| Top-level await | Yes | No (use async functions) |
| Interface Props | Yes (special) | N/A |
| Astro.* globals | Yes | No (pass as arguments) |
| Import .astro | Yes | No |
| Generic utilities | Possible but awkward | Preferred |

**Rule**: Put reusable logic in `.ts` utility files. Keep `.astro` frontmatter focused on props, data fetching, and template preparation.
