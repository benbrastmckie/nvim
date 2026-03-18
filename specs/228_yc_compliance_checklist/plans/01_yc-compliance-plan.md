# Implementation Plan: Task #228

- **Task**: 228 - Add YC Compliance Checklist context file
- **Status**: [NOT STARTED]
- **Effort**: 1.5-2.5 hours
- **Dependencies**: None
- **Research Inputs**: [01_meta-research.md](../reports/01_meta-research.md), [02_yc-compliance-research.md](../reports/02_yc-compliance-research.md)
- **Artifacts**: plans/01_yc-compliance-plan.md (this file)
- **Standards**: /home/benjamin/.config/nvim/CLAUDE.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Create a comprehensive YC compliance checklist context file for the present extension that provides hard enforcement rules for validating YC-style pitch decks. The file will include measurable thresholds for font sizes, slide counts, and layout constraints based on Kevin Hale's three design principles (Legibility, Simplicity, Obviousness). The implementation follows existing patterns in the present extension (pitch-deck-structure.md, submission-checklist.md) and adds an entry to index-entries.json for automatic context loading.

### Research Integration

Key findings from research reports:

- **YC Design Principles**: Legibility (24pt body min, 40pt title min), Simplicity (max 10 slides, max 5 bullets), Obviousness (3-second comprehension)
- **Anti-Patterns Identified**: Screenshots, fonts <24pt, >2 columns, nested panels, >10 slides, jargon
- **Existing Gaps**: pitch-deck-structure.md has principles but no PASS/FAIL enforcement criteria
- **Recommended Structure**: 8 sections (Overview, Hard Limits, Soft Limits, Anti-Patterns, Typst Patterns, Pre-Flight Checklist, Post-Audit Checklist, Related Context)
- **Current Template Violations**: Example decks have 18-22pt text in places, 4-column grids on traction slides

## Goals & Non-Goals

**Goals**:
- Create enforcement-oriented context file with PASS/FAIL validation criteria
- Document specific Typst code patterns that violate YC guidelines
- Provide actionable pre-flight and post-generation checklists
- Add index entry for automatic loading by /deck command and deck-agent

**Non-Goals**:
- Modifying existing pitch-deck-structure.md or touying-pitch-deck-template.md
- Updating example deck files to comply (separate task)
- Implementing automated validation in /deck command code
- Creating new Typst library functions

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Rules too strict, rejecting valid designs | Medium | Medium | Use WARN for edge cases; FAIL only for clear violations |
| Index entry syntax error breaks extension | Low | Low | Validate JSON syntax before commit; test extension loading |
| Incomplete coverage of anti-patterns | Low | Medium | Reference research findings exhaustively; add examples |

## Implementation Phases

### Phase 1: Create Context File Structure [NOT STARTED]

**Goal**: Create the yc-compliance-checklist.md file with all 8 sections and proper markdown structure.

**Tasks**:
- [ ] Create file at `.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md`
- [ ] Write Overview section explaining purpose and enforcement scope
- [ ] Create Hard Limits table with FAIL criteria (slide count, font sizes, bullets, columns)
- [ ] Create Soft Limits table with WARN criteria (caption sizes, grid cells)
- [ ] Document Anti-Pattern Catalog organized by Visual, Content, and Structural categories

**Timing**: 0.75 hours

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md` - Create new file

**Verification**:
- File exists at specified path
- All 5 initial sections present (Overview, Hard Limits, Soft Limits, Anti-Patterns intro)
- Tables have proper markdown formatting with consistent columns
- FAIL/WARN severity levels correctly assigned per research findings

---

### Phase 2: Add Typst Patterns and Checklists [NOT STARTED]

**Goal**: Complete the context file with code examples, validation checklists, and cross-references.

**Tasks**:
- [ ] Add "Typst Patterns to Avoid" section with FAIL/PASS code examples
- [ ] Create "Pre-Flight Validation Checklist" section using checkbox format
- [ ] Create "Post-Generation Audit Checklist" section using checkbox format
- [ ] Add "Related Context" section linking to pitch-deck-structure.md and touying-pitch-deck-template.md
- [ ] Review file for completeness against research recommendations

**Timing**: 0.5 hours

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md` - Complete remaining sections

**Verification**:
- Typst code blocks have proper syntax highlighting (```typst)
- Checklist sections use [ ] checkbox format consistently
- All 8 sections present per research recommendations
- Related Context links are valid relative paths

---

### Phase 3: Update Index and Verify Integration [NOT STARTED]

**Goal**: Add the new context file to index-entries.json for automatic discovery and verify extension loading.

**Tasks**:
- [ ] Add entry to `.claude/extensions/present/index-entries.json` with proper structure
- [ ] Set load_when to trigger for languages:["deck"], agents:["deck-agent"], commands:["/deck"]
- [ ] Verify JSON syntax is valid
- [ ] Test that context discovery query returns the new file

**Timing**: 0.25 hours

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - Add new entry for yc-compliance-checklist.md

**Verification**:
- JSON parses without errors (`jq . index-entries.json`)
- Entry has all required fields (path, domain, subdomain, topics, keywords, summary, line_count, load_when)
- Query `jq '.entries[] | select(.path | contains("yc-compliance"))' index-entries.json` returns the entry
- Extension manifest.json does not require modification (context files auto-discovered via index)

---

## Testing & Validation

- [ ] Context file contains all 8 recommended sections
- [ ] Hard limits table matches research: max 10 slides, min 24pt body, min 40pt titles, max 5 bullets, max 2 columns
- [ ] Typst code examples compile conceptually (correct syntax)
- [ ] Checklists cover pre-generation and post-generation validation
- [ ] Index entry enables discovery via `jq` query
- [ ] File line count is approximately 180-220 lines (estimated)

## Artifacts & Outputs

- `.claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md` - Main deliverable
- `.claude/extensions/present/index-entries.json` - Updated with new entry

## Rollback/Contingency

If implementation causes issues:
1. Remove the new context file: `rm .claude/extensions/present/context/project/present/patterns/yc-compliance-checklist.md`
2. Revert index-entries.json to previous state: `git checkout .claude/extensions/present/index-entries.json`
3. Extension will continue functioning with existing pitch-deck-structure.md context
