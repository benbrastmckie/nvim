# Tailwind CSS v4 Guide

**Scope**: Tailwind CSS v4 with CSS-first configuration

## Configuration

No `tailwind.config.js` needed. Use CSS-first approach:

```css
/* src/styles/global.css */
@import "tailwindcss";

@theme {
  --color-primary: #4a90d9;
  --color-secondary: #6c757d;
  --font-family-display: "Inter", sans-serif;
}
```

## Class Ordering

Follow box-model order:

1. **Layout**: `flex`, `grid`, `relative`, `absolute`, `z-*`
2. **Sizing**: `w-*`, `h-*`, `min-w-*`, `max-w-*`
3. **Spacing**: `p-*`, `m-*`, `gap-*`
4. **Typography**: `text-*`, `font-*`, `leading-*`
5. **Visual**: `bg-*`, `border-*`, `rounded-*`, `shadow-*`
6. **Interactive**: `cursor-*`, `transition-*`, `hover:*`, `focus:*`
7. **Responsive**: `sm:*`, `md:*`, `lg:*`
8. **Dark mode**: `dark:*`

## Example

```html
<!-- Good: follows box-model order -->
<div
  class="relative z-10 flex h-64 w-full gap-2 bg-blue-500 p-4 text-lg font-semibold hover:bg-blue-600 md:p-6"
>
  <!-- Bad: random order -->
  <div
    class="relative z-10 flex h-64 w-full gap-2 bg-blue-500 p-4 text-lg font-semibold hover:bg-blue-600 md:p-6"
  ></div>
</div>
```

## Responsive Design

Mobile-first approach:

```html
<!-- Base styles apply to mobile, md: applies to 768px+ -->
<div class="w-full px-4 md:px-6 lg:px-8"></div>
```

## Dark Mode

```html
<div class="bg-white text-black dark:bg-gray-900 dark:text-white"></div>
```

## Custom Theme Values

```css
@theme {
  /* Colors */
  --color-brand: #007bff;

  /* Fonts */
  --font-family-sans: "Inter", system-ui, sans-serif;

  /* Spacing */
  --spacing-18: 4.5rem;

  /* Breakpoints */
  --breakpoint-3xl: 120rem;
}
```

## Utility Classes

Common patterns:

```html
<!-- Container -->
<div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
  <!-- Card -->
  <div class="rounded-lg bg-white p-6 shadow-md">
    <!-- Button -->
    <button class="rounded bg-blue-500 px-4 py-2 text-white hover:bg-blue-600 disabled:opacity-50">
      <!-- Flex center -->
      <div class="flex items-center justify-center">
        <!-- Grid -->
        <div class="grid grid-cols-1 gap-4 md:grid-cols-2 lg:grid-cols-3"></div>
      </div>
    </button>
  </div>
</div>
```

## Key Differences from v3

- No `tailwind.config.js` - use `@theme` in CSS
- Automatic content detection (no `content` array)
- Use `@import "tailwindcss"` instead of directives
- Class ordering enforced by prettier-plugin-tailwindcss
