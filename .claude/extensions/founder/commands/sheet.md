---
description: Cost breakdown spreadsheet generation with forcing questions and task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick [mode]
---

# /sheet Command

Cost breakdown spreadsheet command using forcing questions with task system integration.

## Overview

This command initiates cost breakdown spreadsheet generation through structured forcing questions. It asks essential forcing questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow.

## Syntax

- `/sheet "Q1 product launch costs"` - Ask forcing questions, create task with gathered data
- `/sheet 234` - Resume research on existing task
- `/sheet /path/to/context.md` - Use file as context, ask questions, create task
- `/sheet --quick BUDGET` - Legacy standalone mode (no task creation)

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, run research, stop at [RESEARCHED] |
| File path | Read file for context, ask questions, create task |
| `--quick [mode]` | Legacy standalone mode (skip task creation) |

## Modes

| Mode | Precision | Focus |
|------|-----------|-------|
| **ESTIMATE** | +/- 50% | Rough order of magnitude for early planning |
| **BUDGET** | +/- 15% | Detailed operational budget with line items |
| **FORECAST** | +/- 25% | Forward-looking projection with scenarios |
| **ACTUALS** | Exact | Historical data for variance analysis |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: `--quick` flag or task number input.

### Step 0.1: Mode Selection

Use AskUserQuestion to present mode options:

```
What type of cost analysis do you need?

- ESTIMATE: Rough order of magnitude (+/- 50%)
- BUDGET: Detailed operational budget (+/- 15%)
- FORECAST: Forward-looking projection with scenarios
- ACTUALS: Historical data for variance analysis
```

Store response as `selected_mode`.

### Step 0.2: Essential Forcing Questions

Ask abbreviated forcing questions to gather essential scope. One question at a time.

**Question 1: Time Period**
```
What time period are we budgeting for?
Examples: Q2 2026, FY2027, Next 18 months
```
Store as `forcing_data.scope_period`.

**Question 2: Entity Scope**
```
What entity or scope are we covering?
Examples: US operations, Engineering team, Product launch
Currency: What currency for all figures?
```
Store as `forcing_data.scope_entity`.

### Step 0.3: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mode": "{selected_mode}",
  "scope_period": "{response_1}",
  "scope_entity": "{response_2}",
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Sheet] Cost Breakdown Spreadsheet Generator
```

### Step 1: Generate Session ID

```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

### Step 2: Detect Input Type

```bash
# Check for --quick flag (legacy mode)
if echo "$ARGUMENTS" | grep -qE '^--quick'; then
  input_type="quick"
  # Extract mode after --quick
  mode=$(echo "$ARGUMENTS" | sed 's/^--quick *//' | tr '[:lower:]' '[:upper:]')

# Check for task number
elif echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then
  input_type="task_number"
  task_number="$ARGUMENTS"

# Check for file path
elif echo "$ARGUMENTS" | grep -qE '^\.|^/|^~|\.md$|\.txt$|\.csv$'; then
  input_type="file_path"
  file_path="$ARGUMENTS"

# Default: treat as description for new task
else
  input_type="description"
  description="$ARGUMENTS"
fi
```

### Step 3: Handle Input Type

**If `--quick` (legacy mode)**:
Skip STAGE 0 and go directly to STAGE 2A (legacy delegation).

**If file path**:
```bash
# Expand path
file_path=$(eval echo "$file_path")

# Verify file exists
if [ ! -f "$file_path" ]; then
  echo "Error: File not found: $file_path"
  exit 1
fi

# Read file as context
context_content=$(cat "$file_path")

# Create description from filename
filename=$(basename "$file_path" | sed 's/\.[^.]*$//')
description="Cost breakdown: $filename"
```
Then proceed to STAGE 0 for forcing questions.

**If task number**:
```bash
# Load existing task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

if [ -z "$task_data" ]; then
  echo "Error: Task $task_number not found"
  exit 1
fi

# Validate language is founder
task_lang=$(echo "$task_data" | jq -r '.language')
if [ "$task_lang" != "founder" ]; then
  echo "Error: Task $task_number is not a founder task (language: $task_lang)"
  exit 1
fi

# Validate task_type is sheet
task_type=$(echo "$task_data" | jq -r '.task_type // ""')
if [ -n "$task_type" ] && [ "$task_type" != "sheet" ]; then
  echo "Warning: Task type is '$task_type', not 'sheet'. Proceeding anyway."
fi
```
Skip STAGE 0, go directly to STAGE 2B.

**If description (new task)**:
Proceed to STAGE 0 for forcing questions, then Step 4.

### Step 4: Create Task (if needed)

Skip if task_number already exists.

```bash
# Get next task number
next_num=$(jq -r '.next_project_number' specs/state.json)

# Create slug from description
slug="cost_breakdown_$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

# Create task in state.json with task_type and forcing_data
jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "Cost breakdown: $description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "sheet" \
   --argjson forcing_data "$forcing_data_json" \
   '. + {next_project_number: ($num + 1)} |
    .active_projects += [{
      project_number: $num,
      project_name: $name,
      status: "not_started",
      task_type: "founder",
      task_type: $task_type,
      description: $desc,
      created: $ts,
      forcing_data: $forcing_data,
      artifacts: []
    }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Update TODO.md
task_number=$next_num
```

### Step 5: Update TODO.md

Add task entry to TODO.md (if new task):

```markdown
### {task_number}. Cost breakdown: {description}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: founder
- **Type**: sheet
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Mode: {selected_mode}
- Period: {forcing_data.scope_period}
- Scope: {forcing_data.scope_entity}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create cost breakdown task

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Display Task Created Summary

For new tasks (description or file path input), display summary and STOP:

```
Cost breakdown task created: Task #{N}

Forcing Data Gathered:
- Mode: {selected_mode}
- Period: {forcing_data.scope_period}
- Scope: {forcing_data.scope_entity}

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to complete cost research with gathered data
- Run /plan {N} to create implementation plan
- Run /implement {N} to generate final cost analysis report
```

**STOP HERE for new tasks.** Do not auto-invoke research.

---

## STAGE 2: DELEGATE

**Only reached when input_type is "task_number" or "--quick".**

### STAGE 2A: Legacy Mode (--quick)

**If input_type == "quick"**:

Invoke skill-spreadsheet directly (original behavior):

```
skill: "skill-spreadsheet"
args: "mode={mode} session_id={session_id}"
```

Skip to CHECKPOINT 2 (Legacy).

### STAGE 2B: Task Workflow Mode (existing task)

**Run research via skill-spreadsheet**:

```
skill: "skill-spreadsheet"
args: "task_number={task_number} session_id={session_id}"
```

The skill workflow:
1. Updates status to [RESEARCHING] (preflight)
2. Invokes spreadsheet-agent, passing forcing_data from task metadata
3. Agent uses pre-gathered data, asks follow-up questions for cost details
4. Agent generates XLSX spreadsheet with formulas
5. Agent exports JSON metrics for Typst
6. Agent creates research report at `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md`
7. Updates status to [RESEARCHED] (postflight)
8. Links artifacts and commits

---

## CHECKPOINT 2: GATE OUT

### For Task Workflow Mode (existing task)

1. **Verify Research Completed**
   ```bash
   status=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .status' \
     specs/state.json)

   if [ "$status" != "researched" ]; then
     echo "Research incomplete. Status: [$status]"
     echo "Resume: /sheet $task_number"
     exit 1
   fi
   ```

2. **Get Artifacts**
   ```bash
   artifacts=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .artifacts' \
     specs/state.json)

   research_path=$(echo "$artifacts" | jq -r '.[] | select(.type == "research") | .path')
   spreadsheet_path=$(echo "$artifacts" | jq -r '.[] | select(.type == "spreadsheet") | .path')
   metrics_path=$(echo "$artifacts" | jq -r '.[] | select(.type == "metrics") | .path')
   ```

3. **Display Result**
   ```
   Cost breakdown research complete for Task #{N}

   Artifacts Generated:
   - Spreadsheet: {spreadsheet_path}
   - JSON Metrics: {metrics_path}
   - Research Report: {research_path}

   Cost Summary:
   - Categories: {category_count}
   - Line items: {line_item_count}
   - Monthly total: ${total_monthly}
   - Annual total: ${total_annual}

   Status: [RESEARCHED]

   Next Steps:
   - Review spreadsheet for accuracy
   - Run /plan {N} to create implementation plan
   - Run /implement {N} to generate final cost analysis report
   ```

### For Legacy Mode (--quick)

```
Cost breakdown spreadsheet generated.

Mode: {MODE}
Artifacts:
- Spreadsheet: founder/cost-breakdown-{datetime}.xlsx
- JSON Metrics: founder/cost-metrics-{datetime}.json

Summary:
{summary}

Key Numbers:
- Monthly: ${total_monthly}
- Annual: ${total_annual}
- Largest Category: {category_name}

Next: Open spreadsheet in Excel to review formulas
```

---

## Error Handling

### Task Not Found (task number mode)

```
Error: Task {N} not found in state.json
Run /task "description" to create a new task
```

### File Not Found (file path mode)

```
Error: File not found: {path}
Verify the file path and try again
```

### Research Incomplete

```
Research incomplete for Task #{N}
Status: [{current_status}]
Resume: /sheet {N}
```

### User Abandons Forcing Questions (STAGE 0)

If user abandons during STAGE 0 forcing questions:
```
Cost breakdown task creation cancelled.

No task was created. Re-run /sheet with your description to start again.
```

### User Abandons Research (STAGE 2)

Return partial status, task remains in [RESEARCHING]:
```
Cost breakdown research partially completed.

Completed: {questions_completed}/{questions_total} forcing questions
Task: #{N} - Status: [RESEARCHING]

Resume: /sheet {N}
```

### openpyxl Not Available

```
Error: openpyxl Python package not installed.

Install with: pip install openpyxl

Then re-run: /sheet {N}
```

---

## Output Artifacts

### Task Workflow Mode

| Artifact | Location |
|----------|----------|
| XLSX Spreadsheet | `specs/{NNN}_{SLUG}/cost-breakdown.xlsx` |
| JSON Metrics | `specs/{NNN}_{SLUG}/cost-metrics.json` |
| Research report | `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` |

**Note**: Final cost analysis report (`strategy/cost-analysis-*.typ`, with `.md` fallback) is generated by `/implement`, not `/sheet`. Typst compiles to PDF.

### Legacy Mode (--quick)

| Artifact | Location |
|----------|----------|
| XLSX Spreadsheet | `founder/cost-breakdown-{datetime}.xlsx` |
| JSON Metrics | `founder/cost-metrics-{datetime}.json` |

---

## Workflow Summary

The standard workflow (with pre-task forcing questions):

```
/sheet "description"    -> Asks forcing questions, creates task with data, stops at [NOT STARTED]
/research {N}           -> Uses forcing_data, completes research, generates XLSX, stops at [RESEARCHED]
/plan {N}               -> Reads research report, creates implementation plan
/implement {N}          -> Executes plan, generates strategy/cost-analysis-*.typ
```

Alternative: Resume existing task:
```
/sheet {N}              -> Runs research on existing task, stops at [RESEARCHED]
```

---

## Examples

```bash
# Create new task with description - asks forcing questions first
/sheet "Q1 product launch costs"

# Resume research on existing task (uses stored forcing_data)
/sheet 234

# Use file as context - asks forcing questions, creates task
/sheet ~/startup/budget-notes.md

# Legacy standalone mode (generates spreadsheet immediately, no task)
/sheet --quick BUDGET
```
