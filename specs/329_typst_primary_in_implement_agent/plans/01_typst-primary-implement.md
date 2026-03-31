# Implementation Plan: Task #329

- **Task**: 329 - Make Typst primary output in founder implement agent
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: Task 328 (companion plan-agent changes)
- **Research Inputs**: reports/01_typst-primary-implement.md
- **Artifacts**: plans/01_typst-primary-implement.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update `.claude/extensions/founder/agents/founder-implement-agent.md` so ALL founder report types generate Typst as the primary output in Phase 4 (following the project-timeline pattern), with Phase 5 reduced to PDF compilation only. Currently only project-timeline generates Typst directly in Phase 4; all other types write markdown in Phase 4 and optionally generate Typst in Phase 5. The single target file is 1564 lines with 14 sections requiring changes.

### Research Integration

**Research Report**: [01_typst-primary-implement.md](../reports/01_typst-primary-implement.md)

**Key Findings**:
- Project-timeline already uses the correct Typst-primary pattern (Phase 4 = Typst generation, Phase 5 = PDF compile)
- All 7 Typst templates already exist -- no new templates needed
- 14 specific sections identified across the file requiring changes
- The `typst_available` flag only gates Phase 5 (PDF compilation), not Phase 4 (Typst source generation)
- cost-breakdown is out of scope (handled by spreadsheet-agent)
- The large self-contained Typst examples (lines 369-922) remain as-is but get reframed as Phase 4 reference material

## Goals & Non-Goals

**Goals**:
- Phase 4 generates Typst as primary output + markdown as fallback for all report types
- Phase 5 only compiles PDF (not generates Typst) for all types
- Update all "markdown is primary" language to "Typst is primary, markdown is fallback"
- Maintain consistency with task 328 plan-agent changes

**Non-Goals**:
- Modifying the spreadsheet-agent (cost-breakdown implementation)
- Changing Typst template files themselves
- Modifying project-timeline sections (already correct)
- Changing output path conventions (founder/ vs strategy/timelines/ inconsistency is out of scope)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking legacy plans that say "Phase 5: Typst Document Generation" | Low | Medium | Stage 3.5 backward compat already handles naming variations |
| Large number of edits across 1564-line file | Medium | Low | Systematic 4-phase approach: generic first, per-type second, supporting third, verify fourth |
| Task 328/329 inconsistency | Medium | Low | Both tasks follow identical "project-timeline as model" approach |
| Typst not installed on target system | Low | Low | Markdown fallback preserved; Phase 5 remains non-blocking |

## Implementation Phases

### Phase 1: Update Generic Phase 4 and Phase 5 [NOT STARTED]

**Goal**: Transform the generic Phase 4 from markdown-only to Typst-primary, and reduce generic Phase 5 from Typst generation + PDF compilation to PDF compilation only

**Tasks**:
- [ ] Update generic Phase 4: Report Generation (lines 265-286) to add Typst generation as primary output
  - Add self-contained Typst file generation at `founder/{report-type}-{slug}.typ`
  - Inline all template functions (no imports), following project-timeline pattern
  - Keep markdown generation as fallback at `strategy/{report-type}-{slug}.md`
- [ ] Update generic Phase 5 (lines 288-357) from "Typst Document Generation" to "PDF Compilation"
  - Remove steps 3-5 (create founder dir, generate typst content, write typst file) -- these are now in Phase 4
  - Keep steps 1-2 (mark in progress, check typst_available)
  - Keep step 6 (compile to PDF) but source file is already written by Phase 4
  - Keep step 7 (mark phase status)
  - Replace line 292 "The markdown report from Phase 4 is the primary deliverable" with "The Typst source from Phase 4 is the primary deliverable. Markdown is a fallback."
- [ ] Reframe the self-contained Typst content generation pattern (lines 359-602) as Phase 4 reference material instead of Phase 5 context

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Generic Phase 4, Phase 5, and Typst pattern sections

**Verification**:
- Generic Phase 4 generates both Typst file (primary) and markdown (fallback)
- Generic Phase 5 heading says "PDF Compilation" and only compiles PDF
- Self-contained Typst pattern is framed as Phase 4 reference

---

### Phase 2: Update Per-Type Phase 4/5 Sections [NOT STARTED]

**Goal**: Update competitive-analysis, GTM strategy, and contract review per-type sections to match the Typst-primary pattern

**Tasks**:
- [ ] Update Competitive Analysis Phase 4 (line 1104): add Typst generation alongside existing content
- [ ] Update Competitive Analysis Phase 5 (line 1109): change from "Generate typst file" to "Compile Typst to PDF"
- [ ] Update GTM Strategy Phase 4 (line 1135): add Typst generation
- [ ] Update GTM Strategy Phase 5 (line 1140): change to "Compile Typst to PDF"
- [ ] Update Contract Review Phase 4 (lines 1213-1230): add Typst generation to detailed section
- [ ] Update Contract Review Phase 5 (lines 1231-1253): reduce from Typst generation + compilation to PDF compilation only
- [ ] Verify Project Timeline sections (lines 1365-1439) remain unchanged (already correct)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Per-type phase sections

**Verification**:
- All 3 per-type sections follow Typst-primary pattern in Phase 4
- All 3 per-type sections have Phase 5 as PDF-only compilation
- Project-timeline sections unchanged

---

### Phase 3: Update Supporting Sections [NOT STARTED]

**Goal**: Update all remaining sections that reference the old markdown-primary / Phase 5 Typst generation pattern

**Tasks**:
- [ ] Update overview/description (line 10): "Phase 4 generates Typst documents as primary output, Phase 5 compiles PDF"
- [ ] Update context references heading (lines 47-53): change "Load for Typst Generation (Phase 5)" to "(Phase 4)"
- [ ] Update Stage 2.5 typst availability (line 151): remove "markdown report from Phase 4 is the primary deliverable" language
- [ ] Update Stage 3.5 ensure typst phase (lines 164-182): update Phase 5 naming detection patterns
- [ ] Update Stage 4 template loading (lines 186-196): add Typst template references alongside markdown templates
- [ ] Update error handling table (line 619): "Typst source from Phase 4 is the primary output; markdown is the fallback"
- [ ] Update Stage 6 summary template (lines 932-998): reorder artifacts to list Typst/PDF first, update Typst generation labels
- [ ] Update Stage 7 metadata template (lines 1002-1066): reorder artifact list, update typst flags semantics
- [ ] Update Stage 8 return text summary (lines 1068-1081): reorder to list Typst/PDF before markdown
- [ ] Update critical requirements (lines 1542-1564): add "Always generate Typst as primary output in Phase 4 for all report types"

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Supporting sections throughout the file

**Verification**:
- No remaining "markdown is primary" or "markdown report from Phase 4 is the primary deliverable" language
- All context reference headings point to Phase 4 for Typst generation
- Summary and metadata templates list Typst/PDF as primary artifacts
- Critical requirements include Typst-primary mandate

---

### Phase 4: Verification and Consistency Check [NOT STARTED]

**Goal**: Verify the file is internally consistent and aligns with task 328 plan-agent changes

**Tasks**:
- [ ] Read the full modified file end-to-end
- [ ] Search for any remaining "Typst Document Generation" references that are not in legacy-detection context (Stage 3.5)
- [ ] Search for any remaining "markdown report is primary" or "markdown is the primary deliverable" language
- [ ] Verify Phase 5 remains non-blocking (failure does not block task completion)
- [ ] Compare updated generic Phase 4/5 structure with project-timeline Phase 4/5 to confirm pattern match
- [ ] Verify Phase 5 naming convention matches task 328 plan agent: "PDF Compilation" for all types
- [ ] Fix any inconsistencies found

**Timing**: 15 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Minor fixups only if needed

**Verification**:
- Grep for "Typst Document Generation" returns only Stage 3.5 legacy-detection contexts
- Grep for "markdown.*primary" returns zero results (except as "fallback" qualifier)
- Phase 5 is non-blocking for all types
- Pattern is consistent with project-timeline model and task 328 changes

## Testing & Validation

- [ ] Generic Phase 4 generates Typst content as primary output
- [ ] Generic Phase 5 only compiles PDF
- [ ] Competitive analysis, GTM strategy, and contract review per-type sections updated
- [ ] Project-timeline sections unchanged
- [ ] No "markdown is primary" language remains (except as "fallback" qualifier)
- [ ] Stage 3.5 legacy detection still handles old plan formats
- [ ] `typst_available` flag only gates Phase 5 (PDF compilation), not Phase 4
- [ ] Critical requirements section includes Typst-primary mandate
- [ ] Summary and metadata templates list Typst/PDF as primary artifacts

## Artifacts & Outputs

- plans/01_typst-primary-implement.md (this plan)
- `.claude/extensions/founder/agents/founder-implement-agent.md` (modified)

## Rollback/Contingency

If implementation fails:
1. The file is version-controlled; `git checkout` restores the original
2. Changes are text-only (markdown agent spec), no runtime risk
3. Partial implementation can be resumed since phases are logically independent
4. Task 328 (plan agent) and task 329 (implement agent) can land independently if needed -- backward compat in Stage 3.5 handles mismatched plans
