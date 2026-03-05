---
description: Refresh OpenCode sessions and clean up temporary data
---

Route to skill-refresh for comprehensive cleanup of OpenCode resources.

**Input**: $ARGUMENTS

**Command Pattern**: `/refresh [--dry-run] [--force]`

---

## Routing

**Target**: skill-refresh  
**Subagent**: cleanup-agent  
**Context**: fork  
**Delegation**: Task tool with subagent_type="cleanup-agent"

---

## Validation (Performed by Skill)

- ~/.opencode/ directory exists (if not, nothing to clean)
- Process permissions for termination

---

## Skill Arguments

- **dry_run**: Preview only, no changes (bool, default: false)
- **force**: Skip confirmation prompts (bool, default: false)
- **session_id**: Generated session identifier (string, required)

---

## Execution Rule

**CRITICAL**: This command MUST be handled by skill delegation. DO NOT implement directly.

### DO NOT:
- Parse arguments yourself
- Find orphaned processes yourself
- Terminate processes yourself
- Clean up ~/.opencode/ yourself
- Reclaim disk space yourself
- Skip confirmation prompts yourself
- Commit changes yourself

### DO:
- Extract --dry-run and --force flags from input
- Generate session_id for tracking
- Invoke Skill(skill-refresh, args)
- Return skill result to user

**Skill handles**: Process detection, termination, directory cleanup, space reclamation, confirmation prompts (unless --force), commits

---

## Expected Skill Behavior

The skill-refresh will:
1. Parse dry_run and force flags
2. If not force: Show preview and ask for confirmation
3. Delegate to cleanup-agent via Task tool with forked context
4. cleanup-agent will:
   - Find orphaned opencode processes (pgrep)
   - Terminate orphaned processes (kill -TERM, then -KILL if needed)
   - Scan ~/.opencode/ for cleanup candidates:
     * Temporary session files
     * Orphaned context data
     * Cached artifacts older than threshold
     * Incomplete postflight markers
   - Calculate space usage before/after
   - If not dry_run: Remove cleanup candidates
   - Generate cleanup report
5. Commit changes (if not dry_run and changes made)
6. Return summary to user

---

## Output

Skill returns:
- Processes terminated count
- Files deleted count
- Space reclaimed
- Cleanup report details
- Dry run preview (if --dry-run)
- Confirmation status (if not --force)

---

## Error Handling

Handled by skill:
- Invalid flags → Usage help
- No orphaned processes → Inform user
- Permission denied → Error with sudo suggestion
- Termination failures → Log warning, continue with directory cleanup
- Skill failure → Error message

---

**Note**: This is a routing specification. All implementation details are delegated to skill-refresh.
**Redesigned**: 2026-03-05 as part of OC_135 command routing enforcement
