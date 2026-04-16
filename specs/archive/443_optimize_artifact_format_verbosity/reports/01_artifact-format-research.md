# Research Report: Task #443

**Task**: 443 - optimize_artifact_format_verbosity
**Started**: 2026-04-15T01:00:00Z
**Completed**: 2026-04-15T01:45:00Z
**Effort**: 1 hour
**Dependencies**: None
**Sources/Inputs**:
- https://github.com/JuliusBrussee/caveman/blob/main/README.md - Caveman compression strategy
- `.claude/context/formats/report-format.md` (131 lines)
- `.claude/context/formats/plan-format.md` (169 lines)
- `.claude/context/formats/summary-format.md` (59 lines)
- `.claude/context/reference/artifact-templates.md` (179 lines)
- `.claude/rules/artifact-formats.md` (118 lines)
- `.claude/rules/plan-format-enforcement.md` (46 lines)
- `.claude/scripts/validate-artifact.sh` - Enforcement script
- `.claude/context/formats/return-metadata-file.md` (503 lines)
- `specs/442_optimize_token_usage_model_routing/reports/01_model-routing-research.md` - Example real report (364 lines)
**Artifacts**:
- `specs/443_optimize_artifact_format_verbosity/reports/01_artifact-format-research.md`
**Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

---

## Executive Summary

- The caveman project demonstrates 65% average output token reduction by dropping filler and using fragments while preserving technical content. The key insight is not the extreme "full grunt" mode but the principle that prose filler in structured documents wastes tokens without adding value.
- Format files total ~700 lines across 6 files, with significant duplication between format standards, rule checklists, and template references. The same structure is often described three times (format, rule, template).
- The `return-metadata-file.md` at 503 lines is the largest single format file; roughly 60% of it is examples that repeat the same JSON schema with minor variations.
- Real-world reports (e.g., task 442 at 364 lines) follow the format correctly but carry verbose sections like full file path lists in Sources/Inputs and duplicated file lists in Appendix that could be condensed.
- The validation script enforces specific metadata fields and section headings by exact name match. Any optimization must preserve validated field names and section headings.
- Modest 20-30% reductions are achievable without changing the fundamental structure, primarily by consolidating duplicate documentation and trimming examples.

---

## Context & Scope

This research evaluates the current artifact format system (reports, plans, summaries) for opportunities to reduce verbosity while maintaining usefulness. The constraint is "not going full caveman" -- we want modest, safe optimizations, not radical compression.

The format system has three layers:
1. **Format standards** (`.claude/context/formats/`) -- authoritative specifications
2. **Rule checklists** (`.claude/rules/`) -- auto-applied enforcement reminders
3. **Template reference** (`.claude/context/reference/artifact-templates.md`) -- copy-paste skeletons

The validation script (`.claude/scripts/validate-artifact.sh`) enforces metadata fields and section headings.

---

## Findings

### 1. Caveman Strategy -- Applicable Principles

The caveman project achieves 65% average output token savings. Key principles relevant to this task (applied modestly):

- **Drop filler phrases in instructions**: Words like "be sure to", "make sure", "it is important to note that" add no information.
- **Eliminate redundant restatements**: Saying the same rule in format, rule, and template files forces agents to load all three.
- **Use fragments for field descriptions**: "Brief 1-sentence description" works as well as "A brief, human-readable description of the artifact in one sentence."
- **Preserve technical content**: Field names, JSON schemas, section headings, path formats must remain exact.
- **Key caveman caveat**: Compression only helps output/instructions. It does not affect reasoning quality. Shorter instructions can actually improve accuracy (cited: "Brevity Constraints Reverse Performance Hierarchies in Language Models", March 2026).

### 2. Duplication Across Format, Rule, and Template Files

The same artifact structure is documented in up to three places:

| Artifact | Format File | Rule File | Template File |
|----------|-------------|-----------|---------------|
| Report | report-format.md (131 lines) | artifact-formats.md (partial) | artifact-templates.md (partial) |
| Plan | plan-format.md (169 lines) | plan-format-enforcement.md (46 lines) + artifact-formats.md (partial) | artifact-templates.md (partial) |
| Summary | summary-format.md (59 lines) | artifact-formats.md (partial) | artifact-templates.md (partial) |

The plan structure, for example, appears as:
- Full specification in `plan-format.md` (sections, metadata, writing guidance, example skeleton)
- Checklist in `plan-format-enforcement.md` (replicates all required fields and sections)
- Skeleton in `artifact-templates.md` (replicates metadata and section structure)

**Impact**: Agents loading all three files for a plan task consume ~400 lines of context for essentially the same information said three ways.

### 3. Report Format -- Specific Verbosity Issues

**report-format.md (131 lines)**:
- Lines 97-131 (35 lines): "Context Extension Recommendations Section" -- elaborates a concept already explained in the main structure section. The inline description at line 25-26 plus the example in the skeleton (lines 88-91) suffice. The 35-line expansion adds an "entry format" code block, "when to include", "when to omit", and another example -- all of which could be a 5-line note.
- Lines 28-38 (11 lines): "Project Context (optional)" field descriptions could be 4 lines. Each field has a one-line description plus an example sentence. The description alone suffices since the field names are self-documenting.
- Lines 40-44 (5 lines): Timestamp section restates "do not use emojis" and "do not include status markers" -- both already covered by general rules. Could be 1 line.

**Potential savings**: ~40 lines (30% of file).

### 4. Plan Format -- Specific Verbosity Issues

**plan-format.md (169 lines)**:
- Lines 28-63 (36 lines): `plan_metadata` JSON schema for state.json. This is state management documentation, not plan format documentation. It belongs in state-management-schema.md and is duplicated there. Could be replaced with a 2-line cross-reference.
- Lines 84-103 (20 lines): Dependency Analysis format explanation. This is useful but the explanation text between the table and the "generate the table" bullet is redundant with the example.
- Lines 117-169 (53 lines): Example skeleton. Useful but duplicates artifact-templates.md. If we eliminate the template file (see recommendation 3), this stays. If not, one copy should be removed.

**Potential savings**: ~40-50 lines (25-30% of file).

### 5. Summary Format -- Already Lean

**summary-format.md (59 lines)**: This file is already concise. The example skeleton is short and clean. No significant verbosity found. Minor: the "Status Marker Usage" section (2 lines) restates rules from status-markers.md.

**Potential savings**: ~5 lines (8% of file).

### 6. Return Metadata File -- Example-Heavy

**return-metadata-file.md (503 lines)**:
- Lines 218-479 (262 lines): Nine JSON examples illustrating variations. Most repeat the same schema with minor field differences.
- The schema section (lines 19-48) plus field specifications (lines 50-164) total 145 lines and are complete. The examples are supplementary.

**Recommendation**: Keep 2-3 examples (success, partial, early metadata) and cut 4-5 redundant variants. Save ~150 lines.

### 7. Artifact Templates File -- Redundant With Format Files

**artifact-templates.md (179 lines)**: This file provides "copy-paste skeletons" but each format file already has an "Example Skeleton" section. The templates file adds:
- A slightly different report template (simpler metadata than the format file specifies)
- A plan template that conflicts with plan-format.md on required fields
- A summary template that matches summary-format.md
- An error report template (unique, not in other files)

**Problem**: The report template in artifact-templates.md (lines 10-58) uses `**Date**`, `**Focus**` in metadata instead of the full 8-field metadata block from report-format.md. This inconsistency could confuse agents.

**Recommendation**: Remove the report, plan, and summary templates (they duplicate format files). Keep the error report template. Or consolidate the format files to include a "quick template" section and drop this file.

### 8. Real-World Report Verbosity (Task 442)

Examining the task 442 report (364 lines):
- **Sources/Inputs** (14 lines): Lists every single file path consulted. Could be grouped (e.g., "7 agent files, 4 skill files, 2 command files").
- **Appendix** (55 lines): Repeats the file lists from Recommendations in a "Files Requiring Changes (Summary)" section. This is pure duplication.
- **Code block examples** (30+ lines): Pseudocode for flag parsing that duplicates the actual files.

These patterns are not mandated by the format but are encouraged by the agent instructions ("cite sources/paths", "include references in appendix"). Tightening the guidance could reduce typical report length by 20-30%.

### 9. Validation Script Enforcement

The validation script checks for:

**Reports**: 8 metadata fields (Task, Started, Completed, Effort, Dependencies, Sources/Inputs, Artifacts, Standards) + 5 sections (Executive Summary, Context & Scope, Findings, Decisions, Recommendations).

**Plans**: 8 metadata fields (Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type) + 7 sections + Phase headings + Dependency Analysis table (warning only).

**Summaries**: 6 metadata fields (Task, Status, Started, Completed, Artifacts, Standards) + 6 sections.

Any optimization must preserve these exact field/section names. However, the content within sections is not validated -- only presence of the heading.

### 10. Report Metadata Fields -- "Effort" and "Standards" Add Little Value

- **Effort**: Always a rough estimate written before work begins ("1 hour", "3 hours"). Never updated after completion. No downstream consumer uses this field.
- **Standards**: Always the same 4 files (status-markers.md, artifact-management.md, tasks.md, {format}.md). Never varies meaningfully. Agents copy-paste it.

Both are validated by the script, so removing them requires a script update. But they are candidates for removal or simplification.

---

## Decisions

1. Format files are the authoritative source. Rules and templates should reference, not restate.
2. The validation script constrains what field/section names must be preserved.
3. This is a "trim, don't restructure" effort. No new formats, no new tools.
4. return-metadata-file.md examples should be reduced to 3 representative cases.

---

## Recommendations

### Priority 1: Reduce Duplication Between Format and Template Files

**Effort**: Low. **Impact**: ~100 lines saved across loaded context.

- Remove report, plan, and summary templates from `artifact-templates.md`, keeping only the error report template. Each format file already has an example skeleton.
- Alternatively, shrink artifact-templates.md to a "quick reference" card with just the metadata block and section headings (no content), and mark it as the quick-copy source.

### Priority 2: Trim Report Format's Context Extension Section

**Effort**: Low. **Impact**: ~30 lines saved.

Replace the 35-line "Context Extension Recommendations Section" (lines 97-131) with a 5-line note:
```markdown
**Context Extension Recommendations**: Include when research reveals undocumented topics.
Omit for meta tasks. Format: `- **Topic**: / **Gap**: / **Recommendation**:` per entry.
```

### Priority 3: Move plan_metadata Schema Out of Plan Format

**Effort**: Low. **Impact**: ~35 lines saved from plan-format.md.

The `plan_metadata` JSON schema (lines 28-63) belongs in `state-management-schema.md`. Replace with a 2-line cross-reference: "Plans may include a `plan_metadata` object in state.json. See state-management-schema.md for schema."

### Priority 4: Reduce return-metadata-file.md Examples

**Effort**: Low. **Impact**: ~150 lines saved.

Keep 3 examples: (1) Research Success, (2) Implementation Success, (3) Early Metadata. Remove the 6 other variations that demonstrate the same schema with minor field changes. Add a 2-line note: "Combine fields from the examples above for other scenarios (partial, blocked, meta tasks)."

### Priority 5: Tighten Agent Writing Guidance

**Effort**: Low. **Impact**: Reduces typical report output by 20-30%.

Add to report-format.md writing guidance:
- "Sources/Inputs: Group by category, not individual file paths, when more than 5 sources."
- "Appendix: Do not duplicate content from Findings or Recommendations. Use only for external references and raw data."
- "Omit code blocks that merely restate file contents already cited by path."

### Priority 6: Evaluate Dropping "Effort" and "Standards" Metadata

**Effort**: Medium (requires script update). **Impact**: 2 lines per artifact + simpler instructions.

- **Effort** is never used downstream. Could be dropped or made optional.
- **Standards** never varies. Could be dropped or made a single line in format instructions ("Standards are always status-markers.md, artifact-management.md, tasks.md, and this format file").

This requires updating `validate-artifact.sh` to remove these from required arrays.

### Priority 7: Consolidate plan-format-enforcement.md Into plan-format.md

**Effort**: Low. **Impact**: Eliminates a 46-line file.

The rule checklist duplicates the format spec. Instead, add a 3-line "Checklist" section at the top of plan-format.md. The rule can become a 3-line file that says "See plan-format.md for the authoritative checklist."

---

## Risks & Mitigations

- **Risk**: Removing examples from return-metadata-file.md leaves agents without clear patterns for edge cases.
  **Mitigation**: Keep the 3 most different examples. Edge cases are rare and agents handle them adequately from the schema description alone.

- **Risk**: Consolidating format and template files may break agents that load templates separately.
  **Mitigation**: Check index.json for what agents load artifact-templates.md. Update load_when entries accordingly.

- **Risk**: Tightening writing guidance may make reports feel sparse.
  **Mitigation**: Guidance says "group sources" and "don't duplicate", not "omit sources" or "skip appendix". Content stays, organization improves.

- **Risk**: Dropping Effort/Standards metadata requires validation script changes.
  **Mitigation**: Make this a separate phase. Test script changes before deploying format changes.

---

## Appendix

### Line Count Summary

| File | Current Lines | Estimated After | Savings |
|------|--------------|----------------|---------|
| report-format.md | 131 | ~95 | ~35 (27%) |
| plan-format.md | 169 | ~125 | ~45 (27%) |
| summary-format.md | 59 | ~55 | ~5 (8%) |
| artifact-templates.md | 179 | ~50 | ~130 (73%) |
| return-metadata-file.md | 503 | ~350 | ~150 (30%) |
| plan-format-enforcement.md | 46 | ~5 | ~40 (87%) |
| **Total** | **1087** | **~680** | **~405 (37%)** |

### Caveman Search Query
- URL: https://github.com/JuliusBrussee/caveman/blob/main/README.md

### Validation Script Enforced Fields

**Reports**: Task, Started, Completed, Effort, Dependencies, Sources/Inputs, Artifacts, Standards + sections: Executive Summary, Context & Scope, Findings, Decisions, Recommendations

**Plans**: Task, Status, Effort, Dependencies, Research Inputs, Artifacts, Standards, Type + sections: Overview, Goals & Non-Goals, Risks & Mitigations, Implementation Phases, Testing & Validation, Artifacts & Outputs, Rollback/Contingency + Phase headings (enforced), Dependency Analysis (warning only)

**Summaries**: Task, Status, Started, Completed, Artifacts, Standards + sections: Overview, What Changed, Decisions, Impacts, Follow-ups, References
