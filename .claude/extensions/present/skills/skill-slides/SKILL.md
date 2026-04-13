---
name: skill-slides
description: Research talk material synthesis, design-aware planning, and presentation assembly. Invoke for slides tasks.
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
# Subagent dispatch (resolved at Stage 4):
#   - slides-research-agent (workflow_type=slides_research)
#   - planner-agent (workflow_type=plan, via design questions pre-delegation)
#   - pptx-assembly-agent (workflow_type=assemble, output_format=pptx)
#   - slidev-assembly-agent (workflow_type=assemble, output_format=slidev)
---

# Slides Skill

Thin wrapper that routes slides tasks to one of three specialized subagents:

- **slides-research-agent** -- material synthesis into slide-mapped reports
- **planner-agent** -- design-aware implementation planning (with D1-D3 design questions)
- **pptx-assembly-agent** / **slidev-assembly-agent** -- presentation assembly by output format

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
- `/plan` on a present task with `task_type: "slides"` (plan workflow)
- `/implement` on a present task with `task_type: "slides"` (assemble workflow)
- Present extension is available

---

## Workflow Type Routing

This skill routes to a specialized subagent based on workflow type and output format:

| Workflow Type | Preflight Status | Success Status | TODO.md Markers |
|---------------|-----------------|----------------|-----------------|
| slides_research | researching | researched | [RESEARCHING] -> [RESEARCHED] |
| plan | planning | planned | [PLANNING] -> [PLANNED] |
| assemble | implementing | completed | [IMPLEMENTING] -> [COMPLETED] |

**Note**: The `plan` workflow asks interactive design questions (D1-D3) in Stage 3.5 before delegating
to planner-agent. Theme fallback chain: `design_decisions.theme` -> research report "Recommended Theme"
section -> default `academic-clean`. Design decisions are stored in state.json task metadata for use
by assembly agents.

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

**Guard**: Only execute this stage when `workflow_type == "plan"`. Skip entirely for `slides_research` and `assemble`.

```bash
if [ "$workflow_type" = "plan" ]; then
  # --- Check for existing design_decisions ---
  existing_dd=$(echo "$task_data" | jq -r '.design_decisions // empty')

  if [ -n "$existing_dd" ]; then
    # Validate schema: must have theme, message_order, section_emphasis
    has_theme=$(echo "$existing_dd" | jq -r '.theme // empty')
    has_order=$(echo "$existing_dd" | jq -r '.message_order // empty')
    has_emphasis=$(echo "$existing_dd" | jq -r '.section_emphasis // empty')

    if [ -n "$has_theme" ] && [ -n "$has_order" ] && [ -n "$has_emphasis" ]; then
      # Offer reuse
      reuse_answer=$(AskUserQuestion "Existing design decisions found:
- Theme: ${has_theme}
- Message Order: ${has_order}
- Section Emphasis: ${has_emphasis}

Reuse these decisions or reconfigure?

A) Reuse existing decisions
B) Reconfigure from scratch")

      if [ "$reuse_answer" = "A" ] || [ "$reuse_answer" = "a" ]; then
        echo "Reusing existing design_decisions."
        skip_design=true
      fi
    fi
  fi

  if [ "$skip_design" != "true" ]; then
    # --- Read research report for key messages ---
    report_path=$(ls specs/${padded_num}_${project_name}/reports/*_slides-research.md 2>/dev/null | tail -1)

    if [ -n "$report_path" ] && [ -f "$report_path" ]; then
      # Extract key messages from research report
      key_messages=$(grep -A 20 "## Key Messages\|### Key Messages" "$report_path" | head -20)
      has_report=true
    else
      key_messages=""
      has_report=false
    fi

    # --- D1: Visual Theme ---
    theme_answer=$(AskUserQuestion "Which visual theme fits best for this talk?

A) Academic Clean - Minimal, high-contrast, serif headings (department seminars)
B) Clinical Teal - Medical/clinical palette, clean data presentation (clinical audiences)
C) Conference Bold - Strong colors, large type, designed for projection (conference talks)
D) Minimal Dark - Dark background, high contrast, code-friendly (technical audiences)
E) UCSF Institutional - Navy/blue, Garamond headings (institutional branding)")

    case "$theme_answer" in
      A|a) theme="academic-clean" ;;
      B|b) theme="clinical-teal" ;;
      C|c) theme="conference-bold" ;;
      D|d) theme="minimal-dark" ;;
      E|e) theme="ucsf-institutional" ;;
      *) theme="academic-clean" ;;
    esac

    # --- D2: Key Message Ordering ---
    if [ "$has_report" = "true" ] && [ -n "$key_messages" ]; then
      message_order=$(AskUserQuestion "The research identified these key messages. Confirm or reorder:

${key_messages}

Enter the preferred order (e.g., '2, 1, 3') or 'confirm' to keep as-is.
Add any messages to emphasize or de-emphasize.")
    else
      message_order="no-report"
      echo "No research report found -- skipping message ordering (D2)."
    fi

    # --- D3: Section Emphasis ---
    section_emphasis=$(AskUserQuestion "Which sections should receive extra slides or depth?

Select all that apply:
- Methods/approach (show technical detail)
- Results/data (more data slides)
- Background/motivation (broader context)
- Clinical implications (translational focus)
- Future directions (forward-looking)

Which sections to expand?")

    # --- Store design_decisions in state.json ---
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
  fi
fi
```

**Theme fallback chain** (used by assembly agents if no explicit design_decisions):
1. `design_decisions.theme` from state.json task metadata
2. Research report "Recommended Theme" section
3. Default: `academic-clean`

---

### Stage 4: Prepare Delegation Context

```json
{
  "session_id": "sess_{timestamp}_{random}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "slides", "skill-slides"],
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

**CRITICAL**: Use the **Task** tool to spawn the subagent.

```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "slides-agent"
  - prompt: [Include task_context, delegation_context, workflow_type, forcing_data, metadata_file_path]
  - description: "Execute {workflow_type} for task {N}"
```

**DO NOT** use `Skill(slides-agent)` - this will FAIL.

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
