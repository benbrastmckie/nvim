---
name: skill-refresh
description: Manage orphaned processes and project file cleanup.
allowed-tools: Bash, Edit, Read
---

# Refresh Skill

Direct execution skill for cleanup and session maintenance.

<context>
  <system_context>OpenCode cleanup and session maintenance.</system_context>
  <task_context>Clean orphaned processes and temporary directories.</task_context>
</context>

<role>Direct execution skill for cleanup workflows.</role>

<task>Execute refresh and cleanup operations.</task>

<execution>Follow the Execution steps for cleanup operations.</execution>

<validation>Confirm cleanup results and safety checks.</validation>

<return_format>Return summary of cleanup actions.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/index.md` - Context discovery index

## Trigger Conditions

- /refresh command invoked
- Cleanup or session maintenance requested
