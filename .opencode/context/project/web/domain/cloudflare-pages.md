# Cloudflare Pages Reference

Deployment platform and edge CDN for web applications.

## Platform Overview

Cloudflare Pages is a JAMstack deployment platform running on Cloudflare's global network (300+ data centers). Static assets are served from the edge CDN. Server-side logic runs via Workers (V8 isolates, not containers).

### Free Tier Limits

| Resource | Limit |
|----------|-------|
| Bandwidth | Unlimited |
| Builds per month | 500 |
| Concurrent builds | 1 |
| Custom domains | Unlimited |
| Preview deployments | Unlimited |
| Sites per account | 100 |
| Max file size | 25 MB |
| Max files per deployment | 20,000 |
| Max build duration | 20 minutes |

## Astro Adapter Configuration

### Static Deployment (SSG)

No adapter needed for static sites:

```typescript
// astro.config.mjs
import { defineConfig } from 'astro/config';

export default defineConfig({
  output: 'static',  // default
  site: 'https://example.com',
});
```

### Server-Side Rendering (SSR)

```bash
pnpm add @astrojs/cloudflare
```

```typescript
// astro.config.mjs
import { defineConfig } from 'astro/config';
import cloudflare from '@astrojs/cloudflare';

export default defineConfig({
  output: 'server',
  adapter: cloudflare(),
});
```

### Hybrid Mode

```typescript
// astro.config.mjs
export default defineConfig({
  output: 'server',
  adapter: cloudflare(),
});

// In individual pages:
// export const prerender = true;  // SSG for this page
```

## Wrangler Configuration

```jsonc
// wrangler.jsonc
{
  "name": "my-website",
  "pages_build_output_dir": "./dist",
  "compatibility_date": "2026-02-01",
  "compatibility_flags": ["nodejs_compat_v2"]
}
```

| Field | Description |
|-------|-------------|
| `name` | Project name (used in deploy URL) |
| `pages_build_output_dir` | Build output directory |
| `compatibility_date` | Workers runtime version date |
| `compatibility_flags` | Runtime feature flags |

## Environment Variables

### In Cloudflare Dashboard

Set per-environment variables in the dashboard under Settings > Environment Variables.

### In wrangler.jsonc

```jsonc
{
  "vars": {
    "PUBLIC_SITE_URL": "https://example.com",
    "PUBLIC_API_BASE": "https://api.example.com"
  }
}
```

### Accessing in Astro (SSR)

```astro
---
// Only available in SSR mode
const env = Astro.locals.runtime.env;
const apiKey = env.SECRET_API_KEY;
---
```

### Public Variables (Available in Client)

Prefix with `PUBLIC_` and access via `import.meta.env`:

```astro
---
const siteUrl = import.meta.env.PUBLIC_SITE_URL;
---
```

## Deployment Methods

### Git Integration (Recommended)

1. Connect repository in Cloudflare dashboard
2. Configure build settings:
   - Build command: `pnpm build`
   - Build output directory: `dist`
   - Root directory: `/` (or monorepo path)
3. Auto-deploys on push to production branch
4. Preview deployments for every non-production branch

### Manual CLI Deployment

```bash
# Install wrangler
pnpm add -D wrangler

# Login to Cloudflare
npx wrangler login

# Deploy build output
npx wrangler pages deploy dist/ --project-name=my-website
```

## Preview Deployments

Every non-production branch gets a preview URL:

```
https://<branch-name>.my-website.pages.dev
https://<commit-hash>.my-website.pages.dev
```

Preview deployments use preview environment variables (separate from production).

## Custom Domains

Add custom domains in the Cloudflare dashboard:

1. Navigate to Pages project > Custom domains
2. Add domain (e.g., `example.com`)
3. Cloudflare handles SSL certificate provisioning automatically
4. DNS records are configured automatically if domain is on Cloudflare

## Workers Integration

For server-side logic beyond SSR pages:

```
functions/
└── api/
    └── contact.ts    # Handles POST /api/contact
```

```typescript
// functions/api/contact.ts
export const onRequestPost: PagesFunction = async (context) => {
  const body = await context.request.json();
  // Process form submission
  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
};
```

## Build and Deploy Pipeline

```
git push -> Cloudflare detects push
         -> Clones repository
         -> Runs build command (pnpm build)
         -> Deploys dist/ to edge CDN
         -> Preview URL or production URL available
         -> Build logs visible in dashboard
```

Typical build times: 30-90 seconds for a static Astro site.
