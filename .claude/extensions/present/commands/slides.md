---
description: Create research talk tasks with pre-task forcing questions for academic presentations
allowed-tools: Skill, Task, Bash(jq:*), Bash(git:*), Bash(date:*), Bash(sed:*), Read, Edit, AskUserQuestion
argument-hint: "description" | TASK_NUMBER | /path/to/file.md | TASK_NUMBER --critic [/path | prompt] | --critic /path/to/file
model: opus
---

# /slides Command

Research presentation creation command with material synthesis and task system integration.

## Overview

This command initiates research talk creation through structured material gathering. It asks essential questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow. The command focuses on collecting source materials and presentation context for synthesis into research talks. Output format is user-selectable: Slidev (default) or PowerPoint (PPTX).

## Syntax

- `/slides "Conference talk on survival analysis methods"` - Ask questions, create task with gathered data
- `/slides 500` - Resume research on existing task
- `/slides /path/to/manuscript.md` - Use file as primary source material, create task
- `/slides N --critic` - Critique existing task's slide materials
- `/slides N --critic /path/to/rubric.md` - Critique with custom rubric file
- `/slides N --critic "Focus on narrative flow"` - Critique with focus prompt
- `/slides --critic /path/to/slides.md` - Critique a standalone file (no task)

**Note**: This command was previously named `/talk`. For PPTX slide file conversion (not research talk creation), use `/convert --format beamer|polylux|touying` in the `filetypes` extension.

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, run research, stop at [RESEARCHED] |
| File path | Read file as primary source material, ask questions, create task |
| `N --critic [path\|prompt]` | Route to skill-slide-critic for interactive critique loop |
| `--critic /path/to/file` | Read file, create temporary context, route to skill-slide-critic |

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

### Step 0.0: Output Format

Use AskUserQuestion to present output format options:

```
What output format do you want for the presentation?

- SLIDEV (default): Slidev markdown-based slides
- PPTX: PowerPoint presentation file
```

Store response as `forcing_data.output_format`. If the user does not specify or is ambiguous, default to `"slidev"`.

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
  "output_format": "{selected_format}",
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
# Check for --critic flag (before other checks, following grant.md flag-first pattern)
if echo "$ARGUMENTS" | grep -q '\-\-critic'; then
  # Extract task number before --critic (if present)
  task_number=$(echo "$ARGUMENTS" | grep -oE '^[0-9]+' || echo "")

  # Extract critic input after --critic
  critic_input=$(echo "$ARGUMENTS" | sed 's/.*--critic\s*//')

  if [ -n "$critic_input" ]; then
    # Detect if it's a file path or prompt text
    if echo "$critic_input" | grep -qE '^\.|^/|^~|\.md$|\.txt$'; then
      critic_type="file_path"
      critic_file="$critic_input"
    elif echo "$critic_input" | grep -qE '^[0-9]+$'; then
      critic_type="task_number"
      critic_task="$critic_input"
    else
      critic_type="prompt"
      critic_prompt="$critic_input"
    fi
  fi

  input_type="critic"

# Check for task number
elif echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then
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

**If critic** (`input_type="critic"`):
Skip Stage 0 forcing questions. Route directly to critique workflow:

1. **Validate task** (if `task_number` is set):
   ```bash
   task_data=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num)' \
     specs/state.json)
   # Validate task_type is "present:slides"
   ```

2. **Build delegation context** for skill-slide-critic:
   - `workflow_type`: `"slides_critique"`
   - `forcing_data.talk_type`: from task's forcing_data (or default "CONFERENCE")
   - `forcing_data.materials_to_review`: task's existing reports/plans/slides, or `critic_file`
   - `forcing_data.focus_categories`: parsed from `critic_prompt` if provided
   - `forcing_data.audience_context`: from task's forcing_data if available

3. **Delegate** to skill-slide-critic:
   ```
   Skill("skill-slide-critic", "task_number={N} session_id={session_id}")
   ```

4. **Gate Out**: Verify critique completed, report results.

**If task number**:
Load existing task, validate task_type is "present:slides", then delegate to skill-slides for research.

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

### Step 2.5: Enrich Description

Construct an enriched description incorporating forcing data:

1. Start with the base description:
   - If `input_type="description"`: use the user's original text
   - If `input_type="file_path"`: synthesize from file content (first heading or basename) and audience_context

2. Append talk type, duration, and output format in parentheses.

3. The enriched description replaces `$desc` for both state.json and TODO.md.

**Target format**:
```
{base_description} ({talk_type} talk, {duration}, {output_format})
```

```bash
# Example enrichment
enriched_description="${description} (${talk_type} talk, ${duration}, ${output_format})"
```

### Step 3: Update state.json

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg desc "$enriched_description" \
  --argjson forcing "$forcing_data_json" \
  '.next_project_number = ($next_num + 1) |
   .active_projects = [{
     "project_number": $next_num,
     "project_name": "slug",
     "status": "not_started",
     "task_type": "present:slides",
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
- **Task Type**: present:slides

**Description**: {enriched_description}

**Sources**:
- {full_absolute_path_1}
- {full_absolute_path_2}
- task:{N} (for task references)

**Forcing Data Gathered**:
- Output format: {forcing_data.output_format}
- Talk type: {forcing_data.talk_type}
- Source materials: {forcing_data.source_materials}
- Audience context: {forcing_data.audience_context}
```

### Step 5: Git commit

```bash
git add specs/
git commit -m "task {N}: create {title}

Session: {session_id}
```

### Step 6: Output

```
Talk task #{N} created: {TITLE}
Status: [NOT STARTED]
Task Type: present
Talk Type: {talk_type}
Output Format: {output_format}
Artifacts path: specs/{NNN}_{SLUG}/ (created on first artifact)

Forcing Data Gathered:
- Output format: {forcing_data.output_format}
- Talk type: {forcing_data.talk_type}
- Source materials: {forcing_data.source_materials}
- Audience context: {forcing_data.audience_context}

Recommended workflow:
1. /research {N} - Synthesize source materials into slide-mapped report
2. /plan {N} - Create implementation plan
3. /implement {N} - Generate {output_format} presentation to talks/{N}_{slug}/
```

---

## STAGE 2: RESEARCH DELEGATION (task number input only)

When input is a task number, delegate to skill-slides for research.

### Step 1: Validate Task

```bash
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
# Validate task_type is "present:slides"
# Validate status allows research (not_started or researched for re-research)
```

### Step 2: Delegate

**Invoke Skill tool**:
```
skill: "skill-slides"
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
Report: specs/{NNN}_{SLUG}/reports/{MM}_slides-research.md

Next: /plan {N} (create implementation plan with design questions)
```

## Core Command Integration

Tasks with task_type="present:slides" route through core commands:

| Command | Routes To | Purpose |
|---------|-----------|---------|
| `/research N` | skill-slides | Synthesize materials into slide-mapped report |
| `/plan N` | skill-slides (plan workflow) | Ask design questions, then delegate to planner-agent |
| `/implement N` | skill-slides (assemble) | Generate presentation (Slidev or PPTX per output_format) |
| `/slides N --critic` | skill-slide-critic | Interactive critique loop with accept/reject decisions |

---

## Error Handling

### Task Creation Errors
- Invalid description: Return guidance on expected format
- State update failure: Log error, do not commit partial state

### Research Errors
- Task not found: Return error with guidance to create task first
- Wrong language/task_type: Return error suggesting /slides for slides tasks
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
Task Type: present
Talk Type: {talk_type}
Output Format: {output_format}

Forcing Data Gathered:
- Output format: {forcing_data.output_format}
- Talk type: {forcing_data.talk_type}
- Source materials: {forcing_data.source_materials}
- Audience context: {forcing_data.audience_context}

Recommended workflow:
1. /research {N} - Synthesize source materials
2. /plan {N} - Create implementation plan
3. /implement {N} - Generate {output_format} presentation
```

### Research Success
```
Talk research completed for Task #{N}
Report: specs/{NNN}_{SLUG}/reports/{MM}_slides-research.md
Status: [RESEARCHED]
Next: /plan {N}
```

### Error Output
```
Talk command error:
- {error description}
- {recovery guidance}
```
