---
name: skill-epi-implement
description: Implementation skill for R-based epidemiology analysis. Invoke for epi/epi:study implementation tasks.
allowed-tools: Agent, Bash, Edit, Read, Write, AskUserQuestion
# Context (loaded by subagent):
#   - .claude/extensions/epidemiology/context/project/epidemiology/patterns/
#   - .claude/extensions/epidemiology/context/project/epidemiology/templates/
#   - .claude/extensions/epidemiology/context/project/epidemiology/tools/
# Tools (used by subagent):
#   - Read, Write, Edit, Glob, Grep, Bash
---

# Epi Implement Skill

Thin wrapper that delegates epidemiology implementation to `epi-implement-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- An implement-phase dispatch on a task with `task_type: "epi"` or `task_type: "epi:study"`
- Epidemiology extension is available

---

## Input Parameters

### Required Parameters
- `task_number` - Task number (must exist in state.json with task_type="epi" or "epi:study")
- `session_id` - Session ID from orchestrator

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Verify task_type is "epi" or "epi:study"

```bash
task_data=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num)' \
  specs/state.json)

if [ -z "$task_data" ]; then
  return error "Task $task_number not found"
fi

task_type=$(echo "$task_data" | jq -r '.task_type // ""')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

if [ "$task_type" = "epi" ] || [ "$task_type" = "epi:study" ]; then
  : # valid
else
  return error "Task $task_number is not an epi task (task_type=$task_type)"
fi
```

---

### Stage 2 + Stage 3: Preflight Status Update and Postflight Marker

Source `skill-base.sh` once, then follow `@.claude/context/patterns/skill-preflight-flow.md` in
full for Stage 2 (preflight status update) and Stage 3 (marker creation):

```bash
source .claude/scripts/skill-base.sh
padded_num=$(printf "%03d" "$task_number")
skill_name="skill-epi-implement"
operation="implement"
```

`operation="implement"` (not `"epi_implement"`) is required here: `update-task-status.sh`'s
`target_status` vocabulary has no `epi_implement` value, so this skill maps onto the plain
`implement` operation, same as `skill-orchestrate`. The marker's `operation` field now reads
`"implement"` rather than `"epi_implement"` — a byte-for-byte Shape A key set, matching what this
skill's marker already carried (`created`, `stop_hook_active`) before this conversion.

---

### Stage 4a: Memory Retrieval and Literature Detection

**Skip memory retrieval if**: `clean_flag` is true (from `--clean`).

```bash
if [ "$clean_flag" != "true" ]; then
  memory_context=$(bash .claude/scripts/memory-retrieve.sh "$description" "$task_type" "" 2>/dev/null) || memory_context=""
fi
```

Follow `@.claude/context/patterns/lit-stage4a-flow.md` in full to resolve `--lit` and set
`lit_context`, exactly as `skill-orchestrate` does. This skill supplies the shared block's
preconditions: `lit_flag`, `description`, `orchestrator_mode` (default `"false"` when unset).

---

### Stage 4: Prepare Delegation Context

Read the implementation plan to identify phases for per-phase delegation.

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "implement", "skill-epi-implement"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "{task_type}"
  },
  "workflow_type": "epi_implement",
  "forcing_data": "{from state.json task metadata: study_design, data_paths, etc.}",
  "research_report_path": "specs/{NNN}_{SLUG}/reports/{MM}_epi-research.md",
  "plan_path": "specs/{NNN}_{SLUG}/plans/{MM}_implementation-plan.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

Phased delegation: Read plan phases from the plan file. Delegate each phase to the subagent
sequentially, passing phase number and details. Resume from last incomplete phase on re-invocation.

---

### Stage 5: Invoke Subagent

**CRITICAL**: Use the **Agent** tool to spawn the subagent.

```
Tool: Agent (NOT Skill, NOT Plan)
Parameters:
  - subagent_type: "epi-implement-agent"
  - prompt: [Include task_context, delegation_context, workflow_type, forcing_data, research_report_path, plan_path, metadata_file_path]
  - description: "Execute epi_implement for task {N}"
```

**DO NOT** use `Skill(epi-implement-agent)` - this will FAIL.

For phased plans, invoke subagent per-phase with phase context. Commit after each phase.

---

### Stage 5b: Self-Execution Fallback

See `context/patterns/thin-wrapper-skill.md` § "3b. Self-Execution Fallback" for the full
obligation: if you performed the work above WITHOUT using the Agent tool, write
`.return-meta.json` now per `return-metadata-file.md`'s schema before proceeding to postflight.
If you DID use the Agent tool, skip this stage.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Read Metadata File

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // "summary"' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
    memory_candidates=$(jq -c '.memory_candidates // []' "$metadata_file")
    # Schema: .claude/context/formats/return-metadata-file.md
    completion_summary=$(jq -r '.completion_data.completion_summary // ""' "$metadata_file")
    roadmap_items=$(jq -c '.completion_data.roadmap_items // []' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    status="failed"
fi
```

**Note**: renamed the local variable from `meta_status` to `status` to match the
`skill-postflight-flow.md` shared block's precondition naming used below.

---

### Stage 7, 7a, 8, 8a: Postflight Status, Memory Candidates, Artifact Linking, Notify

**MUST NOT cross the postflight boundary**: The subagent MUST NOT update state.json or TODO.md status.
Only this skill performs postflight status transitions.

Follow `@.claude/context/patterns/skill-postflight-flow.md` for Stage 7 (postflight status
update), Stage 7a (memory-candidate propagation), Stage 8 (artifact linking; artifact type
`"summary"`, an implementation summary with R script paths), and Stage 8a (TTS notify).
`skill_propagate_completion_summary` (already routed through `skill-base.sh` before this
conversion, sourced once at Stage 2 + Stage 3 above) is preserved as a "not covered by the shared
block" call:

```bash
field_name='**Summary**'
next_field='**Description**'
skill_postflight_update "$task_number" "$operation" "$session_id" "$status"
if [ "$status" = "implemented" ] || [ "$status" = "completed" ]; then
    skill_propagate_completion_summary "$task_number" "$completion_summary" "$roadmap_items" "$task_type"
fi
skill_propagate_memory_candidates "$task_number" "$memory_candidates" "$session_id"
skill_link_artifacts "$task_number" "$artifact_path" "$artifact_type" "$artifact_summary" \
  "$field_name" "$next_field" "$session_id"
skill_lifecycle_notify "$status"
```

| status | Final state.json | Final TODO.md |
|-------------|-----------------|---------------|
| completed | completed | [COMPLETED] |
| partial | implementing (unchanged — `skill_postflight_update` no-ops) | [IMPLEMENTING] |
| failed | (keep preflight, unchanged) | (keep preflight marker) |

---

### Stage 9: Git Commit

Apply the `implement` scope from `.claude/context/standards/git-staging-scope.md` — targeted
staging, never a repo-wide add:

```bash
stage_paths=("specs/${padded_num}_${project_name}/" "specs/TODO.md" "specs/state.json")
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"
while IFS= read -r f; do
  [ -n "$f" ] && stage_paths+=("$f")
done < <(jq -r '.modified_files[]? // empty' "$metadata_file" 2>/dev/null)
bash .claude/scripts/git-commit-scoped.sh \
  --message "task ${task_number}: complete epi implementation" \
  --session "${session_id}" \
  --honest-index-rows "${task_number}" \
  -- "${stage_paths[@]}"
```

---

### Stage 10: Cleanup

Follow `@.claude/context/patterns/skill-postflight-flow.md`'s Stage 9 (cleanup):

```bash
skill_cleanup "$padded_num" "$project_name"
```

---

### Stage 11: Return Brief Summary

**Implementation Success**:
```
Epi implementation completed for task {N}:
- R analysis scripts created and validated
- Created summary at specs/{NNN}_{SLUG}/summaries/{MM}_epi-implementation-summary.md
- Status updated to [COMPLETED]
- Changes committed with session {session_id}
```

---

## Error Handling

### Task not found
```
Epi implement skill error for task {N}:
- Task not found in state.json
- No status changes made
```

### Wrong task_type
```
Epi implement skill error for task {N}:
- Task is not an epi task (task_type={task_type})
- No status changes made
```

### Metadata file missing
Keep status at preflight level for resume.

### Git commit failure
Non-blocking. Log failure but continue.

---

## MUST NOT (Postflight Boundary)

After the agent returns -- whether with status implemented, partial, or failed -- this skill MUST proceed immediately to postflight (Stage 6). The skill MUST NOT:

1. **Edit R/Python files** - All analysis work is done by agent
2. **Run R scripts** - Execution is done by agent
3. **Use MCP tools** - Domain tools are for agent use only
4. **Analyze or grep source** - Analysis is agent work
5. **Write summary/reports** - Artifact creation is done by agent

See `context/standards/postflight-tool-restrictions.md` § "MUST NOT Section Template"
for the full PROHIBITION clause (the lead skill must not continue, complete, or "fill in" a
partial/failed subagent's work; report the status and let the user re-run the implement-phase dispatch) and the
postflight-phase allowed-operations list (read metadata, state.json/TODO.md updates, artifact
linking, git commit, cleanup).

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
