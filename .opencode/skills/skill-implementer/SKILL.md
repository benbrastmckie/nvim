---
name: skill-implementer
description: Execute general implementation tasks following a plan. Invoke for non-Lean implementation work.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: general-implementation-agent
---

# Implementer Skill

Thin wrapper that delegates implementation to `general-implementation-agent`.

<context>
  <system_context>OpenCode implementation skill wrapper.</system_context>
  <task_context>Delegate implementation and coordinate postflight updates.</task_context>
</context>

<role>Delegation skill for general implementation workflows.</role>

<task>Validate inputs, delegate implementation, and update status/artifacts.</task>

<execution>See Execution Flow for preflight/delegation/postflight steps.</execution>

<validation>Validate metadata file, summary artifact, and state updates.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/core/patterns/file-metadata-exchange.md` - Metadata file handling
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq workaround patterns
- Path: `.opencode/context/index.md` - Context discovery index

## Trigger Conditions

- Task language is general, meta, markdown
- /implement command invoked

## Execution Flow

1. Validate task and status.
2. Update status to implementing.
3. Create postflight marker file.
4. Delegate to `general-implementation-agent` via Task tool.
5. Read metadata file and update state + TODO.
6. Link summary artifact and commit.
7. Clean up marker and metadata files.
