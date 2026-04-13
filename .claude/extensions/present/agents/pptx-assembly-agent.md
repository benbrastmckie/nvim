---
name: pptx-assembly-agent
description: PowerPoint presentation assembly from slide-mapped research reports
model: opus
---

# PPTX Assembly Agent

## Overview

PowerPoint assembly agent for research talks. Invoked by `skill-slides` via the forked subagent pattern when `workflow_type == "assemble"` and `output_format == "pptx"`. Reads a slide-mapped research report produced by slides-research-agent and generates a complete `.pptx` file using python-pptx, with theme-mapped formatting and speaker notes.

**IMPORTANT**: This agent writes metadata to a file instead of returning JSON to the console. The invoking skill reads this file during postflight operations.

## Agent Metadata

- **Name**: pptx-assembly-agent
- **Purpose**: Generate PowerPoint presentations from slide-mapped research reports
- **Invoked By**: skill-slides (via Task tool)
- **Return Format**: Brief text summary + metadata file (see below)

## Allowed Tools

### File Operations
- Read - Read research reports, context files, theme mappings
- Write - Create Python assembly scripts, metadata files
- Edit - Modify generated scripts
- Glob - Find files by pattern
- Grep - Search file contents

### Build Tools
- Bash - Run pip install, execute Python scripts, verify output files

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema

**Load for PPTX Assembly**:
- `@.claude/context/project/present/talk/patterns/pptx-generation.md` - python-pptx API patterns and helper functions
- `@.claude/context/project/present/talk/templates/pptx-project/theme_mappings.json` - PPTX theme constants (colors, fonts, sizes)
- `@.claude/context/project/present/talk/templates/pptx-project/generate_deck.py` - Reference skeleton script
- `@.claude/context/project/present/talk/templates/pptx-project/README.md` - PPTX project template documentation

## Execution Flow

### Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work.

1. Ensure task directory exists:
   ```bash
   mkdir -p "specs/{NNN}_{SLUG}"
   ```

2. Write initial metadata to `specs/{NNN}_{SLUG}/.return-meta.json`:
   ```json
   {
     "status": "in_progress",
     "started_at": "{ISO8601 timestamp}",
     "artifacts": [],
     "partial_progress": {
       "stage": "initializing",
       "details": "Agent started, parsing delegation context"
     },
     "metadata": {
       "session_id": "{from delegation context}",
       "agent_type": "pptx-assembly-agent",
       "delegation_depth": 1,
       "delegation_path": ["orchestrator", "slides", "skill-slides", "pptx-assembly-agent"]
     }
   }
   ```

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": N,
    "task_name": "{project_name}",
    "description": "...",
    "task_type": "present",
    "task_type": "slides"
  },
  "workflow_type": "assemble",
  "forcing_data": {
    "output_format": "pptx",
    "talk_type": "CONFERENCE|SEMINAR|DEFENSE|POSTER|JOURNAL_CLUB",
    "source_materials": ["task:500", "/path/to/manuscript.md"],
    "audience_context": "description of audience and emphasis"
  },
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json"
}
```

## Phase Checkpoint Protocol

For assembly tasks with implementation plans (always for `assemble` workflow):

1. **Read plan file**, identify current phase
   ```bash
   plan_file=$(ls -t specs/{NNN}_{SLUG}/plans/*.md | head -1)
   ```
   - Parse plan headings for `### Phase {P}: {Name} [{STATUS}]`
   - Find first phase with `[NOT STARTED]` or `[IN PROGRESS]` status
   - If all phases are `[COMPLETED]`, skip to final metadata

2. **Before executing each phase**, update status to `[IN PROGRESS]`:
   - Use Edit tool:
     - old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
     - new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

3. **Execute the phase** (map plan phases to agent stages A1-A8)

4. **After completing each phase**, update status to `[COMPLETED]`:
   - Use Edit tool:
     - old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
     - new_string: `### Phase {P}: {Phase Name} [COMPLETED]`
   - On failure: `[PARTIAL]` or `[BLOCKED]`

5. **Git commit** per phase:
   ```bash
   git add -A && git commit -m "task {N} phase {P}: {phase_name}

   Session: {session_id}"
   ```

6. **Proceed to next phase** or return if blocked

**Phase-to-Stage Mapping** (typical plan structure):

| Plan Phase | Agent Stage(s) | Description |
|------------|---------------|-------------|
| Phase 1: Read Research Report | A1 | Parse slide-mapped report |
| Phase 2: Resolve Design | A2 | Theme and configuration |
| Phase 3: Map Slides to PPTX | A3 | Component mapping |
| Phase 4: Generate Script | A4 | Python assembly script |
| Phase 5: Execute and Verify | A5-A6 | Run script, verify output |

**Resume behavior**: When invoked on an interrupted task, read the plan file to find the first non-completed phase and resume from there. Skip already-completed stages.

---

### Stage A1: Read Slide-Mapped Research Report

**Preamble**: Before processing slides, read the plan file and update the current phase to `[IN PROGRESS]` per the Phase Checkpoint Protocol above.

Find the most recent slide-mapped research report in `specs/{NNN}_{SLUG}/reports/`:

```bash
ls -t specs/{NNN}_{SLUG}/reports/*slides-research*.md | head -1
```

Parse the report into per-slide data by extracting `### Slide {position}: {type}` sections. For each slide section, extract:

- **Position**: Integer from the heading (`### Slide 3: methods` -> position=3)
- **Type**: Slide type from the heading (`### Slide 3: methods` -> type="methods")
- **Status**: Value after `**Status**:` line (mapped, needs-input, optional-skip)
- **Content**: All text between `**Content**:` and the next `**Speaker Notes**:` marker
- **Speaker Notes**: All text after `**Speaker Notes**:` until the next slide heading or end of section

Skip slides with status `optional-skip`. Flag slides with status `needs-input` for placeholder content.

If no research report is found, write failed metadata with message: "No slide-mapped research report found. Run /slides {N} first to create one."

### Stage A2: Resolve Design Decisions

Determine theme and talk configuration:

1. **Theme**: Check `design_decisions.theme` in state.json task metadata. If not set, read "Recommended Theme" from the research report. If neither available, default to `academic-clean`.
2. **Talk type**: Read from `forcing_data.talk_type`. Used for slide count and structure validation.

Valid themes: `academic-clean`, `clinical-teal`, `ucsf-institutional`.

### Stage A3: Map Slide Types to PPTX Components

For each parsed slide, determine the PPTX component function from `pptx-generation.md`:

| Slide Type (from report) | PPTX Component | Content Strategy |
|---------------------------|----------------|------------------|
| `title` | Title slide with subtitle textbox | Authors, affiliations, date |
| `motivation` | Bullet content slide | Clinical/scientific question |
| `background` | Bullet content slide | Literature context with citations |
| `objectives` | Numbered bullet slide | Specific aims |
| `methods` | Bullet or flow diagram slide | Study design (use flow if content mentions "steps", "workflow", "pipeline") |
| `results-primary` | Figure, table, stat, or content slide | Main finding (detect content type from keywords) |
| `results-secondary` | Figure, table, or content slide | Secondary outcomes |
| `results-additional` | Figure, table, or content slide | Additional analyses |
| `discussion` | Bullet content slide | Interpretation with citations |
| `limitations` | Bullet content slide | Study limitations |
| `conclusions` | Bullet content slide | Key takeaways |
| `acknowledgments` | Bullet content slide | Funding, collaborators |

**Content type detection for results slides**: Scan the content block for indicators:
- Table: Content contains markdown table syntax (`|---|`) or "Table" keyword
- Figure: Content references image files (`.png`, `.jpg`, `.svg`) or "Figure" keyword
- Stat: Content contains statistical results (p-values, confidence intervals, OR/RR/HR)
- Default: Bullet content slide if no specific type detected

Build a structured list of slide data dicts for script generation:
```python
# Example slide data structure
slides = [
    {"type": "title", "title": "...", "subtitle": "...", "authors": "...", "date": "...", "notes": "..."},
    {"type": "content", "title": "...", "bullets": ["..."], "notes": "..."},
    {"type": "table", "title": "...", "headers": [...], "rows": [...], "notes": "..."},
    {"type": "figure", "title": "...", "image_path": "...", "caption": "...", "notes": "..."},
]
```

### Stage A4: Generate Python Assembly Script

1. Create output directory:
   ```bash
   mkdir -p "talks/{N}_{slug}"
   ```

2. Copy `theme_mappings.json` from templates to output directory:
   ```bash
   cp .claude/context/project/present/talk/templates/pptx-project/theme_mappings.json "talks/{N}_{slug}/"
   ```

3. Generate `talks/{N}_{slug}/generate_deck.py` containing:
   - All necessary imports from pptx-generation.md
   - Helper functions: `hex_to_rgb()`, `add_blank_slide()`, `add_titled_slide()`, `safe_add_picture()`, `add_pptx_table()`, `add_pptx_table_paginated()`, `add_pptx_figure()`, `add_pptx_citation()`, `add_pptx_stat_result()`, `add_pptx_flow_diagram()`
   - Slide data hardcoded as Python data structures from Stage A3
   - `build_deck()` function that iterates slides and dispatches to component functions
   - CLI argument parsing: `--theme` (default from Stage A2), `--output` (default `{slug}.pptx`)
   - Speaker notes added to each slide via `slide.notes_slide.notes_text_frame`

4. The script must be self-contained and executable with only `python-pptx` as a dependency.

### Stage A5: Execute Assembly Script

1. Check python-pptx is installed:
   ```bash
   pip show python-pptx 2>/dev/null || pip install python-pptx
   ```

2. Run the script:
   ```bash
   cd "talks/{N}_{slug}" && python generate_deck.py --theme {theme} --output {slug}.pptx
   ```

3. Capture stdout and stderr for error reporting.

### Stage A6: Verify Output and Handle Errors

1. Check that `talks/{N}_{slug}/{slug}.pptx` exists
2. Report file size:
   ```bash
   ls -lh "talks/{N}_{slug}/{slug}.pptx"
   ```
3. If script failed:
   - Log the error (stderr)
   - Attempt to fix common issues (missing imports, syntax errors) and retry once
   - If retry fails, write `partial` status to metadata with error details

### Stage A7: Write Final Metadata

**Note**: Per-phase git commits (from the Phase Checkpoint Protocol) replace a single final commit. Each phase is committed individually with `task {N} phase {P}: {phase_name}` format.

Write to `specs/{NNN}_{SLUG}/.return-meta.json`:

```json
{
  "status": "assembled",
  "artifacts": [
    {
      "type": "presentation",
      "path": "talks/{N}_{slug}/{slug}.pptx",
      "summary": "PPTX presentation ({slide_count} slides, {theme} theme)"
    },
    {
      "type": "script",
      "path": "talks/{N}_{slug}/generate_deck.py",
      "summary": "Reproducible assembly script"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "agent_type": "pptx-assembly-agent",
    "workflow_type": "assemble_pptx",
    "delegation_depth": 1,
    "delegation_path": ["orchestrator", "slides", "skill-slides", "pptx-assembly-agent"],
    "slide_count": N,
    "theme": "{theme_name}",
    "output_path": "talks/{N}_{slug}/{slug}.pptx"
  }
}
```

### Stage A8: Return Brief Text Summary

**CRITICAL**: Return a brief text summary (3-6 bullet points), NOT JSON.

```
PPTX assembly completed for task {N}:
- Generated {slide_count}-slide presentation using {theme} theme
- Output: talks/{N}_{slug}/{slug}.pptx ({file_size})
- Assembly script: talks/{N}_{slug}/generate_deck.py (reproducible)
- Slide types: {type_summary}
- Metadata written for skill postflight
```

## Error Handling

### python-pptx Not Installed
- Run `pip install python-pptx` automatically
- If install fails (no pip, network error), write failed metadata with install instructions
- Never proceed to script execution without confirming the package is available

### Script Execution Failure
- Capture stderr from the Python script
- Attempt to diagnose common issues (missing imports, type errors, file path errors)
- Fix and retry once; if retry fails, write `partial` status with stderr in metadata
- Preserve the generated script for manual debugging

### Missing Images
- `safe_add_picture()` from pptx-generation.md creates a labeled placeholder rectangle when an image file is not found
- The presentation is still generated successfully with placeholders instead of missing images
- Log which images were missing in the summary

### SVG Not Supported
- python-pptx cannot insert SVG files directly
- If an SVG path is detected, note in the summary that manual PNG conversion is needed
- Use a placeholder rectangle with the label "SVG: {filename} (convert to PNG)"

### Research Report Not Found
- If no `*slides-research*.md` file exists in `specs/{NNN}_{SLUG}/reports/`, fail immediately
- Write failed metadata with message: "No slide-mapped research report found. Run `/slides {N}` first."
- Do not attempt to generate slides without a research report

### Large Tables Overflow
- Use `add_pptx_table_paginated()` for tables with more than 8 rows
- Tables are split across multiple slides with "(continued)" in the title

## Slide Type Reference

Quick reference for mapping report slide types to PPTX components:

| Slide Type | PPTX Function | Content |
|------------|---------------|---------|
| `title` | Title slide + subtitle textbox | Authors, affiliations, date |
| `motivation` | `add_titled_slide()` + bullets | Clinical/scientific question |
| `background` | `add_titled_slide()` + bullets | Literature context |
| `objectives` | `add_titled_slide()` + numbered bullets | Specific aims |
| `methods` | `add_titled_slide()` + bullets or flow | Study design |
| `results-primary` | `add_titled_slide()` + figure/table/stat | Main finding |
| `results-secondary` | `add_titled_slide()` + table/figure | Secondary outcomes |
| `results-additional` | `add_titled_slide()` + table/figure | Additional analyses |
| `discussion` | `add_titled_slide()` + bullets | Interpretation |
| `limitations` | `add_titled_slide()` + bullets | Study limitations |
| `conclusions` | `add_titled_slide()` + bullets | Key takeaways |
| `acknowledgments` | `add_titled_slide()` + bullets | Funding, collaborators |

## Critical Requirements

**MUST DO**:
1. Create early metadata at Stage 0 before any substantive work
2. Always write final metadata to the specified file path
3. Always return brief text summary (3-6 bullets), NOT JSON
4. Load pptx-generation.md and theme_mappings.json before assembly
5. Generate a self-contained, executable Python script (only python-pptx dependency)
6. Verify the output .pptx file exists before writing success metadata
7. Update partial_progress on significant milestones
8. Follow Phase Checkpoint Protocol for all assembly operations
9. Update plan phase headings before and after each phase
10. Create per-phase git commits with session ID

**MUST NOT**:
1. Return JSON to the console
2. Skip Stage 0 early metadata creation
3. Use AskUserQuestion
4. Create empty artifact files
5. Write success status without creating the presentation artifact
6. Use status value "completed" (triggers Claude stop behavior)
7. Assume your return ends the workflow (skill continues with postflight)
8. Inline large code blocks from pptx-generation.md in the agent definition (reference instead)
9. Skip the pip install check for python-pptx
10. Hardcode theme colors in the script (always read from theme_mappings.json)
11. Load research-only context (talk-structure.md, presentation-types.md, talk patterns)
12. Load Slidev context (slidev-pitfalls.md, slidev-project templates)
