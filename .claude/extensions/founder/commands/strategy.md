---
description: Go-to-market strategy research with task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick [topic]
---

# /strategy Command

Go-to-market strategy research command that gathers positioning, channel, and launch context through structured forcing questions. Integrates with the task system for tracking and artifacts.

## Overview

This command initiates GTM strategy research through structured questioning. It asks essential forcing questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow with 90-day plans.

## Syntax

- `/strategy "B2B SaaS product launch"` - Ask forcing questions, create task with gathered data
- `/strategy 234` - Resume research on existing task
- `/strategy /path/to/strategy-notes.md` - Use file as context, ask questions, create task
- `/strategy --quick B2B SaaS launch` - Legacy standalone mode (no task creation)

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
| **LAUNCH** | Maximize splash | Awareness, differentiation, initial traction |
| **SCALE** | Optimize engine | CAC optimization, channel scaling, automation |
| **PIVOT** | Find new wedge | Customer segments, value prop testing |
| **EXPAND** | Adjacent markets | New segments, expansion playbook |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: `--quick` flag or task number input.

### Step 0.1: Mode Selection

Use AskUserQuestion to present mode options:

```
What type of GTM strategy do you need?

- LAUNCH: Maximize awareness and initial traction
- SCALE: Optimize acquisition engine, lower CAC
- PIVOT: Test new customer segments or value props
- EXPAND: Enter adjacent markets
```

Store response as `selected_mode`.

### Step 0.2: Essential Forcing Questions

Ask abbreviated forcing questions to gather essential data. One question at a time.

**Question 1: Target Customer**
```
Who is your ideal customer in one sentence?
Be specific: job title, company size, industry, pain level.
```
Store as `forcing_data.target_customer`.

**Question 2: Core Value Proposition**
```
What is the single most important benefit you provide?
Not a feature - the outcome your customer gets.
```
Store as `forcing_data.value_prop`.

**Question 3: Key Differentiator**
```
Why would someone choose you over the alternative (including doing nothing)?
What makes you fundamentally different, not just better?
```
Store as `forcing_data.differentiator`.

**Question 4: Primary Channel Hypothesis**
```
Where do your target customers currently look for solutions?
Examples: Google search, Twitter, conferences, word of mouth, etc.
```
Store as `forcing_data.channel_hypothesis`.

**Question 5: Launch Timeline**
```
What is your launch context?
Examples: "Pre-launch building waitlist", "Just launched, first 100 users", "Post-PMF scaling"
```
Store as `forcing_data.launch_context`.

### Step 0.3: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mode": "{selected_mode}",
  "target_customer": "{response_1}",
  "value_prop": "{response_2}",
  "differentiator": "{response_3}",
  "channel_hypothesis": "{response_4}",
  "launch_context": "{response_5}",
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Strategy] Go-to-Market Strategy Research
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
description="GTM strategy: $filename"
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
slug="gtm_strategy_$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "GTM strategy: $description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "strategy" \
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

task_number=$next_num
```

### Step 5: Update TODO.md

Add task entry (if new task):

```markdown
### {task_number}. GTM strategy: {description}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Language**: founder
- **Type**: strategy
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Mode: {selected_mode}
- Target Customer: {forcing_data.target_customer}
- Value Prop: {forcing_data.value_prop}
- Differentiator: {forcing_data.differentiator}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create GTM strategy task

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Display Task Created Summary

For new tasks (description or file path input), display summary and STOP:

```
GTM strategy task created: Task #{N}

Forcing Data Gathered:
- Mode: {selected_mode}
- Target Customer: {forcing_data.target_customer}
- Value Prop: {forcing_data.value_prop}
- Differentiator: {forcing_data.differentiator}
- Channel Hypothesis: {forcing_data.channel_hypothesis}
- Launch Context: {forcing_data.launch_context}

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to complete research with gathered data
- Run /plan {N} to create implementation plan
- Run /implement {N} to generate full GTM strategy with 90-day plan
```

**STOP HERE for new tasks.** Do not auto-invoke research.

---

## STAGE 2: DELEGATE

**Only reached when input_type is "task_number" or "--quick".**

### STAGE 2A: Legacy Mode (--quick)

**If input_type == "quick"**:

Invoke skill-strategy directly (original behavior):

```
skill: "skill-strategy"
args: "topic={topic} mode={mode} session_id={session_id}"
```

Skip to CHECKPOINT 2 (Legacy).

### STAGE 2B: Task Workflow Mode (existing task)

**Run research via skill-strategy**:

```
skill: "skill-strategy"
args: "task_number={task_number} session_id={session_id}"
```

The skill workflow:
1. Updates status to [RESEARCHING] (preflight)
2. Invokes strategy-agent, passing forcing_data from task metadata
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
     echo "Resume: /strategy $task_number"
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
   GTM strategy research complete for Task #{N}

   Research Report: {research_path}

   Data Gathered:
   - Target customer: {captured}
   - Problem/need: {captured}
   - Key benefit: {captured}
   - Differentiator: {captured}
   - Channel data: {captured}
   - Launch context: {captured}
   - North Star metric: {captured}

   Status: [RESEARCHED]

   Next Steps:
   - Review research report for accuracy
   - Run /plan {N} to create implementation plan
   - Run /implement {N} to generate full GTM strategy with 90-day plan
   ```

### For Legacy Mode (--quick)

```
GTM strategy generated.

Mode: {MODE}
Artifact: founder/gtm-strategy-{datetime}.typ

Summary:
{summary}

Positioning:
For {target} who {problem}, {product} is a {category} that {benefit}.

Top Channels:
1. {channel1} - CAC: ${CAC1}
2. {channel2} - CAC: ${CAC2}

Next: Review 90-day plan and assign owners
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
Resume: /strategy {N}
```

### User Abandons Forcing Questions (STAGE 0)

If user abandons during STAGE 0 forcing questions:
```
GTM strategy task creation cancelled.

No task was created. Re-run /strategy with your description to start again.
```

---

## Output Artifacts

### Task Workflow Mode

| Artifact | Location |
|----------|----------|
| Research report | `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` |

**Note**: Full GTM strategy (`strategy/gtm-strategy-*.typ`, with `.md` fallback) is generated by `/implement`, not `/strategy`.

### Legacy Mode (--quick)

| Artifact | Location |
|----------|----------|
| GTM strategy | `founder/gtm-strategy-{datetime}.typ` |

---

## Workflow Summary

The standard workflow (with pre-task forcing questions):

```
/strategy "description" -> Asks forcing questions, creates task with data, stops at [NOT STARTED]
/research {N}           -> Uses forcing_data, completes research, stops at [RESEARCHED]
/plan {N}               -> Reads research report, creates implementation plan
/implement {N}          -> Executes plan, generates strategy/gtm-strategy-*.typ
```

Alternative: Resume existing task:
```
/strategy {N}           -> Runs research on existing task, stops at [RESEARCHED]
```

---

## Examples

```bash
# Create new task with description - asks forcing questions first
/strategy "B2B SaaS product launch"

# Resume research on existing task (uses stored forcing_data)
/strategy 234

# Use file as context - asks forcing questions, creates task
/strategy ~/startup/launch-notes.md

# Legacy standalone mode (generates full output immediately, no task)
/strategy --quick B2B SaaS launch
```
