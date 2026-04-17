# Preflight Pattern

## Overview

All workflow commands (`/research`, `/plan`, `/revise`, `/implement`) MUST execute preflight in Stage 1.5 before delegating work to subagents.

Preflight ensures status is updated BEFORE work begins, making progress immediately visible to users.

## Standard Preflight Process

Commands MUST execute these steps in Stage 1.5 (Preflight) after validating inputs in Stage 1:

### Step 1: Generate Session ID

Create unique session identifier for tracking:

```bash
# Generate session_id with timestamp and random component
session_id="sess_$(date +%s)_$(head -c 6 /dev/urandom | base64 | tr -dc 'a-z0-9')"

# Store for later use
expected_session_id="$session_id"

# Log generation
echo "Generated session_id: $session_id"
```

**Session ID format:**
- Prefix: `sess_`
- Timestamp: Unix epoch seconds
- Random: 6-character alphanumeric string
- Example: `sess_1704643200_a1b2c3`

### Step 2: Delegate to status-sync-manager

Update status to in-progress state before work begins:

```bash
# Determine target status based on command
case "$command" in
  "research") target_status="researching" ;;
  "plan") target_status="planning" ;;
  "revise") target_status="revising" ;;
  "implement") target_status="implementing" ;;
esac

echo "Preflight: Updating task $task_number status to ${target_status^^}"

# Invoke status-sync-manager via task tool
task(
  subagent_type="status-sync-manager",
  prompt="{
    \"operation\": \"update_status\",
    \"task_number\": $task_number,
    \"new_status\": \"$target_status\",
    \"timestamp\": \"$(date -I)\",
    \"session_id\": \"$session_id\",
    \"delegation_depth\": 1,
    \"delegation_path\": [\"orchestrator\", \"$command\", \"status-sync-manager\"]
  }",
  description="Update task $task_number status to ${target_status^^}"
)
```

**Status mappings:**
- `/research` → `researching`
- `/plan` → `planning`
- `/revise` → `revising`
- `/implement` → `implementing`

### Step 3: Validate status-sync-manager Return

Verify status update succeeded:

```bash
# Parse return as JSON
if ! echo "$sync_return" | jq empty 2>/dev/null; then
  echo "ERROR: Preflight failed - invalid JSON from status-sync-manager"
  exit 1
fi

# Extract status field
sync_status=$(echo "$sync_return" | jq -r '.status')

# Check if status update completed
if [ "$sync_status" != "completed" ]; then
  echo "ERROR: Preflight failed - status-sync-manager returned $sync_status"
  
  # Extract error message
  error_msg=$(echo "$sync_return" | jq -r '.errors[0].message // "Unknown error"')
  
  echo "Error: Failed to update status to ${target_status^^}: $error_msg"
  echo "ABORT - do NOT proceed to Stage 2 (Delegate)"
  exit 1
fi

# Verify files_updated includes TODO.md and state.json
files_updated=$(echo "$sync_return" | jq -r '.files_updated[]')

if ! echo "$files_updated" | grep -q "TODO.md"; then
  echo "WARNING: TODO.md not updated"
fi

if ! echo "$files_updated" | grep -q "state.json"; then
  echo "WARNING: state.json not updated"
fi

echo "✓ status-sync-manager completed successfully"
```

**If validation fails:**
- Log error: `Preflight failed: status-sync-manager returned ${sync_status}`
- Extract error message from return
- Return error to user: `Failed to update status to ${target_status^^}: ${error_msg}`
- ABORT - do NOT proceed to Stage 2 (Delegate)

### Step 4: Verify Status Update (Defense in Depth)

Double-check that status was actually updated in state.json:

```bash
echo "Preflight: Verifying status update succeeded"

# Read state.json to check current status
actual_status=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .status' \
  specs/state.json)

# Compare with expected status
if [ "$actual_status" != "$target_status" ]; then
  echo "ERROR: Preflight verification failed"
  echo "Expected status: $target_status"
  echo "Actual status: $actual_status"
  echo "Error: Status update verification failed. Run /task --sync to fix state."
  echo "ABORT - do NOT proceed to Stage 2 (Delegate)"
  exit 1
fi

echo "✓ Preflight: Status verified as '$target_status'"
```

**If verification fails:**
- Log error: `Preflight verification failed`
- Log: `Expected status: ${target_status}`
- Log: `Actual status: ${actual_status}`
- Return error to user: `Status update verification failed. Run /task --sync to fix state.`
- ABORT - do NOT proceed to Stage 2 (Delegate)

### Step 5: Log Preflight Success

Confirm preflight completed and proceed to delegation:

```bash
echo "✓ Preflight completed: Task $task_number status updated to ${target_status^^}"
echo "Files updated: $files_updated"
echo "Proceeding to Stage 2 (Delegate to ${target_agent})"
```

## Validation Checklist

Before proceeding to Stage 2 (Delegate), verify:

- [ ] Session ID generated and stored
- [ ] status-sync-manager invoked successfully
- [ ] status-sync-manager returned "completed" status
- [ ] TODO.md and state.json were updated
- [ ] state.json status field verified as expected value
- [ ] User can now see in-progress status immediately

## Error Handling

All preflight errors MUST:
1. Log error with clear message
2. Return error to user
3. ABORT command execution (do NOT proceed to delegation)
4. Provide recovery instructions (e.g., "Run /task --sync to fix state")

This ensures work never begins without status being updated first.

## Benefits

This standardized preflight provides:

1. **Immediate Visibility**: Status updates before work begins
2. **Consistency**: All workflow commands use same preflight logic
3. **Defense in Depth**: Verification step catches status-sync-manager failures
4. **Traceability**: Session ID enables tracking across delegation chain
5. **Reliability**: Atomic updates via status-sync-manager

## Integration with Command Files

Command files MUST execute this preflight in Stage 1.5 after Stage 1 (ParseAndValidate) and before Stage 2 (Delegate).

**Example integration in research.md:**

```markdown
<stage id="1.5" name="Preflight">
  <action>Update status to [RESEARCHING] before delegating to researcher</action>
  <process>
    CRITICAL: This stage MUST complete BEFORE Stage 2 (Delegate) begins.
    
    1. Generate session_id for tracking
    2. Delegate to status-sync-manager to update status
    3. Validate status-sync-manager return
    4. Verify status was actually updated (defense in depth)
    5. Log preflight success
    6. ONLY THEN proceed to Stage 2
  </process>
  <checkpoint>Status verified as [RESEARCHING] before delegation to researcher</checkpoint>
</stage>
```

## References

- `specs/workflow-command-refactor-plan.md` - Root cause analysis
- `.claude/context/orchestration/state-management.md` - State management patterns
- `.claude/agent/subagents/status-sync-manager.md` - Status sync manager specification
