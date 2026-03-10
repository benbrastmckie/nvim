# Astro Component Patterns

Common patterns for building Astro components.

## Basic Component

```astro
---
// src/components/Greeting.astro
interface Props {
  name: string;
}

const { name } = Astro.props;
---

<h2>Hello, {name}!</h2>
```

Usage:

```astro
<Greeting name="World" />
```

## Props with Defaults and Variants

```astro
---
// src/components/Button.astro
interface Props {
  variant?: 'primary' | 'secondary' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  href?: string;
  disabled?: boolean;
}

const {
  variant = 'primary',
  size = 'md',
  href,
  disabled = false,
} = Astro.props;

const Tag = href ? 'a' : 'button';
---

<Tag
  href={href}
  disabled={!href && disabled}
  class:list={[
    'btn',
    `btn-${variant}`,
    `btn-${size}`,
    { 'btn-disabled': disabled },
  ]}
>
  <slot />
</Tag>
```

## Slots

### Default Slot

```astro
---
// src/components/Card.astro
interface Props {
  title: string;
}

const { title } = Astro.props;
---

<div class="card">
  <h3>{title}</h3>
  <div class="card-body">
    <slot />
  </div>
</div>
```

```astro
<Card title="Features">
  <p>This goes into the default slot.</p>
</Card>
```

### Named Slots

```astro
---
// src/components/PageSection.astro
interface Props {
  title: string;
}

const { title } = Astro.props;
---

<section class="py-16">
  <div class="container mx-auto px-4">
    <h2 class="text-3xl font-heading font-bold mb-4">{title}</h2>
    <div class="mb-8">
      <slot name="description" />
    </div>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
      <slot />
    </div>
    {Astro.slots.has('cta') && (
      <div class="mt-8 text-center">
        <slot name="cta" />
      </div>
    )}
  </div>
</section>
```

```astro
<PageSection title="Our Services">
  <p slot="description">What we offer.</p>

  <Card title="Research" />
  <Card title="Development" />
  <Card title="Consulting" />

  <a slot="cta" href="/contact" class="btn btn-primary">Get Started</a>
</PageSection>
```

### Checking for Slot Content

```astro
---
const hasFooter = Astro.slots.has('footer');
const hasActions = Astro.slots.has('actions');
---

<div class="panel">
  <slot />
  {hasActions && (
    <div class="panel-actions">
      <slot name="actions" />
    </div>
  )}
  {hasFooter && (
    <footer class="panel-footer">
      <slot name="footer" />
    </footer>
  )}
</div>
```

## Conditional Rendering

```astro
---
interface Props {
  title: string;
  subtitle?: string;
  badge?: string;
  showDivider?: boolean;
}

const { title, subtitle, badge, showDivider = false } = Astro.props;
---

<div>
  {badge && <span class="badge">{badge}</span>}
  <h2>{title}</h2>
  {subtitle && <p class="text-muted">{subtitle}</p>}
  {showDivider && <hr />}
</div>
```

## List Rendering

```astro
---
interface Props {
  items: { title: string; href: string; active?: boolean }[];
}

const { items } = Astro.props;
---

<nav>
  <ul>
    {items.map((item) => (
      <li>
        <a
          href={item.href}
          class:list={[
            'nav-link',
            { 'nav-link-active': item.active },
          ]}
          aria-current={item.active ? 'page' : undefined}
        >
          {item.title}
        </a>
      </li>
    ))}
  </ul>
</nav>
```

## Client Directives (Islands)

Only framework components (React, Svelte, Vue) support client directives. Astro components are always static.

### When to Use Each Directive

```astro
---
import SearchDialog from '../components/SearchDialog.tsx';
import Newsletter from '../components/Newsletter.tsx';
import Analytics from '../components/Analytics.tsx';
import MobileDrawer from '../components/MobileDrawer.tsx';
---

<!-- Critical: user interacts immediately -->
<SearchDialog client:load />

<!-- Not urgent: loads after page is idle -->
<Newsletter client:idle />

<!-- Lazy: loads when scrolled into view -->
<Analytics client:visible />

<!-- Conditional: only on small screens -->
<MobileDrawer client:media="(max-width: 768px)" />
```

**Rule**: Default to no directive (static). Use `client:load` only when immediate interaction is needed. Use `client:visible` for below-fold interactive content.

## Component Composition

### Wrapper Pattern

```astro
---
// src/components/Container.astro
interface Props {
  as?: 'div' | 'section' | 'article' | 'main';
  class?: string;
  narrow?: boolean;
}

const { as: Tag = 'div', class: className, narrow = false } = Astro.props;
---

<Tag class:list={[
  'mx-auto px-4',
  narrow ? 'max-w-3xl' : 'max-w-6xl',
  className,
]}>
  <slot />
</Tag>
```

### Spread Attributes

```astro
---
import type { HTMLAttributes } from 'astro/types';

interface Props extends HTMLAttributes<'div'> {
  variant?: 'default' | 'highlighted';
}

const { variant = 'default', ...rest } = Astro.props;
---

<div class:list={['component', `variant-${variant}`]} {...rest}>
  <slot />
</div>
```

## class:list Directive

Astro's built-in way to conditionally apply classes:

```astro
---
const isActive = true;
const variant = 'primary';
---

<div class:list={[
  'base-class',                    // Always applied
  `variant-${variant}`,            // Template literal
  { 'is-active': isActive },       // Conditional object
  isActive && 'another-class',     // Conditional expression
  ['array', 'of', 'classes'],      // Array of strings
]}>
  Content
</div>
<!-- Renders: class="base-class variant-primary is-active another-class array of classes" -->
```

## Scoped Styles

Styles in `<style>` tags are scoped to the component by default:

```astro
<div class="wrapper"><h2>Title</h2></div>
<style>
  .wrapper { padding: 1rem; }
  h2 { color: var(--color-primary); }
</style>
```

Use `<style is:global>` for styles that should apply globally (e.g., prose content).
