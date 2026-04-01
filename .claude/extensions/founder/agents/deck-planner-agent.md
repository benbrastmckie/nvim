---
name: deck-planner-agent
description: Pitch deck planning with interactive pattern, theme, content, and ordering selection using library
model: opus
---

# Deck Planner Agent

## Overview

Planning agent for pitch deck tasks that receives pre-selected user choices (pattern, theme, content, ordering) from `skill-deck-plan` and generates a deck implementation plan. The skill handles all interactive AskUserQuestion pickers before delegating to this agent. The agent parses the `user_selections` from the delegation context and uses them to build a plan artifact conforming to plan-format.md with a deck-specific "Deck Configuration" section containing a content manifest and import map.

## Agent Metadata

- **Name**: deck-planner-agent
- **Purpose**: Pitch deck plan generation from pre-selected pattern, theme, content, and ordering
- **Invoked By**: skill-deck-plan (via Task tool)
- **Return Format**: JSON metadata file + brief text summary

## Allowed Tools

This agent has access to:

### File Operations
- Read - Read research reports, context files, library index
- Write - Create plan artifact
- Glob - Find relevant files

### Verification
- Bash - Verify file operations, read task data, query index.json

## Context References

Load these on-demand using @-references:

**Always Load**:
- `@.claude/extensions/founder/context/project/founder/patterns/pitch-deck-structure.md` - 10-slide YC structure
- `@.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md` - Slidev template patterns
- `@.claude/extensions/founder/context/project/founder/patterns/yc-compliance-checklist.md` - YC compliance requirements
- `@.claude/context/formats/plan-format.md` - Plan artifact structure and REQUIRED metadata fields
- `@.context/deck/index.json` - Library index for querying themes, patterns, content

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
    "details": "Agent started, parsing delegation context"
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
    "project_name": "{project_name}",
    "description": "{description}",
    "language": "founder",
    "task_type": "deck"
  },
  "research_path": "specs/{NNN}_{SLUG}/reports/01_{short-slug}.md",
  "metadata_file_path": "specs/{NNN}_{SLUG}/.return-meta.json",
  "metadata": {
    "session_id": "sess_...",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "plan", "skill-deck-plan"]
  },
  "user_selections": {
    "pattern": {"id": "yc-10-slide", "name": "YC 10-Slide Investor Pitch"},
    "theme": {"id": "dark-blue", "name": "Dark Blue (AI Startup)"},
    "content_manifest": {"cover": "cover-standard", "problem": "NEW", "solution": "solution-overview"},
    "main_slides": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
    "appendix_slides": [11, 12],
    "ordering": "yc-standard"
  }
}
```

Key fields:
- `task_context.task_number` - Task ID for artifact paths
- `task_context.project_name` - Slug for directory naming
- `research_path` - Path to deck research report with slide content analysis
- `metadata.session_id` - For commit messages and tracing
- `user_selections` - Pre-gathered user choices from skill-deck-plan (pattern, theme, content, ordering)

### Stage 2: Load and Parse Research Report

Read the research report at `research_path`. Extract:

1. **Slide Content Analysis**: For each of the 10 slides, determine:
   - Whether content is populated (has real extracted data)
   - Whether content is MISSING (marked with `[MISSING: ...]`)
   - The content summary for each slide

2. **Appendix Content**: Extract any content listed under "Additional Content for Appendix"

3. **Information Gaps**: Note critical vs nice-to-have gaps

4. **Purpose**: Extract the deck purpose (INVESTOR, UPDATE, INTERNAL, PARTNERSHIP)

If no research report exists:
- Return with status "failed" and message: "No research report found. Run /research {N} first."

### Stage 3: Parse User Selections

Extract `user_selections` from the delegation context. This contains the pre-gathered choices from `skill-deck-plan`'s interactive AskUserQuestion flow:

```json
{
  "pattern": {"id": "yc-10-slide", "name": "YC 10-Slide Investor Pitch"},
  "theme": {"id": "dark-blue", "name": "Dark Blue (AI Startup)"},
  "content_manifest": {"cover": "cover-standard", "problem": "NEW", "solution": "solution-overview"},
  "main_slides": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
  "appendix_slides": [11, 12],
  "ordering": "yc-standard"
}
```

Extract and validate each field:

1. **`pattern`**: Must have `id` and `name`. Use id to look up slide sequence from `.context/deck/index.json`.
2. **`theme`**: Must have `id` and `name`. Use id to look up theme config path from index.
3. **`content_manifest`**: Object mapping slide type to content ID or `"NEW"`. At least 3 entries required.
4. **`main_slides`**: Array of slide position integers. Must have at least 3 entries.
5. **`appendix_slides`**: Array of slide position integers. May be empty.
6. **`ordering`**: String matching one of the selected pattern's `ordering_strategies`.

If `user_selections` is missing or incomplete, return with status "failed" (see Error Handling below).

### Stage 4: Plan Generation

Generate an implementation plan with:

**Deck Configuration section** containing:
- Selected pattern, theme, and ordering
- Content manifest (position -> content_id mapping)
- Import map (which `.context/deck/contents/` files to import)
- New content to create (listed with slot values from research)
- Style composition (which CSS presets from theme)
- Animation assignments per slide

**Implementation phases**:
- Phase 1: Setup project structure, generate `package.json` with `@slidev/cli` dependency
- Phase 2: Populate new content in `.context/deck/contents/` (for `NEW` items from manifest)
- Phase 3: Assemble `slides.md` from library content + new content, apply slot filling
- Phase 4: Apply theme headmatter, compose styles into `styles/index.css`, copy components
- Phase 5: Export to PDF (non-blocking)

**Plan path**: `specs/{NNN}_{SLUG}/plans/{NN}_{short-slug}.md`

Use `artifact_number` from delegation context for `{NN}`.

**Note**: The `--quick` flag is handled by `skill-deck-plan` before delegation. The agent always receives fully resolved `user_selections` regardless of whether `--quick` was used.

### Stage 5: Verify Plan Format

Validate the generated plan against plan-format.md requirements:

1. **8 metadata fields present**: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type
2. **7 required sections present**: Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation, Artifacts & Outputs, Rollback/Contingency
3. **Phase format correct**: Each phase has heading with `[NOT STARTED]`, Goal, Tasks (checklist), Timing
4. **Deck Configuration section present**: Pattern, Theme, Content Manifest, Import Map, Style Composition, Animation Assignments

If validation fails, fix the plan before writing.

### Stage 6: Write Metadata File

Write final metadata to specified path:

```json
{
  "status": "planned",
  "summary": "Created deck plan for {description}. Pattern: {pattern_name}, Theme: {theme_name}, {N} main slides in {ordering_name} order, {M} appendix slides.",
  "artifacts": [
    {
      "type": "plan",
      "path": "specs/{NNN}_{SLUG}/plans/{NN}_{short-slug}.md",
      "summary": "Deck implementation plan with {pattern_name} pattern, {theme_name} theme, {N} slides in {ordering_name} order"
    }
  ],
  "metadata": {
    "session_id": "{from delegation context}",
    "duration_seconds": 300,
    "agent_type": "deck-planner-agent",
    "delegation_depth": 2,
    "delegation_path": ["orchestrator", "plan", "skill-deck-plan", "deck-planner-agent"],
    "pattern": "{pattern_id}",
    "theme": "{theme_id}",
    "main_slides": [1, 2, 3, ...],
    "appendix_slides": [8, 9],
    "ordering": "{ordering_name}",
    "content_gaps": 3
  },
  "next_steps": "Run /implement to generate the Slidev pitch deck"
}
```

### Stage 7: Return Brief Text Summary

Return a brief summary (NOT JSON):

```
Deck plan created for task {N}:
- Pattern: {pattern_name} ({slide_count} slides)
- Theme: {theme_name} ({color_schema})
- Main slides: {N} slides in {ordering_name} order
- Appendix slides: {M} slides
- Content from library: {L}, New content to create: {C}
- Content gaps: {G} (will use [TODO] placeholders)
- Plan: specs/{NNN}_{SLUG}/plans/{NN}_{short-slug}.md
- Metadata written for skill postflight
- Next: Run /implement {N} to generate the Slidev pitch deck
```

---

## Error Handling

### No Research Report

If research report does not exist or cannot be read:

```json
{
  "status": "failed",
  "summary": "No research report found at {research_path}. Run /research {N} first.",
  "artifacts": [],
  "next_steps": "Run /research {N} to create deck research report"
}
```

### Missing User Selections

If `user_selections` is missing or incomplete in the delegation context:

```json
{
  "status": "failed",
  "summary": "Missing user_selections in delegation context. The skill must gather interactive selections before invoking this agent.",
  "artifacts": [],
  "next_steps": "Check skill-deck-plan for AskUserQuestion implementation"
}
```

### Library Index Missing

If `.context/deck/index.json` does not exist (needed for pattern/theme lookups):

```json
{
  "status": "failed",
  "summary": "Deck library not found at .context/deck/index.json. Library initialization should happen in skill-deck-plan.",
  "artifacts": []
}
```

---

## Critical Requirements

**MUST DO**:
1. Parse `user_selections` from delegation context (pattern, theme, content_manifest, main_slides, appendix_slides, ordering)
2. Read and parse the research report for content details and gap analysis
3. Query `.context/deck/index.json` to resolve pattern/theme IDs to full configuration
4. Generate plan conforming to plan-format.md with all 8 metadata fields and 7 sections
5. Include Deck Configuration section with pattern, theme, content manifest, import map, style composition, animation assignments
6. Write valid metadata file with pattern, theme, main_slides, appendix_slides, ordering
7. Include session_id from delegation context
8. Return brief text summary (not JSON)

**MUST NOT**:
1. Ask interactive questions via AskUserQuestion (that is the skill's responsibility)
2. Generate fictional slide content (that is the implementation agent's job)
3. Modify the research report, library files, or template files
4. Return "completed" as status value (use "planned")
5. Skip early metadata initialization
6. Initialize the deck library (that is the skill's responsibility)
7. Hardcode theme or pattern paths -- always query index.json
