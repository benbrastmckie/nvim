# Agent Frontmatter Standard

**Created**: 2026-02-24
**Updated**: 2026-08-05
**Purpose**: Define YAML frontmatter requirements for agent files

## Overview

Agent files in `.claude/agents/` use YAML frontmatter to declare metadata that the Claude Code system and invoking skills use for agent selection, tool scoping, MCP server access, and capability discovery.

**Subagent frontmatter is a distinct field set from SKILL.md / slash-command frontmatter.**
The two are easy to conflate because both use YAML frontmatter and both have a field spelled
similarly, but `allowed-tools:` (skills/commands) and `tools:` (subagents) are not
interchangeable — see the Invalid on Agent Files section below for the two keys that have been
observed silently confused between the two contexts.

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

## Supported Fields

The complete set of frontmatter fields a subagent file may declare. The **Verified** column
states whether this field's effect has been confirmed by a live dispatch probe on this harness
(see "Tool Withholding from Dispatched Subagents" below) — `Unverified` is not a defect in the
field, only an honest statement that no probe has exercised it yet.

| Field | Type | Required | Description | Verified |
|-------|------|----------|-------------|----------|
| `name` | string | Yes | Agent identifier (e.g., `general-research-agent`) | — (required) |
| `description` | string | Yes | Brief description of agent purpose and capabilities | — (required) |
| `tools` | string | No | Tool allowlist. Comma-separated string, e.g. `tools: Read, Glob, Grep`. Omitting the field does **not** unconditionally grant every native tool — see the measured exception below. | **Measured** |
| `disallowedTools` | string | No | Tool denylist (camelCase). Comma-separated string of tools to exclude from the inherited set. | Unverified |
| `model` | string | No | Preferred model for this agent (`opus`, `sonnet`, `haiku`) | Unverified |
| `permissionMode` | string | No | Permission mode override for this agent's tool calls | Unverified |
| `maxTurns` | number | No | Maximum agentic turns before the agent is stopped | Unverified |
| `skills` | string | No | Skills this agent may invoke | Unverified |
| `mcpServers` | string/list | No | MCP server access declaration (camelCase — see Invalid on Agent Files below for the hyphenated misspelling to avoid) | Unverified |
| `hooks` | object | No | Lifecycle hook overrides for this agent | Unverified |
| `memory` | string | No | Memory access configuration | Unverified |
| `background` | boolean | No | Whether this agent runs as a background task | Unverified |
| `effort` | string | No | Reasoning effort override | Unverified |
| `color` | string | No | Display color for this agent in UI surfaces | Unverified |
| `initialPrompt` | string | No | Seed prompt injected before the agent's own instructions | Unverified |

**`isolation` removed (2026-10-06)**: this table formerly carried an `isolation` row (`string`,
`No`, "Isolation mode (e.g., `worktree`)"). It is removed outright, not merely marked unverified,
because nothing in the source store exercises it and the decisive behavioural question cannot be
measured here. Probe B: `grep -rn '^isolation:' agent-system/extensions/*/agents/` → no match —
no agent file declares the field. Probe C: `grep -n -i isolation
agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` → no match — the forwarding
prohibition that once fenced `isolation`/`worktree_path` off from the `Agent` tool call is gone,
deliberately, as part of a recorded byte-budget reclamation
(`context/config/orchestrator-context-budget.json`), not a regression. The decisive question —
whether the harness honours `isolation:` from an agent-definition frontmatter block at all,
independent of the `Agent` tool's own `isolation` call parameter — is **unverified and
deliberately not probed**: taking that probe would require dispatching an agent that requests a
worktree-isolated dispatch, which would re-arm two separately-tracked open defects —
`core/scripts/git-commit-scoped.sh` reports false success inside a worktree (`PROJECT_ROOT`
derived from `BASH_SOURCE[0]`, every pathspec WARN-and-dropped, nothing staged, exit 0) and
`core/scripts/lake-build-guard.sh` replays records across trees. This is removed as "removed; no
measurement supports it," never as "the harness does not support `isolation`" — a future
positive measurement can cleanly re-add the row. The row's two mirrors
(`scripts/lint/lint-agent-contracts.sh`'s `SUPPORTED_KEYS` entry, `docs/templates/agent-template.md`'s
field-name pointer list) are dropped in the same pass so neither asserts a row this table no
longer documents. The worktree isolation verdict itself
(`specs/decisions/worktree-isolation-removal-verdict.md`) is untouched and is not reopened by
this removal — this corrects a documentation row and a missing fence, never the decision.

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

### `tools:`, `disallowedTools:`, and `mcpServers:` Semantics

- **`tools:`** — an allowlist. The documented, verified-working form is a comma-separated
  string: `tools: Read, Glob, Grep`. Omitting the field does **not** mean the agent inherits
  every native tool unconditionally — see "Tool Withholding from Dispatched Subagents" below for
  the measured exception.
- **`disallowedTools:`** — a denylist (camelCase). Same comma-separated string form, naming
  tools to exclude from an otherwise-inherited set. Use this when an agent should have broad
  access minus a small number of excluded tools, rather than enumerating everything it may use.
  Whether omitting `disallowedTools:` behaves differently from omitting `tools:` with respect to
  the same withholding is **unverified** — see below.
- **`mcpServers:`** — camelCase. Declares which MCP servers this agent may call. See Invalid on
  Agent Files below for the hyphenated `mcp-servers:` spelling, which is not a real field.

### Tool Withholding from Dispatched Subagents (Measured)

**`AskUserQuestion` is categorically withheld from every `Agent`-tool dispatch of a named
`subagent_type`, independent of `tools:`/`disallowedTools:` configuration.** Measured directly,
across five live dispatches spanning four distinct configurations (probe:
`ToolSearch({query: "select:AskUserQuestion"})` inside the dispatched subagent):

| Configuration | Probe subject | Result |
|---|---|---|
| No `tools:` line (full inheritance per the table above) | `meta-builder-agent`, `general-research-agent` | `No matching deferred tools found` |
| Explicit `tools:` allowlist **naming** the tool | `literature-agent` (`tools: Bash, Read, Write, Edit, AskUserQuestion`) | Same result; the agent's own runtime tool grant measured as `Bash, Read, Write, Edit` only — `AskUserQuestion` silently dropped, and `ToolSearch` itself is also withheld, so the agent cannot even discover the omission |
| `subagent_type` registered with "All tools" (`Tools: *`) | `general-purpose` | Same result |
| `subagent_type: "fork"` (continuation of the calling agent's own context) | this agent's own context, forked, narrowly instructed to return only the probe result | Same result — confirmed by direct live probe, not inferred from `fork-patterns.md`'s documented mechanism |

So: an explicit allowlist naming the tool does not expose it; "All tools" registration does not
differ; a `fork` continuation does not differ either — all measured, not inferred. The pattern
reads as a harness-level policy on the tool itself (and possibly other native user-interaction
primitives — not independently tested), not a frontmatter-parsing distinction.

**Unverified**: whether `disallowedTools:` omission behaves differently from `tools:` omission
with respect to this withholding. The only two agent files in the source store that declare
`disallowedTools:` belong to an extension not loaded in the probing session, and neither
references `AskUserQuestion`, so there was no live dispatchable subject to test against. Given
the categorical pattern above, a frontmatter-parsing explanation is unlikely — but that is an
inference, not a measurement, and is labeled as such rather than rounded up to the categorical
result.

**Practical consequence**: no agent file should instruct itself to call `AskUserQuestion`, and no
`tools:`/`disallowedTools:` configuration can be relied on to expose it. Any user-choice point
needed by work that will be dispatched to a named `subagent_type` must be collected by the
*invoking skill*, in a stage that runs before the `Agent`-tool dispatch — see
`agent-system/extensions/present/skills/skill-slide-planning/SKILL.md` and
`agent-system/extensions/present/skills/skill-slide-critic/SKILL.md` for the proven working
shape, and `agent-system/extensions/core/docs/fork-patterns.md` for the pointer from the
fork-semantics documentation to this section.

### Invalid on Agent Files

These two keys look plausible but are **not valid subagent frontmatter fields**. Both are
silently ignored rather than rejected, which is why drift onto them goes unnoticed until an
audit catches it — the frontmatter still parses as valid YAML, but the value has no effect.

| Invalid key | Why it looks valid | Correct field |
|-------------|--------------------|----------------|
| `allowed-tools:` | Real field name — but only in SKILL.md / slash-command frontmatter, not subagent frontmatter | `tools:` |
| `mcp-servers:` | Hyphenated misspelling of the real camelCase field | `mcpServers:` |

An agent declaring `allowed-tools:` runs with **unrestricted inherited tool access** despite
apparently declaring a restriction — the key is parsed as an unrecognized frontmatter field and
has no scoping effect. An agent declaring `mcp-servers:` gets **no MCP server access** despite
apparently declaring one — the misspelled key is likewise ignored. Both are silent no-ops, not
errors, which is what allows them to go undetected in review.

### `@`-References Are Not Auto-Expanded

An agent body may contain `@`-style references (e.g. `` `@.claude/context/formats/foo.md` ``) as
pointer text. These are **not** framework-level auto-imports at subagent spawn time — the agent
must explicitly `Read` the referenced file itself if it needs the content. This is a common
source of confusion because `@`-imports do resolve automatically elsewhere (e.g. CLAUDE.md
loading), which invites the assumption that agent-body `@`-references behave the same way. They
do not; treat every `@`-reference in an agent body as a citation the agent must go read, never as
content that has already been injected.

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

Users can override the model at invocation time using model flags (`--haiku`, `--sonnet`, `--opus`, `--fable`) for cost/speed tradeoffs on specific tasks.

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
| `--fable` | `fable` | Use Fable model (claude-fable-5) |

Effort and model flags are independent and can be combined. For example, `--fast --opus` uses Opus with low-effort reasoning. If no model flag is provided, the agent's frontmatter default is used (opus for deep-reasoning agents, sonnet for general-purpose agents). If no effort flag is provided, normal effort is used.

If multiple flags of the same dimension are provided, the last one wins. These flags are passed as `model_flag` and `effort_flag` in the delegation context to the skill and subagent.

**Examples**:
```
/research 42 --opus        # Force Opus (same as default for research/plan/implement commands)
/research 42 --sonnet      # Use Sonnet on research sub-agent (overrides default Sonnet for general-research-agent)
/research 42 --haiku       # Use Haiku for speed
/research 42 --fable       # Use Fable model (claude-fable-5)
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
4. `allowed-tools:` and `mcp-servers:` (hyphenated) MUST NOT appear on any dispatchable agent
   file — see Invalid on Agent Files above; use `tools:` and `mcpServers:` respectively
5. `model:` is required on every dispatchable agent, per the Tiered Model Policy table above

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
