---
name: skill-slides
description: Research talk material synthesis, design-aware planning, and presentation assembly. Invoke for slides tasks.
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
# Subagents (dispatched by workflow_type + output_format):
#   - slides-research-agent (workflow_type=slides_research)
#   - planner-agent (workflow_type=plan, via design questions pre-delegation)
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
- `/research` on a present task with `task_type: "slides"`
- `/plan` on a present task with `task_type: "slides"` (plan workflow with design questions)
- `/implement` on a present task with `task_type: "slides"` (assemble workflow)
- Present extension is available

---

## Workflow Type Routing

This skill routes to the appropriate subagent based on workflow type and output format:

| Workflow Type | Preflight Status | Success Status | TODO.md Markers |
|---------------|-----------------|----------------|-----------------|
| slides_research | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| plan | planning | planned | [PLANNING] -> [PLANNED] |
| assemble | implementing | completed | [IMPLEMENTING] -> [COMPLETED] |

**Note**: The `plan` workflow asks interactive design questions (theme, message ordering, section
emphasis) before delegating to planner-agent. Design decisions are stored as `design_decisions` in
state.json task metadata. Assembly agents read `design_decisions.theme` with a fallback chain:
design_decisions -> research report "Recommended Theme" -> default `academic-clean`.

---

## Input Parameters

### Required Parameters
- `task_number` - Task number (must exist in state.json with language="present", task_type="slides")
- `session_id` - Session ID from orchestrator

### Optional Parameters
- `workflow_type` - One of: slides_research, plan, assemble (default: slides_research)

---

## Execution Flow

### Stage 1: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Verify language is "present" and task_type is "slides"

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
task_type=$(echo "$task_data" | jq -r '.task_type // ""')
status=$(echo "$task_data" | jq -r '.status')
project_name=$(echo "$task_data" | jq -r '.project_name')
description=$(echo "$task_data" | jq -r '.description // ""')

# Validate language and task_type
if [ "$task_type" != "present" ] || [ "$task_type" != "slides" ]; then
  return error "Task $task_number is not a slides task (language=$task_type, task_type=$task_type)"
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
  plan)
    preflight_status="planning"
    preflight_marker="[PLANNING]"
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

### Stage 3.5: Design Questions (plan workflow only)

**Skip this stage** if `workflow_type` is not `plan`.

This stage asks interactive design questions before delegating to the planner-agent. It reads the
research report to extract key messages and presents theme, ordering, and emphasis choices.

#### Step 1: Check for Existing Design Decisions

```bash
existing_dd=$(echo "$task_data" | jq -r '.design_decisions // empty')
if [ -n "$existing_dd" ]; then
  # Ask user: reuse or reconfigure?
  # AskUserQuestion: "Design decisions already exist for this task:
  #   Theme: {theme}, Message Order: {order}, Section Emphasis: {emphasis}
  #   Use existing decisions or reconfigure?"
  # If "use existing": skip to Stage 4
  # If "reconfigure": continue with D1-D3 below
fi
```

#### Step 2: Read Research Report

```bash
padded_num=$(printf "%03d" "$task_number")
report_path=$(ls -1 "specs/${padded_num}_${project_name}/reports/"*_slides-research.md 2>/dev/null | sort -V | tail -1)

# Read the research report to extract key messages, suggested structure, and themes
# Parse key messages for D2 ordering question
```

#### Step 3: Design Questions (D1-D3)

**D1: Visual Theme**

Use AskUserQuestion:

```
Based on the research report, which visual theme fits best?

A) Academic Clean - Minimal, high-contrast, serif headings (department seminars)
B) Clinical Teal - Medical/clinical palette, clean data presentation (clinical audiences)
C) Conference Bold - Strong colors, large type, designed for projection (conference talks)
D) Minimal Dark - Dark background, high contrast, code-friendly (technical audiences)
E) UCSF Institutional - Navy/blue palette, Garamond serif headings (UCSF presentations)
```

Store response as `design_decisions.theme`.

**D2: Key Message Ordering**

Present the 3 key messages identified in the research report and ask:

```
The research identified these key messages. Confirm or reorder:

1. {key_message_1}
2. {key_message_2}
3. {key_message_3}

Enter the preferred order (e.g., "2, 1, 3") or "confirm" to keep as-is.
Add any messages to emphasize or de-emphasize.
```

Store response as `design_decisions.message_order`.

**D3: Section Emphasis**

```
Which sections should receive extra slides or depth?

Select all that apply:
- Methods/approach (show technical detail)
- Results/data (more data slides)
- Background/motivation (broader context)
- Clinical implications (translational focus)
- Future directions (forward-looking)

Which sections to expand?
```

Store response as `design_decisions.section_emphasis`.

#### Step 4: Store Design Decisions

Update task metadata in state.json:

```bash
jq --arg theme "$theme" \
   --arg order "$message_order" \
   --arg emphasis "$section_emphasis" \
   --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '(.active_projects[] | select(.project_number == '$task_number')).design_decisions = {
    "theme": $theme,
    "message_order": $order,
    "section_emphasis": $emphasis,
    "confirmed_at": $ts
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json
```

---

### Stage 4: Prepare Delegation Context

Resolve the target agent based on workflow_type and output_format:

```bash
case "$workflow_type" in
  slides_research)
    target_agent="slides-research-agent"
    ;;
  plan)
    target_agent="planner-agent"
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
    "task_type": "present",
    "task_type": "slides"
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
| `plan` | any | `planner-agent` |
| `assemble` | `pptx` | `pptx-assembly-agent` |
| `assemble` | `slidev` (default) | `slidev-assembly-agent` |

**DO NOT** use `Skill(...)` - this will FAIL. Always use `Task`.

---

### Stage 6: Parse Subagent Return (Read Metadata File)

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
| plan | planned | planned | [PLANNED] |
| plan | partial | planning | [PLANNING] |
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
  plan)
    commit_action="create implementation plan"
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
