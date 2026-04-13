# Implementation Plan: Improve /slides Command Task Description

- **Task**: 415 - Improve /slides command task description
- **Status**: [NOT STARTED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/415_improve_slides_command_task_description/reports/01_slides-description-analysis.md
- **Artifacts**: plans/01_slides-description-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The `/slides` command in the `present/` extension produces terse, poorly structured TODO.md task entries that lack source paths, forcing data, and full audience context. This plan covers three localized edits to a single file (`.claude/extensions/present/commands/slides.md`) to bring its task description output in line with the `/deck` command's richer format. Done when the TODO.md entry includes Sources, Forcing Data Gathered sections, and the enriched description no longer truncates audience context or relativizes paths.

### Research Integration

Research report `01_slides-description-analysis.md` identified three gap areas between `/slides` and `/deck`: (1) path relativization and audience truncation in Step 2.5, (2) missing Sources and Forcing Data Gathered sections in Step 4's TODO.md template, and (3) sparse console output in Step 6. The `/deck` command's Step 5 and Step 7 serve as the reference implementation.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task does not directly advance any current ROADMAP.md items. It is a quality-of-life improvement to an extension command.

## Goals & Non-Goals

**Goals**:
- Remove path relativization from Step 2.5 so source paths stay absolute
- Remove audience truncation (`head -c 120`) from Step 2.5
- Add **Sources** section with full absolute paths to TODO.md entry in Step 4
- Add **Forcing Data Gathered** section to TODO.md entry in Step 4
- Add forcing data recap to console output in Step 6
- Change "Language" to "Task Type" in Step 6 output for consistency

**Non-Goals**:
- Changing the forcing data collection flow (Steps 1-2)
- Modifying state.json update logic (Step 3)
- Changing the git commit format (Step 5)
- Altering the recommended workflow section of output

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Markdown template formatting breaks sed insertion | M | L | Test with a sample task creation after implementation |
| Enriched description change affects state.json description field | M | L | Verify Step 3 still uses the simplified enriched_description correctly |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Simplify Step 2.5 and Expand Step 4 [NOT STARTED]

**Goal**: Clean up the enriched description and add structured sections to the TODO.md entry template.

**Tasks**:
- [ ] Edit Step 2.5 (lines 187-229): Replace the enriched description logic
  - Remove the path relativization loop (lines 214-224)
  - Remove the audience truncation line (lines 226-228)
  - Simplify the enriched_description to: `{base_description} ({talk_type} talk, {duration}, {output_format})`
  - Update the "Target format" documentation block to match
- [ ] Edit Step 4 Part B (lines 261-269): Expand the TODO.md entry template
  - Add `**Sources**:` section with full absolute paths (loop over source_materials array)
  - Add `**Forcing Data Gathered**:` section with output_format, talk_type, source_materials, and audience_context fields
  - Preserve the existing metadata fields (Effort, Status, Task Type)

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/commands/slides.md` - Lines 187-269

**Verification**:
- Step 2.5 no longer contains `git rev-parse`, `head -c 120`, or path relativization logic
- Step 4 template includes both `**Sources**:` and `**Forcing Data Gathered**:` sections
- Enriched description format is clean: `{description} ({talk_type} talk, {duration}, {output_format})`

---

### Phase 2: Enrich Step 6 Console Output [NOT STARTED]

**Goal**: Add forcing data recap to the console output and fix the "Language" label.

**Tasks**:
- [ ] Edit Step 6 (lines 282-296): Update the output template
  - Change `Language: present` to `Task Type: present`
  - Add a `Forcing Data Gathered:` block after the Output Format line, showing output_format, talk_type, sources, and audience
- [ ] Review the complete file for consistency between the three edited sections

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/commands/slides.md` - Lines 282-296

**Verification**:
- Console output shows "Task Type" instead of "Language"
- Console output includes Forcing Data Gathered block
- All three sections (Step 2.5, Step 4, Step 6) reference consistent field names

## Testing & Validation

- [ ] Read the modified file end-to-end and verify no broken markdown
- [ ] Confirm Step 2.5 enriched description no longer contains relativized paths or truncated audience
- [ ] Confirm Step 4 TODO.md template has Sources and Forcing Data Gathered sections
- [ ] Confirm Step 6 console output has forcing data recap and "Task Type" label
- [ ] Verify Step 3 (state.json update) still works with the simplified enriched_description

## Artifacts & Outputs

- `specs/415_improve_slides_command_task_description/plans/01_slides-description-plan.md` (this file)
- `.claude/extensions/present/commands/slides.md` (modified, single file)

## Rollback/Contingency

Revert with `git checkout -- .claude/extensions/present/commands/slides.md` if the changes cause issues with task creation flow.
