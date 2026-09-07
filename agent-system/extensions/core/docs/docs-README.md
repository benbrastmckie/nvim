# Claude Agent System Documentation

[Project Root](../../README.md) | [Architecture](../README.md) | [CLAUDE.md](../CLAUDE.md)

This directory contains the documentation for the `.claude/` agent system. The system provides structured task management, research workflows, and implementation automation for project development. For comprehensive system details, see [architecture/system-overview.md](architecture/system-overview.md).

---

## Documentation Map

```
.claude/docs/
├── README.md                    # This file - documentation hub
├── guides/                      # How-to guides
│   ├── user-guide.md           # Comprehensive command workflows guide
│   ├── user-installation.md    # Quick-start for new users
│   ├── copy-claude-directory.md # Copy .claude/ to another project
│   ├── component-selection.md  # When to create command vs skill vs agent
│   ├── creating-commands.md    # How to create commands
│   ├── creating-skills.md      # How to create skills
│   ├── creating-agents.md      # How to create agents
│   ├── adding-domains.md       # Add new domain support (extensions or core)
│   ├── creating-extensions.md  # Create domain extensions
│   ├── context-loading-best-practices.md # Context loading patterns
│   ├── permission-configuration.md # Permission setup
│   └── development/             # Development subsystem guides
│       └── context-index-migration.md # Context index migration guide
├── examples/                    # Integration examples
│   ├── research-flow-example.md # End-to-end research flow
│   └── fix-it-flow-example.md   # Tag extraction and task creation
├── templates/                   # Reusable templates
│   ├── README.md               # Template overview
│   ├── command-template.md     # Command template
│   └── agent-template.md       # Agent template
├── reference/                   # Reference standards
│   ├── utility-scripts-inventory.md # Operator-only scripts catalog (relocated off CLAUDE.md's eager surface)
│   └── standards/
│       ├── agent-frontmatter-standard.md  # Agent/skill frontmatter spec
│       ├── extension-slim-standard.md     # Extension slim format
│       └── multi-task-creation-standard.md # Multi-task creation pattern
└── architecture/               # Architecture documentation
    ├── system-overview.md      # Three-layer architecture overview
    ├── extension-system.md     # Extension system architecture
    ├── handoff-schema.md       # Orchestrator handoff JSON schema
    └── orchestrate-state-machine.md # /orchestrate state machine spec
```

---

## System Architecture

The `.claude/` directory implements a three-layer architecture: Commands, Skills, and Agents, with checkpoint-based execution and task-type-specific routing. All system details, including the task lifecycle, state management, and git integration patterns, are documented in [architecture/system-overview.md](architecture/system-overview.md).

The core agent system is itself packaged as an extension (`core`) alongside domain extensions
(lean, latex, typst, python, nix, web, z3, epidemiology, formal, and others) that add
task-type-specific routing. See [Extension System Architecture](architecture/extension-system.md)
for how the loader, merger, and per-extension `manifest.json` work, and `../README.md` for the
current command/agent inventory.

---

## Maintenance

### /refresh Command

Clean up Claude Code resources:

| Option | Description |
|--------|-------------|
| `/refresh` | Interactive cleanup |
| `/refresh --dry-run` | Preview changes |
| `/refresh --force` | Execute immediately (8-hour default) |

**Cleanable directories**: `~/.claude/{projects,debug,file-history,todos,session-env,telemetry,cache}/`

### MCP Configuration

Once a workspace is trusted, project-scoped `.mcp.json` servers are fully reachable by dispatched
subagents — there is no categorical subagent access barrier to project scope. The real cost of
project scope is workspace trust: a fresh clone (or any not-yet-trusted workspace) requires a
one-time interactive approval before a project-scoped server is used, and a cloned repository
cannot pre-authorize its own servers from inside the repo. That is a one-time setup cost, not a
per-call or per-session obstacle, and it is not a reason to avoid project scope for a genuinely
repo-local server.

A session's tool registry is also a snapshot taken at startup, so an already-running session
cannot see a server added to `.mcp.json` after it started — this affects the main session
identically to any subagent and is not subagent-specific. Any re-verification of registration or
reachability must use a fresh session (or `claude -p`), never an already-running one.

See `context/patterns/mcp-server-ownership.md` for the full registration/permission model and the
authoritative account of this trade-off.

---

## Guides

### Getting Started
- [User Installation Guide](guides/user-installation.md) - Install Claude Code, set up the agent system, and learn the basics
- [Command Workflows User Guide](guides/user-guide.md) - Comprehensive guide to all commands with examples and troubleshooting
- [Copy .claude/ Directory](guides/copy-claude-directory.md) - Install the agent system in another project
### Component Development
- [Component Selection](guides/component-selection.md) - Decision tree for creating commands, skills, or agents
- [Creating Commands](guides/creating-commands.md) - Define new user-invocable operations
- [Creating Skills](guides/creating-skills.md) - Implement specialized workflow skills using the thin wrapper pattern
- [Creating Agents](guides/creating-agents.md) - Build execution agents for research and implementation

### Domain Extensions
- [Adding Domains](guides/adding-domains.md) - Choose between extension and core approach for new domains
- [Creating Extensions](guides/creating-extensions.md) - Step-by-step guide to creating domain extensions
- [Extension System Architecture](architecture/extension-system.md) - How the extension loader, merger, and state system work

### Advanced Topics
- [Context Loading Best Practices](guides/context-loading-best-practices.md) - Lazy context loading patterns and strategies
- [Permission Configuration](guides/permission-configuration.md) - Configure file access and tool permissions

---

## Examples

- [Research Flow Example](examples/research-flow-example.md) - Complete walkthrough of the research command execution flow
- [Fix-It Flow Example](examples/fix-it-flow-example.md) - Tag extraction from source files and interactive task creation

---

## Templates

Reusable templates for creating new system components are available in [templates/](templates/). See [templates/README.md](templates/README.md) for an overview of available templates and usage instructions.

---

## Related Documentation

### Core References
- [CLAUDE.md](../CLAUDE.md) - Quick reference entry point with command syntax and workflow summaries
- [README.md](../README.md) - Detailed system architecture and component specifications

### Project Documentation
- [Project README](../../README.md) - Main project documentation

---

[Project Root](../../README.md) | [Architecture](../README.md) | [CLAUDE.md](../CLAUDE.md)
