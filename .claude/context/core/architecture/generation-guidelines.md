# Component Generation Guidelines

**Created**: 2026-01-19
**Purpose**: Guidelines and templates for /meta agent when generating new components
**Audience**: meta-builder-agent, system developers

---

## Overview

This document provides guidelines for generating new commands, skills, and agents. It is the primary reference for `/meta` command operations.

**Key principle**: Generate components that integrate seamlessly with the existing three-layer architecture.

---

## Pre-Generation Checklist

Before generating any component:

1. **Verify need** - Check no existing component handles the use case
2. **Determine component type(s)** - Use @.claude/context/core/architecture/component-checklist.md
3. **Identify dependencies** - What other components are needed?
4. **Review templates** - Load appropriate templates from core/templates/

---

## Command Generation

### Template Structure

```markdown
---
name: {command-name}
description: {One-line description of what the command does}
routing:
  lean: skill-{name}
  general: skill-{name}
  default: skill-{name}
---

# /{command-name} Command

{Brief description of command purpose and use cases.}

## Usage

```
/{command-name} TASK_NUMBER [options]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `TASK_NUMBER` | Yes | Task number to operate on |
| `[options]` | No | Additional options |

## Examples

```bash
# Basic usage
/{command-name} 259

# With options
/{command-name} 259 --option value
```

## Routing

| Language | Target Skill |
|----------|--------------|
| lean | skill-{name} |
| general | skill-{name} |
| default | skill-{name} |

## Error Handling

- **Task not found**: Display error with available tasks
- **Invalid arguments**: Display usage with examples
- **Skill failure**: Propagate error from skill
```

### Generation Rules for Commands

1. **Keep commands thin** - Only routing logic, no execution
2. **Provide examples** - At least 2 usage examples
3. **Document routing** - Clear language -> skill mapping
4. **Handle errors** - List common error cases

---

## Skill Generation (Thin Wrapper Pattern)

### Template Structure

```markdown
---
name: skill-{name}
description: {One-line description}
allowed-tools: Task
context: fork
agent: {agent-name}
---

# {Name} Skill

{One-line description of skill purpose.}

## Trigger Conditions

This skill activates when:
- {Condition 1}
- {Condition 2}

---

## Execution

### 1. Input Validation

Validate required inputs:
- `task_number` - Must exist in state.json
- `language` - Must match skill's domain

```bash
# Lookup task
task_data=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi
```

### 2. Context Preparation

Prepare delegation context:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": {current_depth + 1},
  "delegation_path": [..., "skill-{name}"],
  "timeout": {timeout_seconds},
  "task_context": {
    "task_number": N,
    "task_name": "{slug}",
    "description": "{description}",
    "language": "{language}"
  }
}
```

**Session ID generation**:
```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

### 3. Invoke Subagent

**CRITICAL**: Use the **Task** tool to spawn the subagent.

```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "{agent-name}"
  - prompt: [Include task_context, delegation_context]
  - description: "Execute {operation} for task {N}"
```

**DO NOT** use `Skill({agent-name})` - this will FAIL.

### 4. Return Validation

Validate subagent return:
- [ ] Return is valid JSON
- [ ] Status is valid enum value
- [ ] Summary is non-empty and <100 tokens
- [ ] Artifacts array is present
- [ ] Session ID matches expected

### 5. Return Propagation

Return validated result to caller without modification.

---

## Error Handling

### Input Validation Errors
Return immediately with error status.

### Subagent Invocation Errors
Pass through the subagent's error return.

### Timeout
Return partial status if subagent times out.
```

### Generation Rules for Skills

1. **Use thin wrapper pattern** - `context: fork`, `allowed-tools: Task`
2. **Always use Task tool** - Never Skill tool for agent invocation
3. **Include session_id generation** - Portable bash command
4. **Validate returns** - Check all required fields
5. **Document trigger conditions** - When does this skill activate?

---

## Agent Generation

### Template Structure

```markdown
---
name: {name}-agent
description: {One-line description}
---

# {Name} Agent

{Brief description of agent purpose and execution pattern.}

## Agent Metadata

- **Name**: {name}-agent
- **Purpose**: {What this agent does}
- **Invoked By**: skill-{name} (via Task tool)
- **Return Format**: JSON (see subagent-return.md)

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read source files and context documents
- Write - Create new files
- Edit - Modify existing files
- Glob - Find files by pattern
- Grep - Search file contents

### Domain-Specific Tools
- {Tool 1} - {Purpose}
- {Tool 2} - {Purpose}

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/context/core/formats/subagent-return.md` - Return format schema

**Load When Needed**:
- `@{path/to/context}` - {When to load}

## Execution Flow

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": N,
    "task_name": "{slug}",
    "description": "...",
    "language": "{language}"
  },
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 1,
    "delegation_path": [...]
  }
}
```

### Stage 2: Load Context

Load required context files based on task.

### Stage 3: Execute Workflow

{Describe the main execution steps}

### Stage 4: Create Artifacts

Write artifacts to proper locations:
```
specs/{NNN}_{SLUG}/{artifact_type}/{filename}
```

### Stage 5: Return Structured JSON

Return ONLY valid JSON:

```json
{
  "status": "{contextual_status}",
  "summary": "Brief 2-5 sentence summary (<100 tokens)",
  "artifacts": [
    {
      "type": "{type}",
      "path": "specs/{NNN}_{SLUG}/{path}",
      "summary": "Description of artifact"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": N,
    "agent_type": "{name}-agent",
    "delegation_depth": 1,
    "delegation_path": [...]
  },
  "next_steps": "{What to do next}"
}
```

---

## Error Handling

### {Error Type 1}
{How to handle}

### {Error Type 2}
{How to handle}

---

## Critical Requirements

**MUST DO**:
1. Always return valid JSON (not markdown narrative)
2. Always include session_id from delegation context
3. Always verify artifacts exist after creation
4. Always use contextual status values (researched, planned, implemented)

**MUST NOT**:
1. Return plain text instead of JSON
2. Skip artifact verification
3. Return the word "completed" as a status value (triggers Claude stop behavior)
4. Use phrases like "task is complete", "work is done", or "finished" in summaries
5. Assume your return ends the workflow (orchestrator continues with postflight)
```

### Generation Rules for Agents

1. **Include frontmatter** - Required for Claude Code recognition
2. **Document allowed tools** - List all tools the agent uses
3. **Use @-references** - For context loading
4. **Include execution stages** - Clear multi-stage workflow
5. **Include return format example** - Full JSON example
6. **Include anti-stop patterns** - In MUST NOT section
7. **Use contextual status values** - Never "completed"

---

## Anti-Stop Patterns Reference

When generating any component, reference these critical patterns:

### Forbidden Status Values

| Forbidden | Replacement | Use Case |
|-----------|-------------|----------|
| `"completed"` | `"researched"` | Research operations |
| `"completed"` | `"planned"` | Planning operations |
| `"completed"` | `"implemented"` | Implementation operations |
| `"completed"` | `"synced"` | Status sync operations |
| `"done"` | Use contextual value | Any operation |
| `"finished"` | Use contextual value | Any operation |

### Forbidden Phrases

| Forbidden | Safe Alternative |
|-----------|-----------------|
| "Task complete" | "Implementation finished. Run /task --sync to verify." |
| "Task is done" | "Research concluded. Artifacts created." |
| "Work is finished" | "Plan created. Ready for implementation." |
| "All done" | "Operation concluded. Orchestrator continues." |

**Full reference**: @.claude/context/core/patterns/anti-stop-patterns.md

---

## Post-Generation Verification

After generating a component, verify:

### 1. File Location
```bash
# Command
ls .claude/commands/{name}.md

# Skill
ls .claude/skills/skill-{name}/SKILL.md

# Agent
ls .claude/agents/{name}-agent.md
```

### 2. Frontmatter Validity
```bash
# Check YAML is valid (first --- to second ---)
head -20 {file_path}
```

### 3. Anti-Stop Compliance
```bash
# Should return 0 matches for generated agent
grep '"status": "completed"' .claude/agents/{name}-agent.md
```

### 4. Task Tool Usage (Skills)
```bash
# Should find Task tool reference
grep -i "task tool" .claude/skills/skill-{name}/SKILL.md
```

---

## Integration Points

When generating components, ensure integration with:

### State Management
- Read task data from `specs/state.json`
- Task artifacts go in `specs/OC_{NNN}_{SLUG}/`
- Use skill-status-sync for status updates

### Git Workflow
- Commits created via skill-git-workflow
- Commit messages include session_id
- Format: `task {N}: {action}`

### Checkpoint Execution
- GATE IN: Preflight validation, status update
- DELEGATE: Skill invokes agent
- GATE OUT: Postflight validation, artifact linking
- COMMIT: Git commit with session_id

---

## Related Documentation

- @.claude/context/core/architecture/system-overview.md - Architecture overview
- @.claude/context/core/architecture/component-checklist.md - When to create what
- @.claude/context/core/templates/thin-wrapper-skill.md - Skill template
- @.claude/context/core/templates/subagent-template.md - Agent template
- @.claude/context/core/patterns/anti-stop-patterns.md - Critical patterns
- @.claude/context/core/formats/subagent-return.md - Return format
