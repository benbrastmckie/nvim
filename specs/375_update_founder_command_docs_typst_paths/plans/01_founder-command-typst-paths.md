# Implementation Plan: Update Founder Command Docs Typst Paths

- **Task**: 375 - Update founder command docs typst paths
- **Status**: [IMPLEMENTING]
- **Effort**: 0.5 hours
- **Dependencies**: Task 373 (typst primary output)
- **Research Inputs**: reports/01_founder-command-typst-paths.md
- **Artifacts**: plans/01_founder-command-typst-paths.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Update output path references in 6 founder command documentation files from markdown/PDF to Typst as the primary output format. Each file has 3 categories of references: the Note about `/implement` output, legacy mode artifact paths, and workflow diagram output paths. The sheet.md file requires special handling since it references PDF output and has XLSX/JSON data artifacts that must remain unchanged.

### Research Integration

Research report `01_founder-command-typst-paths.md` identified all 18 distinct references across 6 files. Each file follows the same structure, making changes highly parallel. The Note lines get a `(with .md fallback)` parenthetical; legacy artifact and workflow diagram paths simply swap `.md` to `.typ`. Sheet.md swaps `.pdf` to `.typ` in the Note and workflow lines while preserving XLSX/JSON data artifact references.

### Roadmap Alignment

No ROAD_MAP.md found.

## Goals & Non-Goals

**Goals**:
- Update all `.md` output path references to `.typ` in 5 standard command files (market, analyze, strategy, legal, finance)
- Update `.pdf` output path references to `.typ` in sheet.md
- Add `(with .md fallback)` notation to Note lines across all 6 files
- Preserve XLSX/JSON data artifact references in sheet.md unchanged

**Non-Goals**:
- Modifying the `/deck` command (uses Slidev, not Typst)
- Changing runtime behavior of any command or skill
- Updating any files outside the 6 specified command documentation files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Line numbers from research may have shifted | L | L | Use content-based matching (Edit tool) rather than line numbers |
| Missing a reference in a file | M | L | Verify each file post-edit with grep for residual `.md` artifact paths |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Update 5 Standard Command Files [COMPLETED]

**Goal**: Update all `.md` output references to `.typ` in market.md, analyze.md, strategy.md, legal.md, and finance.md.

**Tasks**:
- [ ] Update market.md: Note line (add `.typ` primary, `.md` fallback), legacy artifact path `.md` -> `.typ`, legacy table path `.md` -> `.typ`, workflow diagram `.md` -> `.typ`
- [ ] Update analyze.md: same 4 reference categories
- [ ] Update strategy.md: same 4 reference categories
- [ ] Update legal.md: same 4 reference categories
- [ ] Update finance.md: same 4 reference categories

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/commands/market.md` - 4 path references
- `.claude/extensions/founder/commands/analyze.md` - 4 path references
- `.claude/extensions/founder/commands/strategy.md` - 4 path references
- `.claude/extensions/founder/commands/legal.md` - 4 path references
- `.claude/extensions/founder/commands/finance.md` - 4 path references

**Verification**:
- Grep all 5 files for remaining `.md` artifact path references (excluding non-artifact `.md` references like file names of the commands themselves)
- Confirm each Note line includes `(with .md fallback)` parenthetical
- Confirm workflow diagram lines reference `.typ`

---

### Phase 2: Update sheet.md (Special Case) [IN PROGRESS]

**Goal**: Update sheet.md output references from `.pdf` to `.typ`, preserving XLSX/JSON data artifact paths.

**Tasks**:
- [ ] Update sheet.md Note line: `.pdf` -> `.typ` primary, note PDF as compilation target
- [ ] Update sheet.md workflow diagram: `.pdf` -> `.typ`
- [ ] Verify XLSX and JSON data artifact references remain unchanged
- [ ] If sheet.md has legacy `.md` references (not just `.pdf`), update those to `.typ` as well

**Timing**: 10 minutes

**Depends on**: none

**Files to modify**:
- `.claude/extensions/founder/commands/sheet.md` - 2-3 path references (PDF->typ), preserve XLSX/JSON

**Verification**:
- Confirm `.pdf` references in output paths are now `.typ`
- Confirm XLSX and JSON artifact paths are untouched
- Confirm Note line mentions PDF as compilation output

## Testing & Validation

- [ ] Grep all 6 files for `strategy/.*\.md` to confirm no residual markdown output paths
- [ ] Grep all 6 files for `founder/.*\.md` to confirm legacy artifact paths updated
- [ ] Grep sheet.md for `.xlsx` and `.json` to confirm data artifacts preserved
- [ ] Visual review of each Note line for consistent fallback notation

## Artifacts & Outputs

- `specs/375_update_founder_command_docs_typst_paths/plans/01_founder-command-typst-paths.md` (this plan)
- `specs/375_update_founder_command_docs_typst_paths/summaries/01_founder-command-typst-paths-summary.md` (after implementation)
- 6 modified command files in `.claude/extensions/founder/commands/`

## Rollback/Contingency

All changes are to markdown documentation files tracked in git. Revert with `git checkout -- .claude/extensions/founder/commands/{market,analyze,strategy,legal,finance,sheet}.md` if any changes are incorrect.
