# Implementation Plan: Task #374

- **Task**: 374 - Update skill-founder-implement typst artifact reporting
- **Status**: [IMPLEMENTING]
- **Effort**: 0.75 hours
- **Dependencies**: 373 (completed)
- **Research Inputs**: reports/01_typst-artifact-reporting.md
- **Artifacts**: plans/01_typst-artifact-reporting.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The founder-implement skill's postflight, success messages, and expected artifacts still reflect the pre-task-373 markdown-primary model. The postflight blindly loops all artifacts without distinguishing typst from markdown, success messages list markdown first, and artifact path examples use the wrong pattern. All changes are confined to a single file (SKILL.md) with three distinct sections to update.

### Research Integration

Research report `01_typst-artifact-reporting.md` identified three sections requiring changes (Section 7 postflight lines 177-208, Return Format lines 242-283, Error Handling line 310), a field name mismatch (`typst_generated` vs `typst_source_generated`), and path template mismatches (`{slug}` vs `{report-type}-{slug}`).

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Make postflight artifact linking typst-aware, reporting `.typ` as primary and markdown as fallback
- Update success message templates to show typst source first, PDF second, markdown as fallback
- Fix artifact path examples to match agent's actual output pattern (`founder/{report-type}-{slug}.typ`)
- Correct field name reference from `metadata.typst_generated` to `metadata.typst_source_generated`

**Non-Goals**:
- Changing the agent (`founder-implement-agent.md`) -- already updated in task 373
- Modifying the actual postflight bash logic structure (loop vs explicit) -- only updating awareness
- Adding new metadata fields to the agent schema

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Path template mismatch with actual agent output | Wrong paths in success messages | Low | Use exact patterns from agent metadata schema documented in research |
| Blind artifact loop removal breaks summary linking | Missing summary in state.json | Low | Keep loop for non-report artifacts; add explicit handling only for typst/PDF/markdown |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Rewrite Postflight Artifact Linking [COMPLETED]

**Goal**: Make Section 7 postflight typst-aware by reading agent metadata fields and linking artifacts in priority order.

**Tasks**:
- [ ] Read `metadata.typst_source_generated` and `metadata.pdf_compiled` from agent return metadata in postflight
- [ ] Link `.typ` file as primary artifact (always generated when `typst_source_generated` is true)
- [ ] Conditionally link `.pdf` file only when `pdf_compiled` is true
- [ ] Link markdown file as secondary/fallback artifact
- [ ] Keep existing summary artifact linking unchanged
- [ ] Add comment explaining typst-primary artifact ordering

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` - Section 7 (lines 177-208)

**Verification**:
- Postflight pseudocode reads `typst_source_generated` and `pdf_compiled` before linking
- `.typ` artifact is linked before `.md` artifact
- PDF linking is conditional on `pdf_compiled`

---

### Phase 2: Update Return Format and Fix Field Reference [COMPLETED]

**Goal**: Rewrite success message templates to reflect typst-primary ordering and fix the `typst_generated` field name.

**Tasks**:
- [ ] Rewrite "with typst/PDF" success message (lines 246-257): show `founder/{report-type}-{slug}.typ` as primary, PDF as compiled output, markdown as fallback
- [ ] Rewrite "without typst" success message (lines 259-269): show `.typ` source as primary (always generated), note PDF skipped, markdown as fallback
- [ ] Update artifact path examples from `strategy/{slug}.md` to `founder/{report-type}-{slug}.typ` with PDF companion
- [ ] Fix line 310: change `metadata.typst_generated` to `metadata.typst_source_generated` and add references to `metadata.pdf_compiled`
- [ ] Update the note on lines 271-273 to clarify that typst source is always generated (Phase 4), only PDF compilation is optional (Phase 5)

**Timing**: 0.25 hours

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` - Return Format section (lines 242-283) and Error Handling section (line 310)

**Verification**:
- Success message with PDF shows: typst source -> PDF -> markdown (in that order)
- Success message without PDF shows: typst source -> markdown -> install suggestion
- Line 310 references `metadata.typst_source_generated` and `metadata.pdf_compiled`
- All artifact path examples use `{report-type}-{slug}` pattern

## Testing & Validation

- [ ] Verify all three sections (postflight, return format, error handling) reference `typst_source_generated` consistently
- [ ] Verify artifact path templates use `founder/{report-type}-{slug}.typ` pattern throughout
- [ ] Verify `.typ` is listed before `.md` in all artifact orderings
- [ ] Verify PDF linking is always conditional on `pdf_compiled`
- [ ] Grep SKILL.md for any remaining references to `typst_generated` (without `source_`) or `strategy/{slug}.md` (without `{report-type}-`)

## Artifacts & Outputs

- `.claude/extensions/founder/skills/skill-founder-implement/SKILL.md` (modified)

## Rollback/Contingency

Single-file change with git history. Revert with `git checkout HEAD -- .claude/extensions/founder/skills/skill-founder-implement/SKILL.md`.
