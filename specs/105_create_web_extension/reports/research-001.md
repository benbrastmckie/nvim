# Research Report: Task #105

**Task**: 105 - Create web/ extension from Logos Website .claude configuration
**Started**: 2026-03-02T00:00:00Z
**Completed**: 2026-03-02T00:30:00Z
**Effort**: 2-4 hours (implementation)
**Dependencies**: None (follows pattern established by task 102)
**Sources/Inputs**: Logos Website .claude/ directory, existing extensions (lean, latex, typst, z3, python, formal)
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The Logos Website `.claude/` directory contains a complete web development domain with 2 agents, 2 skills, 1 rule, and 18 context files covering Astro, Tailwind CSS v4, TypeScript, Cloudflare Pages, accessibility, and performance
- All 18 context files are already project-agnostic (framework reference docs, not Logos-specific); only minor de-branding needed in examples
- The extension should follow the established pattern: manifest.json, EXTENSION.md, index-entries.json, agents/, skills/, rules/, context/
- Recommended structure: 2 agents, 2 skills, 1 rule, 18 context files organized under `context/project/web/`

## Context & Scope

This research examines the Logos Website `.claude/` configuration at `/home/benjamin/Projects/Logos/Website/.claude/` to identify all web-relevant components suitable for extraction into a project-agnostic `.claude/extensions/web/` extension. The target follows the pattern established by the lean, latex, typst, z3, python, and formal extensions at `/home/benjamin/.config/nvim/.claude/extensions/`.

## Findings

### Source Inventory: Web-Specific Components

The following components from the Logos Website `.claude/` are web-specific:

**Agents** (2 files):
1. `agents/web-implementation-agent.md` (854 lines) - Full Astro/Tailwind/TypeScript implementation agent
2. `agents/web-research-agent.md` (406 lines) - Web research agent for Astro/Tailwind/Cloudflare

**Skills** (2 directories):
1. `skills/skill-web-implementation/SKILL.md` (381 lines) - Thin wrapper delegating to web-implementation-agent
2. `skills/skill-web-research/SKILL.md` (267 lines) - Thin wrapper delegating to web-research-agent

**Rules** (1 file):
1. `rules/web-astro.md` (223 lines) - Astro, TypeScript, Tailwind, accessibility, performance rules

**Context Files** (18 files under `context/project/web/`):

| Category | File | Lines | Project-Agnostic? |
|----------|------|-------|-------------------|
| domain | astro-framework.md | 287 | Yes (framework reference) |
| domain | tailwind-v4.md | 225 | Yes (framework reference) |
| domain | cloudflare-pages.md | 203 | Mostly (examples use "logos" names, easy to generalize) |
| domain | typescript-web.md | 304 | Mostly (examples use "Logos" names, easy to generalize) |
| patterns | astro-component.md | 315 | Yes (pure patterns) |
| patterns | astro-layout.md | 278 | Mostly (examples use "Logos Laboratories", easy to generalize) |
| patterns | astro-content-collections.md | 317 | Mostly (examples use "Logos Team", easy to generalize) |
| patterns | tailwind-patterns.md | 303 | Mostly (examples use "Logos", easy to generalize) |
| patterns | accessibility-patterns.md | 320 | Yes (WCAG 2.2 standards, universal) |
| standards | web-style-guide.md | 279 | Mostly (examples use "Logos", easy to generalize) |
| standards | performance-standards.md | 211 | Mostly (aspirational targets reference "Logos website", easy to generalize) |
| standards | accessibility-standards.md | 301 | Mostly (examples reference "Logos Laboratories", easy to generalize) |
| tools | astro-cli-guide.md | 256 | Mostly (examples reference "logos-website", easy to generalize) |
| tools | pnpm-guide.md | 155 | Yes (generic pnpm reference) |
| tools | cloudflare-deploy-guide.md | ~120 | Mostly (references "logos-website", easy to generalize) |
| tools | cicd-pipeline-guide.md | ~150 | Mostly (GitLab-specific, references "logos", easy to generalize) |
| tools | debugging-utilities.md | ~120 | Yes (generic CLI tool reference) |
| templates | astro-page-template.md | 211 | Mostly (examples reference "Logos Laboratories", easy to generalize) |
| templates | astro-component-template.md | 277 | Mostly (examples reference "Logos Laboratories", easy to generalize) |

Plus the README:
- `context/project/web/README.md` (111 lines) - Overview and loading strategy

**Total context**: ~19 files, approximately 4,500 lines

### Generalization Assessment

All files are substantially project-agnostic already. They describe framework conventions, not Logos-specific business logic. The generalization work consists of:

1. **Replace "Logos" / "Logos Laboratories"** with generic placeholders like "Your Site Name" or "Example Corp" in example code and comments
2. **Replace domain-specific URLs** (`logos-labs.com`, `logos-laboratories.com`) with `example.com` placeholders
3. **Remove Logos-specific CI/CD details** (GitLab-specific pipeline) -- keep as generic CI/CD patterns or note as "example"
4. **Generalize project names** in wrangler.jsonc examples (`logos-website` -> `my-website`)
5. **Keep all framework documentation intact** -- it is already universal

### Existing Extension Pattern Analysis

Each extension follows a consistent structure:

```
extensions/{name}/
+-- manifest.json          # Extension metadata, provides, merge_targets
+-- EXTENSION.md           # Content merged into CLAUDE.md
+-- index-entries.json     # Context index entries for discovery
+-- agents/                # Agent definitions
+-- skills/                # Skill wrappers
+-- rules/                 # Language-specific rules
+-- context/               # Domain knowledge
    +-- project/{domain}/  # Context files organized by category
        +-- README.md
        +-- domain/
        +-- patterns/
        +-- standards/
        +-- tools/
        +-- templates/
```

Key observations from existing extensions:

- **manifest.json**: Declares language, provides (agents/skills/commands/rules/context), merge_targets, and optional mcp_servers
- **EXTENSION.md**: Brief, focusing on language routing table and skill-agent mapping. Gets merged into CLAUDE.md
- **index-entries.json**: Array of entries with path, description, tags, and load_when (languages/agents) for context discovery
- **Agents**: Full agent definitions following the standard subagent pattern (stages 0-8, metadata file return)
- **Skills**: Thin wrapper SKILL.md files with preflight/delegation/postflight
- **Rules**: Path-pattern-scoped coding rules
- **Context**: Organized into domain/, patterns/, standards/, tools/, templates/ subdirectories

### Recommended Extension Structure

```
extensions/web/
+-- manifest.json
+-- EXTENSION.md
+-- index-entries.json
+-- agents/
|   +-- web-implementation-agent.md
|   +-- web-research-agent.md
+-- skills/
|   +-- skill-web-implementation/
|   |   +-- SKILL.md
|   +-- skill-web-research/
|       +-- SKILL.md
+-- rules/
|   +-- web-astro.md
+-- context/
    +-- project/
        +-- web/
            +-- README.md
            +-- domain/
            |   +-- astro-framework.md
            |   +-- tailwind-v4.md
            |   +-- cloudflare-pages.md
            |   +-- typescript-web.md
            +-- patterns/
            |   +-- astro-component.md
            |   +-- astro-layout.md
            |   +-- astro-content-collections.md
            |   +-- tailwind-patterns.md
            |   +-- accessibility-patterns.md
            +-- standards/
            |   +-- web-style-guide.md
            |   +-- performance-standards.md
            |   +-- accessibility-standards.md
            +-- tools/
            |   +-- astro-cli-guide.md
            |   +-- pnpm-guide.md
            |   +-- cloudflare-deploy-guide.md
            |   +-- cicd-pipeline-guide.md
            |   +-- debugging-utilities.md
            +-- templates/
                +-- astro-page-template.md
                +-- astro-component-template.md
```

**Total files**: 24 (1 manifest + 1 EXTENSION.md + 1 index-entries + 2 agents + 2 skills + 1 rule + 16 context files including README)

### manifest.json Specification

```json
{
  "name": "web",
  "version": "1.0.0",
  "description": "Web development with Astro, Tailwind CSS v4, TypeScript, and Cloudflare Pages",
  "language": "web",
  "dependencies": [],
  "provides": {
    "agents": ["web-implementation-agent.md", "web-research-agent.md"],
    "skills": ["skill-web-implementation", "skill-web-research"],
    "commands": [],
    "rules": ["web-astro.md"],
    "context": ["project/web"],
    "scripts": [],
    "hooks": []
  },
  "merge_targets": {
    "claudemd": {
      "source": "EXTENSION.md",
      "target": ".claude/CLAUDE.md",
      "section_id": "extension_web"
    },
    "index": {
      "source": "index-entries.json",
      "target": ".claude/context/index.json"
    }
  },
  "mcp_servers": {}
}
```

Note: No MCP servers declared. The Astro Docs MCP and Context7 MCP are referenced in the agents but are optional and configured project-level, not extension-level. The Playwright MCP is noted as "deferred" in the source.

### EXTENSION.md Content

```markdown
## Web Extension

This project includes web development support via the web extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `web` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (pnpm build, pnpm check) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-web-research | web-research-agent | Astro/Tailwind/Cloudflare research |
| skill-web-implementation | web-implementation-agent | Web (Astro/Tailwind/TypeScript) implementation |

### Build Verification

- TypeScript check: `pnpm check`
- Production build: `pnpm build`
- Astro diagnostics: `npx astro check`
- Dev server: `pnpm dev`

### Key Technologies

- Astro 5/6 (islands architecture, SSG/SSR)
- Tailwind CSS v4 (CSS-first configuration)
- TypeScript (strict mode)
- Cloudflare Pages (edge deployment)
- pnpm (package manager)
```

### index-entries.json Entries

The index-entries.json should contain entries for all 18 context files. Each entry maps to the appropriate agents and language. All entries should use `"languages": ["web"]`.

Key agent mapping:
- **Both agents**: domain files (astro-framework, tailwind-v4, cloudflare-pages, typescript-web)
- **web-research-agent only**: tools/ files (research needs to know about available tools)
- **web-implementation-agent only**: patterns/ and templates/ files (implementation patterns)
- **Both agents**: standards/ files (both need to know standards)

### Generalization Changes Required

For each file, the following changes are needed:

**Minimal changes** (replace "Logos" branding in examples only):
1. `cloudflare-pages.md`: `logos.example.com` -> `example.com`, `logos-website` -> `my-website`
2. `typescript-web.md`: `Logos Team` -> `Team`, `Logos website` -> `project`
3. `astro-layout.md`: `Logos Laboratories` -> `Your Site Name`
4. `astro-content-collections.md`: `Logos Team` -> `Team`
5. `tailwind-patterns.md`: `Logos` -> generic branding in examples
6. `web-style-guide.md`: `Logos website` -> `website`
7. `performance-standards.md`: `Logos Website` -> `website`
8. `accessibility-standards.md`: `Logos Laboratories` -> `Your Organization`
9. `astro-cli-guide.md`: `logos-website` -> `my-website`, `logos-laboratories.com` -> `example.com`
10. `cloudflare-deploy-guide.md`: `logos-website` -> `my-website`
11. `cicd-pipeline-guide.md`: Make GitLab references generic
12. `astro-page-template.md`: `Logos Laboratories` -> `Your Site Name`
13. `astro-component-template.md`: `Logos Laboratories` -> `Your Site Name`
14. `README.md`: `Logos website` -> generic

**No changes needed** (already project-agnostic):
1. `astro-framework.md` - Pure framework reference
2. `tailwind-v4.md` - Pure framework reference
3. `astro-component.md` - Pure patterns
4. `accessibility-patterns.md` - Pure WCAG patterns
5. `pnpm-guide.md` - Generic tool reference
6. `debugging-utilities.md` - Generic CLI tools

**Agent changes**:
- Both agents: Remove references to `.claude/context/core/` paths (those are part of core system, not extension)
- Both agents: Context references should use relative extension paths
- web-implementation-agent: Remove Logos-specific deployment details (Cloudflare project names)

**Skill changes**:
- Both skills: Already thin wrappers, minimal changes needed
- Update path references to extension-relative context

**Rule changes**:
- `web-astro.md`: Already project-agnostic, no changes needed

## Decisions

1. **Include all 18 context files**: Every file provides useful, reusable web development knowledge
2. **Keep CI/CD guide**: Generalize from GitLab-specific to framework-agnostic examples, keep as useful reference
3. **Keep debugging-utilities.md**: System-wide CLI tools are useful across projects
4. **No MCP servers in manifest**: Astro Docs MCP and Context7 are optional project-level configurations, not extension dependencies
5. **No commands in extension**: The source has no web-specific slash commands; web tasks use the standard /research, /plan, /implement pipeline
6. **Use "web" as language identifier**: Consistent with the source project's language routing

## Risks & Mitigations

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Context files may reference core paths that do not exist in target project | Medium | Low | Review all `@.claude/context/core/` references, convert to notes about core system |
| MCP tool references in agents may confuse when MCP not configured | Low | Low | Agents already have fallback patterns (WebSearch when MCP unavailable) |
| Astro version drift (v5 stable now, v6 may become stable) | Low | Low | Context already notes v5/v6 differences, easy to update |
| Tailwind v4 examples may not work with v3 projects | Medium | Low | Extension name/docs clearly state "Tailwind CSS v4" |

## Appendix

### Search Queries Used
- File listing: `find /home/benjamin/Projects/Logos/Website/.claude/ -type f`
- Extension pattern: `find /home/benjamin/.config/nvim/.claude/extensions/ -type f`
- Read all web-specific files from source
- Read existing extension manifests and EXTENSION.md files for pattern matching

### References
- Source: `/home/benjamin/Projects/Logos/Website/.claude/`
- Extension pattern: `/home/benjamin/.config/nvim/.claude/extensions/lean/` (reference implementation)
- Existing extensions: lean, latex, typst, z3, python, formal
