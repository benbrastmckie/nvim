---
description: Funding landscape analysis with funder portfolio mapping, budget justification, and gap analysis
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | --quick [topic]
model: opus
---

# /funds Command

Funding landscape analysis and verification command with task system integration.

## Overview

This command initiates funding analysis research through structured forcing questions. It asks essential forcing questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow.

## Syntax

- `/funds "NIH R01 funding landscape for computational biology"` - Ask forcing questions, create task with gathered data
- `/funds 400` - Resume research on existing task
- `/funds --quick "F&A rate comparison"` - Legacy standalone mode (no task creation)

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, delegate to skill-funds, stop at [RESEARCHED] |
| `--quick [args]` | Legacy standalone mode (skip task creation) |

## Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **LANDSCAPE** | Survey opportunities | Map funding programs, identify mechanisms, assess eligibility |
| **PORTFOLIO** | Analyze funder | Examine funder priorities, past awards, portfolio patterns |
| **JUSTIFY** | Verify budget | Cross-check budget against funder guidelines, validate cost categories |
| **GAP** | Identify gaps | Map funded vs unfunded areas, find strategic opportunities |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description input).**

**Skip this stage if**: `--quick` flag or task number input.

### Step 0.1: Mode Selection

Use AskUserQuestion to present mode options:

```
What type of funding analysis do you need?

- LANDSCAPE: Map funding opportunities for a research area (which funders, which mechanisms, what deadlines)
- PORTFOLIO: Analyze a specific funder's priorities and past awards (deep-dive on one funder)
- JUSTIFY: Verify budget justification against funder guidelines (cost compliance check)
- GAP: Identify unfunded areas and strategic funding opportunities (portfolio-level analysis)
```

Store response as `selected_mode`.

### Step 0.2: Essential Forcing Questions

Ask abbreviated forcing questions to gather essential data. One question at a time.

**Question 1: Research Area / Project**
```
What research project or area needs funding analysis?

Examples: "Computational modeling of protein folding dynamics", "Community health intervention for diabetes prevention", "Machine learning for materials discovery"
Be specific - "my research" or "the project" is too vague. What discipline, what aims, what methodology?
```
Store as `forcing_data.research_area`.

**Question 2: Funding History / Current Awards**
```
What current or past funding do you have? List each award with funder, mechanism, amount, and period.

Examples: "NIH R21 AI123456, $275K, 2024-2026", "NSF CAREER 2345678, $500K, 2023-2028", "No current funding"
Provide specific award numbers and amounts. "We have some grants" or "NIH-funded" is insufficient.
```
Store as `forcing_data.funding_history`.

**Question 3: Target Funders / Programs**
```
Which funders or programs are you targeting? Or should we survey the landscape?

Examples: "NIH NIGMS R01", "NSF BIO Division CAREER", "Survey all federal options for computational biology"
Specify agencies, institutes, and mechanisms where known. "Federal funding" without specifics needs clarification.
```
Store as `forcing_data.target_funders`.

**Question 4: Budget Parameters**
```
What is the budget range you need? Any known cost constraints?

Examples: "$250K/year direct costs for 5 years", "Modular budget under $250K", "Need to include 52% F&A rate"
Include salary caps, F&A rate limits, cost-sharing requirements, or equipment thresholds if known.
"Standard budget" or "whatever they allow" is too vague.
```
Store as `forcing_data.budget_parameters`.

**Question 5: Decision Context**
```
What funding decision does this analysis inform?

Examples: "Whether to pursue R01 vs R21 for preliminary data", "Resubmission strategy after A1 triage", "Which NSF division to target", "Building 5-year funding portfolio plan"
This determines the required depth and output format.
```
Store as `forcing_data.decision_context`.

### Step 0.3: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mode": "{selected_mode}",
  "research_area": "{response_1}",
  "funding_history": "{response_2}",
  "target_funders": "{response_3}",
  "budget_parameters": "{response_4}",
  "decision_context": "{response_5}",
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Funds] Funding Landscape Analysis
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

# Default: treat as description for new task
else
  input_type="description"
  description="$ARGUMENTS"
fi
```

### Step 3: Handle Input Type

**If `--quick` (legacy mode)**:
Skip STAGE 0 and go directly to STAGE 2A (legacy delegation).

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

# Validate language is present
task_lang=$(echo "$task_data" | jq -r '.language')
if [ "$task_lang" = "present" | not ]; then
  echo "Error: Task $task_number is not a present task (language: $task_lang)"
  exit 1
fi

# Validate task_type is funds
task_type=$(echo "$task_data" | jq -r '.task_type // ""')
if [ "$task_type" = "funds" | not ]; then
  echo "Error: Task $task_number is not a funds task (type: $task_type)"
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
slug="funding_analysis_$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

# Create task in state.json with task_type and forcing_data
jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "Funding analysis: $description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "funds" \
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

# Update TODO.md
task_number=$next_num
```

### Step 5: Update TODO.md

Add task entry to TODO.md (if new task):

```markdown
### {task_number}. Funding analysis: {description}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: present
- **Type**: funds
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Mode: {selected_mode}
- Research Area: {forcing_data.research_area}
- Funding History: {forcing_data.funding_history}
- Target Funders: {forcing_data.target_funders}
- Budget Parameters: {forcing_data.budget_parameters}
- Decision Context: {forcing_data.decision_context}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create funding analysis task

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Step 7: Display Task Created Summary

For new tasks (description input), display summary and STOP:

```
Funding analysis task created: Task #{N}

Forcing Data Gathered:
- Mode: {selected_mode}
- Research Area: {forcing_data.research_area}
- Funding History: {forcing_data.funding_history}
- Target Funders: {forcing_data.target_funders}
- Budget Parameters: {forcing_data.budget_parameters}
- Decision Context: {forcing_data.decision_context}

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to complete research with gathered data
- Run /plan {N} to create implementation plan
- Run /implement {N} to generate full funding analysis report
```

**STOP HERE for new tasks.** Do not auto-invoke research.

---

## STAGE 2: DELEGATE

**Only reached when input_type is "task_number" or "--quick".**

### STAGE 2A: Legacy Mode (--quick)

**If input_type == "quick"**:

Invoke skill-funds directly (standalone behavior):

```
skill: "skill-funds"
args: "topic={topic} mode={mode} session_id={session_id}"
```

Skip to CHECKPOINT 2 (Legacy).

### STAGE 2B: Task Workflow Mode (existing task)

**Run research via skill-funds**:

```
skill: "skill-funds"
args: "task_number={task_number} session_id={session_id}"
```

The skill workflow:
1. Updates status to [RESEARCHING] (preflight)
2. Invokes funds-agent, passing forcing_data from task metadata
3. Agent uses pre-gathered data, asks follow-up questions as needed
4. Agent researches funder databases, analyzes opportunities
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

   if [ "$status" = "researched" | not ]; then
     echo "Research incomplete. Status: [$status]"
     echo "Resume: /funds $task_number"
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
   Funding analysis research complete for Task #{N}

   Research Report: {research_path}

   Data Gathered:
   - Mode: {mode}
   - Research area: {captured}
   - Funding history: {captured}
   - Target funders: {captured}
   - Budget parameters: {captured}
   - Decision context: {captured}

   Analysis Outputs:
   - Landscape: specs/{NNN}_{SLUG}/funding-landscape.xlsx
   - Metrics: specs/{NNN}_{SLUG}/funding-metrics.json

   Status: [RESEARCHED]

   Next Steps:
   - Review research report and funding landscape spreadsheet
   - Run /plan {N} to create implementation plan
   - Run /implement {N} to generate full funding analysis report
   ```

### For Legacy Mode (--quick)

```
Funding analysis generated.

Mode: {MODE}
Summary:
{summary}

Key Findings:
- {finding_1}
- {finding_2}

Next: Review output and verify with source documents
```

---

## Error Handling

### Task Not Found (task number mode)

```
Error: Task {N} not found in state.json
Run /task "description" or /funds "description" to create a new task
```

### Research Incomplete

```
Research incomplete for Task #{N}
Status: [{current_status}]
Resume: /funds {N}
```

### User Abandons Forcing Questions (STAGE 0)

If user abandons during STAGE 0 forcing questions:
```
Funding analysis task creation cancelled.

No task was created. Re-run /funds with your description to start again.
```

---

## Core Command Integration

Tasks with language="present" and task_type="funds" route through core commands:

| Command | Routes To | Purpose |
|---------|-----------|---------|
| `/research N` | skill-funds | Research funding landscape |
| `/plan N` | skill-planner | Create implementation plan |
| `/implement N` | skill-funds | Generate funding analysis report |

---

## Workflow Summary

The standard workflow (with pre-task forcing questions):

```
/funds "description"    -> Asks forcing questions, creates task with data, stops at [NOT STARTED]
/research {N}           -> Uses forcing_data, completes research, stops at [RESEARCHED]
/plan {N}               -> Reads research report, creates implementation plan
/implement {N}          -> Executes plan, generates funding analysis deliverables
```

Alternative: Resume existing task:
```
/funds {N}              -> Runs research on existing task, stops at [RESEARCHED]
```

---

## Examples

```bash
# Create new task with description - asks forcing questions first
/funds "NIH R01 funding landscape for computational biology"

# Resume research on existing task (uses stored forcing_data)
/funds 400

# Legacy standalone mode (generates output immediately, no task)
/funds --quick "F&A rate comparison across institutes"
```
