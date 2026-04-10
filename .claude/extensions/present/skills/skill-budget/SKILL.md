---
name: skill-budget
description: Grant budget spreadsheet generation with forcing questions. Invoke for budget tasks.
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
# Context (loaded by subagent):
#   - .claude/extensions/present/context/project/present/domain/grant-budget-frameworks.md
#   - .claude/extensions/present/context/project/present/patterns/budget-forcing-questions.md
# Tools (used by subagent):
#   - AskUserQuestion, Read, Write, Glob, Bash
---

# Budget Skill

Thin wrapper that routes grant budget spreadsheet requests to the `budget-agent`.

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

### Direct Invocation
- User explicitly runs `/budget` command with task number
- User runs `/research` on a task with language "present" and task_type "budget"

### Implicit Invocation (during task implementation)

When an implementing agent encounters any of these patterns:

**Plan step language patterns**:
- "Create grant budget spreadsheet"
- "Build budget with F&A calculation"
- "Generate NIH/NSF budget"
- "Grant budget with salary cap"

**Target mentions**:
- "grant budget"
- "NIH budget"
- "NSF budget"
- "F&A calculation"
- "indirect cost budget"

### When NOT to trigger

Do not invoke for:
- Budget narrative/justification text (use skill-grant with --budget)
- General cost breakdowns (use skill-spreadsheet from founder)
- Market sizing or revenue projections

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `mode` - Optional, one of: MODULAR, DETAILED, NSF, FOUNDATION, SBIR

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

# Extract pre-gathered forcing_data (if present)
forcing_data=$(echo "$task_data" | jq -r '.forcing_data // null')
pre_gathered_mode=$(echo "$forcing_data" | jq -r '.mode // null' 2>/dev/null)

# Validate mode if provided
if [ -n "$mode" ]; then
  case "$mode" in
    MODULAR|DETAILED|NSF|FOUNDATION|SBIR) ;;
    *) return error "Invalid mode: $mode. Must be MODULAR, DETAILED, NSF, FOUNDATION, or SBIR" ;;
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
  "skill": "skill-budget",
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
    "language": "present",
    "task_type": "budget"
  },
  "forcing_data": {
    "mode": "{pre_gathered_mode}",
    "project_period": "{pre_gathered_period}",
    "direct_cost_cap": "{pre_gathered_cap}",
    "gathered_at": "{timestamp}"
  },
  "mode": "MODULAR|DETAILED|NSF|FOUNDATION|SBIR or use forcing_data.mode",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_{timestamp}_{random}",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "budget", "skill-budget"]
  }
}
```

**Note**: If `forcing_data` is present from STAGE 0 of /budget command, pass it to the agent.
The agent will use pre-gathered data and only ask follow-up questions for missing details.

---

### Stage 5: Invoke Agent

**CRITICAL**: You MUST use the **Task** tool to spawn the agent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "budget-agent"
  - prompt: [Include task_context, forcing_data, mode, metadata_file_path, metadata]
  - description: "Grant budget spreadsheet generation"
```

The agent will:
- Use pre-gathered forcing_data if available (skip already-answered questions)
- Present mode selection only if not pre-selected
- Ask follow-up forcing questions for budget details
- Generate multi-year XLSX with native Excel formulas
- Export JSON metrics
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
Grant budget research completed for task {N}:
- Mode: {mode}, {questions_asked} forcing questions completed
- Funder: {funder_type}, {num_years}-year project
- Personnel: {count} ({roles})
- Year 1 direct costs: ${year1_direct}
- Total project cost: ${total}
- Pre-gathered data used: {yes/no}
- Spreadsheet: specs/{NNN}_{SLUG}/grant-budget.xlsx
- Research report: specs/{NNN}_{SLUG}/reports/{NN}_{short-slug}.md
- Status updated to [RESEARCHED]
- Changes committed
- Next: Run /plan {N} to create implementation plan
```

---

## Return Format

Brief text summary (NOT JSON).

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
