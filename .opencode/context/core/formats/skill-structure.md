# Skill File Structure Standard

**Version**: 1.0
**Created**: 2026-01-23
**Scope**: All `.opencode/skills/*/SKILL.md` files.

## Overview

This standard defines YAML frontmatter and XML body structure for skill files. Skills fall
into two categories: workflow skills (delegating to subagents with pre/postflight) and
direct execution skills. Skills should use XML blocks for execution logic consistent with
`.opencode/context/core/standards/xml-structure.md`.

## YAML Frontmatter (Required)

```yaml
---
name: skill-{name}
description: "Brief description"
allowed-tools: Task, Bash, Edit, Read
context: fork
agent: {subagent-name}
---
```

For direct execution skills, omit `context` and `agent`:

```yaml
---
name: skill-{name}
description: "Brief description"
allowed-tools: Bash, Edit, Read
---
```

## XML Body Structure

```xml
<context>
  <system_context>...</system_context>
  <task_context>...</task_context>
</context>

<role>
  ...
</role>

<task>
  ...
</task>

<execution>
  <stage id="1" name="Preflight">...</stage>
  <stage id="2" name="Delegate">...</stage>
  <stage id="3" name="Postflight">...</stage>
</execution>

<validation>
  <checks>...</checks>
</validation>

<return_format>
  ...
</return_format>
```

## Required Sections

- `<context>` and `<task>` blocks.
- `<execution>` with explicit stages.
- `<validation>` describing status checks.

## Notes

- Workflow skills should follow `.opencode/context/core/patterns/skill-lifecycle.md`.
- Thin wrapper skills should follow `.opencode/context/core/templates/thin-wrapper-skill.md`.
- Use XML tags for consistent formatting.
