---
description: Financial analysis and verification with task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/financials.xlsx | --quick [topic]
---

# /finance Command

Financial analysis and verification command with task system integration.

## Overview

This command initiates financial analysis research through structured forcing questions. It asks essential forcing questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow.

## Syntax

- `/finance "Q1 revenue verification for Series A deck"` - Ask forcing questions, create task with gathered data
- `/finance 330` - Resume research on existing task
- `/finance /path/to/projections.xlsx` - Use file as financial input, ask questions, create task
- `/finance --quick "runway analysis"` - Legacy standalone mode (no task creation)

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, run research, stop at [RESEARCHED] |
| File path | Read file for financial context, ask questions, create task |
| `--quick [args]` | Legacy standalone mode (skip task creation) |

## Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **AUDIT** | Verify numbers | Cross-check existing financials, find discrepancies, validate calculations |
| **MODEL** | Build models | Revenue/cost models, unit economics, scenario analysis |
| **FORECAST** | Project forward | Cash flow projection, runway calculation, growth modeling |
| **VALIDATE** | Stress test | Sensitivity analysis, assumption testing, break-even analysis |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: `--quick` flag or task number input.

### Step 0.1: Mode Selection

Use AskUserQuestion to present mode options:

```
What type of financial analysis do you need?

- AUDIT: Verify existing numbers and cross-check calculations
- MODEL: Build or improve financial models
- FORECAST: Project future numbers (runway, growth, cash flow)
- VALIDATE: Stress-test assumptions and sensitivity analysis
```

Store response as `selected_mode`.

### Step 0.2: Essential Forcing Questions

Ask abbreviated forcing questions to gather essential data. One question at a time.

**Question 1: Financial Document/Data**
```
What financial document or data do you want analyzed?

Examples: "Q1 P&L statement", "Series A financial projections", "cap table after seed round", "monthly burn spreadsheet"
Be specific - "our financials" is too vague. What document, what period, what format?
```
Store as `forcing_data.financial_document`.

**Question 2: Primary Objective**
```
What is the primary question you need answered?

Examples: "Are our revenue projections defensible?", "What's our real burn rate?", "Do the unit economics work at scale?"
What specifically needs verification, modeling, or analysis?
```
Store as `forcing_data.primary_objective`.

**Question 3: Time Horizon**
```
What time period does this analysis cover?

Examples: "Q1 2026 actuals", "FY2026 budget", "18-month runway projection", "3-year forecast for investors"
Specify start and end dates or period length.
```
Store as `forcing_data.time_horizon`.

**Question 4: Key Assumptions**
```
What are the critical assumptions underlying these numbers?

Examples: "15% MoM growth", "3% churn rate", "$49/mo price point", "40% gross margin"
List the 2-4 assumptions that most affect the outcome.
If unknown, say "to be determined from the data".
```
Store as `forcing_data.key_assumptions`.

**Question 5: Decision Context**
```
What decision does this analysis inform?

Examples: "Whether to raise Series A", "Hiring plan for Q3", "Pricing change decision", "Board presentation"
This determines the required rigor and presentation format.
```
Store as `forcing_data.decision_context`.

### Step 0.3: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mode": "{selected_mode}",
  "financial_document": "{response_1}",
  "primary_objective": "{response_2}",
  "time_horizon": "{response_3}",
  "key_assumptions": "{response_4}",
  "decision_context": "{response_5}",
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Finance] Financial Analysis and Verification
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
  args=$(echo "$ARGUMENTS" | sed 's/^--quick *//')

# Check for task number
elif echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then
  input_type="task_number"
  task_number="$ARGUMENTS"

# Check for file path (including financial file extensions)
elif echo "$ARGUMENTS" | grep -qE '^\.|^/|^~|\.md$|\.txt$|\.pdf$|\.xlsx$|\.csv$|\.json$|\.typ$'; then
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

# Read file as financial context
financial_content=$(cat "$file_path")

# Create description from filename
filename=$(basename "$file_path" | sed 's/\.[^.]*$//')
description="Financial analysis: $filename"
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
slug="financial_analysis_$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

# Create task in state.json with task_type and forcing_data
jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "Financial analysis: $description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "finance" \
   --argjson forcing_data "$forcing_data_json" \
   '. + {next_project_number: ($num + 1)} |
    .active_projects += [{
      project_number: $num,
      project_name: $name,
      status: "not_started",
      language: "founder",
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
### {task_number}. Financial analysis: {description}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Language**: founder
- **Type**: finance
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Mode: {selected_mode}
- Financial Document: {forcing_data.financial_document}
- Primary Objective: {forcing_data.primary_objective}
- Time Horizon: {forcing_data.time_horizon}
- Key Assumptions: {forcing_data.key_assumptions}
- Decision Context: {forcing_data.decision_context}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create financial analysis task

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Step 7: Display Task Created Summary

For new tasks (description or file path input), display summary and STOP:

```
Financial analysis task created: Task #{N}

Forcing Data Gathered:
- Mode: {selected_mode}
- Financial Document: {forcing_data.financial_document}
- Primary Objective: {forcing_data.primary_objective}
- Time Horizon: {forcing_data.time_horizon}
- Key Assumptions: {forcing_data.key_assumptions}
- Decision Context: {forcing_data.decision_context}

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to complete research with gathered data
- Run /plan {N} to create implementation plan
- Run /implement {N} to generate full financial analysis report
```

**STOP HERE for new tasks.** Do not auto-invoke research.

---

## STAGE 2: DELEGATE

**Only reached when input_type is "task_number" or "--quick".**

### STAGE 2A: Legacy Mode (--quick)

**If input_type == "quick"**:

Invoke skill-finance directly (original behavior):

```
skill: "skill-finance"
args: "topic={topic} mode={mode} session_id={session_id}"
```

Skip to CHECKPOINT 2 (Legacy).

### STAGE 2B: Task Workflow Mode (existing task)

**Run research via skill-finance**:

```
skill: "skill-finance"
args: "task_number={task_number} session_id={session_id}"
```

The skill workflow:
1. Updates status to [RESEARCHING] (preflight)
2. Invokes finance-agent, passing forcing_data from task metadata
3. Agent uses pre-gathered data, asks follow-up questions as needed
4. Agent reads financial documents, extracts numbers, creates verification spreadsheet
5. Agent creates research report at `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md`
6. Updates status to [RESEARCHED] (postflight)
7. Links artifact and commits

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
     echo "Resume: /finance $task_number"
     exit 1
   fi
   ```

2. **Get Research Artifact**
   ```bash
   research_path=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .artifacts[] | select(.type == "research") | .path' \
     specs/state.json)
   ```

3. **Display Result**
   ```
   Financial analysis research complete for Task #{N}

   Research Report: {research_path}

   Data Gathered:
   - Mode: {mode}
   - Financial document: {captured}
   - Primary objective: {captured}
   - Time horizon: {captured}
   - Key assumptions: {captured}
   - Decision context: {captured}

   Verification Outputs:
   - Spreadsheet: specs/{NNN}_{SLUG}/financial-verification.xlsx
   - Metrics: specs/{NNN}_{SLUG}/financial-metrics.json

   Status: [RESEARCHED]

   Next Steps:
   - Review research report and verification spreadsheet
   - Run /plan {N} to create implementation plan
   - Run /implement {N} to generate full financial analysis report
   ```

### For Legacy Mode (--quick)

```
Financial analysis generated.

Mode: {MODE}
Artifact: founder/financial-analysis-{datetime}.md

Summary:
{summary}

Key Findings:
- {finding_1}
- {finding_2}

Next: Review artifact and verify with source documents
```

---

## Error Handling

### Task Not Found (task number mode)

```
Error: Task {N} not found in state.json
Run /task "description" or /finance "description" to create a new task
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
Resume: /finance {N}
```

### User Abandons Forcing Questions (STAGE 0)

If user abandons during STAGE 0 forcing questions:
```
Financial analysis task creation cancelled.

No task was created. Re-run /finance with your description to start again.
```

### User Abandons Research (STAGE 2)

Return partial status, task remains in [RESEARCHING]:
```
Financial analysis research partially completed.

Completed: {questions_completed}/{questions_total} forcing questions
Task: #{N} - Status: [RESEARCHING]

Resume: /finance {N}
```

---

## Output Artifacts

### Task Workflow Mode

| Artifact | Location |
|----------|----------|
| Research report | `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` |
| Verification spreadsheet | `specs/{NNN}_{SLUG}/financial-verification.xlsx` |
| JSON metrics | `specs/{NNN}_{SLUG}/financial-metrics.json` |

**Note**: Full financial analysis report (`strategy/financial-analysis-*.md`) is generated by `/implement`, not `/finance`.

### Legacy Mode (--quick)

| Artifact | Location |
|----------|----------|
| Financial analysis | `founder/financial-analysis-{datetime}.md` |

---

## Workflow Summary

The standard workflow (with pre-task forcing questions):

```
/finance "description"  -> Asks forcing questions, creates task with data, stops at [NOT STARTED]
/research {N}           -> Uses forcing_data, completes research, stops at [RESEARCHED]
/plan {N}               -> Reads research report, creates implementation plan
/implement {N}          -> Executes plan, generates strategy/financial-analysis-*.md
```

Alternative: Resume existing task:
```
/finance {N}            -> Runs research on existing task, stops at [RESEARCHED]
```

---

## Examples

```bash
# Create new task with description - asks forcing questions first
/finance "Q1 revenue verification for Series A deck"

# Resume research on existing task (uses stored forcing_data)
/finance 330

# Use file as financial input - asks forcing questions, creates task
/finance ~/documents/projections-2026.xlsx

# Legacy standalone mode (generates output immediately, no task)
/finance --quick "runway analysis for board meeting"
```
