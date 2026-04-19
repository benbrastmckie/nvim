# Claude Code Agent System

**Version**: 3.0
**Updated**: 2026-03-28

Task management and automation framework for software development. This README provides a navigation hub to the system's documentation.

For quick reference loaded every session, see [CLAUDE.md](CLAUDE.md).

---

## Quick Reference

| Command | Usage | Purpose |
|---------|-------|---------|
| `/task` | `/task "Description"` | Create new task |
| `/research` | `/research N [focus] [--team]` | Research task N |
| `/plan` | `/plan N [--team]` | Create implementation plan |
| `/implement` | `/implement N [--team]` | Execute implementation |
| `/revise` | `/revise N` | Revise existing plan |
| `/review` | `/review` | Analyze codebase |
| `/todo` | `/todo` | Archive completed tasks |
| `/errors` | `/errors` | Analyze error patterns |
| `/meta` | `/meta` | System builder for .claude/ |
| `/fix-it` | `/fix-it [PATH...]` | Scan for FIX:/NOTE:/TODO:/QUESTION: tags |
| `/refresh` | `/refresh` | Clean orphaned processes |
| `/spawn` | `/spawn N` | Spawn tasks to unblock |
| `/merge` | `/merge` | Create pull/merge request |
| `/tag` | `/tag [--patch\|--minor\|--major]` | Create semantic version tag |

Full command documentation: [docs/guides/user-guide.md](docs/guides/user-guide.md)

---

## Architecture

```
                              USER
                                |
                                | /command args
                                v
    ┌─────────────────────────────────────────────────────────┐
    │                      COMMANDS                            │
    │   .claude/commands/*.md                                  │
    │   Parse arguments, route by task_type, checkpoint flow   │
    └─────────────────────────────────────────────────────────┘
                                |
                                | Delegation context
                                v
    ┌─────────────────────────────────────────────────────────┐
    │                       SKILLS                             │
    │   .claude/skills/skill-*/SKILL.md                        │
    │   Validate inputs, prepare context, invoke agents        │
    └─────────────────────────────────────────────────────────┘
                                |
                                | Task tool invocation
                                v
    ┌─────────────────────────────────────────────────────────┐
    │                       AGENTS                             │
    │   .claude/agents/*.md                                    │
    │   Full execution, create artifacts, return JSON          │
    └─────────────────────────────────────────────────────────┘
```

**Detailed architecture**: [docs/architecture/system-overview.md](docs/architecture/system-overview.md)

### Core Principles

1. **Delegation Safety**: Session tracking, depth limits, cycle detection, timeouts
2. **Standardized Returns**: All agents return consistent JSON format
3. **Atomic State Updates**: Two-phase commit for TODO.md/state.json sync
4. **Task Type Routing**: Route to specialized agents based on task_type

---

## Core Components

### Commands (`.claude/commands/`)

User-invocable operations with checkpoint-based execution:
- **Preflight**: Validate inputs, update status
- **Delegate**: Route to skill/agent
- **Postflight**: Update status, commit

### Skills (`.claude/skills/`)

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-researcher | general-research-agent | Web/codebase research |
| skill-planner | planner-agent | Implementation plans |
| skill-implementer | general-implementation-agent | File implementation |
| skill-meta | meta-builder-agent | System building |
| skill-status-sync | (direct) | Atomic status updates |

**Note**: This is a subset of core skills. See [CLAUDE.md](CLAUDE.md) for the complete skill-to-agent mapping including team mode, git workflow, and orchestrator skills.

### Agents (`.claude/agents/`)

| Agent | Purpose |
|-------|---------|
| general-research-agent | General research |
| general-implementation-agent | General implementation |
| planner-agent | Plan creation |
| meta-builder-agent | Meta tasks |
| code-reviewer-agent | Code review |
| reviser-agent | Plan revision with research synthesis |
| spawn-agent | Task decomposition |

---

## Extensions

The extension system provides task-type-specific support. Extensions are loaded via the extension picker. The core agent system itself is packaged as a real extension (`core`) that installs all base commands, agents, rules, skills, scripts, hooks, context, docs, and templates into the target `.claude/` directory.

**Available Extensions** (`.claude/extensions/`):

| Extension | Domain | Provides |
|-----------|--------|----------|
| **core** | **Agent system foundation** | **All base commands, agents, rules, skills, scripts, hooks, context** |
| lean | Theorem proving | lean4-research-agent, MCP integration |
| latex | LaTeX documents | latex-research-agent |
| typst | Typst documents | typst-research-agent |
| python | Python development | Python patterns, tools |
| nix | Nix expressions | Nix patterns |
| web | Web development | Web standards |
| z3 | SMT solving | Z3 patterns |
| epidemiology | Epidemiology | /epi command, epi-research-agent, epi-implement-agent |
| formal | Formal verification | Logic, math, physics domains |
| filetypes | File conversion | Format conversion utilities |
| founder | Business strategy | Market, analyze, strategy, legal, project, deck, finance, sheet |
| present | Grant writing | Grant proposal development |
| memory | Knowledge management | Learning and memory patterns |

The `core` extension is the foundational layer. All other extensions declare `"dependencies": ["core"]` to ensure it is loaded first. Core files live in `.claude/extensions/core/` and are installed to the standard `.claude/` layout when loaded. Sync (`Load Core Agent System`) sources core artifacts from `extensions/core/` in the global repository.

**Extension documentation**: [docs/architecture/extension-system.md](docs/architecture/extension-system.md)

Creating extensions: [docs/guides/creating-extensions.md](docs/guides/creating-extensions.md)

---

## State Management

### Files

| File | Purpose |
|------|---------|
| `specs/TODO.md` | User-facing task list |
| `specs/state.json` | Machine-readable state |
| `specs/errors.json` | Error tracking |
| `specs/{NNN}_{SLUG}/` | Task directories |

### Task Lifecycle

```
[NOT STARTED] -> [RESEARCHING] -> [RESEARCHED]
    -> [PLANNING] -> [PLANNED]
    -> [IMPLEMENTING] -> [COMPLETED]
```

**State management rules**: [rules/state-management.md](rules/state-management.md)

---

## Context Organization

Context files are discovered via `.claude/context/index.json`:

| Directory | Contains |
|-----------|----------|
| `context/orchestration/` | Delegation, routing, validation |
| `context/formats/` | Return formats, plan formats |
| `context/patterns/` | Reusable patterns |
| `context/processes/` | Workflow documentation |
| `context/reference/` | Schema references |
| `context/architecture/` | Architecture documentation (for agents) |
| `context/meta/` | Meta-system guides |
| `context/repo/` | Repository-specific context |

**Context discovery patterns**: [context/patterns/context-discovery.md](context/patterns/context-discovery.md)

---

## Documentation Hub

### Getting Started

- [User Installation Guide](docs/guides/user-installation.md) - Set up Claude Code
- [User Guide](docs/guides/user-guide.md) - Command workflows
### Development

- [Component Selection](docs/guides/component-selection.md) - Command vs skill vs agent
- [Creating Commands](docs/guides/creating-commands.md)
- [Creating Skills](docs/guides/creating-skills.md)
- [Creating Agents](docs/guides/creating-agents.md)
- [Creating Extensions](docs/guides/creating-extensions.md)

### Reference

- [System Overview](docs/architecture/system-overview.md) - Architecture details
- [Extension System](docs/architecture/extension-system.md) - Extension architecture
- [docs/README.md](docs/README.md) - Full documentation index

### Examples

- [Research Flow](docs/examples/research-flow-example.md) - End-to-end research
- [Fix-It Flow](docs/examples/fix-it-flow-example.md) - Tag extraction

---

## Session Maintenance

### /refresh Command

Clean up Claude Code resources:

| Option | Description |
|--------|-------------|
| `/refresh` | Interactive cleanup |
| `/refresh --dry-run` | Preview changes |
| `/refresh --force` | Execute immediately (8-hour default) |

**Cleanable directories**: `~/.claude/{projects,debug,file-history,todos,session-env,telemetry,cache}/`

### MCP Configuration

Custom subagents cannot access project-scoped MCP servers (`.mcp.json`). For subagent access, configure servers in user scope (`~/.claude.json`).

---

## Error Handling

- **On failure**: Keep task in current status, log to errors.json
- **On timeout**: Mark phase [PARTIAL], next /implement resumes
- **Git failures**: Non-blocking (logged, not fatal)

Error recovery patterns: [rules/error-handling.md](rules/error-handling.md)

---

## Related Files

| File | Purpose |
|------|---------|
| [CLAUDE.md](CLAUDE.md) | Quick reference (loaded every session) |
| [docs/README.md](docs/README.md) | Documentation hub |
| [context/README.md](context/README.md) | Context organization |
| [extensions/README.md](extensions/README.md) | Extension overview |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 3.0 | 2026-03-28 | Restructured as navigation hub |
| 2.2 | 2026-01-28 | Added forked subagent pattern |
| 2.1 | 2026-01-15 | Extension system |
| 2.0 | 2025-12-26 | Clean-break refactor |
