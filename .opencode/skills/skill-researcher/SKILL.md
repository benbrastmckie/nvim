---
name: skill-researcher
description: Conduct general research using web search, documentation, and codebase exploration. Invoke for non-Lean research tasks.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: general-research-agent
---

# Researcher Skill

Thin wrapper that delegates research to `general-research-agent`.

<context>
  <system_context>OpenCode research skill wrapper.</system_context>
  <task_context>Delegate research and coordinate postflight updates.</task_context>
</context>

<role>Delegation skill for general research workflows.</role>

<task>Validate inputs, delegate research, and update status/artifacts.</task>

<execution>See Execution Flow for preflight/delegation/postflight steps.</execution>

<validation>Validate metadata file, report artifact, and state updates.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/core/patterns/file-metadata-exchange.md` - Metadata handling
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq workaround patterns
- Path: `.opencode/context/index.md` - Context discovery index

## Trigger Conditions

- Task language is general, meta, markdown, or latex
- /research command invoked

## Execution Flow

1. Validate task and status.
2. Update status to researching.
3. Create postflight marker file.
4. Delegate to `general-research-agent` via Task tool.
5. Read metadata file and update state + TODO.
6. Link research artifact and commit.
7. Clean up marker and metadata files.
