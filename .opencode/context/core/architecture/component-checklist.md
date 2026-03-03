# Component Checklist

**Version**: 1.0
**Created**: 2026-01-19
**Purpose**: Decision tree for creating commands, skills, and agents

---

## Command Checklist

Create a command when:

- User needs a new top-level action
- The action triggers a full lifecycle (preflight → delegate → postflight)
- It maps to an existing agent workflow

**Required**:
- Command file in `.opencode/commands/`
- Description and usage
- Delegation to skill (if needed)

---

## Skill Checklist

Create a skill when:

- You need to encapsulate a workflow lifecycle
- The command should stay thin
- You want reusable preflight/postflight logic

**Required**:
- Skill file in `.opencode/skills/`
- Thin-wrapper pattern
- Delegates to agent via Task tool

---

## Agent Checklist

Create an agent when:

- Domain-specific reasoning is required
- Artifact creation is part of workflow
- Work is long-running or complex

**Required**:
- Agent file in `.opencode/agent/`
- Context loading guidance
- Structured return format

---

## Related Documentation

- `@.opencode/context/core/architecture/system-overview.md`
- `@.opencode/context/core/patterns/thin-wrapper-skill.md`
- `@.opencode/context/core/formats/subagent-return.md`
