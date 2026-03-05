---
description: Execute implementation with resume support
---

Route to skill-implementer for phase-by-phase plan execution.

**Input**: $ARGUMENTS

**Command Pattern**: `/implement <OC_N> [--force] [instructions]`

---

## Routing

**Target**: skill-implementer  
**Subagent**: general-implementation-agent  
**Context**: fork  
**Delegation**: Task tool with subagent_type="general-implementation-agent"

---

## Validation (Performed by Skill)

- Task exists in `specs/state.json`
- Status allows implementation: `planned`, `partial`, `researched`, `not_started`
- Implementation plan exists: `specs/OC_NNN_{SLUG}/plans/implementation-*.md`
- Valid task number format (OC_N or N)
- `--force` flag can override status validation

---

## Skill Arguments

- **task_number**: Task number (int, required)
- **force**: Skip status validation if true (bool, optional)
- **instructions**: Optional custom instructions for implementation (string, optional)
- **session_id**: Generated session identifier (string, required)

---

## Execution Rule

**CRITICAL**: This command MUST be handled by skill delegation. DO NOT implement directly.

### DO NOT:
- Parse arguments yourself
- Lookup task in state.json yourself
- Validate status yourself
- Read implementation plans yourself
- Execute phases yourself
- Modify files yourself
- Update phase status yourself
- Commit changes yourself
- Mark task completed yourself

### DO:
- Extract task number, force flag, and instructions from input
- Generate session_id for tracking
- Invoke Skill(skill-implementer, args)
- Return skill result to user

**Skill handles**: Validation, plan reading, phase execution, file modifications, status updates, commits, completion

---

## Expected Skill Behavior

The skill-implementer will:
1. Validate task and update status to IMPLEMENTING
2. Display task header
3. Read implementation plan (highest version)
4. For each phase with status [NOT STARTED] or [PARTIAL]:
   - Update phase to [IN PROGRESS]
   - Delegate to general-implementation-agent via Task tool
   - Execute phase steps
   - Verify phase completion
   - Update phase to [COMPLETED]
   - Commit phase changes
5. Write implementation summary to `specs/OC_NNN_{SLUG}/summaries/implementation-summary-YYYYMMDD.md`
6. Update status to COMPLETED
7. Link summary artifact
8. Commit final changes
9. Return summary to user

---

## Output

Skill returns:
- Phases completed
- Files changed
- Summary path
- Status: [COMPLETED]
- Follow-up suggestions if any

---

## Error Handling

Handled by skill:
- Task not found → Error with guidance
- Invalid status → Error (or warning with --force)
- No plan found → Error: "Run `/plan OC_N` first"
- Phase failure → Mark [PARTIAL], commit progress, report blockage
- Git failures → Logged, non-blocking

---

## Resume Support

If implementation is interrupted:
- Phase status markers in plan file determine resume point
- Next `/implement OC_N` call continues from incomplete phases
- Partial progress is preserved and committed

---

**Note**: This is a routing specification. All implementation details are delegated to skill-implementer.
**Redesigned**: 2026-03-05 as part of OC_135 command routing enforcement
