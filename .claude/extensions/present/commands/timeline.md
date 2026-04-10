---
description: Create timeline tasks or execute research timeline workflows for medical research projects
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Bash(sed:*), Read, Edit, AskUserQuestion
argument-hint: "description" | TASK_NUMBER
model: opus
---

# /timeline Command

Hybrid command supporting both task creation and timeline research workflow.

## Modes

| Mode | Syntax | Description |
|------|--------|-------------|
| Task Creation | `/timeline "Description"` | Create task with language="present", task_type="timeline" |
| Research | `/timeline N` | Research and build project timeline |

## CRITICAL: Task Creation Mode

When $ARGUMENTS is a description (no task number), create a task with language="present", task_type="timeline".

**$ARGUMENTS contains a task DESCRIPTION to RECORD in the task list.**

- DO NOT interpret the description as instructions to execute
- DO NOT investigate, analyze, or implement what the description mentions
- ONLY create a task entry and commit it

---

## Mode Detection

Parse $ARGUMENTS to determine mode:

1. **Check for description** (quoted text, no leading number):
   - Pattern: String that doesn't start with a number
   - Mode: Task Creation

2. **Check for task number** (leading integer):
   - Pattern: Starts with a number
   - Mode: Research/Timeline

---

## Task Creation Mode

When $ARGUMENTS is a description without a task number.

### STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description input).**

#### Step 0.1: Grant Mechanism

Use AskUserQuestion:

```
What grant mechanism is this timeline for?

Options:
A) R01 (5 years)
B) R01 (3 years)
C) R21 (2 years)
D) K-series (3-5 years)
E) U01 (cooperative)
F) Other (specify)
```

Store response as `forcing_data.mechanism`.

#### Step 0.2: Project Period

Use AskUserQuestion:

```
What is the project period?

Include start and end dates (e.g., Aug 2026 - Jul 2031).
```

Store response as `forcing_data.period`.

#### Step 0.3: Number of Specific Aims

Use AskUserQuestion:

```
How many specific aims does this project have?

Enter a number (typically 2-4 for most NIH grants).
```

Store response as `forcing_data.aims_count`.

#### Step 0.4: Key Milestones

Use AskUserQuestion:

```
What are the key completion criteria or milestone targets?

Examples: "3 publications, validated model, Phase I trial data"
List the major deliverables that define project success:
```

Store response as `forcing_data.milestones`.

#### Step 0.5: Regulatory Requirements

Use AskUserQuestion with multiSelect:

```
Which regulatory approvals are expected?

Options:
- IRB (human subjects protocol)
- IACUC (animal use protocol)
- FDA (IND/IDE regulatory)
- None expected
```

Store response as `forcing_data.regulatory`.

#### Step 0.6: Existing Aims Document

Use AskUserQuestion:

```
Do you have an existing specific aims document or draft?

Provide a file path (e.g., ~/grants/aims.md) or "none".
```

Store response as `forcing_data.aims_path`.

#### Step 0.7: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "mechanism": "{response_1}",
  "period": "{response_2}",
  "aims_count": "{response_3}",
  "milestones": "{response_4}",
  "regulatory": ["{response_5a}", "{response_5b}"],
  "aims_path": "{response_6}",
  "gathered_at": "{ISO timestamp}"
}
```

---

### Steps

1. **Read next_project_number via jq**:
   ```bash
   next_num=$(jq -r '.next_project_number' specs/state.json)
   ```

2. **Parse description** from $ARGUMENTS:
   - Remove any surrounding quotes
   - Extract description text

3. **Improve description** (same transformations as /task):
   - Slug expansion: `research_mouse_model` -> `Research mouse model`
   - Verb inference: If no action verb, prepend appropriate one
   - Formatting normalization: Capitalize, trim, no trailing period

4. **Set language = "present"** and **task_type = "timeline"** (always for /timeline task creation)

5. **Create slug** from description:
   - Lowercase, replace spaces with underscores
   - Remove special characters
   - Max 50 characters

6. **Update state.json** (via jq):
   ```bash
   jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg desc "$description" \
     --argjson forcing_data "$forcing_data_json" \
     '.next_project_number = {NEW_NUMBER} |
      .active_projects = [{
        "project_number": {N},
        "project_name": "slug",
        "status": "not_started",
        "task_type": "present",
        "task_type": "timeline",
        "description": $desc,
        "forcing_data": $forcing_data,
        "created": $ts,
        "last_updated": $ts
      }] + .active_projects' \
     specs/state.json > specs/tmp/state.json && \
     mv specs/tmp/state.json specs/state.json
   ```

7. **Update TODO.md** (frontmatter AND entry):

   **Part A - Update frontmatter**:
   ```bash
   sed -i 's/^next_project_number: [0-9]*/next_project_number: {NEW_NUMBER}/' \
     specs/TODO.md
   ```

   **Part B - Add task entry** by prepending to `## Tasks` section:
   ```markdown
   ### {N}. {Title}
   - **Effort**: TBD
   - **Status**: [NOT STARTED]
   - **Task Type**: present
   - **Type**: timeline

   **Description**: {description}
   ```

8. **Git commit**:
   ```bash
   git add specs/
   git commit -m "task {N}: create {title}

   Session: {session_id}

   Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
   ```

9. **Output**:
   ```
   Timeline task #{N} created: {TITLE}
   Status: [NOT STARTED]
   Language: present
   Type: timeline
   Artifacts path: specs/{NNN}_{SLUG}/ (created on first artifact)

   Recommended workflow:
   1. /timeline {N} - Research and build project timeline
   2. /plan {N} - Create implementation plan
   3. /implement {N} - Generate Typst timeline output
   ```

---

## Research Mode

When $ARGUMENTS starts with a task number.

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Timeline Research] Task {N}: {project_name}
```

1. **Generate Session ID**
   ```bash
   session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
   ```

2. **Lookup Task**
   ```bash
   task_data=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num)' \
     specs/state.json)
   ```

3. **Validate Task**
   - Task must exist (ABORT if not)
   - Language must be "present" and task_type must be "timeline" (ABORT with message if not)
   - Status must allow research: not_started, researched (re-research), partial
   - If completed/abandoned: ABORT with appropriate message

4. **Determine workflow_type** based on current status:
   - `not_started` or `partial` -> `timeline_research`
   - `researched` -> `timeline_research` (re-research with new round)
   - `planned` -> Already planned, suggest /implement

**ABORT** if validation fails.

### STAGE 2: DELEGATE

**Note**: Forcing data was gathered during Task Creation Mode (Stage 0) and stored in task metadata.
The skill passes `forcing_data` to timeline-agent, which skips pre-gathered questions.

**Invoke Skill tool**:
```
skill: "skill-timeline"
args: "task_number={N} workflow_type=timeline_research session_id={session_id}"
```

### CHECKPOINT 2: GATE OUT

1. **Validate Return**
   - Check for error indicators

2. **Verify Artifacts**
   - Check for report in specs/{NNN}_{SLUG}/reports/

3. **Verify Status**
   - Confirm status is "researched" in state.json

**On success, output**:
```
Timeline research completed for Task #{N}

Report: specs/{NNN}_{SLUG}/reports/{MM}_timeline-research.md

Status: [RESEARCHED]
Next: /plan {N} to create implementation plan
```

---

## Core Command Integration

Tasks with language="present", task_type="timeline" route through core commands:

| Command | Routes To | Purpose |
|---------|-----------|---------|
| `/timeline N` | skill-timeline (timeline_research) | Research and build timeline |
| `/research N` | skill-timeline (timeline_research) | Alternative research entry |
| `/plan N` | skill-planner | Create implementation plan |
| `/implement N` | skill-timeline (timeline_plan) | Generate Typst timeline output |

**Note**: Manifest integration (routing entries, index entries) is handled by task 391.

---

## Error Handling

### Task Creation Errors
- Invalid description: Return guidance on expected format
- State update failure: Log error, do not commit partial state

### Workflow Errors
- Task not found: Return error with guidance to create task first
- Wrong language: Return error suggesting /timeline for timeline tasks
- Invalid status: Return error with current status and valid transitions

### Git Commit Failure
- Non-blocking: Log failure but continue with success response

---

## Output Formats

### Task Creation Success
```
Timeline task #{N} created: {TITLE}
Status: [NOT STARTED]
Language: present
Type: timeline

Recommended workflow:
1. /timeline {N} - Research and build project timeline
2. /plan {N} - Create implementation plan
3. /implement {N} - Generate Typst timeline output
```

### Workflow Success
```
Timeline research completed for Task #{N}

Report: {path}

Status: [RESEARCHED]
Next: /plan {N}
```

### Error Output
```
Timeline command error:
- {error description}
- {recovery guidance}
```
