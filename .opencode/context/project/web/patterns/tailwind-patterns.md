# Tailwind CSS UI Patterns

Common layout and component patterns using Tailwind CSS v4 utilities.

## Layout Patterns

### Centered Container

```html
<div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
  <!-- Content constrained to max width, centered, with responsive padding -->
</div>
```

### Narrow Content Container

```html
<div class="max-w-3xl mx-auto px-4">
  <!-- For prose/article content, narrower for readability -->
</div>
```

### Full-Bleed with Constrained Content

```html
<section class="bg-primary text-white">
  <div class="max-w-6xl mx-auto px-4 py-16">
    <!-- Full-width background, constrained content -->
  </div>
</section>
```

### Two-Column Layout

```html
<div class="max-w-6xl mx-auto px-4 grid md:grid-cols-[1fr_300px] gap-8">
  <main>
    <!-- Main content -->
  </main>
  <aside>
    <!-- Sidebar -->
  </aside>
</div>
```

## Navigation Bar

### Desktop Navigation

```astro
---
const navItems = [
  { label: 'Home', href: '/' },
  { label: 'About', href: '/about' },
  { label: 'Blog', href: '/blog' },
  { label: 'Contact', href: '/contact' },
];
const currentPath = Astro.url.pathname;
---

<header class="sticky top-0 z-50 bg-white/80 dark:bg-gray-900/80 backdrop-blur-md border-b border-gray-200 dark:border-gray-800">
  <nav class="max-w-6xl mx-auto px-4 flex items-center justify-between h-16" aria-label="Main navigation">
    <a href="/" class="text-xl font-heading font-bold">
      Your Site
    </a>
    <ul class="hidden md:flex items-center gap-6">
      {navItems.map((item) => (
        <li>
          <a
            href={item.href}
            class:list={[
              'text-sm font-medium transition-colors hover:text-primary',
              currentPath === item.href
                ? 'text-primary'
                : 'text-gray-600 dark:text-gray-300',
            ]}
            aria-current={currentPath === item.href ? 'page' : undefined}
          >
            {item.label}
          </a>
        </li>
      ))}
    </ul>
  </nav>
</header>
```

## Hero Section

### Centered Hero

```html
<section class="py-24 md:py-32 text-center">
  <div class="max-w-4xl mx-auto px-4">
    <h1 class="text-4xl md:text-5xl lg:text-6xl font-heading font-bold tracking-tight">
      Building the Future of
      <span class="text-primary">Your Product</span>
    </h1>
    <p class="mt-6 text-lg md:text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto">
      Your tagline and value proposition goes here.
    </p>
    <div class="mt-10 flex flex-col sm:flex-row items-center justify-center gap-4">
      <a href="/products" class="btn btn-primary">Get Started</a>
      <a href="/about" class="btn btn-ghost">Learn More</a>
    </div>
  </div>
</section>
```

### Split Hero (Text + Image)

```html
<section class="py-20">
  <div class="max-w-6xl mx-auto px-4 grid md:grid-cols-2 gap-12 items-center">
    <div>
      <h1 class="text-4xl md:text-5xl font-heading font-bold tracking-tight">
        Title Text Here
      </h1>
      <p class="mt-6 text-lg text-gray-600 dark:text-gray-400">
        Supporting description text.
      </p>
      <div class="mt-8">
        <a href="/cta" class="btn btn-primary">Get Started</a>
      </div>
    </div>
    <div class="relative">
      <img src="/hero.jpg" alt="Description" class="rounded-lg shadow-lg" />
    </div>
  </div>
</section>
```

## Card Component

```html
<article class="group rounded-card bg-white dark:bg-gray-800 shadow-sm hover:shadow-md transition-shadow border border-gray-200 dark:border-gray-700 overflow-hidden">
  <div class="aspect-video overflow-hidden">
    <img
      src="/card-image.jpg"
      alt="Description"
      class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
    />
  </div>
  <div class="p-6">
    <h3 class="text-lg font-heading font-semibold">Card Title</h3>
    <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
      Card description text that provides context.
    </p>
    <a href="/link" class="mt-4 inline-flex items-center text-sm font-medium text-primary hover:underline">
      Read more
      <svg class="ml-1 w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
      </svg>
    </a>
  </div>
</article>
```

### Card Grid

```html
<div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
  <!-- Card components here -->
</div>
```

## Responsive Patterns

### Show/Hide by Breakpoint

```html
<!-- Hidden on mobile, visible on md+ -->
<nav class="hidden md:flex">Desktop nav</nav>

<!-- Visible on mobile, hidden on md+ -->
<button class="md:hidden">Menu</button>
```

### Responsive Typography

```html
<h1 class="text-3xl sm:text-4xl md:text-5xl lg:text-6xl font-bold">
  Responsive Heading
</h1>
<p class="text-base md:text-lg lg:text-xl">
  Body text that scales up on larger screens.
</p>
```

### Responsive Spacing

```html
<section class="py-12 md:py-16 lg:py-24">
  <div class="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8">
    <div class="grid gap-6 md:gap-8 lg:gap-12">
      <!-- Items -->
    </div>
  </div>
</section>
```

## Dark Mode Toggle

```css
/* In global.css */
@import "tailwindcss";
@variant dark (&:where(.dark, .dark *));
```

```html
<button
  id="theme-toggle"
  class="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-800"
  aria-label="Toggle dark mode"
>
  <!-- Sun icon (shown in dark mode) -->
  <svg class="hidden dark:block w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
    <!-- sun path -->
  </svg>
  <!-- Moon icon (shown in light mode) -->
  <svg class="block dark:hidden w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
    <!-- moon path -->
  </svg>
</button>
```

## Footer

```html
<footer class="bg-gray-50 dark:bg-gray-900 border-t border-gray-200 dark:border-gray-800">
  <div class="max-w-6xl mx-auto px-4 py-12">
    <div class="grid grid-cols-1 md:grid-cols-4 gap-8">
      <!-- Brand -->
      <div class="md:col-span-1">
        <span class="text-lg font-heading font-bold">Your Site</span>
        <p class="mt-2 text-sm text-gray-600 dark:text-gray-400">
          Building great web experiences.
        </p>
      </div>

      <!-- Link columns -->
      <div>
        <h3 class="text-sm font-semibold uppercase tracking-wider">Products</h3>
        <ul class="mt-4 space-y-2">
          <li><a href="/products" class="text-sm text-gray-600 dark:text-gray-400 hover:text-primary">Overview</a></li>
          <li><a href="/pricing" class="text-sm text-gray-600 dark:text-gray-400 hover:text-primary">Pricing</a></li>
        </ul>
      </div>
      <div>
        <h3 class="text-sm font-semibold uppercase tracking-wider">Company</h3>
        <ul class="mt-4 space-y-2">
          <li><a href="/about" class="text-sm text-gray-600 dark:text-gray-400 hover:text-primary">About</a></li>
          <li><a href="/contact" class="text-sm text-gray-600 dark:text-gray-400 hover:text-primary">Contact</a></li>
        </ul>
      </div>
      <div>
        <h3 class="text-sm font-semibold uppercase tracking-wider">Legal</h3>
        <ul class="mt-4 space-y-2">
          <li><a href="/privacy" class="text-sm text-gray-600 dark:text-gray-400 hover:text-primary">Privacy</a></li>
          <li><a href="/terms" class="text-sm text-gray-600 dark:text-gray-400 hover:text-primary">Terms</a></li>
        </ul>
      </div>
    </div>

    <div class="mt-12 pt-8 border-t border-gray-200 dark:border-gray-800 text-center text-sm text-gray-500">
      &copy; {new Date().getFullYear()} Your Organization. All rights reserved.
    </div>
  </div>
</footer>
```

## Button Styles

Define reusable button classes in global CSS:

```css
/* src/styles/global.css */
@import "tailwindcss";

@layer components {
  .btn {
    @apply inline-flex items-center justify-center px-6 py-3 rounded-button text-sm font-medium transition-colors focus-visible:outline-2 focus-visible:outline-offset-2;
  }
  .btn-primary {
    @apply bg-primary text-white hover:bg-primary/90 focus-visible:outline-primary;
  }
  .btn-secondary {
    @apply bg-secondary text-white hover:bg-secondary/90 focus-visible:outline-secondary;
  }
  .btn-ghost {
    @apply bg-transparent border border-gray-300 dark:border-gray-700 hover:bg-gray-100 dark:hover:bg-gray-800;
  }
  .btn-sm {
    @apply px-4 py-2 text-xs;
  }
  .btn-lg {
    @apply px-8 py-4 text-base;
  }
}
```
