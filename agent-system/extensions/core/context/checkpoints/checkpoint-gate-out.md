# Checkpoint: GATE OUT (Postflight)

The GATE OUT checkpoint validates the skill/agent return and updates status with artifacts.

## Execution Steps

### 1. Validate Return Structure

Check that skill return matches required schema:

```json
{
  "status": "completed|partial|failed",  // REQUIRED
  "summary": "string",                    // REQUIRED
  "artifacts": [                          // REQUIRED (can be empty)
    {
      "type": "research|plan|summary",
      "path": "string",
      "summary": "string"
    }
  ],
  "metadata": {},                         // OPTIONAL
  "next_steps": "string"                  // OPTIONAL
}
```

If missing required fields: RETRY (ask skill to re-emit return).

### 2. Verify Artifacts Exist

For each artifact in the return:

```bash
for artifact in "${artifacts[@]}"; do
  if [ ! -f "$artifact_path" ]; then
    echo "ERROR: Artifact not found: $artifact_path"
    # Continue but flag error
  fi
done
```

### 2b. Lean4-Specific: Plan Compliance Verification (lean4 / lean task_type only)

If `task_type` is "lean4" or "lean", verify that the skill's Stage 6b plan compliance check ran and passed:

```bash
# Read compliance result from metadata (backward compatible: absent field = "skipped")
compliance_status=$(jq -r '.metadata.compliance_check // "skipped"' "$metadata_file" 2>/dev/null)

case "$compliance_status" in
    "failed")
        echo "GATE OUT: Plan compliance check FAILED — plan deliverables not all present or integrity violation detected"
        echo "  Check skill Stage 6b output for missing theorem names or replacement-delegation issues"
        decision="PARTIAL"
        ;;
    "passed")
        echo "GATE OUT: Plan compliance check PASSED"
        ;;
    "skipped"|*)
        echo "INFO: Plan compliance check skipped or not present in metadata — proceeding"
        ;;
esac
```

If `metadata_file` does not contain the `compliance_check` field (older skill version or non-lean4 task), emit INFO and proceed normally. This section is backward compatible.

### 3. Update Status (via skill-status-sync)

Invoke skill-status-sync with operation: `postflight_update`

```
task_number: {N}
target_status: {completed_variant}
artifacts: [{type, path}...]
session_id: {session_id}
```

Completed variants:
- researched (after the research phase)
- planned (after the plan phase)
- completed (after the implement phase)
- partial (if status == "partial")

### 4. Link Artifacts (via skill-status-sync)

For each artifact, invoke: `artifact_link`

```
task_number: {N}
artifact_path: {path}
artifact_type: {type}
```

The artifact_link operation includes idempotency check:

```bash
# Check if link already exists
if grep -q "$artifact_path" specs/TODO.md; then
  echo "Link already exists, skipping"
else
  # Add link to TODO.md
fi
```

### 5. Verify All Updates

Re-read both files and verify:
- state.json has correct status
- state.json artifacts array includes new artifacts
- TODO.md has status marker updated
- TODO.md has artifact links

## Decision

- **PROCEED**: All validations pass, ready for commit
- **RETRY**: Return validation failed (re-invoke skill)
- **PARTIAL**: Some artifacts missing but status updated

## Output

Pass to commit stage:
- session_id
- task_number
- final_status
- artifacts_linked[]
- commit_message (composed from operation)
