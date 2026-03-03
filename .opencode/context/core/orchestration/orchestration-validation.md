# Orchestration Validation

**Version**: 1.0
**Created**: 2026-01-19
**Purpose**: Return validation, artifact verification, and validation strategy
**Consolidates**: validation.md, subagent-validation.md (partial)

---

## Validation Philosophy

The orchestrator validates **structural correctness** and **safety constraints**, not business logic or domain-specific rules.

### High-Value Checks (DO Validate)

| Check | Cost | Benefit | Verdict |
|-------|------|---------|---------|
| Task exists | ~12ms | Prevents 80% of user errors | DO |
| Task number format | ~1ms | Clear error messages | DO |
| Delegation safety | ~5ms | Prevents infinite loops | DO |
| Return format | ~10ms | Ensures consistent parsing | DO |
| Artifacts exist | ~50ms | Prevents phantom work | DO |

### Low-Value Checks (DON'T Validate)

| Check | Reason | Who Validates |
|-------|--------|---------------|
| Plan already exists | Business logic | Agent |
| Research complete | Domain-specific | Agent |
| File permissions | Agent-specific | Agent |
| Lean syntax | Domain-specific | Agent |
| Artifact format | Domain-specific | Agent |

---

## Return Validation Steps

Execute these steps in order. If any step fails, abort with error.

### Step 1: Validate JSON Structure

```bash
if ! echo "$return" | jq empty 2>/dev/null; then
  echo "[FAIL] Invalid JSON return from ${agent}"
  exit 1
fi
echo "[PASS] Return is valid JSON"
```

### Step 2: Validate Required Fields

```bash
required=("status" "summary" "artifacts" "metadata")
for field in "${required[@]}"; do
  if ! echo "$return" | jq -e ".$field" >/dev/null 2>&1; then
    echo "[FAIL] Missing required field: $field"
    exit 1
  fi
done

# Also check metadata subfields
metadata_fields=("session_id" "agent_type" "delegation_depth" "delegation_path")
for field in "${metadata_fields[@]}"; do
  if ! echo "$return" | jq -e ".metadata.$field" >/dev/null 2>&1; then
    echo "[FAIL] Missing metadata field: $field"
    exit 1
  fi
done
echo "[PASS] All required fields present"
```

### Step 3: Validate Status

```bash
status=$(echo "$return" | jq -r '.status')
valid=("implemented" "researched" "planned" "partial" "failed" "blocked")

if [[ ! " ${valid[@]} " =~ " ${status} " ]]; then
  echo "[FAIL] Invalid status: $status"
  exit 1
fi
echo "[PASS] Status is valid: $status"
```

**Note**: Status values must be contextual (implemented, researched, planned) - never use "completed" or "done".

### Step 4: Validate Session ID

```bash
returned_id=$(echo "$return" | jq -r '.metadata.session_id')
if [ "$returned_id" != "$expected_session_id" ]; then
  echo "[FAIL] Session ID mismatch"
  echo "Expected: $expected_session_id"
  echo "Got: $returned_id"
  exit 1
fi
echo "[PASS] Session ID matches"
```

### Step 5: Validate Artifacts (CRITICAL)

**Only validate if status indicates successful completion** (implemented, researched, planned).

```bash
# Check if status indicates completion
if [[ "$status" =~ ^(implemented|researched|planned)$ ]]; then
  # Check artifacts array is non-empty
  artifact_count=$(echo "$return" | jq '.artifacts | length')

  if [ "$artifact_count" -eq 0 ]; then
    echo "[FAIL] Status=$status but no artifacts"
    echo "Error: Phantom work detected"
    exit 1
  fi

  # Verify each artifact exists on disk
  for path in $(echo "$return" | jq -r '.artifacts[].path'); do
    if [ ! -f "$path" ]; then
      echo "[FAIL] Artifact not found: $path"
      exit 1
    fi

    if [ ! -s "$path" ]; then
      echo "[FAIL] Artifact is empty: $path"
      exit 1
    fi

    size=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path")
    echo "[PASS] Artifact verified: $path ($size bytes)"
  done

  echo "[PASS] $artifact_count artifacts validated"
else
  echo "[INFO] Skipping artifact validation (status=$status)"
fi
```

---

## Error Codes

| Code | Meaning | Recoverable |
|------|---------|-------------|
| TIMEOUT | Operation exceeded time limit | Yes |
| VALIDATION_FAILED | Input validation failed | Yes |
| TOOL_UNAVAILABLE | Required tool not available | Yes |
| BUILD_ERROR | Compilation/build failed | Yes |
| FILE_NOT_FOUND | Required file missing | Yes |
| CYCLE_DETECTED | Delegation would create cycle | No |
| MAX_DEPTH_EXCEEDED | Depth limit (3) exceeded | No |
| STATUS_SYNC_FAILED | Failed to update state | Yes |

---

## Validation Error Handling

### On Validation Failure

1. Log error with `[FAIL]` prefix
2. Provide recommendation for fixing
3. DO NOT proceed to postflight
4. Return error to user

### Error Response Format

```json
{
  "status": "failed",
  "summary": "Validation failed: {reason}",
  "artifacts": [],
  "errors": [{
    "type": "validation",
    "message": "{detailed message}",
    "recoverable": true,
    "recommendation": "{how to fix}"
  }]
}
```

---

## /task Command Flag Validation

### Single Flag Enforcement

```bash
flag_count=0
[[ "$ARGUMENTS" =~ --recover ]] && ((flag_count++))
[[ "$ARGUMENTS" =~ --expand ]] && ((flag_count++))
[[ "$ARGUMENTS" =~ --sync ]] && ((flag_count++))
[[ "$ARGUMENTS" =~ --abandon ]] && ((flag_count++))

if [ $flag_count -gt 1 ]; then
  echo "[FAIL] Only one flag allowed at a time"
  exit 1
fi
```

### Range Format Validation

```bash
# Valid formats: "343", "343-345", "337, 343-345, 350"
validate_range() {
  local range="$1"

  if ! [[ "$range" =~ ^[0-9,\ -]+$ ]]; then
    echo "[FAIL] Invalid range format: $range"
    exit 1
  fi
}
```

---

## Quick Validation Summary

| What | Command File Stage | Agent Stage |
|------|-------------------|-------------|
| Task exists | Stage 1 | - |
| Task number format | Stage 1 | - |
| Return format | Stage 3 | - |
| Artifacts exist | Stage 3 | - |
| Plan exists | - | Stage 1 |
| Domain rules | - | Agent-specific |
| Artifact format | - | Agent-specific |

---

## Related Documentation

- `orchestration-core.md` - Session tracking, delegation safety
- `preflight-pattern.md` - Pre-delegation validation
- `postflight-pattern.md` - Post-completion validation
- `.opencode/context/core/formats/subagent-return.md` - Full return schema
