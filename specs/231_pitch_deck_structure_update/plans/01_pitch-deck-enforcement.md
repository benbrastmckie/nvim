# Implementation Plan: Task #231

- **Task**: 231 - Update pitch-deck-structure with mandatory enforcement
- **Status**: [COMPLETED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [01_meta-research.md](../reports/01_meta-research.md)
- **Artifacts**: plans/01_pitch-deck-enforcement.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

Update `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md` to convert advisory YC pitch deck guidelines into mandatory enforcement rules. The document currently uses soft language ("should", "avoid") which allows violations. This plan adds hard limits for content density and typography, strengthens anti-patterns to PROHIBITED status, and introduces a validation checklist for systematic compliance checking.

### Research Integration

The research report (01_meta-research.md) identified four key gaps:
- Missing content density rules (max 1 idea, max 5 bullets, max 30 words per slide)
- Missing typography enforcement (min 24pt body, min 40pt titles)
- Anti-patterns using advisory language instead of prohibition
- No validation checklist with pass/fail criteria

## Goals & Non-Goals

**Goals**:
- Convert soft guidelines to mandatory rules with hard limits
- Add Content Density Rules section with numeric thresholds
- Add Typography Enforcement section with minimum font sizes
- Strengthen Anti-Patterns to PROHIBITED status
- Add Validation Checklist section with pass/fail criteria
- Cross-reference yc-compliance-checklist.md

**Non-Goals**:
- Modifying the slide structure (9+1 slides) - already correct
- Changing the Three Design Principles philosophy
- Adding new slide types or content requirements
- Implementing automated validation tooling

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing slide generation | High | Low | Test with existing templates after changes |
| Over-restrictive rules | Medium | Medium | Keep rules aligned with YC guidance, allow edge case exceptions |
| Inconsistent enforcement language | Low | Low | Use consistent terminology (REQUIRED, PROHIBITED, HARD LIMIT) |

## Implementation Phases

### Phase 1: Add Content Density Rules Section [COMPLETED]

**Goal**: Add new section with hard limits for content per slide

**Tasks**:
- [ ] Insert "Content Density Rules" section after "Three Design Principles"
- [ ] Add maximum 1 main idea per slide rule (REQUIRED)
- [ ] Add maximum 5 bullet points per slide rule (HARD LIMIT)
- [ ] Add maximum 30 words of body text per slide rule (HARD LIMIT)
- [ ] Add prohibition on nested lists
- [ ] Mark all rules with enforcement level indicators

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md` - Add new section after line ~210

**Verification**:
- New section appears between "Three Design Principles" and "Anti-Patterns"
- All rules have enforcement level markers (REQUIRED, HARD LIMIT, PROHIBITED)

---

### Phase 2: Add Typography Enforcement Section [COMPLETED]

**Goal**: Add new section with minimum font size requirements

**Tasks**:
- [ ] Insert "Typography Enforcement" section after "Content Density Rules"
- [ ] Add minimum 24pt body text rule (HARD LIMIT)
- [ ] Add minimum 40pt title text rule (HARD LIMIT)
- [ ] Add minimum 24pt bullet text rule (HARD LIMIT)
- [ ] Add minimum 20pt for any element rule (ABSOLUTE MINIMUM)
- [ ] Include Typst-specific font size guidance

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md` - Add new section after Content Density Rules

**Verification**:
- All font size rules have numeric thresholds
- Enforcement markers are consistent with Phase 1

---

### Phase 3: Strengthen Anti-Patterns Section [COMPLETED]

**Goal**: Convert advisory anti-patterns to PROHIBITED status

**Tasks**:
- [ ] Add "PROHIBITED" marker to all Visual Anti-Patterns
- [ ] Add "PROHIBITED" marker to all Content Anti-Patterns
- [ ] Add "PROHIBITED" marker to all Structural Anti-Patterns
- [ ] Change "avoid" language to "MUST NOT" or "PROHIBITED"
- [ ] Add specific examples of violations where helpful
- [ ] Ensure consistent formatting with enforcement markers

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md` - Update Anti-Patterns section (lines ~214-236)

**Verification**:
- No remaining "avoid", "should not", or advisory language in Anti-Patterns
- All items marked as PROHIBITED
- Section header updated to indicate mandatory nature

---

### Phase 4: Add Validation Checklist Section [COMPLETED]

**Goal**: Add systematic checklist with pass/fail criteria

**Tasks**:
- [ ] Add "Validation Checklist" section after Anti-Patterns
- [ ] Create Pre-Generation Checklist (content planning phase)
- [ ] Create Post-Generation Checklist (verification phase)
- [ ] Add pass/fail criteria with clear thresholds
- [ ] Include slide-by-slide verification items
- [ ] Add cross-reference to yc-compliance-checklist.md

**Timing**: 25 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md` - Add new section before "Key Philosophy"

**Verification**:
- Checklist has clear pass/fail criteria
- All rules from Content Density and Typography sections are verifiable
- Cross-reference to yc-compliance-checklist.md is present

---

### Phase 5: Update Related Context and Verify [COMPLETED]

**Goal**: Ensure document consistency and add cross-references

**Tasks**:
- [ ] Update "Related Context" section with yc-compliance-checklist.md reference
- [ ] Review document for consistent enforcement terminology
- [ ] Verify no conflicting guidance between sections
- [ ] Ensure document flows logically with new sections

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md` - Update Related Context section (line ~250)

**Verification**:
- Related Context section includes yc-compliance-checklist.md
- Enforcement terminology is consistent throughout document
- Document reads cohesively with all new sections

## Testing & Validation

- [ ] Read final document to verify logical flow
- [ ] Check all enforcement markers are present (REQUIRED, PROHIBITED, HARD LIMIT)
- [ ] Verify Content Density Rules section has numeric thresholds
- [ ] Verify Typography Enforcement section has minimum sizes
- [ ] Verify Anti-Patterns section uses PROHIBITED language
- [ ] Verify Validation Checklist has pass/fail criteria
- [ ] Verify cross-reference to yc-compliance-checklist.md exists

## Artifacts & Outputs

- plans/01_pitch-deck-enforcement.md (this file)
- summaries/02_pitch-deck-enforcement-summary.md (after implementation)
- Modified: `.claude/extensions/present/context/project/present/patterns/pitch-deck-structure.md`

## Rollback/Contingency

If changes cause issues with existing slide generation:
1. Revert pitch-deck-structure.md using git checkout
2. Review specific rules causing conflicts
3. Adjust thresholds or add exception clauses
4. Re-implement with modifications
