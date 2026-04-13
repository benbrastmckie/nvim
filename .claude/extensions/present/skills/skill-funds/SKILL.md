---
name: skill-funds
description: Funding landscape analysis with funder portfolio mapping. Invoke for funds tasks.
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
# Context (loaded by subagent):
#   - .claude/extensions/present/context/project/present/README.md
#   - .claude/extensions/present/context/project/present/domain/funding-analysis.md
#   - .claude/extensions/present/context/project/present/patterns/funding-forcing-questions.md
# Tools (used by subagent):
#   - Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, Bash
---

# Funds Skill

Thin wrapper that delegates funding analysis work to `funds-agent` subagent.

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
- Task type is "present" with task_type="funds"
- /funds command with task number
- Present extension is available

---

## Workflow Type Routing

This skill routes to funds-agent with one of four analysis modes:

| Analysis Mode | Preflight Status | Success Status | TODO.md Markers |
|---------------|-----------------|----------------|-----------------|
| LANDSCAPE | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| PORTFOLIO | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| JUSTIFY | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| GAP | researching | researched | [RESEARCHING] -> [RESEARCHED] |

**Note**: All modes follow the same status transition since they produce research-type output.

---

## Input Parameters

### Required Parameters
- `task_number` - Task number (must exist in state.json with language="present" and task_type="funds")
- `session_id` - Session ID from orchestrator

### Optional Parameters
- `topic` - Topic for legacy standalone mode (--quick)
- `mode` - Analysis mode override (LANDSCAPE, PORTFOLIO, JUSTIFY, GAP)

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Task must have language="present" and task_type="funds"

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
language=$(echo "$task_data" | jq -r '.language // "present"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')
task_type=$(echo "$task_data" | jq -r '.task_type // ""')

# Validate language is "present"
if [ "$task_type" = "present" | not ]; then
  return error "Task $task_number has language '$task_type', expected 'present'"
fi

# Validate task_type is "funds"
if [ "$task_type" = "funds" | not ]; then
  return error "Task $task_number has task_type '$task_type', expected 'funds'"
fi

# Validate status allows research
if [ "$status" = "completed" ]; then
  return error "Task already completed"
fi
```

---

### Stage 2: Preflight Status Update

Update task status to "researching" BEFORE invoking subagent.

```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg status "researching" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: $status,
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

**Update TODO.md**: Use Edit tool to change status marker to `[RESEARCHING]`.

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
  "skill": "skill-funds",
  "task_number": ${task_number},
  "operation": "funds_analysis",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 3a: Calculate Artifact Number

```bash
# Read next_artifact_number from state.json
next_num=$(jq -r --argjson num "$task_number" \
  '.active_projects[] | select(.project_number == $num) | .next_artifact_number // 1' \
  specs/state.json)

# Use current number for research artifacts (advances sequence)
artifact_number=$next_num
artifact_padded=$(printf "%02d" "$artifact_number")

# Increment next_artifact_number
jq '(.active_projects[] | select(.project_number == '$task_number')).next_artifact_number = '$((next_num + 1))'' \
  specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

---

### Stage 4: Prepare Delegation Context

Extract forcing_data from task metadata and prepare delegation context:

```bash
# Extract forcing_data from task
forcing_data=$(echo "$task_data" | jq '.forcing_data // {}')
mode=$(echo "$forcing_data" | jq -r '.mode // "LANDSCAPE"')
```

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "funds", "skill-funds"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "present",
    "task_type": "funds"
  },
  "mode": "{selected_mode from forcing_data}",
  "forcing_data": "{forcing_data object}",
  "artifact_number": "{artifact_padded}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 4b: Read and Inject Format Specification

Read the summary format file and prepare it for injection into the subagent prompt:

```bash
format_content=$(cat .claude/context/formats/summary-format.md)
```

The format content will be included as a delimited section in the Stage 5 prompt.

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "funds-agent"
  - prompt: [Include task_context, delegation_context, mode, forcing_data, artifact_number, metadata_file_path,
             AND the format specification from Stage 4b]
  - description: "Execute funding analysis for task {N}"
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

**DO NOT** use `Skill(funds-agent)` - this will FAIL.

The subagent will:
- Load funding analysis context files
- Parse forcing_data and mode
- Execute mode-specific analysis (web research, funder database queries)
- Create research report and optional XLSX/JSON outputs
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
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 5b). Do NOT skip these stages for any reason.

### Stage 6: Read Metadata File

Read the metadata file:

```bash
metadata_file="specs/${padded_num}_${project_name}/.return-meta.json"

if [ -f "$metadata_file" ] && jq empty "$metadata_file" 2>/dev/null; then
    meta_status=$(jq -r '.status' "$metadata_file")
    artifact_path=$(jq -r '.artifacts[0].path // ""' "$metadata_file")
    artifact_type=$(jq -r '.artifacts[0].type // ""' "$metadata_file")
    artifact_summary=$(jq -r '.artifacts[0].summary // ""' "$metadata_file")
else
    echo "Error: Invalid or missing metadata file"
    meta_status="failed"
fi
```

**Handle in_progress status**: If metadata file shows `status: "in_progress"`, the subagent was interrupted:
```bash
if [ "$meta_status" = "in_progress" ]; then
    partial_stage=$(jq -r '.partial_progress.stage // "unknown"' "$metadata_file")
    partial_details=$(jq -r '.partial_progress.details // ""' "$metadata_file")
    echo "Subagent interrupted at stage: $partial_stage"
    echo "Details: $partial_details"
fi
```

---

### Stage 6a: Validate Artifact Content

If subagent status indicates success and `artifact_path` is non-empty, validate the artifact:

```bash
if [ "$meta_status" = "researched" ]; then
    if [ -n "$artifact_path" ] && [ -f "$artifact_path" ]; then
        echo "Validating artifact..."
        if ! bash .claude/scripts/validate-artifact.sh "$artifact_path" report --fix; then
            echo "WARNING: Artifact has format issues (non-blocking). Review output above."
        fi
    fi
fi
```

---

### Stage 7: Update Task Status (Postflight)

**Postflight Status Mapping**:
| Meta Status | Final state.json | Final TODO.md |
|-------------|-----------------|---------------|
| researched | researched | [RESEARCHED] |
| partial | researching | [RESEARCHING] |
| failed | (keep preflight) | (keep preflight marker) |

**Update state.json** (if status changed to success):
```bash
if [ "$meta_status" = "researched" ]; then
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg status "researched" \
    '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
      status: $status,
      last_updated: $ts
    }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Use Edit tool to change status marker to `[RESEARCHED]`.

**On partial/failed**: Keep status at preflight level for resume.

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug.

```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing report artifacts (use "| not" pattern - Issue #1132)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "report" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Add artifact link using count-aware format per `.claude/rules/state-management.md`.

---

### Stage 9: Git Commit

Commit changes with session ID:

```bash
git add -A
git commit -m "task ${task_number}: complete funding analysis research

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

**On commit failure**: Non-blocking. Log the failure but continue with success response.

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

Return a brief text summary (NOT JSON) based on analysis outcome.

**Research Success**:
```
Funding analysis research completed for task {N}:
- Mode: {mode} analysis
- Identified {count} funding opportunities
- Created report at specs/{NNN}_{SLUG}/reports/{MM}_funding-analysis.md
- Status updated to [RESEARCHED]
- Changes committed with session {session_id}

Next steps:
- Review the funding analysis report
- Run /plan {N} to create implementation plan
- Run /implement {N} to generate deliverables
```

**Partial Return**:
```
Funding analysis partially completed for task {N}:
- {completed_actions}
- {failed_action} failed: {reason}
- Partial report saved at specs/{NNN}_{SLUG}/reports/{MM}_funding-analysis.md
- Status remains [RESEARCHING] - run /funds {N} to continue
```

---

## Error Handling

### Input Validation Errors

**Task not found**:
```
Funds skill error for task {N}:
- Task not found in state.json
- Verify task exists with /task --sync
- No status changes made
```

**Wrong language or task_type**:
```
Funds skill error for task {N}:
- Task has language '{language}' / task_type '{task_type}', expected 'present' / 'funds'
- Use /funds "description" to create a new funding analysis task
- No status changes made
```

### Metadata File Missing

If subagent didn't write metadata file:
1. Keep status at preflight level (researching)
2. Do not cleanup postflight marker
3. Report error to user with resume guidance

```
Funds skill error for task {N}:
- Subagent did not write metadata file
- Task remains [RESEARCHING] for resume
- Postflight marker preserved
- Run /funds {N} to retry
```

### Git Commit Failure

Non-blocking error:
```
Funding analysis completed for task {N}:
- {analysis_results}
- [Warning] Git commit failed: {error}
- Manual commit recommended: git add -A && git commit
```

### Subagent Timeout

Return partial status (default 3600s timeout):
```
Funding analysis timed out for task {N}:
- Subagent exceeded timeout limit
- Partial progress: {partial_details}
- Status remains [RESEARCHING]
- Run /funds {N} to continue
```

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
