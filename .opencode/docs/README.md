# OpenCode Agent System Documentation

[Back to Theory](../../README.md) | [Architecture](../README.md) | [OPENCODE.md](../../OPENCODE.md)

This directory contains the documentation for the `.opencode/` agent system. The system provides structured task management, research workflows, and implementation automation for Logos/Theory development. For comprehensive system details, see [architecture/system-overview.md](architecture/system-overview.md).

---

## Documentation Map

```
.opencode/docs/
├── README.md                    # This file - documentation hub
├── guides/                      # How-to guides
│   ├── user-guide.md           # Comprehensive command workflows guide
│   ├── user-installation.md    # Quick-start for new users
│   ├── component-selection.md  # When to create command vs skill vs agent
│   ├── creating-commands.md    # How to create commands
│   ├── creating-skills.md      # How to create skills
│   └── creating-agents.md      # How to create agents
└── architecture/               # Architecture documentation
    └── system-overview.md      # Three-layer architecture overview
```

---

## System Architecture

The `.opencode/` directory implements a three-layer architecture: Commands, Skills, and Agents, with checkpoint-based execution and language-specific routing. All system details, including the task lifecycle, state management, and git integration patterns, are documented in [architecture/system-overview.md](architecture/system-overview.md).

---

## Guides

### Getting Started
- [User Installation Guide](guides/user-installation.md) - Install opencode and learn the basics
- [Command Workflows User Guide](guides/user-guide.md) - Comprehensive guide to all commands with examples and troubleshooting

### Component Development
- [Component Selection](guides/component-selection.md) - Decision tree for creating commands, skills, or agents
- [Creating Commands](guides/creating-commands.md) - Define new user-invocable operations
- [Creating Skills](guides/creating-skills.md) - Implement specialized workflow skills using the thin wrapper pattern
- [Creating Agents](guides/creating-agents.md) - Build execution agents for research and implementation

---

## Related Documentation

### Core References
- [OPENCODE.md](../../OPENCODE.md) - Quick reference entry point with command syntax and workflow summaries

### Logos/Theory Project
- [Theory README](../../README.md) - Main project documentation
- [Theory docs/](../../docs/) - Project-specific documentation

---

[Back to Theory](../../README.md) | [Architecture](../README.md) | [OPENCODE.md](../../OPENCODE.md)
