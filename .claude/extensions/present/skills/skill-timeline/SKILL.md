---
name: skill-timeline
description: Research timeline planning for medical research projects. Invoke for timeline tasks.
allowed-tools: Task, Bash, Edit, Read, Write
# Context (loaded by subagent):
#   - .claude/extensions/present/context/project/present/domain/research-timelines.md
#   - .claude/extensions/present/context/project/present/patterns/timeline-patterns.md
#   - .claude/extensions/present/context/project/present/templates/timeline-template.md
# Tools (used by subagent):
#   - AskUserQuestion, Read, Write, Edit, Glob
---

# Timeline Skill

Thin wrapper that delegates timeline research to `timeline-agent` subagent.

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
- Task type is "present" and task_type is "timeline"
- Timeline workflow requested via /timeline command or /research routing
- Present extension is available

---

## Workflow Type Routing

This skill routes to timeline-agent with one of two workflow types:

| Workflow Type | Preflight Status | Success Status | TODO.md Markers |
|---------------|-----------------|----------------|-----------------|
| timeline_research | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| timeline_plan | planning | planned | [PLANNING] -> [PLANNED] |

---

## Input Parameters

### Required Parameters
- `task_number` - Task number (must exist in state.json with language="present" and task_type="timeline")
- `workflow_type` - One of: timeline_research, timeline_plan
- `session_id` - Session ID from orchestrator

### Optional Parameters
- `forcing_data` - Pre-gathered forcing question responses from /timeline command

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `workflow_type` - Must be one of: timeline_research, timeline_plan

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
language=$(echo "$task_data" | jq -r '.language // "present"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

# Extract pre-gathered forcing_data (if present from Stage 0)
forcing_data=$(echo "$task_data" | jq -r '.forcing_data // null')

# Validate language is "present"
if [ "$task_type" != "present" ]; then
  return error "Task $task_number has language '$task_type', expected 'present'"
fi
```

---

### Stage 2: Preflight Status Update

Update task status based on workflow type BEFORE invoking subagent.

```bash
case "$workflow_type" in
  timeline_research)
    preflight_status="researching"
    preflight_marker="[RESEARCHING]"
    ;;
  timeline_plan)
    preflight_status="planning"
    preflight_marker="[PLANNING]"
    ;;
esac

# Update state.json
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "$preflight_status" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md**: Use Edit tool to change status marker to the in-progress state.

---

### Stage 3: Create Postflight Marker

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-timeline",
  "task_number": ${task_number},
  "operation": "${workflow_type}",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 3a: Artifact Number Calculation

Calculate the artifact sequence number following the same pattern as skill-planner:

```bash
padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"

# Get current artifact number from state.json
artifact_num=$(jq -r --argjson num "$task_number" \
  '(.active_projects[] | select(.project_number == $num)).next_artifact_number // 1' \
  specs/state.json)

# For research: use current number (advances it)
# For plan: use current round (artifact_num - 1)
case "$workflow_type" in
  timeline_research)
    current_mm=$(printf "%02d" "$artifact_num")
    # Increment next_artifact_number
    jq --argjson num "$task_number" \
      '(.active_projects[] | select(.project_number == $num)).next_artifact_number = ('$artifact_num' + 1)' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
    ;;
  timeline_plan)
    current_mm=$(printf "%02d" "$((artifact_num - 1))")
    if [ "$current_mm" = "00" ]; then current_mm="01"; fi
    ;;
esac
```

---

### Stage 4: Prepare Delegation Context

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "timeline", "skill-timeline"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "present",
    "task_type": "timeline"
  },
  "workflow_type": "timeline_research",
  "forcing_data": { "...pre-gathered data if available..." },
  "artifact_number": "{MM}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 5: Invoke Subagent

**CRITICAL**: Use the **Task** tool to spawn the subagent.

```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "timeline-agent"
  - prompt: [Include task_context, delegation_context, workflow_type, forcing_data, artifact_number, metadata_file_path]
  - description: "Execute {workflow_type} workflow for task {N}"
```

**DO NOT** use `Skill(timeline-agent)` - this will FAIL.

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

| Workflow Type | Meta Status | Final state.json | Final TODO.md |
|---------------|-------------|-----------------|---------------|
| timeline_research | researched | researched | [RESEARCHED] |
| timeline_research | partial | researching | [RESEARCHING] |
| timeline_plan | planned | planned | [PLANNED] |
| timeline_plan | partial | planning | [PLANNING] |
| any | failed | (keep preflight) | (keep preflight marker) |

```bash
case "$workflow_type" in
  timeline_research)
    if [ "$meta_status" = "researched" ]; then
      postflight_status="researched"
      postflight_marker="[RESEARCHED]"
    fi
    ;;
  timeline_plan)
    if [ "$meta_status" = "planned" ]; then
      postflight_status="planned"
      postflight_marker="[PLANNED]"
    fi
    ;;
esac

if [ -n "$postflight_status" ]; then
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg status "$postflight_status" \
    '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
      status: $status,
      last_updated: $ts
    }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Use Edit tool to change status marker to the final success state.

---

### Stage 8: Link Artifacts

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing artifacts of same type
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "report" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Add artifact link using count-aware format.

---

### Stage 9: Git Commit

```bash
case "$workflow_type" in
  timeline_research)
    commit_action="complete timeline research"
    ;;
  timeline_plan)
    commit_action="create timeline plan"
    ;;
esac

git add -A
git commit -m "task ${task_number}: ${commit_action}

Session: ${session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

**On commit failure**: Non-blocking. Log failure but continue.

---

### Stage 10: Cleanup

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 11: Return Brief Summary

**Timeline Research Success**:
```
Timeline research completed for task {N}:
- Project: {mechanism}, {years}-year, {aims} specific aims
- Critical path: {E} months (95% CI: {low}-{high})
- Regulatory milestones: {count}
- Created report at specs/{NNN}_{SLUG}/reports/{MM}_timeline-research.md
- Status updated to [RESEARCHED]
- Changes committed with session {session_id}
```

**Partial Return**:
```
Timeline research partially completed for task {N}:
- {completed_actions}
- {failed_action} failed: {reason}
- Partial report at specs/{NNN}_{SLUG}/reports/{MM}_timeline-research.md
- Status remains [{preflight_marker}] - run /timeline {N} to continue
```

---

## Error Handling

### Task Not Found
```
Timeline skill error for task {N}:
- Task not found in state.json
- Verify task exists with /task --sync
- No status changes made
```

### Wrong Language
```
Timeline skill error for task {N}:
- Task has language '{language}', expected 'present'
- Use /timeline to create timeline tasks
- No status changes made
```

### Metadata File Missing
Keep status at preflight level, preserve postflight marker, report error with resume guidance.

### Git Commit Failure
Non-blocking. Log failure but continue with success response.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
