---
description: Competitive landscape research with task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick [competitors]
---

# /analyze Command

Competitive analysis research command that gathers competitive intelligence through structured forcing questions. Integrates with the task system for tracking and artifacts.

## Overview

This command initiates competitive analysis research through structured questioning. It asks essential forcing questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow.

## Syntax

- `/analyze "fintech payments competitors"` - Ask forcing questions, create task with gathered data
- `/analyze 234` - Resume research on existing task
- `/analyze /path/to/competitors.md` - Use file as context, ask questions, create task
- `/analyze --quick stripe,square,adyen` - Legacy standalone mode (no task creation)

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
| **LANDSCAPE** | Map the field | All competitors, categories |
| **DEEP** | Focus on key rivals | Top 3-5 detailed analysis |
| **POSITION** | Find white space | 2x2 maps, differentiation |
| **BATTLE** | Prepare for competition | Battle cards, objection handling |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: `--quick` flag or task number input.

### Step 0.1: Mode Selection

Use AskUserQuestion to present mode options:

```
What type of competitive analysis do you need?

- LANDSCAPE: Map all competitors and categories
- DEEP: Detailed analysis of top 3-5 rivals
- POSITION: Find white space, create positioning maps
- BATTLE: Prepare battle cards and objection handling
```

Store response as `selected_mode`.

### Step 0.2: Essential Forcing Questions

Ask abbreviated forcing questions to gather essential data. One question at a time.

**Question 1: Your Product/Service**
```
What is your product/service in one sentence?
Be specific about what you do and for whom.
```
Store as `forcing_data.product`.

**Question 2: Known Competitors**
```
Who are your known competitors? (List names, comma-separated)
Include both direct competitors and alternatives customers might consider.
```
Store as `forcing_data.known_competitors`.

**Question 3: Competitive Dimension**
```
What is your primary competitive advantage?
Examples: price, speed, features, ease of use, integrations, support
```
Store as `forcing_data.competitive_advantage`.

**Question 4: Customer Decision Factors**
```
What are the top 3 factors your customers consider when choosing?
Example: price, ease of setup, API quality, compliance certifications
```
Store as `forcing_data.decision_factors`.

### Step 0.3: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mode": "{selected_mode}",
  "product": "{response_1}",
  "known_competitors": "{response_2}",
  "competitive_advantage": "{response_3}",
  "decision_factors": "{response_4}",
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Analyze] Competitive Landscape Research
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
file_path=$(eval echo "$file_path")
if [ ! -f "$file_path" ]; then
  echo "Error: File not found: $file_path"
  exit 1
fi
context_content=$(cat "$file_path")
filename=$(basename "$file_path" | sed 's/\.[^.]*$//')
description="Competitive analysis: $filename"
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
if [ "$task_lang" != "founder" ]; then
  echo "Error: Task $task_number is not a founder task (language: $task_lang)"
  exit 1
fi
```
Skip STAGE 0, go directly to STAGE 2B.

**If description (new task)**:
Proceed to STAGE 0 for forcing questions, then Step 4.

### Step 4: Create Task (if needed)

```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
slug="competitive_analysis_$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "Competitive analysis: $description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "analyze" \
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

task_number=$next_num
```

### Step 5: Update TODO.md

Add task entry (if new task):

```markdown
### {task_number}. Competitive analysis: {description}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: founder
- **Type**: analyze
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Mode: {selected_mode}
- Product: {forcing_data.product}
- Known Competitors: {forcing_data.known_competitors}
- Competitive Advantage: {forcing_data.competitive_advantage}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create competitive analysis task

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Display Task Created Summary

For new tasks (description or file path input), display summary and STOP:

```
Competitive analysis task created: Task #{N}

Forcing Data Gathered:
- Mode: {selected_mode}
- Product: {forcing_data.product}
- Known Competitors: {forcing_data.known_competitors}
- Competitive Advantage: {forcing_data.competitive_advantage}
- Decision Factors: {forcing_data.decision_factors}

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to complete research with gathered data
- Run /plan {N} to create implementation plan
- Run /implement {N} to generate full competitive analysis with positioning map
```

**STOP HERE for new tasks.** Do not auto-invoke research.

---

## STAGE 2: DELEGATE

**Only reached when input_type is "task_number" or "--quick".**

### STAGE 2A: Legacy Mode (--quick)

**If input_type == "quick"**:

Invoke skill-analyze directly (original behavior):

```
skill: "skill-analyze"
args: "competitors={competitors} mode={mode} session_id={session_id}"
```

Skip to CHECKPOINT 2 (Legacy).

### STAGE 2B: Task Workflow Mode (existing task)

**Run research via skill-analyze**:

```
skill: "skill-analyze"
args: "task_number={task_number} session_id={session_id}"
```

The skill workflow:
1. Updates status to [RESEARCHING] (preflight)
2. Invokes analyze-agent, passing forcing_data from task metadata
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
     echo "Resume: /analyze $task_number"
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
   Competitive analysis research complete for Task #{N}

   Research Report: {research_path}

   Data Gathered:
   - Direct competitors: {captured}
   - Indirect competitors: {captured}
   - Per-competitor analysis: {captured}
   - Positioning dimensions: {captured}
   - Strategic observations: {captured}

   Status: [RESEARCHED]

   Next Steps:
   - Review research report for accuracy
   - Run /plan {N} to create implementation plan
   - Run /implement {N} to generate full competitive analysis with positioning map
   ```

### For Legacy Mode (--quick)

```
Competitive analysis generated.

Mode: {MODE}
Artifact: founder/competitive-analysis-{datetime}.typ

Summary:
{summary}

Competitors Analyzed:
- {competitor1}: {positioning}
- {competitor2}: {positioning}

Next: Review artifact and prepare for competitive situations
```

---

## Error Handling

### Task Not Found

```
Error: Task {N} not found in state.json
Run /task "description" to create a new task
```

### File Not Found

```
Error: File not found: {path}
Verify the file path and try again
```

### Research Incomplete

```
Research incomplete for Task #{N}
Status: [{current_status}]
Resume: /analyze {N}
```

### User Abandons Forcing Questions (STAGE 0)

If user abandons during STAGE 0 forcing questions:
```
Competitive analysis task creation cancelled.

No task was created. Re-run /analyze with your description to start again.
```

---

## Output Artifacts

### Task Workflow Mode

| Artifact | Location |
|----------|----------|
| Research report | `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` |

**Note**: Full competitive analysis (`strategy/competitive-analysis-*.typ`, with `.md` fallback) is generated by `/implement`, not `/analyze`.

### Legacy Mode (--quick)

| Artifact | Location |
|----------|----------|
| Competitive analysis | `founder/competitive-analysis-{datetime}.typ` |

---

## Workflow Summary

The standard workflow (with pre-task forcing questions):

```
/analyze "description" -> Asks forcing questions, creates task with data, stops at [NOT STARTED]
/research {N}          -> Uses forcing_data, completes research, stops at [RESEARCHED]
/plan {N}              -> Reads research report, creates implementation plan
/implement {N}         -> Executes plan, generates strategy/competitive-analysis-*.typ
```

Alternative: Resume existing task:
```
/analyze {N}           -> Runs research on existing task, stops at [RESEARCHED]
```

---

## Examples

```bash
# Create new task with description - asks forcing questions first
/analyze "fintech payments competitors"

# Resume research on existing task (uses stored forcing_data)
/analyze 234

# Use file as context - asks forcing questions, creates task
/analyze ~/startup/competitor-notes.md

# Legacy standalone mode (generates full output immediately, no task)
/analyze --quick stripe,square,adyen
```
