---
name: skill-neovim-implementation
description: Implement Neovim Lua configuration with validation. Invoke for neovim-language implementation.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: neovim-implementation-agent
---

# Neovim Implementation Skill

Thin wrapper that delegates Neovim implementation to `neovim-implementation-agent`.

<context>
  <system_context>OpenCode Neovim implementation skill wrapper.</system_context>
  <task_context>Delegate Neovim implementation and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
</context_injection>

<role>Delegation skill for Neovim implementation workflows.</role>

<task>Validate inputs, delegate Neovim implementation, and update status/artifacts.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate task, status, and plan exists using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Invoke neovim-implementation-agent with injected context</action>
  </stage>
  <stage id="4" name="Postflight">
    <action>Update state and link artifacts using {file_metadata} and {jq_workarounds}</action>
  </stage>
</execution>

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

- Task language is neovim
- /implement command invoked
- Task has implementation plan

## Execution Flow

1. Validate task, status, and plan exists.
2. Update status to implementing.
3. Create postflight marker file.
4. Delegate to `neovim-implementation-agent` via Task tool.
5. Read metadata file and update state + TODO.
6. Link implementation artifacts and commit.
7. Clean up marker and metadata files.
