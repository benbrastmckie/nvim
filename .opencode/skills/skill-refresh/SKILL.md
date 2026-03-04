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

<context_injection>
  <file path=".opencode/context/core/patterns/postflight-control.md" variable="postflight_control" />
</context_injection>

<role>Direct execution skill for cleanup workflows.</role>

<task>Execute refresh and cleanup operations.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Load cleanup rules from {postflight_control} for marker file patterns</action>
  </stage>
  <stage id="2" name="ScanOrphaned">
    <action>Scan for orphaned processes and temp directories</action>
  </stage>
  <stage id="3" name="Cleanup">
    <action>Clean marker files, temp directories, and orphaned processes</action>
  </stage>
  <stage id="4" name="Report">
    <action>Return summary of cleanup actions</action>
  </stage>
</execution>

<validation>Confirm cleanup results and safety checks.</validation>

<return_format>Return summary of cleanup actions.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.opencode/context/index.md` - Context discovery index

## Trigger Conditions

- /refresh command invoked
- Cleanup or session maintenance requested
