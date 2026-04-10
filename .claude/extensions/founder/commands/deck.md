---
description: Pitch deck creation with material synthesis and task integration
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: "[description]" | TASK_NUMBER | /path/to/file.md | --quick "prompt"
---

# /deck Command

Pitch deck creation command with material synthesis and task system integration.

## Overview

This command initiates pitch deck creation through structured material gathering. It asks essential questions BEFORE creating the task, storing gathered data in task metadata. After task creation, the user runs `/research`, `/plan`, and `/implement` to complete the workflow. Unlike other founder commands that use extensive forcing questions, the deck command focuses on collecting source materials for synthesis.

## Syntax

- `/deck "Seed round pitch for AI startup"` - Ask questions, create task with gathered data
- `/deck 234` - Resume research on existing task
- `/deck /path/to/context.md` - Use file as primary source material, create task
- `/deck --quick "investor pitch for NeoTex"` - Legacy: delegate to present's skill-deck for standalone generation

## Input Types

| Input | Behavior |
|-------|----------|
| Description string | Ask forcing questions, create task with forcing_data, stop at [NOT STARTED] |
| Task number | Load existing task, run research, stop at [RESEARCHED] |
| File path | Read file as primary source material, ask questions, create task |
| `--quick [args]` | Legacy standalone mode: delegate to present's skill-deck (no task creation) |

## Modes

| Mode | Posture | Focus |
|------|---------|-------|
| **INVESTOR** | Fundraising pitch | YC 10-slide format, traction emphasis, clear ask |
| **UPDATE** | Progress report | Traction, milestones, financials, runway |
| **INTERNAL** | Team alignment | Strategy, roadmap, metrics, priorities |
| **PARTNERSHIP** | Business proposal | Mutual value, problem/solution, market fit |

---

## STAGE 0: PRE-TASK FORCING QUESTIONS

**This stage runs BEFORE task creation for new tasks (description or file path input).**

**Skip this stage if**: `--quick` flag or task number input.

### Step 0.1: Deck Purpose

Use AskUserQuestion to present purpose options:

```
What is this deck for?

- INVESTOR: Fundraising pitch to investors (YC 10-slide format)
- UPDATE: Progress update for existing investors
- INTERNAL: Strategy presentation for team
- PARTNERSHIP: Business partnership proposal
```

Store response as `forcing_data.purpose`.

### Step 0.2: Source Materials

Use AskUserQuestion:

```
What materials should inform the deck content?

Provide any combination of:
- Task references (e.g., "task:234" to pull research from task 234)
- File paths to documents (e.g., "/path/to/business-plan.md")
- "none" if you will provide details in a prompt

Separate multiple entries with commas.
```

Store response as `forcing_data.source_materials` (parse into array).

### Step 0.3: Company/Project Context (conditional)

**Only ask if** forcing_data.source_materials is "none" or empty:

```
Briefly describe your company/project:
- What does it do?
- Who is it for?
- What stage are you at (pre-revenue, seed, Series A)?
```

Store response as `forcing_data.context`.

**If source materials were provided**, set `forcing_data.context` to the original description string.

### Step 0.4: Store Forcing Data

Capture all responses in a forcing_data object:
```json
{
  "purpose": "{selected_purpose}",
  "source_materials": ["{material_1}", "{material_2}"],
  "context": "{company/project description}",
  "gathered_at": "{ISO timestamp}"
}
```

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Deck] Pitch Deck Research and Generation
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
Delegate to present's skill-deck for standalone generation. Skip STAGE 0 and task creation.

```
skill: "skill-deck"
args: "{args}"
```

Skip to CHECKPOINT 2 (Legacy).

**If file path**:
```bash
# Expand path
file_path=$(eval echo "$file_path")

# Verify file exists
if [ ! -f "$file_path" ]; then
  echo "Error: File not found: $file_path"
  exit 1
fi

# Add file to source materials
description="Pitch deck from $(basename "$file_path")"
```
Then proceed to STAGE 0 for forcing questions, with file_path pre-added to source_materials.

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

# Validate language is founder and task_type is deck
task_lang=$(echo "$task_data" | jq -r '.language')
task_type=$(echo "$task_data" | jq -r '.task_type // ""')
if [ "$task_lang" != "founder" ] || [ "$task_type" != "deck" ]; then
  echo "Error: Task $task_number is not a founder:deck task (language: $task_lang, type: $task_type)"
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
slug="deck_$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

# Create task in state.json with task_type and forcing_data
jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "Pitch deck: $description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "deck" \
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

# Update TODO.md
task_number=$next_num
```

### Step 5: Update TODO.md

Add task entry to TODO.md (if new task):

```markdown
### {task_number}. Pitch deck: {description}
- **Effort**: 2-4 hours
- **Status**: [NOT STARTED]
- **Task Type**: founder
- **Type**: deck
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Forcing Data Gathered**:
- Purpose: {forcing_data.purpose}
- Source materials: {forcing_data.source_materials}
- Context: {forcing_data.context}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create deck task

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Display Task Created Summary

For new tasks (description or file path input), display summary and STOP:

```
Pitch deck task created: Task #{N}

Forcing Data Gathered:
- Purpose: {forcing_data.purpose}
- Source Materials: {forcing_data.source_materials}
- Context: {forcing_data.context}

Status: [NOT STARTED]

Next Steps:
- Run /research {N} to analyze source materials and map to slides
- Run /plan {N} to create deck implementation plan
- Run /implement {N} to generate the final Slidev pitch deck
```

**STOP HERE for new tasks.** Do not auto-invoke research.

---

## STAGE 2: DELEGATE

**Only reached when input_type is "task_number" or "--quick".**

### STAGE 2A: Legacy Mode (--quick)

**If input_type == "quick"**:

Delegate to present's skill-deck for standalone generation:

```
skill: "skill-deck"
args: "{args}"
```

Skip to CHECKPOINT 2 (Legacy).

### STAGE 2B: Task Workflow Mode (existing task)

**Run research via skill-deck-research**:

```
skill: "skill-deck-research"
args: "task_number={task_number} session_id={session_id}"
```

The skill workflow:
1. Updates status to [RESEARCHING] (preflight)
2. Invokes deck-research-agent, passing forcing_data from task metadata
3. Agent reads source materials and maps content to 10-slide structure
4. Agent asks at most 1-2 follow-up questions for critical gaps
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
     echo "Resume: /deck $task_number"
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
   Pitch deck research complete for Task #{N}

   Research Report: {research_path}

   Content Extracted:
   - Slides populated: {M}/10
   - Critical gaps: {G} identified
   - Source materials analyzed: {S}

   Status: [RESEARCHED]

   Next Steps:
   - Review research report for accuracy
   - Run /plan {N} to create deck implementation plan
   - Run /implement {N} to generate the final Slidev pitch deck
   ```

### For Legacy Mode (--quick)

```
Pitch deck generated.

Artifact: {output_path}

Summary:
{summary from skill-deck}

Next: Review and iterate on the generated deck
```

---

## Error Handling

### Task Not Found (task number mode)

```
Error: Task {N} not found in state.json
Run /deck "description" to create a new deck task
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
Resume: /deck {N}
```

### User Abandons Forcing Questions (STAGE 0)

If user abandons during STAGE 0 forcing questions:
```
Pitch deck task creation cancelled.

No task was created. Re-run /deck with your description to start again.
```

### User Abandons Research (STAGE 2)

Return partial status, task remains in [RESEARCHING]:
```
Pitch deck research partially completed.

Task: #{N} - Status: [RESEARCHING]

Resume: /deck {N}
```

---

## Output Artifacts

### Task Workflow Mode

| Artifact | Location |
|----------|----------|
| Research report | `specs/{NNN}_{SLUG}/reports/01_{short-slug}.md` |

**Note**: Final Slidev pitch deck is generated by `/implement`, not `/deck`.

### Legacy Mode (--quick)

| Artifact | Location |
|----------|----------|
| Pitch deck | Generated by present's skill-deck |

---

## Workflow Summary

The standard workflow (with pre-task forcing questions):

```
/deck "description"     -> Asks purpose/sources, creates task with data, stops at [NOT STARTED]
/research {N}           -> Uses forcing_data, synthesizes materials, stops at [RESEARCHED]
/plan {N}               -> Reads research report, creates implementation plan
/implement {N}          -> Executes plan, generates final Slidev pitch deck
```

Alternative: Resume existing task:
```
/deck {N}               -> Runs research on existing task, stops at [RESEARCHED]
```

---

## Examples

```bash
# Create new task with description - asks forcing questions first
/deck "Seed round pitch for AI-powered code editor"

# Resume research on existing task (uses stored forcing_data)
/deck 234

# Use file as primary source material - asks purpose, creates task
/deck ~/startup/business-plan.md

# Legacy standalone mode (generates deck immediately via present extension, no task)
/deck --quick "investor pitch for NeoTex AI editor"
```
