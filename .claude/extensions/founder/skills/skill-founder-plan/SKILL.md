---
name: skill-founder-plan
description: Create founder analysis plans with interactive forcing questions
allowed-tools: Task, Bash, Edit, Read, Write
---

# Founder Plan Skill

Routes founder-specific planning requests to the `founder-plan-agent`, enabling interactive forcing questions workflow for market sizing, competitive analysis, and GTM strategy planning.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- `/plan` command on a task with `language: founder`
- Extension routing lookup finds `routing.plan.founder`

### Task-Type-Based Routing
- Task type is "founder"
- `/plan {N}` where task {N} has language="founder"

### When NOT to trigger

Do not invoke for:
- Tasks with other language types (general, meta, neovim, etc.)
- Quick mode operations (`--quick` flag)
- Tasks already in [PLANNED] or [COMPLETED] status

---

## Execution

### 1. Input Validation

Validate inputs from delegation context:
- `task_number` - Required, integer
- `research_path` - Optional, path to existing research reports
- `session_id` - Required, string

```bash
# Validate task_number is present
if [ -z "$task_number" ]; then
  return error "task_number is required"
fi

# Validate session_id is present
if [ -z "$session_id" ]; then
  return error "session_id is required"
fi
```

### 2. Preflight Status Update

Update task status to "planning" in state.json:

```bash
jq --argjson num "$task_number" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '(.active_projects[] | select(.project_number == $num)) += {
     status: "planning",
     last_updated: $ts
   }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

Update TODO.md status marker to [PLANNING].

### 3. Create Postflight Marker

Create marker file to signal postflight operations needed:

```bash
padded_num=$(printf "%03d" "$task_number")
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
task_dir="specs/${padded_num}_${project_name}"
mkdir -p "$task_dir"

cat > "$task_dir/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-founder-plan",
  "task_number": ${task_number},
  "operation": "plan",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

### 4. Context Preparation

Extract task_type from state.json (null-safe):

```bash
# Extract task_type from state.json (null-safe)
task_type=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .task_type // null' \
  specs/state.json)
```

Prepare delegation context for agent:

```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "market_sizing_fintech_payments",
    "description": "Market sizing: fintech payments",
    "task_type": "founder",
    "task_type": "market"
  },
  "research_path": "specs/234_market_sizing_fintech_payments/reports/01_context.md",
  "metadata_file_path": "specs/234_market_sizing_fintech_payments/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "plan", "skill-founder-plan"]
  }
}
```

### 5. Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "founder-plan-agent"
  - prompt: [Include task_context, research_path, metadata_file_path, metadata]
  - description: "Create founder analysis plan with forcing questions"
```

The agent will:
- Load existing context (research reports if any)
- Conduct interactive forcing questions to gather data
- Generate plan artifact with gathered context stored
- Write metadata file for postflight consumption
- Return brief text summary

### 6. Read Metadata File

After agent returns, read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
metadata=$(cat "$metadata_file")
status=$(echo "$metadata" | jq -r '.status')
```

### 7. Postflight Status Update

If agent succeeded (status == "planned"):

```bash
# Update state.json
jq --argjson num "$task_number" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '(.active_projects[] | select(.project_number == $num)) += {
     status: "planned",
     last_updated: $ts
   }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Link artifact in state.json
plan_path=$(echo "$metadata" | jq -r '.artifacts[0].path')
plan_summary=$(echo "$metadata" | jq -r '.artifacts[0].summary')
jq --argjson num "$task_number" \
   --arg path "$plan_path" \
   --arg summary "$plan_summary" \
   '(.active_projects[] | select(.project_number == $num)).artifacts += [{
     type: "plan",
     path: $path,
     summary: $summary
   }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

Update TODO.md status marker to [PLANNED] and add Plan link.

### 8. Git Commit

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: create implementation plan

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### 9. Cleanup and Return

Remove postflight markers and metadata:

```bash
rm -f "$task_dir/.postflight-pending"
rm -f "$task_dir/.postflight-loop-guard"
rm -f "$task_dir/.return-meta.json"
```

Return brief text summary to caller.

---

## Return Format

Brief text summary (NOT JSON).

Expected successful return:
```
Founder plan created for task {N}:
- {questions_asked} forcing questions completed, {phase_count} phases planned
- Context gathered: {brief summary of key data points}
- Plan: specs/{NNN}_{SLUG}/plans/01_{short-slug}.md
- Status updated to [PLANNED]
- Changes committed with session {session_id}
- Next: Run /implement {N} to execute the plan and generate report
```

---

## Error Handling

### Session ID Missing
Return immediately with failed status.

### Task Not Found
Return error with guidance to check task number.

### Agent Errors
Pass through the agent's error return verbatim.

### User Abandonment
Return partial status with progress made, keep status as "planning".
