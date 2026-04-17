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

### 3. Update Status (via skill-status-sync)

Invoke skill-status-sync with operation: `postflight_update`

```
task_number: {N}
target_status: {completed_variant}
artifacts: [{type, path}...]
session_id: {session_id}
```

Completed variants:
- researched (after /research)
- planned (after /plan)
- completed (after /implement)
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
