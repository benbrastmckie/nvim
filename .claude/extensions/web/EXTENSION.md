## Web Extension

Web development support for Astro/Tailwind/TypeScript sites deployed to Cloudflare Pages.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `web` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (pnpm build/check) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-web-research | web-research-agent | Astro/Tailwind/Cloudflare research |
| skill-web-implementation | web-implementation-agent | Web (Astro/Tailwind/TypeScript) implementation |
| skill-tag | (direct execution) | Semantic version tagging for CI/CD deployment (user-only) |

### Commands

| Command | Syntax | Description |
|---------|--------|-------------|
| `/tag` | `/tag [--patch\|--minor\|--major] [--force] [--dry-run]` | Create and push semantic version tags for CI/CD deployment. **User-only**. |

### Context

- @context/project/web/domain/web-reference.md - Technologies, build commands, deployment tracking
- @context/project/web/domain/astro-framework.md - Astro 5/6 framework reference
- @context/project/web/domain/tailwind-v4.md - Tailwind CSS v4 configuration
- @context/project/web/standards/web-style-guide.md - Naming conventions and coding standards
