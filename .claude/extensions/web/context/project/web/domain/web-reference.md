# Web Extension Reference

## Key Technologies

- **Astro**: Static site generator with islands architecture (v5 stable, v6 notes where relevant)
- **Tailwind CSS v4**: CSS-first configuration with @theme directive
- **TypeScript**: Strict mode with Astro type utilities
- **Cloudflare Pages**: Edge deployment with automatic preview deployments

## Build Verification

```bash
# Development server
pnpm dev

# TypeScript + Astro diagnostics
pnpm check

# Production build
pnpm build

# Preview production build
pnpm preview
```

## Context Categories

- **Domain**: Core framework concepts (Astro, Tailwind v4, Cloudflare, TypeScript)
- **Patterns**: Implementation patterns (components, layouts, content collections, accessibility)
- **Standards**: Coding conventions and targets (style guide, performance, accessibility)
- **Tools**: Tool-specific guides (CLI, deployment, debugging)
- **Templates**: Boilerplate templates (pages, components)

## Deployment Version Tracking

The `/tag` command tracks deployment versions in `specs/state.json`:

```json
{
  "deployment_versions": {
    "last_deployed": "v0.2.4",
    "last_deployed_at": "2026-02-10T18:00:00Z",
    "deployment_history": [
      {
        "version": "v0.2.4",
        "deployed_at": "2026-02-10T18:00:00Z",
        "commit_sha": "abc1234def5678"
      }
    ]
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `last_deployed` | string | Most recent version tag (e.g., `v0.2.4`) |
| `last_deployed_at` | string | ISO8601 timestamp of last deployment |
| `deployment_history` | array | Last 10 deployments with version, timestamp, and commit SHA |
