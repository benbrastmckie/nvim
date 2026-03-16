---
name: skill-grant
description: Grant proposal research and drafting with funder analysis. Invoke for grant tasks.
allowed-tools: Task, Bash, Edit, Read, Write
# Context (loaded by subagent):
#   - .claude/extensions/present/context/project/present/README.md
# Tools (used by subagent):
#   - Read, Write, Edit, Glob, Grep, WebSearch, WebFetch
---

# Grant Skill

Thin wrapper that delegates grant work to `grant-agent` subagent.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.
This eliminates the "continue" prompt issue between skill return and orchestrator.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/core/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/core/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/core/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/core/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill is a thin wrapper with internal postflight. Context is loaded by the delegated agent.

## Trigger Conditions

This skill activates when:
- Task language is "grant"
- Grant workflow requested via flags (--draft, --budget) or /implement routing
- Extension is loaded via `<leader>ac`

---

## Workflow Type Routing

This skill routes to grant-agent with one of five workflow types:

| Workflow Type | Preflight Status | Success Status | TODO.md Markers |
|---------------|-----------------|----------------|-----------------|
| funder_research | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| proposal_draft | planning | planned | [PLANNING] -> [PLANNED] |
| budget_develop | planning | planned | [PLANNING] -> [PLANNED] |
| progress_track | (no change) | (no change) | (no change) |
| assemble | implementing | completed | [IMPLEMENTING] -> [COMPLETED] |

**Note**: The `assemble` workflow is triggered via `/implement N` command (not `/grant`), which routes to skill-grant when the task language is "grant".

---

## Input Parameters

### Required Parameters
- `task_number` - Task number (must exist in state.json with language="grant")
- `workflow_type` - One of: funder_research, proposal_draft, budget_develop, progress_track, assemble
- `session_id` - Session ID from orchestrator

### Optional Parameters
- `focus` - Focus prompt for workflow direction (used by all workflow types)

**Prompt Usage by Workflow Type**:
| Workflow | focus Parameter | Example |
|----------|-----------------|---------|
| funder_research | Research focus | "Focus on NIH institutes" |
| proposal_draft | Drafting guidance | "Emphasize innovation and methodology" |
| budget_develop | Budget guidance | "Include 3 conferences/year, emphasize personnel" |
| progress_track | Summary focus | "Focus on budget utilization" |
| assemble | Assembly options | "Include executive summary" |

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- `workflow_type` - Must be one of: funder_research, proposal_draft, budget_develop, progress_track, assemble
- `focus` - Optional prompt for workflow direction

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
language=$(echo "$task_data" | jq -r '.language // "grant"')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

# Validate language is "grant"
if [ "$language" != "grant" ]; then
  return error "Task $task_number has language '$language', expected 'grant'"
fi

# Validate workflow_type
case "$workflow_type" in
  funder_research|proposal_draft|budget_develop|progress_track|assemble)
    ;;
  *)
    return error "Invalid workflow_type: $workflow_type. Expected one of: funder_research, proposal_draft, budget_develop, progress_track, assemble"
    ;;
esac
```

---

### Stage 2: Preflight Status Update

Update task status based on workflow type BEFORE invoking subagent.

**Status Mapping by Workflow Type**:
| Workflow Type | state.json status | TODO.md marker |
|---------------|------------------|----------------|
| funder_research | researching | [RESEARCHING] |
| proposal_draft | planning | [PLANNING] |
| budget_develop | planning | [PLANNING] |
| progress_track | (no change) | (no change) |
| assemble | implementing | [IMPLEMENTING] |

**Update state.json** (for workflows that change status):
```bash
# Determine preflight status based on workflow type
case "$workflow_type" in
  funder_research)
    preflight_status="researching"
    preflight_marker="[RESEARCHING]"
    ;;
  proposal_draft|budget_develop)
    preflight_status="planning"
    preflight_marker="[PLANNING]"
    ;;
  progress_track)
    preflight_status=""  # No status change
    preflight_marker=""
    ;;
  assemble)
    preflight_status="implementing"
    preflight_marker="[IMPLEMENTING]"
    ;;
esac

# Update state.json if status change needed
if [ -n "$preflight_status" ]; then
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg status "$preflight_status" \
     --arg sid "$session_id" \
    '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
      status: $status,
      last_updated: $ts,
      session_id: $sid
    }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Use Edit tool to change status marker to the workflow-specific in-progress state.

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
  "skill": "skill-grant",
  "task_number": ${task_number},
  "operation": "${workflow_type}",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 4: Prepare Delegation Context

**Detect revision mode** (for assemble workflow):
```bash
# Check if task has parent_grant field (indicates revision task)
parent_grant=$(echo "$task_data" | jq -r '.parent_grant // ""')
revises_directory=$(echo "$task_data" | jq -r '.revises_directory // ""')

if [ -n "$parent_grant" ] && [ "$workflow_type" = "assemble" ]; then
    is_revision="true"
    # Validate revises_directory exists
    if [ ! -d "$revises_directory" ]; then
        return error "Revision target not found: $revises_directory"
    fi
else
    is_revision="false"
    revises_directory=""
fi
```

Prepare delegation context for the subagent:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "grant", "skill-grant"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "language": "grant"
  },
  "workflow_type": "funder_research|proposal_draft|budget_develop|progress_track|assemble",
  "focus_prompt": "{optional focus - passed to agent for guidance}",
  "is_revision": "{boolean - true if task has parent_grant field}",
  "revises_directory": "{grants/{N}_{slug}/ - path to existing grant if revision}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 5: Invoke Subagent

**CRITICAL**: You MUST use the **Task** tool to spawn the subagent.

**Required Tool Invocation**:
```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "grant-agent"
  - prompt: [Include task_context, delegation_context, workflow_type, focus_prompt, is_revision, revises_directory, metadata_file_path]
  - description: "Execute {workflow_type} workflow for task {N}"
```

**DO NOT** use `Skill(grant-agent)` - this will FAIL.

The subagent will:
- Execute the specified workflow (funder_research, proposal_draft, budget_develop, progress_track, assemble)
- Use the focus_prompt to guide its output
- Create workflow-specific artifacts in `specs/{NNN}_{SLUG}/{subdir}/`
- Write metadata to `specs/{NNN}_{SLUG}/.return-meta.json`
- Return a brief text summary (NOT JSON)

---

### Stage 5a: Validate Return Format

After subagent returns, validate the return format:

```
If subagent returned JSON to console:
  - Log warning: "Subagent returned JSON to console instead of brief summary"
  - Continue with metadata file parsing (Stage 6)

If subagent returned brief text summary:
  - This is expected behavior
  - Continue to Stage 6
```

---

### Stage 6: Parse Subagent Return (Read Metadata File)

After subagent returns, read the metadata file:

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
    # Extract partial progress info
    partial_stage=$(jq -r '.partial_progress.stage // "unknown"' "$metadata_file")
    partial_details=$(jq -r '.partial_progress.details // ""' "$metadata_file")

    # Keep preflight status (researching, planning)
    # Do not cleanup - resume is possible
    echo "Subagent interrupted at stage: $partial_stage"
    echo "Details: $partial_details"
fi
```

---

### Stage 7: Update Task Status (Postflight)

Map workflow_type + metadata status to final state.json status:

**Postflight Status Mapping**:
| Workflow Type | Meta Status | Final state.json | Final TODO.md |
|---------------|-------------|-----------------|---------------|
| funder_research | researched | researched | [RESEARCHED] |
| funder_research | partial | researching | [RESEARCHING] |
| proposal_draft | drafted | planned | [PLANNED] |
| proposal_draft | partial | planning | [PLANNING] |
| budget_develop | drafted | planned | [PLANNED] |
| budget_develop | partial | planning | [PLANNING] |
| progress_track | tracked | (no change) | (no change) |
| progress_track | partial | (no change) | (no change) |
| assemble | assembled | completed | [COMPLETED] |
| assemble | partial | implementing | [IMPLEMENTING] |
| any | failed | (keep preflight) | (keep preflight marker) |

**Update state.json** (if status changed to success):
```bash
# Determine postflight status based on workflow type and meta_status
case "$workflow_type" in
  funder_research)
    if [ "$meta_status" = "researched" ]; then
      postflight_status="researched"
      postflight_marker="[RESEARCHED]"
    fi
    ;;
  proposal_draft|budget_develop)
    if [ "$meta_status" = "drafted" ]; then
      postflight_status="planned"
      postflight_marker="[PLANNED]"
    fi
    ;;
  progress_track)
    postflight_status=""  # No status change for progress tracking
    postflight_marker=""
    ;;
  assemble)
    if [ "$meta_status" = "assembled" ]; then
      postflight_status="completed"
      postflight_marker="[COMPLETED]"
    fi
    ;;
esac

# Update state.json if status change to success
if [ -n "$postflight_status" ]; then
  jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     --arg status "$postflight_status" \
    '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
      status: $status,
      last_updated: $ts
    }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Use Edit tool to change status marker to the final success state.

**On partial/failed**: Keep status at preflight level for resume.

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary.

**IMPORTANT**: Use two-step jq pattern to avoid Issue #1132 escaping bug. See `jq-escaping-workarounds.md`.

**Determine artifact type for filtering**:
```bash
# Map workflow_type to artifact type for state.json
case "$workflow_type" in
  funder_research)
    artifact_filter_type="report"
    ;;
  proposal_draft)
    artifact_filter_type="draft"
    ;;
  budget_develop)
    artifact_filter_type="budget"
    ;;
  progress_track)
    artifact_filter_type="summary"
    ;;
  assemble)
    artifact_filter_type="grant"
    ;;
esac
```

**Update state.json with artifact**:
```bash
if [ -n "$artifact_path" ]; then
    # Step 1: Filter out existing artifacts of same type (use "| not" pattern to avoid != escaping - Issue #1132)
    jq '(.active_projects[] | select(.project_number == '$task_number')).artifacts =
        [(.active_projects[] | select(.project_number == '$task_number')).artifacts // [] | .[] | select(.type == "'"$artifact_filter_type"'" | not)]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

    # Step 2: Add new artifact
    jq --arg path "$artifact_path" \
       --arg type "$artifact_type" \
       --arg summary "$artifact_summary" \
      '(.active_projects[] | select(.project_number == '$task_number')).artifacts += [{"path": $path, "type": $type, "summary": $summary}]' \
      specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
fi
```

**Update TODO.md**: Add artifact link based on workflow type:
- funder_research: `- **Research**: [{filename}]({artifact_path})`
- proposal_draft: `- **Draft**: [{filename}]({artifact_path})`
- budget_develop: `- **Budget**: [{filename}]({artifact_path})`
- progress_track: `- **Progress**: [{filename}]({artifact_path})`
- assemble: `- **Grant**: [{directory}](grants/{N}_{slug}/)`

---

### Stage 9: Git Commit

Commit changes with session ID:

```bash
# Commit message based on workflow type
case "$workflow_type" in
  funder_research)
    commit_action="complete funder research"
    ;;
  proposal_draft)
    commit_action="create proposal draft"
    ;;
  budget_develop)
    commit_action="develop budget"
    ;;
  progress_track)
    commit_action="update progress"
    ;;
  assemble)
    commit_action="assemble grant materials"
    ;;
esac

git add -A
git commit -m "task ${task_number}: ${commit_action}

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

Return a brief text summary (NOT JSON) based on workflow type.

**Funder Research Success**:
```
Funder research completed for task {N}:
- Identified {count} potential funders matching criteria
- Top recommendation: {funder_name} ({reason})
- Created report at specs/{NNN}_{SLUG}/reports/{MM}_funder-analysis.md
- Status updated to [RESEARCHED]
- Changes committed with session {session_id}
```

**Proposal Draft Success**:
```
Proposal draft created for task {N}:
- Drafted {count} of {total} required sections
- Focus applied: "{focus_prompt}" (if provided)
- Created draft at specs/{NNN}_{SLUG}/drafts/{MM}_narrative-draft.md
- Status updated to [PLANNED]
- Recommend: Run /grant {N} --budget next, then /plan {N}
```

**Budget Development Success**:
```
Budget developed for task {N}:
- Created {count} line items across {categories} categories
- Total budget: {amount}
- Focus applied: "{focus_prompt}" (if provided)
- Created budget at specs/{NNN}_{SLUG}/budgets/{MM}_line-item-budget.md
- Status updated to [PLANNED]
- Recommend: Run /plan {N} to create implementation plan
```

**Assemble Success**:
```
Grant materials assembled for task {N}:
- Output directory: grants/{N}_{slug}/
- Files created: narrative.md, budget.md, checklist.md
- Assembly options applied: "{focus_prompt}" (if provided)
- Status updated to [COMPLETED]
- Changes committed with session {session_id}
```

**Progress Tracking Success**:
```
Progress summary updated for task {N}:
- Overall completion: {percentage}%
- {completed_count} sections completed, {pending_count} in progress
- Created summary at specs/{NNN}_{SLUG}/summaries/{MM}_progress-summary.md
- Status unchanged (progress tracking only)
- Changes committed with session {session_id}
```

**Partial Return**:
```
Grant {workflow_type} partially completed for task {N}:
- {completed_actions}
- {failed_action} failed: {reason}
- Partial artifact created at specs/{NNN}_{SLUG}/{subdir}/{filename}
- Status remains [{preflight_marker}] - run /grant {N} {flag} to continue
```

---

## Error Handling

### Input Validation Errors

**Task not found**:
Return immediately with error message:
```
Grant skill error for task {N}:
- Task not found in state.json
- Verify task exists with /task --sync
- No status changes made
```

**Invalid workflow_type**:
Return immediately with error message:
```
Grant skill error for task {N}:
- Invalid workflow_type: {provided_value}
- Expected one of: funder_research, proposal_draft, budget_develop, progress_track, assemble
- No status changes made
```

**Wrong language**:
Return immediately with error message:
```
Grant skill error for task {N}:
- Task has language '{language}', expected 'grant'
- Use /grant {N} to update task language or use appropriate skill
- No status changes made
```

### Metadata File Missing

If subagent didn't write metadata file:
1. Keep status at preflight level (researching, planning)
2. Do not cleanup postflight marker
3. Report error to user with resume guidance

```
Grant skill error for task {N}:
- Subagent did not write metadata file
- Task remains [{preflight_marker}] for resume
- Postflight marker preserved
- Run /grant {N} {flag} to retry
```

### Git Commit Failure

Non-blocking error. Log failure but continue with success response:

```
Grant {workflow_type} completed for task {N}:
- {workflow_results}
- [Warning] Git commit failed: {error}
- Manual commit recommended: git add -A && git commit
```

### Subagent Timeout

Return partial status if subagent times out (default 3600s):
1. Check for partial metadata file (may have in_progress status)
2. Keep status at preflight level for resume
3. Report partial progress if available

```
Grant {workflow_type} timed out for task {N}:
- Subagent exceeded timeout limit
- Partial progress: {partial_details}
- Status remains [{preflight_marker}]
- Run /grant {N} {flag} to continue
```

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.

Example successful return (proposal_draft with prompt):
```
Proposal draft created for task 500:
- Drafted 5 of 7 required sections
- Focus applied: "Emphasize innovation and methodology"
- Created draft at specs/500_research_ai_safety_funders/drafts/01_narrative-draft.md
- Status updated to [PLANNED]
- Recommend: Run /grant 500 --budget next
```

Example partial return:
```
Grant proposal_draft partially completed for task 500:
- Completed problem statement, methodology, impact sections
- WebFetch failed for funder template retrieval
- Partial draft saved at specs/500_research_ai_safety_funders/drafts/01_narrative-draft.md
- Status remains [PLANNING] - run /grant 500 --draft to continue
```

Example failed return:
```
Grant skill error for task 999:
- Task not found in state.json
- No artifacts created
- No status changes made
- Verify task exists with /task --sync
```
