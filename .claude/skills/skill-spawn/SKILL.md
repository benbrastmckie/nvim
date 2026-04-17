---
name: skill-spawn
description: Research blockers and spawn new tasks to overcome them, updating parent task dependencies
allowed-tools: Task, Bash, Edit, Read, Write
---

# Spawn Skill

Thin wrapper that delegates blocker analysis to `spawn-agent` subagent, then handles all state management in postflight: creates new task entries, establishes parent-child relationships, and updates dependencies.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns, this skill handles all postflight operations (task creation, dependency linking, git commit) before returning. This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task status allows spawn (implementing, partial, blocked, planned, researched)
- Task is NOT completed or abandoned
- /spawn command is invoked with a valid task number

---

## Execution Flow

### Stage 1: Parse Delegation Context

Parse inputs from the /spawn command:

```bash
# Extract from delegation context
task_number=$1
session_id="$2"
blocker_prompt="$3"  # May be empty

# Lookup task data
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

# Validate exists
if [ -z "$task_data" ]; then
  echo "Error: Task $task_number not found"
  exit 1
fi

# Extract fields
project_name=$(echo "$task_data" | jq -r '.project_name')
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
status=$(echo "$task_data" | jq -r '.status')
description=$(echo "$task_data" | jq -r '.description // ""')
```

---

### Stage 2: Preflight Status Update

Update parent task status to "blocked" BEFORE invoking subagent.

**Update state.json**:
```bash
padded_num=$(printf "%03d" "$task_number")

jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "blocked" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

---

### Stage 3: Update TODO.md Parent Status

Use Edit tool to change status marker to `[BLOCKED]` if not already blocked.

```markdown
old_string: - **Status**: [{current_status}]
new_string: - **Status**: [BLOCKED]
```

---

### Stage 4: Create Postflight Marker

Create the marker file to prevent premature termination:

```bash
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-spawn",
  "task_number": ${task_number},
  "operation": "spawn",
  "reason": "Postflight pending: task creation, dependency linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 5: Prepare Delegation Context

Find the latest plan path (if exists):

```bash
plan_path=""
if [ -d "specs/${padded_num}_${project_name}/plans" ]; then
  plan_path=$(ls -t "specs/${padded_num}_${project_name}/plans/"*.md 2>/dev/null | head -1)
fi
```

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 2,
  "delegation_path": ["orchestrator", "spawn", "skill-spawn"],
  "timeout": 1800,
  "task_number": N,
  "task_data": {
    "project_number": N,
    "project_name": "{slug}",
    "status": "blocked",
    "task_type": "{task_type}",
    "description": "{description}",
    "effort": "{effort}"
  },
  "blocker_prompt": "{optional user description}",
  "plan_path": "{path to latest plan or null}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 6: Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "spawn-agent"
  - prompt: [Include task_number, task_data, blocker_prompt, plan_path, metadata_file_path, session_id]
  - description: "Analyze blocker for task {N} and propose new tasks"
```

**DO NOT** use `Skill(spawn-agent)` - this will FAIL.

The subagent will:
- Load task context and plan
- Analyze the blocker and identify root cause
- Propose minimal new tasks with dependencies
- Write blocker analysis report
- Write `.spawn-return.json` with task definitions
- Return a brief text summary (NOT JSON)

---

### Stage 6b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 6b). Do NOT skip these stages for any reason.

### Stage 7: Read Return Metadata

Read the spawn return file:

```bash
spawn_file="specs/${padded_num}_${project_name}/.spawn-return.json"

if [ -f "$spawn_file" ] && jq empty "$spawn_file" 2>/dev/null; then
    new_tasks=$(jq -r '.new_tasks' "$spawn_file")
    dependency_order=$(jq -r '.dependency_order' "$spawn_file")
    analysis_summary=$(jq -r '.analysis_summary' "$spawn_file")
    report_path=$(jq -r '.report_path' "$spawn_file")
    task_count=$(jq '.new_tasks | length' "$spawn_file")
else
    echo "Error: Invalid or missing spawn return file"
    exit 1
fi
```

---

### Stage 8: Get Next Task Numbers

Get the next available task numbers from state.json:

```bash
next_num=$(jq -r '.next_project_number' specs/state.json)

# Calculate task numbers for each new task based on dependency_order
# First task gets next_num, second gets next_num+1, etc.
```

---

### Stage 9: Apply Topological Sort (Kahn's Algorithm)

The agent provides `dependency_order` which is already topologically sorted (foundational tasks first). Map internal indices to actual task numbers:

```bash
# Example: dependency_order = [0, 1] means task at index 0 is foundational
# If next_num = 242:
#   - Index 0 -> Task 242 (foundational)
#   - Index 1 -> Task 243 (depends on 242)

# Build index->task_number mapping
declare -A task_num_map
order_idx=0
for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    task_num_map[$idx]=$((next_num + order_idx))
    order_idx=$((order_idx + 1))
done
```

---

### Stage 10: Create New Task Directories

For each new task, create directory structure:

```bash
for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    new_task_num=${task_num_map[$idx]}
    new_padded=$(printf "%03d" "$new_task_num")

    # Get task data from spawn return
    task_title=$(jq -r --argjson i "$idx" '.new_tasks[$i].title' "$spawn_file")
    task_slug=$(echo "$task_title" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')

    # Create directory with research artifact stub
    mkdir -p "specs/${new_padded}_${task_slug}/reports"

    # Copy spawn analysis as initial research for first task
    # (or create stub pointing to parent's spawn analysis)
done
```

---

### Stage 11: Update state.json with New Tasks

Insert new tasks in topological order (foundational first):

```bash
for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    new_task_num=${task_num_map[$idx]}

    # Extract task fields
    task_title=$(jq -r --argjson i "$idx" '.new_tasks[$i].title' "$spawn_file")
    task_desc=$(jq -r --argjson i "$idx" '.new_tasks[$i].description' "$spawn_file")
    task_effort=$(jq -r --argjson i "$idx" '.new_tasks[$i].effort' "$spawn_file")
    task_lang=$(jq -r --argjson i "$idx" '.new_tasks[$i].task_type' "$spawn_file")
    internal_deps=$(jq -r --argjson i "$idx" '.new_tasks[$i].dependencies' "$spawn_file")

    # Convert internal deps to task numbers
    resolved_deps="[]"
    for dep_idx in $(echo "$internal_deps" | jq -r '.[]'); do
        dep_num=${task_num_map[$dep_idx]}
        resolved_deps=$(echo "$resolved_deps" | jq --argjson n "$dep_num" '. + [$n]')
    done

    # Create task slug
    task_slug=$(echo "$task_title" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')

    # Add to state.json
    jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       --argjson num "$new_task_num" \
       --arg name "$task_slug" \
       --arg desc "$task_desc" \
       --arg effort "$task_effort" \
       --arg lang "$task_lang" \
       --argjson deps "$resolved_deps" \
       --argjson parent "$task_number" \
       --arg report "$report_path" \
      '.active_projects += [{
        "project_number": $num,
        "project_name": $name,
        "status": "researched",
        "task_type": $lang,
        "description": $desc,
        "effort": $effort,
        "parent_task": $parent,
        "dependencies": $deps,
        "created": $ts,
        "last_updated": $ts,
        "artifacts": [{"type": "research", "path": $report, "summary": "Spawn analysis from parent task"}]
      }]' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
done

# Update next_project_number
jq --argjson next "$((next_num + task_count))" \
  '.next_project_number = $next' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

---

### Stage 12: Update TODO.md with New Task Entries

Insert new task entries after the Tasks header, in topological order:

```markdown
### {NEW_TASK_NUM}. {Title}
- **Effort**: {estimate}
- **Status**: [RESEARCHED]
- **Task Type**: {task_type}
- **Dependencies**: Task #{dep1}, Task #{dep2}  OR  None
- **Parent Task**: #{parent_task_number}
- **Started**: {timestamp}
- **Research**: [02_spawn-analysis.md]({parent_dir}/reports/02_spawn-analysis.md)

**Description**: {full description}
```

Use Edit tool to insert each task entry at the top of the Tasks section (after `## Tasks` header).

**Refresh Recommended Order section** (non-blocking):
```bash
# Refresh Recommended Order section to include spawned tasks (non-blocking)
if source "$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh" 2>/dev/null; then
    refresh_recommended_order || echo "Note: Failed to refresh Recommended Order"
fi
```

---

### Stage 13: Update Parent Task Dependencies

Add new task numbers to parent task's dependencies in state.json:

```bash
# Build array of new task numbers
new_task_nums="[]"
for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    new_task_nums=$(echo "$new_task_nums" | jq --argjson n "${task_num_map[$idx]}" '. + [$n]')
done

# Update parent task dependencies (use "| not" pattern for Issue #1132)
jq --argjson new_deps "$new_task_nums" \
   --argjson num "$task_number" \
  '(.active_projects[] | select(.project_number == $num) | .dependencies) =
   ((.active_projects[] | select(.project_number == $num) | .dependencies) // [] + $new_deps)' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

---

### Stage 14: Update Parent Task Dependencies in TODO.md

Edit the parent task entry to add/update the Dependencies line:

```markdown
# If no Dependencies line exists, add after Status line:
old_string: - **Status**: [BLOCKED]
new_string: - **Status**: [BLOCKED]
- **Dependencies**: Task #242, Task #243

# If Dependencies line exists, update it:
old_string: - **Dependencies**: None
new_string: - **Dependencies**: Task #242, Task #243
```

Use Edit tool to update the parent task entry.

---

### Stage 15: Git Commit

Commit all changes with session ID:

```bash
git add -A
git commit -m "$(cat <<'EOF'
task {N}: spawn {M} tasks to resolve blocker

Session: {session_id}

EOF
)"
```

Commit failure is non-blocking (log and continue).

---

### Stage 16: Cleanup

Remove temporary files:

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.spawn-return.json"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 17: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Spawned {M} tasks to unblock task {N}:
- Task #{X}: {title} (no dependencies)
- Task #{Y}: {title} (depends on #{X})
- Parent task #{N} now depends on: #{X}, #{Y}
- Status: Parent [BLOCKED], spawned tasks [RESEARCHED]
- Next: /plan {first_spawned_task_num}
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found or status invalid.

### Spawn Return File Missing
If subagent didn't write spawn return file:
1. Keep status as "blocked"
2. Do not cleanup postflight marker
3. Report error to user

### Invalid Dependency Graph
If dependency_order contains cycles or invalid indices:
1. Log error
2. Fall back to sequential ordering by index
3. Report warning to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### jq Parse Failure
If jq commands fail (Issue #1132):
1. Log error
2. Retry using "| not" pattern
3. See jq-escaping-workarounds.md

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Perform research or analysis** - Analysis is done by agent
2. **Make decisions about task breakdown** - Agent decides decomposition
3. **Write implementation files** - Only state files in specs/
4. **Modify files outside specs/** - All changes confined to specs/

The postflight phase is LIMITED TO:
- Reading agent spawn return file
- Creating task directories
- Updating state.json with new tasks
- Updating TODO.md with new task entries
- Updating parent task dependencies
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The structured data is processed internally.

Example successful return:
```
Spawned 2 tasks to unblock task 241:
- Task #242: Create state validation utilities (no dependencies)
- Task #243: Implement recovery workflow (depends on #242)
- Parent task #241 now depends on: #242, #243
- Status: Parent [BLOCKED], spawned tasks [RESEARCHED]
- Next: /plan 242
```

Example partial return:
```
Spawn partially completed for task 241:
- Blocker analyzed, 2 tasks proposed
- Task creation failed at Task #243
- Partial state may exist, run /task --sync to reconcile
```
