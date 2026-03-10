# Astro Component Templates

Boilerplate templates for common Astro components in the website.

## Basic Component with Props

```astro
---
// src/components/ui/heading.astro
interface Props {
  level?: 1 | 2 | 3 | 4;
  class?: string;
}

const { level = 2, class: className = "" } = Astro.props;
const Tag = `h${level}` as "h1" | "h2" | "h3" | "h4";
---
<Tag class:list={["font-bold tracking-tight", className]}>
  <slot />
</Tag>
```

## Component with Default and Named Slots

```astro
---
// src/components/ui/callout.astro
interface Props {
  type?: "info" | "warning" | "success";
}

const { type = "info" } = Astro.props;

const styles = {
  info: "bg-blue-50 border-blue-300 text-blue-900 dark:bg-blue-950 dark:border-blue-700 dark:text-blue-100",
  warning: "bg-amber-50 border-amber-300 text-amber-900 dark:bg-amber-950 dark:border-amber-700 dark:text-amber-100",
  success: "bg-green-50 border-green-300 text-green-900 dark:bg-green-950 dark:border-green-700 dark:text-green-100",
};
---
<aside class:list={["border-l-4 p-4 rounded-r-lg my-6", styles[type]]} role="note">
  <div class="font-semibold mb-1">
    <slot name="title" />
  </div>
  <div class="text-sm">
    <slot />
  </div>
</aside>
```

Usage:

```astro
<Callout type="warning">
  <Fragment slot="title">Important Note</Fragment>
  This feature requires Node.js 22 or later.
</Callout>
```

## Interactive Island Component

```astro
---
// src/components/ui/theme-toggle.astro
// This component uses client-side JavaScript for interactivity
---
<button
  id="theme-toggle"
  type="button"
  aria-label="Toggle dark mode"
  class="inline-flex items-center justify-center w-10 h-10 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
>
  <svg class="w-5 h-5 dark:hidden" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20.354 15.354A9 9 0 018.646 3.646 9.003 9.003 0 0012 21a9.003 9.003 0 008.354-5.646z" />
  </svg>
  <svg class="w-5 h-5 hidden dark:block" fill="none" viewBox="0 0 24 24" stroke="currentColor">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z" />
  </svg>
</button>

<script>
  const toggle = document.getElementById("theme-toggle");

  function setTheme(dark: boolean): void {
    document.documentElement.classList.toggle("dark", dark);
    localStorage.setItem("theme", dark ? "dark" : "light");
  }

  toggle?.addEventListener("click", () => {
    const isDark = document.documentElement.classList.contains("dark");
    setTheme(!isDark);
  });

  // Initialize from localStorage or system preference
  const stored = localStorage.getItem("theme");
  if (stored === "dark" || (!stored && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
    setTheme(true);
  }
</script>
```

Note: This component uses an inline `<script>` tag (no `client:*` directive needed) because it is a pure Astro component with vanilla JavaScript.

## Card Component

```astro
---
// src/components/ui/blog-card.astro
import { Image } from 'astro:assets';
import type { CollectionEntry } from 'astro:content';

interface Props {
  post: CollectionEntry<'blog'>;
}

const { post } = Astro.props;
const { title, description, pubDate } = post.data;
---
<a
  href={`/blog/${post.id}`}
  class="group block rounded-xl border border-gray-200 dark:border-gray-800 overflow-hidden hover:shadow-lg transition-shadow duration-200 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
>
  <div class="p-6">
    <time
      datetime={pubDate.toISOString()}
      class="text-sm text-gray-500 dark:text-gray-400"
    >
      {pubDate.toLocaleDateString("en-US", {
        year: "numeric",
        month: "short",
        day: "numeric",
      })}
    </time>
    <h3 class="text-xl font-semibold mt-2 group-hover:text-primary transition-colors">
      {title}
    </h3>
    {description && (
      <p class="text-gray-600 dark:text-gray-400 mt-2 line-clamp-2">
        {description}
      </p>
    )}
  </div>
</a>
```

## Navigation Component

```astro
---
// src/components/layout/nav.astro
interface Props {
  class?: string;
}

const { class: className = "" } = Astro.props;
const currentPath = Astro.url.pathname;

const links = [
  { href: "/", label: "Home" },
  { href: "/about", label: "About" },
  { href: "/blog", label: "Blog" },
  { href: "/contact", label: "Contact" },
];

function isActive(href: string): boolean {
  if (href === "/") return currentPath === "/";
  return currentPath.startsWith(href);
}
---
<nav aria-label="Main navigation" class:list={["flex items-center gap-1", className]}>
  {links.map((link) => (
    <a
      href={link.href}
      class:list={[
        "px-4 py-2 rounded-lg text-sm font-medium transition-colors",
        "hover:bg-gray-100 dark:hover:bg-gray-800",
        "focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary",
        isActive(link.href)
          ? "text-primary bg-primary/10"
          : "text-gray-700 dark:text-gray-300",
      ]}
      aria-current={isActive(link.href) ? "page" : undefined}
    >
      {link.label}
    </a>
  ))}
</nav>
```

## Footer Component

```astro
---
// src/components/layout/footer.astro
const currentYear = new Date().getFullYear();

const footerLinks = [
  {
    heading: "Company",
    links: [
      { href: "/about", label: "About" },
      { href: "/contact", label: "Contact" },
    ],
  },
  {
    heading: "Resources",
    links: [
      { href: "/blog", label: "Blog" },
    ],
  },
];
---
<footer class="border-t border-gray-200 dark:border-gray-800 bg-gray-50 dark:bg-gray-950">
  <div class="max-w-6xl mx-auto px-6 py-12">
    <div class="grid gap-8 md:grid-cols-3">
      <!-- Brand -->
      <div>
        <p class="text-lg font-bold">Your Site Name</p>
        <p class="text-sm text-gray-600 dark:text-gray-400 mt-2">
          Building formal verification tools for the next generation of software.
        </p>
      </div>

      <!-- Link columns -->
      {footerLinks.map((column) => (
        <div>
          <h2 class="text-sm font-semibold uppercase tracking-wider text-gray-500 dark:text-gray-400">
            {column.heading}
          </h2>
          <nav aria-label={`${column.heading} links`} class="mt-3">
            <ul class="space-y-2">
              {column.links.map((link) => (
                <li>
                  <a
                    href={link.href}
                    class="text-sm text-gray-600 dark:text-gray-400 hover:text-primary transition-colors"
                  >
                    {link.label}
                  </a>
                </li>
              ))}
            </ul>
          </nav>
        </div>
      ))}
    </div>

    <!-- Copyright -->
    <div class="border-t border-gray-200 dark:border-gray-800 mt-8 pt-8 text-center">
      <p class="text-sm text-gray-500 dark:text-gray-400">
        &copy; {currentYear} Your Site Name. All rights reserved.
      </p>
    </div>
  </div>
</footer>
```

## Header Component

```astro
---
// src/components/layout/header.astro
import Nav from './nav.astro';
import ThemeToggle from '../ui/theme-toggle.astro';
---
<header class="sticky top-0 z-40 w-full border-b border-gray-200 dark:border-gray-800 bg-white/80 dark:bg-gray-950/80 backdrop-blur-sm">
  <div class="flex items-center justify-between max-w-6xl mx-auto px-6 h-16">
    <a href="/" class="text-lg font-bold hover:text-primary transition-colors">
      Brand
    </a>
    <div class="flex items-center gap-4">
      <Nav />
      <ThemeToggle />
    </div>
  </div>
</header>
```
