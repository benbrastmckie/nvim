---
description: Execute grant workflows (funder research, proposal drafting, budget development, progress tracking)
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBER WORKFLOW_TYPE [FOCUS]
model: claude-opus-4-5-20251101
---

# /grant Command

Execute grant workflows for a task by delegating to the skill-grant skill.

## Arguments

- `$1` - Task number (required)
- `$2` - Workflow type (required): funder_research, proposal_draft, budget_develop, progress_track
- Remaining args - Optional focus/prompt for workflow direction

## Workflow Types

| Workflow | Description | Status Transition |
|----------|-------------|-------------------|
| funder_research | Research and analyze potential funders | [NOT STARTED] -> [RESEARCHING] -> [RESEARCHED] |
| proposal_draft | Draft proposal narrative sections | [RESEARCHED] -> [PLANNING] -> [PLANNED] |
| budget_develop | Develop line-item budget | [RESEARCHED] -> [PLANNING] -> [PLANNED] |
| progress_track | Track progress without status change | (no status change) |

## Execution

**Note**: Delegate to skill-grant which handles status updates and git commits internally.

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Grant] Task {N}: {project_name} ({workflow_type})
```

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

3. **Validate Task Exists**
   - Task must exist in state.json (ABORT if not)
   - Extract: language, status, project_name, description

4. **Validate Language**
   - Language must be "grant" (ABORT if not with message: "Task has language '{lang}', expected 'grant'")

5. **Validate Status**
   - Status must allow grant workflows: not_started, researched, planned, partial, blocked
   - If completed: ABORT "Task already completed"
   - If abandoned: ABORT "Task is abandoned"

6. **Validate Workflow Type**
   - Must be one of: funder_research, proposal_draft, budget_develop, progress_track
   - ABORT if invalid with message: "Invalid workflow_type: {value}. Expected one of: funder_research, proposal_draft, budget_develop, progress_track"

**ABORT** if any validation fails.

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 2 below.

### STAGE 2: DELEGATE

**EXECUTE NOW**: After CHECKPOINT 1 passes, immediately invoke the Skill tool.

**Invoke the Skill tool NOW** with:
```
skill: "skill-grant"
args: "task_number={N} workflow_type={workflow_type} focus={focus_prompt} session_id={session_id}"
```

The skill will:
- Update task status (preflight: researching/planning based on workflow)
- Spawn grant-agent to execute the workflow
- Create workflow-specific artifacts
- Update task status (postflight: researched/planned based on workflow)
- Commit changes with session ID

**On DELEGATE success**: Workflow complete. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   - Skill returns brief text summary (NOT JSON)
   - Check for error indicators in return text

2. **Verify Artifacts**
   - For funder_research: Check for report in specs/{NNN}_{SLUG}/reports/
   - For proposal_draft: Check for draft in specs/{NNN}_{SLUG}/drafts/
   - For budget_develop: Check for budget in specs/{NNN}_{SLUG}/budgets/
   - For progress_track: Check for summary in specs/{NNN}_{SLUG}/summaries/

3. **Verify Status Updated**
   - The skill handles status updates internally (preflight and postflight)
   - For funder_research: Confirm status is "researched" in state.json
   - For proposal_draft/budget_develop: Confirm status is "planned" in state.json
   - For progress_track: Status should be unchanged

**RETRY** skill if validation fails.

**On GATE OUT success**: Workflow verified. **NO CHECKPOINT 3** - skill handles commits.

## Output

### Funder Research Success
```
Grant funder research completed for Task #{N}

Report: specs/{NNN}_{SLUG}/reports/{MM}_funder-analysis.md

Status: [RESEARCHED]
Next: /grant {N} proposal_draft
```

### Proposal Draft Success
```
Grant proposal draft created for Task #{N}

Draft: specs/{NNN}_{SLUG}/drafts/{MM}_narrative-draft.md

Status: [PLANNED]
Next: /grant {N} budget_develop
```

### Budget Development Success
```
Grant budget developed for Task #{N}

Budget: specs/{NNN}_{SLUG}/budgets/{MM}_line-item-budget.md

Status: [PLANNED]
Next: /implement {N}
```

### Progress Tracking Success
```
Grant progress updated for Task #{N}

Summary: specs/{NNN}_{SLUG}/summaries/{MM}_progress-summary.md

Status: (unchanged)
```

## Error Handling

### GATE IN Failure
- Task not found: Return error with guidance to create task first
- Invalid language: Return error suggesting correct skill or task update
- Invalid status: Return error with current status and allowed transitions
- Invalid workflow_type: Return error listing valid workflow types

### DELEGATE Failure
- Skill fails: Log error, status remains at preflight level for resume
- Timeout: Partial progress preserved, user can re-run to continue
- Missing artifacts: Skill reports partial completion with resume guidance

### GATE OUT Failure
- Missing artifacts: Log warning, report partial completion
- Status mismatch: Log warning, check if skill encountered error
