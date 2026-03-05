---
description: Create a phased implementation plan for a task
---

Route to skill-planner for implementation plan creation.

**Input**: $ARGUMENTS

**Command Pattern**: `/plan <OC_N> [notes]`

---

## Routing

**Target**: skill-planner  
**Subagent**: planner-agent  
**Context**: fork  
**Delegation**: Task tool with subagent_type="planner-agent"

---

## Validation (Performed by Skill)

- Task exists in `specs/state.json`
- Status allows planning: `researched`, `not_started`, `partial`
- Valid task number format (OC_N or N)

---

## Skill Arguments

- **task_number**: Task number (int, required)
- **notes**: Optional planning notes/constraints (string, optional)
- **session_id**: Generated session identifier (string, required)

---

## Execution Rule

**CRITICAL**: This command MUST be handled by skill delegation. DO NOT implement directly.

### DO NOT:
- Parse arguments yourself
- Lookup task in state.json yourself
- Validate status yourself  
- Update state.json or TODO.md yourself
- Read research reports yourself
- Create implementation plans yourself
- Decompose tasks into phases yourself
- Commit changes yourself

### DO:
- Extract task number and notes from input
- Generate session_id for tracking
- Invoke Skill(skill-planner, args)
- Return skill result to user

**Skill handles**: Validation, status updates, research reading, plan creation, artifact linking, commits

---

## Expected Skill Behavior

The skill-planner will:
1. Validate task and update status to PLANNING
2. Display task header
3. Read existing research reports if available
4. Delegate to planner-agent via Task tool with forked context
5. planner-agent creates implementation plan at `specs/OC_NNN_{SLUG}/plans/implementation-001.md`
6. Update status to PLANNED
7. Link plan artifact
8. Commit changes
9. Return summary to user

---

## Output

Skill returns:
- Plan file path
- Number of phases defined
- Total estimated effort
- Status: [PLANNED]
- Next step: `/implement OC_N`

---

## Error Handling

Handled by skill:
- Task not found → Error with guidance
- Invalid status → Error with current status
- Planning failures → Logged, partial plan preserved
- No research exists → Plans from task description alone

---

**Note**: This is a routing specification. All implementation details are delegated to skill-planner.
**Redesigned**: 2026-03-05 as part of OC_135 command routing enforcement
