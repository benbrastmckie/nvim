---
description: Market sizing research using TAM/SAM/SOM framework with task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick [industry] [segment]
---

# /market Command

Market sizing research command using TAM/SAM/SOM framework with task system integration.

## Overview

This command initiates market sizing research through structured forcing questions. It asks essential forcing questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow.

## Syntax

- `/market "fintech payments app"` - Ask forcing questions, create task with gathered data
- `/market 234` - Resume research on existing task
- `/market /path/to/context.md` - Use file as context, ask questions, create task
- `/market --quick fintech payments` - Legacy standalone mode (no task creation)

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, run research, stop at [RESEARCHED] |
| File path | Read file for context, ask questions, create task |
| `--quick [args]` | Legacy standalone mode (skip task creation) |

## Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **VALIDATE** | Test assumptions | Evidence gathering, bottom-up sizing |
| **SIZE** | Comprehensive | All three tiers with methodology |
| **SEGMENT** | Deep dive | Specific segment breakdown |
| **DEFEND** | Investor-ready | Credibility, data sources, conservative estimates |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: `--quick` flag or task number input.

### Step 0.1: Mode Selection

Use AskUserQuestion to present mode options:

```
What type of market sizing analysis do you need?

- VALIDATE: Test specific assumptions with evidence
- SIZE: Comprehensive TAM/SAM/SOM analysis
- SEGMENT: Deep dive into specific market segment
- DEFEND: Investor-ready with conservative estimates
```

Store response as `selected_mode`.

### Step 0.2: Essential Forcing Questions

Ask abbreviated forcing questions to gather essential data. One question at a time.

**Question 1: Problem Definition**
```
What specific problem does your product/service solve?
Be concrete - "helps businesses" is too vague. What pain point, for whom?
```
Store as `forcing_data.problem`.

**Question 2: Target Entity**
```
Who is your primary customer?
Specify: Individual consumers, businesses (what size?), or specific job titles?
```
Store as `forcing_data.target_entity`.

**Question 3: Geographic Scope**
```
What is your initial geographic scope?
Examples: US only, North America, Global, specific regions/countries
```
Store as `forcing_data.geography`.

**Question 4: Price Point (optional)**
```
Do you have a target price point or revenue model?
If known, specify. Otherwise, say "to be determined" and we'll research comparable pricing.
```
Store as `forcing_data.price_point`.

### Step 0.3: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mode": "{selected_mode}",
  "problem": "{response_1}",
  "target_entity": "{response_2}",
  "geography": "{response_3}",
  "price_point": "{response_4}",
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Market] TAM/SAM/SOM Market Sizing Research
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
  # Remove --quick from arguments
  args=$(echo "$ARGUMENTS" | sed 's/^--quick *//')

# Check for task number
elif echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then
  input_type="task_number"
  task_number="$ARGUMENTS"

# Check for file path
elif echo "$ARGUMENTS" | grep -qE '^\.|^/|^~|\.md$|\.txt$'; then
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
description="Market sizing: $filename"
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
slug="market_sizing_$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

# Create task in state.json with task_type and forcing_data
jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "Market sizing: $description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "market" \
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
### {task_number}. Market sizing: {description}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Language**: founder
- **Type**: market
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Mode: {selected_mode}
- Problem: {forcing_data.problem}
- Target: {forcing_data.target_entity}
- Geography: {forcing_data.geography}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create market sizing task

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Display Task Created Summary

For new tasks (description or file path input), display summary and STOP:

```
Market sizing task created: Task #{N}

Forcing Data Gathered:
- Mode: {selected_mode}
- Problem: {forcing_data.problem}
- Target: {forcing_data.target_entity}
- Geography: {forcing_data.geography}
- Price Point: {forcing_data.price_point}

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to complete research with gathered data
- Run /plan {N} to create implementation plan
- Run /implement {N} to generate final market sizing report
```

**STOP HERE for new tasks.** Do not auto-invoke research.

---

## STAGE 2: DELEGATE

**Only reached when input_type is "task_number" or "--quick".**

### STAGE 2A: Legacy Mode (--quick)

**If input_type == "quick"**:

Invoke skill-market directly (original behavior):

```
skill: "skill-market"
args: "industry={industry} segment={segment} mode={mode} session_id={session_id}"
```

Skip to CHECKPOINT 2 (Legacy).

### STAGE 2B: Task Workflow Mode (existing task)

**Run research via skill-market**:

```
skill: "skill-market"
args: "task_number={task_number} session_id={session_id}"
```

The skill workflow:
1. Updates status to [RESEARCHING] (preflight)
2. Invokes market-agent, passing forcing_data from task metadata
3. Agent uses pre-gathered data, asks follow-up questions as needed
4. Agent creates research report at `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md`
5. Updates status to [RESEARCHED] (postflight)
6. Links artifact and commits

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
     echo "Resume: /market $task_number"
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
   Market sizing research complete for Task #{N}

   Research Report: {research_path}

   Data Gathered:
   - Problem definition: {captured}
   - Entity count: {captured}
   - Price point: {captured}
   - Geographic scope: {captured}
   - Capture rates: {captured}
   - Competitive context: {captured}

   Status: [RESEARCHED]

   Next Steps:
   - Review research report for accuracy
   - Run /plan {N} to create implementation plan
   - Run /implement {N} to generate final market sizing report
   ```

### For Legacy Mode (--quick)

```
Market sizing analysis generated.

Mode: {MODE}
Artifact: founder/market-sizing-{datetime}.typ

Summary:
{summary}

Key Numbers:
- TAM: ${TAM}
- SAM: ${SAM}
- SOM: ${SOM}

Next: Review artifact and validate assumptions
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
Resume: /market {N}
```

### User Abandons Forcing Questions (STAGE 0)

If user abandons during STAGE 0 forcing questions:
```
Market sizing task creation cancelled.

No task was created. Re-run /market with your description to start again.
```

### User Abandons Research (STAGE 2)

Return partial status, task remains in [RESEARCHING]:
```
Market sizing research partially completed.

Completed: {questions_completed}/{questions_total} forcing questions
Task: #{N} - Status: [RESEARCHING]

Resume: /market {N}
```

---

## Output Artifacts

### Task Workflow Mode

| Artifact | Location |
|----------|----------|
| Research report | `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` |

**Note**: Final market sizing report (`strategy/market-sizing-*.typ`, with `.md` fallback) is generated by `/implement`, not `/market`.

### Legacy Mode (--quick)

| Artifact | Location |
|----------|----------|
| Market sizing analysis | `founder/market-sizing-{datetime}.typ` |

---

## Workflow Summary

The standard workflow (with pre-task forcing questions):

```
/market "description"   -> Asks forcing questions, creates task with data, stops at [NOT STARTED]
/research {N}           -> Uses forcing_data, completes research, stops at [RESEARCHED]
/plan {N}               -> Reads research report, creates implementation plan
/implement {N}          -> Executes plan, generates strategy/market-sizing-*.typ
```

Alternative: Resume existing task:
```
/market {N}             -> Runs research on existing task, stops at [RESEARCHED]
```

---

## Examples

```bash
# Create new task with description - asks forcing questions first
/market "fintech payments for SMBs"

# Resume research on existing task (uses stored forcing_data)
/market 234

# Use file as context - asks forcing questions, creates task
/market ~/startup/pitch-deck.md

# Legacy standalone mode (generates full output immediately, no task)
/market --quick fintech payments
```
