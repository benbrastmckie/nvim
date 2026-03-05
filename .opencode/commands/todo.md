---
description: Archive completed and abandoned tasks
---

Route to skill-todo for task archiving and cleanup.

**Input**: $ARGUMENTS

**Command Pattern**: `/todo [--dry-run]`

---

## Routing

**Target**: skill-todo  
**Subagent**: task-archive-agent  
**Context**: fork  
**Delegation**: Task tool with subagent_type="task-archive-agent"

---

## Validation (Performed by Skill)

- `specs/state.json` exists and is valid
- Archive directory structure accessible

---

## Skill Arguments

- **dry_run**: Preview only, no changes (bool, default: false)
- **session_id**: Generated session identifier (string, required)

---

## Execution Rule

**CRITICAL**: This command MUST be handled by skill delegation. DO NOT implement directly.

### DO NOT:
- Parse arguments yourself
- Scan for archivable tasks yourself
- Read state.json yourself
- Cross-reference TODO.md yourself
- Detect orphaned directories yourself
- Move files to archive yourself
- Update state.json yourself
- Update TODO.md yourself
- Commit changes yourself

### DO:
- Extract --dry-run flag from input
- Generate session_id for tracking
- Invoke Skill(skill-todo, args)
- Return skill result to user

**Skill handles**: Task scanning, orphaned directory detection, archiving operations, state updates, TODO.md updates, commits

---

## Expected Skill Behavior

The skill-todo will:
1. Parse --dry-run flag
2. Scan `specs/state.json` for completed/abandoned tasks
3. Cross-reference with `specs/TODO.md`
4. Detect orphaned directories in `specs/` and `specs/archive/`
5. Delegate to task-archive-agent via Task tool with forked context
6. task-archive-agent will:
   - Identify archivable tasks
   - Detect orphaned directories
   - If not dry_run: Move directories to archive
   - Update state.json (remove from active, add to completed)
   - Update TODO.md (mark archived entries)
   - Calculate repository health metrics
7. Commit changes (if not dry_run)
8. Return summary to user

---

## Output

Skill returns:
- Tasks archived count
- Orphaned directories found/cleaned
- Repository health metrics
- Space reclaimed (if applicable)
- Dry run summary (if --dry-run)

---

## Error Handling

Handled by skill:
- Missing state.json → Error with /meta suggestion
- No archivable tasks → Inform user, no error
- Orphaned directories found → Report, clean if not dry_run
- Permission errors → Error with sudo suggestion
- Git failures → Log warning, continue

---

**Note**: This is a routing specification. All implementation details are delegated to skill-todo.
**Redesigned**: 2026-03-05 as part of OC_135 command routing enforcement
