---
description: Create new version of implementation plan, or update task description if no plan exists
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(jq:*), Bash(git:*), TodoWrite
argument-hint: TASK_NUMBER [REASON]
model: claude-opus-4-5-20251101
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

3. **Validate and Route**
   - Task exists (ABORT if not)
   - Route based on status:

   | Status | Action |
   |--------|--------|
   | planned, implementing, partial, blocked | → Plan Revision (Stage 2A) |
   | not_started, researched | → Description Update (Stage 2B) |
   | completed | ABORT "Task completed, no revision needed" |
   | abandoned | ABORT "Task abandoned, use /task --recover first" |

**ABORT** if any validation fails. **PROCEED** to appropriate stage.

---

### STAGE 2A: Plan Revision

For tasks with existing plans (planned, implementing, partial, blocked):

1. **Load Current Context**
   - Current plan from `specs/{NNN}_{SLUG}/plans/*.md` (latest version)
     (Check padded directory first, fall back to unpadded for legacy tasks)
   - Research reports if any
   - Implementation progress (phase statuses)

2. **Analyze What Changed**
   - What phases succeeded/failed?
   - What new information emerged?
   - What dependencies weren't anticipated?

3. **Create Revised Plan**
   Increment version: MM_{short-slug}.md format (e.g., 02_revised-approach.md, 03_updated-design.md)

   Write to `specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md`
   (Always use padded directory for new plans)

4. **Update Status Inline** (two-step to avoid jq escaping bug - see `jq-escaping-workarounds.md`)
   Update state.json to "planned" status and add plan artifact:
   ```bash
   # Step 1: Update status and timestamps
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --arg status "planned" \
      '(.active_projects[] | select(.project_number == {task_number})) |= . + {
        status: $status,
        last_updated: $ts,
        planned: $ts
      }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

   # Step 2: Add artifact (use "| not" pattern to avoid != escaping - Issue #1132)
    jq --arg path "{new_plan_path}" \
      '(.active_projects[] | select(.project_number == {task_number})).artifacts =
        ([(.active_projects[] | select(.project_number == {task_number})).artifacts // [] | .[] | select(.type == "plan" | not)] + [{"path": $path, "type": "plan"}])' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
   ```

   Update TODO.md status marker using Edit tool.

-> Continue to CHECKPOINT 2 (Plan Revision)

---

### STAGE 2B: Description Update

For tasks without plans (not_started, researched):

1. **Read Current Description**
   ```bash
   old_description=$(echo "$task_data" | jq -r '.description // ""')
   ```

2. **Validate Revision Reason**
   If no revision_reason provided: ABORT "No revision reason provided. Usage: /revise N \"new description\""

3. **Update state.json**
   ```bash
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg desc "$new_description" \
      '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
        description: $desc,
        last_updated: $ts
      }' specs/state.json > specs/tmp/state.json && \
      mv specs/tmp/state.json specs/state.json
   ```

4. **Update TODO.md**
   Use Edit tool to replace description

→ Continue to CHECKPOINT 2 (Description Update)

---

### CHECKPOINT 2: GATE OUT

**For Plan Revision (Stage 2A):**
1. Verify new plan file exists
2. Verify status is "planned"
3. Verify plan link updated in TODO.md

**For Description Update (Stage 2B):**
1. Verify description updated in state.json
2. Verify description updated in TODO.md

**PROCEED** to commit.

---

### CHECKPOINT 3: COMMIT

**For Plan Revision:**
```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: revise plan (v{NEW_VERSION})

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

**For Description Update:**
```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: revise description

Session: {session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

Commit failure is non-blocking (log and continue).

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
- Invalid status: Return error with current status

### STAGE Failure
- Missing plan for revision: Fall back to description update
- Write failure: Log error, preserve original

### GATE OUT Failure
- Verification failure: Log warning, continue

### COMMIT Failure
- Non-blocking: Log warning, continue with success
