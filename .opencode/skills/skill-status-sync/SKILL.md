---
name: skill-status-sync
description: Atomically update task status across specs/TODO.md and specs/state.json.
allowed-tools: Bash, Edit, Read
---

# Status Sync Skill

Direct execution skill for atomic status synchronization across specs/TODO.md and specs/state.json.

<context>
  <system_context>OpenCode task status synchronization.</system_context>
  <task_context>Synchronize specs/TODO.md and specs/state.json statuses.</task_context>
</context>

<role>Direct execution skill for status updates.</role>

<task>Update specs/state.json and specs/TODO.md atomically.</task>

<execution>Use the Operation sections for status updates.</execution>

<validation>Confirm state/TODO updates and artifact links.</validation>

<return_format>Return JSON status result for sync operations.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq escaping patterns
- Path: `.opencode/context/index.md` - Context discovery index

## Standalone Use Only

Use this skill for manual status corrections or recovery operations. Workflow skills handle
preflight/postflight updates internally to avoid multi-skill halt boundaries.
