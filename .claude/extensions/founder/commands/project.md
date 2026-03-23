---
description: Project timeline management with WBS, PERT estimation, and resource allocation
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick [mode]
---

# /project Command

Project timeline management command with work breakdown structure (WBS), PERT estimation, and resource allocation. Integrates with the task system through structured forcing questions.

## Overview

This command initiates project planning through structured forcing questions. It asks essential forcing questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow with project timelines.

## Syntax

- `/project "Mobile App Redesign"` - Ask forcing questions, create task with gathered data
- `/project 234` - Resume project planning on existing task
- `/project /path/to/project-brief.md` - Use file as context, ask questions, create task
- `/project --quick PLAN` - Legacy standalone mode (no task creation)

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, run project planning, stop at [PLANNED] |
| File path | Read file for context, ask questions, create task |
| `--quick [mode]` | Legacy standalone mode (skip task creation) |

## Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **PLAN** | Create timeline | WBS structure, PERT estimates, resource allocation, critical path |
| **TRACK** | Update progress | Task completion %, milestone status, variance analysis |
| **REPORT** | Executive summary | Status dashboard, risk assessment, key decisions needed |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: `--quick` flag or task number input.

### Step 0.1: Mode Selection

Use AskUserQuestion to present mode options:

```
What type of project management do you need?

- PLAN: Create new project timeline from scratch
- TRACK: Update existing timeline with progress
- REPORT: Generate executive status summary
```

Store response as `selected_mode`.

**Note**: For new tasks, PLAN is typically the starting point. TRACK and REPORT require an existing timeline.

### Step 0.2: Essential Forcing Questions

Ask forcing questions to gather project planning data. One question at a time.

**Question 1: Project Name and Completion Criteria**
```
What is this project called, and what does "done" look like?

Push for: Specific project name, clear completion criteria
Reject: Vague goals like "improve things" or "make it better"
Example: "Mobile App Redesign - done when new app is live with 4+ star rating"
```
Store as `forcing_data.project_name` and `forcing_data.completion_criteria`.

**Push-back triggers**:
- "ASAP" or "Soon" -> "What is the specific completion criteria?"
- "Make it better" -> "What measurable outcome defines success?"

**Question 2: Goals and Deliverables**
```
What are the 2-4 key deliverables (nouns, not actions)?

Push for: Specific output artifacts, not activities
Reject: "Do the development" -> Accept: "Deployed application"
Example: "1. Approved mockups, 2. Working prototype, 3. Production deployment"
```
Store as `forcing_data.deliverables` (array).

**Push-back triggers**:
- Activity words (develop, build, create) -> "What is the deliverable, the noun you will hand over?"
- More than 4 items -> "Prioritize to 2-4 key deliverables"

**Question 3: Team Members with Roles and Allocation**
```
Who will work on this project? List names, roles, and allocation %.

Push for: Specific names, concrete roles, explicit allocations
Reject: "The team" or "developers"
Example: "Alice (PM, 50%), Bob (Designer, 100% during design, 25% after), Carol (Dev, 100%)"
```
Store as `forcing_data.team_members` (array of objects with name, role, allocation).

**Push-back triggers**:
- "The team" -> "Name the specific people and their roles."
- No allocation % -> "What percentage of their time is allocated to this project?"

**Question 4: Timeline Constraints**
```
What are your timeline constraints?

Push for: Start date, target end date, key milestones
Accept: Hard deadlines, soft targets, or "flexible but prefer by X"
Example: "Start: April 1, Must launch by: June 15 for trade show, Milestone: Beta by May 15"
```
Store as `forcing_data.start_date`, `forcing_data.target_date`, `forcing_data.milestones` (array).

**Push-back triggers**:
- "ASAP" -> "What is the specific target date?"
- No milestones -> "What are the key checkpoints between now and launch?"

**Question 5: Resource Needs**
```
What resources does this project require beyond the team?

Push for: Specific compute, budget, equipment, external services
Accept: "None beyond team time" if genuinely not needed
Example: "AWS compute: ~$500/month, Design tools: $100/month, External API: $200/month"
```
Store as `forcing_data.resource_needs`.

**Push-back triggers**:
- "Various resources" -> "List the specific resources needed."
- Empty answer -> "Confirm: No additional resources beyond team time?"

**Question 6: External Dependencies**
```
What external dependencies or blockers exist?

Push for: Specific external parties, third-party services, approvals needed
Accept: "None" if internal-only project
Example: "Need API access from Partner X (pending), Legal approval for ToS (due April 5)"
```
Store as `forcing_data.external_dependencies`.

**Push-back triggers**:
- "It depends" -> "What are the dependencies, specifically?"
- Vague timing -> "When do you expect each dependency to be resolved?"

**Question 7: Risk Factors**
```
What are the biggest risks to this project succeeding?

Push for: Specific risks with likelihood and impact
Reject: "Various risks" or "Things might go wrong"
Example: "1. Key developer might leave (medium likelihood, high impact), 2. API changes from partner (low likelihood, high impact)"
```
Store as `forcing_data.risk_factors` (array).

**Push-back triggers**:
- "Things might go wrong" -> "Name 2-3 specific risks with likelihood and impact."
- No impact assessment -> "What is the impact if this risk materializes?"

### Step 0.3: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mode": "{selected_mode}",
  "project_name": "{response_1_name}",
  "completion_criteria": "{response_1_criteria}",
  "deliverables": ["{deliverable_1}", "{deliverable_2}"],
  "team_members": [
    {"name": "{name}", "role": "{role}", "allocation": "{percent}"}
  ],
  "start_date": "{ISO date or null}",
  "target_date": "{ISO date or null}",
  "milestones": ["{milestone_1}", "{milestone_2}"],
  "resource_needs": "{response_5}",
  "external_dependencies": "{response_6}",
  "risk_factors": ["{risk_1}", "{risk_2}"],
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Project] Project Timeline Management
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
description="Project timeline: $filename"
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

# Validate task type is project
task_type=$(echo "$task_data" | jq -r '.task_type // ""')
if [ "$task_type" != "project" ]; then
  echo "Error: Task $task_number is not a project task (task_type: $task_type)"
  echo "Run /project with a description to create a new project task"
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

# Create slug from project name
slug="project_$(echo "$forcing_data_project_name" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

# Create task in state.json with task_type and forcing_data
jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "Project timeline: $forcing_data_project_name" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "project" \
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
### {task_number}. Project timeline: {project_name}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Language**: founder
- **Type**: project
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Mode: {selected_mode}
- Completion Criteria: {forcing_data.completion_criteria}
- Deliverables: {forcing_data.deliverables}
- Team: {forcing_data.team_members count} members allocated
- Timeline: {forcing_data.start_date} to {forcing_data.target_date}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create project timeline task

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Display Task Created Summary

For new tasks (description or file path input), display summary and STOP:

```
Project timeline task created: Task #{N}

Forcing Data Gathered:
- Mode: {selected_mode}
- Project: {forcing_data.project_name}
- Completion Criteria: {forcing_data.completion_criteria}
- Deliverables: {count} key deliverables
- Team: {count} members with allocations
- Timeline: {start_date} to {target_date}
- Milestones: {count} checkpoints
- Resources: {forcing_data.resource_needs}
- External Dependencies: {forcing_data.external_dependencies}
- Risk Factors: {count} identified

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to create project timeline with WBS and PERT estimates
- Run /plan {N} to create implementation plan
- Run /implement {N} to generate final timeline artifacts
```

**STOP HERE for new tasks.** Do not auto-invoke research.

---

## STAGE 2: DELEGATE

**Only reached when input_type is "task_number" or "--quick".**

### STAGE 2A: Legacy Mode (--quick)

**If input_type == "quick"**:

Invoke skill-project directly (original behavior):

```
skill: "skill-project"
args: "mode={mode} session_id={session_id}"
```

Skip to CHECKPOINT 2 (Legacy).

### STAGE 2B: Task Workflow Mode (existing task)

**Run project planning via skill-project**:

```
skill: "skill-project"
args: "task_number={task_number} session_id={session_id}"
```

The skill workflow:
1. Updates status to [PLANNING] (preflight)
2. Invokes project-agent, passing forcing_data from task metadata
3. Agent uses pre-gathered data, asks follow-up questions as needed
4. Agent creates timeline at `strategy/timelines/{project-slug}.typ`
5. Updates status to [PLANNED], [TRACKED], or [REPORTED] based on mode (postflight)
6. Links artifact and commits

---

## CHECKPOINT 2: GATE OUT

### For Task Workflow Mode (existing task)

1. **Verify Project Planning Completed**
   ```bash
   status=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .status' \
     specs/state.json)

   # Status depends on mode used
   if [ "$status" != "planned" ] && [ "$status" != "tracked" ] && [ "$status" != "reported" ]; then
     echo "Project planning incomplete. Status: [$status]"
     echo "Resume: /project $task_number"
     exit 1
   fi
   ```

2. **Get Timeline Artifact**
   ```bash
   timeline_path=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .artifacts[] | select(.type == "timeline") | .path' \
     specs/state.json)
   ```

3. **Display Result (PLAN mode)**
   ```
   Project timeline created for Task #{N}

   Timeline: {timeline_path}

   Project: {project_name}
   Completion Criteria: {completion_criteria}

   WBS Summary:
   - Phases: {phase_count}
   - Tasks: {task_count}
   - Total Duration: {duration} (PERT estimate)
   - Critical Path: {critical_path_summary}

   Team Allocation:
   - {member_1}: {role}, {allocation}
   - {member_2}: {role}, {allocation}

   Key Milestones:
   - {milestone_1}: {date}
   - {milestone_2}: {date}

   Status: [PLANNED]

   Next Steps:
   - Review timeline for accuracy
   - Use /project {N} with TRACK mode to update progress
   - Use /project {N} with REPORT mode for status summary
   ```

4. **Display Result (TRACK mode)**
   ```
   Project timeline updated for Task #{N}

   Timeline: {timeline_path} (updated)

   Progress Summary:
   - Overall: {percent}% complete
   - On Track: {on_track_count} tasks
   - At Risk: {at_risk_count} tasks
   - Completed: {completed_count} / {total_count} tasks

   Variance Analysis:
   - Schedule Variance: {sv_description}
   - Scope Changes: {scope_change_count}

   Status: [TRACKED]

   Next Steps:
   - Address at-risk items
   - Generate REPORT for stakeholders
   ```

5. **Display Result (REPORT mode)**
   ```
   Status report generated for Task #{N}

   Report: {report_path}

   Executive Summary:
   - Project: {project_name}
   - Status: {On Track|At Risk|Delayed}
   - Progress: {percent}% complete
   - Target Date: {target_date}

   Key Decisions Needed:
   - {decision_1}
   - {decision_2}

   Risk Assessment:
   - {risk_summary}

   Status: [REPORTED]

   Next Steps:
   - Share report with stakeholders
   - Schedule review meeting if At Risk
   ```

### For Legacy Mode (--quick)

```
Project timeline generated.

Mode: {MODE}
Artifact: strategy/timelines/{project-slug}.typ

Summary:
{summary}

Key Numbers:
- Phases: {phase_count}
- Tasks: {task_count}
- Duration: {duration}
- Team: {team_count} members

Next: Review timeline and validate estimates
```

---

## Error Handling

### Task Not Found (task number mode)

```
Error: Task {N} not found in state.json
Run /project "description" to create a new project task
```

### Task Type Mismatch

```
Error: Task {N} is not a project task (task_type: {actual_type})
Run /project with a description to create a new project task
```

### File Not Found (file path mode)

```
Error: File not found: {path}
Verify the file path and try again
```

### Project Planning Incomplete

```
Project planning incomplete for Task #{N}
Status: [{current_status}]
Resume: /project {N}
```

### No Existing Timeline (TRACK/REPORT modes)

```
Error: No existing timeline found for Task #{N}
Use PLAN mode first to create the initial timeline:
/project {N}  (select PLAN mode)
```

### User Abandons Forcing Questions (STAGE 0)

If user abandons during STAGE 0 forcing questions:
```
Project timeline task creation cancelled.

No task was created. Re-run /project with your description to start again.
```

### User Abandons Project Planning (STAGE 2)

Return partial status, task remains in [PLANNING]:
```
Project planning partially completed.

Completed: {steps_completed}/{steps_total} steps
Task: #{N} - Status: [PLANNING]

Resume: /project {N}
```

---

## Output Artifacts

### Task Workflow Mode

| Artifact | Location |
|----------|----------|
| Project timeline (PLAN) | `strategy/timelines/{project-slug}.typ` |
| Updated timeline (TRACK) | `strategy/timelines/{project-slug}.typ` |
| Status report (REPORT) | `strategy/timelines/{project-slug}-report.typ` |

**Note**: Timelines are generated in Typst format for high-quality PDF output.

### Legacy Mode (--quick)

| Artifact | Location |
|----------|----------|
| Project timeline | `strategy/timelines/{project-slug}.typ` |

---

## Workflow Summary

The standard workflow (with pre-task forcing questions):

```
/project "description" -> Asks forcing questions, creates task with data, stops at [NOT STARTED]
/research {N}          -> Routes to skill-project, creates timeline, stops at [PLANNED]
/project {N} (TRACK)   -> Updates timeline with progress, stops at [TRACKED]
/project {N} (REPORT)  -> Generates status report, stops at [REPORTED]
```

Alternative: Resume existing task:
```
/project {N}           -> Runs project planning on existing task
```

Alternative: Legacy standalone mode:
```
/project --quick PLAN  -> Creates timeline without task creation
```

---

## Examples

```bash
# Create new project task with description - asks forcing questions first
/project "Mobile App Redesign"

# Resume project planning on existing task (uses stored forcing_data)
/project 234

# Use file as context - asks forcing questions, creates task
/project ~/startup/project-brief.md

# Update progress on existing timeline
/project 234
# (select TRACK mode when prompted)

# Generate status report
/project 234
# (select REPORT mode when prompted)

# Legacy standalone mode (generates timeline immediately, no task)
/project --quick PLAN
```
