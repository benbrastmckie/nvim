# Agent Frontmatter Standard

**Created**: 2026-02-24
**Updated**: 2026-04-16
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
| `name` | string | Yes | Agent identifier (e.g., `general-research-agent`) |
| `description` | string | Yes | Brief description of agent purpose and capabilities |

## Optional Fields

```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
model: opus
---
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model` | string | No | Preferred model for this agent (`opus`, `sonnet`, `haiku`) |

## Model Field

The `model` field allows explicit model selection for agents that benefit from specific model capabilities.

### Default Policy

**All agents default to Opus.** All 7 core agents and all extension agents declare `model: opus` in their frontmatter. This provides the highest reasoning quality as the baseline.

Users can override the model at invocation time using model flags (`--haiku`, `--sonnet`, `--opus`) for cost/speed tradeoffs on specific tasks.

### Values

| Value | Use Case | Rationale |
|-------|----------|-----------|
| `opus` | Default for all agents | Superior analytical and reasoning capabilities |
| `sonnet` | Cost-effective alternative when specified via `--sonnet` | Good quality, faster, lower cost |
| `haiku` | Lightweight tasks when specified via `--haiku` | Fastest, lowest cost, suitable for simple tasks |
| (omitted) | Default behavior | System chooses based on context |

### Usage Guidelines

**Use `model: opus` for**:
- All core agents (research, planning, implementation, coordination)
- All extension agents (domain-specific research and implementation)

**Omit model field when**:
- Model flexibility is desired
- Default model selection is appropriate

### Runtime Override Flags

Users can override the agent's default model at invocation time using flags on `/research`, `/plan`, and `/implement` commands. There are two independent flag dimensions:

**Effort flags** (how deeply the model reasons):

| Flag | Behavior |
|------|----------|
| `--fast` | Low-effort mode: lighter reasoning, faster responses |
| `--hard` | High-effort mode: deeper reasoning, more thorough analysis |

**Model flags** (which model family to use):

| Flag | Maps to | Behavior |
|------|---------|----------|
| `--haiku` | `haiku` | Use Haiku model (fastest, lowest cost) |
| `--sonnet` | `sonnet` | Use Sonnet model (balanced cost/quality) |
| `--opus` | `opus` | Use Opus model (highest quality, same as default) |

Effort and model flags are independent and can be combined. For example, `--fast --opus` uses Opus with low-effort reasoning. If no model flag is provided, the agent's frontmatter default is used (currently opus for all agents). If no effort flag is provided, normal effort is used.

If multiple flags of the same dimension are provided, the last one wins. These flags are passed as `model_flag` and `effort_flag` in the delegation context to the skill and subagent.

**Examples**:
```
/research 42 --opus        # Force Opus (same as default)
/research 42 --sonnet      # Use Sonnet for cost savings
/research 42 --haiku       # Use Haiku for speed
/implement 42 --hard       # Deep reasoning with default model (Opus)
/implement 42 --fast       # Light reasoning with default model (Opus)
/plan 42 --fast --sonnet   # Light reasoning with Sonnet
```

### Examples

```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
model: opus
---
```

**Rationale**: All agents use Opus as the default for highest quality. Use `--sonnet` or `--haiku` at invocation time for cost savings on simpler tasks.

```yaml
---
name: lean-research-agent
description: Research and prove Lean4 theorems
model: opus
---
```

**Rationale**: Lean4 proof work requires deep mathematical reasoning; Opus provides superior capabilities for formal verification.

## Validation

Agent frontmatter is validated during:
1. Agent file creation (via `/meta` command)
2. Agent invocation (by skill preflight)

### Validation Rules

1. `name` must be present and non-empty
2. `description` must be present and non-empty
3. `model`, if present, must be one of: `opus`, `sonnet`, `haiku`

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

### Lean4 Research Agent

```yaml
---
name: lean-research-agent
description: Research and prove Lean4 theorems using Mathlib
model: opus
---
```

## Migration

To add model enforcement to existing agents:

1. Open agent file (e.g., `.claude/agents/general-research-agent.md`)
2. Add `model: opus` to frontmatter (default for all agents)
3. Document rationale in agent comments

No other changes are required - the Task tool will respect the model field when spawning agents.

## Related Documentation

- [Creating Agents Guide](.claude/docs/guides/creating-agents.md)
- [Agent Template](.claude/docs/templates/agent-template.md)
- [Context Discovery Patterns](.claude/context/patterns/context-discovery.md)
