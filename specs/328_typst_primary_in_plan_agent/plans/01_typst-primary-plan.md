# Implementation Plan: Task #328

- **Task**: 328 - Make Typst primary output in founder plan agent
- **Status**: [IMPLEMENTING]
- **Effort**: 2 hours
- **Dependencies**: None
- **Research Inputs**: reports/01_typst-primary-plan.md
- **Artifacts**: plans/01_typst-primary-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Update founder-plan-agent.md and founder-implement-agent.md so that ALL founder report types (not just project-timeline) use Typst as the primary output format. Phase 4 will generate both a Typst document and markdown fallback, and Phase 5 will only compile the PDF. The project-timeline type already follows this pattern and serves as the model.

### Research Integration

**Research Report**: [01_typst-primary-plan.md](../reports/01_typst-primary-plan.md)

**Key Findings**:
- Project-timeline already uses the correct pattern (Phase 4 = Typst generation, Phase 5 = PDF compile)
- All 6 Typst templates already exist -- no new templates needed
- Changes are confined to two agent files: founder-plan-agent.md and founder-implement-agent.md
- 5 non-timeline types need updating: market-sizing, competitive-analysis, gtm-strategy, contract-review, cost-breakdown
- cost-breakdown is planned by founder-plan-agent but implemented by spreadsheet-agent; plan updates are in scope, spreadsheet-agent changes are not

## Goals & Non-Goals

**Goals**:
- Make Phase 4 generate Typst as primary output for all founder report types
- Make Phase 5 only compile PDF (not generate Typst) for all types
- Preserve markdown as a fallback output, not primary
- Update both plan and implement agents for consistency

**Non-Goals**:
- Modifying the spreadsheet-agent (cost-breakdown implementation)
- Changing Typst templates themselves
- Modifying the project-timeline sections (already correct)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing in-flight plans | Low | Low | Stage 3.5 legacy detection in implement agent handles old plan formats |
| Typst not installed on system | Medium | Low | Markdown fallback preserved; Phase 5 non-blocking unchanged |
| Inconsistency between plan and implement agents | Medium | Medium | Update both files in same phase, verify consistency |

## Implementation Phases

### Phase 1: Update founder-plan-agent.md Generic Template and Critical Requirements [COMPLETED]

**Goal**: Update the generic phase template (Phase 4/5) and critical requirements section to reflect Typst-primary pattern

**Tasks**:
- [ ] Update generic Phase 4 (lines 339-348) from "Report Generation" to "Report and Typst Generation" -- goal becomes generating Typst as primary + markdown as fallback
- [ ] Update generic Phase 5 (lines 350-366) from "Typst Document Generation" to "PDF Compilation" -- remove typst generation tasks, keep only PDF compile
- [ ] Update Risks & Mitigations table (line 306): change "Typst compilation failure | Low | Low | Markdown report is primary output" to reflect Typst is now primary, markdown is fallback
- [ ] Update Artifacts & Outputs section (lines 377-384): reorder to show typst/PDF as primary, markdown as fallback
- [ ] Update Critical Requirements lines 740-741: remove "(except project-timeline)" exceptions, make all types use "PDF Compilation" for Phase 5
- [ ] Update Phase 5 note at line 619: remove or revise the note explaining the naming difference (no longer different)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Generic template sections

**Verification**:
- Generic Phase 4 mentions Typst generation as primary
- Generic Phase 5 only mentions PDF compilation
- Critical requirements no longer have project-timeline exceptions
- Artifacts list shows typst/PDF as primary

---

### Phase 2: Update founder-plan-agent.md Per-Type Phase Definitions [COMPLETED]

**Goal**: Update all 5 non-timeline report type phase definitions to use Typst-primary pattern

**Tasks**:
- [ ] Update Market Sizing Phase 4 (lines 423-429): add Typst generation to tasks alongside markdown
- [ ] Update Market Sizing Phase 5 (lines 431-437): change to "PDF Compilation", remove typst generation tasks
- [ ] Update Competitive Analysis Phase 4 (lines 467-473): add Typst generation to tasks
- [ ] Update Competitive Analysis Phase 5 (lines 475-481): change to "PDF Compilation"
- [ ] Update GTM Strategy Phase 4 (lines 511-517): add Typst generation to tasks
- [ ] Update GTM Strategy Phase 5 (lines 519-525): change to "PDF Compilation"
- [ ] Update Contract Review Phase 4 (lines 557-563): add Typst generation to tasks
- [ ] Update Contract Review Phase 5 (lines 565-571): change to "PDF Compilation"
- [ ] Verify cost-breakdown phases follow same pattern (if present in plan agent)

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-plan-agent.md` - Per-type phase sections

**Verification**:
- All 5 non-timeline types have Phase 4 generating both Typst and markdown
- All 5 non-timeline types have Phase 5 as "PDF Compilation" only
- Project-timeline section remains unchanged
- Pattern is consistent across all types

---

### Phase 3: Update founder-implement-agent.md Phase 4 and Phase 5 [COMPLETED]

**Goal**: Update the implement agent so Phase 4 generates Typst as primary and Phase 5 only compiles PDF

**Tasks**:
- [ ] Update agent description (line 10): reflect that Phase 4 (not Phase 5) generates typst documents
- [ ] Update Phase 4: Report Generation (lines 265-286): add Typst content generation as primary output alongside markdown fallback
- [ ] Update Phase 5: Typst Document Generation (lines 288-357): rename to "PDF Compilation", remove typst generation logic, keep only PDF compile step
- [ ] Move self-contained Typst content generation pattern (lines 359-680+) from Phase 5 context to Phase 4 context
- [ ] Update all "markdown report from Phase 4 is the primary deliverable" statements (lines 151, 292, 619+) to "Typst/PDF is primary, markdown is fallback"
- [ ] Update Stage 3.5 phase detection logic (lines 164-182) if needed for new Phase 5 name

**Timing**: 45 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Phase 4, Phase 5, and supporting sections

**Verification**:
- Phase 4 generates both Typst file and markdown fallback
- Phase 5 only compiles PDF from existing Typst file
- Self-contained Typst generation pattern is documented under Phase 4
- No remaining "markdown is primary" language (except as "fallback" references)

---

### Phase 4: Update founder-implement-agent.md Per-Type Sections [COMPLETED]

**Goal**: Update per-type Phase 4/5 sections in the implement agent to match new pattern

**Tasks**:
- [ ] Update Competitive Analysis per-type sections (lines 1104-1110): Phase 4 generates typst + markdown, Phase 5 compiles PDF
- [ ] Update GTM Strategy per-type sections (lines 1135-1141): same pattern
- [ ] Update Contract Review per-type sections (lines 1213-1253): same pattern
- [ ] Verify Project Timeline sections (lines 1365-1439) remain unchanged (already correct)
- [ ] Search for any remaining references to "Typst Document Generation" as Phase 5 name and update

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Per-type phase sections

**Verification**:
- All per-type sections follow Typst-primary pattern
- No remaining "Phase 5: Typst Document Generation" references (except in legacy/detection context)
- Project-timeline sections unchanged

---

### Phase 5: Verification and Consistency Check [COMPLETED]

**Goal**: Verify both files are internally consistent and cross-consistent

**Tasks**:
- [ ] Read both modified files end-to-end
- [ ] Verify every report type has matching Phase 4/5 structure in both plan and implement agents
- [ ] Verify no orphaned references to old Phase 5 name "Typst Document Generation"
- [ ] Verify Stage 3.5 legacy plan detection still works for older plans that used the old naming
- [ ] Verify Phase 5 remains non-blocking in implement agent (failure does not block task completion)
- [ ] Verify cost-breakdown plan phases are updated but no spreadsheet-agent changes were made

**Timing**: 15 minutes

**Files to modify**:
- None (read-only verification), or minor fixups in either file

**Verification**:
- Grep for "Typst Document Generation" returns only legacy-detection contexts
- Grep for "markdown report is primary" returns zero results
- Both agents agree on phase names and structure for all 6 report types

## Testing & Validation

- [ ] All 5 non-timeline types in plan agent have Typst-primary Phase 4
- [ ] All types have "PDF Compilation" as Phase 5 (plan agent)
- [ ] Implement agent Phase 4 generates Typst content
- [ ] Implement agent Phase 5 only compiles PDF
- [ ] No "markdown is primary" language remains (except as "fallback" qualifier)
- [ ] Project-timeline sections unchanged in both files
- [ ] Critical requirements section updated (no project-timeline exceptions)
- [ ] Stage 3.5 legacy detection still handles old plan formats

## Artifacts & Outputs

- plans/01_typst-primary-plan.md (this plan)
- `.claude/extensions/founder/agents/founder-plan-agent.md` (modified)
- `.claude/extensions/founder/agents/founder-implement-agent.md` (modified)

## Rollback/Contingency

If implementation fails:
1. Both files are version-controlled; `git checkout` restores originals
2. Changes are text-only (markdown agent specs), no runtime risk
3. Partial implementation can be resumed since phases are independent per-file
