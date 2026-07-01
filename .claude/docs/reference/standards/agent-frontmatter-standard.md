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

### Tiered Model Policy

Agents use a three-tier model assignment based on task complexity:

| Tier | Model | When to Use | Examples |
|------|-------|-------------|---------|
| **Deep Reasoning** | `opus` | Complex analytical, planning, or formal reasoning tasks | planner-agent, meta-builder-agent, reviser-agent, lean/formal/math/logic agents |
| **General Purpose** | `sonnet` | Pattern-execution, research, implementation, and review tasks | general-research-agent, general-implementation-agent, code-reviewer-agent, spawn-agent, domain research/implementation agents |
| **Inherit** | (omitted) | Utility agents where model flexibility is desired | Agents that should respect `CLAUDE_CODE_SUBAGENT_MODEL` env var |

Sonnet 5 delivers near-Opus quality on most pattern-execution work, including coding and agentic tasks; Opus remains the choice for deep analytical reasoning, multi-step planning, and formal verification.

Users can override the model at invocation time using model flags (`--haiku`, `--sonnet`, `--opus`) for cost/speed tradeoffs on specific tasks.

### Values

| Value | Use Case | Rationale |
|-------|----------|-----------|
| `opus` | Deep reasoning agents (planning, formal verification, system architecture) | Superior analytical and multi-step reasoning capabilities |
| `sonnet` | General-purpose agents (research, implementation, review) | Near-Opus quality at lower cost; suitable for pattern-execution tasks |
| `haiku` | Lightweight tasks when specified via `--haiku` | Fastest, lowest cost, suitable for simple tasks |
| (omitted) | Utility agents, inherits from environment | Respects `CLAUDE_CODE_SUBAGENT_MODEL` env var |

### Usage Guidelines

**Use `model: opus` for**:
- Planning and architecture agents (planner-agent, meta-builder-agent, reviser-agent)
- Formal reasoning agents (lean, formal, logic, math, physics)
- Legal analysis agents (complex document reasoning)
- **Orchestrator commands** (`/research`, `/plan`, `/implement`): these commands run long multi-task sessions that accumulate context from many sequential sub-agent summaries. Both `model: opus` and `model: sonnet` now receive the native 1M-token context window (Anthropic's current catalog ships 1M context at standard pricing for both Opus 4.8 and Sonnet 5, no premium or beta header required — verify empirically via `/context` if behavior seems inconsistent). Context size alone no longer requires `model: opus` here; `model: opus` may still be preferred for these commands when the *reasoning depth* of orchestration decisions (not context capacity) justifies it. Domain worker agents dispatched by these commands remain `model: sonnet` per their own frontmatter.

**Use `model: sonnet` for**:
- General research and implementation agents (they have their own fresh context per invocation)
- Code review and spawn agents
- Domain-specific research and implementation (neovim, nix, epi, presentation, etc.)

**Omit model field when**:
- Model flexibility is desired
- The agent should inherit from `CLAUDE_CODE_SUBAGENT_MODEL` environment variable

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

Effort and model flags are independent and can be combined. For example, `--fast --opus` uses Opus with low-effort reasoning. If no model flag is provided, the agent's frontmatter default is used (opus for deep-reasoning agents, sonnet for general-purpose agents). If no effort flag is provided, normal effort is used.

If multiple flags of the same dimension are provided, the last one wins. These flags are passed as `model_flag` and `effort_flag` in the delegation context to the skill and subagent.

**Examples**:
```
/research 42 --opus        # Force Opus (same as default for research/plan/implement commands)
/research 42 --sonnet      # Use Sonnet on research sub-agent (overrides default Sonnet for general-research-agent)
/research 42 --haiku       # Use Haiku for speed
/implement 42 --hard       # Deep reasoning at high effort (model per command frontmatter; --opus to force Opus)
/implement 42 --fast       # Light reasoning with default model
/plan 42 --fast --sonnet   # Light reasoning with Sonnet (overrides Opus command, uses Sonnet for planner sub-agent)
```

### Examples

```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
model: sonnet
---
```

**Rationale**: General research is pattern-execution work; Sonnet provides near-Opus quality at lower cost. Use `--opus` at invocation time for complex research tasks.

```yaml
---
name: lean-research-agent
description: Research and prove Lean4 theorems
model: opus
---
```

**Rationale**: Lean4 proof work requires deep mathematical reasoning; Opus provides superior capabilities for formal verification.

```yaml
---
name: planner-agent
description: Create phased implementation plans from research findings
model: opus
---
```

**Rationale**: Planning requires multi-step analytical reasoning and architectural decisions; Opus excels at this complexity level.

## Validation

Agent frontmatter is validated during:
1. Agent file creation (via `/meta` command)
2. Agent invocation (by skill preflight)

### Validation Rules

1. `name` must be present and non-empty
2. `description` must be present and non-empty
3. `model`, if present, must be one of: `opus`, `sonnet`, `haiku`

## Examples

### General Research Agent (Sonnet tier)

```yaml
---
name: general-research-agent
description: Research general tasks using web search and codebase exploration
model: sonnet
---
```

### Implementation Agent (Sonnet tier)

```yaml
---
name: general-implementation-agent
description: Implement general, meta, and markdown tasks from plans
model: sonnet
---
```

### Planning Agent (Opus tier)

```yaml
---
name: planner-agent
description: Create phased implementation plans from research findings
model: opus
---
```

### Lean4 Research Agent (Opus tier)

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
2. Determine the appropriate tier (see Tiered Model Policy above)
3. Add `model: sonnet` or `model: opus` to frontmatter based on tier
4. Document rationale in agent comments

No other changes are required - the Agent tool will respect the model field when spawning agents.

## Related Documentation

- [Creating Agents Guide](.claude/docs/guides/creating-agents.md)
- [Agent Template](.claude/docs/templates/agent-template.md)
- [Context Discovery Patterns](.claude/context/patterns/context-discovery.md)
