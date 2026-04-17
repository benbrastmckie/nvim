---
description: Create new version of implementation plan, or update task description if no plan exists
allowed-tools: Skill, Bash(jq:*), Bash(git:*), Read, Edit, Glob
argument-hint: TASK_NUMBER [REASON]
model: opus
---

# /revise Command

Create a new version of an implementation plan, or update task description if no plan exists.

**Artifact Numbering Note**: Plan revision creates a new plan file within the same artifact round. The revised plan uses the SAME artifact number (not incremented) because it replaces the previous plan in the same round. Only `/research` advances the artifact number to start a new round.

## Arguments

- `$1` - Task number (required)
- Remaining args - Optional reason for revision

## Execution

### CHECKPOINT 1: GATE IN

1. **Generate Session ID**
   ```
   session_id = sess_{timestamp}_{random}
   ```

2. **Lookup Task**
   ```bash
   task_data=$(jq -r --arg num "$task_number" \
     '.active_projects[] | select(.project_number == ($num | tonumber))' \
     specs/state.json)
   ```

3. **Validate Task Exists**
   - **ABORT** if task not found in state.json

   No other ABORT conditions. The command works regardless of task status.

4. **Check Plan Existence**
   ```bash
   padded_num=$(printf "%03d" "$task_number")
   project_name=$(echo "$task_data" | jq -r '.project_name')
   plan_exists=$(ls specs/${padded_num}_${project_name}/plans/*.md 2>/dev/null | head -1)
   ```

   This determines routing:
   - Plan file exists: Plan Revision path
   - No plan file: Description Update path

**PROCEED** to delegation.

---

### CHECKPOINT 2: DELEGATE TO SKILL

Invoke `skill-reviser` with the validated task context. The skill delegates to `reviser-agent` which handles:

- **Plan Revision path**: Load current plan, discover new research, synthesize revised plan
- **Description Update path**: Update task description based on revision reason

Pass to skill-reviser:
- `task_number` - Validated task number
- `session_id` - Generated session ID
- `revision_reason` - Optional reason from remaining args
- `task_data` - Full task data from state.json lookup
- `plan_exists` - Whether a plan file exists (boolean flag)

```
skill: "skill-reviser"
args: "task_number={N} session_id={session_id} revision_reason={reason} plan_exists={true|false}"
```

The skill spawns the reviser-agent, handles postflight (status update, artifact linking, git commit), and returns a brief text summary.

**On DELEGATE success**: Revision complete. **IMMEDIATELY CONTINUE** to CHECKPOINT 3 below.

---

### CHECKPOINT 3: GATE OUT

1. **Verify Artifacts** (Plan Revision only)
   If `plan_exists` was true (plan revision path), check the revised plan file exists on disk:
   ```bash
   revised_plan=$(ls -1t specs/${padded_num}_${project_name}/plans/*.md 2>/dev/null | head -1)
   if [ -z "$revised_plan" ]; then
       echo "WARNING: No plan file found after revision."
   fi
   ```

2. **Verify Status Updated** (Plan Revision only)
   The skill handles status updates internally (postflight).
   Confirm status is now "planned" in state.json:

   ```bash
   current_status=$(jq -r --argjson num "$task_number" \
     '.active_projects[] | select(.project_number == $num) | .status' \
     specs/state.json)

   if [ "$current_status" = "planned" | not ]; then
       echo "WARNING: state.json status is '$current_status', expected 'planned'. Applying defensive correction."
       bash .claude/scripts/update-task-status.sh postflight "$task_number" plan "$session_id"
   fi
   ```

3. **Verify TODO.md Status** (Plan Revision only)
   Check that the task entry in TODO.md shows `[PLANNED]`:

   ```bash
   if grep -q "- \*\*Status\*\*: \[PLANNING\]" <(grep -A 5 "^### ${task_number}\." specs/TODO.md); then
       echo "WARNING: TODO.md status not updated to [PLANNED]. Applying defensive correction."
   fi
   ```

   If mismatch found, use Edit tool to fix both task entry and Task Order.

**On GATE OUT success**: Revision verified.

---

## Output

**Plan Revision:**
```
Plan revised for Task #{N}

Previous: MM_{short-slug}.md
New: MM_{short-slug}.md

Preserved phases: {N}
Revised phases: {range}

Status: [PLANNED]
Next: /implement {N}
```

**Description Update:**
```
Description updated for Task #{N}

Previous: {old_description}
New: {new_description}

Status: [{current_status}]
```

## Error Handling

### GATE IN Failure
- Task not found: Return error with guidance

### DELEGATE Failure
- skill-reviser handles all error cases internally
- Missing plan for revision: Agent falls back to description update
- Write failure: Agent logs error, preserves original
- Git commit failure: Non-blocking (logged by skill)

### GATE OUT Failure
- Missing artifacts: Log warning, continue with available
- Status mismatch: Apply defensive correction via update-task-status.sh
