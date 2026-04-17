# Implementation Plan: Fix Documentation Regressions from Agent System Update

- **Task**: 456 - Fix documentation regressions from agent system update
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: specs/456_fix_doc_regressions_agent_system_update/reports/01_fix-doc-regressions.md
- **Artifacts**: plans/01_fix-doc-regressions.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Four documentation regressions were introduced during an agent system update that compressed several format specification files. The fixes restore missing frontmatter fields in the memory CREATE template, add two missing JSON examples to return-metadata-file.md, and restore a JSON example block plus a clarifying sentence in plan-format.md. All changes are additive (no existing content removed or rewritten).

### Research Integration

Research report 01_fix-doc-regressions.md confirmed all four regressions are present and provided exact content for each fix, including line-level locations. The plan follows the report's priority ordering and recommended changes verbatim.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This plan advances the "Agent System Quality" roadmap area by fixing documentation drift in agent format specifications. It also supports the success metric "Zero stale references to removed/renamed files in `.claude/`" by restoring content that was incorrectly removed during compression.

## Goals & Non-Goals

**Goals**:
- Restore four missing documentation elements across three files
- Ensure CREATE template in SKILL.md matches the fields extracted by JSON Index Maintenance
- Ensure return-metadata-file.md has examples for all major agent return scenarios
- Ensure plan-format.md has a concrete plan_metadata JSON example and sequential plan guidance

**Non-Goals**:
- Rewriting or restructuring the affected documentation files beyond the specific regressions
- Updating the UPDATE template in SKILL.md (preserves existing frontmatter by design)
- Addressing Finding 5 from the source report (memory_health cosmetic inconsistency -- architecture is correct)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Restored examples drift from schema over time | M | M | Examples reference fields documented in surrounding text; schema changes should update examples in same edit |
| Increased context budget usage from added lines | L | L | Total additions are approximately 80 lines across 3 files, well within budget |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2, 3 | -- |

All three phases target different files and can execute in parallel.

### Phase 1: Fix SKILL.md CREATE Template [COMPLETED]

**Goal**: Add missing `keywords`, `summary`, `retrieval_count`, and `last_retrieved` fields to the CREATE template frontmatter so it matches the JSON Index Maintenance extraction logic.

**Tasks**:
- [ ] Read `.claude/extensions/memory/skills/skill-memory/SKILL.md` to locate the CREATE template frontmatter block (around lines 360-378)
- [ ] Add four fields between the `modified` line and the closing `---`: `keywords`, `summary`, `retrieval_count`, `last_retrieved`
- [ ] Verify the added fields match the field names used in the JSON Index Maintenance section (lines 466-473)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/memory/skills/skill-memory/SKILL.md` - Add 4 frontmatter fields to CREATE template

**Verification**:
- The CREATE template frontmatter contains all fields that the JSON Index Maintenance section extracts via grep

---

### Phase 2: Add Missing Examples to return-metadata-file.md [COMPLETED]

**Goal**: Restore "Planning Success" and "Implementation Partial" JSON examples to return-metadata-file.md, bringing the example count from 3 to 5.

**Tasks**:
- [ ] Read `.claude/context/formats/return-metadata-file.md` to locate the insertion point (after the "Early Metadata" example, around line 351)
- [ ] Add "Planning Success" example section with planner-agent-specific fields (`status: "planned"`, plan artifact, planner delegation path)
- [ ] Add "Implementation Partial" example section with error recovery fields (`partial_progress`, `errors` array, `phases_completed`/`phases_total`)
- [ ] Verify JSON syntax is valid in both examples

**Timing**: 25 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/formats/return-metadata-file.md` - Add two JSON example sections (~60 lines)

**Verification**:
- File contains 5 distinct JSON examples covering: Research Success, Implementation Success, Early Metadata, Planning Success, Implementation Partial

---

### Phase 3: Fix plan-format.md JSON Example and Sequential Note [COMPLETED]

**Goal**: Add a concrete `plan_metadata` JSON example block and a clarifying sentence about sequential plans requiring wave tables.

**Tasks**:
- [ ] Read `.claude/context/formats/plan-format.md` to locate the `plan_metadata` compressed paragraph (around line 29) and the Dependency Analysis description (around line 52)
- [ ] Add `plan_metadata` JSON example block after the compressed paragraph, showing `dependency_waves` as array-of-arrays
- [ ] Add sentence to end of Dependency Analysis description: "For fully sequential plans, each wave contains one phase."
- [ ] Verify the JSON example fields match those listed in the compressed paragraph

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/formats/plan-format.md` - Add JSON example block (~15 lines) and one sentence

**Verification**:
- `plan_metadata` paragraph is followed by a JSON code block showing all fields including `dependency_waves` as `[[1], [2, 3], [4, 5]]`
- Dependency Analysis section includes guidance for sequential plans

## Testing & Validation

- [ ] All three modified files parse correctly (no broken markdown formatting)
- [ ] SKILL.md CREATE template frontmatter fields are a superset of JSON Index Maintenance extracted fields
- [ ] return-metadata-file.md JSON examples are syntactically valid
- [ ] plan-format.md JSON example matches the schema described in the preceding paragraph
- [ ] No unintended changes to surrounding content in any file

## Artifacts & Outputs

- Modified: `.claude/extensions/memory/skills/skill-memory/SKILL.md`
- Modified: `.claude/context/formats/return-metadata-file.md`
- Modified: `.claude/context/formats/plan-format.md`
- Plan: `specs/456_fix_doc_regressions_agent_system_update/plans/01_fix-doc-regressions.md`

## Rollback/Contingency

All changes are additive insertions. Rollback via `git checkout` of the three affected files. No destructive edits or dependency changes are involved.
