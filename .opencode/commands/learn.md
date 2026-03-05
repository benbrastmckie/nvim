---
description: Scan files for FIX, NOTE, TODO tags and create structured tasks interactively
---

Route to skill-learn for codebase tag scanning and task creation.

**Input**: $ARGUMENTS

**Command Pattern**: `/learn [PATH...]`

---

## Routing

**Target**: skill-learn  
**Subagent**: tag-scan-agent  
**Context**: fork  
**Delegation**: Task tool with subagent_type="tag-scan-agent"

---

## Validation (Performed by Skill)

- Paths exist (if provided)
- Project structure accessible

---

## Skill Arguments

- **paths**: Files/directories to scan (array of strings, optional - default: entire project)
- **session_id**: Generated session identifier (string, required)

---

## Execution Rule

**CRITICAL**: This command MUST be handled by skill delegation. DO NOT implement directly.

### DO NOT:
- Parse arguments yourself
- Scan files for tags yourself
- Identify FIX:/NOTE:/TODO: markers yourself
- Group tags by type yourself
- Present interactive selection yourself
- Create tasks yourself
- Update state.json yourself
- Update TODO.md yourself
- Commit changes yourself

### DO:
- Extract paths from input (if any)
- Generate session_id for tracking
- Invoke Skill(skill-learn, args)
- Return skill result to user

**Skill handles**: File scanning, tag detection, interactive user selection, task creation, state updates, commits

---

## Expected Skill Behavior

The skill-learn will:
1. Parse paths (if none provided, scan entire project)
2. Delegate to tag-scan-agent via Task tool with forked context
3. tag-scan-agent will:
   - Scan specified paths for tags:
     * `FIX:` - Issues needing fixes
     * `NOTE:` - Important notes/documentation
     * `TODO:` - Tasks to complete
   - Group tags by type and file
   - Remove duplicates
   - Present interactive selection to user (AskUserQuestion multiSelect)
   - Get user confirmation
   - For selected items: Create tasks using /task
   - Group related items into single tasks where appropriate
4. Update state.json with new tasks
5. Update TODO.md with new entries
6. Commit changes
7. Return summary to user

---

## Output

Skill returns:
- Tags found by type (FIX, NOTE, TODO)
- Selected items count
- Tasks created count
- Task numbers and paths
- Next step guidance

---

## Error Handling

Handled by skill:
- Invalid paths → Error with guidance
- No tags found → Inform user, no error
- User cancels selection → Exit gracefully
- Task creation failure → Log error, continue with others
- Git failures → Log warning, continue

---

## Interactive Flow

**User Experience** (handled by skill):
1. Scanning notification
2. Tag summary display
3. Interactive selection prompt (multiSelect)
4. Confirmation dialog
5. Task creation progress
6. Completion summary

---

**Note**: This is a routing specification. All implementation details including interactive flow are delegated to skill-learn.
**Redesigned**: 2026-03-05 as part of OC_135 command routing enforcement
