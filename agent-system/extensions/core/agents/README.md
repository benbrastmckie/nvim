# Agents

Agent definitions for the Claude Code system. Agents perform execution work for research, implementation, and specialized tasks.

## Agent Files

| Agent | Purpose |
|-------|---------|
| general-research-agent.md | General web/codebase research with web search capabilities |
| general-implementation-agent.md | General file implementation and editing |
| planner-agent.md | Implementation plan creation and task planning |
| meta-builder-agent.md | System building for .claude/ architecture changes |
| code-reviewer-agent.md | Code quality assessment and review |
| reviser-agent.md | Plan revision and task description updates |
| spawn-agent.md | Blocker analysis and task decomposition |
| scout-agent.md | Read-only strategic orientation brief, dispatched on demand from `/review --brief` |

## Agent Structure

All agents follow the minimal frontmatter format (see `.claude/docs/reference/standards/agent-frontmatter-standard.md`):

```yaml
---
name: agent-name
description: Brief description of agent purpose
model: sonnet
---
```

**Required fields**: `name`, `description`

**Optional field**: `model` (values: `opus`, `sonnet`). Agents use a tiered model policy:
- **Opus**: Deep reasoning agents -- planner-agent, meta-builder-agent, reviser-agent, formal/lean/math/logic agents
- **Sonnet**: General-purpose agents -- research, implementation, review, spawn, and domain-specific agents
- **Omit**: Utility agents that should inherit from `CLAUDE_CODE_SUBAGENT_MODEL` env var

## Usage

Agents are invoked by skills, not directly by users. The orchestrator skill routes tasks to appropriate agents based on task type.

## Navigation

- [Parent Directory](../README.md)
- [CLAUDE.md](../CLAUDE.md) - Quick reference
