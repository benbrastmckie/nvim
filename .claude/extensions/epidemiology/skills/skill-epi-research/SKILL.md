---
name: skill-epi-research
description: Research skill for epidemiology study design and analysis planning. Invoke for epi/epi:study research tasks.
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
# Context (loaded by subagent):
#   - .claude/extensions/epidemiology/context/project/epidemiology/domain/
#   - .claude/extensions/epidemiology/context/project/epidemiology/tools/
# Tools (used by subagent):
#   - Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Epi Research Skill

Thin wrapper that delegates epidemiology research to `epi-research-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- `/research` on a task with `task_type: "epi"` or `task_type: "epi:study"`
- Epidemiology extension is available

---

## Input Parameters

### Required Parameters
- `task_number` - Task number (must exist in state.json with task_type="epi" or "epi:study")
- `session_id` - Session ID from orchestrator

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Verify task_type is "epi" or "epi:study"

```bash
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

task_type=$(echo "$task_data" | jq -r '.task_type // ""')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

if [ "$task_type" = "epi" ] || [ "$task_type" = "epi:study" ]; then
  : # valid
else
  return error "Task $task_number is not an epi task (task_type=$task_type)"
fi
```

---

### Stage 2: Preflight Status Update

| state.json status | TODO.md marker |
|------------------|----------------|
| researching | [RESEARCHING] |

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researching" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

---

### Stage 3: Create Postflight Marker

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-epi-research",
  "task_number": ${task_number},
  "operation": "epi_research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 4: Prepare Delegation Context

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "research", "skill-epi-research"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "workflow_type": "epi_research",
  "forcing_data": "{from state.json task metadata: study_design, data_paths, etc.}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 5: Invoke Subagent

**CRITICAL**: Use the **Task** tool to spawn the subagent.

```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "epi-research-agent"
  - prompt: [Include task_context, delegation_context, workflow_type, forcing_data, metadata_file_path]
  - description: "Execute epi_research for task {N}"
```

**DO NOT** use `Skill(epi-research-agent)` - this will FAIL.

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Read Metadata File

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    meta_status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    meta_status="failed"
fi
```

---

### Stage 7: Update Task Status (Postflight)

**MUST NOT cross the postflight boundary**: The subagent MUST NOT update state.json or TODO.md status.
Only this skill performs postflight status transitions.

| Meta Status | Final state.json | Final TODO.md |
|-------------|-----------------|---------------|
| researched | researched | [RESEARCHED] |
| partial | researching | [RESEARCHING] |
| failed | (keep preflight) | (keep preflight marker) |

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary. Use the two-step jq pattern to avoid Issue #1132.
Artifact type: "report" (study design report).

---

### Stage 9: Git Commit

```bash
git add -A
git commit -m "task ${task_number}: complete epi research

Session: ${session_id}"
```

---

### Stage 10: Cleanup

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 11: Return Brief Summary

**Research Success**:
```
Epi research completed for task {N}:
- Study design and analysis plan documented
- Created report at specs/{NNN}_{SLUG}/reports/{MM}_epi-research.md
- Status updated to [RESEARCHED]
- Changes committed with session {session_id}
```

---

## Error Handling

### Task not found
```
Epi research skill error for task {N}:
- Task not found in state.json
- No status changes made
```

### Wrong task_type
```
Epi research skill error for task {N}:
- Task is not an epi task (task_type={task_type})
- No status changes made
```

### Metadata file missing
Keep status at preflight level for resume.

### Git commit failure
Non-blocking. Log failure but continue.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
