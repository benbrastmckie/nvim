---
name: skill-neovim-research
description: Research Neovim plugins, Lua configuration, and vimscript. Invoke for neovim-language research.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: neovim-research-agent
---

# Neovim Research Skill

Thin wrapper that delegates Neovim research to `neovim-research-agent`.

<context>
  <system_context>OpenCode Neovim research skill wrapper.</system_context>
  <task_context>Delegate Neovim research and coordinate postflight updates.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
</context_injection>

<role>Delegation skill for Neovim research workflows.</role>

<task>Validate inputs, delegate Neovim research, and update status/artifacts.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="Preflight">
    <action>Validate task and status using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Invoke neovim-research-agent with injected context</action>
  </stage>
  <stage id="4" name="Postflight">
    <action>Update state and link artifacts using {file_metadata} and {jq_workarounds}</action>
  </stage>
</execution>

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

- Task language is neovim
- /research command invoked

## Execution Flow

1. Validate task and status.
2. Update status to researching.
3. Create postflight marker file.
4. Delegate to `neovim-research-agent` via Task tool.
5. Read metadata file and update state + TODO.
6. Link research artifact and commit.
7. Clean up marker and metadata files.
