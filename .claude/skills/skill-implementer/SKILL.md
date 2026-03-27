---
name: skill-implementer
description: Execute general implementation tasks following a plan. Invoke for general implementation work.
allowed-tools: Task, Bash, Edit, Read, Write
# Original context (now loaded by subagent):
#   - .claude/context/formats/summary-format.md
#   - .claude/context/standards/code-patterns.md
# Original tools (now used by subagent):
#   - Read, Write, Edit, Glob, Grep, Bash
---

# Implementer Skill

Thin wrapper that delegates general implementation to `general-implementation-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task language is "general", "meta", or "markdown"
- /implement command is invoked
- Plan exists and task is ready for implementation

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Task status must allow implementation (planned, implementing, partial)

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

# Validate status
if [ "$status" = "completed" ]; then
  return error "Task already completed"
fi
```

---

### Stage 2: Preflight Status Update

Update task status to "implementing" BEFORE invoking subagent.

**Update state.json**:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "implementing" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid,
    started: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md**: Use Edit tool to change status marker from `[PLANNED]` to `[IMPLEMENTING]`.

**Update plan file** (if exists): Update the Status field in plan metadata:
```bash
.claude/scripts/update-plan-status.sh "$task_number" "$project_name" "IMPLEMENTING"
```

---

### Stage 3: Create Postflight Marker

Create the marker file to prevent premature termination:

```bash
# Ensure task directory exists
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-implementer",
  "task_number": ${task_number},
  "operation": "implement",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 3a: Calculate Artifact Number

Read `next_artifact_number` from state.json and use (current-1) since summary stays in the same round as research/plan:

```bash
# Read next_artifact_number from state.json
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Implement uses (current - 1) to stay in the same round as research/plan
# If next_artifact_number is 1 (no research yet), use 1
if [ "$next_num" -le 1 ]; then
  artifact_number=1
else
  artifact_number=$((next_num - 1))
fi

# Fallback for legacy tasks: count existing summary artifacts
if [ "$next_num" = "null" ] || [ -z "$next_num" ]; then
  padded_num=$(printf "%03d" "$task_number")
  count=$(ls "specs/${padded_num}_${project_name}/summaries/"*[0-9][0-9]*.md 2>/dev/null | wc -l)
  artifact_number=$((count + 1))
fi

artifact_padded=$(printf "%02d" "$artifact_number")
```

**Note**: Implement does NOT increment `next_artifact_number`. Only research advances the sequence.

---

### Stage 4: Prepare Delegation Context

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-implementer"],
  "timeout": 7200,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "language": "{language}"
  },
  "artifact_number": "{artifact_number from Stage 3a}",
  "plan_path": "specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

**Note**: The `artifact_number` field tells the agent which sequence number to use for artifact naming (e.g., `01`, `02`). Summary uses the same round number as the research and plan that preceded it.

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "general-implementation-agent"
  - prompt: [Include task_context, delegation_context, plan_path, metadata_file_path]
  - description: "Execute implementation for task {N}"
```

**DO NOT** use `Skill(general-implementation-agent)` - this will FAIL.

The subagent will:
- Load implementation context files
- Parse plan and find resume point
- Execute phases sequentially
- Create/modify files as needed
- Create implementation summary
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5a: Validate Subagent Return Format

**IMPORTANT**: Check if subagent accidentally returned JSON to console (v1 pattern) instead of writing to file (v2 pattern).

If the subagent's text return parses as valid JSON, log a warning:

```bash
# Check if subagent return looks like JSON (starts with { and is valid JSON)
subagent_return="$SUBAGENT_TEXT_RETURN"
if echo "$subagent_return" | grep -q '^{' && echo "$subagent_return" | jq empty 2>/dev/null; then
    echo "WARNING: Subagent returned JSON to console instead of writing metadata file."
    echo "This indicates the agent may have outdated instructions (v1 pattern instead of v2)."
    echo "The skill will continue by reading the metadata file, but this should be fixed."
fi
```

This validation:
- Does NOT fail the operation (continues to read metadata file)
- Logs a warning for debugging
- Indicates the subagent instructions need updating
- Allows graceful handling of mixed v1/v2 agents

---

### Stage 6: Parse Subagent Return (Read Metadata File)

After subagent returns, read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    phases_completed=$(jq -r '.metadata.phases_completed // 0' "$metadata_file")
    phases_total=$(jq -r '.metadata.phases_total // 0' "$metadata_file")

    # Extract completion_data fields (if present)
    completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
    claudemd_suggestions=$(jq -r '.completion_data.claudemd_suggestions // ""' "$metadata_file")
    roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

---

### Stage 7: Update Task Status (Postflight)

**If status is "implemented"**:

Update state.json to "completed" and add completion_data fields:
```bash
# Step 1: Update status and timestamps
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    completed: $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Step 2: Add completion_summary (always required for completed tasks)
if [ -n "$completion_summary" ]; then
    jq --arg summary "$completion_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).completion_summary = $summary' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi

# Step 3: Add language-specific completion fields
# For meta tasks: add claudemd_suggestions
if [ "$language" = "meta" ] && [ -n "$claudemd_suggestions" ]; then
    jq --arg suggestions "$claudemd_suggestions" \
      '(.active_projects[] | select(.project_number == '$task_number')).claudemd_suggestions = $suggestions' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi

# For non-meta tasks: add roadmap_items (if present and non-empty)
if [ "$language" != "meta" ] && [ "$roadmap_items" != "[]" ] && [ -n "$roadmap_items" ]; then
    jq --argjson items "$roadmap_items" \
      '(.active_projects[] | select(.project_number == '$task_number')).roadmap_items = $items' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

Update TODO.md: Change status marker from `[IMPLEMENTING]` to `[COMPLETED]`.

**Update plan file** (if exists): Update the Status field to `[COMPLETED]`:
```bash
.claude/scripts/update-plan-status.sh "$task_number" "$project_name" "COMPLETED"
```

**Remove from Recommended Order section** (non-blocking):
```bash
# Remove completed task from Recommended Order section (non-blocking)
if source "$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh" 2>/dev/null; then
    remove_from_recommended_order "$task_number" || echo "Note: Failed to update Recommended Order"
fi
```

**If status is "partial"**:

Keep status as "implementing" but update resume point:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson phase "$phases_completed" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    last_updated: $ts,
    resume_phase: ($phase + 1)
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

TODO.md stays as `[IMPLEMENTING]`.

**Update plan file** (if exists): Update the Status field to `[PARTIAL]`:
```bash
.claude/scripts/update-plan-status.sh "$task_number" "$project_name" "PARTIAL"
```

**On failed**: Keep status as "implementing" for retry. Do not update plan file (leave as `[IMPLEMENTING]` for retry).

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug. See `jq-escaping-workarounds.md`.

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing summary artifacts (use "| not" pattern to avoid != escaping - Issue #1132)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "summary" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new summary artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md** (if implemented): Add summary artifact link using count-aware format.

See `.claude/rules/state-management.md` "Artifact Linking Format" for canonical rules. Use Edit tool:

1. **Read existing task entry** to detect current summary links
2. **If no `- **Summary**:` line exists**: Insert inline format:
   ```markdown
   - **Summary**: [MM_{short-slug}-summary.md]({artifact_path})
   ```
3. **If existing inline (single link)**: Convert to multi-line:
   ```markdown
   old_string: - **Summary**: [existing.md](existing/path)
   new_string: - **Summary**:
     - [existing.md](existing/path)
     - [MM_{short-slug}-summary.md]({artifact_path})
   ```
4. **If existing multi-line**: Append new item before next field:
   ```markdown
   old_string:   - [last-item.md](last/path)
   **Description**:
   new_string:   - [last-item.md](last/path)
     - [MM_{short-slug}-summary.md]({artifact_path})
   **Description**:
   ```

---

### Stage 9: Git Commit

Commit changes with session ID:

```bash
git add -A
git commit -m "task ${task_number}: complete implementation

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Stage 10: Cleanup

Remove marker and metadata files:

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 11: Return Brief Summary

Return a brief text summary (NOT JSON). Example:

```
Implementation completed for task {N}:
- All {phases_total} phases executed successfully
- Key changes: {summary of changes}
- Created summary at specs/{NNN}_{SLUG}/summaries/MM_{short-slug}-summary.md
- Status updated to [COMPLETED]
- Changes committed
```

---

## Error Handling

### Input Validation Errors
Return immediately with error message if task not found or status invalid.

### Metadata File Missing
If subagent didn't write metadata file:
1. Keep status as "implementing"
2. Do not cleanup postflight marker
3. Report error to user

### Git Commit Failure
Non-blocking: Log failure but continue with success response.

### Subagent Timeout
Return partial status if subagent times out (default 7200s).
Keep status as "implementing" for resume.

---

## MUST NOT (Postflight Boundary)

After the agent returns, this skill MUST NOT:

1. **Edit source files** - All implementation work is done by agent
2. **Run build/test commands** - Verification is done by agent
3. **Use MCP tools** - Domain tools are for agent use only
4. **Analyze or grep source** - Analysis is agent work
5. **Write summary/reports** - Artifact creation is agent work

The postflight phase is LIMITED TO:
- Reading agent metadata file
- Updating state.json via jq
- Updating TODO.md status marker via Edit
- Linking artifacts in state.json
- Git commit
- Cleanup of temp/marker files

Reference: @.claude/context/standards/postflight-tool-restrictions.md

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.

Example successful return:
```
Implementation completed for task 350:
- All 5 phases executed successfully
- Created new feature component with tests
- Created summary at specs/350_feature/summaries/MM_{short-slug}-summary.md
- Status updated to [COMPLETED]
- Changes committed with session sess_1736700000_abc123
```

Example partial return:
```
Implementation partially completed for task 350:
- Phases 1-3 of 5 executed
- Phase 4 failed: TypeScript compilation error
- Partial summary at specs/350_feature/summaries/MM_{short-slug}-summary.md
- Status remains [IMPLEMENTING] - run /implement 350 to resume
```
