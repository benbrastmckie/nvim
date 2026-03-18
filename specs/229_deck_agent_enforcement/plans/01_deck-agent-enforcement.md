# Implementation Plan: Task #229

- **Task**: 229 - Update deck-agent with strict YC enforcement
- **Status**: [IMPLEMENTING]
- **Effort**: 3-4 hours
- **Dependencies**: Task #228 (yc-compliance-checklist.md - completed)
- **Research Inputs**: [02_deck-agent-research.md](../reports/02_deck-agent-research.md)
- **Artifacts**: plans/01_deck-agent-enforcement.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

This plan modifies `.claude/extensions/present/agents/deck-agent.md` (409 lines) to enforce YC compliance rules established in Task #228. The implementation adds slide count limits, font size minimums, layout constraints, and a compliance validation stage with `compliance_passed` boolean in return metadata. All changes are additive modifications to existing sections without restructuring the agent's 7-stage execution flow.

### Research Integration

The research report identified precise line numbers for all modification points:
- Context References (line 39): Add yc-compliance-checklist.md
- Stage 4 (lines 127-149): Insert Stage 4.5 for slide limit enforcement
- Stage 5 (lines 151-216): Add font and layout rules after line 196
- Stage 7 (lines 232-260): Add Stage 6.5 validation and modify metadata schema
- Critical Requirements (lines 389-409): Add MUST DO/NOT items

## Goals & Non-Goals

**Goals**:
- Enforce 10-slide maximum with merge priority rules
- Enforce 24pt minimum body font, 40pt minimum title font
- Enforce 2-column maximum, 5-bullet maximum per slide
- Add `yc_compliance` object to return metadata with `compliance_passed` boolean
- Reference yc-compliance-checklist.md from context section

**Non-Goals**:
- Changing the existing stage structure (preserve 7 stages, insert 4.5 and 6.5)
- Modifying existing Typst template patterns (already compliant)
- Adding visual compliance indicators to generated slides
- Automated fix-up of non-compliant content (only validation)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line numbers shift during editing | Medium | Medium | Edit bottom-to-top (Stage 7 first, then 5, then 4) |
| New sections break markdown parsing | Low | Low | Follow existing heading/list style exactly |
| Compliance checks are too strict | Medium | Low | Use HARD/SOFT distinction from checklist |
| Font size regex misses edge cases | Medium | Medium | Test with multiple generation patterns |

## Implementation Phases

### Phase 1: Add Context Reference [NOT STARTED]

**Goal**: Update Always Load section to include yc-compliance-checklist.md

**Tasks**:
- [ ] Edit line 39 to add: `- \`@context/project/present/patterns/yc-compliance-checklist.md\``

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/agents/deck-agent.md` - Add one line after line 39

**Verification**:
- Context reference appears in Always Load section
- Path is syntactically correct (@-reference format)

---

### Phase 2: Add Slide Count Enforcement (Stage 4.5) [NOT STARTED]

**Goal**: Insert new Stage 4.5 that enforces 10-slide maximum with merge priority rules

**Tasks**:
- [ ] Insert new subsection `### Stage 4.5: Enforce Slide Limit` after Stage 4 (line 149)
- [ ] Define hard limit of 10 slides (excluding appendix)
- [ ] Add merge priority table: Critical (Title, Problem, Solution, Traction, Ask), Important (Why Us/Now, Team), Mergeable (Business Model, Market, Closing)
- [ ] Document violation logging for compliance check

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/agents/deck-agent.md` - Insert new section after line 149

**Verification**:
- Stage 4.5 appears between Stage 4 and Stage 5
- Merge priority table matches YC recommendation hierarchy
- Logic handles count > 10 case

---

### Phase 3: Add Font and Layout Rules to Stage 5 [NOT STARTED]

**Goal**: Add YC compliance rules for font sizes and layouts to Stage 5

**Tasks**:
- [ ] Insert `### Font Size Rules (YC Compliance)` after line 196 (after existing text setup)
- [ ] Define minimum fonts: 40pt titles, 24pt body
- [ ] Add prohibited patterns table (size < 24pt)
- [ ] Insert `### Layout Rules (YC Compliance)` after font rules
- [ ] Define maximum columns (2), maximum bullets (5)
- [ ] Add content density rule (one idea per slide)

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/present/agents/deck-agent.md` - Insert two new subsections within Stage 5

**Verification**:
- Font size rules appear in Stage 5
- Layout rules appear after font rules
- Prohibited patterns use correct Typst syntax
- Allowed patterns demonstrate compliant alternatives

---

### Phase 4: Add Compliance Validation Stage (Stage 6.5) and Update Metadata [NOT STARTED]

**Goal**: Insert validation stage before return, add yc_compliance object to metadata

**Tasks**:
- [ ] Insert `### Stage 6.5: YC Compliance Validation` before Stage 7 (line 232)
- [ ] Define validation checklist: slide_count, font_size, column_count, bullet_count
- [ ] Add validation implementation (grep patterns for violations)
- [ ] Define compliance_passed logic (all HARD checks must pass)
- [ ] Modify Stage 7 return JSON to include `yc_compliance` object
- [ ] Add fields: `compliance_passed` (boolean), `violations` (array), `checks_performed` (array)

**Timing**: 1 hour

**Files to modify**:
- `.claude/extensions/present/agents/deck-agent.md` - Insert Stage 6.5, modify Stage 7 JSON schema

**Verification**:
- Stage 6.5 appears between Stage 6 and Stage 7
- Validation logic covers all HARD checks from checklist
- Return JSON schema includes yc_compliance object
- compliance_passed is boolean, not string

---

### Phase 5: Update Critical Requirements [NOT STARTED]

**Goal**: Add enforcement requirements to MUST DO and MUST NOT sections

**Tasks**:
- [ ] Add to MUST DO (after line 399):
  - Enforce 10-slide maximum (excluding appendix)
  - Enforce 24pt minimum body font, 40pt minimum title font
  - Enforce 2-column maximum layout
  - Include compliance_passed boolean in return metadata
  - Reference @context/project/present/patterns/yc-compliance-checklist.md for validation rules
- [ ] Add to MUST NOT (after line 408):
  - Generate font sizes below 24pt for body text
  - Generate font sizes below 40pt for titles
  - Generate 3+ column grids
  - Generate lists with more than 5 bullets
  - Return compliance_passed: true if any HARD check fails

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/agents/deck-agent.md` - Extend both lists at end of file

**Verification**:
- MUST DO list has 5 new items (numbered 9-13)
- MUST NOT list has 5 new items (numbered 8-12)
- All items reference specific limits from checklist

## Testing & Validation

- [ ] Verify deck-agent.md parses as valid markdown (no broken headings/lists)
- [ ] Verify all 9 stages present (1-4, 4.5, 5, 6, 6.5, 7)
- [ ] Verify context reference path exists: `.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md`
- [ ] Verify Stage 7 JSON example is valid JSON
- [ ] Verify grep patterns in Stage 6.5 are syntactically correct
- [ ] Count total lines (should be ~520-550 lines, increased from 409)

## Artifacts & Outputs

- `.claude/extensions/present/agents/deck-agent.md` (modified)
- `specs/229_deck_agent_enforcement/plans/01_deck-agent-enforcement.md` (this file)
- `specs/229_deck_agent_enforcement/summaries/01_deck-agent-enforcement-summary.md` (after implementation)

## Rollback/Contingency

If implementation introduces issues:
1. Restore deck-agent.md from git: `git checkout HEAD -- .claude/extensions/present/agents/deck-agent.md`
2. Partial rollback: Remove only problematic sections (Stage 4.5, 6.5) while keeping context reference
3. If compliance validation too strict: Change specific checks from HARD to SOFT (log only, don't fail)
