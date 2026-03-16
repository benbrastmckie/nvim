# Implementation Plan: Task #214

- **Task**: 214 - restructure_context_grant_to_present
- **Status**: [NOT STARTED]
- **Effort**: 1-1.5 hours
- **Dependencies**: None
- **Research Inputs**: [01_context-restructure-research.md](../reports/01_context-restructure-research.md)
- **Artifacts**: plans/01_context-restructure-plan.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta

## Overview

This task restructures the grant context directory within the present extension by renaming `context/project/grant/` to `context/project/present/` and merging it with existing deck content. The research report identified 28 total path references across 5 files that require updates, plus the physical directory move operation. The implementation will proceed in three phases: directory operations, file reference updates, and validation.

### Research Integration

Key findings from research report:
- 16 path entries in index-entries.json (also update subdomain fields)
- 6 @-references in grant-agent.md (includes 1 typo fix: extensions/grant/ -> extensions/present/)
- 4 @-references in EXTENSION.md
- 1 provides.context entry in manifest.json (simplify from 2 to 1)
- 1 comment reference in skill-grant/SKILL.md (includes typo fix)
- patterns/ directory requires merge (no filename conflicts)

## Goals & Non-Goals

**Goals**:
- Rename `context/project/grant/` to `context/project/present/` within present extension
- Merge grant patterns alongside existing deck patterns in present/patterns/
- Update all 28 path references across 5 files
- Fix 2 typos referencing `extensions/grant/` instead of `extensions/present/`
- Simplify manifest.json provides.context to single entry

**Non-Goals**:
- Changing the actual content of any grant documentation files
- Modifying the deck-related files in present/patterns/
- Restructuring other parts of the present extension

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Overwriting deck patterns during merge | M | L | Verify no filename conflicts before move; research confirms none exist |
| Missing reference updates | H | L | Post-update grep verification for any remaining `project/grant` references |
| Breaking extension loading | H | L | Test extension load after changes complete |
| Incomplete directory removal | L | L | Verify grant/ directory is empty before removal |

## Implementation Phases

### Phase 1: Directory Operations [COMPLETED]

**Goal**: Move grant content to present directory and merge patterns

**Tasks**:
- [ ] Create target subdirectories in present/ (domain/, standards/, templates/, tools/)
- [ ] Move grant/README.md to present/README.md
- [ ] Move grant/domain/* to present/domain/
- [ ] Move grant/patterns/* to present/patterns/ (alongside existing deck patterns)
- [ ] Move grant/standards/* to present/standards/
- [ ] Move grant/templates/* to present/templates/
- [ ] Move grant/tools/* to present/tools/
- [ ] Verify all 16 files moved successfully
- [ ] Remove empty grant/ directory tree

**Timing**: 20 minutes

**Files to modify**:
- `.claude/extensions/present/context/project/grant/` - source directory (remove after move)
- `.claude/extensions/present/context/project/present/` - target directory (add content)

**Verification**:
- All 16 files from grant/ exist in present/ with correct paths
- grant/ directory no longer exists
- Existing deck patterns (pitch-deck-structure.md, touying-pitch-deck-template.md) preserved

---

### Phase 2: Reference Updates [COMPLETED]

**Goal**: Update all 28 path references across 5 files

**Tasks**:
- [ ] Update index-entries.json: change 16 path entries from `project/grant/` to `project/present/`
- [ ] Update index-entries.json: change subdomain field from "grant" to "present" for affected entries
- [ ] Update grant-agent.md: change 6 @-references to use `project/present/` paths
- [ ] Fix grant-agent.md typo: change `extensions/grant/` to `extensions/present/`
- [ ] Update EXTENSION.md: change 4 @-references to use `project/present/` paths
- [ ] Update manifest.json: simplify provides.context from `["project/grant", "project/present"]` to `["project/present"]`
- [ ] Update skill-grant/SKILL.md: change 1 @-reference to use `project/present/` path
- [ ] Fix skill-grant/SKILL.md typo: change `extensions/grant/` to `extensions/present/`

**Timing**: 30 minutes

**Files to modify**:
- `.claude/extensions/present/index-entries.json` - 16 path entries + subdomain fields
- `.claude/extensions/present/agents/grant-agent.md` - 6 @-references + 1 typo
- `.claude/extensions/present/EXTENSION.md` - 4 @-references
- `.claude/extensions/present/manifest.json` - 1 provides.context entry
- `.claude/extensions/present/skills/skill-grant/SKILL.md` - 1 @-reference + 1 typo

**Verification**:
- Each file saved successfully after edits
- No syntax errors in JSON files (index-entries.json, manifest.json)

---

### Phase 3: Validation [COMPLETED]

**Goal**: Verify all references updated and extension functions correctly

**Tasks**:
- [ ] Run grep for remaining `project/grant` references in present extension
- [ ] Verify directory structure matches target structure from research
- [ ] Verify index-entries.json is valid JSON
- [ ] Verify manifest.json is valid JSON
- [ ] Count files in present/ to confirm 18 total (16 grant + 2 deck patterns)

**Timing**: 15 minutes

**Files to modify**: None (validation only)

**Verification**:
- Grep returns no matches for `project/grant` in `.claude/extensions/present/`
- All JSON files parse without errors
- File count matches expected (18 files in present/ tree)

---

## Testing & Validation

- [ ] No remaining `project/grant` references in present extension (grep verification)
- [ ] index-entries.json parses as valid JSON
- [ ] manifest.json parses as valid JSON
- [ ] Directory structure matches target layout from research report
- [ ] All 18 files present in context/project/present/ (16 grant + 2 deck)
- [ ] Empty grant/ directory removed

## Artifacts & Outputs

- plans/01_context-restructure-plan.md (this file)
- summaries/01_context-restructure-summary.md (post-implementation)

## Rollback/Contingency

If issues arise during implementation:
1. Git status shows all changes as uncommitted
2. Use `git checkout -- .claude/extensions/present/` to restore original state
3. Re-run research phase if needed to identify missed references
4. Directory operations can be reversed by moving files back from present/ to grant/
