# Accessibility Patterns

Implementation patterns for WCAG 2.2 AA compliance in Astro sites.

## Semantic HTML Structure

Use semantic elements to convey document structure to assistive technologies:

```html
<body>
  <a href="#main-content" class="skip-link">Skip to main content</a>

  <header>
    <nav aria-label="Main navigation">
      <!-- Primary navigation -->
    </nav>
  </header>

  <main id="main-content">
    <article>
      <h1>Page Title</h1>
      <section aria-labelledby="intro-heading">
        <h2 id="intro-heading">Introduction</h2>
        <p>Content...</p>
      </section>
    </article>
  </main>

  <aside aria-label="Related content">
    <!-- Sidebar -->
  </aside>

  <footer>
    <nav aria-label="Footer navigation">
      <!-- Footer links -->
    </nav>
  </footer>
</body>
```

### Semantic Element Reference

| Element | Purpose | Notes |
|---------|---------|-------|
| `<header>` | Page or section header | One per page at top level |
| `<nav>` | Navigation section | Use `aria-label` when multiple navs |
| `<main>` | Primary content | Exactly one per page |
| `<article>` | Self-contained content | Blog posts, cards |
| `<section>` | Thematic grouping | Use with heading or `aria-labelledby` |
| `<aside>` | Tangentially related | Sidebars, call-outs |
| `<footer>` | Page or section footer | Copyright, links |
| `<figure>` + `<figcaption>` | Image with caption | Diagrams, code listings |

## Skip Navigation Link

Allows keyboard users to skip past repeated navigation:

```astro
<!-- In BaseLayout.astro, first child of <body> -->
<a
  href="#main-content"
  class="skip-link"
>
  Skip to main content
</a>

<!-- Target element -->
<main id="main-content" tabindex="-1">
  <!-- tabindex="-1" allows programmatic focus -->
</main>
```

```css
/* CSS for skip link */
.skip-link {
  position: absolute;
  top: -100%;
  left: 50%;
  transform: translateX(-50%);
  padding: 0.75rem 1.5rem;
  background: var(--color-primary);
  color: white;
  border-radius: 0 0 0.5rem 0.5rem;
  z-index: 100;
  font-weight: 600;
}

.skip-link:focus {
  top: 0;
}
```

## Heading Hierarchy

Always maintain a logical heading order. Never skip levels:

```html
<!-- Correct -->
<h1>Page Title</h1>
  <h2>Section</h2>
    <h3>Subsection</h3>
    <h3>Subsection</h3>
  <h2>Section</h2>

<!-- Incorrect: skips h2 -->
<h1>Page Title</h1>
  <h3>Section</h3>
```

**Rules**:
- Exactly one `<h1>` per page
- Headings never skip levels (h1 -> h2 -> h3, not h1 -> h3)
- Use headings for structure, not for visual styling
- Use Tailwind classes for visual sizing: `<h2 class="text-lg">` not `<h3>` for a smaller heading

## Image Accessibility

### Informative Images

```html
<!-- Descriptive alt text -->
<img src="/team-photo.jpg" alt="The team at the 2026 conference" />

<!-- Complex images with long descriptions -->
<figure>
  <img src="/architecture-diagram.svg" alt="System architecture showing three layers: client, API, and database" />
  <figcaption>Figure 1: System architecture overview</figcaption>
</figure>
```

### Decorative Images

```html
<!-- Empty alt for purely decorative images -->
<img src="/decorative-pattern.svg" alt="" />

<!-- Or use aria-hidden -->
<img src="/decorative-divider.svg" alt="" aria-hidden="true" />
```

### Icon Accessibility

```html
<!-- Icon with visible label: hide icon from screen readers -->
<button>
  <svg aria-hidden="true" class="w-5 h-5"><!-- icon --></svg>
  <span>Search</span>
</button>

<!-- Icon-only button: provide accessible label -->
<button aria-label="Close dialog">
  <svg aria-hidden="true" class="w-5 h-5"><!-- X icon --></svg>
</button>
```

## Focus Management

### Visible Focus Indicators (WCAG 2.4.7)

```css
/* Global focus style */
:focus-visible {
  outline: 2px solid var(--color-primary);
  outline-offset: 2px;
}

/* Remove default focus ring, rely on :focus-visible */
:focus:not(:focus-visible) {
  outline: none;
}
```

```html
<!-- Tailwind focus utilities -->
<a href="/page" class="focus-visible:outline-2 focus-visible:outline-primary focus-visible:outline-offset-2">
  Link text
</a>

<button class="focus-visible:ring-2 focus-visible:ring-primary focus-visible:ring-offset-2">
  Button text
</button>
```

### Focus Not Obscured (WCAG 2.4.11)

Ensure focused elements are not fully hidden behind sticky headers or modals:

```css
/* Account for sticky header height */
:target {
  scroll-margin-top: 5rem; /* height of sticky nav */
}

/* Focus within scrollable regions */
[tabindex]:focus {
  scroll-margin: 1rem;
}
```

## Keyboard Navigation

Prefer `<a>` and `<button>` over `<div>` with click handlers. Native elements have built-in keyboard support.

```html
<!-- Native elements: keyboard accessible by default -->
<a href="/page">Link</a>
<button type="button">Action</button>
```

### Tab Order

- Natural tab order follows DOM order
- `tabindex="0"`: add to tab order
- `tabindex="-1"`: programmatic focus only (dialogs, targets)
- Never use `tabindex > 0` (disrupts natural order)

## ARIA Attributes

### When to Use ARIA

**First rule of ARIA**: Do not use ARIA if a native HTML element has the semantics you need.

```html
<!-- Bad: redundant ARIA -->
<nav role="navigation">  <!-- <nav> already has navigation role -->

<!-- Good: native semantics -->
<nav aria-label="Main navigation">
```

### Common ARIA Patterns

```html
<!-- Current page in navigation -->
<a href="/about" aria-current="page">About</a>

<!-- Expanded/collapsed state -->
<button aria-expanded="false" aria-controls="menu">Menu</button>
<ul id="menu" hidden><!-- items --></ul>

<!-- Loading state -->
<div aria-live="polite" aria-busy="true">Loading...</div>

<!-- Required form fields -->
<input type="email" aria-required="true" aria-describedby="email-help" />
<span id="email-help">We will never share your email.</span>

<!-- Error messages -->
<input type="email" aria-invalid="true" aria-describedby="email-error" />
<span id="email-error" role="alert">Please enter a valid email address.</span>
```

## Form Accessibility

```html
<form>
  <div>
    <label for="name">Full Name <span aria-hidden="true">*</span></label>
    <input type="text" id="name" name="name" required aria-required="true" autocomplete="name" />
  </div>
  <div>
    <label for="email">Email <span aria-hidden="true">*</span></label>
    <input type="email" id="email" name="email" required aria-required="true" aria-describedby="email-hint" autocomplete="email" />
    <span id="email-hint" class="text-sm text-gray-500">We'll use this to respond.</span>
  </div>
  <button type="submit">Send Message</button>
</form>
```

**Rules**:
- Every input has a `<label>` with matching `for`/`id`
- Use `autocomplete` attributes (WCAG 1.3.5)
- Mark required fields with `required` and `aria-required="true"`
- Connect help text via `aria-describedby`

## Color Contrast

### Minimum Ratios (WCAG 1.4.3)

| Text Type | Minimum Ratio |
|-----------|--------------|
| Normal text (< 18pt / < 14pt bold) | 4.5:1 |
| Large text (>= 18pt / >= 14pt bold) | 3:1 |
| UI components and graphics | 3:1 |

### Do Not Rely on Color Alone

```html
<!-- Bad: color is the only indicator -->
<span class="text-red-500">Error occurred</span>

<!-- Good: icon + text + color -->
<span class="text-red-500" role="alert">
  <svg aria-hidden="true"><!-- error icon --></svg>
  Error: Please enter a valid email address.
</span>
```

## Touch Target Size (WCAG 2.5.8)

Interactive elements must be at least 24x24 CSS pixels (44x44 recommended). Use padding on inline links: `nav a { padding: 0.5rem 1rem; }`.

## Live Regions

Announce dynamic content changes to screen readers:

```html
<!-- Status messages -->
<div aria-live="polite" aria-atomic="true">
  <!-- Content changes are announced after current speech -->
  Form submitted successfully.
</div>

<!-- Urgent alerts -->
<div aria-live="assertive" role="alert">
  <!-- Immediately interrupts screen reader -->
  Session expired. Please log in again.
</div>
```
