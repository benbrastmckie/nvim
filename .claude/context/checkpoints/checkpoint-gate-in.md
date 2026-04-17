# Checkpoint: GATE IN (Preflight)

The GATE IN checkpoint validates preconditions and updates status before delegating to a skill/agent.

## Execution Steps

### 1. Generate Session ID

```bash
# Portable command (works on NixOS, macOS, Linux - no xxd dependency)
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

Store in memory for use throughout operation.

### 2. Validate Task Exists

```bash
task_data=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber))' \
  specs/state.json)

if [ -z "$task_data" ]; then
  echo "ABORT: Task $task_number not found"
  exit 1
fi
```

### 3. Validate Status Transition

Extract current status and verify transition is allowed:

| Current Status | Allowed Transitions |
|----------------|---------------------|
| not_started | researching, planning, implementing |
| researched | planning, implementing |
| planned | implementing |
| implementing | implementing (resume) |
| partial | implementing (resume) |

If transition not allowed: ABORT with reason.

### 4. Update Status (via skill-status-sync)

Invoke skill-status-sync with operation: `preflight_update`

```
task_number: {N}
target_status: {in_progress_variant}
session_id: {session_id}
```

In-progress variants:
- researching (for /research)
- planning (for /plan)
- implementing (for /implement)

### 5. Verify Status Update

Re-read state.json and verify status changed:

```bash
new_status=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .status' \
  specs/state.json)

if [ "$new_status" != "$target_status" ]; then
  echo "ABORT: Status update failed"
  exit 1
fi
```

## Decision

- **PROCEED**: All validations pass, status updated
- **ABORT**: Any validation fails

## Output

Pass to next stage:
- session_id
- task_number
- task_data (full task object)
- previous_status (for rollback if needed)
