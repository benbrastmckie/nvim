---
description: Create new version of implementation plan, or update task description if no plan exists
---

Route to skill-revisor for plan revision or task description updates.

**Input**: $ARGUMENTS

**Command Pattern**: `/revise <OC_N> [REASON]`

---

## Routing

**Target**: skill-revisor  
**Conditional Subagents**:
- If plan exists: **planner-agent** (for plan revision)
- If no plan: **task-expander** (for description update)
**Context**: fork  
**Delegation**: Task tool with conditional subagent_type

---

## Validation (Performed by Skill)

- Task exists in `specs/state.json`
- Status allows revision: `planned`, `researched`, `partial`, `revised`, `completed` (with reason)
- Valid task number format (OC_N or N)
- Checks for existing plan to determine routing target

---

## Skill Arguments

- **task_number**: Task number (int, required)
- **reason**: Revision reason or new description (string, required)
- **force**: Override status checks if true (bool, optional)
- **session_id**: Generated session identifier (string, required)

---

## Conditional Routing Logic

**Skill determines target based on plan existence**:
```
If plan exists:
  → Delegate to planner-agent for plan revision
  → Create implementation-{NEXT}.md
  → Status: [REVISED]
Else:
  → Delegate to task-expander for description update
  → Update task description
  → Status unchanged
```

---

## Execution Rule

**CRITICAL**: This command MUST be handled by skill delegation. DO NOT implement directly.

### DO NOT:
- Parse arguments yourself
- Check for plan existence yourself
- Lookup task in state.json yourself
- Validate status yourself
- Decide routing target yourself
- Call planner-agent or task-expander directly
- Update plan files yourself
- Update task descriptions yourself
- Commit changes yourself

### DO:
- Extract task number, reason, and force flag from input
- Generate session_id for tracking
- Invoke Skill(skill-revisor, args)
- Return skill result to user

**Skill handles**: Plan detection, routing decision, validation, subagent delegation, status updates, commits

---

## Expected Skill Behavior

The skill-revisor will:
1. Parse task number and reason
2. Check for existing implementation plan
3. Validate task status allows revision
4. Route conditionally:
   - **If plan exists**: Delegate to planner-agent to create new plan version
   - **If no plan**: Delegate to task-expander to update description
5. Validate subagent return format and artifacts
6. Update status to REVISED (if plan revised) or keep current (if description updated)
7. Link new artifact
8. Commit changes
9. Return summary to user

---

## Output

Skill returns:
- Operation type (plan revision or description update)
- New plan path (if applicable)
- Summary of changes
- Status: [REVISED] or unchanged
- Next step guidance

---

## Error Handling

Handled by skill:
- Task not found → Error with guidance
- Invalid status → Error with current status (unless --force)
- Implementation in progress → Warning with /task --sync suggestion
- Subagent validation failure → Error with specific validation details

---

**Note**: This is a routing specification. All implementation details including conditional routing are delegated to skill-revisor.
**Redesigned**: 2026-03-05 as part of OC_135 command routing enforcement
