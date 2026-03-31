# Research Report: Task #329

**Task**: 329 - Make Typst primary output in founder implement agent
**Started**: 2026-03-30T12:00:00Z
**Completed**: 2026-03-30T12:20:00Z
**Effort**: 1-2 hours implementation
**Dependencies**: Task 328 (plan agent changes should land first or concurrently)
**Sources/Inputs**: Codebase analysis of founder-implement-agent.md (1564 lines), task 328 research report
**Artifacts**: specs/329_typst_primary_in_implement_agent/reports/01_typst-primary-implement.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The founder-implement-agent currently generates markdown in Phase 4 and Typst/PDF in Phase 5 for all non-timeline types
- Project-timeline already uses the correct pattern: Phase 4 generates Typst directly, Phase 5 only compiles PDF
- Six specific sections need changes: the generic Phase 4/5, plus per-type sections for competitive-analysis, GTM strategy, and contract review
- The large self-contained Typst example (lines 359-602) must be reframed as Phase 4 content generation rather than Phase 5
- Multiple "markdown is primary" statements throughout the file need updating to "Typst is primary, markdown is fallback"
- All 7 Typst templates already exist -- no new template files needed

## Context & Scope

Task 329 updates the founder-implement-agent.md so that ALL founder report types generate Typst as the primary output in Phase 4 (like project-timeline already does), with Phase 5 reduced to PDF compilation only. This is the implementation-agent counterpart to task 328 (plan agent changes).

## Findings

### Current Architecture: Non-Timeline Types

**Phase 4: Report Generation (lines 265-286)**
- Generates **markdown only** at `strategy/{report-type}-{slug}.md`
- Uses markdown templates from `context/project/founder/templates/*.md`
- No Typst generation happens here

**Phase 5: Typst Document Generation (lines 288-357)**
- Generates self-contained Typst file (inlines all template functions)
- Writes to `founder/{report-type}-{slug}.typ`
- Compiles to PDF at `founder/{report-type}-{slug}.pdf`
- Explicitly marked "Non-blocking" -- failure does not block task completion
- Line 292: "The markdown report from Phase 4 is the primary deliverable"
- Line 619: "Phase 5 failures do NOT block task completion. The markdown report (Phase 4) is the primary output."

### Current Architecture: Project-Timeline (The Model)

**Phase 4: Gantt Chart and Typst Visualization (lines 1365-1402)**
- Generates self-contained Typst directly at `strategy/timelines/{project-slug}.typ`
- Inlines project-timeline.typ template functions
- Also generates a markdown summary at `strategy/timelines/{slug}-report.md`
- Typst is the primary artifact

**Phase 5: PDF Compilation and Deliverables (lines 1406-1439)**
- Only compiles Typst to PDF
- Non-blocking
- Line 1410: "The markdown report from Phase 4 is the primary deliverable" (this should say "fallback" post-change)
- Line 1439: Same "primary deliverable" language

### Specific Sections Requiring Changes

#### 1. Overview/Description (line 10)

Current: "Phase 5 generates typst documents and compiles them to PDF in the `founder/` directory."
Target: "Phase 4 generates Typst documents as primary output, and Phase 5 compiles them to PDF."

#### 2. Context References (lines 47-53)

Current heading: "Load for Typst Generation (Phase 5)"
Target heading: "Load for Typst Generation (Phase 4)" -- since Typst generation moves to Phase 4.

#### 3. Stage 2.5: Detect Typst Availability (lines 134-151)

Line 151: "Phase 5 skipping does NOT block task completion -- the markdown report from Phase 4 is the primary deliverable."
Target: Update to reflect that Typst is primary and markdown is fallback. Also, the `typst_available` check should now gate Phase 4's Typst generation (not just Phase 5's compilation).

**Design decision needed**: If typst is unavailable, should Phase 4 generate markdown-only as fallback? The answer should be yes -- Phase 4 generates both Typst + markdown, but if typst CLI is unavailable for compilation testing, the Typst file is still written (it can be compiled later). The `typst_available` flag only matters for Phase 5 (PDF compilation). This is actually the same as project-timeline's current behavior.

#### 4. Stage 3.5: Ensure Typst Phase Exists (lines 164-182)

Line 169: grep pattern `"Phase 5.*(Typst|PDF Compilation)"` -- needs updating since Phase 5 will always be "PDF Compilation" now (not "Typst Document Generation").
Line 174: "If the plan contains a 'Phase 5: Typst Document Generation' heading: execute it normally" -- this backward compat text needs updating.

#### 5. Stage 4: Load Report Template (lines 186-196)

Currently loads only markdown templates. For the new pattern, Phase 4 should also reference the Typst template for content generation. Add Typst template paths alongside markdown templates.

| Report Type | Markdown Template | Typst Template |
|-------------|-------------------|----------------|
| market-sizing | `templates/market-sizing.md` | `templates/typst/market-sizing.typ` |
| competitive-analysis | `templates/competitive-analysis.md` | `templates/typst/competitive-analysis.typ` |
| gtm-strategy | `templates/gtm-strategy.md` | `templates/typst/gtm-strategy.typ` |
| contract-review | `templates/contract-analysis.md` | `templates/typst/contract-analysis.typ` |
| cost-breakdown | N/A (spreadsheet-agent) | `templates/typst/cost-breakdown.typ` |

#### 6. Generic Phase 4: Report Generation (lines 265-286) -- MAJOR CHANGE

Current: Generates markdown only at `strategy/{report-type}-{slug}.md`

Target (following project-timeline pattern):
1. Generate self-contained Typst file at `founder/{report-type}-{slug}.typ`
   - Inline all template functions (no imports)
   - Populate with all analysis data from Phases 1-3
2. Also generate markdown fallback at `strategy/{report-type}-{slug}.md`
3. Output path for Typst: `founder/{report-type}-{slug}.typ`

This is where the bulk of the self-contained Typst content generation pattern (currently under Phase 5, lines 359-602) should be referenced from.

#### 7. Generic Phase 5: Typst Document Generation (lines 288-357) -- MAJOR CHANGE

Current name: "Phase 5: Typst Document Generation"
Target name: "Phase 5: PDF Compilation"

Current behavior: Generate Typst + compile PDF (steps 1-7)
Target behavior: Compile PDF only (like project-timeline Phase 5, lines 1406-1430)

Specific changes:
- Remove steps 3-5 (create founder dir, generate typst content, write typst file) -- these move to Phase 4
- Keep steps 1-2 (mark in progress, check typst_available)
- Keep step 6 (compile to PDF) but source file is already written by Phase 4
- Keep step 7 (mark phase status)
- Remove line 292: "The markdown report from Phase 4 is the primary deliverable"
- Replace with: "The Typst source from Phase 4 is the primary deliverable. Markdown is a fallback."

#### 8. Self-Contained Typst Content Generation Pattern (lines 359-602)

This large example section currently lives under Phase 5 context. It needs to be reframed as Phase 4 content. The actual typst code examples (market-sizing.typ example at lines 369-601, project-timeline.typ example at lines 621-922) can stay largely the same since they are reference examples. But the contextual framing must indicate this is Phase 4 work.

#### 9. Per-Type Phase 4/5 Sections

**Competitive Analysis (lines 1104-1113)**:
- Phase 4 (line 1104): Currently "Report Generation" -- add Typst generation
- Phase 5 (line 1109): Currently "Generate typst file using competitive-analysis.typ template" -- change to "Compile Typst to PDF"

**GTM Strategy (lines 1135-1144)**:
- Phase 4 (line 1135): Currently "Report Generation" -- add Typst generation
- Phase 5 (line 1140): Currently "Generate typst file using gtm-strategy.typ template" -- change to "Compile Typst to PDF"

**Contract Review (lines 1213-1253)**:
- Phase 4 (line 1213): Currently detailed markdown-only report generation -- add Typst generation
- Phase 5 (lines 1231-1253): Currently detailed Typst generation + compilation -- change to PDF compilation only

#### 10. Stage 6: Summary Template (lines 932-998)

Line 949: "Files Created" section lists `strategy/{report-type}-{slug}.md` first (as primary).
Target: List `founder/{report-type}-{slug}.typ` first, then `.pdf`, then markdown as fallback.

Line 982-987: "Typst Generation" section -- update labels:
- "Typst skipped" concept changes since Typst is now generated in Phase 4 regardless of typst CLI availability
- "PDF generated" is the Phase 5 output

#### 11. Stage 7: Metadata Template (lines 1002-1066)

Lines 1013-1015: Artifact list puts markdown first. Reorder to put Typst/PDF first.
Line 1044-1047: `typst_available`, `typst_skipped`, `typst_generated` flags need semantic update.

#### 12. Stage 8: Return Text Summary (lines 1068-1081)

Line 1077: Currently lists "Markdown report" first, then "PDF report". Reorder.

#### 13. Error Handling Table (lines 610-619)

Line 619: "Phase 5 failures do NOT block task completion. The markdown report (Phase 4) is the primary output."
Target: "Phase 5 failures do NOT block task completion. The Typst source from Phase 4 is the primary output; markdown is the fallback."

#### 14. Critical Requirements (lines 1542-1564)

No explicit mention of "markdown is primary" here, but should add a requirement like:
"Always generate Typst as primary output in Phase 4 for all report types"

### Cost-Breakdown Scope Note

The cost-breakdown type is handled by the spreadsheet-agent, not the founder-implement-agent. The cost-breakdown.typ template exists but changes to the spreadsheet-agent are out of scope for this task. Only the founder-implement-agent needs modification.

### Relationship to Task 328

Task 328 modifies the founder-plan-agent.md to plan Typst as primary. Task 329 modifies the founder-implement-agent.md to execute that plan. The two tasks are complementary:
- Plan agent tells the implement agent what phases to run and their names
- Implement agent contains the actual execution logic

Both must be updated consistently. The Phase 5 naming convention should match:
- Plan agent Phase 5: "PDF Compilation" (for all types)
- Implement agent Phase 5: "PDF Compilation" (for all types)

## Recommendations

### Implementation Approach

**Phase 1: Update Generic Phase 4 (Report Generation)**
1. Rename from "Phase 4: Report Generation" to "Phase 4: Report and Typst Generation"
2. Add Typst generation as primary output (self-contained pattern, inline functions)
3. Keep markdown generation as fallback output
4. Move Typst content generation pattern reference from Phase 5 context to Phase 4

**Phase 2: Update Generic Phase 5 (Typst Document Generation -> PDF Compilation)**
1. Rename from "Phase 5: Typst Document Generation" to "Phase 5: PDF Compilation"
2. Remove Typst generation steps (moved to Phase 4)
3. Keep only PDF compilation steps
4. Update non-blocking language: "Typst source is primary, markdown is fallback"

**Phase 3: Update Per-Type Sections**
1. Competitive analysis Phase 4/5 (lines 1104-1113)
2. GTM strategy Phase 4/5 (lines 1135-1144)
3. Contract review Phase 4/5 (lines 1213-1253)
4. Each follows same pattern: Phase 4 adds Typst, Phase 5 becomes PDF-only

**Phase 4: Update Supporting Sections**
1. Overview/description (line 10)
2. Context references heading (line 47)
3. Stage 2.5 language (line 151)
4. Stage 3.5 backward compat (lines 164-182)
5. Stage 4 template loading (lines 186-196)
6. Self-contained pattern framing (lines 359-602)
7. Error handling table (lines 610-619)
8. Stage 6 summary template (lines 932-998)
9. Stage 7 metadata template (lines 1002-1066)
10. Stage 8 return summary (lines 1068-1081)
11. Critical requirements (lines 1542-1564)

**Phase 5: Verification**
1. Compare project-timeline Phase 4/5 pattern with updated generic pattern
2. Ensure all "markdown is primary" statements are updated
3. Verify backward compatibility for legacy plans (Stage 3.5)

### Output Path Convention

After changes, the output paths for non-timeline types should be:

| Phase | Output | Path |
|-------|--------|------|
| Phase 4 | Typst source (primary) | `founder/{report-type}-{slug}.typ` |
| Phase 4 | Markdown (fallback) | `strategy/{report-type}-{slug}.md` |
| Phase 5 | PDF (compiled) | `founder/{report-type}-{slug}.pdf` |

This matches the existing project-timeline pattern where:
- Phase 4 -> `strategy/timelines/{slug}.typ` (Typst) + `strategy/timelines/{slug}-report.md` (markdown)
- Phase 5 -> `founder/{slug}.pdf` (PDF)

**Note**: Non-timeline types write Typst to `founder/` (not `strategy/`) because that is where the existing Phase 5 writes them. Project-timeline writes to `strategy/timelines/` because that was the original design. This inconsistency exists today and is not in scope to fix.

## Decisions

- Follow the project-timeline pattern exactly as the model for all types
- Typst generation moves to Phase 4; Phase 5 becomes PDF-only compilation
- Markdown remains as fallback (generated alongside Typst in Phase 4), not removed
- The `typst_available` flag only gates Phase 5 (PDF compilation), not Phase 4 (Typst source generation) -- .typ files can be written regardless of whether the typst CLI is installed
- cost-breakdown changes are out of scope (handled by spreadsheet-agent)
- The large self-contained Typst examples (lines 369-922) remain as-is but are reframed as Phase 4 reference material

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking legacy plans that say "Phase 5: Typst Document Generation" | Low | Medium | Stage 3.5 backward compat handles this -- it detects Phase 5 naming variations |
| Large number of edits across 1564-line file | Medium | Low | Systematic approach: generic sections first, then per-type sections, then supporting text |
| Inconsistent Typst output paths (founder/ vs strategy/timelines/) | Low | N/A | Out of scope -- existing inconsistency predates this task |
| Task 328 and 329 must be consistent | Medium | Low | Both tasks follow same "project-timeline as model" approach |

## Appendix

### Files to Modify

1. `.claude/extensions/founder/agents/founder-implement-agent.md` -- Primary and only target file

### Line Reference Summary

| Section | Lines | Change Type |
|---------|-------|-------------|
| Overview description | 10 | Update language |
| Context references heading | 47 | Rename "Phase 5" to "Phase 4" |
| Stage 2.5 typst availability | 134-151 | Update "primary deliverable" language |
| Stage 3.5 ensure typst phase | 164-182 | Update Phase 5 naming detection |
| Stage 4 template loading | 186-196 | Add Typst template references |
| Generic Phase 4 | 265-286 | Add Typst generation (major) |
| Generic Phase 5 | 288-357 | Reduce to PDF compilation only (major) |
| Self-contained Typst pattern | 359-602 | Reframe as Phase 4 reference |
| Error handling table | 610-619 | Update "primary output" language |
| Stage 6 summary template | 932-998 | Reorder artifacts, update labels |
| Stage 7 metadata | 1002-1066 | Reorder artifacts, update flags |
| Stage 8 return summary | 1068-1081 | Reorder artifact listing |
| Competitive analysis Phase 4/5 | 1104-1113 | Phase 4 adds Typst, Phase 5 PDF-only |
| GTM strategy Phase 4/5 | 1135-1144 | Phase 4 adds Typst, Phase 5 PDF-only |
| Contract review Phase 4/5 | 1213-1253 | Phase 4 adds Typst, Phase 5 PDF-only |
| Project-timeline Phase 4/5 | 1365-1439 | Already correct (model pattern) |
| Critical requirements | 1542-1564 | Add Typst-primary requirement |

### Search Queries Used
- Direct file reads of founder-implement-agent.md (all 1564 lines)
- Glob for .typ template files in founder extension context
- Task 328 research report for related plan-agent findings
- Typst template structure review (competitive-analysis.typ, cost-breakdown.typ)
