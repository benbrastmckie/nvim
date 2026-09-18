---
name: skill-spawn
description: Research blockers and spawn new tasks to overcome them, updating parent task dependencies
allowed-tools: Agent, Bash, Edit, Read, Write
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
- Task status is not terminal (completed, abandoned, expanded)
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

# Lookup task data (skill_validate_input exits 1 with its own not-found/terminal-state message;
# no separate existence check needed)
source .claude/scripts/skill-base.sh
skill_validate_input "$task_number"
task_data="$TASK_DATA"

# Extract fields
project_name="$PROJECT_NAME"
task_type="$TASK_TYPE"
status="$TASK_STATUS"
description="$DESCRIPTION"
parent_topic=$(echo "$task_data" | jq -r '.topic // ""')  # Inherited by spawned tasks
```

**Mode A Universal Fallback**: If `parent_topic` is empty, the parent task has no topic.
Invoke Mode A per @.claude/context/patterns/topic-assignment-pattern.md (Mode A:
Interactive) to let the user assign one now (which will also be inherited by spawned tasks).
There is no Skip option; topic assignment is mandatory.

```bash
if [[ -z "$parent_topic" ]]; then
  # Get existing active topics from state.json
  mapfile -t existing_topics < <(bash .claude/scripts/manage-topics.sh list)
  # Follow @.claude/context/patterns/topic-assignment-pattern.md (Mode A: Interactive) to
  # show the picker and capture the result in $parent_topic.
fi
```

AskUserQuestion:
```json
{
  "question": "Assign a topic to this task (will be inherited by spawned tasks)?",
  "header": "Topic",
  "multiSelect": false,
  "options": ["<existing-topic-1>", "<existing-topic-2>", "New topic..."]
}
```

- If user selects an existing topic → `parent_topic="$selected"`
- If user selects "New topic..." → show free-text follow-up and capture as `parent_topic`

---

### Stage 2: Preflight Status Update

Determine spawn type and preserve original status before updating.

**Spawn type detection**:
- If `status` is `blocked`, `implementing`, or `partial` -> Blocker-driven spawn
- If `status` is any other non-terminal state -> Holistic decomposition

**Note**: `[BLOCKED]` means "has unmet dependencies", not "encountered an error". The parent task transitions to `blocked` because it now depends on spawned subtasks.

**Update state.json** (preserve `previous_status`):
```bash
padded_num=$(printf "%03d" "$task_number")
previous_status=$(echo "$task_data" | jq -r '.status')

bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    previous_status: $prev,
    last_updated: $ts,
    session_id: $sid
  }' \
  --session-id "$session_id" \
  --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --arg status "blocked" \
  --arg prev "$previous_status" \
  --arg sid "$session_id"
```

---

### Stage 3: (Removed — state.json is authoritative for status)

The state.json update in Stage 2 already sets status to "blocked". TODO.md will be regenerated via generate-todo.sh in Stage 14b after all task writes complete.

---

### Stage 4: Create Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md`'s
Stage 3 (marker creation) — Stage 2 above is intentionally left untouched (it writes `status:
"blocked"` directly via `state-write.sh`, a genuinely custom transition outside the
`research`/`plan`/`implement` vocabulary `skill_preflight_update` requires), only the marker
write itself moves onto the shared function. `operation` stays `"spawn"` here, an opaque string
with no vocabulary requirement for the marker (see `skill_create_postflight_marker`'s signature
in `skill-base.sh`):

```bash
source .claude/scripts/skill-base.sh
skill_name="skill-spawn"
operation="spawn"
skill_create_postflight_marker "$padded_num" "$project_name" "$session_id" "$skill_name" "$operation"
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

Determine analysis mode for the agent:

```bash
analysis_mode="holistic"
if [ "$status" = "blocked" ] || [ "$status" = "implementing" ] || [ "$status" = "partial" ] || [ -n "$blocker_prompt" ]; then
    analysis_mode="blocker"
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
  "analysis_mode": "blocker" | "holistic",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 6: Invoke Subagent

**CRITICAL**: You MUST use the **Agent** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Agent (NOT Skill, NOT Plan)
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

**CRITICAL**: If you performed the work above WITHOUT using the Agent tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Agent tool, skip this stage -- the subagent already wrote the metadata.

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
    task_count=$(jq '.new_tasks | length' "$spawn_file")

    if [ "$task_count" -eq 0 ]; then
        echo "Spawn cancelled: no tasks selected."
        # Cleanup and restore parent status if needed
        rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
        rm -f "specs/${padded_num}_${project_name}/.spawn-return.json"
        exit 0
    fi

    dependency_order=$(jq -r '.dependency_order' "$spawn_file")
    analysis_summary=$(jq -r '.analysis_summary' "$spawn_file")
    report_path=$(jq -r '.report_path' "$spawn_file")
else
    echo "Error: Invalid or missing spawn return file"
    exit 1
fi
```

---

### Stage 8: Get Next Task Numbers

Bootstrap `specs/` first (belt-and-braces; `/spawn` requires a pre-existing parent task, so
`specs/` should already exist, but the call is idempotent and cheap — see
`context/standards/orchestrator-runtime-files.md`'s "Consumer Repo Setup"):
```bash
bash .claude/scripts/init-specs.sh
```

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
#   - Index 0 -> Task {N} (foundational)
#   - Index 1 -> Task {M} (depends on {N})

# Build index->task_number mapping
declare -A task_num_map
order_idx=0
for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    task_num_map[$idx]=$((next_num + order_idx))
    order_idx=$((order_idx + 1))
done
```

---

### Stage 9.5: File Footprint Overlap Check (Component 4a)

Before finalizing any `dependencies` merges (Stage 11), run the shared overlap check across
`new_tasks[]`'s `file_scope` entries so two spawned tasks that touch the same files are never
left without a serializing edge:

```bash
# Pairwise check across all new_tasks using file-footprint-overlap.md's directory-prefix rule
# (.claude/context/patterns/file-footprint-overlap.md, referenced by path — not restated here).
# For each unordered pair (i, j) of new_tasks indices with no existing dependency edge between
# them (checking .new_tasks[i].dependencies and .new_tasks[j].dependencies), if their
# file_scope arrays overlap, auto-add an edge from the later index to the earlier one:
#   .new_tasks[later_idx].dependencies += [earlier_idx]
# This mutates the in-memory dependency data used by Stage 9's task_num_map and Stage 11's
# internal_deps resolution, so the auto-added edge flows through Kahn's ordering and into
# state.json like any agent-declared dependency.
```

**Never silent**: any edge added by this check must be included in the Stage 17 return summary
annotated "(auto: file overlap)", distinguishing it from dependencies the `spawn-agent` already
declared with explicit reasoning.

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

    # Add to state.json (inherit parent topic if available)
    bash .claude/scripts/state-write.sh \
      '.active_projects += [{
        "project_number": $num,
        "project_name": $name,
        "status": "researched",
        "task_type": $lang,
        "description": $desc,
        "effort": $effort,
        "parent_task": $parent,
        "topic": (if ($topic == "") then null else $topic end),
        "dependencies": $deps,
        "created": $ts,
        "last_updated": $ts,
        "artifacts": [{"type": "research", "path": $report, "summary": "Spawn analysis from parent task"}]
      } | if .topic == null then del(.topic) else . end]' \
      --session-id "$session_id" \
      --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      --argjson num "$new_task_num" \
      --arg name "$task_slug" \
      --arg desc "$task_desc" \
      --arg effort "$task_effort" \
      --arg lang "$task_lang" \
      --argjson deps "$resolved_deps" \
      --argjson parent "$task_number" \
      --arg topic "$parent_topic" \
      --arg report "$report_path"
done

# Update next_project_number
bash .claude/scripts/state-write.sh \
  '.next_project_number = $next' \
  --session-id "$session_id" \
  --argjson next "$((next_num + task_count))"
```

---

### Stage 12: (Removed — state.json is authoritative for task entries)

The state.json updates in Stage 11 already write all task data. TODO.md will be regenerated via generate-todo.sh in Stage 14b after all task writes complete.

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
bash .claude/scripts/state-write.sh \
  '(.active_projects[] | select(.project_number == $num) | .dependencies) =
   ((.active_projects[] | select(.project_number == $num) | .dependencies) // [] + $new_deps)' \
  --session-id "$session_id" \
  --argjson new_deps "$new_task_nums" --argjson num "$task_number"
```

---

### Stage 14: (Removed — state.json is authoritative for dependencies)

The state.json update in Stage 13 already writes the dependencies array. TODO.md will be regenerated via generate-todo.sh in Stage 14b after all task writes complete.

---

### Stage 14a: Assign Topics via manage-topics.sh (Non-Blocking)

For each new task created in Stage 11, assign the inherited `parent_topic` via `manage-topics.sh set`. The `set` subcommand updates both the task's `topic` field and the `active_topics` array atomically (must be called AFTER the task entry exists in state.json from Stage 11). `parent_topic` is non-empty by construction (either inherited from the parent or assigned via the Mode A universal fallback above); the `-n` guard below is defensive only:

```bash
# Call set for each new task (parent_topic already written to each task entry in Stage 11)
if [[ -n "$parent_topic" ]]; then
  for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    new_task_num=${task_num_map[$idx]}
    bash .claude/scripts/manage-topics.sh set "$new_task_num" "$parent_topic" \
      2>/dev/null || echo "Warning: manage-topics.sh set failed for task $new_task_num (non-fatal)" >&2
  done
fi
```

---

### Stage 14b: Regenerate TODO.md (Non-Blocking)

After all state.json writes are complete (parent status blocked, new tasks, parent dependencies), regenerate the entire TODO.md from state.json. This single call replaces all direct TODO.md writes:

```bash
bash .claude/scripts/generate-todo.sh \
  2>/dev/null || echo "Note: Failed to regenerate TODO.md (non-fatal)" >&2
```

---

### Stage 15: Git Commit

Apply targeted staging per `.claude/context/standards/git-staging-scope.md` — scope to the
parent task dir plus every newly spawned task dir, never a repo-wide add:

```bash
stage_paths=("specs/${padded_num}_${project_name}/" "specs/TODO.md" "specs/state.json")
for idx in $(echo "$dependency_order" | jq -r '.[]'); do
    new_task_num=${task_num_map[$idx]}
    new_padded=$(printf "%03d" "$new_task_num")
    task_title=$(jq -r --argjson i "$idx" '.new_tasks[$i].title' "$spawn_file")
    task_slug=$(echo "$task_title" | tr '[:upper:]' '[:lower:]' | tr ' ' '_' | sed 's/[^a-z0-9_]//g')
    stage_paths+=("specs/${new_padded}_${task_slug}/")
done
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: spawn {M} tasks to resolve blocker" \
  --session "${session_id}" \
  --honest-index-rows {N} \
  -- "${stage_paths[@]}"
```

Commit failure is non-blocking (log and continue).

---

### Stage 16: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup); this skill also
removes `.spawn-return.json`, which is spawn-specific and not folded into `skill_cleanup`. `/spawn`
has no `command-gate-out.sh`/CHECKPOINT 3 consumer of `.return-meta.json` downstream of this
skill, so `skill-spawn` owns that deletion itself, inline, rather than relying on a calling
command:

```bash
skill_cleanup "$padded_num" "$project_name"
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
- Task #{Z}: {title} (depends on #{X} (auto: file overlap))
- Parent task #{N} now depends on: #{X}, #{Y}, #{Z}
- Status: Parent [BLOCKED], spawned tasks [RESEARCHED]
- Next: /plan {first_spawned_task_num}
```

Any dependency edge added by Stage 9.5's file-footprint overlap check MUST be annotated
"(auto: file overlap)" in this summary, distinguishing it from `spawn-agent`-declared
dependencies.

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found or status invalid.

### Spawn Return File Missing
If subagent didn't write spawn return file:
1. Keep status as "blocked"
2. Do not cleanup postflight marker
3. Report error to user

### Empty Task Selection (Cancelled Spawn)
If user selected no tasks in holistic mode:
1. `task_count` will be 0
2. Exit gracefully with informative message
3. Cleanup temporary files
4. Parent task remains `[BLOCKED]` (it still has the dependency intent)

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
Spawned 2 tasks to unblock task {N}:
- Task #{M}: Create state validation utilities (no dependencies)
- Task #{P}: Implement recovery workflow (depends on #{M})
- Parent task #{N} now depends on: #{M}, #{P}
- Status: Parent [BLOCKED], spawned tasks [RESEARCHED]
- Next: /plan {M}
```

Example partial return:
```
Spawn partially completed for task {N}:
- Blocker analyzed, 2 tasks proposed
- Task creation failed at Task #{P}
- Partial state may exist, run /task --sync to reconcile
```
