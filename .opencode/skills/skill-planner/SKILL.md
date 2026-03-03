---
name: skill-planner
description: Create phased implementation plans from research findings. Invoke when a task needs an implementation plan.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: planner-agent
---

# Planner Skill

Thin wrapper that delegates plan creation to `planner-agent`.

<context>
  <system_context>OpenCode planning skill wrapper.</system_context>
  <task_context>Delegate planning and coordinate postflight updates.</task_context>
</context>

<role>Delegation skill for planning workflows.</role>

<task>Validate planning inputs, delegate plan creation, and update task state.</task>

<execution>See Execution Flow for preflight/delegation/postflight steps.</execution>

<validation>Validate metadata file, plan artifact, and status updates.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/core/patterns/file-metadata-exchange.md` - Metadata file handling
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq workaround patterns
- Path: `.opencode/context/index.md` - Context discovery index

## Trigger Conditions

- Task status allows planning
- /plan command invoked

## Execution Flow

1. Validate task and status.
2. Update status to planning.
3. Create postflight marker file.
4. Delegate to `planner-agent` via Task tool.
5. Read metadata file and update state + TODO.
6. Link plan artifact and commit.
7. Clean up marker and metadata files.
