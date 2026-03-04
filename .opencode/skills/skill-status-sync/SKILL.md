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

<context_injection>
  <file path="specs/TODO.md" variable="todo_file" />
  <file path="specs/state.json" variable="state_file" />
  <file path=".opencode/context/core/patterns/jq-escaping-workarounds.md" variable="jq_workarounds" />
</context_injection>

<role>Direct execution skill for status updates.</role>

<task>Update specs/state.json and specs/TODO.md atomically.</task>

<execution>
  <stage id="1" name="LoadContext">
    <action>Load {todo_file}, {state_file}, and {jq_workarounds} patterns</action>
  </stage>
  <stage id="2" name="Analyze">
    <action>Compare statuses between TODO.md and state.json</action>
  </stage>
  <stage id="3" name="Synchronize">
    <action>Apply atomic updates using jq patterns from {jq_workarounds}</action>
  </stage>
  <stage id="4" name="Validate">
    <action>Confirm state/TODO updates and return JSON result</action>
  </stage>
</execution>

<validation>Confirm state/TODO updates and artifact links.</validation>

<return_format>Return JSON status result for sync operations.</return_format>

## Context References

Reference (do not load eagerly):
- Path: `.opencode/context/core/patterns/jq-escaping-workarounds.md` - jq escaping patterns
- Path: `.opencode/context/index.md` - Context discovery index

## Standalone Use Only

Use this skill for manual status corrections or recovery operations. Workflow skills handle
preflight/postflight updates internally to avoid multi-skill halt boundaries.
