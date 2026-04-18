# Project Overview

## Purpose

This file describes the repository structure for agent context. When extensions are loaded, they provide project-specific domain knowledge (technology stack, development workflows, verification commands).

## Two-Layer Extension Architecture

This repository uses a two-layer extension system:

- **Layer 1 -- Neovim Lua loader** (`lua/neotex/plugins/ai/shared/extensions/`): Manages which agent files, skills, rules, and context exist in the `.claude/` runtime. The extension picker (`<leader>ac`) triggers the loader, which copies files from `.claude/extensions/*/` sources into the `.claude/` runtime and regenerates `.claude/CLAUDE.md`.
- **Layer 2 -- .claude/ agent system** (`.claude/`): The runtime read by Claude Code. Contains only the files that have been loaded by the Lua loader. Claude Code does not know about the extension system; it sees a standard `.claude/` directory structure.

See `.claude/docs/architecture/extension-system.md` for the full two-layer architecture documentation.

## Repository Structure

```
specs/                       # Task management
├── TODO.md                 # Task list
├── state.json              # Task state
└── {NNN}_{SLUG}/           # Task artifacts
    ├── reports/
    ├── plans/
    └── summaries/

.claude/                     # Claude Code configuration
├── CLAUDE.md               # Main reference
├── commands/               # Slash commands
├── skills/                 # Skill definitions
├── agents/                 # Agent definitions
├── rules/                  # Auto-applied rules
├── context/                # Domain knowledge
└── extensions/             # Extension modules
    └── */                  # Per-extension directories
        ├── manifest.json   # Extension metadata
        ├── index-entries.json  # Context index entries
        └── context/        # Extension-specific context
```

## Extension-Provided Context

Extensions supply project-specific knowledge:
- Technology stack and language details
- Development workflows and verification commands
- Coding standards and patterns
- Tool-specific guides

Extensions can declare dependencies on other extensions (e.g., founder and present both depend on slidev for shared Slidev animation patterns). Resource-only extensions like slidev/ provide only context files with no agents, skills, or routing.

See `.claude/extensions/*/manifest.json` for available extensions, their capabilities, and dependency declarations.

## AI-Assisted Workflow

1. **Research**: `/research` - Gather documentation and patterns
2. **Planning**: `/plan` - Create implementation plan
3. **Implementation**: `/implement` - Execute the plan
4. **Review**: `/review` - Analyze changes

## Related Documentation

- `.claude/CLAUDE.md` - Agent system configuration
- `.claude/extensions/` - Extension modules with project-specific context
- `CLAUDE.md` (project root) - Project-specific coding standards
