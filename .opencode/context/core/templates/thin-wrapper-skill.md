# Thin Wrapper Skill Template

**Purpose**: Standard structure for skills that delegate to forked subagents
**Version**: 1.0
**Created**: 2026-01-12

---

## Overview

This template defines the minimal structure for skills that use the `context: fork` pattern. These skills act as thin wrappers that:
1. Validate inputs
2. Prepare delegation context
3. Invoke a subagent via Task tool
4. Validate and propagate the return

Thin wrapper skills do NOT:
- Load heavy context (that's the subagent's job)
- Execute business logic (that's the subagent's job)
- Handle complex error recovery (that's the subagent's job)

---

## Frontmatter Format

```yaml
---
name: skill-{name}
description: {Brief description of skill purpose}
allowed-tools: Task
context: fork
agent: {subagent-name}
# Original context (now loaded by subagent):
#   - {path/to/context/file.md}
# Original tools (now used by subagent):
#   - {Tool1}, {Tool2}, ...
---
```

### Field Specifications

| Field | Value | Purpose |
|-------|-------|---------|
| `allowed-tools` | `Task` | Only tool needed for delegation |
| `context` | `fork` | Signal to NOT load context eagerly |
| `agent` | `{name}` | Subagent to invoke |

---

## Body Structure

```markdown
# {Skill Name} Skill

{One-line description}

## Trigger Conditions

This skill activates when:
- {Condition 1}
- {Condition 2}

---

## Execution

### 1. Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in specs/state.json
- `focus_prompt` - Optional additional context

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
  "timeout": {appropriate_timeout},
  "task_context": {
    "task_number": N,
    "task_name": "{slug}",
    "description": "{description}",
    "language": "{language}"
  },
  "focus_prompt": "{optional focus}"
}
```

**Session ID generation**:
```bash
# Portable command (works on NixOS, macOS, Linux - no xxd dependency)
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

### 3. Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

The `agent` field in frontmatter specifies the target subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "{agent-name}" (from frontmatter)
  - prompt: [Include task_context, delegation_context, focus_prompt if present]
  - description: "Execute {operation} for task {N}"
```

**DO NOT** use `Skill({agent-name})` - this will FAIL.
Agents live in `.opencode/agents/`, not `.opencode/skills/`.
The Skill tool can only invoke skills from `.opencode/skills/`.

### 4. Return Validation

Validate subagent return matches schema from `subagent-return.md`:

```json
{
  "status": "completed|partial|failed|blocked",
  "summary": "...",
  "artifacts": [...],
  "metadata": {
    "session_id": "...",  // Must match expected
    "agent_type": "...",
    "delegation_depth": N,
    "delegation_path": [...]
  },
  "errors": [...],
  "next_steps": "..."
}
```

**Validation checks**:
- [ ] Return is valid JSON
- [ ] Status is valid enum value
- [ ] Summary is non-empty and <100 tokens
- [ ] Artifacts array is present (may be empty)
- [ ] Metadata contains required fields
- [ ] Session ID matches expected

### 5. Return Propagation

Return validated result to caller without modification.

If validation fails:
```json
{
  "status": "failed",
  "summary": "Subagent return validation failed",
  "artifacts": [],
  "metadata": {...},
  "errors": [
    {
      "type": "validation",
      "message": "Invalid return format from subagent",
      "recoverable": true,
      "recommendation": "Check subagent implementation"
    }
  ]
}
```

---

## Return Format

Skills return the subagent's return verbatim (pass-through).

See `.opencode/context/core/formats/subagent-return.md` for full specification.

---

## Error Handling

### Input Validation Errors
Return immediately with error status:
```json
{
  "status": "failed",
  "summary": "Input validation failed: {reason}",
  "artifacts": [],
  "errors": [{...}]
}
```

### Subagent Invocation Errors
Pass through the subagent's error return.

### Timeout
Return partial status if subagent times out.

---

## Example: Research Skill

```yaml
---
name: skill-lean-research
description: Research Lean 4 and Mathlib for theorem proving tasks.
allowed-tools: Task
context: fork
agent: lean-research-agent
---
```

```markdown
# Lean Research Skill

Specialized research for Lean 4 theorem proving tasks.

## Trigger Conditions
- Task language is "lean"
- Research involves Mathlib, theorems, or proofs

## Execution

### 1. Input Validation
Extract task_number from arguments.
Validate task exists in specs/state.json.
Extract optional focus_prompt.

### 2. Context Preparation
Generate session_id.
Prepare delegation context with task details.

### 3. Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "lean-research-agent"
  - prompt: [Include task_context, delegation_context, focus_prompt if present]
  - description: "Execute Lean research for task {N}"
```

**DO NOT** use `Skill(lean-research-agent)` - this will FAIL.

### 4. Return Validation
Validate return matches subagent-return.md schema.

### 5. Return Propagation
Return validated result to caller.

## Return Format
See subagent-return.md
```

---

## Related Standards

- `subagent-return.md` - Return format specification
- `delegation.md` - Delegation patterns and safety
- `frontmatter.md` - Frontmatter specification
