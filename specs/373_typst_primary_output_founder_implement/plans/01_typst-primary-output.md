# Implementation Plan: Task #373

- **Task**: 373 - Make typst primary output in founder-implement-agent
- **Status**: [IMPLEMENTING]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/373_typst_primary_output_founder_implement/reports/01_typst-primary-output.md
- **Artifacts**: plans/01_typst-primary-output.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Rewrite the Context References, Stage 4 template table, and Phase 4 section of `founder-implement-agent.md` to make typst the unambiguous primary output format. The agent already generates typst first in Phase 4 execution logic, but the template loading sections still foreground markdown templates. This plan restructures those sections so typst templates are "Always Load" and markdown templates become a fallback section. Done when all four sections consistently present typst as primary and markdown as secondary.

### Research Integration

Research report confirmed: (1) eight typst templates exist, six are currently referenced; (2) the Phase 4 execution logic already generates typst first; (3) four specific sections need restructuring; (4) `cost-breakdown.typ` and `financial-analysis.typ` are not yet wired into agent flows and should not be added in this task.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Promote typst templates to "Always Load" in Context References
- Move markdown templates to a "Load for Markdown Fallback" section
- Rewrite Stage 4 template table to map report types to typst templates (with markdown as fallback column)
- Clarify Phase 4 heading and step descriptions to emphasize typst-primary, markdown-fallback

**Non-Goals**:
- Adding `cost-breakdown.typ` or `financial-analysis.typ` to the agent (no phase flows exist for these)
- Modifying the `/deck` pipeline or deck-builder-agent
- Changing Phase 5 (PDF compilation) or Stage 6-8 logic
- Altering domain knowledge references (business-frameworks.md, timeline-frameworks.md)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Existing plans reference old markdown template paths | L | L | Agent reads templates by report type, not by plan references |
| Removing "Load for Typst Generation" section name breaks other agents | M | L | No other agents reference this section name; it is internal |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Restructure Context References and Stage 4 Table [COMPLETED]

**Goal**: Make typst templates primary in the loading and lookup sections of the agent file.

**Tasks**:
- [ ] Replace "Always Load" section (lines 36-41): remove four markdown template references, add typst templates (`strategy-template.typ`, `market-sizing.typ`, `competitive-analysis.typ`, `gtm-strategy.typ`, `contract-analysis.typ`); keep `business-frameworks.md`
- [ ] Replace "Load for Typst Generation (Phase 4)" section (lines 47-53) with "Load for Markdown Fallback" section listing the four markdown templates
- [ ] Keep "Load for Project-Timeline" and "Load for Output" sections unchanged
- [ ] Rewrite Stage 4 "Load Report Template" table (lines 188-194) to show two columns: Primary Template (Typst) and Fallback Template (Markdown) for each report type

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Context References section (lines 36-53) and Stage 4 table (lines 188-194)

**Verification**:
- "Always Load" section contains typst template paths, not markdown template paths
- "Load for Markdown Fallback" section exists with the four markdown templates
- "Load for Typst Generation (Phase 4)" section no longer exists
- Stage 4 table has Primary (Typst) and Fallback (Markdown) columns

---

### Phase 2: Clarify Phase 4 Generation Order and Verify Output Paths [NOT STARTED]

**Goal**: Ensure Phase 4 heading and step descriptions explicitly mark typst as primary and markdown as fallback, and verify output path documentation is consistent.

**Tasks**:
- [ ] Rename Phase 4 heading from "Report and Typst Generation" to "Typst Report Generation" (or similar typst-first name)
- [ ] Update step 2 description to reference loading the typst template from the new Stage 4 table
- [ ] Update step 4 description to explicitly label markdown as "fallback" and reference the markdown fallback template
- [ ] Verify Stage 6 summary and Stage 7 metadata sections list typst first, markdown second (research confirms these are already correct -- verify only, no edit expected)
- [ ] Spot-check report-type-specific Phase 4 sections (competitive-analysis, gtm-strategy, contract-review, project-timeline) for consistency with the new primary/fallback framing

**Timing**: 15 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/extensions/founder/agents/founder-implement-agent.md` - Phase 4 section (lines 265-304) and report-specific Phase 4 sections (lines 1079+)

**Verification**:
- Phase 4 heading names typst first
- Step descriptions use "primary" for typst and "fallback" for markdown
- No references to "Load for Typst Generation" section remain anywhere in the file
- Output paths in Stage 6/7 list typst before markdown

## Testing & Validation

- [ ] Grep for "Load for Typst Generation" in the file -- should return zero matches
- [ ] Grep for markdown template paths in "Always Load" section -- should return zero matches
- [ ] Verify all five report types appear in the rewritten Stage 4 table with both typst and markdown columns
- [ ] Confirm Phase 4 heading no longer says "Report and Typst Generation"

## Artifacts & Outputs

- Modified file: `.claude/extensions/founder/agents/founder-implement-agent.md`

## Rollback/Contingency

Single file modification. Revert with `git checkout -- .claude/extensions/founder/agents/founder-implement-agent.md`.
