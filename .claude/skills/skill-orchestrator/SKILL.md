---
name: skill-orchestrator
description: Route commands to appropriate workflows based on task type and status. Invoke when executing /task, /research, /plan, /implement commands.
allowed-tools: Read, Glob, Grep, Task
# Context loaded on-demand via @-references (see Context Loading section)
---

# Orchestrator Skill

Central routing intelligence for the task management system.

## Context Loading

Load context on-demand when needed:
- `@.claude/context/orchestration/orchestration-core.md` - Routing, delegation, session tracking
- `@.claude/context/orchestration/state-management.md` - Task lookup and status validation
- `@.claude/context/index.json` - Full context discovery index

## Trigger Conditions

This skill activates when:
- A slash command needs task-type-based routing
- Task context needs to be gathered before delegation
- Multi-step workflows require coordination

## Core Responsibilities

### 1. Task Lookup

Given a task number, retrieve full context:
```
1. Read specs/state.json
2. Find task by project_number
3. Extract: task_type, status, project_name, description, priority
4. Read TODO.md for additional context if needed
```

### 2. Task-Type-Based Routing

Route to appropriate skill based on task type:

| Task Type | Research Skill | Implementation Skill |
|-----------|---------------|---------------------|
| general | skill-researcher | skill-implementer |
| meta | skill-researcher | skill-implementer |
| markdown | skill-researcher | skill-implementer |

**Note**: Additional languages (latex, typst) are available via extensions in `.claude/extensions/`.

### 3. Status Validation

Before routing, validate task status allows the operation:

| Operation | Allowed Statuses |
|-----------|------------------|
| research | not_started, planned, partial, blocked |
| plan | not_started, researched, partial |
| implement | planned, implementing, partial, researched |
| revise | planned, implementing, partial, blocked |

### 4. Context Preparation

Prepare context package for delegated skill:
```json
{
  "task_number": 259,
  "task_name": "task_slug",
  "task_type": "general",
  "status": "planned",
  "description": "Full task description",
  "artifacts": {
    "research": ["path/to/research.md"],
    "plan": "path/to/plan.md"
  },
  "focus_prompt": "Optional user-provided focus"
}
```

## Execution Flow

```
1. Receive command context (task number, operation type)
2. Lookup task in state.json
3. Validate status for operation
4. Determine target skill by task_type
5. Prepare context package
6. Invoke target skill via Task tool
7. Receive and validate result
8. Return result to caller
```

## Return Format

```json
{
  "status": "completed|partial|failed",
  "routed_to": "skill-name",
  "task_number": 259,
  "result": {
    "artifacts": [],
    "summary": "..."
  }
}
```

## Error Handling

- Task not found: Return clear error with suggestions
- Invalid status: Return error with current status and allowed operations
- Skill invocation failure: Return partial result with error details

---

## MUST NOT (Postflight Boundary)

After routing to a skill, this skill MUST NOT:

1. **Edit source files** - All work is done by routed skills/agents
2. **Run build/test commands** - Verification is done by routed skills/agents
3. **Update task status** - Status updates are done by routed skills
4. **Create artifacts** - Artifact creation is done by routed skills/agents

The orchestrator is a **routing-only** skill. It:
- Looks up task context
- Routes to appropriate skill based on task_type
- Passes through the routed skill's return

Reference: @.claude/context/standards/postflight-tool-restrictions.md
