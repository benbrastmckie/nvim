# Subagent Return Validation

---

> **DEPRECATED** (2026-01-19): This file has been consolidated into:
> - `orchestration-validation.md` - Return validation steps, artifact verification
>
> This file is preserved for reference but should not be loaded for new development.

---

## Overview

All workflow commands (`/research`, `/plan`, `/revise`, `/implement`) MUST validate subagent returns using this standardized process before executing postflight operations.

This validation prevents phantom work (status updates without actual artifacts) and ensures consistency across all workflow commands.

## Standard Validation Process

Commands MUST execute these validation steps in Stage 3 (ValidateReturn) after receiving subagent output:

### Step 1: Validate JSON Structure

Parse return as JSON using jq:

```bash
# Attempt to parse return as JSON
if ! echo "$subagent_return" | jq empty 2>/dev/null; then
  echo "[FAIL] Invalid JSON return from ${target_agent}"
  echo "Error: Cannot parse return as JSON"
  echo "Recommendation: Fix ${target_agent} subagent return format"
  exit 1
fi

echo "[PASS] Return is valid JSON"
```

**If parsing fails:**
- Log error: `[FAIL] Invalid JSON return from ${target_agent}`
- Return error to user: `Subagent return validation failed: Cannot parse return as JSON`
- Recommendation: `Fix ${target_agent} subagent to return valid JSON`
- Exit with error

### Step 2: Validate Required Fields

Check that all required fields exist:

```bash
# Required top-level fields
required_fields=("status" "summary" "artifacts" "metadata")

for field in "${required_fields[@]}"; do
  if ! echo "$subagent_return" | jq -e ".$field" >/dev/null 2>&1; then
    echo "[FAIL] Missing required field: $field"
    echo "Error: Subagent return validation failed"
    echo "Recommendation: Fix ${target_agent} subagent to include all required fields"
    exit 1
  fi
done

# Required metadata subfields
metadata_fields=("session_id" "agent_type" "delegation_depth" "delegation_path")

for field in "${metadata_fields[@]}"; do
  if ! echo "$subagent_return" | jq -e ".metadata.$field" >/dev/null 2>&1; then
    echo "[FAIL] Missing required metadata field: $field"
    echo "Error: Subagent return validation failed"
    echo "Recommendation: Fix ${target_agent} subagent to include all required metadata fields"
    exit 1
  fi
done

echo "[PASS] All required fields present"
```

**Required fields:**
- `status`: Subagent execution status
- `summary`: Brief description of work completed
- `artifacts`: Array of created artifacts
- `metadata`: Delegation tracking information
  - `session_id`: Session identifier
  - `agent_type`: Name of subagent
  - `delegation_depth`: Current delegation depth
  - `delegation_path`: Array of agent names in chain

**If any field missing:**
- Log error: `[FAIL] Missing required field: ${field}`
- Return error to user: `Subagent return validation failed: Missing required field: ${field}`
- Recommendation: `Fix ${target_agent} subagent to include all required fields`
- Exit with error

### Step 3: Validate Status Field

Check status is a valid enum value:

```bash
# Extract status
status=$(echo "$subagent_return" | jq -r '.status')

# Valid status values
valid_statuses=("completed" "partial" "failed" "blocked")

# Check if status is valid
if [[ ! " ${valid_statuses[@]} " =~ " ${status} " ]]; then
  echo "[FAIL] Invalid status: $status"
  echo "Valid statuses: completed, partial, failed, blocked"
  echo "Error: Subagent return validation failed"
  echo "Recommendation: Fix ${target_agent} subagent to use valid status enum"
  exit 1
fi

echo "[PASS] Status is valid: $status"
```

**Valid status values:**
- `completed`: Work completed successfully
- `partial`: Work partially completed (can be resumed)
- `failed`: Work failed (cannot proceed)
- `blocked`: Work blocked by external dependency

**If status invalid:**
- Log error: `[FAIL] Invalid status: ${status}`
- Log: `Valid statuses: completed, partial, failed, blocked`
- Return error to user: `Subagent return validation failed: Invalid status: ${status}`
- Recommendation: `Fix ${target_agent} subagent to use valid status enum`
- Exit with error

### Step 4: Validate Session ID

Compare returned session_id with expected value:

```bash
# Extract returned session_id
returned_session_id=$(echo "$subagent_return" | jq -r '.metadata.session_id')

# Compare with expected session_id (from delegation context)
if [ "$returned_session_id" != "$expected_session_id" ]; then
  echo "[FAIL] Session ID mismatch"
  echo "Expected: $expected_session_id"
  echo "Got: $returned_session_id"
  echo "Error: Subagent return validation failed"
  echo "Recommendation: Fix ${target_agent} subagent to return correct session_id"
  exit 1
fi

echo "[PASS] Session ID matches"
```

**If mismatch:**
- Log error: `[FAIL] Session ID mismatch`
- Log: `Expected: ${expected_session_id}`
- Log: `Got: ${returned_session_id}`
- Return error to user: `Subagent return validation failed: Session ID mismatch`
- Recommendation: `Fix ${target_agent} subagent to return correct session_id`
- Exit with error

### Step 5: Validate Artifacts (CRITICAL)

**Only validate artifacts if status == "completed"**

This is the most critical validation step - it prevents phantom work where subagents claim completion without creating artifacts.

```bash
# Only validate artifacts if status is completed
if [ "$status" == "completed" ]; then
  # Step 5a: Check artifacts array is non-empty
  artifact_count=$(echo "$subagent_return" | jq '.artifacts | length')
  
  if [ "$artifact_count" -eq 0 ]; then
    echo "[FAIL] Agent returned 'completed' status but created no artifacts"
    echo "Error: Phantom work detected - status=completed but no artifacts"
    echo "Recommendation: Verify ${target_agent} creates artifacts before updating status"
    exit 1
  fi
  
  echo "[INFO] Artifact count: $artifact_count"
  
  # Step 5b: Verify each artifact exists on disk
  artifact_paths=$(echo "$subagent_return" | jq -r '.artifacts[].path')
  
  for path in $artifact_paths; do
    if [ ! -f "$path" ]; then
      echo "[FAIL] Artifact does not exist: $path"
      echo "Error: Subagent claimed to create artifact but file does not exist"
      echo "Recommendation: Verify ${target_agent} writes artifacts to correct paths"
      exit 1
    fi
    echo "[PASS] Artifact exists: $path"
  done
  
  # Step 5c: Verify each artifact is non-empty
  for path in $artifact_paths; do
    if [ ! -s "$path" ]; then
      echo "[FAIL] Artifact is empty: $path"
      echo "Error: Subagent created file but wrote no content"
      echo "Recommendation: Verify ${target_agent} writes content to artifacts"
      exit 1
    fi
    
    # Get file size for logging
    file_size=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path")
    echo "[PASS] Artifact is non-empty: $path ($file_size bytes)"
  done
  
  echo "[PASS] $artifact_count artifacts validated"
else
  echo "[INFO] Skipping artifact validation (status=$status)"
  echo "Note: Partial/failed/blocked status may have empty or incomplete artifacts"
fi
```

**Artifact validation steps:**

a. **Check artifacts array is non-empty:**
   - Extract artifact count: `artifact_count=$(echo "$subagent_return" | jq '.artifacts | length')`
   - If count == 0 and status == "completed":
     - Log error: `[FAIL] Agent returned 'completed' status but created no artifacts`
     - Log error: `Error: Phantom work detected - status=completed but no artifacts`
     - Return error to user: `Subagent return validation failed: Phantom work detected`
     - Recommendation: `Verify ${target_agent} creates artifacts before updating status`
     - Exit with error

b. **Verify each artifact exists on disk:**
   - Extract artifact paths: `artifact_paths=$(echo "$subagent_return" | jq -r '.artifacts[].path')`
   - For each path:
     - Check file exists: `[ -f "$path" ]`
     - If file does not exist:
       - Log error: `[FAIL] Artifact does not exist: ${path}`
       - Return error to user: `Subagent return validation failed: Artifact not found: ${path}`
       - Recommendation: `Verify ${target_agent} writes artifacts to correct paths`
       - Exit with error
     - If file exists:
       - Log: `[PASS] Artifact exists: ${path}`

c. **Verify each artifact is non-empty:**
   - For each path:
     - Check file is non-empty: `[ -s "$path" ]`
     - If file is empty:
       - Log error: `[FAIL] Artifact is empty: ${path}`
       - Return error to user: `Subagent return validation failed: Empty artifact: ${path}`
       - Recommendation: `Verify ${target_agent} writes content to artifacts`
       - Exit with error
     - If file is non-empty:
       - Get file size: `file_size=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path")`
       - Log: `[PASS] Artifact is non-empty: ${path} (${file_size} bytes)`

d. **Log validation success:**
   - Log: `[PASS] ${artifact_count} artifacts validated`

**If status != "completed":**
- Log: `[INFO] Skipping artifact validation (status=${status})`
- Note: Partial/failed/blocked status may have empty or incomplete artifacts

### Step 6: Validation Summary

Log overall validation result:

```bash
echo "[PASS] Return validation succeeded"
echo "Status: $status"

if [ "$status" == "completed" ]; then
  echo "Artifacts: $artifact_count validated"
fi
```

## Integration with Command Files

Command files MUST execute this validation in Stage 3 (ValidateReturn) before proceeding to Stage 3.5 (Postflight).

**Example integration in research.md:**

```markdown
<stage id="3" name="ValidateReturn">
  <action>Validate subagent return format and artifacts</action>
  <process>
    1. Log return for debugging
    2. Execute VALIDATION STEP 1: Validate JSON Structure
    3. Execute VALIDATION STEP 2: Validate Required Fields
    4. Execute VALIDATION STEP 3: Validate Status Field
    5. Execute VALIDATION STEP 4: Validate Session ID
    6. Execute VALIDATION STEP 5: Validate Artifacts (CRITICAL)
    7. Log Validation Summary
  </process>
  <checkpoint>Subagent return validated, all checks passed</checkpoint>
</stage>
```

## Error Handling

All validation errors MUST:
1. Log error with `[FAIL]` prefix
2. Return error to user with clear message
3. Include recommendation for fixing the issue
4. Exit with error (do NOT proceed to postflight)

This ensures that status updates and artifact linking only happen when work is actually completed.

## Benefits

This standardized validation provides:

1. **Phantom Work Prevention**: Ensures artifacts exist before updating status
2. **Consistency**: All workflow commands use same validation logic
3. **Debugging**: Clear error messages with recommendations
4. **Defense in Depth**: Multiple validation layers catch different failure modes
5. **Traceability**: Session ID validation ensures correct delegation chain

## References

- `specs/workflow-command-refactor-plan.md` - Root cause analysis
- `.claude/context/formats/subagent-return.md` - Return format specification
- `.claude/context/orchestration/delegation.md` - Delegation patterns
