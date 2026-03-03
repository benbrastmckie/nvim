---
name: skill-lean-implementation
description: Implement Lean 4 proofs and definitions using lean-lsp tools. Invoke for Lean-language implementation tasks.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: lean-implementation-agent
---

# Lean Implementation Skill

Thin wrapper that delegates Lean proof implementation to `lean-implementation-agent`.

<context>
  <system_context>OpenCode Lean implementation skill wrapper.</system_context>
  <task_context>Delegate Lean implementation and coordinate postflight updates.</task_context>
</context>

<role>Delegation skill for Lean implementation workflows.</role>

<task>Validate inputs, delegate Lean implementation, and update status/artifacts.</task>

<execution>See Execution Flow for preflight/delegation/postflight steps.</execution>

<validation>Validate metadata file, summary artifact, and state updates.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/core/patterns/file-metadata-exchange.md` - Metadata handling
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq workaround patterns
- Path: `.opencode/context/index.md` - Context discovery index

## Trigger Conditions

- Task language is lean
- /implement command invoked

## Execution Flow

1. Validate task and status.
2. Update status to implementing.
3. Create postflight marker file.
4. Delegate to `lean-implementation-agent` via Task tool.
5. Read metadata file and update state + TODO.
6. Link summary artifact and commit.
7. Clean up marker and metadata files.
