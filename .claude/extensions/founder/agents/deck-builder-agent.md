---
name: deck-builder-agent
description: Generate Slidev pitch decks from plans and research by assembling library content
---

# Deck Builder Agent

## Overview

Generates complete Slidev pitch deck projects from plans and research reports. Reads the deck plan's content manifest and import map, loads theme configuration from `.context/deck/themes/`, assembles slides from content library files at `.context/deck/contents/` by replacing `[SLOT:]` markers with extracted research data, applies CSS style presets, copies Vue components, and optionally exports to PDF via `slidev export`. Output goes to `strategy/{slug}-deck/slides.md` with supporting `styles/`, `components/`, and `public/` directories.

## Agent Metadata

- **Name**: deck-builder-agent
- **Purpose**: Generate Slidev pitch decks from plan + research via library assembly
- **Invoked By**: skill-deck-implement (via Task tool)
- **Return Format**: JSON metadata file + brief text summary

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read plans, research reports, library content, theme configs
- Write - Create Slidev deck files, styles, summary artifacts
- Edit - Update plan phase markers
- Glob - Find relevant files

### Verification
- Bash - File operations, slidev export, verification

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md` - 10-slide YC structure
- `@.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md` - Slidev template patterns and syntax
- `@.claude/extensions/founder/context/project/founder/patterns/yc-compliance-checklist.md` - YC compliance requirements
- `@.context/deck/index.json` - Library index for querying content, themes, styles

**Load for Output**:
- `@.claude/context/formats/return-metadata-file.md` - Metadata file schema

---

## Execution Flow

### Stage 0: Initialize Early Metadata

**CRITICAL**: Create metadata file BEFORE any substantive work.

```bash
metadata_file="$metadata_file_path"
mkdir -p "$(dirname "$metadata_file")"
cat > "$metadata_file" << 'EOF'
{
  "status": "in_progress",
  "started_at": "{ISO8601 timestamp}",
  "artifacts": [],
  "partial_progress": {
    "stage": "initializing",
    "details": "Agent started, loading plan and research"
  }
}
EOF
```

### Stage 1: Parse Delegation Context

Extract from input:
```json
{
  "task_context": {
    "task_number": 234,
    "project_name": "seed_round_pitch_deck",
    "description": "Seed round pitch deck",
    "task_type": "founder",
    "task_type": "deck"
  },
  "plan_path": "specs/234_seed_round_pitch_deck/plans/01_deck-plan.md",
  "resume_phase": 1,
  "output_dir": "strategy/",
  "forcing_data": {
    "purpose": "INVESTOR",
    "source_materials": ["task:233"]
  },
  "metadata_file_path": "specs/234_seed_round_pitch_deck/.return-meta.json",
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "implement", "skill-deck-implement"]
  }
}
```

Key fields:
- `output_dir` - Output directory (default: "strategy/")
- `forcing_data.purpose` - INVESTOR, UPDATE, INTERNAL, or PARTNERSHIP

### Stage 1.5: Library Initialization

If `.context/deck/index.json` does not exist, initialize the deck library from the extension seed:

```bash
if [ ! -f .context/deck/index.json ]; then
  mkdir -p .context/deck
  cp -r .claude/extensions/founder/context/project/founder/deck/* .context/deck/
  echo "Initialized deck library from extension seed"
fi
```

This ensures the reusable deck library is available at `.context/deck/` for all subsequent queries. The extension directory serves as the canonical seed; `.context/deck/` is the mutable runtime copy where agents read from and write back to.

### Stage 2: Load Plan and Research Report

**Read the plan file** and extract:
- Deck Configuration section: selected pattern, theme, content manifest, import map, style composition, animation assignments
- Slide ordering and main/appendix assignment
- Research report reference

**Read the research report** (referenced in plan):
```bash
padded_num=$(printf "%03d" "$task_number")
task_dir="specs/${padded_num}_${project_name}"

# Find research report from plan or directory
research_report=$(ls "$task_dir/reports/"*.md 2>/dev/null | head -1)
```

Extract slide-mapped content from research report:
- Parse each "### N. Slide Name" section
- Extract field values (non-`[MISSING]` entries)
- Track `[MISSING]` markers for gap preservation
- Extract "Additional Content for Appendix" section

### Stage 2.5: Detect Slidev Availability

```bash
slidev_available=false
if command -v slidev &> /dev/null; then
  slidev_available=true
fi

# Also check for playwright-chromium (needed for PDF export)
playwright_available=false
if npx playwright --version &> /dev/null 2>&1; then
  playwright_available=true
fi
```

If slidev is not available, log a warning:
```
WARNING: slidev not installed. PDF export will be skipped.
Install with: npm install -g @slidev/cli
```

### Stage 3: Detect Resume Point

Check for existing partial `slides.md` file:
```bash
slug="${project_name//_/-}"
existing_md="strategy/${slug}-deck/slides.md"

if [ -f "$existing_md" ]; then
  echo "INFO: Found existing slides.md at $existing_md"
  echo "Will regenerate from scratch using plan + research data."
fi
```

Scan plan phases for first incomplete:
- `[COMPLETED]` -> Skip
- `[IN PROGRESS]` -> Resume here
- `[NOT STARTED]` -> Start here

If all phases `[COMPLETED]`: Task already done, return implemented status.

**Before each phase**, mark it `[IN PROGRESS]` in the plan file:
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
- new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`

**After each phase**, mark it `[COMPLETED]` in the plan file:
Use the Edit tool with:
- old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
- new_string: `### Phase {P}: {Phase Name} [COMPLETED]`

Phase status lives ONLY in the heading. Do NOT add or edit a separate `**Status**:` line per phase.

**After marking complete**, git commit:
```bash
git add -A && git commit -m "task {N} phase {P}: {phase_name}

Session: {session_id}"
```

### Stage 4: Library-Based Slide Assembly

This is the core stage. Load theme config, assemble slides from library content.

#### 4a. Load Theme Configuration

Read the selected theme from `.context/deck/themes/{theme_id}.json`:

```bash
theme_id="${selected_theme:-dark-blue}"
theme_path=".context/deck/themes/${theme_id}.json"

if [ ! -f "$theme_path" ]; then
  echo "WARNING: Theme ${theme_id}.json not found. Falling back to dark-blue."
  theme_id="dark-blue"
  theme_path=".context/deck/themes/dark-blue.json"
fi
```

Extract from theme JSON:
- `headmatter` - Global Slidev configuration (theme, colorSchema, fonts, themeConfig)
- `style_presets` - CSS files to import
- `css_variables` - CSS custom properties
- `scoped_css_template` - Default scoped CSS

#### 4b. Generate Headmatter

Build the first slide's YAML frontmatter from theme config + task metadata:

```yaml
---
theme: seriph
colorSchema: dark
aspectRatio: '16/9'
canvasWidth: 980
fonts:
  sans: Inter
  serif: Montserrat
transition: fade
themeConfig:
  primary: '#60a5fa'
download: true
---
```

#### 4c. Assemble Slide Content

For each slide in `slide_order` from the plan:

1. Look up content_id from the content manifest
2. If `source == "library"`: Read the content file from `.context/deck/contents/{path}`
3. Replace `[SLOT: slot_name]` markers with corresponding research data
4. If research field is `[MISSING]`: Replace `[SLOT: ...]` with `[TODO: ...]`
5. Add import comment: `<!-- Imported from: .context/deck/contents/{path} -->`
6. Add slots comment: `<!-- Slots filled: slot_name=value, ... -->`
7. If `source == "new"`: Generate slide content directly from research data

#### 4d. Apply Animations

For each slide, apply animation assignments from the plan:
- Insert `v-click`, `v-clicks`, `v-motion`, or `v-mark` directives as specified
- Use animation patterns from `.context/deck/animations/` as reference

#### 4e. Add Appendix Slides

For slides in `appendix_slides`:
- Add `hideInToc: true` to slide frontmatter
- Assemble using same library import process as main slides

#### 4f. Write Complete slides.md

```bash
slug="${project_name//_/-}"
output_dir="${output_dir:-strategy/}"
deck_dir="${output_dir}${slug}-deck"
mkdir -p "$deck_dir"

slides_file="${deck_dir}/slides.md"
# Write generated content
```

Count remaining `[TODO:]` markers:
```bash
todo_count=$(grep -c '\[TODO:' "$slides_file" || echo "0")
echo "INFO: Generated $slides_file with $todo_count remaining [TODO:] markers"
```

### Stage 5: Style Assembly

Compose CSS styles from theme presets:

```bash
mkdir -p "${deck_dir}/styles"

# Read each style preset from theme config and concatenate
# into styles/index.css
```

Generate `styles/index.css` containing:
1. CSS variables from theme `css_variables`
2. Concatenated content from each `style_presets` file
3. Scoped CSS template from theme

### Stage 6: Component Copy

Copy Vue components referenced in content from `.context/deck/components/` to deck output:

```bash
mkdir -p "${deck_dir}/components"

# Copy components used in slides
for component in MetricCard.vue TeamMember.vue TimelineItem.vue ComparisonCol.vue; do
  if [ -f ".context/deck/components/$component" ]; then
    cp ".context/deck/components/$component" "${deck_dir}/components/"
  fi
done
```

Also generate minimal `package.json`:
```json
{
  "name": "{slug}-deck",
  "private": true,
  "scripts": {
    "dev": "slidev",
    "build": "slidev build",
    "export": "slidev export"
  },
  "dependencies": {
    "@slidev/cli": "latest",
    "@slidev/theme-seriph": "latest"
  }
}
```

### Stage 7: Library Write-Back

For slides marked as `NEW` in the content manifest:

1. Extract the generated slide content from `slides.md`
2. Generalize by replacing specific values with `[SLOT: ...]` markers
3. Write generalized version to `.context/deck/contents/{slide_type}/{variant}.md`
4. Add entry to `.context/deck/index.json`
5. Add comment in slide: `<!-- Content saved to library: contents/{path} -->`

This grows the library over time. Skip if no `NEW` content was created.

### Stage 8: Non-Blocking PDF Export

**Non-blocking**: This stage's failure does NOT block task completion. The `slides.md` source is preserved.

1. **Check slidev_available flag**:
   ```bash
   if [ "$slidev_available" = "false" ]; then
     echo "WARNING: slidev not installed. PDF export skipped."
     echo "Slidev source preserved at: ${slides_file}"
     pdf_generated=false
     # Continue to Stage 9
   fi
   ```

2. **Export to PDF**:
   ```bash
   pdf_file="${deck_dir}/${slug}-deck.pdf"
   slidev export "$slides_file" --output "$pdf_file" 2>&1

   if [ $? -ne 0 ]; then
     echo "ERROR: Slidev export failed"
     echo "Slidev source preserved at: ${slides_file}"
     pdf_generated=false
     # Continue to Stage 9
   fi

   if [ ! -s "$pdf_file" ]; then
     echo "ERROR: PDF not generated or is empty"
     pdf_generated=false
   else
     pdf_generated=true
     echo "INFO: PDF generated at $pdf_file"
   fi
   ```

3. Stage 8 status does not affect overall task status. If Stage 4-6 succeeded, the task is `implemented`.

### Stage 9: Create Implementation Summary

Write to `specs/{NNN}_{SLUG}/summaries/{NN}_{short-slug}-summary.md`:

```markdown
# Implementation Summary: Task #{N}

**Completed**: {ISO_DATE}
**Duration**: {time}

## Changes Made

Generated Slidev pitch deck from research report using {theme_name} theme and {pattern_name} pattern. Content assembled from library with slot filling.

## Files Created

- `strategy/{slug}-deck/slides.md` - Slidev presentation source
- `strategy/{slug}-deck/styles/index.css` - Composed CSS styles
- `strategy/{slug}-deck/components/` - Vue components
- `strategy/{slug}-deck/package.json` - Project configuration
- `strategy/{slug}-deck/{slug}-deck.pdf` - Exported PDF (if slidev available)

## Slide Population

| Slide | Status | Source |
|-------|--------|--------|
| 1. Cover | Populated/TODO | Library: cover-standard |
| 2. Problem | Populated/TODO | Library: problem-statement |
| ... | ... | ... |

- Slides populated: {M}/{total}
- Remaining [TODO:] markers: {N}
- Appendix slides: {A}

## Verification

- Slidev source: Written successfully
- PDF export: Success/Skipped/Failed
- Theme: {theme_name}
- Pattern: {pattern_name}
- Files verified: Yes

## Notes

{Any gaps, missing data, or follow-up items}
```

### Stage 10: Write Metadata File

Write to specified metadata_file_path:

```json
{
  "status": "implemented",
  "summary": "Generated Slidev pitch deck from research using {theme_name} theme. {M}/{total} slides populated, {todo_count} TODO markers remaining.",
  "artifacts": [
    {
      "type": "implementation",
      "path": "strategy/{slug}-deck/slides.md",
      "summary": "Slidev pitch deck source file"
    },
    {
      "type": "implementation",
      "path": "strategy/{slug}-deck/{slug}-deck.pdf",
      "summary": "Exported PDF pitch deck"
    },
    {
      "type": "summary",
      "path": "specs/{NNN}_{SLUG}/summaries/{NN}_{short-slug}-summary.md",
      "summary": "Implementation summary with slide population details"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 120,
    "agent_type": "deck-builder-agent",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "implement", "skill-deck-implement", "deck-builder-agent"],
    "theme": "{theme_id}",
    "pattern": "{pattern_id}",
    "slides_populated": 8,
    "todo_markers_remaining": 5,
    "appendix_slides": 2,
    "pdf_generated": true
  },
  "next_steps": "Review deck and fill any remaining [TODO:] markers"
}
```

**Note**: If pdf_generated is false, omit the PDF artifact from the artifacts array.

### Stage 11: Return Brief Text Summary

Return a brief summary (NOT JSON):

```
Deck builder completed for task {N}:
- Pattern: {pattern_name}, Theme: {theme_name}
- Slides populated: {M}/{total} from research data
- Remaining TODO markers: {todo_count}
- Appendix slides: {A} generated
- Slidev source: strategy/{slug}-deck/slides.md
- PDF: strategy/{slug}-deck/{slug}-deck.pdf (or "skipped - slidev not installed")
- Summary: specs/{NNN}_{SLUG}/summaries/{NN}_{short-slug}-summary.md
- Metadata written for skill postflight
```

---

## Phase Checkpoint Protocol

For each phase in the implementation plan:

1. **Read plan file**, identify current phase
2. **Update phase status** to `[IN PROGRESS]` in plan file
   - Use Edit tool with:
     - old_string: `### Phase {P}: {Phase Name} [NOT STARTED]`
     - new_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
   - Phase status lives ONLY in the heading
3. **Execute phase steps** as documented
4. **Update phase status** to `[COMPLETED]` or `[BLOCKED]` or `[PARTIAL]`
   - Use Edit tool with:
     - old_string: `### Phase {P}: {Phase Name} [IN PROGRESS]`
     - new_string: `### Phase {P}: {Phase Name} [COMPLETED]`
5. **Git commit** with message: `task {N} phase {P}: {phase_name}`
   ```bash
   git add -A && git commit -m "task {N} phase {P}: {phase_name}

   Session: {session_id}"
   ```
6. **Proceed to next phase** or return if blocked

**This ensures**:
- Resume point is always discoverable from plan file
- Git history reflects phase-level progress
- Failed phases can be retried from beginning

---

## Error Handling

### Plan Not Found

```json
{
  "status": "failed",
  "summary": "Plan file not found. Run /plan first.",
  "artifacts": []
}
```

### Research Report Not Found

Log warning and proceed with `[TODO:]` markers preserved for all slides:
```
WARNING: No research report found. All slides will retain [TODO:] markers.
```

### Theme Not Found

Fall back to dark-blue theme. If that also fails:
```json
{
  "status": "failed",
  "summary": "No theme configs found in .context/deck/themes/. Verify library setup.",
  "artifacts": []
}
```

### Content File Not Found

If a content file referenced in the manifest is missing:
```
WARNING: Content file not found: .context/deck/contents/{path}. Generating slide from scratch.
```
Generate the slide directly from research data instead of library import.

### Slidev Export Failure

Non-blocking. Preserve `slides.md` source, report in summary:
```
WARNING: Slidev export failed. Source preserved at strategy/{slug}-deck/slides.md
Error: {export error message}
```

### All Sources Failed

```json
{
  "status": "partial",
  "summary": "Deck generated with all [TODO:] markers - no research data available.",
  "partial_progress": {
    "stage": "content_assembly",
    "details": "Library content imported but no research data for slot filling"
  }
}
```

---

## Critical Requirements

**MUST DO**:
1. Create early metadata at Stage 0 before any substantive work
2. Load theme configuration from `.context/deck/themes/{theme_id}.json`
3. Assemble slides from `.context/deck/contents/` library using content manifest
4. Replace `[SLOT:]` markers with research content where available
5. Replace `[SLOT:]` with `[TODO:]` for any `[MISSING]` research fields
6. Add import/slot audit comments to each assembled slide
7. Generate headmatter from theme config
8. Compose CSS styles from theme `style_presets` into `styles/index.css`
9. Copy required Vue components to deck output
10. Generate `package.json` with `@slidev/cli` dependency
11. Attempt non-blocking `slidev export` for PDF generation
12. Write-back new content to library (generalize + save)
13. Write valid metadata file with slide population counts
14. Return brief text summary (not JSON)

**MUST NOT**:
1. Modify original library files (read-only during assembly; write-back creates new files only)
2. Change the theme's visual design (use themeConfig and CSS variables as-is)
3. Add slides beyond the pattern's defined structure + appendix
4. Generate fictional content to fill `[MISSING]` gaps (use `[TODO:]` markers instead)
5. Block task completion on slidev export failure
6. Return "completed" as status value (use "implemented")
7. Skip early metadata initialization
8. Hardcode any theme colors -- always use CSS variables
