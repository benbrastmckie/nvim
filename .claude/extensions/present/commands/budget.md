---
description: Grant budget spreadsheet generation with forcing questions and task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick [mode]
model: opus
---

# /budget Command

Grant budget spreadsheet command using forcing questions with task system integration. Generates multi-year XLSX spreadsheets with native Excel formulas for NIH, NSF, Foundation, and SBIR grant budgets.

## Overview

This command initiates grant budget spreadsheet generation through structured forcing questions. It asks essential forcing questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow.

## Syntax

- `/budget "NIH R01 budget for AI interpretability project"` - Ask forcing questions, create task with gathered data
- `/budget 234` - Resume research on existing task
- `/budget /path/to/context.md` - Use file as context, ask questions, create task
- `/budget --quick MODULAR` - Legacy standalone mode (no task creation)

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, run research, stop at [RESEARCHED] |
| File path | Read file for context, ask questions, create task |
| `--quick [mode]` | Legacy standalone mode (skip task creation) |

## Modes

| Mode | Format | Focus |
|------|--------|-------|
| **MODULAR** | NIH Modular | Under $250K/year, $25K modules |
| **DETAILED** | NIH Detailed | $250K+/year, full categorical breakdown |
| **NSF** | NSF Standard | NSF categories A through J |
| **FOUNDATION** | Foundation | Simplified categories, limited/no overhead |
| **SBIR** | SBIR | Phase-specific, includes fee/profit |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: `--quick` flag or task number input.

### Step 0.1: Funder Type Selection

Use AskUserQuestion to present mode options:

```
What type of grant budget are you preparing?

A) NIH MODULAR - Under $250K/year direct costs, requested in $25K modules
B) NIH DETAILED - $250K+/year, full categorical breakdown
C) NSF - Standard NSF budget format
D) FOUNDATION - Simplified format for private foundations
E) SBIR - Small Business Innovation Research

Which format?
```

Store response as `selected_mode`.

### Step 0.2: Project Period

```
What is the project period?

- Number of years (e.g., 3, 5)
- Start date (e.g., July 2026)
- Mechanism if known (e.g., R01, R21, NSF CAREER)
```

Store as `forcing_data.project_period`.

### Step 0.3: Direct Cost Cap

```
What is your target annual direct cost amount?

This determines budget scale and (for NIH) confirms modular vs detailed.
- NIH Modular: up to $250,000/year
- NIH Detailed: $250,000+/year
- NSF: varies by program

Enter approximate annual direct costs:
```

Store as `forcing_data.direct_cost_cap`.

### Step 0.4: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mode": "{selected_mode}",
  "project_period": "{response_2}",
  "direct_cost_cap": "{response_3}",
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Budget] Grant Budget Spreadsheet Generator
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
file_path=$(eval echo "$file_path")

if [ ! -f "$file_path" ]; then
  echo "Error: File not found: $file_path"
  exit 1
fi

context_content=$(cat "$file_path")
filename=$(basename "$file_path" | sed 's/\.[^.]*$//')
description="Grant budget: $filename"
```
Then proceed to STAGE 0 for forcing questions.

**If task number**:
```bash
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

if [ -z "$task_data" ]; then
  echo "Error: Task $task_number not found"
  exit 1
fi

task_lang=$(echo "$task_data" | jq -r '.language')
if [ "$task_lang" = "present" ]; then
  : # OK
else
  echo "Error: Task $task_number has language '$task_lang', expected 'present'"
  exit 1
fi
```
Skip STAGE 0, go directly to STAGE 2B.

**If description (new task)**:
Proceed to STAGE 0 for forcing questions, then Step 4.

### Step 4: Create Task (if needed)

Skip if task_number already exists.

```bash
next_num=$(jq -r '.next_project_number' specs/state.json)

slug="grant_budget_$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "Grant budget: $description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "budget" \
   --argjson forcing_data "$forcing_data_json" \
  '. + {next_project_number: ($num + 1)} |
   .active_projects += [{
     project_number: $num,
     project_name: $name,
     status: "not_started",
     task_type: "present",
     task_type: $task_type,
     description: $desc,
     created: $ts,
     forcing_data: $forcing_data,
     artifacts: []
   }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

task_number=$next_num
```

### Step 5: Update TODO.md

Add task entry to TODO.md (if new task):

```markdown
### {task_number}. Grant budget: {description}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: present
- **Type**: budget
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Mode: {selected_mode}
- Period: {forcing_data.project_period}
- Direct Cost Cap: {forcing_data.direct_cost_cap}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create grant budget task

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Display Task Created Summary

For new tasks (description or file path input), display summary and STOP:

```
Grant budget task created: Task #{N}

Forcing Data Gathered:
- Mode: {selected_mode}
- Period: {forcing_data.project_period}
- Direct Cost Cap: {forcing_data.direct_cost_cap}

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to complete budget research with forcing questions
- Run /plan {N} to create implementation plan
- Run /implement {N} to generate final budget deliverables
```

**STOP HERE for new tasks.** Do not auto-invoke research.

---

## STAGE 2: DELEGATE

**Only reached when input_type is "task_number" or "--quick".**

### STAGE 2A: Legacy Mode (--quick)

**If input_type == "quick"**:

Invoke skill-budget directly (original behavior):

```
skill: "skill-budget"
args: "mode={mode} session_id={session_id}"
```

Skip to CHECKPOINT 2 (Legacy).

### STAGE 2B: Task Workflow Mode (existing task)

**Run research via skill-budget**:

```
skill: "skill-budget"
args: "task_number={task_number} session_id={session_id}"
```

The skill workflow:
1. Updates status to [RESEARCHING] (preflight)
2. Invokes budget-agent, passing forcing_data from task metadata
3. Agent uses pre-gathered data, asks follow-up questions for budget details
4. Agent generates multi-year XLSX with formulas (salary cap, F&A, escalation)
5. Agent exports JSON metrics
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

   if [ "$status" = "researched" ] || [ "$status" = "completed" ]; then
     : # OK
   else
     echo "Research incomplete. Status: [$status]"
     echo "Resume: /budget $task_number"
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
   Grant budget research complete for Task #{N}

   Artifacts Generated:
   - Spreadsheet: {spreadsheet_path}
   - JSON Metrics: {metrics_path}
   - Research Report: {research_path}

   Budget Summary:
   - Mode: {mode}
   - Years: {num_years}
   - Personnel: {personnel_count}
   - Year 1 Direct: ${year1_direct}
   - Total Project Cost: ${total}

   Status: [RESEARCHED]

   Next Steps:
   - Review spreadsheet for accuracy
   - Run /plan {N} to create implementation plan
   - Run /implement {N} to generate final deliverables
   ```

### For Legacy Mode (--quick)

```
Grant budget spreadsheet generated.

Mode: {MODE}
Artifacts:
- Spreadsheet: present/grant-budget-{datetime}.xlsx
- JSON Metrics: present/budget-metrics-{datetime}.json

Summary:
{summary}

Key Numbers:
- Year 1 Direct: ${year1_direct}
- Total Project Cost: ${total}
- F&A Rate: {rate}%

Next: Open spreadsheet in Excel to review formulas
```

---

## Error Handling

### Task Not Found (task number mode)

```
Error: Task {N} not found in state.json
Run /budget "description" to create a new task
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
Resume: /budget {N}
```

### User Abandons Forcing Questions (STAGE 0)

```
Grant budget task creation cancelled.

No task was created. Re-run /budget with your description to start again.
```

### User Abandons Research (STAGE 2)

```
Grant budget research partially completed.

Completed: {questions_completed}/{questions_total} forcing questions
Task: #{N} - Status: [RESEARCHING]

Resume: /budget {N}
```

### openpyxl Not Available

```
Error: openpyxl Python package not installed.

Install with: pip install openpyxl

Then re-run: /budget {N}
```

---

## Output Artifacts

### Task Workflow Mode

| Artifact | Location |
|----------|----------|
| XLSX Spreadsheet | `specs/{NNN}_{SLUG}/grant-budget.xlsx` |
| JSON Metrics | `specs/{NNN}_{SLUG}/budget-metrics.json` |
| Research report | `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` |

### Legacy Mode (--quick)

| Artifact | Location |
|----------|----------|
| XLSX Spreadsheet | `present/grant-budget-{datetime}.xlsx` |
| JSON Metrics | `present/budget-metrics-{datetime}.json` |

---

## Workflow Summary

The standard workflow (with pre-task forcing questions):

```
/budget "description"    -> Asks forcing questions, creates task with data, stops at [NOT STARTED]
/research {N}            -> Uses forcing_data, completes research, generates XLSX, stops at [RESEARCHED]
/plan {N}                -> Reads research report, creates implementation plan
/implement {N}           -> Executes plan, generates final deliverables
```

Alternative: Resume existing task:
```
/budget {N}              -> Runs research on existing task, stops at [RESEARCHED]
```

---

## Examples

```bash
# Create new task with description - asks forcing questions first
/budget "NIH R01 budget for AI interpretability project"

# Resume research on existing task (uses stored forcing_data)
/budget 234

# Use file as context - asks forcing questions, creates task
/budget ~/grants/r01-aims.md

# Legacy standalone mode (generates spreadsheet immediately, no task)
/budget --quick MODULAR
```
