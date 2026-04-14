---
name: skill-implementer
description: Execute general implementation tasks following a plan. Invoke for general implementation work.
allowed-tools: Task, Bash, Edit, Read, Write
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
- Task type is "general", "meta", or "markdown"
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
task_type=$(echo "$task_data" | jq -r '.task_type // "general"')
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

Run the centralized status update script, which atomically updates state.json, TODO.md (task entry + Task Order), and the plan file:

```bash
bash .claude/scripts/update-task-status.sh preflight "$task_number" implement "$session_id"
```

**Note**: The script handles all three updates (state.json status/timestamps/session_id, TODO.md `[PLANNED]` -> `[IMPLEMENTING]` in both task entry and Task Order, and plan file status -> `[IMPLEMENTING]`) in a single call. No additional Edit or jq operations are needed.

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
    "task_type": "{task_type}"
  },
  "artifact_number": "{artifact_number from Stage 3a}",
  "plan_path": "specs/{NNN}_{SLUG}/plans/MM_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

**Note**: The `artifact_number` field tells the agent which sequence number to use for artifact naming (e.g., `01`, `02`). Summary uses the same round number as the research and plan that preceded it.

---

### Stage 4b: Read and Inject Format Specification

Read the summary format file and prepare it for injection into the subagent prompt. This ensures the subagent always has the full format specification in its context, regardless of whether it reads the file itself.

```bash
format_content=$(cat .claude/context/formats/summary-format.md)
```

The format content will be included as a delimited section in the Stage 5 prompt (see below).

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "general-implementation-agent"
  - prompt: [Include task_context, delegation_context, plan_path, metadata_file_path,
             AND the format specification from Stage 4b as shown below]
  - description: "Execute implementation for task {N}"
```

**Format Injection**: Include the format specification from Stage 4b in the prompt as a clearly-delimited section:

```
<artifact-format-specification>
## CRITICAL: Summary Format Requirements

You MUST follow this format specification exactly when writing the implementation summary.
Non-compliance will be caught by postflight validation.

{format_content from Stage 4b}
</artifact-format-specification>
```

Place this section AFTER the delegation context JSON and BEFORE any other instructions.

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

If the subagent's text return parses as valid JSON, log a warning (v1 pattern instead of v2 file-based pattern). Non-blocking -- continue to read metadata file regardless.

---

### Stage 5b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with status value `"implemented"` and the appropriate artifact information.

If you DID use the Task tool (Stage 5), skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent (Stage 5) or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Parse Subagent Return (Read Metadata File)

Read the metadata file:

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

### Stage 6a: Validate Artifact Content

If subagent status indicates success ("implemented" or "partial") and `artifact_path` is non-empty, validate the summary artifact against format requirements. This is **non-blocking** -- warnings are logged but do not prevent postflight from completing.

```bash
if [ "$status" = "implemented" ] || [ "$status" = "partial" ]; then
    if [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
        echo "Validating summary artifact..."
        if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" summary --fix; then
            echo "WARNING: Summary artifact has format issues (non-blocking). Review output above."
        fi
    fi
fi
```

**Note**: The `--fix` flag attempts auto-repair of missing metadata fields. Validation failures are logged but do not block status update or git commit.

---

### Stage 7: Update Task Status (Postflight)

**If status is "implemented"**:

**Step 1**: Run the centralized status update script to update state.json (status -> "completed", timestamps), TODO.md (`[IMPLEMENTING]` -> `[COMPLETED]` in task entry + Task Order), and plan file (status -> `[COMPLETED]`):
```bash
bash .claude/scripts/update-task-status.sh postflight "$task_number" implement "$session_id"
```

**Step 2**: Add completion_summary to state.json (implementer-specific, not covered by centralized script):
```bash
if [ -n "$completion_summary" ]; then
    jq --arg summary "$completion_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).completion_summary = $summary' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Step 3**: Add task-type-specific completion fields (implementer-specific):
```bash
# For meta tasks: add claudemd_suggestions
if [ "$task_type" = "meta" ] && [ -n "$claudemd_suggestions" ]; then
    jq --arg suggestions "$claudemd_suggestions" \
      '(.active_projects[] | select(.project_number == '$task_number')).claudemd_suggestions = $suggestions' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi

# For non-meta tasks: add roadmap_items (if present and non-empty)
if [ "$task_type" != "meta" ] && [ "$roadmap_items" != "[]" ] && [ -n "$roadmap_items" ]; then
    jq --argjson items "$roadmap_items" \
      '(.active_projects[] | select(.project_number == '$task_number')).roadmap_items = $items' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Step 4**: Remove from Recommended Order section (non-blocking, not covered by centralized script):
```bash
if source "$PROJECT_ROOT/.claude/scripts/update-recommended-order.sh" 2>/dev/null; then
    remove_from_recommended_order "$task_number" || echo "Note: Failed to update Recommended Order"
fi
```

**If status is "partial"**:

Keep status as "implementing" but update resume point. This path remains inline because the centralized `update-task-status.sh` maps `postflight:implement` to "completed" only -- it has no "partial" mapping.

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

**Update TODO.md** (if implemented): Link artifact using the automated script:

```bash
bash .claude/scripts/link-artifact-todo.sh $task_number '**Summary**' '**Description**' "$artifact_path"
```

If the script exits non-zero, log a warning but continue (linking errors are non-blocking).

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

See `rules/error-handling.md` for general patterns. Skill-specific behaviors:

- **Input validation errors**: Return immediately with error message
- **Metadata file missing**: Keep status as "implementing", do not cleanup marker, report to user
- **Git commit failure**: Non-blocking (log and continue)
- **Subagent timeout**: Return partial status, keep "implementing" for resume

## Postflight Boundary

After the agent returns, this skill is LIMITED TO: reading metadata, updating state.json/TODO.md, linking artifacts, git commit, cleanup. No source edits, builds, MCP tools, or analysis. See `@.claude/context/standards/postflight-tool-restrictions.md`.
