---
name: skill-founder-implement
description: Execute founder plans and generate strategy reports
allowed-tools: Task
---

# Founder Implement Skill

Routes founder-specific implementation requests to the `founder-implement-agent`, executing plans created by `skill-founder-plan` and generating detailed strategy reports.

## Context Pointers

Reference (do not load eagerly):
- Path: `.claude/context/core/formats/subagent-return.md`
- Purpose: Return validation
- Load at: Subagent execution only

Note: This skill is a thin wrapper. Context is loaded by the delegated agent, not this skill.

## Trigger Conditions

This skill activates when:

### Direct Invocation
- `/implement` command on a task with `language: founder`
- Extension routing lookup finds `routing.implement.founder`

### Language-Based Routing
- Task language is "founder"
- `/implement {N}` where task {N} has language="founder"

### When NOT to trigger

Do not invoke for:
- Tasks with other language types (general, meta, neovim, etc.)
- Quick mode operations (`--quick` flag)
- Tasks in [NOT STARTED] status (need plan first)
- Tasks already [COMPLETED]

---

## Execution

### 1. Input Validation

Validate inputs from delegation context:
- `task_number` - Required, integer
- `plan_path` - Required, path to implementation plan
- `resume_phase` - Optional, phase number to resume from
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

# Validate plan_path exists
if [ -z "$plan_path" ] || [ ! -f "$plan_path" ]; then
  return error "plan_path is required and must exist. Run /plan first."
fi
```

### 2. Preflight Status Update

Update task status to "implementing" in state.json:

```bash
jq --argjson num "$task_number" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '(.active_projects[] | select(.project_number == $num)) += {
     status: "implementing",
     last_updated: $ts
   }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

Update TODO.md status marker to [IMPLEMENTING].

### 3. Create Postflight Marker

Create marker file to signal postflight operations needed:

```bash
padded_num=$(printf "%03d" "$task_number")
project_name=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .project_name' \
  specs/state.json)
task_dir="specs/${padded_num}_${project_name}"
mkdir -p "$task_dir"
echo "$session_id" > "$task_dir/.postflight-pending"
```

### 4. Context Preparation

Prepare delegation context for agent:

```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "market_sizing_fintech_payments",
    "description": "Market sizing: fintech payments",
    "language": "founder"
  },
  "plan_path": "specs/234_market_sizing_fintech_payments/plans/01_market-sizing-plan.md",
  "resume_phase": 1,
  "output_dir": "strategy/",
  "metadata_file_path": "specs/234_market_sizing_fintech_payments/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "implement", "skill-founder-implement"]
  }
}
```

### 5. Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "founder-implement-agent"
  - prompt: [Include task_context, plan_path, resume_phase, output_dir, metadata]
  - description: "Execute founder plan and generate strategy report"
```

The agent will:
- Load plan and detect resume point
- Execute phases (TAM -> SAM -> SOM -> Report)
- Generate report artifact in `strategy/` directory
- Create summary in task directory
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

If agent succeeded (status == "implemented"):

```bash
# Update state.json to completed
jq --argjson num "$task_number" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   '(.active_projects[] | select(.project_number == $num)) += {
     status: "completed",
     last_updated: $ts
   }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Link artifacts in state.json (report and summary)
artifacts=$(echo "$metadata" | jq '.artifacts')
for i in $(seq 0 $(($(echo "$artifacts" | jq 'length') - 1))); do
  artifact_type=$(echo "$artifacts" | jq -r ".[$i].type")
  artifact_path=$(echo "$artifacts" | jq -r ".[$i].path")
  artifact_summary=$(echo "$artifacts" | jq -r ".[$i].summary")
  jq --argjson num "$task_number" \
     --arg type "$artifact_type" \
     --arg path "$artifact_path" \
     --arg summary "$artifact_summary" \
     '(.active_projects[] | select(.project_number == $num)).artifacts += [{
       type: $type,
       path: $path,
       summary: $summary
     }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
done
```

Update TODO.md status marker to [COMPLETED], add Completed date and Summary link.

If partial (status == "partial"):
- Keep status as "implementing"
- Note resume point in metadata

### 8. Git Commit

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: complete implementation

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### 9. Cleanup and Return

Remove postflight marker:

```bash
rm -f "$task_dir/.postflight-pending"
```

Return validated result to caller.

---

## Return Format

Expected successful return:
```json
{
  "status": "implemented",
  "summary": "Generated market sizing report for fintech payments. TAM: $50B, SAM: $8B, SOM Y1: $40M.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "strategy/market-sizing-fintech-payments.md",
      "summary": "Full market sizing report with TAM/SAM/SOM analysis"
    },
    {
      "type": "summary",
      "path": "specs/234_market_sizing_fintech_payments/summaries/01_market-sizing-summary.md",
      "summary": "Implementation summary with key results"
    }
  ],
  "metadata": {
    "session_id": "sess_...",
    "agent_type": "founder-implement-agent",
    "delegation_depth": 2,
    "phases_completed": 4,
    "phases_total": 4,
    "tam": "$50B",
    "sam": "$8B",
    "som_y1": "$40M"
  },
  "next_steps": "Review report and validate assumptions"
}
```

Expected partial return:
```json
{
  "status": "partial",
  "summary": "Completed phases 1-2 of 4. TAM and SAM calculated.",
  "artifacts": [],
  "partial_progress": {
    "phases_completed": 2,
    "phases_total": 4,
    "resume_phase": 3,
    "data_gathered": ["TAM: $50B", "SAM: $8B"]
  },
  "metadata": {...},
  "next_steps": "Run /implement to resume from phase 3 (SOM calculation)"
}
```

---

## Error Handling

### Session ID Missing
Return immediately with failed status.

### Plan Not Found
Return error with guidance to run /plan first.

### Task Not Found
Return error with guidance to check task number.

### Agent Errors
Pass through the agent's error return verbatim.

### Build/Calculation Errors
Return partial status with progress made.
