# Implementation Plan: Update /slides Command Format

- **Task**: 406 - update_slides_command_format_enriched
- **Status**: [IMPLEMENTING]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/406_update_slides_command_format_enriched/reports/01_slides-command-format.md
- **Artifacts**: plans/01_slides-command-format.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
  - status-markers.md
  - artifact-management.md
  - tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Rewrite the `/slides` command file (`.claude/extensions/present/commands/slides.md`) to remove the `--design` flag and Stage 3 design confirmation, add output format selection (Step 0.0) and enriched description construction (Step 2.5), update the routing table, and replace hardcoded "Slidev" references with `{output_format}`. All 15 changes from DIFF.md section 2 target a single file. Research confirmed that skill-slides, manifest.json, and all agents are already in the NEW state and require no changes.

### Research Integration

The research report identified that only `slides.md` needs modification (all other present extension files are already updated). It catalogued 15 discrete changes with exact line references. The recommended bottom-to-top edit strategy preserves line numbers during sequential edits. One risk was identified: the enriched description Step 2.5 needs a duration lookup based on talk_type, which the implementation must include.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No direct roadmap items. This task is an extension maintenance change that keeps the present extension command in sync with the already-updated skill and agent files.

## Goals & Non-Goals

**Goals**:
- Remove all `--design` flag references (syntax, input types table, detection, routing)
- Delete entire Stage 3 (Design Confirmation, ~125 lines)
- Add Step 0.0 for output format selection (Slidev default vs PPTX)
- Add Step 2.5 for enriched description construction with talk_type, duration, output_format, sources, audience
- Update routing table: `/plan N` routes to `skill-slides (plan workflow)`
- Replace all hardcoded "Slidev" in output templates with `{output_format}`

**Non-Goals**:
- Modifying skill-slides/SKILL.md (already updated)
- Modifying manifest.json (already has correct routing)
- Modifying any agent files (already exist in NEW state)
- Adding new talk library context files (separate concern)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Enriched description template missing duration mapping | M | M | Include explicit talk_type-to-duration case mapping in Step 2.5 |
| Edit ordering causes line drift | L | L | Apply edits bottom-to-top as research recommends |
| Missing a `--design` reference | M | L | Grep file after edits to confirm zero remaining references |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Remove Stage 3 and Update Bottom Sections [COMPLETED]

**Goal**: Delete Stage 3 entirely and update the output format templates and routing table at the bottom of the file, working from the bottom up to preserve line numbers for later phases.

**Tasks**:
- [ ] Delete entire Stage 3: Design Confirmation section (lines 294-418, ~125 lines including the `---` separator)
- [ ] Update Output Formats section: change all "Generate Slidev presentation" to "Generate {output_format} presentation"
- [ ] Update Core Command Integration routing table: change `/plan N` from `skill-planner` to `skill-slides (plan workflow) -- Ask design questions, then delegate to planner-agent`
- [ ] Update `/implement N` description to "Generate presentation (Slidev or PPTX per output_format)"
- [ ] Update Stage 2 research output: change "Next: /slides {N} --design..." to "Next: /plan {N} (create implementation plan with design questions)"

**Timing**: 30 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/commands/slides.md` - Remove Stage 3, update routing table, update output templates, update Stage 2 output

**Verification**:
- Stage 3 heading and all content between lines 294-418 are gone
- Routing table shows `skill-slides (plan workflow)` for `/plan N`
- No remaining "Generate Slidev presentation" strings (should all be `{output_format}`)
- Stage 2 output no longer references `--design`

---

### Phase 2: Remove --design References and Add New Steps [COMPLETED]

**Goal**: Remove all `--design` flag references from the top/middle of the file, add Step 0.0 (output format selection), add Step 2.5 (enriched description), and update forcing_data.

**Tasks**:
- [ ] Update overview text (line 14): change "Slidev-based research talks" to "research talks. Output format is user-selectable: Slidev (default) or PowerPoint (PPTX)."
- [ ] Remove `/slides 500 --design` from Syntax section (line 21)
- [ ] Remove `Task number --design` row from Input Types table (line 31)
- [ ] Add new Step 0.0 (Output Format) before Step 0.1 with AskUserQuestion for SLIDEV vs PPTX, storing as `forcing_data.output_format`
- [ ] Add `"output_format": "{selected_format}"` as first field in Step 0.4 forcing_data JSON
- [ ] Remove `--design` flag detection block from Step 2 (Detect Input Type) -- the `if` branch checking for `--design`
- [ ] Remove `--design` handling paragraph from Step 3 (Handle Input Type) -- the "If --design:" block
- [ ] Add Step 2.5 (Enrich Description) after Step 2 in CHECKPOINT 1, with duration lookup table and enriched description template: `{base_description}. {talk_type} talk ({duration}), {output_format} output. Source: {relative_paths}. Audience: {audience_summary}.`
- [ ] Update Step 3 (state.json): change `$desc`/`$description` to `$enriched_description`
- [ ] Update Step 4 (TODO.md): change `{description}` to `{enriched_description}`
- [ ] Update Step 6 (Output): add `Output Format: {output_format}` line, change "Generate Slidev presentation" to "Generate {output_format} presentation"

**Timing**: 45 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/commands/slides.md` - All remaining edits from the 15-change list

**Verification**:
- Zero occurrences of `--design` in the file
- Step 0.0 exists before Step 0.1 with SLIDEV/PPTX AskUserQuestion
- Step 2.5 exists with enriched description template and duration mapping
- forcing_data includes `output_format` as first field
- state.json and TODO.md steps reference `$enriched_description`

---

### Phase 3: Validation and Cleanup [COMPLETED]

**Goal**: Verify the complete file is internally consistent and all 15 DIFF.md changes are applied.

**Tasks**:
- [ ] Grep slides.md for `--design` -- expect zero matches
- [ ] Grep slides.md for `"Slidev presentation"` (without `{output_format}`) -- expect zero matches except in the Note about PPTX conversion
- [ ] Verify Stage numbering is sequential (Stage 0, Checkpoint 1, Stage 1, Stage 2 -- no Stage 3)
- [ ] Verify Step numbering within each stage is correct (0.0, 0.1, 0.2, 0.3, 0.4 in Stage 0)
- [ ] Read the full file to confirm coherent structure and no orphaned references
- [ ] Cross-check all 15 changes from DIFF.md section 2 against the final file

**Timing**: 15 minutes

**Depends on**: 2

**Files to modify**:
- `.claude/extensions/present/commands/slides.md` - Fix any issues found during validation

**Verification**:
- All 15 DIFF.md section 2 changes confirmed applied
- File reads coherently end-to-end
- No broken references or orphaned content

## Testing & Validation

- [ ] Grep for `--design` in slides.md returns zero matches
- [ ] Grep for `Stage 3` or `STAGE 3` in slides.md returns zero matches
- [ ] Grep for `"Generate Slidev presentation"` returns zero matches (all replaced with `{output_format}`)
- [ ] Step 0.0 exists and presents SLIDEV/PPTX choice
- [ ] Step 2.5 exists with enriched description template
- [ ] Routing table shows `skill-slides` for `/plan N`
- [ ] forcing_data JSON includes `output_format` field

## Artifacts & Outputs

- `.claude/extensions/present/commands/slides.md` - Updated command file with all 15 changes applied

## Rollback/Contingency

All changes are in a single file. Rollback via `git checkout -- .claude/extensions/present/commands/slides.md` restores the original. Since the skill, agents, and manifest are already in the NEW state, the old command file is the only component lagging behind.
