# Postflight Pattern

## Overview

All workflow commands (`/research`, `/plan`, `/revise`, `/implement`) MUST execute postflight in Stage 3.5 after validating subagent returns in Stage 3.

Postflight ensures status is updated and artifacts are linked AFTER work completes, preventing manual fixes like those needed for Task 326.

## Standard Postflight Process

Commands MUST execute these steps in Stage 3.5 (Postflight) after validating subagent return in Stage 3:

### Step 1: Extract Artifacts from Subagent Return

Parse artifacts array from validated return:

```bash
echo "Postflight: Extracting artifacts from ${target_agent} return"

# Parse artifacts array from subagent return
artifacts_json=$(echo "$subagent_return" | jq -c '.artifacts')
artifact_count=$(echo "$artifacts_json" | jq 'length')

echo "Subagent returned $artifact_count artifact(s)"

# Handle case where no artifacts returned
if [ "$artifact_count" -eq 0 ]; then
  echo "WARNING: ${target_agent} returned no artifacts"
  echo "This may indicate work failed or was incomplete"
  # Continue (will update status but no artifacts to link)
fi
```

### Step 2: Validate Artifacts Exist on Disk (CRITICAL)

Verify each artifact actually exists before linking:

```bash
echo "Postflight: Validating artifacts exist on disk"

# Iterate through each artifact
for artifact_path in $(echo "$artifacts_json" | jq -r '.[].path'); do
  # Check file exists
  if [ ! -f "$artifact_path" ]; then
    echo "ERROR: Artifact not found on disk: $artifact_path"
    echo "Subagent claimed to create artifact but file does not exist"
    echo "This is the same issue that caused Task 326 manual fixes"
    exit 1
  fi
  
  # Check file is non-empty
  if [ ! -s "$artifact_path" ]; then
    echo "ERROR: Artifact is empty: $artifact_path"
    echo "Subagent created file but wrote no content"
    exit 1
  fi
  
  # Get file size for logging
  file_size=$(stat -c%s "$artifact_path" 2>/dev/null || stat -f%z "$artifact_path")
  echo "✓ Validated artifact: $artifact_path ($file_size bytes)"
done

echo "✓ All $artifact_count artifact(s) validated on disk"
```

**This validation is CRITICAL** - it prevents the exact issue that caused Task 326 manual fixes where status was updated but artifacts weren't actually created.

### Step 3: Delegate to status-sync-manager

Update status to completed state and link artifacts:

```bash
# Determine target status based on command
case "$command" in
  "research") target_status="researched" ;;
  "plan") target_status="planned" ;;
  "revise") target_status="revised" ;;
  "implement") target_status="completed" ;;
esac

echo "Postflight: Updating task $task_number status to ${target_status^^} and linking artifacts"

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
    \"delegation_path\": [\"orchestrator\", \"$command\", \"status-sync-manager\"],
    \"validated_artifacts\": $artifacts_json
  }",
  description="Update task $task_number status to ${target_status^^} and link artifacts"
)
```

**Status mappings:**
- `/research` → `researched`
- `/plan` → `planned`
- `/revise` → `revised`
- `/implement` → `completed`

**Note:** The `validated_artifacts` field contains the artifacts array from the subagent return, which status-sync-manager will use to create artifact links in TODO.md.

### Step 4: Validate status-sync-manager Return

Verify status update and artifact linking succeeded:

```bash
# Parse return as JSON
if ! echo "$sync_return" | jq empty 2>/dev/null; then
  echo "ERROR: Postflight failed - invalid JSON from status-sync-manager"
  echo "WARNING: Work completed but status update failed"
  echo "Manual fix: /task --sync $task_number"
  # Continue (work is done, just status update failed)
fi

# Extract status field
sync_status=$(echo "$sync_return" | jq -r '.status')

# Check if status update completed
if [ "$sync_status" != "completed" ]; then
  echo "ERROR: Postflight failed - status-sync-manager returned $sync_status"
  
  # Extract error message
  error_msg=$(echo "$sync_return" | jq -r '.errors[0].message // "Unknown error"')
  
  echo "WARNING: Work completed but status update failed: $error_msg"
  echo "Manual fix: /task --sync $task_number"
  # Continue (work is done, just status update failed)
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

**Note:** Unlike preflight, postflight failures are logged as warnings but don't fail the command, since the actual work is already done. Manual recovery instructions are provided.

### Step 5: Verify Status and Artifact Links (Defense in Depth)

Double-check that status and artifact links were actually updated:

```bash
echo "Postflight: Verifying status and artifact links"

# Read state.json to check current status
actual_status=$(jq -r --arg num "$task_number" \
  '.active_projects[] | select(.project_number == ($num | tonumber)) | .status' \
  specs/state.json)

# Compare with expected status
if [ "$actual_status" != "$target_status" ]; then
  echo "WARNING: Postflight verification failed - status not updated"
  echo "Expected status: $target_status"
  echo "Actual status: $actual_status"
  echo "This is the same issue that caused Task 326 manual fixes"
  echo "Manual fix: /task --sync $task_number"
else
  echo "✓ Status verified as '$target_status'"
fi

# Verify artifact links in TODO.md
for artifact_path in $(echo "$artifacts_json" | jq -r '.[].path'); do
  if ! grep -q "$artifact_path" specs/TODO.md; then
    echo "WARNING: Artifact not linked in TODO.md: $artifact_path"
    echo "This is the same issue that caused Task 326 manual fixes"
    echo "Manual fix: Edit TODO.md to add artifact link"
  else
    echo "✓ Verified artifact link in TODO.md: $artifact_path"
  fi
done
```

**If verification fails:**
- Log warning (not error, since work is done)
- Provide manual fix instructions
- Continue to git commit step

### Step 6: Delegate to git-workflow-manager

Create git commit for completed work:

```bash
echo "Postflight: Creating git commit"

# Extract artifact paths for git commit
artifact_paths=$(echo "$artifacts_json" | jq -r '.[].path' | tr '\n' ' ')

# Invoke git-workflow-manager via task tool
task(
  subagent_type="git-workflow-manager",
  prompt="{
    \"scope_files\": [$artifact_paths, \"specs/TODO.md\", \"specs/state.json\"],
    \"message_template\": \"task $task_number: ${command} completed\",
    \"task_context\": {
      \"task_number\": $task_number,
      \"description\": \"${command} completed\"
    },
    \"session_id\": \"$session_id\",
    \"delegation_depth\": 1,
    \"delegation_path\": [\"orchestrator\", \"$command\", \"git-workflow-manager\"]
  }",
  description="Create git commit for task $task_number ${command}"
)
```

### Step 7: Validate git-workflow-manager Return

Verify git commit succeeded (non-critical):

```bash
# Parse return as JSON
if ! echo "$git_return" | jq empty 2>/dev/null; then
  echo "WARNING: Git commit failed - invalid JSON from git-workflow-manager"
  echo "Manual fix: git add . && git commit -m 'task $task_number: ${command} completed'"
  # Continue (git failure is non-critical)
fi

# Extract status field
git_status=$(echo "$git_return" | jq -r '.status')

# Check if git commit succeeded
if [ "$git_status" == "completed" ]; then
  # Extract commit hash
  commit_hash=$(echo "$git_return" | jq -r '.commit_info.commit_hash // "unknown"')
  echo "✓ Git commit created: $commit_hash"
elif [ "$git_status" == "failed" ]; then
  echo "WARNING: Git commit failed (non-critical)"
  
  # Extract error message
  error_msg=$(echo "$git_return" | jq -r '.errors[0].message // "Unknown error"')
  
  echo "Git error: $error_msg"
  echo "Manual fix: git add . && git commit -m 'task $task_number: ${command} completed'"
  # Continue (git failure doesn't fail the command)
fi
```

**Note:** Git commit failures are logged as warnings but don't fail the command, since the work and status updates are already done.

### Step 8: Log Postflight Success

Confirm postflight completed and proceed to result relay:

```bash
echo "✓ Postflight completed: Task $task_number status updated to ${target_status^^}"
echo "Artifacts linked: $artifact_count"
echo "Git commit: ${commit_hash:-'failed (see warning above)'}"
echo "No manual fixes needed (unlike Task 326)"
echo "Proceeding to Stage 4 (RelayResult)"
```

## Validation Checklist

Before proceeding to Stage 4 (RelayResult), verify:

- [ ] All artifacts validated on disk before status update
- [ ] status-sync-manager invoked successfully
- [ ] status-sync-manager returned "completed" status (or warning logged)
- [ ] state.json status field verified as expected value (or warning logged)
- [ ] Artifact links verified in TODO.md (or warning logged)
- [ ] Git commit created (or warning logged)
- [ ] NO manual fixes needed (unlike Task 326)

## Error Handling

Postflight errors are handled differently than preflight errors:

**Critical errors (ABORT):**
- Artifacts don't exist on disk → ABORT (prevents phantom work)
- Artifacts are empty → ABORT (prevents phantom work)

**Non-critical errors (WARN and CONTINUE):**
- status-sync-manager fails → Log warning, provide manual fix, continue
- Status verification fails → Log warning, provide manual fix, continue
- Artifact link verification fails → Log warning, provide manual fix, continue
- Git commit fails → Log warning, provide manual fix, continue

This distinction is important: if the actual work is done (artifacts exist), we want to complete the command even if status updates or git commits fail, since those can be fixed manually.

## Benefits

This standardized postflight provides:

1. **Phantom Work Prevention**: Validates artifacts exist before updating status
2. **Consistency**: All workflow commands use same postflight logic
3. **Defense in Depth**: Verification step catches status-sync-manager failures
4. **Graceful Degradation**: Non-critical failures don't block command completion
5. **Manual Recovery**: Clear instructions for fixing any failures
6. **No More Task 326**: Prevents the exact issue that required manual fixes

## Integration with Command Files

Command files MUST execute this postflight in Stage 3.5 after Stage 3 (ValidateReturn) and before Stage 4 (RelayResult).

**Example integration in research.md:**

```markdown
<stage id="3.5" name="Postflight">
  <action>Update status to [RESEARCHED], link artifacts, create git commit</action>
  <process>
    CRITICAL: This stage ensures artifacts are linked and status is updated.
    This addresses the Task 326 issue where manual fixes were needed.
    
    1. Extract artifacts from subagent return
    2. Validate artifacts exist on disk (CRITICAL)
    3. Delegate to status-sync-manager to update status and link artifacts
    4. Validate status-sync-manager return
    5. Verify status and artifact links were actually updated
    6. Delegate to git-workflow-manager to create commit
    7. Validate git-workflow-manager return
    8. Log postflight success
  </process>
  <checkpoint>Status updated to [RESEARCHED], artifacts linked and verified, git commit created</checkpoint>
</stage>
```

## References

- `specs/workflow-command-refactor-plan.md` - Root cause analysis
- `.claude/context/orchestration/state-management.md` - State management patterns
- `.claude/agent/subagents/status-sync-manager.md` - Status sync manager specification
- `.claude/agent/subagents/git-workflow-manager.md` - Git workflow manager specification
