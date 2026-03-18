# Implementation Plan: Task #230

- **Task**: 230 - Update touying-pitch-deck-template with simpler layouts
- **Status**: [COMPLETED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [01_meta-research.md](../reports/01_meta-research.md)
- **Artifacts**: plans/01_template-simplification.md (this file)
- **Standards**:
  - .claude/context/core/standards/plan.md
  - .claude/context/core/standards/status-markers.md
  - .claude/context/core/system/artifact-management.md
  - .claude/context/core/standards/tasks.md
- **Type**: meta

## Overview

Update the touying-pitch-deck-template.md file to enforce YC design principles by removing complex layout patterns and increasing default font sizes. The current template contains grid layouts, panel/card helpers, and small font examples that encourage non-compliant deck generation. This update replaces complex patterns with single-column layouts, increases all font sizes (32pt body, 48pt titles), removes helper patterns, and adds an explicit "DO NOT USE" section documenting prohibited patterns.

### Research Integration

Key findings from research report:
- Current template has complex grid patterns, small font defaults (24pt), panel/box patterns, and traction chart placeholders
- Simplified patterns needed: 32pt body text, 48pt+ titles, single-message slides
- Remove: Grid layouts (except Team slide), metric cards/panels, nested blocks, small labels
- Add: "DO NOT USE" section, large-font-first examples, whitespace-focused layouts

## Goals & Non-Goals

**Goals**:
- Increase all font size examples to YC-compliant minimums (32pt body, 48pt titles)
- Replace multi-column grid examples with single-column layouts
- Remove panel/card helper patterns that create visual clutter
- Add explicit "DO NOT USE" section documenting prohibited patterns
- Simplify the main template code block to be copy-paste ready

**Non-Goals**:
- Removing the two-column layout entirely (Team slide still needs it)
- Creating new advanced features or animations
- Changing the underlying touying 0.6.3 theme system
- Updating other presentation-related context files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing decks using current patterns | Medium | Low | This is a template file, not production code; agents will use new patterns |
| Removing useful patterns needed for edge cases | Low | Low | Keep minimal two-column for Team slide; document exceptions |
| Missing prohibited patterns in DO NOT USE section | Medium | Medium | Reference research findings comprehensively |

## Implementation Phases

### Phase 1: Update Font Sizes and Simplify Main Template [COMPLETED]

**Goal**: Update all font size declarations to YC-compliant minimums and simplify the main template code block.

**Tasks**:
- [ ] Change default body text from `30pt` to `32pt` in Template Overview section
- [ ] Update `#set text(size: 30pt)` to `#set text(size: 32pt)` in main template
- [ ] Verify heading sizes are 48pt+ (level 1: 48pt, level 2: 40pt - already compliant)
- [ ] Update Problem slide text from 36pt to 32pt (consistent body size)
- [ ] Update Solution slide font size references to 32pt+
- [ ] Remove nested text size variations (28pt secondary text patterns)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md` - font size updates

**Verification**:
- All text size declarations are 32pt or higher for body text
- No font sizes below 28pt appear in template (28pt allowed for bullets only)

---

### Phase 2: Remove Complex Layout Patterns from Main Template [COMPLETED]

**Goal**: Replace complex grid layouts and panels with simple single-column patterns.

**Tasks**:
- [ ] Replace Business Model grid layout with single-column list format
- [ ] Remove Market Opportunity circle/stack visual (replace with simple text)
- [ ] Simplify Traction slide (remove block/fill pattern, use simple placeholder text)
- [ ] Remove or simplify nested `#align(center)` patterns where unnecessary
- [ ] Keep Team slide grid (2-column is appropriate here) but simplify text sizes

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md` - layout simplification

**Verification**:
- Business Model slide uses single-column layout
- Market Opportunity uses text-only format (no circles/stacks)
- Traction slide has simple placeholder without fill/radius styling

---

### Phase 3: Remove Helper Pattern Sections [COMPLETED]

**Goal**: Remove the Template Customization section patterns that encourage complexity.

**Tasks**:
- [ ] Remove "Chart Placeholder Pattern" section (encourages complex cetz charts)
- [ ] Remove or simplify "Two-Column Layouts" section (provide only Team exception)
- [ ] Keep "Changing Theme Colors" section (useful, not complex)
- [ ] Keep "Inserting Images" section (simple, necessary)
- [ ] Keep "Adding Animations" section (already says "Use Sparingly")
- [ ] Keep "Using Alternative Themes" section (simple reference)

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md` - remove/simplify sections

**Verification**:
- No Chart Placeholder Pattern section exists
- Two-Column section either removed or explicitly limited to Team slide

---

### Phase 4: Add "DO NOT USE" Section [COMPLETED]

**Goal**: Add explicit documentation of prohibited layout patterns to prevent agents from using them.

**Tasks**:
- [ ] Create new "## Prohibited Patterns (DO NOT USE)" section after Design Checklist
- [ ] Document prohibited grid layouts (except Team slide exception)
- [ ] Document prohibited panel/card/block styling with fill colors
- [ ] Document prohibited nested circles/stacks for market sizing
- [ ] Document prohibited small font sizes (anything below 28pt)
- [ ] Document prohibited complex cetz charts (keep charts simple or use images)
- [ ] Add rationale for each prohibition (YC principles reference)

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md` - add new section

**Verification**:
- "DO NOT USE" or "Prohibited Patterns" section exists
- All patterns identified in research are documented as prohibited
- Each prohibition includes brief rationale

---

### Phase 5: Update Design Checklist [COMPLETED]

**Goal**: Update the checklist to reflect new font size requirements.

**Tasks**:
- [ ] Change "All text is readable at 24pt or larger" to "All text is 28pt or larger"
- [ ] Add checklist item: "No multi-column layouts (except Team slide)"
- [ ] Add checklist item: "No decorative panels, cards, or colored boxes"
- [ ] Remove any references to complex visualizations

**Timing**: 10 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md` - update checklist

**Verification**:
- Checklist reflects 28pt minimum font size
- Checklist includes layout simplicity checks

## Testing & Validation

- [ ] Read final file and verify no font sizes below 28pt appear
- [ ] Verify Business Model, Market Opportunity, and Traction slides use simple layouts
- [ ] Verify "DO NOT USE" section exists with comprehensive pattern list
- [ ] Verify Design Checklist reflects new requirements
- [ ] Count remaining grid patterns (should be 1: Team slide only)

## Artifacts & Outputs

- `plans/01_template-simplification.md` (this file)
- `.claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md` (updated)
- `summaries/02_template-simplification-summary.md` (upon completion)

## Rollback/Contingency

If implementation causes issues:
1. Restore original template from git: `git checkout HEAD -- .claude/extensions/present/context/project/present/patterns/touying-pitch-deck-template.md`
2. The file is version-controlled, so full history is available
3. If partial changes are needed, cherry-pick specific updates from the implementation commit
