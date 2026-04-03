---
description: Create new version of implementation plan, or update task description if no plan exists
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(jq:*), Bash(git:*), TaskCreate, TaskUpdate
argument-hint: TASK_NUMBER [REASON]
model: opus
---

# /revise Command

Create a new version of an implementation plan, or update task description if no plan exists.

**Artifact Numbering Note**: Plan revision creates a new plan file within the same artifact round. The revised plan uses the SAME artifact number (not incremented) because it replaces the previous plan in the same round. Only `/research` advances the artifact number to start a new round.

## Arguments

- `$1` - Task number (required)
- Remaining args - Optional reason for revision

## Execution

### CHECKPOINT 1: GATE IN

1. **Generate Session ID**
   ```
   session_id = sess_{timestamp}_{random}
   ```

2. **Lookup Task**
   ```bash
   task_data=$(jq -r --arg num "$task_number" \
     '.active_projects[] | select(.project_number == ($num | tonumber))' \
     specs/state.json)
   ```

3. **Validate and Route**
   - Task exists (ABORT if not)
   - Route based on status:

   | Status | Action |
   |--------|--------|
   | planned, implementing, partial, blocked | Plan Revision (via skill-reviser) |
   | not_started, researched | Description Update (via skill-reviser) |
   | completed | ABORT "Task completed, no revision needed" |
   | abandoned | ABORT "Task abandoned, use /task --recover first" |

**ABORT** if any validation fails. **PROCEED** to delegation.

---

### CHECKPOINT 2: DELEGATE TO SKILL

Invoke `skill-reviser` with the validated task context. The skill handles:

- **Plan Revision path**: Load current plan, analyze changes, create revised plan, update status via `update-task-status.sh postflight plan`, link artifacts, git commit
- **Description Update path**: Validate revision reason, update state.json description, update TODO.md, git commit

Pass to skill-reviser:
- `task_number` - Validated task number
- `session_id` - Generated session ID
- `revision_reason` - Optional reason from remaining args
- `task_data` - Full task data from state.json lookup
- `branch` - "plan_revision" or "description_update" based on routing

The skill returns a brief text summary of what was done.

---

## Output

**Plan Revision:**
```
Plan revised for Task #{N}

Previous: MM_{short-slug}.md
New: MM_{short-slug}.md

Preserved phases: {N}
Revised phases: {range}

Status: [PLANNED]
Next: /implement {N}
```

**Description Update:**
```
Description updated for Task #{N}

Previous: {old_description}
New: {new_description}

Status: [{current_status}]
```

## Error Handling

### GATE IN Failure
- Task not found: Return error with guidance
- Invalid status: Return error with current status

### Skill Failure
- skill-reviser handles all error cases internally
- Missing plan for revision: Skill falls back to description update
- Write failure: Skill logs error, preserves original
- Git commit failure: Non-blocking (logged by skill)
