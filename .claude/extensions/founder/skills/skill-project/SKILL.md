---
name: skill-project
description: Project research with scope analysis and timeline estimation
allowed-tools: Task, Bash, Edit, Read, Write
---

# Project Skill

Thin wrapper that routes project research requests to the `project-agent`.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- User explicitly runs `/project` command with task number
- User runs `/research` on a founder task with `task_type: "project"`

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Create project timeline"
- "Build project schedule"
- "Estimate project duration"
- "Track project progress"

**Target mentions**:
- "WBS", "work breakdown structure"
- "PERT", "three-point estimates"
- "Gantt chart", "critical path"
- "project timeline", "resource allocation"

### When NOT to trigger

Do not invoke for:
- Market sizing analysis (use skill-market)
- Competitive analysis (use skill-analyze)
- Business strategy (use skill-strategy)
- General research without project planning focus (use skill-researcher)

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json

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
language=$(echo "$task_data" | jq -r '.language // "founder"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

# Extract pre-gathered forcing_data (if present)
forcing_data=$(echo "$task_data" | jq -r '.forcing_data // null')
```

---

### Stage 2: Preflight Status Update

Update task status to "researching" BEFORE invoking subagent.

**Update state.json**:
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

**Update TODO.md**: Use Edit tool to change status marker to `[RESEARCHING]`.

---

### Stage 3: Create Postflight Marker

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-project",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

---

### Stage 4: Prepare Delegation Context

Include pre-gathered forcing_data when available:

```json
{
  "task_context": {
    "task_number": N,
    "project_name": "{project_name}",
    "description": "{description}",
    "task_type": "founder",
    "task_type": "project"
  },
  "forcing_data": {
    "project_name": "{pre_gathered_name}",
    "target_date": "{pre_gathered_date}",
    "stakeholders": "{pre_gathered_stakeholders}",
    "gathered_at": "{timestamp}"
  },
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "project", "skill-project"]
  }
}
```

**Note**: If `forcing_data` is present from pre-task gathering, pass it to the agent.
The agent will use pre-gathered data and only ask follow-up questions for missing details.

---

### Stage 5: Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "project-agent"
  - prompt: [Include task_context, forcing_data, metadata_file_path, metadata]
  - description: "Project research with scope analysis and timeline estimation"
```

The agent will:
- Use pre-gathered forcing_data if available (skip already-answered questions)
- Ask forcing questions for project scope, phases, tasks, and estimates
- Create research report at specs/{NNN}_{SLUG}/reports/
- Write metadata file
- Return brief text summary

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
padded_num=$(printf "%03d" "$task_number")
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
else
    status="failed"
fi
```

---

### Stage 7: Update Task Status (Postflight)

If status is "researched", update state.json and TODO.md.

**Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researched" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md**: Use Edit tool to change status marker to `[RESEARCHED]`.

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary.

**IMPORTANT**: Use two-step jq pattern to avoid escaping issues.

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing research artifacts (use "| not" pattern)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "research" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new research artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Add research artifact link using count-aware format.

**Strip specs/ prefix for TODO.md** (TODO.md is inside specs/): `todo_link_path="${artifact_path#specs/}"`

Use count-aware artifact linking format per `.claude/rules/state-management.md` "Artifact Linking Format".

---

### Stage 9: Git Commit

```bash
git add -A
git commit -m "task ${task_number}: complete research

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
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

```
Project research completed for task {N}:
- {questions_asked} forcing questions completed
- Project: {project_name}
- Research report: specs/{NNN}_{SLUG}/reports/01_{short-slug}.md
- Status updated to [RESEARCHED]
- Changes committed
- Next: Run /plan {N} to create implementation plan
```

---

## Return Format

Brief text summary (NOT JSON).

Expected successful return:
```
Project research completed for task 234:
- 6 forcing questions completed
- Project: mobile_app_launch
- Research report: specs/234_mobile_app_launch/reports/01_project-research.md
- Status updated to [RESEARCHED]
- Changes committed with session sess_1736700000_abc123
- Next: Run /plan 234 to create implementation plan
```

---

## Error Handling

### Input Validation Errors
Return immediately if task not found.

### Metadata File Missing
Keep status as "researching" for resume.

### User Abandonment
Return partial status with progress made.

### Git Commit Failure
Non-blocking: Log failure but continue.

---
