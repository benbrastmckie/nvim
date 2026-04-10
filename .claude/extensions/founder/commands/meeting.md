---
description: Investor meeting note processing with web research and CSV tracking
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Bash(date:*), Read, Edit, AskUserQuestion
argument-hint: /path/to/notes.md | TASK_NUMBER | --update /path/to/meeting-file.md
---

# /meeting Command

Process investor meeting notes into structured meeting files with YAML frontmatter, formatted analysis, and CSV tracker updates.

## Overview

This command transforms raw meeting notes into comprehensive investor profiles. Unlike other founder commands that use forcing questions, `/meeting` takes a file path directly and processes autonomously using web research to enrich the investor profile.

## Syntax

- `/meeting /path/to/notes.md` - Process notes into structured meeting file + update CSV
- `/meeting 382` - Resume processing on existing task
- `/meeting --update /path/to/meeting-file.md` - Update CSV from existing structured meeting file

## Input Types

| Input | Behavior |
|-------|----------|
| File path | Create task with notes_path, immediately delegate to skill-meeting |
| Task number | Load existing task, run research via skill-meeting |
| `--update /path` | Create task with update_only=true, delegate for CSV-only sync |

---

## CHECKPOINT 1: GATE IN

**Display header**:
```
[Meeting] Investor Meeting Note Processing
```

### Step 1: Generate Session ID

```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

### Step 2: Detect Input Type

```bash
# Check for --update flag
if echo "$ARGUMENTS" | grep -qE '^--update'; then
  input_type="update"
  # Extract file path after --update
  file_path=$(echo "$ARGUMENTS" | sed 's/^--update *//')

# Check for task number
elif echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then
  input_type="task_number"
  task_number="$ARGUMENTS"

# Default: treat as file path
else
  input_type="file_path"
  file_path="$ARGUMENTS"
fi
```

### Step 3: Handle Input Type

**If file path (new meeting notes)**:
```bash
# Expand path
file_path=$(eval echo "$file_path")

# Verify file exists
if [ ! -f "$file_path" ]; then
  echo "Error: File not found: $file_path"
  exit 1
fi

# Extract investor hint from filename or content
filename=$(basename "$file_path" | sed 's/\.[^.]*$//')
description="Investor meeting: $filename"
update_only=false
```
Proceed to Step 4 (Create Task).

**If --update (CSV sync from existing meeting file)**:
```bash
# Expand path
file_path=$(eval echo "$file_path")

# Verify file exists
if [ ! -f "$file_path" ]; then
  echo "Error: File not found: $file_path"
  exit 1
fi

# Verify YAML frontmatter exists
if ! head -1 "$file_path" | grep -q '^---'; then
  echo "Error: File does not have YAML frontmatter: $file_path"
  echo "The --update flag requires a structured meeting file, not raw notes."
  exit 1
fi

filename=$(basename "$file_path" | sed 's/\.[^.]*$//')
description="CSV update: $filename"
update_only=true
```
Proceed to Step 4 (Create Task).

**If task number (resume)**:
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
if [ "$task_lang" = "founder" | not ]; then
  echo "Error: Task $task_number is not a founder task (language: $task_lang)"
  exit 1
fi

# Extract stored notes_path and update_only
file_path=$(echo "$task_data" | jq -r '.notes_path // ""')
update_only=$(echo "$task_data" | jq -r '.update_only // false')
```
Skip to STAGE 2 (Delegate).

### Step 4: Create Task

Skip if task_number already exists.

```bash
# Get next task number
next_num=$(jq -r '.next_project_number' specs/state.json)

# Create slug from description
slug="meeting_$(echo "$description" | tr ' ' '_' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_]//g' | cut -c1-40)"

# Create task in state.json with notes_path stored for resume
jq --argjson num "$next_num" \
   --arg name "$slug" \
   --arg desc "$description" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg task_type "meeting" \
   --arg notes "$file_path" \
   --argjson update "$update_only" \
   '. + {next_project_number: ($num + 1)} |
    .active_projects += [{
      project_number: $num,
      project_name: $name,
      status: "not_started",
      task_type: "founder",
      task_type: $task_type,
      description: $desc,
      notes_path: $notes,
      update_only: $update,
      created: $ts,
      artifacts: []
    }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Update TODO.md
task_number=$next_num
```

### Step 5: Update TODO.md

Add task entry to TODO.md (if new task):

```markdown
### {task_number}. {description}
- **Effort**: 1-2 hours
- **Status**: [NOT STARTED]
- **Task Type**: founder
- **Type**: meeting
- **Dependencies**: None
- **Started**: {ISO timestamp}

**Description**: {full description}

**Input**: `{file_path}`
**Mode**: {full processing|CSV update only}
```

### Step 6: Git Commit (Task Creation)

```bash
git add specs/state.json specs/TODO.md
git commit -m "$(cat <<'EOF'
task {N}: create meeting processing task

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Step 7: Proceed to Delegation

**Unlike other founder commands, /meeting proceeds directly to delegation after task creation.**
There are no forcing questions to gather -- the file IS the input.

---

## STAGE 2: DELEGATE

Invoke skill-meeting to process the meeting notes:

```
skill: "skill-meeting"
args: "task_number={task_number} notes_path={file_path} update_only={update_only} session_id={session_id}"
```

The skill workflow:
1. Updates status to [RESEARCHING] (preflight)
2. Invokes meeting-agent with notes_path and update_only
3. Agent reads notes, web-researches investor, generates structured file, updates CSV
4. Updates status to [RESEARCHED] (postflight)
5. Links artifact and commits

---

## CHECKPOINT 2: GATE OUT

1. **Verify Research Completed**
   ```bash
   status=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .status' \
     specs/state.json)

   if [ "$status" = "researched" | not ]; then
     echo "Processing incomplete. Status: [$status]"
     echo "Resume: /meeting $task_number"
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

   **For full processing mode**:
   ```
   Meeting notes processed: Task #{N}

   Investor: {investor_name}
   Meeting Date: {meeting_date}
   Meeting File: {output_path}
   Action Items: {count}
   CSV Tracker: {updated|created}

   Status: [RESEARCHED]

   Next Steps:
   - Review meeting file for accuracy (verify web-researched data)
   - Run /plan {N} if further analysis is needed
   - Run /meeting --update {output_path} to re-sync CSV after manual edits
   ```

   **For --update mode**:
   ```
   CSV updated: Task #{N}

   Source File: {file_path}
   Investor: {investor_name}
   CSV Tracker: Updated

   Status: [RESEARCHED]
   ```

---

## Error Handling

### File Not Found

```
Error: File not found: {path}
Verify the file path and try again.
```

### Task Not Found (task number mode)

```
Error: Task {N} not found in state.json
Run /meeting /path/to/notes.md to create a new task.
```

### No YAML Frontmatter (--update mode)

```
Error: File does not have YAML frontmatter: {path}
The --update flag requires a structured meeting file, not raw notes.
Use /meeting {path} to process raw notes first.
```

### Processing Incomplete

```
Processing incomplete for Task #{N}
Status: [{current_status}]
Resume: /meeting {N}
```

---

## Output Artifacts

| Mode | Artifact | Location |
|------|----------|----------|
| Full processing | Structured meeting file | Same directory as input (YYYY-MM-DD_slug.md) |
| Full processing | CSV tracker update | Same directory (*.csv) |
| --update | CSV tracker update | Same directory (*.csv) |

---

## Workflow Summary

```
/meeting /path/to/notes.md           -> Create task, process notes, generate meeting file + CSV
/meeting --update /path/to/file.md   -> Create task, re-sync CSV from existing meeting file
/meeting {N}                         -> Resume processing on existing task
```

---

## Examples

```bash
# Process raw meeting notes into structured file
/meeting ~/Projects/Logos/Vision/investors/VC/halcyon-notes.md

# Update CSV after manually editing a meeting file
/meeting --update ~/Projects/Logos/Vision/investors/VC/2026-04-07_halcyon.md

# Resume processing on an existing task
/meeting 382
```
