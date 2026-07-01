---
description: Vet completed CSLib tasks against library standards (CONTRIBUTING.md, NOTATION.md, ORGANISATION.md, CODE_OF_CONDUCT.md), run the CI pipeline, and create fix tasks for violations found.
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: "<task_number[,task_number-task_number...]> [focus_prompt]"
---

# /vet Command

Quality-gate command for CSLib tasks. Vets completed (or in-progress) CSLib implementations
against all four standards documents, runs the CI verification pipeline, and creates scoped fix
tasks for violations found — with user confirmation before any task creation.

## Syntax

```
/vet <task_numbers> [focus_prompt]
```

## Examples

| Invocation | Behavior |
|------------|----------|
| `/vet 265` | Vet single task |
| `/vet 260,262,265` | Vet three specific tasks |
| `/vet 258-262` | Vet a range of tasks |
| `/vet 265 "focus on notation consistency"` | Vet with a focus prompt |

## Execution

**EXECUTE NOW**: Follow all steps in sequence. Do not stop between steps unless instructed.

---

### STEP 1: Parse Arguments

**EXECUTE NOW**: Parse `$ARGUMENTS` to extract task numbers and optional focus prompt.

```bash
cd /home/benjamin/Projects/cslib

# Source the parser to populate TASK_NUMBERS and FOCUS_PROMPT
source .claude/scripts/parse-command-args.sh "$ARGUMENTS"
# TASK_NUMBERS: space-separated list (ranges already expanded)
# FOCUS_PROMPT: remaining text after flags/task numbers stripped

echo "Task numbers: $TASK_NUMBERS"
echo "Focus prompt: $FOCUS_PROMPT"
```

If `parse-command-args.sh` returns non-zero (no task numbers found), display:

```
Usage: /vet <task_numbers> [focus_prompt]

Examples:
  /vet 265
  /vet 260,262,265
  /vet 258-262
  /vet 265 "focus on notation consistency"
```

Then **STOP**.

**On success**: **IMMEDIATELY CONTINUE** to STEP 2.

---

### STEP 2: Validate Tasks

**EXECUTE NOW**: For each task number in `$TASK_NUMBERS`, verify the task exists in state.json.

```bash
cd /home/benjamin/Projects/cslib
CSLIB_STATE="specs/state.json"

VALID_TASKS=""
for task_num in $TASK_NUMBERS; do
  task_name=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num) | .project_name' \
    "$CSLIB_STATE" 2>/dev/null)
  task_type=$(jq -r --argjson num "$task_num" \
    '.active_projects[] | select(.project_number == $num) | .task_type' \
    "$CSLIB_STATE" 2>/dev/null)

  if [ -z "$task_name" ] || [ "$task_name" = "null" ]; then
    echo "Warning: Task $task_num not found in state.json — skipping."
    continue
  fi

  echo "Task $task_num: $task_name (type: $task_type)"
  VALID_TASKS="$VALID_TASKS $task_num"
done

VALID_TASKS=$(echo "$VALID_TASKS" | xargs)  # trim whitespace

if [ -z "$VALID_TASKS" ]; then
  echo "Error: No valid tasks found in: $TASK_NUMBERS"
  echo "Run /task to view your task list."
  # STOP
fi

echo "Valid tasks to vet: $VALID_TASKS"
```

Display a summary of the tasks to be vetted:

```
Tasks to Vet
============
{For each valid task: "  #{N}: {task_name} ({task_type})"}

Focus: {FOCUS_PROMPT or "(none)"}

Standards to check:
  - CONTRIBUTING.md (proof style, notation, documentation, CI compliance)
  - NOTATION.md (arrow notation, bisimilarity, transitions)
  - ORGANISATION.md (directory placement, namespace conventions)
  - CODE_OF_CONDUCT.md (community guidelines)
```

**On success**: **IMMEDIATELY CONTINUE** to STEP 3.

---

### STEP 3: Delegate to skill-cslib-vet

**EXECUTE NOW**: Invoke the `skill-cslib-vet` skill to perform the vetting workflow.

Generate a session ID for this operation:

```bash
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

Invoke the skill by calling the Skill tool with `skill-cslib-vet` and passing:
- `task_numbers`: The space-separated list from `$VALID_TASKS`
- `focus_prompt`: The optional focus prompt from `$FOCUS_PROMPT`
- `session_id`: Generated above
- `cslib_dir`: `/home/benjamin/Projects/cslib`

The skill will:
1. Identify Lean files changed by each task via git history
2. Prepare the full delegation context (standards paths, changed files, metadata)
3. Invoke `cslib-vet-agent` to read files, run CI, and analyze against all standards
4. Present violations to the user for interactive selection
5. Create fix tasks for selected violations with confirmation
6. Commit any new fix tasks and return a summary

**STOP** — the skill handles all remaining workflow steps.

---

## Error Recovery

### No Changed Files Found

If no Lean files are found in git history for a task:
```
Warning: No Lean files found in git history for task #{N}.
The vet agent will check uncommitted changes and task artifact paths instead.
```

This is non-fatal — the agent checks uncommitted changes as a fallback.

### No Violations Found

If the agent finds no standards violations and CI passes:
```
Vet complete: No violations found for task #{N}.
CI pipeline passed. Task meets all CSLib standards.
```

### CI Failure

If CI fails during vetting, the agent classifies it as a Critical violation and creates a fix
task for it after user confirmation.

### User Selects No Issues

If the user deselects all issues at the confirmation step, no fix tasks are created and the
command exits gracefully.
