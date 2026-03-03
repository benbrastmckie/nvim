# Validation Strategy

---

> **DEPRECATED** (2026-01-19): This file has been consolidated into:
> - `orchestration-validation.md` - Validation philosophy, return validation, error codes
>
> This file is preserved for reference but should not be loaded for new development.

---

## Orchestrator Validation Philosophy

The orchestrator validates **structural correctness** and **safety constraints**, not business logic or domain-specific rules.

## High-Value Checks (DO Validate)

### Task Number Validation
**When**: Command requires task_number parameter
**Checks**:
- Task number is integer (regex: `^\d+$`)
- Task exists in specs/TODO.md (grep `^### {number}\.`)
- Extract task status (for status transition validation)
- Extract task language (for routing)

**Cost**: ~50ms (file read + grep)  
**Benefit**: Prevents 80% of user errors  
**Verdict**: ✅ Worth it

### Delegation Safety Checks
**When**: Every delegation
**Checks**:
- delegation_depth ≤ 3
- No cycles in delegation_path (target not in path)
- session_id is unique (not in active registry)

**Cost**: ~5ms (in-memory checks)  
**Benefit**: Prevents infinite loops and hangs  
**Verdict**: ✅ Worth it

### Command Argument Validation
**When**: Parsing command arguments
**Checks**:
- Required arguments present
- Argument types correct (integer, string, etc.)
- Flag syntax valid

**Cost**: ~1ms (string parsing)  
**Benefit**: Clear error messages for user  
**Verdict**: ✅ Worth it

### Return Format Validation
**When**: Receiving subagent return
**Checks**:
- Return is valid JSON
- Required fields present (status, summary, artifacts, metadata, session_id)
- Status is valid enum (completed|partial|failed|blocked)
- session_id matches expected
- Summary <100 tokens

**Cost**: ~10ms (JSON parsing + validation)  
**Benefit**: Ensures consistent return handling  
**Verdict**: ✅ Worth it  
**Status**: ✅ IMPLEMENTED (Task 280) - Command files Stage 3 (ValidateReturn)

## Low-Value Checks (DON'T Validate)

### Business Logic Validation
**Examples**:
- Plan file already exists (let planner check and warn)
- Task has research artifacts (let planner harvest if available)
- Specific file permissions (let agent fail with clear error)

**Rationale**: These are agent-specific concerns, not orchestrator concerns  
**Verdict**: ❌ Skip - Let agents handle

### Deep Validation
**Examples**:
- Plan file format/structure (let planner validate)
- Research report completeness (let researcher validate)
- Implementation correctness (let implementer validate)
- Lean syntax correctness (let lean-implementation-agent validate)

**Rationale**: Orchestrator shouldn't understand domain-specific formats  
**Verdict**: ❌ Skip - Let agents handle

### Artifact Existence (Partial)
**When to check**: Only if status=completed
**When to skip**: If status=partial or failed

**Rationale**: 
- Completed tasks MUST have artifacts (worth validating)
- Partial/failed tasks MAY have artifacts (not worth validating)

**Verdict**: ✅ Validate for completed, ❌ Skip for partial/failed

## Validation Stages

### Command File Stage 1: ParseAndValidate
**Validates**:
- Task number (if required)
- Task exists in specs/state.json
- Task status allows operation
- Argument syntax and types

**Does NOT validate**:
- Business logic (plan exists, etc.)
- File permissions
- Domain-specific rules

### Command File Stage 3: ValidateReturn
**Validates**:
- Return format (JSON schema)
- Required fields present
- session_id matches
- Status enum valid
- Summary token limit
- Artifacts exist (if status=completed)
- Artifacts are non-empty (if status=completed)

**Does NOT validate**:
- Artifact content/format
- Business logic correctness
- Domain-specific rules

**Implementation**: See `.opencode/commands/*.md` Stage 3 for executable validation logic

## Error Handling

### Validation Failures
**Orchestrator validation fails** → Return error immediately, don't delegate

**Agent validation fails** → Agent returns failed status with clear error message

### Error Messages
**Good** (orchestrator): "Task 999 not found in specs/TODO.md"  
**Good** (agent): "Plan already exists at path/to/plan.md. Use /revise to update."

**Bad** (orchestrator): "Plan already exists" (business logic, not orchestrator concern)  
**Bad** (agent): "Invalid task number" (should be caught by orchestrator)

## Summary

| Validation Type | Command File | Agent |
|----------------|--------------|-------|
| Task exists | ✅ | ❌ |
| Task number format | ✅ | ❌ |
| Task status | ✅ | ❌ |
| Return format | ✅ | ❌ |
| Artifacts exist | ✅ | ❌ |
| Plan exists | ❌ | ✅ |
| Research complete | ❌ | ✅ |
| File permissions | ❌ | ✅ |
| Domain rules | ❌ | ✅ |
| Artifact format | ❌ | ✅ |

**Note**: In orchestrator v7.0, command files handle validation (not orchestrator). Orchestrator is a pure router that loads command files and delegates with $ARGUMENTS.

---

## Validation Gates for /task Command Flags

### Flag Validation (Stage 1)

**Single Flag Enforcement**:
```bash
# Count flags present
flag_count=0
[[ "$ARGUMENTS" =~ --recover ]] && ((flag_count++))
[[ "$ARGUMENTS" =~ --expand ]] && ((flag_count++))
[[ "$ARGUMENTS" =~ --sync ]] && ((flag_count++))
[[ "$ARGUMENTS" =~ --abandon ]] && ((flag_count++))

if [ $flag_count -gt 1 ]; then
  echo "[FAIL] Only one flag allowed at a time"
  echo "Error: Multiple flags detected: $ARGUMENTS"
  exit 1
fi

echo "[PASS] Single flag validation passed"
```

### Range Parsing Validation

**Format Validation**:
```bash
# Validate range format: "343", "343-345", "337, 343-345, 350"
validate_range() {
  local range="$1"
  
  # Check for valid characters only (digits, dash, comma, space)
  if ! [[ "$range" =~ ^[0-9,\ -]+$ ]]; then
    echo "[FAIL] Invalid range format: $range"
    echo "Valid formats: '343', '343-345', '337, 343-345, 350'"
    exit 1
  fi
  
  # Validate each part
  IFS=',' read -ra parts <<< "$range"
  for part in "${parts[@]}"; do
    part=$(echo "$part" | tr -d ' ')
    
    if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      # Range: validate start <= end
      start="${BASH_REMATCH[1]}"
      end="${BASH_REMATCH[2]}"
      if [ "$start" -gt "$end" ]; then
        echo "[FAIL] Invalid range: $part (start > end)"
        exit 1
      fi
    elif ! [[ "$part" =~ ^[0-9]+$ ]]; then
      echo "[FAIL] Invalid range part: $part"
      exit 1
    fi
  done
  
  echo "[PASS] Range format validation passed"
}
```

### Git Blame Timestamp Validation

**Timestamp Extraction and Comparison**:
```bash
# Get git blame timestamp for specs/TODO.md field
get_todo_timestamp() {
  local task_number="$1"
  local field="$2"
  
  # Find task entry line range
  start_line=$(grep -n "^### ${task_number}\." specs/TODO.md | cut -d: -f1)
  end_line=$(tail -n +$start_line specs/TODO.md | grep -n "^---$" | head -1 | cut -d: -f1)
  end_line=$((start_line + end_line - 1))
  
  # Get commit hash for field line
  commit_hash=$(git blame -L ${start_line},${end_line} specs/TODO.md | grep "$field" | awk '{print $1}')
  
  # Get commit timestamp
  timestamp=$(git show -s --format=%ct "$commit_hash")
  
  echo "$timestamp"
}

# Get git blame timestamp for specs/state.json field
get_state_timestamp() {
  local task_number="$1"
  
  # Get last commit that modified this task in specs/state.json
  timestamp=$(git log -1 --format=%ct -S "\"project_number\": $task_number" -- specs/state.json)
  
  echo "$timestamp"
}

# Compare timestamps and determine winner
resolve_conflict() {
  local task_number="$1"
  local field="$2"
  local todo_timestamp=$(get_todo_timestamp "$task_number" "$field")
  local state_timestamp=$(get_state_timestamp "$task_number")
  
  if [ "$state_timestamp" -gt "$todo_timestamp" ]; then
    echo "specs/state.json"  # specs/state.json wins
  elif [ "$todo_timestamp" -gt "$state_timestamp" ]; then
    echo "specs/TODO.md"  # specs/TODO.md wins
  else
    echo "specs/state.json"  # Tie-breaker: specs/state.json wins
  fi
}
```

### Bulk Operation Validation

**All-or-Nothing vs Partial Success**:

**All-or-Nothing (Recommended)**:
```bash
# Validate all tasks before processing any
validate_all_tasks() {
  local task_numbers=("$@")
  local errors=()
  
  for task_num in "${task_numbers[@]}"; do
    # Check task exists in archive (for --recover)
    if ! jq -e ".archived_projects[] | select(.project_number == $task_num)" specs/archive/state.json > /dev/null; then
      errors+=("Task $task_num not found in archive")
    fi
    
    # Check task not already active
    if jq -e ".active_projects[] | select(.project_number == $task_num)" specs/state.json > /dev/null; then
      errors+=("Task $task_num already active")
    fi
  done
  
  # If any errors, abort before processing
  if [ ${#errors[@]} -gt 0 ]; then
    echo "[FAIL] Validation failed for ${#errors[@]} tasks:"
    printf '%s\n' "${errors[@]}"
    exit 1
  fi
  
  echo "[PASS] All tasks validated"
}
```

**Partial Success (Alternative)**:
```bash
# Process tasks individually, report partial success
process_with_partial_success() {
  local task_numbers=("$@")
  local success_count=0
  local failure_count=0
  local errors=()
  
  for task_num in "${task_numbers[@]}"; do
    if process_task "$task_num"; then
      ((success_count++))
    else
      ((failure_count++))
      errors+=("Task $task_num: $error_message")
    fi
  done
  
  # Return partial success
  echo "[INFO] Processed $success_count tasks successfully, $failure_count failed"
  
  if [ $failure_count -gt 0 ]; then
    echo "[WARN] Partial failure:"
    printf '%s\n' "${errors[@]}"
  fi
}
```

### Task Division Validation

**Pre-Division Validation**:
```bash
# Validate task can be divided
validate_division() {
  local task_number="$1"
  
  # Check task exists
  if ! jq -e ".active_projects[] | select(.project_number == $task_number)" specs/state.json > /dev/null; then
    echo "[FAIL] Task $task_number not found in active_projects"
    exit 1
  fi
  
  # Check task status allows division
  status=$(jq -r ".active_projects[] | select(.project_number == $task_number) | .status" specs/state.json)
  if [[ "$status" == "completed" || "$status" == "abandoned" ]]; then
    echo "[FAIL] Cannot divide $status task"
    exit 1
  fi
  
  # Check task has no existing dependencies
  deps=$(jq -r ".active_projects[] | select(.project_number == $task_number) | .dependencies | length" specs/state.json)
  if [ "$deps" -gt 0 ]; then
    echo "[FAIL] Task $task_number already has dependencies"
    exit 1
  fi
  
  echo "[PASS] Task division validation passed"
}
```

**Subtask Count Validation**:
```bash
# Validate subtask count is 1-5
validate_subtask_count() {
  local count="$1"
  
  if [ "$count" -lt 1 ] || [ "$count" -gt 5 ]; then
    echo "[FAIL] Subtask count must be 1-5, got: $count"
    exit 1
  fi
  
  echo "[PASS] Subtask count validation passed: $count"
}
```

---

# Validation Rules Standard

## Overview

This standard defines validation rules for subagent returns, including return format validation and artifact verification.

**ENFORCEMENT**: These validation rules are ENFORCED by command files (`.opencode/commands/*.md`) in Stage 3 (ValidateReturn). All subagent returns are validated before relaying results to the user. Validation failures result in immediate error reporting to the user and workflow termination.

**IMPLEMENTATION**: See command files for executable validation logic:
- `.opencode/commands/research.md` Stage 3 (ValidateReturn)
- `.opencode/commands/plan.md` Stage 3 (ValidateReturn)
- `.opencode/commands/revise.md` Stage 3 (ValidateReturn)
- `.opencode/commands/implement.md` Stage 3 (ValidateReturn)

**ARCHITECTURE NOTE**: In orchestrator v7.0 (pure router architecture), validation moved from orchestrator Stage 4 to command files Stage 3. This reflects the architectural shift from centralized orchestrator to distributed command files.

## Return Format Validation

All subagents must return a standard JSON format (see `core/standards/delegation.md`).

### Required Fields

```json
{
  "status": "completed|partial|failed|blocked",
  "summary": "Brief 2-5 sentence summary (<100 tokens)",
  "artifacts": [...],
  "metadata": {
    "session_id": "...",
    "duration_seconds": 123,
    "agent_type": "...",
    "delegation_depth": 1,
    "delegation_path": [...]
  },
  "errors": [...],
  "next_steps": "..."
}
```

### Validation Steps

#### Step 1: Validate JSON Structure

```bash
# Parse return as JSON
if ! echo "$return" | jq . > /dev/null 2>&1; then
  echo "[FAIL] Invalid JSON return from ${agent}"
  exit 1
fi

echo "[PASS] Return is valid JSON"
```

#### Step 2: Validate Required Fields

```bash
# Check required fields exist
required_fields=("status" "summary" "artifacts" "metadata" "session_id")

for field in "${required_fields[@]}"; do
  if ! echo "$return" | jq -e ".${field}" > /dev/null 2>&1; then
    echo "[FAIL] Missing required field: ${field}"
    exit 1
  fi
done

echo "[PASS] All required fields present"
```

#### Step 3: Validate Status Field

```bash
# Check status is valid enum
status=$(echo "$return" | jq -r '.status')
valid_statuses=("completed" "partial" "failed" "blocked")

if [[ ! " ${valid_statuses[@]} " =~ " ${status} " ]]; then
  echo "[FAIL] Invalid status: ${status}"
  echo "Valid statuses: completed, partial, failed, blocked"
  exit 1
fi

echo "[PASS] Status is valid: ${status}"
```

#### Step 4: Validate Session ID

```bash
# Check session_id matches expected
returned_session_id=$(echo "$return" | jq -r '.session_id')

if [ "$returned_session_id" != "$expected_session_id" ]; then
  echo "[FAIL] Session ID mismatch"
  echo "Expected: ${expected_session_id}"
  echo "Got: ${returned_session_id}"
  exit 1
fi

echo "[PASS] Session ID matches"
```

#### Step 5: Validate Summary Token Limit

```bash
# Check summary is <100 tokens (~400 characters)
summary=$(echo "$return" | jq -r '.summary')
summary_length=${#summary}

if [ $summary_length -gt 400 ]; then
  echo "[WARN] Summary exceeds recommended length: ${summary_length} characters"
  # Non-critical warning, continue
fi
```

## Artifact Validation (CRITICAL)

Prevents "phantom research" - status=completed but no artifacts created.

### When to Validate

**Only validate artifacts if status == "completed"**

For partial/failed/blocked status, artifacts may be empty or incomplete.

### Validation Steps

#### Step 1: Check Artifacts Array is Non-Empty

```bash
if [ "$status" == "completed" ]; then
  artifact_count=$(echo "$return" | jq '.artifacts | length')
  
  if [ $artifact_count -eq 0 ]; then
    echo "[FAIL] Agent returned 'completed' status but created no artifacts"
    echo "Error: Phantom research detected - status=completed but no artifacts"
    exit 1
  fi
  
  echo "[INFO] Artifact count: ${artifact_count}"
fi
```

#### Step 2: Verify Each Artifact Exists

```bash
if [ "$status" == "completed" ]; then
  # Extract artifact paths
  artifact_paths=$(echo "$return" | jq -r '.artifacts[].path')
  
  for path in $artifact_paths; do
    # Check file exists
    if [ ! -f "$path" ]; then
      echo "[FAIL] Artifact does not exist: ${path}"
      exit 1
    fi
    
    echo "[PASS] Artifact exists: ${path}"
  done
fi
```

#### Step 3: Verify Each Artifact is Non-Empty

```bash
if [ "$status" == "completed" ]; then
  for path in $artifact_paths; do
    # Check file is non-empty (size > 0)
    if [ ! -s "$path" ]; then
      echo "[FAIL] Artifact is empty: ${path}"
      exit 1
    fi
    
    file_size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path")
    echo "[PASS] Artifact is non-empty: ${path} (${file_size} bytes)"
  done
  
  echo "[PASS] ${artifact_count} artifacts validated"
fi
```

### Why This Matters

**Problem**: Agents may update status to "completed" without actually creating artifacts.

**Example**:
```json
{
  "status": "completed",
  "summary": "Research completed successfully",
  "artifacts": [],  // Empty! No research was actually done
  "metadata": {...}
}
```

**Impact**: User thinks research is done, but no research report exists.

**Solution**: Validate artifacts array is non-empty and all files exist.

## Error Handling

### Invalid JSON Return

**Error**:
```
[FAIL] Invalid JSON return from {agent}
Error: Cannot parse return as JSON
```

**Recommendation**: Fix {agent} subagent return format

### Missing Required Field

**Error**:
```
[FAIL] Missing required field: {field}
Error: Subagent return is incomplete
```

**Recommendation**: Fix {agent} subagent to include all required fields

### Invalid Status

**Error**:
```
[FAIL] Invalid status: {status}
Valid statuses: completed, partial, failed, blocked
```

**Recommendation**: Fix {agent} subagent to use valid status enum

### Session ID Mismatch

**Error**:
```
[FAIL] Session ID mismatch
Expected: {expected}
Got: {actual}
```

**Recommendation**: Fix {agent} subagent to return correct session_id

### Phantom Research Detected

**Error**:
```
[FAIL] Agent returned 'completed' status but created no artifacts
Error: Phantom research detected - status=completed but no artifacts
```

**Recommendation**: Verify {agent} creates artifacts before updating status

### Artifact Not Found

**Error**:
```
[FAIL] Artifact does not exist: {path}
Error: Artifact validation failed
```

**Recommendation**: Verify {agent} writes artifacts to correct paths

### Empty Artifact

**Error**:
```
[FAIL] Artifact is empty: {path}
Error: Artifact validation failed
```

**Recommendation**: Verify {agent} writes content to artifacts

## Validation Summary

After all validations pass, log summary:

```
[PASS] Return validation succeeded
[PASS] {N} artifacts validated
```

## Implementation Status

**STATUS**: ✅ ENFORCED (as of Task 280)

These validation rules are now ACTIVELY ENFORCED by command files Stage 3 (ValidateReturn). Prior to Task 280, these rules were documented but not executed, leading to "phantom research" incidents where agents claimed completion without creating artifacts.

**Key Changes**:
- Command files Stage 3 (ValidateReturn) added with executable validation logic
- All 5 validation steps now executed for every subagent return
- Validation failures result in immediate error reporting and workflow termination
- Prevents phantom research/planning/implementation across all workflow commands

**Validation Execution Flow**:
1. Command file Stage 1: Parse and validate arguments
2. Command file Stage 2: Delegate to subagent, capture return
3. Command file Stage 3: Execute validation steps 1-5 on return
4. If validation fails: Error reported to user, workflow terminated
5. If validation passes: Proceed to Stage 4 (RelayResult)

**Architecture Evolution**:
- **v5.0**: Orchestrator Stage 4 (ValidateReturn) - documentation only, not executed
- **v7.0**: Command files Stage 3 (ValidateReturn) - executable validation logic
- **Rationale**: v7.0 orchestrator is pure router, command files handle delegation and validation

**Testing**:
- Validation tested with malformed returns (plain text, missing fields, invalid status)
- Validation tested with phantom research scenarios (status=completed, no artifacts)
- Validation tested with missing/empty artifact files
- All workflow commands (/research, /plan, /implement, /revise) protected

## See Also

- **Command Files Stage 3**: `.opencode/commands/*.md` Stage 3 (ValidateReturn) - Executable validation logic
- **Validation Template**: `specs/280_fix_orchestrator_stage_4_validation/validation-template.md` - Reusable validation section
- Delegation Standard: `.opencode/context/core/standards/delegation.md`
- Subagent Return Format: `.opencode/context/core/standards/subagent-return-format.md`
- State Management: `.opencode/context/core/system/state-management.md`
- Routing Logic: `.opencode/context/core/system/routing-logic.md`
