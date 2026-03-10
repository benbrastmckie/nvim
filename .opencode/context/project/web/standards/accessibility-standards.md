# Accessibility Standards

WCAG 2.2 AA compliance requirements for the website.

## POUR Principles

| Principle | Meaning | Key Question |
|-----------|---------|--------------|
| **Perceivable** | Content can be perceived by all users | Can everyone see/hear/read the content? |
| **Operable** | Interface can be operated by all users | Can everyone navigate and interact? |
| **Understandable** | Content and UI are understandable | Can everyone comprehend the content and UI? |
| **Robust** | Content works with assistive technologies | Does it work with screen readers and other tools? |

## Color Contrast Requirements

### Minimum Ratios (AA Level)

| Element | Ratio | Example |
|---------|-------|---------|
| Normal text (< 18pt / < 14pt bold) | 4.5:1 | Body text, labels, links |
| Large text (>= 18pt / >= 14pt bold) | 3:1 | Headings, large buttons |
| UI components and graphics | 3:1 | Icons, form borders, focus indicators |
| Decorative elements | N/A | Brand logos, purely decorative images |

### Implementation

```css
@theme {
  /* Verify all color pairings meet contrast ratios */
  --color-text-primary: oklch(0.20 0.02 260);     /* Dark on light: 12:1+ */
  --color-text-secondary: oklch(0.40 0.02 260);   /* Dark on light: 5.5:1+ */
  --color-bg-primary: oklch(0.99 0.00 0);         /* Light background */
  --color-link: oklch(0.45 0.15 260);             /* Must meet 4.5:1 on bg */
  --color-link-hover: oklch(0.35 0.18 260);       /* Must meet 4.5:1 on bg */
}
```

### Testing

```bash
# Use Lighthouse accessibility audit
pnpm exec lighthouse http://localhost:4321 --only-categories=accessibility

# Use axe-core in browser dev tools
# Chrome DevTools > Lighthouse > Accessibility
```

## Touch Target Sizes

### WCAG 2.5.8: Target Size (Minimum) -- AA

- Interactive targets must be at least **24 x 24 CSS pixels**
- Exceptions: inline text links, browser-default controls, where size is essential

```css
/* Ensure minimum touch target size */
button, a[role="button"], [role="tab"] {
  min-width: 24px;
  min-height: 24px;
}

/* Better: use 44x44 for comfortable touch targets */
.nav-link {
  min-width: 44px;
  min-height: 44px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
```

## Required HTML Attributes

### Images

Every `<img>` must have an `alt` attribute:

```html
<!-- Informative image: descriptive alt -->
<img src="/team/alice.jpg" alt="Alice Chen, Lead Researcher" />

<!-- Decorative image: empty alt -->
<img src="/decorative-line.svg" alt="" role="presentation" />

<!-- Complex image: link to full description -->
<img src="/chart.png" alt="Revenue growth chart" aria-describedby="chart-desc" />
<p id="chart-desc">Revenue grew 45% year over year from 2024 to 2025.</p>
```

### Language

Set the page language on the `<html>` element:

```html
<html lang="en">
```

### Page Title

Every page must have a unique, descriptive `<title>`:

```astro
<title>{pageTitle} | Your Organization</title>
```

## Heading Hierarchy

### Rules

- Exactly one `<h1>` per page
- No skipping levels (h1 -> h2 -> h3, never h1 -> h3)
- Headings must describe the content that follows

```html
<!-- Good -->
<h1>About Your Organization</h1>
  <h2>Our Mission</h2>
  <h2>Our Team</h2>
    <h3>Leadership</h3>
    <h3>Research Staff</h3>

<!-- Bad: skipped h2 -->
<h1>About Your Organization</h1>
  <h3>Our Mission</h3>
```

## Keyboard Navigation

### Requirements

- All interactive elements must be reachable via Tab key
- Focus order must match visual order (left-to-right, top-to-bottom)
- Custom components must handle Enter/Space for activation
- No keyboard traps (user can always Tab away)

### Focus Indicators

WCAG 2.4.7 (Focus Visible) and 2.4.11 (Focus Not Obscured):

```css
/* Visible focus indicator */
:focus-visible {
  outline: 3px solid var(--color-primary);
  outline-offset: 2px;
}

/* Remove default outline only when custom focus is applied */
:focus:not(:focus-visible) {
  outline: none;
}
```

### Skip Navigation

Every page must include a skip-to-content link:

```astro
<body>
  <a href="#main-content" class="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-50 focus:px-4 focus:py-2 focus:bg-white focus:text-black focus:rounded">
    Skip to main content
  </a>
  <header><!-- navigation --></header>
  <main id="main-content">
    <slot />
  </main>
</body>
```

## Semantic HTML

### Landmark Elements

Use semantic elements for page structure:

| Element | Purpose | ARIA Equivalent |
|---------|---------|-----------------|
| `<header>` | Site/section header | `role="banner"` |
| `<nav>` | Navigation links | `role="navigation"` |
| `<main>` | Primary content | `role="main"` |
| `<aside>` | Supplementary content | `role="complementary"` |
| `<footer>` | Site/section footer | `role="contentinfo"` |
| `<article>` | Self-contained content | `role="article"` |
| `<section>` | Thematic grouping | `role="region"` |

```html
<body>
  <header>
    <nav aria-label="Main navigation"><!-- links --></nav>
  </header>
  <main id="main-content">
    <article>
      <h1>Page Title</h1>
      <!-- content -->
    </article>
  </main>
  <footer>
    <nav aria-label="Footer navigation"><!-- links --></nav>
  </footer>
</body>
```

## WCAG 2.2 New Criteria (AA Level)

### 2.4.11 Focus Not Obscured (Minimum)

When an element receives keyboard focus, it must not be entirely hidden by other content (e.g., sticky headers, cookie banners).

```css
/* Ensure sticky header does not cover focused elements */
:target {
  scroll-margin-top: 80px; /* Height of sticky header */
}
```

### 2.5.7 Dragging Movements

Any functionality that uses dragging must also be operable with a single pointer without dragging (e.g., click/tap alternatives).

### 2.5.8 Target Size (Minimum)

Interactive targets must be at least 24x24 CSS pixels (see Touch Target Sizes above).

### 3.2.6 Consistent Help

If a help mechanism exists, it must appear in the same relative location across pages.

### 3.3.7 Redundant Entry

Information previously entered by the user must be auto-populated or selectable (do not force re-entry).

### 3.3.8 Accessible Authentication (Minimum)

Authentication must not require cognitive function tests (e.g., solving puzzles, remembering passwords). Allow password managers and paste.

```html
<!-- Good: allows password managers -->
<input type="password" autocomplete="current-password" />

<!-- Bad: blocks paste -->
<input type="password" onpaste="return false" />
```

## Form Accessibility

### Labels

Every form input must have an associated label:

```html
<!-- Explicit label (preferred) -->
<label for="email">Email address</label>
<input type="email" id="email" name="email" required />

<!-- Error messages linked to input -->
<input type="email" id="email" aria-describedby="email-error" aria-invalid="true" />
<p id="email-error" role="alert">Please enter a valid email address.</p>
```

### Required Fields

Indicate required fields both visually and programmatically:

```html
<label for="name">
  Name <span aria-hidden="true">*</span>
  <span class="sr-only">(required)</span>
</label>
<input type="text" id="name" required aria-required="true" />
```

## Testing Checklist

### Automated

- [ ] Lighthouse accessibility score >= 95
- [ ] axe-core reports zero violations
- [ ] HTML validator: no errors
- [ ] All images have alt attributes
- [ ] All form inputs have labels
- [ ] Color contrast ratios pass

### Manual

- [ ] Tab through page -- all interactive elements reachable
- [ ] Focus indicators visible on every focused element
- [ ] Skip navigation link works
- [ ] Heading hierarchy is logical
- [ ] Page usable at 200% zoom and 400% text zoom
- [ ] No horizontal scrolling at 320px viewport width
- [ ] Screen reader: landmarks, headings, images, links, forms announced correctly

### Tools

| Tool | Type | Coverage |
|------|------|----------|
| Lighthouse | Automated | ~30-40% of WCAG criteria |
| axe-core / axe DevTools | Automated | ~30-40% of WCAG criteria |
| WAVE | Semi-automated | Visual overlay of issues |
| VoiceOver / NVDA / Orca | Manual | Full screen reader testing |
| Keyboard-only navigation | Manual | Operability testing |
