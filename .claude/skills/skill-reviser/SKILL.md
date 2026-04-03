---
name: skill-reviser
description: Create new version of implementation plan or update task description. Invoke for /revise command.
allowed-tools: Bash, Edit, Read, Write, Glob, Grep
model: opus
---

# Reviser Skill

Thin wrapper that handles plan revision and description update with proper preflight/postflight structure.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After execution,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)
- Path: `.claude/context/formats/plan-format.md` - Plan file format specification

Note: This skill does NOT delegate to a subagent. Revise is lightweight enough to execute directly.

## Trigger Conditions

This skill activates when:
- `/revise` command is invoked
- Task exists and status allows revision

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Route based on status:

| Status | Action |
|--------|--------|
| planned, implementing, partial, blocked | Plan Revision (Stage 2A) |
| not_started, researched | Description Update (Stage 2B) |
| completed | ABORT "Task completed, no revision needed" |
| abandoned | ABORT "Task abandoned, use /task --recover first" |

```bash
# Lookup task
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

# Extract fields
language=$(echo "$task_data" | jq -r '.language // "general"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')
```

---

### Stage 2A: Plan Revision

For tasks with existing plans (planned, implementing, partial, blocked):

**2A.1: Load Current Context**
- Current plan from `specs/{NNN}_{SLUG}/plans/*.md` (latest version)
  (Check padded directory first, fall back to unpadded for legacy tasks)
- Research reports if any
- Implementation progress (phase statuses)

**2A.2: Analyze What Changed**
- What phases succeeded/failed?
- What new information emerged?
- What dependencies were not anticipated?

**2A.3: Create Revised Plan**
Increment version: MM_{short-slug}.md format (e.g., 02_revised-approach.md, 03_updated-design.md)

Write to `specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md`
(Always use padded directory for new plans)

---

### Stage 2B: Description Update

For tasks without plans (not_started, researched):

**2B.1: Read Current Description**
```bash
old_description=$(echo "$task_data" | jq -r '.description // ""')
```

**2B.2: Validate Revision Reason**
If no revision_reason provided: ABORT "No revision reason provided. Usage: /revise N \"new description\""

**2B.3: Update state.json**
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --arg desc "$new_description" \
   --argjson num "$task_number" \
  '(.active_projects[] | select(.project_number == $num)) |= . + {
    description: $desc,
    last_updated: $ts
  }' specs/state.json > specs/tmp/state.json && \
  mv specs/tmp/state.json specs/state.json
```

**2B.4: Update TODO.md**
Use Edit tool to replace description text in the task entry.

---

### Stage 3: Postflight Status Update (Plan Revision Only)

For Stage 2A (plan revision), update status to "planned" using the centralized script:

```bash
bash .claude/scripts/update-task-status.sh postflight $task_number plan $session_id
```

This atomically updates:
- state.json: status -> "planned", last_updated, session_id
- TODO.md task entry: [STATUS] -> [PLANNED]
- TODO.md Task Order: [STATUS] -> [PLANNED]

If the script exits non-zero, log error but continue (status update is best-effort for revise).

**Note**: No preflight status update is needed for revise -- there is no "revising" intermediate status.
The task transitions directly from its current status to "planned" after the revised plan is created.

**Note**: Stage 2B (description update) does NOT change status, so it skips this stage entirely.

---

### Stage 4: Artifact Linking (Plan Revision Only)

Add the new plan artifact to state.json.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug. See `jq-escaping-workarounds.md`.

```bash
if [ -n "$new_plan_path" ]; then
    # Step 1: Filter out existing plan artifacts (use "| not" pattern to avoid != escaping - Issue #1132)
    jq --argjson num "$task_number" \
      '(.active_projects[] | select(.project_number == $num)).artifacts =
        [(.active_projects[] | select(.project_number == $num)).artifacts // [] | .[] | select(.type == "plan" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new plan artifact
    jq --argjson num "$task_number" \
       --arg path "$new_plan_path" \
      '(.active_projects[] | select(.project_number == $num)).artifacts += [{"path": $path, "type": "plan"}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Add plan artifact link using count-aware format (see state-management.md).

Use Edit tool:
1. **If no `- **Plan**:` line exists**: Insert inline format
2. **If existing inline (single link)**: Convert to multi-line
3. **If existing multi-line**: Append new item

---

### Stage 5: Git Commit

**For Plan Revision:**
```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: revise plan (v{NEW_VERSION})

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

**For Description Update:**
```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: revise description

Session: {session_id}

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
EOF
)"
```

Commit failure is non-blocking (log and continue).

---

### Stage 6: Return Brief Summary

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

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found or status invalid.

### Missing Plan for Revision
Fall back to description update if no plan files found.

### Write Failure
Log error, preserve original files.

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### jq Parse Failure
If jq commands fail with INVALID_CHARACTER or syntax error (Issue #1132):
1. Log to errors.json
2. Retry with two-step pattern (already implemented in Stage 4)

---

## Return Format

This skill returns a **brief text summary** (NOT JSON).
