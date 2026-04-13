---
name: skill-slide-planning
description: Interactive slide planning with narrative arc review and per-slide feedback. Invoke for /plan on present:slides tasks.
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
context: fork
agent: slide-planner-agent
---

# Slide Planning Skill

Interactive 5-stage Q&A skill for slide planning. Gathers theme preference, narrative arc feedback,
slide include/exclude decisions, and per-slide refinement before delegating to slide-planner-agent
for slide-by-slide plan generation.

**IMPORTANT**: This skill implements the skill-internal postflight pattern. After the subagent returns,
this skill handles all postflight operations (status update, artifact linking, git commit) before returning.

## Context References

Reference (do not load eagerly):
- Path: `.claude/context/formats/return-metadata-file.md` - Metadata file schema
- Path: `.claude/context/patterns/postflight-control.md` - Marker file protocol
- Path: `.claude/context/patterns/file-metadata-exchange.md` - File I/O helpers
- Path: `.claude/context/patterns/jq-escaping-workarounds.md` - jq escaping patterns (Issue #1132)

Note: This skill runs interactive Q&A then delegates to slide-planner-agent. Context is loaded by the agent.

## Trigger Conditions

This skill activates when:
- `/plan` on a present task with `task_type: "slides"` (or compound `present:slides`)
- Manifest routing: `plan -> present:slides -> skill-slide-planning`
- Present extension is available

---

## Input Parameters

### Required Parameters
- `task_number` - Task number (must exist in state.json with task_type containing "slides")
- `session_id` - Session ID from orchestrator

### Optional Parameters
- `plan_path` - Path to existing plan (for resume, not typically used)
- `resume_phase` - Phase to resume from (not typically used)

---

## Execution Flow

### Stage 0: Input Validation

Validate required inputs:
- `task_number` - Must be provided and exist in state.json
- Verify task_type contains "slides" (supports "present:slides", "slides", or legacy language="present" + task_type="slides")

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
forcing_data=$(echo "$task_data" | jq -r '.forcing_data // {}')
```

---

### Stage 1: Preflight Status Update

Update task status to `planning` BEFORE starting interactive flow.

```bash
padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"
mkdir -p "$task_dir"

# Update state.json
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --arg sid "$session_id" \
  '(.active_projects[] | select(.project_number == '$task_number')) |= . + {
    status: "planning",
    last_updated: $ts,
    session_id: $sid
  }' specs/state.json > specs/tmp/state.json && mv specs/tmp/state.json specs/state.json

# Update TODO.md marker to [PLANNING]
```

Create postflight marker:

```bash
cat > "${task_dir}/.postflight-pending" << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-slide-planning",
  "task_number": ${task_number},
  "operation": "plan",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

---

### Stage 2: Check for Existing Design Decisions

```bash
existing_dd=$(echo "$task_data" | jq -r '.design_decisions // empty')
if [ -n "$existing_dd" ]; then
  # AskUserQuestion:
  #   "Previous design decisions found for this task:
  #    Theme: {theme}
  #    Slides: {included count} included, {excluded count} excluded
  #    Feedback on {count} slides
  #
  #    Reuse existing decisions, or start fresh?"
  #
  # If "reuse": skip to Stage 7 (delegation)
  # If "start fresh": clear design_decisions and continue
fi
```

---

### Stage 3: Theme Selection (Interactive Stage 1)

Read the research report to extract the recommended theme:

```bash
report_path=$(ls -1 "${task_dir}/reports/"*_slides-research.md 2>/dev/null | sort -V | tail -1)
# Extract recommended theme from report (if exists)
```

**AskUserQuestion**:

```
{If report exists: "The research report recommends: {recommended_theme}\n\n"}
Select a visual theme for your {talk_type} presentation:

A) Academic Clean -- Minimal, high-contrast, serif headings. Best for department seminars.
B) Clinical Teal -- Medical/clinical palette, clean data presentation. Best for clinical audiences.
C) Conference Bold -- Strong colors, large type, designed for projection. Best for conference talks.
D) Minimal Dark -- Dark background, high contrast, code-friendly. Best for technical audiences.
E) UCSF Institutional -- Navy/blue palette, Garamond headings. Best for UCSF presentations.

Or type a custom theme description.
```

Map response to theme slug:
- A -> `academic-clean`
- B -> `clinical-teal`
- C -> `conference-bold`
- D -> `minimal-dark`
- E -> `ucsf-institutional`
- Custom text -> store as-is

Store as `design_decisions.theme`.

---

### Stage 4: Narrative Arc Outline (Interactive Stage 2)

Build the narrative outline from the research report slide map (or talk pattern if no report):

For each slide in the map:
```
{position}. [{type}] {one-line content summary} ({REQUIRED|optional})
```

**AskUserQuestion**:

```
Here is the narrative arc for your {talk_type} talk ({duration} min, {slide_count} slides):

1. [title] "{talk_title}" -- authors, affiliations, date
2. [motivation] Gap in knowledge: {summary} (REQUIRED)
3. [background] Literature context: {summary} (REQUIRED)
...
{N}. [acknowledgments] Funding, collaborators: {summary} (optional)

Estimated timing: ~{duration/slide_count} min/slide

Feedback on the narrative arc:
- Reorder? (e.g., "move 10 before 9")
- Add slides? (e.g., "add a slide about X after 5")
- Remove slides? (e.g., "remove 8")
- Change emphasis? (e.g., "expand results to 3 slides")
- Or type "looks good" to proceed as-is.
```

**Process feedback**:
- Parse reorder instructions, insertions, removals, emphasis changes
- Rebuild the slide list with changes applied
- New slides from user additions get type "custom"

Store as:
- `design_decisions.narrative_arc` - Final ordered slide list (array of objects with position, type, summary, required flag)
- `design_decisions.arc_feedback` - Raw user feedback text

---

### Stage 5: Slide Picker (Interactive Stage 3)

Present the updated slide list with 2-3 line content previews per slide.

**AskUserQuestion**:

```
Review each slide and mark for inclusion. Type the numbers of slides to EXCLUDE
(all are included by default), or "all" to include everything.

 1. [title] "{talk_title}"
    Content: Authors, affiliations, conference/date

 2. [motivation] Gap in knowledge
    Content: {2-3 line preview of mapped content}

 ...

 {N}. [acknowledgments] Funding and collaborators
    Content: {2-3 line preview}

Exclude slides (comma-separated numbers), or "all" to keep everything:
```

Parse response:
- "all" or empty -> include everything
- Comma-separated numbers -> exclude those positions

Store as:
- `design_decisions.included_slides` - List of included slide positions
- `design_decisions.excluded_slides` - List of excluded slide positions

---

### Stage 6: Per-Slide Detail and Feedback (Interactive Stage 4)

For each **included** slide, show detailed content mapping and collect optional feedback.
Uses a single consolidated AskUserQuestion to minimize round-trips.

**For long talks (20+ included slides)**: Group by section and show section summaries first. Accept "section looks good" for entire groups.

**AskUserQuestion**:

```
Here are the {N} included slides in detail. For any slide you want to adjust,
type its number and your feedback. Examples:

  2: emphasize the clinical urgency more
  5: include the CONSORT diagram
  6: split into two slides, one for each primary outcome
  9: add comparison to the Smith et al. 2024 findings

---
Slide 1: [title] "{talk_title}"
  Content: {full content mapping from research report}
  Speaker notes: {suggested talking points}
  Template: {template name}

---
Slide 2: [motivation] Gap in knowledge
  Content: {full content mapping}
  Speaker notes: {suggested talking points}
  Template: {template name}

...

Enter feedback (one per line, "done" when finished, or "looks good" for no changes):
```

Parse response:
- "looks good" or "done" with no feedback -> no changes
- Lines matching `{number}: {feedback}` -> store per-slide feedback

Store as `design_decisions.slide_feedback` (map of slide position string -> feedback text).

---

### Stage 7: Delegate to slide-planner-agent

Assemble the complete delegation context:

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "plan", "skill-slide-planning", "slide-planner-agent"],
  "task_context": {
    "task_number": "{task_number}",
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "present:slides"
  },
  "research_report_path": "{report_path}",
  "design_decisions": {
    "theme": "{selected theme}",
    "narrative_arc": [{position, type, summary, included, feedback}],
    "arc_feedback": "{raw arc feedback}",
    "included_slides": [1, 2, 3, ...],
    "excluded_slides": [7, 8, ...],
    "slide_feedback": {"2": "feedback text", ...}
  },
  "forcing_data": "{from state.json task metadata}",
  "metadata_file_path": "{task_dir}/.return-meta.json"
}
```

**CRITICAL**: Use the **Task** tool to spawn slide-planner-agent. Do NOT use `Skill(...)`.

```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "slide-planner-agent"
  - prompt: [Include full delegation context above]
  - description: "Create slide plan for task {N}"
```

Also store design decisions in state.json before delegation:

```bash
# Store design_decisions in state.json task metadata
# Use jq to update the task entry with the complete design_decisions object
```

---

### Stage 7b: Self-Execution Fallback

**CRITICAL**: If you performed the work above WITHOUT using the Task tool (i.e., you read files,
wrote artifacts, or updated metadata directly instead of spawning a subagent), you MUST write a
`.return-meta.json` file now before proceeding to postflight. Use the schema from
`return-metadata-file.md` with the appropriate status value for this operation.

If you DID use the Task tool, skip this stage -- the subagent already wrote the metadata.

---

## Postflight (ALWAYS EXECUTE)

The following stages MUST execute after work is complete, whether the work was done by a
subagent or inline (Stage 7b). Do NOT skip these stages for any reason.

### Stage 8: Read Metadata File

```bash
metadata_file="${task_dir}/.return-meta.json"

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

### Stage 9: Update Task Status (Postflight)

| Meta Status | Final state.json | Final TODO.md |
|-------------|-----------------|---------------|
| planned | planned | [PLANNED] |
| partial | planning | [PLANNING] |
| failed | (keep preflight) | (keep preflight marker) |

---

### Stage 10: Link Artifacts

Add artifact to state.json with summary. Use the two-step jq pattern to avoid Issue #1132.

---

### Stage 11: Git Commit

```bash
git add -A
git commit -m "task ${task_number}: create slide implementation plan

Session: ${session_id}"
```

---

### Stage 12: Cleanup

```bash
rm -f "${task_dir}/.postflight-pending"
rm -f "${task_dir}/.postflight-loop-guard"
rm -f "${task_dir}/.return-meta.json"
```

---

### Stage 13: Return Brief Summary

**Success**:
```
Slide planning completed for task {N}:
- Theme: {theme}
- {included_count} slides planned, {excluded_count} excluded
- {feedback_count} slides with user feedback
- Plan: specs/{NNN}_{SLUG}/plans/{MM}_slide-plan.md
- Status updated to [PLANNED]
- Changes committed with session {session_id}
```

**Partial**:
```
Slide planning partially completed for task {N}:
- Design decisions gathered but plan generation incomplete
- Run /plan {N} again to retry (existing decisions will be reusable)
```

---

## Edge Cases

### No Research Report
- Warn user at Stage 3: "No research report found. Run `/research {N}` first for best results."
- Fall back to talk pattern JSON for slide structure in Stages 4-6
- Theme question still works (omit recommendation line)
- Arc outline uses pattern defaults with generic summaries

### Existing Design Decisions
- Stage 2 asks: reuse or start fresh
- "Reuse" skips directly to Stage 7 delegation
- "Start fresh" clears existing and runs all interactive stages

### User Adds Slides in Arc Feedback
- Create new slide entries with type "custom" and user's description
- Assign next position number in sequence
- Custom slides appear in picker (Stage 5) and detail (Stage 6)

### User Removes All Optional Slides
- Valid. Proceed with required slides only.
- Note in delegation context that minimal slide set was chosen.

### Very Long Talks (35+ slides)
- Stage 6 groups slides by section (e.g., "Introduction (6 slides)", "Aim 1 (5 slides)")
- Show section summaries first
- Accept "section looks good" for entire groups

---

## Error Handling

### Task not found
```
Slide planning error for task {N}:
- Task not found in state.json
- No status changes made
```

### Wrong task type
```
Slide planning error for task {N}:
- Task is not a slides task (task_type={task_type})
- Use /plan for slides tasks routed via manifest
- No status changes made
```

### Agent metadata file missing
Keep status at preflight level (planning) for resume.

### Git commit failure
Non-blocking. Log failure but continue.

---

## Return Format

This skill returns a **brief text summary** (NOT JSON). The JSON metadata is written to the file and processed internally.
