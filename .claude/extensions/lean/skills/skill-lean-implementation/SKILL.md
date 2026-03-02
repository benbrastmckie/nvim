---
name: skill-lean-implementation
description: Implement Lean 4 proofs and definitions using lean-lsp tools. Invoke for Lean-language implementation tasks.
allowed-tools: Task, Bash, Edit, Read, Write
---

# Lean Implementation Skill

Thin wrapper that delegates Lean 4 proof implementation to `lean-implementation-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Trigger Conditions

This skill activates when:
- Task language is "lean"
- /implement command targets a Lean task
- Plan exists and task is ready for implementation

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Task status must allow implementation (planned, implementing, partial)
- Task language must be "lean"

```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
language=$(echo "$task_data" | jq -r '.language // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')

# Validate language
if [ "$language" != "lean" ]; then
  return error "Task $task_number is not a Lean task"
fi
```

---

### Stage 2: Preflight Status Update

Update task status to "implementing" BEFORE invoking subagent.

**Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "implementing" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid,
    started: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

**Update TODO.md**: Use Edit tool to change status marker from `[PLANNED]` to `[IMPLEMENTING]`.

---

### Stage 3: Prepare Delegation Context

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-lean-implementation"],
  "timeout": 7200,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "language": "lean"
  },
  "plan_path": "specs/{N}_{SLUG}/plans/implementation-{NNN}.md",
  "metadata_file_path": "specs/{N}_{SLUG}/.return-meta.json"
}
```

---

### Stage 4: Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "lean-implementation-agent"
  - prompt: [Include task_context, delegation_context, plan_path, metadata_file_path]
  - description: "Execute Lean implementation for task {N}"
```

**DO NOT** use `Skill(lean-implementation-agent)` - this will FAIL.

The subagent will:
- Load implementation context files (MCP tools guide, tactic patterns)
- Parse plan and find resume point
- Execute phases sequentially using lean-lsp MCP tools
- Verify proofs with `lean_goal` and `lake build`
- Create implementation summary
- Write metadata to `specs/{N}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5: Parse Subagent Return (Read Metadata File)

After subagent returns, read the metadata file:

```bash
metadata_file="specs/${task_number}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    phases_completed=$(jq -r '.metadata.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.metadata.phases_total // 0' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

---

### Stage 6: Zero-Debt Verification Gate (MANDATORY)

**CRITICAL**: Before proceeding to status update, verify the zero-debt completion gate.

If status from metadata is "implemented":

```bash
# Check for sorries in modified files
sorry_count=$(grep -r "\bsorry\b" Theories/ 2>/dev/null | grep -v "^[[:space:]]*--" | wc -l)

# Verify build passes
if ! lake build 2>/dev/null; then
    build_failed=true
fi

if [ "$sorry_count" -gt 0 ] || [ "$build_failed" = true ]; then
    echo "Zero-debt gate FAILED"
    status="partial"
fi
```

---

### Stage 7: Update Task Status (Postflight)

**If status is "implemented"** (verified by Stage 6):

Update state.json to "completed":
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    completed: $ts
  }' specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
```

Update TODO.md: Change status marker from `[IMPLEMENTING]` to `[COMPLETED]`.

**If status is "partial"**:

Keep status as "implementing" but update resume point.
TODO.md stays as `[IMPLEMENTING]`.

---

### Stage 8: Link Artifacts

Add summary artifact to state.json.

```bash
if [ -n "$summary_artifact_path" ]; then
    jq --arg path "$summary_artifact_path" \
       --arg summary "$summary_artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": "summary", "summary": $summary}]' \
      specs/state.json > /tmp/state.json && mv /tmp/state.json specs/state.json
fi
```

---

### Stage 9: Git Commit

Commit changes with session ID:

```bash
git add \
  "Theories/" \
  "specs/${task_number}_${project_name}/summaries/" \
  "specs/${task_number}_${project_name}/plans/" \
  "specs/TODO.md" \
  "specs/state.json"
git commit -m "task ${task_number}: complete implementation

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Stage 10: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Lean implementation completed for task {N}:
- All {phases_total} phases executed, all proofs verified
- Lake build: Success
- Key theorems: {theorem names}
- Created summary at specs/{N}_{SLUG}/summaries/implementation-summary-{DATE}.md
- Status updated to [COMPLETED]
- Changes committed
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found, wrong language, or status invalid.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "implementing"
2. Report error to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### Subagent Timeout
Return partial status if subagent times out (default 7200s).
Keep status as "implementing" for resume.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
