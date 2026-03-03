---
name: skill-latex-implementation
description: Implement LaTeX documents following a plan. Invoke for LaTeX-language implementation tasks.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: latex-implementation-agent
---

# LaTeX Implementation Skill

Thin wrapper that delegates LaTeX document implementation to `latex-implementation-agent`.

<context>
  <system_context>OpenCode LaTeX implementation skill wrapper.</system_context>
  <task_context>Delegate LaTeX implementation and coordinate postflight updates.</task_context>
</context>

<role>Delegation skill for LaTeX implementation workflows.</role>

<task>Validate inputs, delegate LaTeX implementation, and update status/artifacts.</task>

<execution>See Execution Flow for preflight/delegation/postflight steps.</execution>

<validation>Validate metadata file, summary artifact, and state updates.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Trigger Conditions

- Task language is latex
- /implement command invoked

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/core/patterns/file-metadata-exchange.md` - Metadata handling
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq workaround patterns
- Path: `.opencode/context/index.md` - Context discovery index

## Trigger Conditions

- Task language is latex
- /implement command invoked

## Execution Flow

1. Validate task and status.
2. Update status to implementing.
3. Create postflight marker file.
4. Delegate to `latex-implementation-agent` via Task tool.
5. Read metadata file and update state + TODO.
6. Link summary artifact and commit.
7. Clean up marker and metadata files.
