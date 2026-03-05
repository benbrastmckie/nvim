---
description: Research a task and create a research report
---

Route to skill-researcher for comprehensive task research.

**Input**: $ARGUMENTS

**Command Pattern**: `/research <OC_N> [focus]`

---

## Routing

**Target**: skill-researcher  
**Subagent**: general-research-agent  
**Context**: fork  
**Delegation**: Task tool with subagent_type="general-research-agent"

---

## Validation (Performed by Skill)

- Task exists in `specs/state.json`
- Status allows research: `not_started`, `partial`, `researched`
- Valid task number format (OC_N or N)

---

## Skill Arguments

- **task_number**: Task number (int, required)
- **focus**: Optional research focus/prompt (string, optional)
- **session_id**: Generated session identifier (string, required)

---

## Execution Rule

**CRITICAL**: This command MUST be handled by skill delegation. DO NOT implement directly.

### DO NOT:
- Parse arguments yourself
- Lookup task in state.json yourself  
- Validate status yourself
- Update state.json or TODO.md yourself
- Execute research queries yourself
- Write research reports yourself
- Commit changes yourself

### DO:
- Extract task number and focus from input
- Generate session_id for tracking
- Invoke Skill(skill-researcher, args)
- Return skill result to user

**Skill handles**: Validation, status updates, research execution, report writing, artifact linking, commits

---

## Expected Skill Behavior

The skill-researcher will:
1. Validate task and update status to RESEARCHING
2. Display task header
3. Execute research based on task language:
   - **meta**: Explore `.opencode/` files, conventions, patterns
   - **lean**: Search codebase for proofs, check Lean/Mathlib patterns
   - **typst/latex**: Read existing documents, check style
   - **general**: Web search + codebase exploration
4. Write research report to `specs/OC_NNN_{SLUG}/reports/research-001.md`
5. Update status to RESEARCHED
6. Commit changes
7. Return summary to user

---

## Output

Skill returns:
- Research report path
- Key findings summary
- Recommendations
- Next step: `/plan OC_N`

---

## Error Handling

Handled by skill:
- Task not found → Error with guidance
- Invalid status → Error with current status
- Research failures → Logged, partial results preserved

---

**Note**: This is a routing specification. All implementation details are delegated to skill-researcher.
**Redesigned**: 2026-03-05 as part of OC_135 command routing enforcement
