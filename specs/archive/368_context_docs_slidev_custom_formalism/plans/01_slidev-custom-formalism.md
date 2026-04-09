# Implementation Plan: Custom Formalism Rendering Documentation

- **Task**: 368 - context_docs_slidev_custom_formalism
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/368_context_docs_slidev_custom_formalism/reports/01_slidev-custom-formalism.md
- **Artifacts**: plans/01_slidev-custom-formalism.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Add context documentation for custom mathematical formalism rendering patterns used in Slidev presentations. The Logos Vision deck uses a three-layer system: LogosOp.vue (SVG inline operators), KaTex.vue (KaTeX with SVG injection), and HTML entities in font-serif spans. Documentation will be added to slidev-deck-template.md (new section after Component Usage) and deck/README.md (new component table entries). No separate file or index-entries.json changes are needed since all content fits within existing files.

### Research Integration

Research report `01_slidev-custom-formalism.md` provided complete component analysis of LogosOp.vue, KaTex.vue, and setup/katex.ts. Key findings integrated: SVG viewBox/sizing conventions, placeholder substitution pipeline for KaTex.vue, htmlStyle overlap technique for native KaTeX macros, HTML entity inventory with 18 operators across 7 categories, and the dual rendering decision tree. Research recommended Option A (add to existing template) over Option B (separate file).

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Document the three-layer custom formalism rendering system in slidev-deck-template.md
- Add LogosOp.vue and KaTex.vue to deck/README.md component table
- Provide a clear decision tree for choosing the correct rendering method
- Note the SVG duplication coupling between LogosOp.vue and KaTex.vue

**Non-Goals**:
- Creating a separate custom-formalism-patterns.md file (content fits in existing template)
- Modifying index-entries.json (no new files created)
- Documenting the full HTML entity inventory (include representative examples, not exhaustive list)
- Fixing the vertical-align inconsistency between LogosOp (-0.1em) and KaTex (-0.15em)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| slidev-deck-template.md grows too large | M | L | Content is ~60-80 lines; file stays under 470 total |
| Documentation drifts from source components | M | M | Note the source file paths so editors can verify |
| Insertion point shifts if template is edited concurrently | L | L | Use content-based matching for insertion, not line numbers |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1, 2 |

Phases within the same wave can execute in parallel.

### Phase 1: Add Custom Formalism Section to slidev-deck-template.md [COMPLETED]

**Goal**: Insert a comprehensive "Custom Formalism Rendering" section into the Slidev deck template documentation, covering all three rendering layers and the decision tree.

**Tasks**:
- [ ] Read slidev-deck-template.md to confirm current structure and insertion point (after "Custom Components" subsection around line 287, before "Library Integration Patterns")
- [ ] Add "Custom Formalism Rendering" subsection under Component Usage with three-layer overview
- [ ] Document LogosOp.vue: props (op), operator registry (boxright, diamondright, circleright, dotcircleright), viewBox 28x16, sizing 1.4em x 1em, vertical-align -0.1em, currentColor inheritance, usage example
- [ ] Document KaTex.vue: props (expr, display), placeholder substitution pipeline, usage example for math context
- [ ] Document setup/katex.ts: native KaTeX fallback with mathrel + htmlStyle overlap technique, trust/strict config
- [ ] Document HTML entity pattern: font-serif span convention with representative examples from modal/temporal/classical categories
- [ ] Add rendering decision tree: Unicode check -> compound operator check -> context check (HTML vs KaTeX component vs markdown $...$)
- [ ] Note SVG duplication coupling between LogosOp.vue and KaTex.vue with different vertical-align values

**Timing**: 45 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md` - Insert new subsection after Component Usage

**Verification**:
- New section appears between "Custom Components" and "Library Integration Patterns"
- All three rendering layers documented with usage examples
- Decision tree is clear and actionable
- Source file paths referenced for maintainability

---

### Phase 2: Update deck/README.md Component Documentation [COMPLETED]

**Goal**: Add LogosOp.vue and KaTex.vue entries to the component table and update the directory tree file count.

**Tasks**:
- [ ] Read deck/README.md to confirm current component table structure (around line 49)
- [ ] Add LogosOp.vue entry to components directory tree (between MetricCard.vue and TeamMember.vue, alphabetically)
- [ ] Add KaTex.vue entry to components directory tree (before LogosOp.vue, alphabetically)
- [ ] Update component count from "4 files" to "6 files" in the directory tree header
- [ ] Add LogosOp.vue and KaTex.vue to the Components section description with props and usage summary

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/context/project/founder/deck/README.md` - Update components section

**Verification**:
- Component count reads "6 files"
- Both new components listed in directory tree with descriptions
- Props documented for both components
- Alphabetical ordering maintained

---

### Phase 3: Review and Cross-Reference Verification [COMPLETED]

**Goal**: Verify consistency between the two modified files and ensure cross-references are correct.

**Tasks**:
- [ ] Verify component names and props match between slidev-deck-template.md and deck/README.md
- [ ] Verify operator names are consistent (boxright, diamondright, circleright, dotcircleright) across both files
- [ ] Confirm no broken references or formatting issues in either file
- [ ] Read both modified files end-to-end to check integration with surrounding content

**Timing**: 15 minutes

**Depends on**: 1, 2

**Files to modify**:
- None (review only; corrections if needed to either file from Phase 1 or 2)

**Verification**:
- No inconsistencies between the two documentation files
- All operator names spelled identically
- Props lists match
- No formatting artifacts from insertion

## Testing & Validation

- [ ] slidev-deck-template.md contains "Custom Formalism Rendering" section
- [ ] Decision tree covers all three rendering paths (LogosOp, KaTex, HTML entity)
- [ ] deck/README.md lists 6 components including LogosOp.vue and KaTex.vue
- [ ] No duplicate content between the two files (template has usage patterns, README has component reference)
- [ ] Source file paths referenced for future maintenance

## Artifacts & Outputs

- `.claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md` (modified)
- `.claude/extensions/founder/context/project/founder/deck/README.md` (modified)
- `specs/368_context_docs_slidev_custom_formalism/plans/01_slidev-custom-formalism.md` (this plan)

## Rollback/Contingency

Both files are under git version control. If documentation causes issues, revert the two modified files:
```
git checkout HEAD -- .claude/extensions/founder/context/project/founder/patterns/slidev-deck-template.md
git checkout HEAD -- .claude/extensions/founder/context/project/founder/deck/README.md
```
