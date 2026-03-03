# Checkpoint: COMMIT (Finalization)

The COMMIT checkpoint creates a git commit and completes the operation.

## Execution Steps

### 1. Stage All Changes

```bash
git add -A
```

### 2. Compose Commit Message

Format depends on operation:

**Research:**
```
task {N}: complete research

Session: {session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

**Plan:**
```
task {N}: create implementation plan

Session: {session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

**Implementation (complete):**
```
task {N}: complete implementation

Session: {session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

**Implementation (partial):**
```
task {N}: partial implementation (phases 1-{M} of {total})

Session: {session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

**Implementation (phase):**
```
task {N} phase {P}: {phase_name}

Session: {session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

### 3. Create Commit

```bash
git commit -m "$(cat <<'EOF'
{commit_message}
EOF
)"
```

### 4. Verify Commit

```bash
# Verify commit was created
if [ $? -eq 0 ]; then
  commit_hash=$(git rev-parse HEAD)
  echo "Commit created: $commit_hash"
else
  echo "WARNING: Commit failed (non-blocking)"
fi
```

### 5. Log Session Completion

Record in operation log (optional):
- session_id
- operation
- task_number
- commit_hash
- timestamp

## Error Handling

Git commit failures are **non-blocking**:
- Log the failure
- Do not roll back state updates
- Report to user that commit failed
- Continue with success return

## Output

Return to caller:
```json
{
  "status": "completed|partial|failed",
  "summary": "{operation summary}",
  "artifacts": [{artifact_list}],
  "metadata": {
    "session_id": "{session_id}",
    "commit_hash": "{hash or null}",
    "phases_completed": {N},
    "phases_total": {M}
  },
  "next_steps": "{guidance}"
}
```
