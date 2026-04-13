---
name: skill-slides
description: Research talk material synthesis, design-aware planning, and presentation assembly. Invoke for slides tasks.
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
# Subagents (dispatched by workflow_type + output_format):
#   - slides-research-agent (workflow_type=slides_research)
#   - pptx-assembly-agent (workflow_type=assemble, output_format=pptx)
#   - slidev-assembly-agent (workflow_type=assemble, output_format=slidev)
# Context is loaded by each subagent independently.
# Tools (used by subagents):
#   - Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, Bash
---

# Slides Skill

Thin wrapper that delegates slides work to the appropriate subagent based on workflow type and output format:

- **slides-research-agent**: Material synthesis into slide-mapped research reports
- **pptx-assembly-agent**: PowerPoint generation from research reports
- **slidev-assembly-agent**: Slidev project generation from research reports

**Note**: Plan workflow (`/plan present:slides`) is handled by `skill-slide-planning`, not this skill.

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
- `/slides` command with task number input
- `/research` on a task with `task_type: "present:slides"`
- `/implement` on a task with `task_type: "present:slides"` (assemble workflow)
- Present extension is available

---

## Workflow Type Routing

This skill routes to the appropriate subagent based on workflow type and output format:

| Workflow Type | Preflight Status | Success Status | TODO.md Markers |
|---------------|-----------------|----------------|-----------------|
| slides_research | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| assemble | implementing | completed | [IMPLEMENTING] -> [COMPLETED] |

**Note**: Assembly agents read `design_decisions.theme` with a fallback chain:
design_decisions -> research report "Recommended Theme" -> default `academic-clean`.

---

## Input Parameters

### Required Parameters
- `task_number` - Task number (must exist in state.json with task_type="present:slides")
- `session_id` - Session ID from orchestrator

### Optional Parameters
- `workflow_type` - One of: slides_research, assemble (default: slides_research)

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Verify task_type is "present:slides"

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
task_type=$(echo "$task_data" | jq -r '.task_type // ""')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

# Validate task_type (supports "present:slides" or legacy "slides")
if [ "$task_type" != "present:slides" ] && [ "$task_type" != "slides" ]; then
  return error "Task $task_number is not a slides task (task_type=$task_type)"
fi
```

---

### Stage 2: Preflight Status Update

Update task status based on workflow type BEFORE invoking subagent.

| Workflow Type | state.json status | TODO.md marker |
|---------------|------------------|----------------|
| slides_research | researching | [RESEARCHING] |
| plan | planning | [PLANNING] |
| assemble | implementing | [IMPLEMENTING] |

```bash
# Extract output_format from forcing_data (default: "slidev" for backward compatibility)
output_format=$(echo "$task_data" | jq -r '.forcing_data.output_format // "slidev"')

case "$workflow_type" in
  slides_research)
    preflight_status="researching"
    preflight_marker="[RESEARCHING]"
    ;;
  assemble)
    preflight_status="implementing"
    preflight_marker="[IMPLEMENTING]"
    ;;
esac

# Update state.json
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

---

### Stage 3: Create Postflight Marker

```bash
padded_num=$(printf "%03d" "$task_number")
mkdir -p "specs/${padded_num}_${project_name}"

cat > "specs/${padded_num}_${project_name}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-slides",
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

Resolve the target agent based on workflow_type and output_format:

```bash
case "$workflow_type" in
  slides_research)
    target_agent="slides-research-agent"
    ;;
  assemble)
    case "$output_format" in
      pptx) target_agent="pptx-assembly-agent" ;;
      *)    target_agent="slidev-assembly-agent" ;;
    esac
    ;;
esac
```

**Delegation context**:

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "slides", "skill-slides", "{target_agent}"],
  "timeout": 3600,
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "present:slides"
  },
  "workflow_type": "slides_research|assemble",
  "output_format": "slidev|pptx (extracted from forcing_data, default: slidev)",
  "forcing_data": "{from state.json task metadata, includes output_format}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

---

### Stage 5: Invoke Subagent

**CRITICAL**: Use the **Task** tool to spawn the subagent. Use the `target_agent` resolved in Stage 4.

```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "{target_agent}"
  - prompt: [Include task_context, delegation_context, workflow_type, forcing_data, metadata_file_path]
  - description: "Execute {workflow_type} for task {N}"
```

**Routing table**:

| workflow_type | output_format | target_agent |
|---------------|---------------|--------------|
| `slides_research` | any | `slides-research-agent` |
| `assemble` | `pptx` | `pptx-assembly-agent` |
| `assemble` | `slidev` (default) | `slidev-assembly-agent` |

**DO NOT** use `Skill(...)` - this will FAIL. Always use `Task`.

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

---

### Stage 7: Update Task Status (Postflight)

| Workflow Type | Meta Status | Final state.json | Final TODO.md |
|---------------|-------------|-----------------|---------------|
| slides_research | researched | researched | [RESEARCHED] |
| slides_research | partial | researching | [RESEARCHING] |
| assemble | assembled | completed | [COMPLETED] |
| assemble | partial | implementing | [IMPLEMENTING] |
| any | failed | (keep preflight) | (keep preflight marker) |

---

### Stage 8: Link Artifacts

Add artifact to state.json with summary. Use the two-step jq pattern to avoid Issue #1132.

---

### Stage 9: Git Commit

```bash
case "$workflow_type" in
  slides_research)
    commit_action="complete slides research"
    ;;
  assemble)
    # Branch commit message on output_format
    if [ "$output_format" = "pptx" ]; then
      commit_action="assemble PPTX presentation"
    else
      commit_action="assemble Slidev presentation"
    fi
    ;;
esac

git add -A
git commit -m "task ${task_number}: ${commit_action}

Session: ${session_id}

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
```

---

### Stage 10: Cleanup

```bash
rm -f "specs/${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/${padded_num}_${project_name}/.return-meta.json"
```

---

### Stage 11: Return Brief Summary

**Talk Research Success**:
```
Talk research completed for task {N}:
- Synthesized source materials into slide-mapped report
- Talk type: {talk_type}, {slide_count} slides mapped
- Created report at specs/{NNN}_{SLUG}/reports/{MM}_slides-research.md
- Status updated to [RESEARCHED]
- Changes committed with session {session_id}
```

**Assemble Success (Slidev)**:
```
Slidev presentation assembled for task {N}:
- Output directory: talks/{N}_{slug}/
- Files created: slides.md, style.css, README.md
- Theme: {theme_name}
- Status updated to [COMPLETED]
- Changes committed with session {session_id}
```

**Assemble Success (PPTX)**:
```
PPTX presentation assembled for task {N}:
- Output directory: talks/{N}_{slug}/
- Files created: {slug}.pptx, generate_deck.py
- Theme: {theme_name}
- Status updated to [COMPLETED]
- Changes committed with session {session_id}
```

---

## Error Handling

### Task not found
```
Talk skill error for task {N}:
- Task not found in state.json
- No status changes made
```

### Wrong language/task_type
```
Talk skill error for task {N}:
- Task is not a talk task (language={language}, task_type={task_type})
- Use /slides for talk-type tasks
- No status changes made
```

### Metadata file missing
Keep status at preflight level for resume.

### Git commit failure
Non-blocking. Log failure but continue.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
