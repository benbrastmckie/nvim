# Thin Wrapper Skill Pattern

**Version**: 1.0
**Created**: 2026-01-19
**Purpose**: Quick reference for the thin wrapper skill pattern
**Audience**: /meta agent, skill developers

---

## Overview

Thin wrapper skills are the standard pattern for workflow skills. They:
1. Validate inputs
2. Prepare delegation context
3. Invoke a subagent via Task tool
4. Validate and propagate the return

They do NOT:
- Load heavy context (subagent does this)
- Execute business logic (subagent does this)
- Handle complex error recovery (subagent does this)

---

## Frontmatter

```yaml
---
name: skill-{name}
description: {One-line description}
allowed-tools: Task
context: fork
agent: {agent-name}
---
```

**Key fields**:
- `allowed-tools: Task` - Only tool needed for delegation
- `context: fork` - Do NOT load context eagerly; subagent loads context
- `agent: {name}` - Target subagent to invoke

---

## Execution Pattern

### 1. Input Validation

Validate task exists and arguments are correct:

```bash
task_data=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)

if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi
```

### 2. Context Preparation

Generate session_id and prepare delegation context:

```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

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

### 3. Invoke Subagent

**CRITICAL**: Use the **Task** tool to spawn the subagent.

```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "{agent-name}" (from frontmatter)
  - prompt: [Include task_context, delegation_context]
  - description: "Execute {operation} for task {N}"
```

**DO NOT** use `Skill({agent-name})` - this will FAIL.
Agents live in `.opencode/agents/`, not `.opencode/skills/`.

### 4. Return Validation

Validate subagent return:
- Return is valid JSON
- Status is valid enum value
- Summary is non-empty and <100 tokens
- Artifacts array is present
- Session ID matches expected

### 5. Return Propagation

Return validated result to caller without modification.

---

## Example

```markdown
---
name: skill-lean-research
description: Research Lean 4 and Mathlib for theorem proving tasks.
allowed-tools: Task
context: fork
agent: lean-research-agent
---

# Lean Research Skill

Specialized research for Lean 4 theorem proving tasks.

## Trigger Conditions
- Task language is "lean"
- Research involves Mathlib, theorems, or proofs

## Execution

### 1. Input Validation
Extract task_number. Validate task exists.

### 2. Context Preparation
Generate session_id. Prepare delegation context.

### 3. Invoke Subagent
Use Task tool with subagent_type: lean-research-agent

### 4. Return Validation
Validate return matches subagent-return.md schema.

### 5. Return Propagation
Return validated result to caller.
```

---

## When NOT to Use This Pattern

Use direct execution instead when:
- Skill executes atomic operations (skill-status-sync)
- No subagent needed
- Work is trivial

Direct execution skills use:
```yaml
allowed-tools: Bash, Edit, Read
```

---

## Related Documentation

- @.opencode/context/core/templates/thin-wrapper-skill.md - Full template
- @.opencode/context/core/patterns/skill-lifecycle.md - Complete skill lifecycle
- @.opencode/context/core/formats/subagent-return.md - Return format
- @.opencode/docs/guides/creating-skills.md - Step-by-step guide
