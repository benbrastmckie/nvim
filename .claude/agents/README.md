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

## Agent Structure

All agents follow the minimal frontmatter format (see `.claude/docs/reference/standards/agent-frontmatter-standard.md`):

```yaml
---
name: agent-name
description: Brief description of agent purpose
model: opus
---
```

**Required fields**: `name`, `description`

**Optional field**: `model` (values: `opus`, `sonnet`). Omit for default model behavior. Research and planning agents typically use `opus`; implementation agents typically omit the field.

## Usage

Agents are invoked by skills, not directly by users. The orchestrator skill routes tasks to appropriate agents based on task type.

## Navigation

- [Parent Directory](../README.md)
- [CLAUDE.md](../CLAUDE.md) - Quick reference
