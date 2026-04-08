---
description: Contract review and negotiation counsel with task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/contract.md | --quick [contract type]
---

# /legal Command

Contract review and negotiation counsel command with task system integration.

## Overview

This command initiates contract review research through structured forcing questions. It asks essential forcing questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow.

## Syntax

- `/legal "SaaS vendor agreement with Company X"` - Ask forcing questions, create task with gathered data
- `/legal 256` - Resume research on existing task
- `/legal /path/to/contract.md` - Use file as contract input, ask questions, create task
- `/legal --quick "employment contract"` - Legacy standalone mode (no task creation)

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, run research, stop at [RESEARCHED] |
| File path | Read file for contract context, ask questions, create task |
| `--quick [args]` | Legacy standalone mode (skip task creation) |

## Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **REVIEW** | Risk assessment | Identify problematic clauses, red flags, missing protections |
| **NEGOTIATE** | Position building | Counter-terms, leverage points, BATNA/ZOPA analysis |
| **TERMS** | Term sheet review | Key terms, market benchmarks, standard vs non-standard |
| **DILIGENCE** | Due diligence | Comprehensive review for transaction, IP, liability, R&W |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: `--quick` flag or task number input.

### Step 0.1: Mode Selection

Use AskUserQuestion to present mode options:

```
What type of contract analysis do you need?

- REVIEW: Risk assessment and clause analysis
- NEGOTIATE: Position building and negotiation strategy
- TERMS: Term sheet review and benchmark comparison
- DILIGENCE: Comprehensive review for transaction
```

Store response as `selected_mode`.

### Step 0.2: Essential Forcing Questions

Ask abbreviated forcing questions to gather essential data. One question at a time.

**Question 1: Contract Type**
```
What type of contract is this?

Examples: SaaS agreement, employment contract, data license, SAFE note, partnership agreement, NDA
Be specific - "vendor agreement" is too vague. What kind of vendor? What are they providing?
```
Store as `forcing_data.contract_type`.

**Question 2: Primary Concern**
```
What is your primary concern or objective with this contract?

Examples: "Limit liability exposure", "Protect our IP", "Negotiate better data rights", "Ensure compliance"
What specifically worries you or needs attention?
```
Store as `forcing_data.primary_concern`.

**Question 3: Your Position**
```
What is your role/position in this contract?

Examples: "We are the customer", "We are the vendor", "I'm the employee", "We're the investor"
Are you the stronger or weaker negotiating party?
```
Store as `forcing_data.position`.

**Question 4: Financial Exposure**
```
What is the approximate deal value or financial exposure?

Examples: "$50K ARR", "$2M investment", "$300K/year compensation"
This determines whether attorney review is recommended (>$100K threshold).
If unknown, say "to be determined".
```
Store as `forcing_data.financial_exposure`.

### Step 0.3: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mode": "{selected_mode}",
  "contract_type": "{response_1}",
  "primary_concern": "{response_2}",
  "position": "{response_3}",
  "financial_exposure": "{response_4}",
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Legal] Contract Review and Negotiation Counsel
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
elif echo "$ARGUMENTS" | grep -qE '^\.|^/|^~|\.md$|\.txt$|\.pdf$'; then
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

# Read file as contract context
contract_content=$(cat "$file_path")

# Create description from filename
filename=$(basename "$file_path" | sed 's/\.[^.]*$//')
description="Contract review: $filename"
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
slug="contract_review_$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

# Create task in state.json with task_type and forcing_data
jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "Contract review: $description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "legal" \
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
### {task_number}. Contract review: {description}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Language**: founder
- **Type**: legal
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Mode: {selected_mode}
- Contract Type: {forcing_data.contract_type}
- Primary Concern: {forcing_data.primary_concern}
- Position: {forcing_data.position}
- Financial Exposure: {forcing_data.financial_exposure}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create contract review task

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Display Task Created Summary

For new tasks (description or file path input), display summary and STOP:

```
Contract review task created: Task #{N}

Forcing Data Gathered:
- Mode: {selected_mode}
- Contract Type: {forcing_data.contract_type}
- Primary Concern: {forcing_data.primary_concern}
- Position: {forcing_data.position}
- Financial Exposure: {forcing_data.financial_exposure}

Escalation Assessment: {Self-serve|Attorney review recommended} (based on ${exposure})

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to complete research with gathered data
- Run /plan {N} to create implementation plan
- Run /implement {N} to generate full contract analysis report
```

**STOP HERE for new tasks.** Do not auto-invoke research.

---

## STAGE 2: DELEGATE

**Only reached when input_type is "task_number" or "--quick".**

### STAGE 2A: Legacy Mode (--quick)

**If input_type == "quick"**:

Invoke skill-legal directly (original behavior):

```
skill: "skill-legal"
args: "contract_type={contract_type} primary_concern={concern} mode={mode} session_id={session_id}"
```

Skip to CHECKPOINT 2 (Legacy).

### STAGE 2B: Task Workflow Mode (existing task)

**Run research via skill-legal**:

```
skill: "skill-legal"
args: "task_number={task_number} session_id={session_id}"
```

The skill workflow:
1. Updates status to [RESEARCHING] (preflight)
2. Invokes legal-council-agent, passing forcing_data from task metadata
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
     echo "Resume: /legal $task_number"
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
   Contract review research complete for Task #{N}

   Research Report: {research_path}

   Data Gathered:
   - Contract type: {captured}
   - Primary concerns: {captured}
   - Position: {captured}
   - Financial exposure: {captured}
   - Walk-away conditions: {captured}
   - Escalation level: {captured}

   Status: [RESEARCHED]

   Next Steps:
   - Review research report for accuracy
   - Run /plan {N} to create implementation plan
   - Run /implement {N} to generate full contract analysis report
   ```

### For Legacy Mode (--quick)

```
Contract review analysis generated.

Mode: {MODE}
Artifact: founder/contract-analysis-{datetime}.typ

Summary:
{summary}

Key Findings:
- Risk Level: {level}
- Top Concerns: {concerns}
- Escalation: {recommendation}

Next: Review artifact and consider attorney consultation for material items
```

---

## Error Handling

### Task Not Found (task number mode)

```
Error: Task {N} not found in state.json
Run /task "description" or /legal "description" to create a new task
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
Resume: /legal {N}
```

### User Abandons Forcing Questions (STAGE 0)

If user abandons during STAGE 0 forcing questions:
```
Contract review task creation cancelled.

No task was created. Re-run /legal with your description to start again.
```

### User Abandons Research (STAGE 2)

Return partial status, task remains in [RESEARCHING]:
```
Contract review research partially completed.

Completed: {questions_completed}/{questions_total} forcing questions
Task: #{N} - Status: [RESEARCHING]

Resume: /legal {N}
```

---

## Output Artifacts

### Task Workflow Mode

| Artifact | Location |
|----------|----------|
| Research report | `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` |

**Note**: Full contract analysis report (`strategy/contract-analysis-*.typ`, with `.md` fallback) is generated by `/implement`, not `/legal`.

### Legacy Mode (--quick)

| Artifact | Location |
|----------|----------|
| Contract analysis | `founder/contract-analysis-{datetime}.typ` |

---

## Workflow Summary

The standard workflow (with pre-task forcing questions):

```
/legal "description"    -> Asks forcing questions, creates task with data, stops at [NOT STARTED]
/research {N}           -> Uses forcing_data, completes research, stops at [RESEARCHED]
/plan {N}               -> Reads research report, creates implementation plan
/implement {N}          -> Executes plan, generates strategy/contract-analysis-*.typ
```

Alternative: Resume existing task:
```
/legal {N}              -> Runs research on existing task, stops at [RESEARCHED]
```

---

## Examples

```bash
# Create new task with description - asks forcing questions first
/legal "SaaS vendor agreement with DataCorp"

# Resume research on existing task (uses stored forcing_data)
/legal 256

# Use file as contract input - asks forcing questions, creates task
/legal ~/contracts/vendor-agreement.md

# Legacy standalone mode (generates output immediately, no task)
/legal --quick "employment contract for senior engineer"
```
