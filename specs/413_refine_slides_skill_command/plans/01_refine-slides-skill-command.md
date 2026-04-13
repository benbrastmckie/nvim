# Implementation Plan: Task #413

**Task**: Refine slides skill and command (design questions, routing, delegation)
**Version**: 01
**Created**: 2026-04-13
**Task Type**: meta
**Estimated Effort**: 1 hour
**Research**: [01_refine-slides-skill-command.md](../reports/01_refine-slides-skill-command.md)
**Source of Truth**: Zed working copy at `/home/benjamin/.config/zed/.claude_NEW/`

## Overview

Port 8 edits to SKILL.md and 3 edits to slides.md from the Zed refined versions. All changes are textual simplifications with no behavioral or routing logic changes. The Zed files serve as exact targets for each edit.

## Files Modified

| File | Edits | Lines Changed |
|------|-------|---------------|
| `.claude/extensions/present/skills/skill-slides/SKILL.md` | 8 | ~120 removed, ~100 added |
| `.claude/extensions/present/commands/slides.md` | 3 | ~30 removed, ~50 added |

## Phases

### Phase 1: SKILL.md -- Frontmatter, Intro, and Routing Note (Changes 1-3) [COMPLETED]

**Estimated effort**: 10 minutes

**Edit 1.1**: Update frontmatter comment block (lines 5-9)

```
old_string:
# Subagent dispatch (resolved at Stage 4):
#   - slides-research-agent (workflow_type=slides_research)
#   - planner-agent (workflow_type=plan, via design questions pre-delegation)
#   - pptx-assembly-agent (workflow_type=assemble, output_format=pptx)
#   - slidev-assembly-agent (workflow_type=assemble, output_format=slidev)

new_string:
# Subagents (dispatched by workflow_type + output_format):
#   - slides-research-agent (workflow_type=slides_research)
#   - planner-agent (workflow_type=plan, via design questions pre-delegation)
#   - pptx-assembly-agent (workflow_type=assemble, output_format=pptx)
#   - slidev-assembly-agent (workflow_type=assemble, output_format=slidev)
# Context is loaded by each subagent independently.
# Tools (used by subagents):
#   - Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, Bash
```

**Edit 1.2**: Update introductory paragraph and bullet list (lines 14-18)

```
old_string:
Thin wrapper that routes slides tasks to one of three specialized subagents:

- **slides-research-agent** -- material synthesis into slide-mapped reports
- **planner-agent** -- design-aware implementation planning (with D1-D3 design questions)
- **pptx-assembly-agent** / **slidev-assembly-agent** -- presentation assembly by output format

new_string:
Thin wrapper that delegates slides work to the appropriate subagent based on workflow type and output format:

- **slides-research-agent**: Material synthesis into slide-mapped research reports
- **pptx-assembly-agent**: PowerPoint generation from research reports
- **slidev-assembly-agent**: Slidev project generation from research reports
```

**Edit 1.3**: Update trigger condition for plan workflow (line 39)

```
old_string:
- `/plan` on a present task with `task_type: "slides"` (plan workflow)

new_string:
- `/plan` on a present task with `task_type: "slides"` (plan workflow with design questions)
```

**Edit 1.4**: Update Workflow Type Routing section intro and note (lines 47, 55-58)

```
old_string:
This skill routes to a specialized subagent based on workflow type and output format:

new_string:
This skill routes to the appropriate subagent based on workflow type and output format:
```

```
old_string:
**Note**: The `plan` workflow asks interactive design questions (D1-D3) in Stage 3.5 before delegating
to planner-agent. Theme fallback chain: `design_decisions.theme` -> research report "Recommended Theme"
section -> default `academic-clean`. Design decisions are stored in state.json task metadata for use
by assembly agents.

new_string:
**Note**: The `plan` workflow asks interactive design questions (theme, message ordering, section
emphasis) before delegating to planner-agent. Design decisions are stored as `design_decisions` in
state.json task metadata. Assembly agents read `design_decisions.theme` with a fallback chain:
design_decisions -> research report "Recommended Theme" -> default `academic-clean`.
```

**Validation**: Read lines 1-62 of modified SKILL.md, compare with Zed target lines 1-62.

---

### Phase 2: SKILL.md -- Stage 3.5 Design Questions Replacement (Change 4) [COMPLETED]

**Estimated effort**: 15 minutes

This is the largest single change. Replace the entire Stage 3.5 section (lines 172-275) with the restructured 4-step prose version from the Zed target.

**Edit 2.1**: Replace Stage 3.5 guard text and entire bash block

```
old_string:
### Stage 3.5: Design Questions (plan workflow only)

**Guard**: Only execute this stage when `workflow_type == "plan"`. Skip entirely for `slides_research` and `assemble`.

```bash
if [ "$workflow_type" = "plan" ]; then
  # --- Check for existing design_decisions ---
  existing_dd=$(echo "$task_data" | jq -r '.design_decisions // empty')
  ... [entire bash block through line 274]
fi
```

**Theme fallback chain** (used by assembly agents if no explicit design_decisions):
1. `design_decisions.theme` from state.json task metadata
2. Research report "Recommended Theme" section
3. Default: `academic-clean`

new_string:
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
```

**Note**: The full old_string for Edit 2.1 spans lines 172-280 of the current file. The implementer should use Read to capture the exact text, then apply the Edit tool with the complete old_string and the new_string shown above (matching Zed target lines 175-273).

**Validation**: Read Stage 3.5 of modified file, verify 4-step structure matches Zed target.

---

### Phase 3: SKILL.md -- Agent Resolution, Delegation, Stage 5, and Return Messages (Changes 5-8) [COMPLETED]

**Estimated effort**: 15 minutes

**Edit 3.1**: Replace Stage 4 heading and agent resolution case statement (lines 284-312)

Replace the heading text:

```
old_string:
**Agent Resolution**: Determine target agent from workflow_type and output_format:

new_string:
Resolve the target agent based on workflow_type and output_format:
```

Replace the case statement:

```
old_string:
  assemble)
    if [ "$output_format" = "pptx" ]; then
      target_agent="pptx-assembly-agent"
    else
      target_agent="slidev-assembly-agent"
    fi
    ;;

new_string:
  assemble)
    case "$output_format" in
      pptx) target_agent="pptx-assembly-agent" ;;
      *)    target_agent="slidev-assembly-agent" ;;
    esac
    ;;
```

Remove the routing table immediately after the case statement (lines 306-311):

```
old_string:
| workflow_type | output_format | target_agent |
|---------------|---------------|--------------|
| slides_research | (any) | slides-research-agent |
| plan | (any) | planner-agent |
| assemble | pptx | pptx-assembly-agent |
| assemble | slidev (default) | slidev-assembly-agent |

**Delegation context**:

new_string:
```

(Remove table, keep empty line before delegation context JSON block.)

**Edit 3.2**: Simplify delegation context JSON (lines 313-334)

Remove `"design_decisions"` line from the JSON block, and change workflow_type values:

```
old_string:
  "workflow_type": "slides_research|plan|assemble",
  "output_format": "slidev|pptx (extracted from forcing_data, default: slidev)",
  "forcing_data": "{from state.json task metadata, includes output_format}",
  "design_decisions": "{from state.json task metadata, if present}",

new_string:
  "workflow_type": "slides_research|assemble",
  "output_format": "slidev|pptx (extracted from forcing_data, default: slidev)",
  "forcing_data": "{from state.json task metadata, includes output_format}",
```

**Edit 3.3**: Update Stage 5 to use target_agent reference and add routing table

Replace Stage 5 content (lines 338-357):

```
old_string:
**CRITICAL**: Use the **Task** tool to spawn the resolved `{target_agent}`.

```
Tool: Task (NOT Skill)
Parameters:
  - subagent_type: "{target_agent}"
  - prompt: [Include task_context, delegation_context, workflow_type, forcing_data, design_decisions, metadata_file_path]
  - description: "Execute {workflow_type} for task {N}"
```

| workflow_type | output_format | Spawned Agent |
|---------------|---------------|---------------|
| slides_research | (any) | slides-research-agent |
| plan | (any) | planner-agent |
| assemble | pptx | pptx-assembly-agent |
| assemble | slidev | slidev-assembly-agent |

**DO NOT** use `Skill({target_agent})` - this will FAIL. Always use the Task tool.

new_string:
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
```

**Edit 3.4**: Remove "Plan Success" return message from Stage 11 (lines 451-458)

```
old_string:
**Plan Success**:
```
Implementation plan created for task {N}:
- Design decisions confirmed (theme: {theme}, emphasis: {section_emphasis})
- Plan created at specs/{NNN}_{SLUG}/plans/{MM}_slides-plan.md
- Status updated to [PLANNED]
- Changes committed with session {session_id}
```

**Assemble Success (Slidev)**:

new_string:
**Assemble Success (Slidev)**:
```

**Validation**: Read Stages 4, 5, and 11 of modified file, compare with Zed target.

---

### Phase 4: slides.md -- Output Format Wording, Step References, and Step 2.5 Expansion (Changes 1-3) [COMPLETED]

**Estimated effort**: 15 minutes

**Edit 4.1**: Simplify output format question wording (lines 54-59)

```
old_string:
```
What output format for this presentation?

- SLIDEV (default): Browser-based slides with Slidev markdown
- PPTX: PowerPoint file via python-pptx
```

Store response as `forcing_data.output_format`. Default: `"slidev"`.

new_string:
```
What output format do you want for the presentation?

- SLIDEV (default): Slidev markdown-based slides
- PPTX: PowerPoint presentation file
```

Store response as `forcing_data.output_format`. If the user does not specify or is ambiguous, default to `"slidev"`.
```

**Edit 4.2**: Update step references in Step 3 (lines 163-167)

```
old_string:
Read the file as primary source material. Run Stage 0 forcing questions (Steps 0.0-0.3) with the file content as context. Then proceed to task creation.

**If description**:
Run Stage 0 forcing questions (Steps 0.0-0.3), then proceed to task creation.

new_string:
Read the file as primary source material. Run Stage 0 forcing questions (Steps 0.1-0.3) with the file content as context. Then proceed to task creation.

**If description**:
Run Stage 0 forcing questions (Steps 0.1-0.3), then proceed to task creation.
```

**Edit 4.3**: Move and expand Step 2.5 "Enrich Description"

Remove Step 2.5 from its current location (lines 169-193, between Step 3 and STAGE 1) and insert an expanded version within STAGE 1 (between Step 2 "Create slug" and Step 3 "Update state.json").

First, remove the old Step 2.5 block:

```
old_string:
### Step 2.5: Enrich Description

Construct an enriched description from the base description and forcing data.

**Duration lookup by talk_type**:

| talk_type | duration |
|-----------|----------|
| CONFERENCE | 15-20 min |
| SEMINAR | 45-60 min |
| DEFENSE | 30-60 min |
| POSTER | N/A |
| JOURNAL_CLUB | 15-30 min |

**Relativize source paths**: Convert absolute paths in `forcing_data.source_materials` to paths relative to the repository root.

**Audience summary**: Extract a 1-sentence summary from `forcing_data.audience_context` (e.g., "clinicians and basic scientists" or "mixed departmental audience").

**Enriched description template**:
```
{base_description}. {talk_type} talk ({duration}), {output_format} output. Source: {relative_paths}. Audience: {audience_summary}.
```

Store as `$enriched_description`. This replaces `$description` in all downstream steps.

---

## STAGE 1: TASK CREATION

new_string:
---

## STAGE 1: TASK CREATION
```

Then insert the expanded Step 2.5 after Step 2 in STAGE 1:

```
old_string:
### Step 2: Create slug from description

- Lowercase, replace spaces with underscores
- Remove special characters
- Max 50 characters

### Step 3: Update state.json

new_string:
### Step 2: Create slug from description

- Lowercase, replace spaces with underscores
- Remove special characters
- Max 50 characters

### Step 2.5: Enrich Description

Construct an enriched description incorporating forcing data:

1. Start with the base description:
   - If `input_type="description"`: use the user's original text
   - If `input_type="file_path"`: synthesize from file content (first heading or basename) and audience_context

2. Append structured details:
   - Talk type and output format: "({talk_type} talk, {output_format} format)"
   - Source materials with relative paths (strip repository root via `git rev-parse --show-toplevel`)
   - Audience context summary (first sentence or key phrase, ~20 words max)

3. The enriched description replaces `$desc` for both state.json and TODO.md.

**Path relativization**: Detect the git repository root and strip it from absolute paths. Fall back to basename for paths outside the repo.

**Target format**:
```
{base_description}. {talk_type} talk ({duration}), {output_format} output. Source: {relative_paths}. Audience: {audience_summary}.
```

```bash
# Example enrichment
repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
enriched_description="${description}. ${talk_type} talk, ${output_format} output."

# Relativize source material paths
for src in "${source_materials[@]}"; do
  if [[ "$src" == task:* ]]; then
    enriched_description="${enriched_description} Source: ${src}."
  elif [[ -n "$repo_root" && "$src" == "$repo_root"* ]]; then
    rel_path="${src#$repo_root/}"
    enriched_description="${enriched_description} Source: ${rel_path}."
  else
    enriched_description="${enriched_description} Source: $(basename "$src")."
  fi
done

# Append audience summary (first ~20 words)
audience_summary=$(echo "$audience_context" | head -c 120)
enriched_description="${enriched_description} Audience: ${audience_summary}."
```

### Step 3: Update state.json
```

**Validation**: Read STAGE 1 of modified slides.md, verify Step 2.5 is between Steps 2 and 3 with full path relativization logic.

---

### Phase 5: Final Validation [COMPLETED]

**Estimated effort**: 5 minutes

1. Read the full modified SKILL.md and compare line count with Zed target (~485 lines)
2. Read the full modified slides.md and compare line count with Zed target (~401 lines)
3. Verify no orphaned cross-references (search for "Step 0.0" in slides.md -- should not exist in step references)
4. Verify no "Plan Success" text remains in SKILL.md Stage 11
5. Verify Stage 3.5 has 4 numbered steps (Step 1 through Step 4)
6. Verify Stage 4 case statement uses nested `case` for assemble (not if/else)

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Large old_string blocks fail uniqueness check | Low | Low | Read exact text before each Edit; use sufficient context |
| Step 2.5 relocation creates orphaned references | Low | Medium | Search for "Step 2.5" references after move |
| Markdown formatting drift from Zed target | Low | Low | Line count comparison in Phase 5 |

## Dependencies

- None (all changes are isolated to two files within the present extension)

## Rollback

All edits are text-only changes to two files. Rollback via `git checkout -- .claude/extensions/present/skills/skill-slides/SKILL.md .claude/extensions/present/commands/slides.md`.
