# Implementation Plan: Custom Formalism Rendering Documentation (Revised)

- **Task**: 368 - context_docs_slidev_custom_formalism
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/368_context_docs_slidev_custom_formalism/reports/01_slidev-custom-formalism.md, specs/368_context_docs_slidev_custom_formalism/reports/02_team-research.md
- **Artifacts**: plans/02_slidev-custom-formalism.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add context documentation for custom formalism rendering in Slidev presentations. Team research revealed that the actual rendering architecture differs significantly from the original task assumptions: KaTex.vue and setup/katex.ts are dead code (zero usage in slides.md), LogosOp.vue is the only active custom rendering mechanism (8 instances for 4 compound operators), and ~70+ HTML entities use inconsistent font wrappers. The documentation will describe the actual state -- active LogosOp.vue, inactive KaTeX infrastructure, inconsistent HTML entities -- with a rendering decision tree and follow-on recommendations. Done when slidev-deck-template.md has a "Custom Formalism Rendering" section and deck/README.md lists the formalism components.

### Research Integration

Two rounds of research were integrated into this plan:

- **Report 01** (`reports/01_slidev-custom-formalism.md`): Initial analysis of the three rendering layers, SVG conventions, placeholder pipeline, and HTML entity inventory.
- **Report 02** (`reports/02_team-research.md`): Team research (4 teammates) that discovered KaTex.vue and setup/katex.ts are dead code, confirmed LogosOp.vue is the only active custom rendering, identified ~70+ HTML entities with inconsistent font wrappers, found SVG geometry duplication with vertical-align discrepancy, and recommended the target architecture (LogosOp.vue + Unicode literals + shared CSS class).

Key findings driving plan revision:
1. KaTex.vue/setup/katex.ts have zero usage in slides.md -- document as inactive, not as active rendering path
2. LogosOp.vue handles only 4 compound operators (boxright, diamondright, circleright, dotcircleright) across 2 slides
3. SVG geometry is duplicated between LogosOp.vue and KaTex.vue with vertical-align discrepancy (-0.1em vs -0.15em)
4. HTML entities (~70+ instances) use inconsistent wrappers: font-serif spans, code tags, bare text
5. Recommended architecture: LogosOp.vue for compound operators, Unicode literals with shared CSS class for standard operators

### Roadmap Alignment

No ROAD_MAP.md found (file does not exist at specs/ROAD_MAP.md).

## Goals & Non-Goals

**Goals**:
- Document the actual formalism rendering state in slidev-deck-template.md: active LogosOp.vue, inactive KaTeX infrastructure, inconsistent HTML entities
- Provide a rendering decision tree: when to use LogosOp.vue vs Unicode literals vs native KaTeX $...$ syntax
- Note the SVG geometry duplication coupling and vertical-align discrepancy between LogosOp.vue and KaTex.vue
- Document trigger conditions for escalating to a separate context file
- Include follow-on recommendations (unified geometry module, dead code cleanup, entity migration, accessibility)
- Add LogosOp.vue and KaTex.vue to deck/README.md component table with accurate status annotations

**Non-Goals**:
- Creating a separate custom-formalism-patterns.md file (content fits in existing template)
- Modifying index.json (no new files created)
- Exhaustive HTML entity inventory (include representative examples and counts, not full list)
- Fixing the vertical-align inconsistency or cleaning up dead code (follow-on tasks)
- Migrating HTML entities to Unicode literals (follow-on task)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| slidev-deck-template.md grows too large with formalism section | M | L | Target ~80-100 lines; file stays under 490 total lines |
| Documentation drifts from source components as deck evolves | M | M | Reference source file paths so editors can verify against actual code |
| Dead code status changes if KaTeX is later activated | L | L | Include trigger conditions for when to update the documentation |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |

Phases within the same wave can execute in parallel.

### Phase 1: Add Custom Formalism Section to slidev-deck-template.md [COMPLETED]

**Goal**: Insert a "Custom Formalism Rendering" section into the Slidev deck template documentation that accurately reflects the current state: active LogosOp.vue, dead KaTeX infrastructure, and inconsistent HTML entities.

**Tasks**:
- [ ] Read slidev-deck-template.md to confirm insertion point (after "Custom Components" subsection around line 287, before "Library Integration Patterns" at line 289)
- [ ] Add "Custom Formalism Rendering" subsection under Component Usage with architecture overview that clearly states: LogosOp.vue is active (8 instances, 4 operators), KaTex.vue and setup/katex.ts are inactive dead code (0 instances), HTML entities are used for ~70+ standard operators with inconsistent wrappers
- [ ] Document LogosOp.vue as the active custom rendering: props (op), operator registry (boxright, diamondright, circleright, dotcircleright), viewBox 28x16, sizing 1.4em x 1em, vertical-align -0.1em, currentColor inheritance, usage example
- [ ] Document KaTex.vue and setup/katex.ts as inactive infrastructure: note they were built but never wired into slides.md, describe the placeholder substitution pipeline and htmlStyle overlap technique for reference, mark clearly as "not currently used"
- [ ] Document HTML entity pattern: ~70+ instances with inconsistent font wrappers (font-serif spans, code tags, bare), representative examples from modal/temporal/classical categories
- [ ] Add rendering decision tree: compound operator (4 custom glyphs) -> LogosOp.vue; standard operator in HTML context -> Unicode literal (recommended) or HTML entity (current); mathematical prose -> native KaTeX $...$
- [ ] Note SVG geometry duplication between LogosOp.vue and KaTex.vue with vertical-align discrepancy (-0.1em vs -0.15em)
- [ ] Add "Maintenance Notes" sub-subsection: duplication coupling warning, trigger conditions for escalating to separate context file (operator count doubles or second formalism deck created), follow-on recommendations (unified geometry module, dead code cleanup, entity-to-Unicode migration, accessibility)

**Timing**: 50 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md` - Insert new subsection after "Custom Components" (line ~287), before "Library Integration Patterns" (line 289)

**Verification**:
- New "Custom Formalism Rendering" section appears between "Custom Components" and "Library Integration Patterns"
- LogosOp.vue documented as the only active custom rendering mechanism
- KaTex.vue and setup/katex.ts clearly marked as inactive/dead code
- Decision tree covers all three rendering contexts
- Duplication coupling and follow-on recommendations included
- Source file paths referenced for maintainability

---

### Phase 2: Update deck/README.md Component Documentation [COMPLETED]

**Goal**: Add LogosOp.vue and KaTex.vue entries to the deck library README component table with accurate status annotations reflecting active vs inactive usage.

**Tasks**:
- [ ] Read deck/README.md to confirm current component table structure (Components section around line 172, directory tree around line 49)
- [ ] Add KaTex.vue entry to components directory tree (before LogosOp.vue alphabetically, between ComparisonCol.vue and MetricCard.vue)
- [ ] Add LogosOp.vue entry to components directory tree (between KaTex.vue and MetricCard.vue alphabetically)
- [ ] Update component count from "4 files" to "6 files" in the directory tree
- [ ] Add KaTex.vue to the Components table with props (expr, display) and note "(inactive -- not used in current deck)"
- [ ] Add LogosOp.vue to the Components table with props (op) and note "Custom compound operator SVG rendering"
- [ ] Verify alphabetical ordering is maintained in both directory tree and table

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/deck/README.md` - Update components directory tree and Components table

**Verification**:
- Component count reads "6 files"
- Both new components listed in directory tree in correct alphabetical position
- Components table has 6 entries with props documented
- KaTex.vue clearly marked as inactive
- LogosOp.vue described as active custom rendering

## Testing & Validation

- [ ] slidev-deck-template.md contains "Custom Formalism Rendering" section after "Custom Components"
- [ ] Decision tree covers all three rendering contexts (LogosOp, Unicode/entity, native KaTeX)
- [ ] KaTex.vue and setup/katex.ts documented as inactive dead code (not as active rendering path)
- [ ] LogosOp.vue documented as the only active custom rendering mechanism
- [ ] deck/README.md lists 6 components including LogosOp.vue and KaTex.vue
- [ ] No duplicate content between the two files (template has usage patterns, README has component reference)
- [ ] Source file paths referenced for future maintenance
- [ ] Follow-on recommendations listed (unified geometry module, dead code cleanup, entity migration, accessibility)

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md` (modified -- new Custom Formalism Rendering section)
- `.claude/extensions/founder/context/project/founder/deck/README.md` (modified -- 2 new component entries)
- `specs/368_context_docs_slidev_custom_formalism/plans/02_slidev-custom-formalism.md` (this plan)

## Rollback/Contingency

Both files are under git version control. If documentation causes issues, revert the two modified files:
```
git checkout HEAD -- .claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md
git checkout HEAD -- .claude/extensions/founder/context/project/founder/deck/README.md
```
