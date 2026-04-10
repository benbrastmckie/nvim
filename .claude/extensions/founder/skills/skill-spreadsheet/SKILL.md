---
name: skill-spreadsheet
description: Cost breakdown spreadsheet generation with forcing questions
allowed-tools: Task, Bash, Edit, Read, Write
---

# Spreadsheet Skill

Thin wrapper that routes cost breakdown spreadsheet requests to the `spreadsheet-agent`.

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
- User explicitly runs `/sheet` command with task number
- User runs `/research` on a founder task with `task_type: "sheet"`

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Create cost breakdown"
- "Build financial spreadsheet"
- "Generate cost analysis"
- "Cost modeling spreadsheet"

**Target mentions**:
- "cost breakdown"
- "budget spreadsheet"
- "expense analysis"
- "financial model"

### When NOT to trigger

Do not invoke for:
- Market sizing (use skill-market)
- Revenue projections (use skill-strategy)
- General business analysis (use skill-analyze)
- Project timelines (use skill-project)

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `mode` - Optional, one of: ESTIMATE, BUDGET, FORECAST, ACTUALS

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
pre_gathered_mode=$(echo "$forcing_data" | jq -r '.mode // null' 2>/dev/null)

# Validate mode if provided
if [ -n "$mode" ]; then
  case "$mode" in
    ESTIMATE|BUDGET|FORECAST|ACTUALS) ;;
    *) return error "Invalid mode: $mode. Must be ESTIMATE, BUDGET, FORECAST, or ACTUALS" ;;
  esac
fi
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
  "skill": "skill-spreadsheet",
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
    "task_type": "sheet"
  },
  "forcing_data": {
    "mode": "{pre_gathered_mode}",
    "scope_period": "{pre_gathered_period}",
    "scope_entity": "{pre_gathered_entity}",
    "gathered_at": "{timestamp}"
  },
  "mode": "ESTIMATE|BUDGET|FORECAST|ACTUALS or use forcing_data.mode",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "sheet", "skill-spreadsheet"]
  }
}
```

**Note**: If `forcing_data` is present from STAGE 0 of /sheet command, pass it to the agent.
The agent will use pre-gathered data and only ask follow-up questions for missing details.

---

### Stage 5: Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "spreadsheet-agent"
  - prompt: [Include task_context, forcing_data, mode, metadata_file_path, metadata]
  - description: "Cost breakdown spreadsheet generation"
```

The agent will:
- Use pre-gathered forcing_data if available (skip already-answered questions)
- Present mode selection only if not pre-selected
- Ask follow-up forcing questions for cost details
- Generate XLSX with native Excel formulas
- Export JSON metrics for Typst integration
- Create research report at specs/{NNN}_{SLUG}/reports/
- Write metadata file
- Return brief text summary

---

### Stage 6: Parse Subagent Return

```bash
padded_num=$(printf "%03d" "$task_number")
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifacts=$(jq -r '.artifacts' "$metadata_file")
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

Add artifacts to state.json with summaries.

**IMPORTANT**: Use two-step jq pattern to avoid escaping issues.

```bash
# For each artifact type (research, spreadsheet, metrics)
for artifact in $(echo "$artifacts" | jq -c '.[]'); do
    path=$(echo "$artifact" | jq -r '.path')
    type=$(echo "$artifact" | jq -r '.type')
    summary=$(echo "$artifact" | jq -r '.summary')

    # Step 1: Filter out existing artifacts of same type (use "| not" pattern)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "'$type'" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new artifact
    jq --arg path "$path" \
       --arg type "$type" \
       --arg summary "$summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
done
```

**Update TODO.md**: Add artifact links using count-aware format.

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
Cost breakdown research completed for task {N}:
- Mode: {mode}, {questions_asked} forcing questions completed
- Categories: {category_list}
- Line items: {count}
- Monthly total: ${total_monthly}
- Pre-gathered data used: {yes/no}
- Spreadsheet: specs/{NNN}_{SLUG}/cost-breakdown.xlsx
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
Cost breakdown research completed for task 234:
- Mode: BUDGET, 8 forcing questions completed
- Categories: Personnel, Infrastructure, Marketing, Operations
- Line items: 12
- Monthly total: $81,200
- Pre-gathered data used: yes (2 questions from STAGE 0)
- Spreadsheet: specs/234_cost_breakdown_saas/cost-breakdown.xlsx
- Research report: specs/234_cost_breakdown_saas/reports/01_cost-breakdown.md
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
