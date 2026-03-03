---
name: skill-orchestrator
description: Route commands to appropriate workflows based on task language and status.
allowed-tools: Read, Glob, Grep, Task
---

# Orchestrator Skill

Central routing for task workflows. Delegates to research, plan, implement, and meta skills based on task language.

<context>
  <system_context>OpenCode routing and task orchestration.</system_context>
  <task_context>Route tasks to appropriate skills based on language and status.</task_context>
</context>

<role>Routing skill for command workflows.</role>

<task>Validate task context and route to the correct skill.</task>

<execution>Follow Execution Flow steps for routing.</execution>

<validation>Validate task status and language routing decisions.</validation>

<return_format>Return structured routing result.</return_format>

## Context Loading

Load context on-demand when needed:
- `@.opencode/context/core/orchestration/orchestration-core.md` - Routing, delegation, session tracking
- `@.opencode/context/core/orchestration/state-management.md` - Task lookup and status validation
- `@.opencode/context/index.md` - Context discovery index

## Trigger Conditions

- A slash command needs language-based routing
- Task context needs gathering before delegation

## Execution Flow

1. Lookup task in `specs/state.json`.
2. Validate status for requested operation.
3. Route to appropriate skill based on language.
4. Return structured result to caller.
