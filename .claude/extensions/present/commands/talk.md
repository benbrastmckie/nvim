---
description: Create research talk tasks with pre-task forcing questions for academic presentations
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Bash(sed:*), Read, Edit, AskUserQuestion
argument-hint: "description" | TASK_NUMBER | /path/to/file.md
model: opus
---

# /talk Command

Research presentation creation command with material synthesis and task system integration.

## Overview

This command initiates research talk creation through structured material gathering. It asks essential questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow. The command focuses on collecting source materials and presentation context for synthesis into Slidev-based research talks.

## Syntax

- `/talk "Conference talk on survival analysis methods"` - Ask questions, create task with gathered data
- `/talk 500` - Resume research on existing task
- `/talk /path/to/manuscript.md` - Use file as primary source material, create task

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, run research, stop at [RESEARCHED] |
| File path | Read file as primary source material, ask questions, create task |

## Modes

| Mode | Duration | Slides | Focus |
|------|----------|--------|-------|
| **CONFERENCE** | 15-20 min | 12-18 | Research findings, methods, impact |
| **SEMINAR** | 45-60 min | 30-45 | Deep methodology, background, discussion |
| **DEFENSE** | 30-60 min | 25-40 | Research justification, rigor, future work |
| **POSTER** | N/A | 1 large | Visual summary, methods, results |
| **JOURNAL_CLUB** | 15-30 min | 10-15 | Paper critique, key findings, discussion |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: task number input.

### Step 0.1: Talk Type

Use AskUserQuestion to present talk type options:

```
What type of talk is this?

- CONFERENCE: Research talk (15-20 min) for conference presentation
- SEMINAR: Departmental seminar (45-60 min)
- DEFENSE: Grant defense or thesis defense
- POSTER: Poster session presentation
- JOURNAL_CLUB: Paper review for journal club
```

Store response as `forcing_data.talk_type`.

### Step 0.2: Source Materials

Use AskUserQuestion:

```
What materials should inform the talk?

Provide any combination of:
- Task references (e.g., "task:500" to pull grant research)
- File paths to papers, manuscripts, data (e.g., "/path/to/manuscript.md")
- "none" if you will describe the content

Separate multiple entries with commas.
```

Store response as `forcing_data.source_materials` (parse into array).

### Step 0.3: Audience Context

Use AskUserQuestion:

```
Describe the presentation context:
- What is the research topic?
- Who is the audience? (clinicians, basic scientists, mixed)
- What is the time limit?
- Any specific emphasis? (methods, clinical implications, translational)
```

Store response as `forcing_data.audience_context`.

### Step 0.4: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "talk_type": "{selected_type}",
  "source_materials": ["{material_1}", "{material_2}"],
  "audience_context": "{audience description}",
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Talk] Research Presentation Creation
```

### Step 1: Generate Session ID

```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

### Step 2: Detect Input Type

```bash
# Check for task number
if echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then
  input_type="task_number"
  task_number="$ARGUMENTS"

# Check for file path
elif echo "$ARGUMENTS" | grep -qE '^\.|^/|^~|\.md$|\.txt$|\.tex$|\.pdf$'; then
  input_type="file_path"
  file_path="$ARGUMENTS"

# Default: treat as description for new task
else
  input_type="description"
  description="$ARGUMENTS"
fi
```

### Step 3: Handle Input Type

**If task number**:
Load existing task, validate language is "present" and task_type is "talk", then delegate to skill-talk for research.

**If file path**:
Read the file as primary source material. Run Stage 0 forcing questions (Steps 0.1-0.3) with the file content as context. Then proceed to task creation.

**If description**:
Run Stage 0 forcing questions (Steps 0.1-0.3), then proceed to task creation.

---

## STAGE 1: TASK CREATION

**This stage runs for new tasks only (description or file path input).**

### Step 1: Read next_project_number

```bash
next_num=$(jq -r '.next_project_number' specs/state.json)
```

### Step 2: Create slug from description

- Lowercase, replace spaces with underscores
- Remove special characters
- Max 50 characters

### Step 3: Update state.json

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg desc "$description" \
  --argjson forcing "$forcing_data_json" \
  '.next_project_number = ($next_num + 1) |
   .active_projects = [{
     "project_number": $next_num,
     "project_name": "slug",
     "status": "not_started",
     "language": "present",
     "task_type": "talk",
     "description": $desc,
     "forcing_data": $forcing,
     "created": $ts,
     "last_updated": $ts
   }] + .active_projects' \
  specs/state.json > specs/tmp/state.json && \
  mv specs/tmp/state.json specs/state.json
```

### Step 4: Update TODO.md

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
- **Language**: present

**Description**: {description}
```

### Step 5: Git commit

```bash
git add specs/
git commit -m "task {N}: create {title}

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

### Step 6: Output

```
Talk task #{N} created: {TITLE}
Status: [NOT STARTED]
Language: present
Talk Type: {talk_type}
Artifacts path: specs/{NNN}_{SLUG}/ (created on first artifact)

Recommended workflow:
1. /research {N} - Synthesize source materials into slide-mapped report
2. /plan {N} - Create implementation plan
3. /implement {N} - Generate Slidev presentation to talks/{N}_{slug}/
```

---

## STAGE 2: RESEARCH DELEGATION (task number input only)

When input is a task number, delegate to skill-talk for research.

### Step 1: Validate Task

```bash
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
# Validate language is "present"
# Validate task_type is "talk"
# Validate status allows research (not_started or researched for re-research)
```

### Step 2: Delegate

**Invoke Skill tool**:
```
skill: "skill-talk"
args: "task_number={N} session_id={session_id}"
```

### Step 3: Gate Out

Verify research completed:
- Check status updated to "researched" in state.json
- Check for report artifact in specs/{NNN}_{SLUG}/reports/

**On success, output**:
```
Talk research completed for Task #{N}
Status: [RESEARCHED]
Report: specs/{NNN}_{SLUG}/reports/{MM}_talk-research.md

Next: /plan {N}
```

---

## Core Command Integration

Tasks with language="present" and task_type="talk" route through core commands:

| Command | Routes To | Purpose |
|---------|-----------|---------|
| `/research N` | skill-talk | Synthesize materials into slide-mapped report |
| `/plan N` | skill-planner | Create implementation plan |
| `/implement N` | skill-talk (assemble) | Generate Slidev presentation |

---

## Error Handling

### Task Creation Errors
- Invalid description: Return guidance on expected format
- State update failure: Log error, do not commit partial state

### Research Errors
- Task not found: Return error with guidance to create task first
- Wrong language/task_type: Return error suggesting /talk for talk tasks
- Invalid status: Return error with current status and valid transitions

### Git Commit Failure
- Non-blocking: Log failure but continue with success response
- Report to user that manual commit may be needed

---

## Output Formats

### Task Creation Success
```
Talk task #{N} created: {TITLE}
Status: [NOT STARTED]
Language: present
Talk Type: {talk_type}

Recommended workflow:
1. /research {N} - Synthesize source materials
2. /plan {N} - Create implementation plan
3. /implement {N} - Generate Slidev presentation
```

### Research Success
```
Talk research completed for Task #{N}
Report: specs/{NNN}_{SLUG}/reports/{MM}_talk-research.md
Status: [RESEARCHED]
Next: /plan {N}
```

### Error Output
```
Talk command error:
- {error description}
- {recovery guidance}
```
