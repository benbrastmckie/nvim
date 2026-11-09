# Web Extension

Web development support for Astro/Tailwind CSS v4/TypeScript sites deployed to Cloudflare Pages. Provides research and implementation agents for web development tasks.

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `web` | web-research-agent | Astro/Tailwind/Cloudflare research |
| `web` | web-implementation-agent | Web (Astro/Tailwind/TypeScript) implementation |

**Note**: The `/tag` command for semantic versioning is provided by the core agent system, not this extension.

## Installation

Loaded via the extension picker. Once loaded, `web` becomes a recognized task type.

## Architecture

```
web/
├── manifest.json              # Extension configuration
├── EXTENSION.md               # CLAUDE.md merge content
├── index-entries.json         # Context discovery entries
├── settings-fragment.json     # Scoped MCP permission grants (merged into .claude/settings.local.json)
├── README.md                  # This file
│
├── skills/
│   ├── skill-web-research/        # Research wrapper
│   └── skill-web-implementation/  # Implementation wrapper
│
├── agents/
│   ├── web-research-agent.md      # Astro/Tailwind/Cloudflare research
│   └── web-implementation-agent.md # Web implementation
│
├── rules/
│   └── web-astro.md           # Astro/Tailwind conventions (auto-applied)
│
└── context/
    └── project/
        └── web/
            ├── domain/        # Web reference, Astro, Tailwind v4
            └── standards/     # Web style guide
```

## Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-web-research | web-research-agent | Astro/Tailwind/Cloudflare research |
| skill-web-implementation | web-implementation-agent | Web (Astro/Tailwind/TypeScript) implementation |

## Language Routing

| Task Type | Research Tools | Implementation Tools |
|-----------|----------------|---------------------|
| `web` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash(pnpm build/check) |

## Workflow

```
/orchestrate <task> --research   (task_type: web)
    |
    v
skill-web-research -> web-research-agent
    |  (web search for Astro/Tailwind/Cloudflare docs, codebase exploration)
    v
specs/{NNN}_{SLUG}/reports/MM_{slug}.md
    |
    v
/orchestrate <task> --plan
    |
    v
specs/{NNN}_{SLUG}/plans/MM_{slug}.md
    |
    v
/orchestrate <task> --implement
    |
    v
skill-web-implementation -> web-implementation-agent
    |  (edits .astro/.ts/.tsx/.css files, runs pnpm build and pnpm check)
    v
specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md
    |
    v
User runs /tag --patch (or --minor/--major) to deploy
```

## Output Artifacts

| Phase | Artifact |
|-------|----------|
| Research | `specs/{NNN}_{SLUG}/reports/MM_{slug}.md` |
| Plan | `specs/{NNN}_{SLUG}/plans/MM_{slug}.md` |
| Implementation | Source file edits plus `specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md` |
| Deployment | Git tag (e.g., `v1.2.3`) pushed to origin |

## Key Patterns

### Astro Component Structure

Astro components use a three-section layout: frontmatter script, template, and style:

```astro
---
// Frontmatter: runs at build time
import Layout from "../layouts/Layout.astro";
const { title } = Astro.props;
---

<Layout title={title}>
  <main>
    <slot />
  </main>
</Layout>

<style>
  main { padding: 2rem; }
</style>
```

### Tailwind v4 Configuration

Tailwind CSS v4 uses CSS-first configuration via `@theme` directives rather than `tailwind.config.js`:

```css
@import "tailwindcss";

@theme {
  --color-primary: oklch(0.6 0.2 250);
  --font-sans: "Inter", sans-serif;
}
```

### Build and Check

Before any commit, the implementation agent runs:

```bash
pnpm build               # Full Astro build (catches template errors)
pnpm check               # TypeScript type-checking
```

Both must succeed before the phase is marked `[COMPLETED]`.

### Cloudflare Pages Deployment

Deployment is triggered by pushing a semantic version tag. The `/tag` command handles tag creation and push. Cloudflare Pages picks up the tag and builds from the associated commit.

## Rules Applied

- `web-astro.md` - auto-applied to `*.astro`, `*.ts`, `*.tsx`, `*.css` files
  - Astro component structure conventions
  - Tailwind v4 CSS-first patterns
  - TypeScript strict mode enforcement

## Context References

- `@.claude/extensions/web/context/project/web/domain/web-reference.md`
- `@.claude/extensions/web/context/project/web/domain/astro-framework.md`
- `@.claude/extensions/web/context/project/web/domain/tailwind-v4.md`
- `@.claude/extensions/web/context/project/web/standards/web-style-guide.md`

## References

- [Astro Documentation](https://docs.astro.build/)
- [Tailwind CSS v4](https://tailwindcss.com/docs/v4-beta)
- [Cloudflare Pages](https://developers.cloudflare.com/pages/)
- [pnpm](https://pnpm.io/)
