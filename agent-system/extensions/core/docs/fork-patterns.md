# Fork Patterns Reference Guide

**Created**: 2026-04-28
**Purpose**: Document fork mechanisms, prompt cache sharing, and delegation decision criteria
**Audience**: Skill authors, /meta agent, system maintainers

---

## Mechanism Overview

Two distinct "fork" concepts exist in Claude Code. They solve opposite problems.

### `context: fork` (skill frontmatter field)

**What it does**: Signals the Claude Code executor NOT to load CLAUDE.md context files or other
context-building steps before invoking the skill. The subagent loads its own context on demand.

**When it fires**: On every skill invocation where the frontmatter contains `context: fork`.

**Benefit**: Token efficiency — avoids loading context into the skill's conversation when the
subagent will load it fresh anyway.

**Typical users**: Extension skills (`skill-{ext}-research`, `skill-{ext}-implementation`),
`skill-meta` (uses `agent:` but not `context: fork`).

---

### `subagent_type: "fork"` (Agent tool parameter — current pattern)

**What it does**: Passing `subagent_type: "fork"` to the Agent tool spawns a forked subprocess
that inherits the parent's prompt cache. This is the **current, preferred** fork mechanism used
by `skill-orchestrate` for blocker research and drift inspection.

**Current state**: `skill-orchestrate` uses `subagent_type: "fork"` for its two fork dispatch
points, both reached via Move 2's `aux_dispatch[]` path (the `drift-inspection` and
`blocker-research` kinds — formerly Stage 5a drift inspection and Stage 6 blocker research).
This pattern was confirmed working
in an earlier lifecycle skill and is now unified across all fork dispatch sites.

**When to use**: Lightweight analysis tasks that benefit from cache sharing (e.g., reading a
plan file, researching a specific blocker). The fork inherits the parent's context without
requiring a specialized agent type — this is not a pure benefit; see "Fork Prompt Scoping
Hazard" below.

**Native tool withholding applies here too**: `AskUserQuestion` is withheld from a
`subagent_type: "fork"` dispatch identically to a plain `Agent` dispatch — confirmed by direct
live probe, not inferred from the cache-inheritance mechanism above. See
`agent-frontmatter-standard.md`'s "Tool Withholding from Dispatched Subagents" section for the
full measured probe matrix; this file does not duplicate that content.

---

### Fork Prompt Scoping Hazard (Measured)

A `subagent_type: "fork"` dispatch inherits the **entire** calling session's context, not just
the forking turn's own instructions. A fork prompt asking for one narrow diagnostic or probe
action can therefore autonomously resume or complete unrelated inherited work instead of
returning only the requested result — a positive instruction alone ("return X") is not
sufficient containment; the prompt also needs explicit **negative** scoping ("do not write
files, do not dispatch further agents, stop after step N").

Measured directly (2026-10-06): a first fork prompt, scoped only positively, inherited the
calling session's full in-flight task mandate and autonomously produced a complete, unrelated
deliverable set instead of the single requested probe result. A second attempt, adding explicit
negative scoping, returned exactly the intended single-line result.

**Mitigation**: any fork dispatch for a narrow diagnostic/probe action must state what the fork
must NOT do, not only what it should return.

---

### `CLAUDE_CODE_FORK_SUBAGENT=1` (environment variable — legacy)

**What it does**: When set, Agent/Agent tool invocations that **omit `subagent_type`** spawn a
forked subprocess that inherits the parent's prompt cache. This can reduce input token costs by
~90% for the child compared to a fresh session.

**Critical constraint**: Only fires when `subagent_type` is OMITTED. If `subagent_type` is
specified explicitly, the env var has no effect — a fresh agent is always launched.

**Current state**: Core skills always specify `subagent_type` explicitly (e.g.,
`subagent_type: "general-implementation-agent"`), so they are unaffected by this env var.
The `FORK_SUBAGENT` env var mechanism is obsolete and no longer used. Use
`subagent_type: "fork"` instead.

---

## Prompt Cache Sharing Mechanics

### How cache sharing works

When `CLAUDE_CODE_FORK_SUBAGENT=1` and `subagent_type` is omitted:
1. The child inherits the parent's cached prompt prefix.
2. The child pays near-zero input tokens for the shared prefix.
3. Each child generates its own output tokens and any unique context.

### Cost implications

| Scenario | Input token cost | Notes |
|----------|------------------|-------|
| Fresh agent (`subagent_type` specified) | Full cost | No cache sharing |
| Forked agent (no `subagent_type`) | ~10% of fresh | ~90% reduction via cache |

### Why core skills don't benefit today

Core skills (skill-reviser, skill-spawn, skill-meta, etc.) always pass
`subagent_type` explicitly to ensure the correct specialized agent is invoked. This is
intentional: structured context injection (session_id, delegation_depth, memory_context) requires
a known agent type. The trade-off is no FORK_SUBAGENT cache sharing.

---

## Decision Matrix: Which Delegation Pattern to Use

### Pattern A: Explicit Agent tool with `subagent_type` (core skill pattern)

```yaml
---
name: skill-reviser
description: Thin wrapper that delegates plan revision to reviser-agent subagent.
allowed-tools: Agent, Bash, Edit, Read, Write, Glob, Grep
---
```

**Use when**:
- Skill needs to inject structured context (session_id, delegation_depth, memory_context)
- Skill has multi-stage postflight (status update, artifact linking, git commit)
- Agent type must be explicitly controlled
- Skill is a core workflow skill (research, plan, implement, revise, spawn)

**How delegation works**:
```
Tool: Agent
Parameters:
  subagent_type: "general-implementation-agent"
  prompt: [full structured context JSON + instructions]
```

---

### Pattern B: `context: fork` + `agent:` frontmatter (extension skill pattern)

```yaml
---
name: skill-lean-research
description: Research Lean4 patterns. Invoke for lean research tasks.
allowed-tools: Agent
context: fork
agent: lean-research-agent
---
```

**Use when**:
- Skill is a simple thin wrapper with minimal or no postflight
- No structured context injection needed (or handled inside the skill body)
- Extension skills where the agent carries all the logic
- Simpler delegation where the skill body only validates inputs and calls the agent

**How delegation works**:
```
Tool: Agent (implicitly routed via `agent:` frontmatter)
Prompt: simple task instructions (no structured context JSON required)
```

---

## Constraints and Incompatibilities

| Constraint | Details |
|------------|---------|
| Headless mode | `context: fork` may behave differently in `--headless` invocations |
| No recursive forks | A forked subagent cannot itself fork; nesting is not supported |
| `subagent_type` blocks FORK_SUBAGENT | Explicitly specifying `subagent_type` disables fork inheritance |
| `context: fork` ≠ FORK_SUBAGENT | These are independent mechanisms; one does not imply the other |
| `agent:` frontmatter | Works with or without `context: fork`; `skill-meta` uses `agent:` alone |
| Fork prompt scoping | A `subagent_type: "fork"` dispatch inherits the entire calling session's mandate; a narrow diagnostic fork prompt needs explicit negative scoping, not just a positive instruction — see "Fork Prompt Scoping Hazard" above |

---

---

## Related Documentation

- @.claude/context/architecture/system-overview.md - System architecture overview
- @.claude/context/patterns/thin-wrapper-skill.md - Thin wrapper pattern reference
- @.claude/context/templates/thin-wrapper-skill.md - Full skill template
- `.claude/docs/guides/creating-skills.md` - Step-by-step skill creation guide
