---
name: skill-document-converter
description: Convert documents to markdown.
allowed-tools: Task, Bash, Edit, Read, Write
context: fork
agent: document-converter-agent
---

# Document Converter Skill

Thin wrapper that delegates document conversion to `document-converter-agent`.

<context>
  <system_context>OpenCode skill wrapper for document conversion.</system_context>
  <task_context>Delegate conversion work and coordinate metadata handling.</task_context>
</context>

<role>Delegation skill for document conversion workflows.</role>

<task>Validate inputs, delegate to the conversion agent, and summarize results.</task>

<execution>See Execution Flow for delegation steps.</execution>

<validation>Validate metadata file and required artifacts.</validation>

<return_format>Brief text summary; metadata file in `specs/{N}_{SLUG}/.return-meta.json`.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.opencode/context/core/formats/subagent-return.md` - Return validation
- Path: `.opencode/context/index.md` - Context discovery index

## Trigger Conditions

- /convert command invoked
- User requests file format conversion
- Plan step mentions converting PDF/DOCX/HTML/Markdown

## Execution Flow

1. Validate input paths and infer output path if missing.
2. Prepare delegation context with session metadata.
3. Invoke `document-converter-agent` via Task tool.
4. Validate metadata file and return summary.

## Return Format

Return brief text summary. The agent writes metadata to `specs/{N}_{SLUG}/.return-meta.json`.
