# Agent File Structure Standard

**Version**: 1.0.1
**Created**: 2026-01-23
**Scope**: All `.opencode/agent/*.md` files.

## Overview

This standard defines the required YAML frontmatter and XML-structured body layout for agent files.

## YAML Frontmatter (Required)

```yaml
---
description: "Brief description of the agent"
mode: subagent
temperature: 0.2
tools:
  read: true
  write: true
  edit: false
  glob: true
  grep: true
  bash: false
permissions:
  read:
    "**/*.md": "allow"
    ".opencode/**/*": "allow"
  write:
    "specs/**/*": "allow"
  bash:
    "*": "deny"
---
```

## XML Body Structure

```xml
<context>
  <system_context>...</system_context>
  <domain_context>...</domain_context>
  <task_context>...</task_context>
  <execution_context>...</execution_context>
</context>

<role>
  ...
</role>

<task>
  ...
</task>

<workflow_execution>
  <stage id="1" name="InputValidation">...</stage>
  <stage id="2" name="ContextLoading">...</stage>
  <stage id="3" name="Execution">...</stage>
  <stage id="4" name="Postflight">...</stage>
</workflow_execution>

<validation>
  <checks>...</checks>
</validation>

<error_handling>
  <errors>...</errors>
</error_handling>
```

## Required Sections

- `<context>` with system, domain, task, and execution sub-tags.
- `<role>` describing agent identity.
- `<task>` describing objective.
- `<workflow_execution>` with ordered stages.
- `<validation>` describing checks.
- `<error_handling>` describing recovery.

## Notes

- Use XML tags consistently.
- Avoid markdown headings inside the XML body; headings should be outside XML blocks.
