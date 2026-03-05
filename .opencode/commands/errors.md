---
description: Analyze errors and create fix plans
---

Route to skill-errors for error pattern analysis and fix task creation.

**Input**: $ARGUMENTS

**Command Pattern**: `/errors [--fix <OC_N>]`

---

## Routing

**Target**: skill-errors  
**Subagent**: error-analysis-agent  
**Context**: fork  
**Delegation**: Task tool with subagent_type="error-analysis-agent"

---

## Validation (Performed by Skill)

- `specs/errors.json` exists or can be initialized
- If --fix flag: Task exists in state.json
- Valid task number format (OC_N or N)

---

## Skill Arguments

- **fix_task_number**: Task to fix (int, optional - if --fix flag present)
- **analysis_mode**: True if no --fix flag (bool, auto-detected)
- **session_id**: Generated session identifier (string, required)

---

## Execution Rule

**CRITICAL**: This command MUST be handled by skill delegation. DO NOT implement directly.

### DO NOT:
- Parse arguments yourself
- Load errors.json yourself
- Analyze error patterns yourself
- Group errors by type/severity yourself
- Create analysis reports yourself
- Create fix tasks yourself
- Run fix implementations yourself
- Update error status yourself
- Commit changes yourself

### DO:
- Extract --fix flag and task number (if present) from input
- Generate session_id for tracking
- Invoke Skill(skill-errors, args)
- Return skill result to user

**Skill handles**: Error loading, pattern analysis, report generation, fix task creation, implementation, status updates, commits

---

## Expected Skill Behavior

The skill-errors will:
1. Parse arguments (determine analysis vs fix mode)
2. Load `specs/errors.json` (initialize if missing)
3. **Analysis Mode** (no --fix flag):
   - Delegate to error-analysis-agent
   - Group errors by type, severity, recurrence
   - Identify patterns and root causes
   - Create analysis report at `specs/errors/analysis-{DATE}.md`
   - Create fix tasks for significant patterns
   - Update review state
   - Commit changes
4. **Fix Mode** (--fix OC_N):
   - Load specific task error data
   - Analyze error context and history
   - Delegate to error-analysis-agent for fix implementation
   - Run fix procedures
   - Verify fixes
   - Update error status to "fixed"
   - Commit changes
5. Return summary to user

---

## Output

Skill returns (Analysis Mode):
- Total/unfixed/fixed error counts
- Errors by type table
- Critical unfixed errors list
- Pattern analysis summary
- Created task recommendations

Skill returns (Fix Mode):
- Task analyzed
- Errors fixed count
- Verification results
- Status updates

---

## Error Handling

Handled by skill:
- Invalid --fix argument → Error with guidance
- Missing errors.json → Initialize empty
- No errors found → Inform user, no error
- Analysis failure → Log warning, continue with partial results
- Fix failure → Keep error status "unfixed", report issue

---

**Note**: This is a routing specification. All implementation details are delegated to skill-errors.
**Redesigned**: 2026-03-05 as part of OC_135 command routing enforcement
