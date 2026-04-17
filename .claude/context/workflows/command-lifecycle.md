# Command Lifecycle and Two-Phase Status Update Pattern

## Overview

This document describes the lifecycle of workflow commands (`/research`, `/plan`, `/revise`, `/implement`, `/task`) and the two-phase status update pattern that all workflow subagents follow.

**Note**: `/task` follows a different pattern since it creates tasks rather than modifying them. See "Task Creation Pattern" section below.

## Command Lifecycle Stages

All workflow commands follow a standardized 8-stage lifecycle:

### Orchestrator Stages (1-5, 8)

**Stage 1 (PreflightValidation):**
- Parse task number from $ARGUMENTS
- Validate task exists in TODO.md
- Extract task metadata

**Stage 2 (DetermineRouting):**
- Extract language from task entry (state.json or TODO.md)
- Map language to appropriate subagent using routing table
- Validate routing decision

**Stage 3 (RegisterAndDelegate):**
- Register session in session registry
- Prepare delegation context
- Invoke target subagent

**Stage 4 (ValidateReturn):**
- Validate return format per subagent-return.md
- Verify artifacts exist and are non-empty
- Extract metadata from return

**Stage 5 (PostflightCleanup):**
- Update session registry
- Relay result to user

**Stage 8 (Return):**
- Subagent returns standardized result to orchestrator

### Subagent Stages (6-7)

**Stage 6 (Execution):**
- Subagent executes main workflow
- Creates artifacts (research reports, plans, implementation files)
- Validates artifacts

**Stage 7 (Postflight):**
- Update status to completion marker
- Create git commit
- Return standardized result

## Two-Phase Status Update Pattern

All workflow subagents (researcher, planner, implementer) follow a **two-phase status update pattern** to provide visibility into work progress and ensure atomic state transitions.

### Phase 1: Preflight Status Update

**When:** Before executing main workflow (Stage 0 or Step 0 in subagent)  
**Purpose:** Signal that work has started  
**Status Markers:**
- `/research`: [RESEARCHING]
- `/plan`: [PLANNING]
- `/revise`: [REVISING]
- `/implement`: [IMPLEMENTING]

**Process:**
1. Validate task exists and is valid for operation
2. Verify task not [COMPLETED] or [ABANDONED]
3. Verify task is in valid starting status
4. Generate timestamp (ISO 8601 date: YYYY-MM-DD)
5. Invoke status-sync-manager with:
   - task_number
   - new_status: "researching" | "planning" | "revising" | "implementing"
   - timestamp
   - session_id
   - delegation_depth
   - delegation_path
6. Validate status update succeeded
7. **Abort if status update fails** (critical error)

**Error Handling:**
- If status update fails: Return status "failed" with error
- Error type: "status_update_failed"
- Recommendation: "Check status-sync-manager logs and retry"
- Work is NOT performed if preflight fails

### Phase 2: Postflight Status Update

**When:** After completing main workflow (Stage 7 or Step 7 in subagent)  
**Purpose:** Signal that work has completed  
**Status Markers:**
- `/research`: [RESEARCHED]
- `/plan`: [PLANNED]
- `/revise`: [REVISED]
- `/implement`: [COMPLETED]

**Process:**
1. Validate artifacts created successfully
2. Generate timestamp (ISO 8601 date: YYYY-MM-DD)
3. Invoke status-sync-manager with:
   - task_number
   - new_status: "researched" | "planned" | "revised" | "completed"
   - timestamp
   - session_id
   - validated_artifacts
   - delegation_depth
   - delegation_path
4. Validate status update succeeded
5. **Log warning if status update fails** (non-critical - work already done)
6. Invoke git-workflow-manager to create commit
7. Return standardized result

**Error Handling:**
- If status update fails: Log error (non-critical)
- Work artifacts already created
- Manual recovery: Update TODO.md and state.json manually

## Status Transitions

### Research Command

```
[NOT STARTED] → [RESEARCHING] → [RESEARCHED]
     ↑              ↑                ↑
     |         Preflight         Postflight
  Initial      (Step 0)          (Step 5)
```

### Plan Command

```
[RESEARCHED] → [PLANNING] → [PLANNED]
     ↑            ↑             ↑
     |       Preflight      Postflight
  Starting    (Step 0)      (Step 7)
```

### Revise Command

```
[PLANNED] → [REVISING] → [REVISED]
    ↑          ↑            ↑
    |     Preflight     Postflight
 Starting   (Step 0)    (Step 7)
```

### Implement Command

```
[PLANNED] → [IMPLEMENTING] → [COMPLETED]
    ↑           ↑                ↑
    |      Preflight         Postflight
 Starting    (Step 0)        (Step 7)
```

## Benefits of Two-Phase Pattern

### User Visibility
- Users can see when work starts (in-progress markers)
- Users can see when work completes (completion markers)
- Clear progress tracking in TODO.md and state.json

### Atomic Updates
- status-sync-manager ensures atomic updates across TODO.md and state.json
- Both files updated together or neither updated
- No partial state updates

### Error Recovery
- Preflight failure aborts work (prevents wasted effort)
- Postflight failure logs warning (work already done, manual recovery possible)
- Clear error messages guide users to recovery steps

### Consistency
- All workflow subagents follow the same pattern
- Predictable behavior across all commands
- Easier to understand and maintain

## Implementation Details

### Preflight Status Update (Step 0)

All workflow subagents implement a `<step_0_preflight>` or `<stage_1_preflight>` section:

```xml
<step_0_preflight>
  <action>Preflight: Validate task and update status to [COMMAND-ING]</action>
  <process>
    1. Parse task_number from delegation context or prompt string
    2. Validate task exists in specs/TODO.md
    3. Extract task description and current status
    4. Verify task not [COMPLETED] or [ABANDONED]
    5. Verify task is in valid starting status
    6. Generate timestamp: $(date -I)
    7. Invoke status-sync-manager to mark [COMMAND-ING]:
       a. Prepare delegation context
       b. Invoke status-sync-manager with timeout (60s)
       c. Validate return status == "completed"
       d. Verify files_updated includes ["TODO.md", "state.json"]
       e. If status update fails: Abort with error
    8. Log preflight completion
  </process>
  <validation>
    - Task exists and is valid for operation
    - Status updated to [COMMAND-ING] atomically
    - Timestamp added to TODO.md and state.json
  </validation>
  <error_handling>
    If status update fails:
      Return status "failed" with error:
      - type: "status_update_failed"
      - message: "Failed to update status to [COMMAND-ING]"
      - recommendation: "Check status-sync-manager logs and retry"
  </error_handling>
  <output>Task validated, status updated to [COMMAND-ING]</output>
</step_0_preflight>
```

### Postflight Status Update (Step 7)

All workflow subagents implement a `<step_7>` section for postflight:

```xml
<step_7>
  <action>Execute Stage 7 (Postflight) - Update status and create git commit</action>
  <process>
    STAGE 7: POSTFLIGHT (Subagent owns this stage)
    
    STEP 7.1: INVOKE status-sync-manager
      PREPARE delegation context:
      - task_number
      - new_status: "researched" | "planned" | "revised" | "completed"
      - timestamp
      - session_id
      - validated_artifacts
      - delegation_depth
      - delegation_path
      
      INVOKE status-sync-manager with timeout (60s)
      VALIDATE return status == "completed"
      VERIFY files_updated includes ["TODO.md", "state.json"]
    
    STEP 7.2: INVOKE git-workflow-manager
      PREPARE delegation context with scope_files
      INVOKE git-workflow-manager with timeout (120s)
      VALIDATE return and extract commit_hash
  </process>
  <output>Status updated to [COMMAND-ED], git commit created</output>
</step_7>
```

## Task Creation Pattern

The `/task` command follows a different pattern from workflow commands since it **creates** tasks rather than modifying existing ones.

### /task Command Lifecycle

**Stage 1 (ParseAndValidate):**
- Parse task description from $ARGUMENTS
- Extract optional flags (--priority, --effort, --language)
- Detect language from description keywords if not provided
- Validate all inputs (description non-empty, priority valid, etc.)

**Stage 2 (CreateTask):**
- Read next_project_number from state.json using jq
- Format TODO.md entry with proper metadata
- Append to correct priority section in TODO.md
- Update state.json (increment next_project_number, add to active_projects)
- Verify updates succeeded
- Return task number to user

### Inline Implementation

Unlike /research and /implement which delegate to subagents, /task uses **inline implementation** with executable pseudocode directly in Stage 2:

```bash
# Read next project number
next_number=$(jq -r '.next_project_number' specs/state.json)

# Format TODO.md entry
entry="### ${next_number}. ${description}
- **Effort**: ${effort}
- **Status**: [NOT STARTED]
- **Priority**: ${priority}
- **Task Type**: ${language}
- **Blocking**: None
- **Dependencies**: None

---"

# Append to TODO.md (using Edit tool)
# Update state.json (using jq)
jq '.next_project_number = (.next_project_number + 1) | 
    .active_projects += [...]' specs/state.json
```

### Key Differences from Workflow Commands

1. **No Two-Phase Status Update**: Task creation is atomic (single file update operation)
2. **No Preflight/Postflight**: Task doesn't exist yet, so no status to update
3. **No Git Commit**: Task creation doesn't create artifacts (only TODO.md + state.json updates)
4. **Inline Implementation**: No delegation to subagent (executable pseudocode in command file)
5. **Matches /research Pattern**: Stage 1 has executable logic that Claude can directly follow

### Atomic Updates

/task ensures atomic updates by:
- Reading state.json to get next_project_number
- Updating TODO.md first (using Edit tool)
- Updating state.json second (using jq)
- Verifying both updates succeeded
- If state.json update fails: Manual rollback required (documented in error message)

### Validation

**Pre-execution:**
- Description is non-empty
- Priority is Low|Medium|High
- Effort is TBD or time estimate
- Language is valid (general|meta|markdown, or extension-provided type)
- Language field MANDATORY per tasks.md line 110

**Post-execution:**
- Task number allocated correctly
- TODO.md contains new task entry
- state.json next_project_number incremented
- Language field is set
- Metadata format uses `- **Field**:` pattern

### References

- **Task Command:** `.claude/command/task.md` (inline implementation)
- **Task Standards:** `.claude/context/standards/tasks.md`
- **Original Implementation Plan:** `specs/task-command-improvement-plan.md`
- **Fix Plan:** `specs/task-command-fix-plan.md`

## Control Flow in Commands

### The Continuation Marker Pattern

Workflow commands (`/research`, `/plan`, `/implement`) use explicit continuation markers to ensure Claude executes the full checkpoint-based flow without stopping prematurely.

**Problem**: Without explicit continuation markers, Claude may interpret skill invocation returns (JSON responses) as transaction boundaries and stop execution after GATE IN or DELEGATE, failing to complete the full workflow.

**Solution**: Each checkpoint ends with an explicit continuation marker:

```markdown
**On {CHECKPOINT} success**: {State note}. **IMMEDIATELY CONTINUE** to {NEXT_SECTION} below.
```

### Standard Continuation Markers

| After | Marker Template |
|-------|-----------------|
| CHECKPOINT 1 (GATE IN) | `**On GATE IN success**: Status is [{STATUS}]. **IMMEDIATELY CONTINUE** to STAGE 2 below.` |
| STAGE 2 (DELEGATE) | `**On DELEGATE success**: {Work} complete. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.` |
| CHECKPOINT 2 (GATE OUT) | `**On GATE OUT success**: Artifacts verified. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.` |

### Examples

**In /research command**:
```markdown
**On GATE IN success**: Status is [RESEARCHING]. **IMMEDIATELY CONTINUE** to STAGE 2 below.
```

**In /plan command**:
```markdown
**On DELEGATE success**: Plan created. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.
```

**In /implement command**:
```markdown
**On GATE OUT success**: Artifacts verified. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.
```

### Why This Works

1. **Explicit over implicit**: The marker explicitly tells Claude what to do next, removing ambiguity
2. **State confirmation**: The marker confirms the expected state (e.g., "Status is [RESEARCHING]")
3. **Directional guidance**: "below" indicates the next section is in the same document
4. **Imperative language**: "IMMEDIATELY CONTINUE" is unambiguous directive language

### Commands That Do Not Need Continuation Markers

The `/meta` command does not require continuation markers because:
- It has no preflight checkpoint (no intermediate skill returns before delegation)
- It delegates directly to a skill without multiple return points

### Adding Continuation Markers to New Commands

When creating new checkpoint-based commands:
1. Add a continuation marker after each checkpoint that precedes another section
2. Use the standard template format
3. Include the expected state in the marker
4. Test that Claude executes the full flow without stopping

## References

- **State Management:** `.claude/context/orchestration/state-management.md`
- **Status Sync Skill:** `.claude/skills/skill-status-sync.md`
- **Research Agent:** `.claude/agents/general-research-agent.md`
- **Planner Agent:** `.claude/agents/planner-agent.md`
- **Implementation Agent:** `.claude/agents/general-implementation-agent.md`
- **Command Files:** `.claude/commands/{research,plan,revise,implement,task}.md`

## Validation

### Pre-execution Validation
- Verify task_number is positive integer
- Verify task exists in TODO.md
- Verify task not [COMPLETED] or [ABANDONED]
- Verify task in valid starting status

### Post-execution Validation
- Verify preflight status update occurred
- Verify artifacts created successfully
- Verify postflight status update occurred
- Verify git commit created (or logged if failed)

## Testing Recommendations

When testing workflow commands, verify:

1. **Preflight Status Update:**
   - Status changes from starting status to in-progress marker
   - Timestamp added to TODO.md and state.json
   - Both files updated atomically

2. **Postflight Status Update:**
   - Status changes from in-progress marker to completion marker
   - Timestamp updated in TODO.md and state.json
   - Both files updated atomically

3. **Error Cases:**
   - Preflight failure aborts work
   - Postflight failure logs warning but doesn't fail command
   - Clear error messages with recovery instructions

4. **Atomic Updates:**
   - Both TODO.md and state.json updated together
   - No partial updates (both files or neither)
   - Rollback on failure

## Maintenance Notes

- All workflow subagents MUST implement two-phase status updates
- Preflight is CRITICAL (abort on failure)
- Postflight is NON-CRITICAL (log warning on failure)
- Follow researcher.md as reference implementation
- Keep pattern consistent across all subagents
