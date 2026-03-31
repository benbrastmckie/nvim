# Research Report: Task #328

**Task**: 328 - Make Typst primary output in founder plan agent
**Started**: 2026-03-30T12:00:00Z
**Completed**: 2026-03-30T12:15:00Z
**Effort**: 1-2 hours implementation
**Dependencies**: None
**Sources/Inputs**: Codebase analysis of founder extension agents and templates
**Artifacts**: specs/328_typst_primary_in_plan_agent/reports/01_typst-primary-plan.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The founder-plan-agent currently treats Typst as secondary for all types except project-timeline
- Project-timeline already uses the correct pattern: Phase 4 generates Typst, Phase 5 compiles PDF
- All 6 Typst templates already exist for every report type -- no new templates needed
- The founder-implement-agent also needs updates to match (Phase 4 = Typst primary, Phase 5 = PDF compile)
- Changes are confined to two files: `founder-plan-agent.md` and `founder-implement-agent.md`

## Context & Scope

The task is to update the founder-plan-agent so that ALL founder report types use Typst as the primary output format (not just project-timeline). Currently, for non-timeline types, Phase 4 generates a markdown report and Phase 5 optionally generates Typst/PDF. The desired pattern makes Phase 4 generate the Typst document and Phase 5 compile it to PDF, with markdown becoming a fallback.

## Findings

### Current Phase 4/5 Structure by Report Type

**Non-timeline types (market-sizing, competitive-analysis, gtm-strategy, contract-review, cost-breakdown):**

In the plan agent (founder-plan-agent.md):
- Phase 4: "Report Generation" -- synthesizes findings into **markdown** report at `strategy/{report-type}-{slug}.md`
- Phase 5: "Typst Document Generation" -- generates typst from template, compiles to PDF; explicitly states "Markdown report from Phase 4 is the primary output"

In the implement agent (founder-implement-agent.md):
- Phase 4 (line 265): Writes markdown to `strategy/{report-type}-{slug}.md`
- Phase 5 (line 288): Generates self-contained typst, writes to `founder/{report-type}-{slug}.typ`, compiles to PDF
- Phase 5 is explicitly "Non-blocking" -- failure does not block task completion
- Line 292: "The markdown report from Phase 4 is the primary deliverable"
- Line 151: "Phase 5 skipping does NOT block task completion -- the markdown report from Phase 4 is the primary deliverable"

**Project-timeline type (the model to follow):**

In the plan agent (founder-plan-agent.md, lines 604-619):
- Phase 4: "Gantt Chart and Typst Visualization" -- generates Typst document with all visualizations
- Phase 5: "PDF Compilation and Deliverables" -- compiles Typst to PDF
- Note on line 619 explains the naming difference

In the implement agent (founder-implement-agent.md, lines 1365-1439):
- Phase 4 (line 1365): Generates self-contained Typst at `strategy/timelines/{slug}.typ`
- Phase 5 (line 1406): Only compiles Typst to PDF, also generates markdown summary
- Phase 5 is still "Non-blocking"

### Key Differences Between Current and Target State

| Aspect | Current (non-timeline) | Target (all types) |
|--------|----------------------|-------------------|
| Phase 4 name | "Report Generation" | "{Type} Report and Typst Generation" |
| Phase 4 output | Markdown at strategy/ | Typst at founder/ + markdown at strategy/ |
| Phase 5 name | "Typst Document Generation" | "PDF Compilation" |
| Phase 5 work | Generate typst + compile PDF | Compile PDF only |
| Primary output | Markdown | Typst/PDF |
| Fallback | N/A | Markdown |

### Typst Templates Available

All 6 templates exist at `.claude/extensions/founder/context/project/founder/templates/typst/`:
1. `market-sizing.typ` -- TAM/SAM/SOM analysis
2. `competitive-analysis.typ` -- Competitor landscape
3. `gtm-strategy.typ` -- Go-to-market strategy
4. `contract-analysis.typ` -- Contract review
5. `project-timeline.typ` -- Project timeline (already primary)
6. `cost-breakdown.typ` -- Cost breakdown
7. `strategy-template.typ` -- Base template (shared functions)

All templates use `#import "strategy-template.typ": *` pattern, though the implement agent inlines these functions for self-contained generation.

### Specific Sections to Change in founder-plan-agent.md

**1. Generic Phase Template (lines 338-393)**

The generic "Phase 4: Report Generation" and "Phase 5: Typst Document Generation" sections need rewriting:
- Phase 4 should generate Typst as primary + markdown as fallback
- Phase 5 should only compile PDF
- The "Risks & Mitigations" table (line 307) says "Typst compilation failure | Low | Low | Markdown report is primary output" -- update to reflect Typst is now primary

**2. Market Sizing phases (lines 424-438)**

Phase 4 currently: "Compile TAM/SAM/SOM analysis into strategy/{report-type}-{slug}.md"
Phase 5 currently: "Generate typst document using market-sizing.typ template"

Change: Phase 4 generates both typst and markdown, Phase 5 compiles PDF only.

**3. Competitive Analysis phases (lines 467-481)**

Same pattern as market sizing -- Phase 4 currently generates markdown, Phase 5 generates typst.

**4. GTM Strategy phases (lines 517-525)**

Same pattern.

**5. Contract Review phases (lines 557-570)**

Same pattern.

**6. Critical Requirements section (line 736)**

Line 736: "Always generate 5-phase structure with Phase 5 as Typst Document Generation (except project-timeline)"
Line 737: "Always name Phase 5 exactly 'Typst Document Generation' (except project-timeline, which uses 'PDF Compilation and Deliverables')"

These need updating to reflect all types now use "PDF Compilation" for Phase 5.

**7. Artifacts & Outputs section (lines 377-385)**

Currently lists:
- `strategy/{report-type}-{slug}.md` (markdown report)
- `founder/{report-type}-{slug}.typ` (typst source, if generated)
- `founder/{report-type}-{slug}.pdf` (PDF output, if compiled)

Should update to indicate typst/PDF are primary, markdown is fallback.

### Specific Sections to Change in founder-implement-agent.md

**1. Description (line 10)**

Currently says "Phase 5 generates typst documents" -- update to reflect Phase 4 generates Typst.

**2. Phase 4: Report Generation (lines 265-286)**

Currently generates only markdown. Needs to also generate Typst content as primary output.

**3. Phase 5: Typst Document Generation (lines 288-357)**

Currently generates typst + compiles PDF. Should only compile PDF (typst already generated in Phase 4).

**4. Lines 151, 292, 619 (multiple "markdown is primary" statements)**

All statements declaring "markdown report from Phase 4 is the primary deliverable" need updating.

**5. Stage 3.5 (lines 164-182)**

Phase 5 detection logic checks for "Typst Document Generation" or "PDF Compilation" -- may need updating.

**6. Self-Contained Typst Content Generation Pattern (lines 359-680+)**

This large section with inline typst examples currently lives under Phase 5. Needs to move to Phase 4 context.

**7. Per-type Phase 4/5 sections (lines 1104-1253)**

Competitive analysis, GTM strategy, contract review sections all have Phase 4 = markdown, Phase 5 = typst pattern.

### Scope Consideration: cost-breakdown

The cost-breakdown type is listed in the plan agent's type table but is routed to the `spreadsheet-agent` (not founder-implement-agent). The plan agent should still plan Typst as primary for cost-breakdown since a cost-breakdown.typ template exists, but the spreadsheet-agent implementation is out of scope for this task.

## Recommendations

### Approach: Follow project-timeline pattern

1. **Phase 4 for all types**: Rename to "{Type}-specific Report and Typst Generation"
   - Generate self-contained Typst file (inline template functions)
   - Also generate markdown fallback at `strategy/{report-type}-{slug}.md`
   - Typst output at `founder/{report-type}-{slug}.typ`

2. **Phase 5 for all types**: Rename to "PDF Compilation"
   - Only compile Typst to PDF
   - Non-blocking (failure does not block task completion)
   - Markdown report from Phase 4 is the fallback (not primary)

3. **Update both agents**: founder-plan-agent.md and founder-implement-agent.md

4. **Update language**: All "Markdown report is primary" statements become "Typst/PDF is primary, markdown is fallback"

### Files to Modify

1. `.claude/extensions/founder/agents/founder-plan-agent.md` -- Primary target
2. `.claude/extensions/founder/agents/founder-implement-agent.md` -- Must match plan structure

### Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing plans | Low | Low | Only new plans use updated structure; Stage 3.5 handles legacy plans |
| Typst not installed | Medium | Low | Markdown fallback preserved; Phase 5 non-blocking behavior unchanged |
| Scope creep to spreadsheet-agent | Low | Medium | Explicitly exclude from this task |

## Decisions

- The project-timeline pattern is the correct model to follow
- Both plan and implement agents must be updated together for consistency
- Markdown remains as a fallback, not removed entirely
- cost-breakdown plan updates are in scope, but spreadsheet-agent changes are not

## Appendix

### Files Analyzed
- `.claude/extensions/founder/agents/founder-plan-agent.md` (752 lines)
- `.claude/extensions/founder/agents/founder-implement-agent.md` (1500+ lines)
- `.claude/extensions/founder/context/project/founder/templates/typst/` (7 template files)

### Key Line References in founder-plan-agent.md
- Lines 338-393: Generic phase template (Phase 4/5)
- Lines 396-438: Market sizing phases
- Lines 440-481: Competitive analysis phases
- Lines 483-525: GTM strategy phases
- Lines 527-570: Contract review phases
- Lines 574-619: Project timeline phases (model pattern)
- Lines 734-737: Critical requirements for phase naming

### Key Line References in founder-implement-agent.md
- Lines 265-286: Phase 4 Report Generation (generic)
- Lines 288-357: Phase 5 Typst Document Generation (generic)
- Lines 1104-1110: Competitive analysis Phase 4/5
- Lines 1135-1141: GTM strategy Phase 4/5
- Lines 1213-1253: Contract review Phase 4/5
- Lines 1365-1439: Project timeline Phase 4/5 (model pattern)
