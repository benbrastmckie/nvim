---
name: skill-meta
description: Interactive system builder. Invoke for /meta command to create tasks for .opencode system changes.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: meta-builder-agent
---

# Meta Skill

Thin wrapper that delegates system building to `meta-builder-agent`.

<context>
  <system_context>OpenCode meta skill wrapper.</system_context>
  <task_context>Delegate system analysis and task creation.</task_context>
</context>

<context_injection>
  <file path=".opencode/context/core/formats/return-metadata-file.md" variable="return_metadata" />
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
  <file path=".opencode/context/core/patterns/file-metadata-exchange.md" variable="file_metadata" />
</context_injection>

<role>Delegation skill for meta workflows.</role>

<task>Determine mode, delegate to meta-builder agent, and coordinate postflight.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Read context files defined in <context_injection></action>
  </stage>
  <stage id="2" name="DetermineMode">
    <action>Determine mode (interactive/prompt/analyze)</action>
  </stage>
  <stage id="3" name="Delegate">
    <action>Invoke meta-builder-agent with injected context using {return_metadata} and {postflight_control}</action>
  </stage>
  <stage id="4" name="Postflight">
    <action>If tasks created, perform postflight updates and commit using {file_metadata}</action>
  </stage>
</execution>

<validation>Validate metadata file and created tasks.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/core/patterns/file-metadata-exchange.md` - Metadata handling
- Path: `.opencode/context/index.md` - Context discovery index

## Trigger Conditions

- /meta command invoked
- System analysis requested

## Execution Flow

1. Determine mode (interactive/prompt/analyze).
2. Delegate to `meta-builder-agent` via Task tool.
3. If tasks created, perform postflight updates and commit.
4. Return validated result.
