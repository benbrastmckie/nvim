# Astro Page Templates

Boilerplate templates for common page types in the website.

## Basic Page

```astro
---
// src/pages/about.astro
import BaseLayout from '../layouts/base-layout.astro';
---
<BaseLayout title="About" description="About Your Site Name">
  <section class="max-w-4xl mx-auto px-6 py-16">
    <h1 class="text-4xl font-bold mb-8">About Us</h1>
    <p class="text-lg leading-relaxed text-gray-700 dark:text-gray-300">
      <!-- Page content here -->
    </p>
  </section>
</BaseLayout>
```

## Page with SEO Meta Tags

```astro
---
// src/pages/index.astro
import BaseLayout from '../layouts/base-layout.astro';
import { Image } from 'astro:assets';
import heroImage from '../assets/hero.jpg';

const title = "Your Site Name";
const description = "Building formal verification tools for the next generation of software.";
const canonicalUrl = new URL(Astro.url.pathname, Astro.site);
const ogImageUrl = new URL("/og-image.png", Astro.site);
---
<BaseLayout title={title} description={description}>
  <Fragment slot="head">
    <link rel="canonical" href={canonicalUrl} />

    <!-- Open Graph -->
    <meta property="og:type" content="website" />
    <meta property="og:title" content={title} />
    <meta property="og:description" content={description} />
    <meta property="og:url" content={canonicalUrl} />
    <meta property="og:image" content={ogImageUrl} />

    <!-- Twitter Card -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content={title} />
    <meta name="twitter:description" content={description} />
    <meta name="twitter:image" content={ogImageUrl} />
  </Fragment>

  <section class="max-w-6xl mx-auto px-6 py-20 text-center">
    <h1 class="text-5xl font-bold mb-6">{title}</h1>
    <p class="text-xl text-gray-600 dark:text-gray-400 mb-12">
      {description}
    </p>
    <Image
      src={heroImage}
      alt="Your Site Name visualization"
      width={1200}
      height={630}
      loading="eager"
    />
  </section>
</BaseLayout>
```

## Content Collection Page (Blog Index)

```astro
---
// src/pages/blog/index.astro
import BaseLayout from '../../layouts/base-layout.astro';
import BlogCard from '../../components/ui/blog-card.astro';
import { getCollection } from 'astro:content';

import type { CollectionEntry } from 'astro:content';

const posts: CollectionEntry<'blog'>[] = (await getCollection('blog'))
  .filter((post) => !post.data.draft)
  .sort((a, b) => b.data.pubDate.valueOf() - a.data.pubDate.valueOf());
---
<BaseLayout title="Blog" description="Latest articles from Your Site Name">
  <section class="max-w-4xl mx-auto px-6 py-16">
    <h1 class="text-4xl font-bold mb-12">Blog</h1>

    {posts.length === 0 && (
      <p class="text-gray-500">No posts yet. Check back soon.</p>
    )}

    <ul class="grid gap-8 md:grid-cols-2">
      {posts.map((post) => (
        <li>
          <BlogCard post={post} />
        </li>
      ))}
    </ul>
  </section>
</BaseLayout>
```

## Dynamic Route Page (Blog Post)

```astro
---
// src/pages/blog/[slug].astro
import BaseLayout from '../../layouts/base-layout.astro';
import { getCollection, render } from 'astro:content';

import type { GetStaticPaths, InferGetStaticPropsType } from 'astro';

export const getStaticPaths = (async () => {
  const posts = await getCollection('blog');
  return posts.map((post) => ({
    params: { slug: post.id },
    props: { post },
  }));
}) satisfies GetStaticPaths;

type Props = InferGetStaticPropsType<typeof getStaticPaths>;

const { post } = Astro.props;
const { Content } = await render(post);
const { title, description, pubDate } = post.data;
---
<BaseLayout title={title} description={description}>
  <article class="max-w-3xl mx-auto px-6 py-16">
    <header class="mb-12">
      <time
        datetime={pubDate.toISOString()}
        class="text-sm text-gray-500 dark:text-gray-400"
      >
        {pubDate.toLocaleDateString("en-US", {
          year: "numeric",
          month: "long",
          day: "numeric",
        })}
      </time>
      <h1 class="text-4xl font-bold mt-2">{title}</h1>
      {description && (
        <p class="text-lg text-gray-600 dark:text-gray-400 mt-4">
          {description}
        </p>
      )}
    </header>

    <div class="prose prose-lg dark:prose-invert max-w-none">
      <Content />
    </div>
  </article>
</BaseLayout>
```

## 404 Error Page

```astro
---
// src/pages/404.astro
import BaseLayout from '../layouts/base-layout.astro';
---
<BaseLayout title="Page Not Found" description="The requested page could not be found.">
  <section class="flex flex-col items-center justify-center min-h-[60vh] px-6 text-center">
    <h1 class="text-6xl font-bold text-gray-300 dark:text-gray-700 mb-4">
      404
    </h1>
    <h2 class="text-2xl font-semibold mb-4">Page Not Found</h2>
    <p class="text-gray-600 dark:text-gray-400 mb-8 max-w-md">
      The page you are looking for does not exist or has been moved.
    </p>
    <a
      href="/"
      class="inline-flex items-center px-6 py-3 text-white bg-primary rounded-lg hover:bg-primary/90 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
    >
      Return Home
    </a>
  </section>
</BaseLayout>
```

## Static Page with Structured Data

```astro
---
// src/pages/contact.astro
import BaseLayout from '../layouts/base-layout.astro';

const structuredData = {
  "@context": "https://schema.org",
  "@type": "Organization",
  "name": "Your Site Name",
  "url": Astro.site?.toString(),
  "contactPoint": {
    "@type": "ContactPoint",
    "contactType": "general",
    "email": "contact@example.com",
  },
};
---
<BaseLayout title="Contact" description="Get in touch with Your Site Name">
  <Fragment slot="head">
    <script type="application/ld+json" set:html={JSON.stringify(structuredData)} />
  </Fragment>

  <section class="max-w-2xl mx-auto px-6 py-16">
    <h1 class="text-4xl font-bold mb-8">Contact Us</h1>
    <!-- Contact form or information -->
  </section>
</BaseLayout>
```
