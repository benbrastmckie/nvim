# Research Report: Interactive Slide Planning Workflow

- **Task**: 417 - Interactive slide planning workflow with narrative arc feedback and per-slide refinement
- **Date**: 2026-04-13
- **Status**: Complete
- **Session**: sess_1776073200_f41a7e

## Executive Summary

The current `/plan` flow for `present:slides` tasks asks three brief design questions (theme, message ordering, section emphasis) before delegating to the generic `planner-agent`. This produces a standard phase-based implementation plan that lacks slide-level granularity and gives the user no opportunity to shape the narrative arc, include/exclude individual slides, or provide per-slide feedback before the plan is committed.

This report analyzes the current architecture, identifies the gaps, and designs a replacement: a new `skill-slide-planning` skill that runs a 5-stage interactive questioning flow, and a new `slide-planner-agent` that consumes the gathered feedback to produce a detailed slide-by-slide plan.

## 1. Current Architecture Analysis

### 1.1 Routing Chain for `/plan present:slides`

```
User: /plan N
  -> orchestrator reads task_type from state.json
  -> manifest.json: plan -> present:slides -> skill-slides
  -> skill-slides (workflow_type=plan)
     -> Stage 3.5: Design Questions (D1-D3)
     -> Stage 4-5: Delegates to planner-agent via Task tool
  -> planner-agent creates generic phase-based plan
  -> skill-slides postflight (status update, artifact linking, commit)
```

### 1.2 Current Design Questions (skill-slides Stage 3.5)

The current interactive stage asks exactly three questions:

| ID | Question | Format | Stored As |
|----|----------|--------|-----------|
| D1 | Visual theme | Single-select A-E (5 themes) | `design_decisions.theme` |
| D2 | Key message ordering | Reorder 3 messages or "confirm" | `design_decisions.message_order` |
| D3 | Section emphasis | Multi-select (5 options) | `design_decisions.section_emphasis` |

**Location**: `skill-slides/SKILL.md` lines 175-273 (Stage 3.5)

### 1.3 What the Generic Planner Produces

The `planner-agent` creates a standard phase-based plan with:
- Phase decomposition (Simple: 1-2 phases, Medium: 2-4, Complex: 4-6)
- Per-phase goals, tasks, timing, dependencies
- Standard metadata (Status, Dependencies, Research Inputs, etc.)

It has no awareness of individual slides, narrative flow, or slide-specific feedback. It treats a slides task like any other task type.

### 1.4 Research Report Structure

The `slides-research-agent` produces a slide-mapped report with:
- Per-slide content mapping (type, template, content, speaker notes)
- Content gaps identification
- Recommended theme
- 3 key messages
- Full slide map following the talk pattern (e.g., conference-standard.json: 12 slides)

This report is the primary input for planning and is already well-structured for the proposed interactive flow.

## 2. Gap Analysis

### 2.1 What's Missing

| Gap | Impact | Severity |
|-----|--------|----------|
| No narrative arc review | User cannot see or shape the overall story flow before planning | High |
| No slide-level include/exclude | Optional slides auto-included; user cannot drop or add slides | High |
| No per-slide feedback | User cannot adjust content emphasis, add notes, or redirect individual slides | High |
| Generic planner output | Plan has phases but not slide-by-slide production instructions | Medium |
| Theme choice lacks preview | User picks from a list without seeing how theme affects their specific content | Low |

### 2.2 What Works Well (Keep)

- The routing through `skill-slides` for plan workflow is clean
- Research report slide map provides excellent input for interactive questions
- `design_decisions` storage in state.json is the right persistence mechanism
- Metadata file exchange pattern between skill and agent is reliable
- Postflight in skill-slides (stages 6-11) handles status, artifacts, and commits correctly

## 3. Proposed Architecture

### 3.1 New Components

| Component | Type | File Path | Purpose |
|-----------|------|-----------|---------|
| `skill-slide-planning` | Skill | `.claude/extensions/present/skills/skill-slide-planning/SKILL.md` | 5-stage interactive Q&A before plan generation |
| `slide-planner-agent` | Agent | `.claude/extensions/present/agents/slide-planner-agent.md` | Slide-aware plan generation from feedback |

### 3.2 Modified Components

| Component | Change |
|-----------|--------|
| `manifest.json` | Route `plan -> present:slides` to `skill-slide-planning` (was `skill-slides`) |
| `skill-slides/SKILL.md` | Remove Stage 3.5 (D1-D3 design questions) entirely; plan workflow routing removed |
| `present/index-entries.json` | Add entries for new skill and agent |

### 3.3 New Routing Chain

```
User: /plan N
  -> orchestrator reads task_type from state.json
  -> manifest.json: plan -> present:slides -> skill-slide-planning (NEW)
  -> skill-slide-planning runs 5-stage interactive Q&A
     -> Stage 1: Theme selection
     -> Stage 2: Narrative arc outline + feedback
     -> Stage 3: Slide picker (include/exclude)
     -> Stage 4: Per-slide detail + feedback
     -> Stage 5: Delegate to slide-planner-agent with all feedback
  -> slide-planner-agent creates slide-by-slide plan (NEW)
  -> skill-slide-planning postflight (status, artifacts, commit)
```

### 3.4 Why a Separate Skill (Not Extending skill-slides)

1. **Separation of concerns**: skill-slides handles research and assembly routing; planning is a fundamentally different workflow with heavy user interaction
2. **Complexity management**: The 5-stage interactive flow would balloon skill-slides from 487 lines to ~800+, making it harder to maintain
3. **Routing clarity**: manifest.json can route directly without workflow_type dispatch inside skill-slides
4. **Reusability**: skill-slide-planning could later support other planning variants (e.g., poster layout planning)

### 3.5 Why a Separate Agent (Not Using planner-agent)

1. **Slide-specific output**: The plan must contain per-slide production instructions, not generic phases
2. **Input structure**: The agent receives structured slide feedback (included/excluded, per-slide notes) that the generic planner has no schema for
3. **Template awareness**: The agent needs to know about talk patterns, content templates, and Vue components
4. **Plan format**: A slide plan has sections like "Slide Production Schedule" and "Per-Slide Specifications" that don't map to the generic phase model

## 4. Detailed Design: skill-slide-planning

### 4.1 Skill Metadata

```yaml
name: skill-slide-planning
description: Interactive slide planning with narrative arc review and per-slide feedback. Invoke for /plan on present:slides tasks.
allowed-tools: Task, Bash, Edit, Read, Write, AskUserQuestion
context: fork
agent: slide-planner-agent
```

### 4.2 Stage 0: Input Validation and Preflight

Same pattern as skill-slides:
- Validate task exists with task_type `present:slides` (or language `present`, task_type `slides`)
- Set status to `planning` in state.json
- Update TODO.md marker to `[PLANNING]`
- Create `.postflight-pending` marker file

### 4.3 Stage 1: Theme Selection

Read the research report to extract the recommended theme, then present choices with context.

**AskUserQuestion**:
```
The research report recommends: {recommended_theme}

Select a visual theme for your {talk_type} presentation:

A) Academic Clean -- Minimal, high-contrast, serif headings. Best for department seminars.
B) Clinical Teal -- Medical/clinical palette, clean data presentation. Best for clinical audiences.
C) Conference Bold -- Strong colors, large type, designed for projection. Best for conference talks.
D) Minimal Dark -- Dark background, high contrast, code-friendly. Best for technical audiences.
E) UCSF Institutional -- Navy/blue palette, Garamond headings. Best for UCSF presentations.

Or type a custom theme description.
```

Store as `design_decisions.theme`.

### 4.4 Stage 2: Narrative Arc Outline

Read the slide map from the research report and present the full narrative arc as a numbered outline. This is the core new capability -- the user sees the entire story flow.

**Build narrative outline** from research report slide map:
- For each slide: `{position}. [{type}] {one-line content summary}`
- Mark required vs optional slides
- Show timing estimates

**AskUserQuestion**:
```
Here is the narrative arc for your {talk_type} talk ({duration} min, {slide_count} slides):

1. [title] "{talk_title}" -- authors, affiliations, date
2. [motivation] Gap in knowledge: {summary} (REQUIRED)
3. [background] Literature context: {summary} (REQUIRED)
4. [objectives] Specific aims: {summary} (REQUIRED)
5. [methods] Study design: {summary} (REQUIRED)
6. [results-primary] Primary finding: {summary} (REQUIRED)
7. [results-secondary] Secondary outcomes: {summary} (optional)
8. [results-additional] Sensitivity analyses: {summary} (optional)
9. [discussion] Interpretation: {summary} (REQUIRED)
10. [limitations] Study limitations: {summary} (optional)
11. [conclusions] Key takeaways: {summary} (REQUIRED)
12. [acknowledgments] Funding, collaborators: {summary} (optional)

Estimated timing: ~1.5 min/slide

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
- Store as `design_decisions.narrative_arc` (the final ordered list)
- Store as `design_decisions.arc_feedback` (raw user feedback text)

### 4.5 Stage 3: Slide Picker (Include/Exclude)

Present the updated slide list (after arc feedback) as an interactive picker. Each slide is shown with slightly more detail than the arc view.

**AskUserQuestion**:
```
Review each slide and mark for inclusion. Type the numbers of slides to EXCLUDE
(all are included by default), or "all" to include everything.

 1. [title] "{talk_title}"
    Content: Authors, affiliations, conference/date

 2. [motivation] Gap in knowledge
    Content: {2-3 line preview of mapped content}

 3. [background] Literature context
    Content: {2-3 line preview}

 ...

 {N}. [acknowledgments] Funding and collaborators
    Content: {2-3 line preview}

Exclude slides (comma-separated numbers), or "all" to keep everything:
```

Store as `design_decisions.included_slides` (list of included slide positions) and `design_decisions.excluded_slides` (list of excluded slide positions).

### 4.6 Stage 4: Per-Slide Detail and Feedback

For each **included** slide, show a more detailed view and collect optional feedback. This stage uses a single consolidated AskUserQuestion to avoid excessive back-and-forth.

**Build per-slide detail view**:
```
Slide-by-slide review. For each slide, provide specific feedback or leave blank to accept as-is.

---
Slide 1: [title] "{talk_title}"
  Content: {full content mapping from research report}
  Speaker notes: {suggested talking points}
  Template: {template name}
  Feedback: ___

---
Slide 2: [motivation] Gap in knowledge
  Content: {full content mapping}
  Speaker notes: {suggested talking points}
  Template: {template name}
  Feedback: ___

...
```

**AskUserQuestion**:
```
Here are the {N} included slides in detail. For any slide you want to adjust,
type its number and your feedback. Examples:

  2: emphasize the clinical urgency more
  5: include the CONSORT diagram
  6: split into two slides, one for each primary outcome
  9: add comparison to the Smith et al. 2024 findings

Enter feedback (one per line, "done" when finished, or "looks good" for no changes):
```

Store as `design_decisions.slide_feedback` (map of slide position -> feedback text).

### 4.7 Stage 5: Delegate to slide-planner-agent

Assemble the complete delegation context:

```json
{
  "session_id": "{session_id}",
  "delegation_depth": 1,
  "delegation_path": ["orchestrator", "plan", "skill-slide-planning", "slide-planner-agent"],
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "{description}",
    "task_type": "present:slides"
  },
  "research_report_path": "specs/{NNN}_{SLUG}/reports/{MM}_slides-research.md",
  "design_decisions": {
    "theme": "{selected theme}",
    "narrative_arc": [
      {"position": 1, "type": "title", "summary": "...", "included": true},
      {"position": 2, "type": "motivation", "summary": "...", "included": true, "feedback": "..."}
    ],
    "arc_feedback": "{raw arc feedback}",
    "included_slides": [1, 2, 3, 4, 5, 6, 9, 11],
    "excluded_slides": [7, 8, 10, 12],
    "slide_feedback": {
      "2": "emphasize clinical urgency",
      "6": "split into two slides"
    }
  },
  "forcing_data": "{from state.json}",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

Invoke via **Task** tool (NOT Skill), same as current skill-slides pattern.

### 4.8 Postflight (Stages 6-10)

Identical to current skill-slides postflight:
- Stage 6: Parse metadata file
- Stage 7: Update status to `planned`
- Stage 8: Link artifacts in state.json and TODO.md
- Stage 9: Git commit
- Stage 10: Cleanup marker files, return summary

## 5. Detailed Design: slide-planner-agent

### 5.1 Agent Metadata

```yaml
name: slide-planner-agent
description: Create slide-by-slide implementation plans from interactive design feedback and research reports
model: opus
```

### 5.2 Input

The agent receives the complete delegation context from skill-slide-planning, including:
- Research report path (slide-mapped content)
- Full design decisions (theme, narrative arc, included/excluded slides, per-slide feedback)
- Forcing data (talk_type, output_format, source_materials, audience_context)

### 5.3 Context References

```
Always load:
- @.claude/context/formats/return-metadata-file.md
- @.claude/context/formats/plan-format.md

Load for slide planning:
- @.claude/extensions/present/context/project/present/patterns/talk-structure.md
- @.claude/extensions/present/context/project/present/domain/presentation-types.md
- The appropriate talk pattern JSON (conference-standard.json, etc.)
- The selected theme JSON (academic-clean.json, etc.)
```

### 5.4 Plan Output Structure

The agent produces a plan file with the standard metadata header PLUS slide-specific sections:

```markdown
# Implementation Plan: {title}

## Metadata
- **Task**: {N} - {description}
- **Status**: [NOT STARTED]
- **Type**: present:slides
- **Dependencies**: Research report {MM}_slides-research.md
- **Research Inputs**: specs/{NNN}_{SLUG}/reports/{MM}_slides-research.md
- **Artifacts**: specs/{NNN}_{SLUG}/talks/{slug}/slides.md (Slidev) or {slug}.pptx (PPTX)
- **Standards**: plan-format.md, talk-structure.md, slidev-pitfalls.md

## Goals & Non-Goals

### Goals
- Generate a {talk_type} presentation with {N} slides using {theme} theme
- Follow the user-approved narrative arc with per-slide adjustments
- {output_format}-specific goals

### Non-Goals
- Content not in scope: {excluded slides}
- Not modifying source materials

## Design Decisions Summary

- **Theme**: {theme} -- {reason}
- **Narrative arc**: {brief description of flow}
- **Excluded slides**: {list with reasons}
- **User feedback incorporated**: {count} slides with specific adjustments

## Slide Production Schedule

### Phase 1: Project Scaffold and Configuration
- **Goal**: Set up {output_format} project with {theme} theme
- **Tasks**:
  1. Copy scaffold template files
  2. Configure theme (style.css from theme JSON)
  3. Set up frontmatter with talk metadata
- **Timing**: ~10 min
- **Depends on**: None

### Phase 2: Slide Content Generation
- **Goal**: Generate all {N} included slides
- **Tasks**: (one per slide)
  1. Slide {pos}: [{type}] -- {content summary} {user feedback if any}
  2. Slide {pos}: [{type}] -- {content summary}
  ...
- **Timing**: ~3-5 min per slide
- **Depends on**: Phase 1

### Phase 3: Speaker Notes and Polish
- **Goal**: Add speaker notes, transitions, timing markers
- **Tasks**:
  1. Write speaker notes for each slide
  2. Add transition animations
  3. Verify timing targets
- **Timing**: ~15 min
- **Depends on**: Phase 2

### Phase 4: Verification
- **Goal**: Validate output and run checks
- **Tasks**:
  1. Verify all files exist
  2. Count slides matches expected
  3. Run pnpm install (Slidev) or python verification (PPTX)
- **Timing**: ~5 min
- **Depends on**: Phase 3

## Per-Slide Specifications

### Slide 1: [{type}] {title}
- **Template**: {template_path}
- **Content source**: {reference to research report section}
- **User feedback**: {feedback or "none"}
- **Vue components**: {list if any}
- **Speaker notes guidance**: {notes}

### Slide 2: [{type}] {title}
...

## Testing & Validation
- All slide files generated
- Theme applied correctly
- Speaker notes present on all slides
- Timing estimates sum to target duration
- Content gaps from research addressed or flagged

## Rollback/Contingency
- Scaffold template provides clean starting point
- Each slide is independent; failed slides don't block others
- Theme can be changed by regenerating style.css
```

### 5.5 Execution Flow

1. **Stage 0**: Initialize early metadata
2. **Stage 1**: Parse delegation context (design decisions, research path, forcing data)
3. **Stage 2**: Read research report, extract slide map
4. **Stage 3**: Load talk pattern JSON and theme JSON
5. **Stage 4**: Apply design decisions to slide map (reorder, include/exclude, merge feedback)
6. **Stage 5**: Generate plan with per-slide specifications
7. **Stage 6**: Write final metadata
8. **Stage 7**: Return brief text summary

## 6. Routing Changes

### 6.1 manifest.json Changes

```json
"plan": {
  "present": "skill-planner",
  "present:grant": "skill-planner",
  "present:budget": "skill-planner",
  "present:timeline": "skill-planner",
  "present:funds": "skill-planner",
  "present:slides": "skill-slide-planning",   // CHANGED from skill-slides
  "slides": "skill-slide-planning"             // CHANGED from skill-slides
}
```

### 6.2 skill-slides Changes

Remove Stage 3.5 entirely (lines 175-273). The plan workflow routing is no longer handled by skill-slides. Remove the `plan` case from the workflow_type routing table and delegation context. Update the trigger conditions to remove the `/plan` reference.

Specifically:
- Remove "Stage 3.5: Design Questions" section
- Remove `plan` from the workflow type routing table
- Remove `plan` case from Stage 2 preflight status, Stage 4 delegation, Stage 7 postflight, Stage 9 commit
- Update trigger conditions to remove `/plan` mention
- Update header comment to remove planner-agent reference

### 6.3 index-entries.json Additions

Add entries for the new skill and agent so context discovery works:

```json
{
  "path": "project/present/patterns/talk-structure.md",
  "load_when": {
    "agents": ["slide-planner-agent"],
    "task_types": ["present"]
  }
},
{
  "path": "project/present/domain/presentation-types.md",
  "load_when": {
    "agents": ["slide-planner-agent"],
    "task_types": ["present"]
  }
}
```

Also add `slide-planner-agent` to existing talk-related entries (theme JSONs, talk patterns, slidev-pitfalls, etc.).

### 6.4 manifest.json `provides` Updates

Add to `provides.agents`: `"slide-planner-agent.md"`
Add to `provides.skills`: `"skill-slide-planning"`

## 7. Interactive Question Design Principles

### 7.1 Minimize Round-Trips

The design uses 4 AskUserQuestion calls (theme, arc, picker, per-slide feedback). This is intentional:
- Each question builds on the previous answer
- Batching all per-slide feedback into one question avoids N round-trips
- The user can type "looks good" at any stage to accept defaults

### 7.2 Progressive Disclosure

Each stage shows progressively more detail:
1. **Theme**: One-line descriptions
2. **Arc**: One-line per slide with type tags
3. **Picker**: 2-3 line preview per slide
4. **Detail**: Full content mapping, speaker notes, template

### 7.3 Graceful Defaults

- Theme defaults to research report recommendation
- Arc defaults to pattern order (e.g., conference-standard.json)
- All slides included by default
- No feedback = accept as-is

### 7.4 Research Report as Foundation

All questions are grounded in the research report's slide map. If no research report exists, Stage 2-4 use the talk pattern JSON as a skeleton with placeholder content. The skill should warn the user that feedback will be more productive after running `/research` first.

## 8. Edge Cases

### 8.1 No Research Report

If the task has no research report (status is `not_started` or `researching`):
- Warn user: "No research report found. Run `/research {N}` first for best results."
- Fall back to talk pattern JSON for slide structure
- Theme question still works (no report recommendation, so omit that line)
- Arc outline uses pattern defaults with generic summaries
- Per-slide detail shows template descriptions instead of mapped content

### 8.2 Existing Design Decisions

If `design_decisions` already exists in state.json (from a prior `/plan` attempt):
- AskUserQuestion: "Previous design decisions found. Reuse them, or start fresh?"
- "Reuse": Skip to Stage 5 delegation
- "Start fresh": Clear and run all 4 stages

### 8.3 User Adds Slides

If the user requests additional slides in Stage 2 (e.g., "add a slide about X after 5"):
- Create a new slide entry with type "custom" and the user's description
- Assign it the next position number
- It appears in Stage 3 picker and Stage 4 detail
- The slide-planner-agent handles it as a custom content slide

### 8.4 User Removes All Optional Slides

Valid. The plan should proceed with only required slides. The narrative arc collapses to the minimal set.

### 8.5 Very Long Talks (SEMINAR: 35+ slides)

Stage 4 (per-slide feedback) could be overwhelming with 35 slides. Mitigation:
- Group slides by section (e.g., "Introduction (6 slides)", "Aim 1 (5 slides)")
- Show section summaries first, let user drill into specific slides
- Accept "section looks good" for entire groups

## 9. Implementation Effort Estimate

| Component | Effort | Notes |
|-----------|--------|-------|
| skill-slide-planning | ~300-400 lines | 5 interactive stages + postflight |
| slide-planner-agent | ~200-300 lines | Plan generation with per-slide specs |
| manifest.json update | ~5 lines | Routing change |
| skill-slides cleanup | ~-100 lines (removal) | Remove Stage 3.5 and plan workflow |
| index-entries.json | ~20 lines | Add new agent to load_when entries |
| **Total** | ~500-700 net new lines | |

## 10. Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Too many interactive questions frustrate user | Medium | "looks good" fast-path at every stage; progressive disclosure |
| Slide feedback parsing is fragile | Medium | Accept freeform text; slide-planner-agent interprets it |
| Plan format diverges from standard | Low | slide-planner-agent loads plan-format.md; includes standard metadata |
| Postflight duplication with skill-slides | Low | skill-slide-planning has its own postflight; clean separation |

## 11. Recommendations

1. **Create both components in a single implementation task** -- the skill and agent are tightly coupled
2. **Test with a CONFERENCE talk first** (12 slides) -- simplest pattern, easiest to validate
3. **Keep the Stage 4 per-slide feedback as a single question** -- resist the urge to ask per-slide individually
4. **Preserve the `design_decisions` storage pattern** in state.json -- assembly agents already read from it
5. **Add `slide-planner-agent` to the manifest `provides.agents` list** so it's discoverable
