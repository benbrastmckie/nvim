# Web Context

Domain knowledge for web project development with Astro, Tailwind CSS v4, and Cloudflare Pages.

## Directory Structure

```
project/web/
├── README.md                           # This file
├── domain/                             # Core technology concepts
│   ├── astro-framework.md              # Astro 5/6 framework reference
│   ├── tailwind-v4.md                  # Tailwind CSS v4 CSS-first config
│   ├── cloudflare-pages.md             # Cloudflare Pages deployment
│   └── typescript-web.md               # TypeScript in Astro projects
├── patterns/                           # Common implementation patterns
│   ├── astro-component.md              # Component structure and props
│   ├── astro-layout.md                 # Layout patterns and head management
│   ├── astro-content-collections.md    # Content collections and Zod schemas
│   ├── tailwind-patterns.md            # UI component patterns
│   └── accessibility-patterns.md       # Semantic HTML, ARIA, keyboard nav
├── standards/                          # Coding conventions and targets
│   ├── web-style-guide.md              # Naming, structure, conventions
│   ├── performance-standards.md        # Core Web Vitals targets
│   └── accessibility-standards.md      # WCAG 2.2 AA compliance
├── tools/                              # Tool-specific guides
│   ├── astro-cli-guide.md              # Astro CLI commands
│   ├── cicd-pipeline-guide.md          # GitLab CI/CD and deployment debugging
│   ├── cloudflare-deploy-guide.md      # Wrangler deployment workflow
│   ├── debugging-utilities.md          # CLI debugging and optimization tools
│   └── pnpm-guide.md                   # pnpm package manager
└── templates/                          # Boilerplate templates
    ├── astro-page-template.md          # Page boilerplate variations
    └── astro-component-template.md     # Component boilerplate variations
```

## Loading Strategy

**Always load first**:
- This README for overview
- `domain/astro-framework.md` for .astro file format and islands architecture

**Load for component work**:
- `patterns/astro-component.md` for props, slots, client directives
- `templates/astro-component-template.md` for boilerplate

**Load for layout/page work**:
- `patterns/astro-layout.md` for BaseLayout, nested layouts, head management
- `templates/astro-page-template.md` for page boilerplate

**Load for content/blog work**:
- `patterns/astro-content-collections.md` for defineCollection, querying
- `domain/typescript-web.md` for Zod schemas and type utilities

**Load for styling work**:
- `domain/tailwind-v4.md` for @theme config and utility classes
- `patterns/tailwind-patterns.md` for layout and UI patterns

**Load for accessibility work**:
- `standards/accessibility-standards.md` for WCAG 2.2 AA requirements
- `patterns/accessibility-patterns.md` for implementation patterns

**Load for deployment work**:
- `domain/cloudflare-pages.md` for platform overview
- `tools/cloudflare-deploy-guide.md` for wrangler commands

**Load for CI/CD and deployment debugging**:
- `tools/cicd-pipeline-guide.md` for GitLab CI/CD, tag-triggered deployment, failure debugging

**Load for debugging and optimization**:
- `tools/debugging-utilities.md` for CLI tools (optipng, jpegoptim, httpie, dig, openssl)

## Configuration Assumptions

This context assumes:
- Astro 5 stable (Astro 6 notes where relevant)
- Tailwind CSS v4 with CSS-first configuration
- Cloudflare Pages for deployment
- TypeScript in strict mode
- pnpm as package manager
- Node.js 22+

## Key Concepts

### Islands Architecture
Astro ships zero JavaScript by default. Interactive components are hydrated selectively via client directives (`client:load`, `client:idle`, `client:visible`), creating "islands" of interactivity in a sea of static HTML.

### CSS-First Configuration
Tailwind v4 replaces JavaScript config with CSS directives. Use `@import "tailwindcss"` and `@theme { }` to define design tokens directly in CSS. No `tailwind.config.js` needed.

### Edge Deployment
Cloudflare Pages deploys to a global CDN with automatic SSL, preview deployments per branch, and optional Workers for server-side logic.

### Content Collections
Astro's type-safe content layer uses `defineCollection` with Zod schemas and file-based loaders. Query content with `getCollection()` and `getEntry()`.

## Agent Context Loading

Agents should load context based on task type:

| Task Type | Required Context |
|-----------|-----------------|
| New component | astro-component.md, astro-component-template.md |
| Page/layout | astro-layout.md, astro-page-template.md |
| Content/blog | astro-content-collections.md, typescript-web.md |
| Styling/UI | tailwind-v4.md, tailwind-patterns.md |
| Accessibility | accessibility-standards.md, accessibility-patterns.md |
| Deployment | cloudflare-pages.md, cloudflare-deploy-guide.md |
| CI/CD debugging | cicd-pipeline-guide.md, cloudflare-deploy-guide.md |
| Debugging/optimization | debugging-utilities.md |
| General | astro-framework.md, web-style-guide.md |
