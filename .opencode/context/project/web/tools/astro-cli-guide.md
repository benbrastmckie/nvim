# Astro CLI Guide

Command reference for the Astro CLI used in the website project.

## Core Commands

| Command | Description |
|---------|-------------|
| `astro dev` | Start development server |
| `astro build` | Build for production |
| `astro preview` | Preview production build locally |
| `astro check` | Run TypeScript type checking |
| `astro sync` | Generate content collection types |
| `astro add` | Add integrations and adapters |

## Development Server

```bash
# Start dev server (default: http://localhost:4321)
pnpm astro dev

# Custom port
pnpm astro dev --port 3000

# Expose to network (LAN access)
pnpm astro dev --host

# Open browser automatically
pnpm astro dev --open

# Verbose output for debugging
pnpm astro dev --verbose
```

### Dev Server Hotkeys

While the dev server is running:

| Key | Action |
|-----|--------|
| `h` | Show all hotkeys |
| `r` | Restart server |
| `u` | Show server URL |
| `o` | Open in browser |
| `c` | Clear console |
| `q` | Quit |

### Dev Server Features

- Hot Module Replacement (HMR) for instant updates
- Automatic content collection type generation
- TypeScript error overlay in browser
- CSS changes applied without full page reload

## Build

```bash
# Production build (output to dist/)
pnpm astro build

# With type checking first
pnpm astro check && pnpm astro build
```

### Build Output

```
dist/
├── _astro/           # Hashed assets (CSS, JS, images)
│   ├── index.D4f8k.css
│   └── hero.B3x2q.avif
├── index.html        # Pre-rendered pages
├── about/
│   └── index.html
└── blog/
    ├── index.html
    └── first-post/
        └── index.html
```

### Build Flags

| Flag | Description |
|------|-------------|
| `--verbose` | Show detailed build output |
| `--config <path>` | Use custom config file |
| `--root <path>` | Set project root directory |

## Preview

```bash
# Preview the production build locally
pnpm astro build && pnpm astro preview

# Custom port
pnpm astro preview --port 4000

# Expose to network
pnpm astro preview --host
```

Preview uses the actual build output, making it useful for testing performance and verifying SSG output matches expectations.

## Type Checking

```bash
# Check TypeScript types (uses astro check under the hood)
pnpm astro check

# Watch mode for continuous checking
pnpm astro check --watch
```

### What `astro check` Validates

- TypeScript types in `.astro` frontmatter
- Component prop types
- Content collection schema compliance
- Import path resolution
- Type-only imports

## Content Collection Sync

```bash
# Regenerate .astro/types.d.ts and content collection types
pnpm astro sync
```

Run `astro sync` when:
- Adding a new content collection
- Changing a collection schema in `content.config.ts`
- Content types seem stale in the editor

## Integration Management

### Adding Integrations

```bash
# Add Tailwind CSS integration
pnpm astro add tailwind

# Add Cloudflare adapter
pnpm astro add cloudflare

# Add sitemap generation
pnpm astro add sitemap

# Add multiple at once
pnpm astro add tailwind sitemap
```

The `astro add` command automatically:
1. Installs the npm package
2. Updates `astro.config.mjs` with the integration
3. Creates any required config files

### Manual Integration

If `astro add` does not support a package:

```bash
# Install manually
pnpm add @astrojs/rss

# Then add to astro.config.mjs manually
```

```typescript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';
import cloudflare from '@astrojs/cloudflare';

export default defineConfig({
  site: 'https://example.com',
  output: 'static',
  integrations: [
    tailwind(),
    sitemap(),
  ],
  adapter: cloudflare(),
});
```

## Configuration File

### astro.config.mjs

```typescript
import { defineConfig } from 'astro/config';
import tailwind from '@astrojs/tailwind';
import sitemap from '@astrojs/sitemap';

export default defineConfig({
  // Required for sitemap and canonical URLs
  site: 'https://example.com',

  // Output mode: 'static' (SSG) or 'server' (SSR)
  output: 'static',

  // Integrations
  integrations: [
    tailwind(),
    sitemap(),
  ],

  // Vite configuration overrides
  vite: {
    build: {
      assetsInlineLimit: 0,
    },
  },

  // Image optimization
  image: {
    domains: [],
    remotePatterns: [],
  },
});
```

## Common Workflows

### New Project Setup

```bash
pnpm create astro@latest my-website
cd my-website
pnpm astro add tailwind
pnpm astro add sitemap
pnpm dev
```

### Before Deploying

```bash
# Full check and build
pnpm astro check && pnpm astro build

# Preview locally
pnpm astro preview

# Deploy
npx wrangler pages deploy dist/
```

### After Schema Changes

```bash
# Regenerate types, check, restart dev server
pnpm astro sync
pnpm astro check
pnpm dev
```
