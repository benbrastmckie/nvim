# Agent Frontmatter Standard

**Created**: 2026-02-24
**Purpose**: Define YAML frontmatter requirements for agent files

## Overview

Agent files in `.claude/agents/` use YAML frontmatter to declare metadata that the Claude Code system and invoking skills use for agent selection, model enforcement, and capability discovery.

## Required Fields

```yaml
---
name: {agent-name}
description: {brief description of agent purpose}
---
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | Yes | Agent identifier (e.g., `neovim-research-agent`) |
| `description` | string | Yes | Brief description of agent purpose and capabilities |

## Optional Fields

```yaml
---
name: neovim-research-agent
description: Research Neovim configuration and plugin tasks
model: opus
---
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model` | string | No | Preferred model for this agent (`opus`, `sonnet`) |

## Model Field

The `model` field allows explicit model selection for agents that benefit from specific model capabilities.

### Values

| Value | Use Case | Rationale |
|-------|----------|-----------|
| `opus` | Complex reasoning, research, planning | Superior analytical and reasoning capabilities |
| `sonnet` | Implementation, code generation | Cost-effective, fast, good for routine tasks |
| (omitted) | Default behavior | System chooses based on context |

### Usage Guidelines

**Use `model: opus` for**:
- Research agents requiring deep analysis
- Planning agents requiring complex decomposition
- Tasks requiring mathematical or logical reasoning

**Use `model: sonnet` for**:
- Team orchestration skills (lightweight coordination)
- Routine code generation tasks
- Tasks where speed is prioritized over depth

**Omit model field when**:
- Agent handles varied task complexity
- Default model selection is appropriate
- Model flexibility is desired

### Example

```yaml
---
name: neovim-research-agent
description: Research Neovim configuration and plugin tasks
model: opus
---
```

**Rationale**: Research agents benefit from Opus's deeper reasoning capabilities when analyzing plugin ecosystems, API patterns, and community best practices.

## Validation

Agent frontmatter is validated during:
1. Agent file creation (via `/meta` command)
2. Agent invocation (by skill preflight)

### Validation Rules

1. `name` must be present and non-empty
2. `description` must be present and non-empty
3. `model`, if present, must be one of: `opus`, `sonnet`

## Examples

### Research Agent

```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
model: opus
---
```

### Implementation Agent

```yaml
---
name: general-implementation-agent
description: Implement general, meta, and markdown tasks from plans
model: opus
---
```

### Planning Agent

```yaml
---
name: planner-agent
description: Create phased implementation plans from research findings
model: opus
---
```

## Migration

To add model enforcement to existing agents:

1. Open agent file (e.g., `.claude/agents/neovim-research-agent.md`)
2. Add `model: opus` or `model: sonnet` to frontmatter
3. Document rationale in agent comments

No other changes are required - the Task tool will respect the model field when spawning agents.

## Related Documentation

- [Creating Agents Guide](.claude/docs/guides/creating-agents.md)
- [Agent Template](.claude/docs/templates/agent-template.md)
- [Context Discovery Patterns](.claude/context/patterns/context-discovery.md)
