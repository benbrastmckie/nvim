# Implementation Plan: Optimize Artifact Format Verbosity

- **Task**: 443 - optimize_artifact_format_verbosity
- **Status**: [IMPLEMENTING]
- **Effort**: 4 hours
- **Dependencies**: None
- **Research Inputs**: specs/443_optimize_artifact_format_verbosity/reports/01_artifact-format-research.md
- **Artifacts**: plans/02_artifact-format-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Reduce verbosity across the artifact format system (~1087 lines across 6 files) by consolidating duplicate documentation, trimming redundant examples, and tightening writing guidance. Target is a modest 20-30% reduction (~300-400 lines saved) without changing validated field names, section headings, or fundamental structure. The approach is conservative: trim prose filler and eliminate duplication, not restructure.

### Research Integration

Key findings from the research report:
- Same artifact structure documented up to 3 times (format file, rule checklist, template reference)
- `return-metadata-file.md` has 262 lines of examples that repeat the same schema with minor variations
- `artifact-templates.md` duplicates format file skeletons and introduces inconsistencies (different metadata fields)
- Report format has a 35-line section that restates what 5 lines could cover
- Plan format embeds a `plan_metadata` state.json schema that belongs elsewhere
- Real-world reports carry verbose source lists and duplicated appendix content due to loose writing guidance

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

This task advances the "Agent System Quality" theme under Phase 1 by reducing context size agents must load, improving instruction clarity, and eliminating stale cross-references.

## Goals & Non-Goals

**Goals**:
- Remove duplication between format files, rule checklists, and template references
- Trim verbose sections in report-format.md and plan-format.md
- Reduce return-metadata-file.md examples from 9 to 3
- Add concise writing guidance to reduce output verbosity in generated reports
- Preserve all validated field names and section headings

**Non-Goals**:
- Changing the fundamental artifact structure or adding new formats
- "Full caveman" compression -- this is modest trimming
- Removing any metadata fields that the validation script enforces
- Rewriting the validation script logic (only updating its required-field arrays if fields are dropped)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing examples from return-metadata-file.md leaves agents without edge-case patterns | M | L | Keep 3 most distinct examples (research success, implementation success, early metadata) |
| Agents that load artifact-templates.md separately break | M | L | Check index.json load_when entries; update references |
| Tightened writing guidance makes reports too terse | L | L | Guidance says "group" and "avoid duplication", not "omit" |
| Consolidating plan-format-enforcement.md breaks auto-apply rule | M | L | Keep the rule file with a 3-line redirect to plan-format.md |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | 1 |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Trim Format Files (report, plan, summary) [COMPLETED]

**Goal**: Reduce verbosity in the three core format files by cutting redundant sections and tightening prose.

**Tasks**:
- [ ] **report-format.md**: Replace the 35-line "Context Extension Recommendations Section" (lines 97-131) with a 5-line note covering purpose, when to include/omit, and entry format
- [ ] **report-format.md**: Condense the "Project Context (optional)" field descriptions (lines 28-38) from 11 lines to ~4 lines -- field names are self-documenting
- [ ] **report-format.md**: Merge the "Timestamps" section (lines 40-44) into the metadata block description as a single line
- [ ] **report-format.md**: Add concise writing guidance: "Group Sources/Inputs by category when >5 items. Appendix must not duplicate Findings or Recommendations content. Omit code blocks that restate file contents cited by path."
- [ ] **plan-format.md**: Replace the `plan_metadata` JSON schema block (lines 27-63, ~37 lines) with a 2-line cross-reference to state-management-schema.md (verify the schema exists there first; if not, move it)
- [ ] **plan-format.md**: Trim the Dependency Analysis explanation (lines 84-103) by removing text that restates the example table
- [ ] **summary-format.md**: Remove the 2-line "Status Marker Usage" section (redundant with status-markers.md general rule)

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/context/formats/report-format.md` -- trim ~35 lines
- `.claude/context/formats/plan-format.md` -- trim ~45 lines
- `.claude/context/formats/summary-format.md` -- trim ~5 lines

**Verification**:
- Run `validate-artifact.sh` on an existing report, plan, and summary to confirm no regressions
- Confirm all validated section headings and metadata fields still present in format files
- Line count reduction: report ~95, plan ~125, summary ~55

---

### Phase 2: Reduce return-metadata-file.md Examples [NOT STARTED]

**Goal**: Cut the 262-line examples section down to ~80 lines by keeping only 3 representative examples.

**Tasks**:
- [ ] Keep "Research Success" example (lines 218-239) -- demonstrates basic success pattern
- [ ] Keep "Implementation Success (Non-Meta)" example (lines 242-274) -- demonstrates completion_data with roadmap_items
- [ ] Keep "Early Metadata (In Progress)" example (lines 407-427) -- demonstrates early-write pattern
- [ ] Remove the remaining 6 examples: "Implementation Success (Meta with changes)", "Implementation Success (Meta without changes)", "Implementation Partial", "Planning Success", "In Progress with Partial Work", "Implementation In Progress (Phase-Level)"
- [ ] Add a 2-line note after the kept examples: "For other scenarios (meta tasks, partial, blocked, planning), combine the schema fields above. Meta tasks add `claudemd_suggestions` to `completion_data`."
- [ ] Remove or condense the "Relationship to subagent-return.md" comparison table (lines 481-493) into a 1-line note, since the migration is complete

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `.claude/context/formats/return-metadata-file.md` -- trim ~150 lines

**Verification**:
- Schema section (lines 19-164) remains untouched
- Agent Instructions section remains intact
- Remaining examples cover the 3 most common patterns
- File drops from ~503 lines to ~350 lines

---

### Phase 3: Consolidate Template and Rule Duplicates [NOT STARTED]

**Goal**: Eliminate the report/plan/summary templates from artifact-templates.md (they duplicate format files and introduce inconsistencies) and slim down plan-format-enforcement.md to a redirect.

**Tasks**:
- [ ] **artifact-templates.md**: Remove the "Research Reports" template section (report skeleton with wrong metadata fields), the "Implementation Plans" template section (conflicts with plan-format.md on required fields), and the "Implementation Summaries" template section (duplicates summary-format.md)
- [ ] **artifact-templates.md**: Keep the "Error Reports" template (unique, not in other format files) and the file header
- [ ] **artifact-templates.md**: Update the header description to reflect the reduced scope (error reports only, plus reference links to format files for other types)
- [ ] **plan-format-enforcement.md**: Replace the full checklist body (lines 7-47) with a 5-line version: keep the `paths:` frontmatter, add "Full specification: plan-format.md", list just the 8 required metadata field names and 7 section names as compact bullet lists, keep the phase heading format note
- [ ] Update `.claude/context/index.json` if artifact-templates.md has load_when entries that need adjusting
- [ ] Update `.claude/rules/artifact-formats.md` "Template Reference" section (last 3 lines) to note templates file now covers error reports only

**Timing**: 1 hour

**Depends on**: 1 (format files must be trimmed first so we know what the authoritative source looks like)

**Files to modify**:
- `.claude/context/reference/artifact-templates.md` -- reduce from ~179 to ~50 lines
- `.claude/rules/plan-format-enforcement.md` -- reduce from 46 to ~15 lines
- `.claude/context/index.json` -- update load_when if needed
- `.claude/rules/artifact-formats.md` -- update template reference note

**Verification**:
- Error report template still present and complete in artifact-templates.md
- plan-format-enforcement.md still has paths frontmatter and references plan-format.md
- No broken cross-references (grep for "artifact-templates" across .claude/)
- `validate-artifact.sh` still passes on existing artifacts

---

### Phase 4: Validation and Cross-Reference Sweep [NOT STARTED]

**Goal**: Verify all changes work together, update any remaining cross-references, and confirm line count targets.

**Tasks**:
- [ ] Run `validate-artifact.sh` on 3 real artifacts (one report, one plan, one summary from recent tasks) to confirm no validation regressions
- [ ] Grep `.claude/` for references to removed sections or relocated content; fix any stale pointers
- [ ] Verify `plan_metadata` schema is accessible from its new location (or that the cross-reference in plan-format.md points to a valid target)
- [ ] Tally final line counts and compare against research targets (report ~95, plan ~125, summary ~55, templates ~50, return-meta ~350, enforcement ~15)
- [ ] Run `check-extension-docs.sh` to confirm no doc-lint regressions

**Timing**: 0.5 hours

**Depends on**: 1, 2, 3

**Files to modify**:
- Any files with stale cross-references (discovered during sweep)

**Verification**:
- All validation scripts pass
- No grep hits for removed section names or relocated content
- Total line savings approximately 350-400 lines (33-37% reduction)

## Testing & Validation

- [ ] `validate-artifact.sh <recent_report> report` exits 0
- [ ] `validate-artifact.sh <recent_plan> plan` exits 0
- [ ] `validate-artifact.sh <recent_summary> summary` exits 0
- [ ] `check-extension-docs.sh` exits 0
- [ ] No broken `@`-references in CLAUDE.md files
- [ ] All 8 plan metadata fields still present in plan-format.md
- [ ] All 8 report metadata fields still present in report-format.md
- [ ] Error report template preserved in artifact-templates.md

## Artifacts & Outputs

- `.claude/context/formats/report-format.md` (trimmed)
- `.claude/context/formats/plan-format.md` (trimmed)
- `.claude/context/formats/summary-format.md` (minor trim)
- `.claude/context/formats/return-metadata-file.md` (examples reduced)
- `.claude/context/reference/artifact-templates.md` (reduced to error reports only)
- `.claude/rules/plan-format-enforcement.md` (slimmed to redirect)
- `.claude/rules/artifact-formats.md` (template reference updated)

## Rollback/Contingency

All changes are to markdown documentation files tracked in git. If any optimization causes agent misbehavior, revert individual files with `git checkout HEAD~1 -- <path>`. Changes are independent enough that reverting one file does not require reverting others.
