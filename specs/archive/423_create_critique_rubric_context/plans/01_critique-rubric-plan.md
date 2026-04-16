# Implementation Plan: Critique Rubric Context File

- **Task**: 423 - Create critique rubric context file
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/423_create_critique_rubric_context/reports/01_critique-rubric-research.md
- **Artifacts**: plans/01_critique-rubric-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Create a structured critique rubric context file at `.claude/extensions/present/context/project/present/talk/critique-rubric.md` that defines review criteria, severity levels, and scoring patterns for evaluating slide presentations. The rubric covers 6 categories (narrative flow, audience alignment, timing balance, content depth, evidence quality, visual design) with talk-type-specific adjustments for CONFERENCE, SEMINAR, DEFENSE, POSTER, and JOURNAL_CLUB modes. The file is designed for future consumption by a slide-critic-agent.

### Research Integration

Research report (01_critique-rubric-research.md) provided:
- Comprehensive analysis of existing talk pattern JSONs (4 modes), domain files, and theme JSONs
- External research on academic presentation rubrics confirming 6-category model
- 3-tier severity classification (critical/major/minor) aligned with code review conventions
- Detailed criteria tables for visual design, narrative flow, and per-mode priorities
- Recommended file structure: overview, severity definitions, 6 category sections, talk-type modifier table, cross-references, output format guidance

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md items directly addressed by this task. This is an extension content addition that supports the present extension's evaluation capabilities.

## Goals & Non-Goals

**Goals**:
- Define 3-tier severity system (critical/major/minor) with clear definitions and action requirements
- Define 6 rubric categories with structured criteria tables (criterion, good, problematic, severity-if-violated)
- Provide talk-type-specific priority adjustments via a modifier table referencing existing pattern JSONs
- Include cross-references to existing pattern files, theme JSONs, and domain knowledge
- Structure the file for machine readability (tables, checklists, clear headings) suitable for agent consumption

**Non-Goals**:
- Creating the slide-critic-agent itself (future task)
- Modifying existing pattern JSONs or domain files
- Adding numeric scoring scales (severity-based feedback is more actionable)
- Creating separate rubric files per talk type (modifier table approach is more maintainable)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rubric categories overlap (e.g., evidence quality vs content depth) | M | M | Define clear boundary descriptions; each criterion assigned to exactly one category |
| File becomes too long for efficient agent context loading | M | L | Target 200-300 lines; use concise table format over prose |
| Poster mode criteria diverge significantly from slide-based modes | L | H | Include a poster-specific notes subsection in the talk-type adjustments |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Create Rubric File with Core Structure [COMPLETED]

**Goal**: Create the critique-rubric.md file with overview, severity definitions, and all 6 rubric category sections.

**Tasks**:
- [ ] Create file at `.claude/extensions/present/context/project/present/talk/critique-rubric.md`
- [ ] Write overview section explaining purpose (agent-consumable critique framework)
- [ ] Define 3-tier severity system table (critical/major/minor with definitions and action requirements)
- [ ] Write Narrative Flow category: criteria table covering logical progression, story arc, transitions, glance test, section bridges
- [ ] Write Audience Alignment category: criteria table covering jargon level, assumed knowledge, engagement strategies
- [ ] Write Timing Balance category: criteria table covering slides per section, pacing, information density per minute
- [ ] Write Content Depth category: criteria table covering too shallow vs too detailed, completeness, accuracy
- [ ] Write Evidence Quality category: criteria table covering data presentation, citations, statistical reporting, claims support
- [ ] Write Visual Design category: criteria table covering text density, font sizes, figure placement, color contrast, consistency
- [ ] Include common anti-patterns list for each category

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/extensions/present/context/project/present/talk/critique-rubric.md` - create new file

**Verification**:
- File exists at target path
- All 6 categories present with criteria tables
- Severity definitions include all 3 tiers
- Tables use consistent format (criterion | good | problematic | severity)

---

### Phase 2: Add Talk-Type Adjustments and Cross-References [COMPLETED]

**Goal**: Add talk-type-specific priority modifiers and integrate with existing present extension files.

**Tasks**:
- [ ] Add talk-type priority matrix table (6 categories x 5 modes with Critical/High/Medium/Low/N-A priorities)
- [ ] Add per-mode adjustment notes for CONFERENCE (time discipline, one message per slide, figures over tables)
- [ ] Add per-mode adjustment notes for SEMINAR (research narrative arc, transitions between aims, methodology depth)
- [ ] Add per-mode adjustment notes for DEFENSE (preliminary data emphasis, pitfalls/alternatives, innovation explicitness)
- [ ] Add per-mode adjustment notes for POSTER (readability from distance, visual hierarchy, standalone comprehension)
- [ ] Add per-mode adjustment notes for JOURNAL_CLUB (objective-before-critique, discussion question quality, methodological critique)
- [ ] Add cross-references section pointing to pattern JSONs, theme JSONs, narrative-patterns.md, writing-standards.md, presentation-types.md
- [ ] Add output format guidance section (how a critic agent should structure its feedback)
- [ ] Verify file length is within 200-300 line target

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/present/context/project/present/talk/critique-rubric.md` - append sections

**Verification**:
- All 5 talk types have adjustment notes
- Priority matrix covers all 30 cells (6 categories x 5 modes)
- Cross-references point to files that exist in the codebase
- Output format section provides structured template for critique results

## Testing & Validation

- [ ] File exists at `.claude/extensions/present/context/project/present/talk/critique-rubric.md`
- [ ] All 6 rubric categories are present with criteria tables
- [ ] Severity system has 3 tiers with definitions
- [ ] All 5 talk types have specific adjustment notes
- [ ] Cross-referenced files exist in the codebase
- [ ] File length is within target range (200-300 lines)
- [ ] No prose paragraphs -- all content is in tables, lists, or short structured blocks

## Artifacts & Outputs

- `.claude/extensions/present/context/project/present/talk/critique-rubric.md` - the critique rubric context file
- `specs/423_create_critique_rubric_context/plans/01_critique-rubric-plan.md` - this plan

## Rollback/Contingency

Delete the single created file. No existing files are modified by this task.
```bash
rm .claude/extensions/present/context/project/present/talk/critique-rubric.md
```
