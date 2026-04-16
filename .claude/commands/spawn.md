---
description: Spawn new tasks to unblock a blocked task
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit
argument-hint: TASK_NUMBER [blocker description]
model: opus
---

# /spawn Command

Recover from blocked implementations by analyzing the blocker, decomposing it into minimal new tasks, and establishing proper dependency relationships.

## Arguments

- `$1` - Task number (required)
- `$2...` - Optional blocker description (free text)

## Syntax

```
/spawn N [blocker description]
```

**Examples**:
- `/spawn 241` - Analyze task 241's blocker automatically
- `/spawn 241 missing state validation utilities` - Analyze with explicit blocker context

## Execution

### CHECKPOINT 1: GATE IN

**Display header**:
```
[Spawning] Task {N}: {project_name}
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

3. **Validate Task Exists**
   If task not found: **ABORT** with error message:
   ```
   Error: Task {N} not found in state.json.
   Run /task --sync to reconcile state.
   ```

4. **Validate Status Allows Spawn**
   Extract status and validate:
   ```bash
   status=$(echo "$task_data" | jq -r '.status')
   ```

   | Status | Action |
   |--------|--------|
   | `implementing`, `partial`, `blocked` | ALLOW - task is stuck |
   | `planned`, `researched` | ALLOW - preemptive spawn |
   | `completed` | ABORT "Task is already complete. Nothing to spawn." |
   | `abandoned` | ABORT "Task is abandoned. Recover it first with /task --recover {N}." |
   | `not_started` | ALLOW - may have discovered blocker before starting |
   | `researching`, `planning` | ABORT "Task in progress. Wait for current phase to complete." |

5. **Extract Task Context**
   ```bash
   project_name=$(echo "$task_data" | jq -r '.project_name')
   task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
   description=$(echo "$task_data" | jq -r '.description // ""')
   ```

6. **Extract Blocker Prompt**
   Parse arguments to extract optional blocker description:
   ```bash
   # $1 is task number, rest is blocker prompt
   blocker_prompt=""
   if [ $# -gt 1 ]; then
     shift
     blocker_prompt="$*"
   fi
   ```

7. **Load Task Context**
   Find latest plan from task directory:
   ```bash
   padded_num=$(printf "%03d" "$task_number")
   plan_path=""
   if [ -d "specs/${padded_num}_${project_name}/plans" ]; then
     plan_path=$(ls -t "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | head -1)
   fi
   ```

**ABORT** if any validation fails.

**On GATE IN success**: Task validated. **IMMEDIATELY CONTINUE** to STAGE 2 below.

---

### STAGE 2: DELEGATE

**EXECUTE NOW**: After GATE IN completes, immediately invoke the Skill tool.

**Invoke the Skill tool NOW** with:
```
skill: "skill-spawn"
args: "task_number={N} session_id={session_id} blocker_prompt={blocker_prompt}"
```

The skill will:
1. Update parent task status to [BLOCKED]
2. Invoke spawn-agent for blocker analysis
3. Read agent's spawn return file
4. Create new task directories
5. Update state.json with new tasks (including parent_task and dependencies)
6. Update TODO.md with new task entries
7. Update parent task dependencies
8. Git commit all changes

**On DELEGATE success**: Tasks created. **IMMEDIATELY CONTINUE** to CHECKPOINT 2 below.

---

### CHECKPOINT 2: GATE OUT

1. **Verify State Updated**
   Confirm parent task status is now "blocked" in state.json:
   ```bash
   new_status=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .status' \
     specs/state.json)
   [ "$new_status" = "blocked" ] || echo "Warning: Parent status not updated"
   ```

2. **Verify New Tasks Created**
   Check that new tasks exist in state.json:
   ```bash
   # Get parent task's dependencies (these are the spawned tasks)
   spawned_tasks=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .dependencies // []' \
     specs/state.json)
   spawned_count=$(echo "$spawned_tasks" | jq 'length')
   ```

3. **Validate Artifacts**
   Check spawn analysis report exists:
   ```bash
   report_path="specs/${padded_num}_${project_name}/reports/02_spawn-analysis.md"
   [ -f "$report_path" ] || echo "Warning: Spawn analysis report not found"
   ```

**RETRY** skill if validation fails.

**On GATE OUT success**: Spawn complete. **IMMEDIATELY CONTINUE** to Output below.

---

### Note: Commit Handled by Skill

The skill handles git commit internally during postflight (Stage 15).
The command does not need to commit separately.

---

## Output

Display summary of spawned tasks and next steps:

```
Spawned {M} tasks to unblock Task #{N}

Parent Task: #{N} - {project_name} [BLOCKED]
  Now depends on: Task #{X}, Task #{Y}

Spawned Tasks:
  #{X}: {title} [RESEARCHED]
    - Dependencies: None
    - Effort: {estimate}

  #{Y}: {title} [RESEARCHED]
    - Dependencies: Task #{X}
    - Effort: {estimate}

Analysis: specs/{NNN}_{SLUG}/reports/02_spawn-analysis.md

Dependency Graph:
  #{X} (foundational)
    |
    v
  #{Y}
    |
    v
  #{N} (parent - unblocked when spawned tasks complete)

Next Steps:
  1. /plan {first_spawned_task} - Create implementation plan
  2. /implement {first_spawned_task} - Implement the task
  3. Repeat for remaining spawned tasks
  4. /implement {N} - Resume parent task after spawned tasks complete
```

---

## Error Handling

### GATE IN Failure
- **Task not found**: Return error with /task --sync guidance
- **Invalid status**: Return error with current status and guidance

### DELEGATE Failure
- **Skill fails**: Keep parent at current status, log error to errors.json
- **Timeout**: Partial spawn may exist, run /task --sync

### GATE OUT Failure
- **Missing tasks**: Log warning, report what was created
- **Missing artifacts**: Log warning, continue with available

---

## Examples

### Basic spawn (auto-detect blocker)
```
/spawn 241
```
Agent analyzes task 241's plan and context to identify the blocker.

### Spawn with explicit blocker description
```
/spawn 241 missing state validation utilities before recovery can be implemented
```
Agent uses the provided description as primary signal for blocker analysis.

### Spawn a planned task (preemptive)
```
/spawn 150 task scope is too large, need to break down
```
Spawns sub-tasks before implementation begins.
