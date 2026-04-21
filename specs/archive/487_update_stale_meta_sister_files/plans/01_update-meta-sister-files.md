# Implementation Plan: Update Stale Meta Sister Files

- **Task**: 487 - Update stale meta sister files
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: 485 (completed)
- **Research Inputs**: specs/487_update_stale_meta_sister_files/reports/01_meta-sister-files.md
- **Artifacts**: plans/01_update-meta-sister-files.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Delete 3 stale and redundant meta sister files (architecture-principles.md, standards-checklist.md, interview-patterns.md) and rewrite 2 partially stale files (domain-patterns.md, context-revision-guide.md). All changes must be applied to both deployed (.claude/context/meta/) and extension source (.claude/extensions/core/context/meta/) copies, with corresponding index file updates. This cleans up misleading phantom content that could misdirect the meta-builder-agent.

### Research Integration

Research report (01_meta-sister-files.md) provided per-file staleness analysis:
- 3 files are 40-80% stale with phantom components (status-sync-manager, git-workflow-manager, XML structures, unused frontmatter fields) and are redundant with the task 485 meta-guide.md rewrite
- 2 files retain unique value (extension domain templates, context revision guidance) but need path fixes, emoji removal, and stale reference cleanup
- Cross-reference analysis identified 3 files that reference deleted content: context-loading-best-practices.md, context-revision-guide.md, meta-guide.md

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- Advances "Zero stale references to removed/renamed files in .claude/" (Success Metrics)
- Contributes to "Agent System Quality" (Phase 1) by removing misleading context files

## Goals & Non-Goals

**Goals**:
- Remove 3 files that provide inaccurate context to meta-builder-agent
- Rewrite domain-patterns.md (~150 lines) focusing on extension domain templates
- Rewrite context-revision-guide.md (~280 lines) with corrected paths and no emoji
- Update all index files (index.json, index-entries.json, extensions.json) to reflect deletions and new line counts
- Fix cross-references in files that mention deleted content

**Non-Goals**:
- Sweeping phantom component names (status-sync-manager, git-workflow-manager) from the broader 42-file set -- separate task
- Restructuring the meta/ directory or changing the meta-guide.md
- Adding new meta context files

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Deleting files reduces meta-builder-agent context quality | M | L | meta-guide.md already provides comprehensive, accurate context; deleted files were misleading |
| Index file edits introduce JSON syntax errors | M | M | Validate with jq after each edit |
| Extension source and deployed copies drift out of sync | M | L | Phase 1 and 2 explicitly handle both locations in parallel |
| Cross-references missed in cleanup | L | M | Research report identified all references; grep verification in Phase 4 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Delete 3 Redundant Files [COMPLETED]

**Goal**: Remove architecture-principles.md, standards-checklist.md, and interview-patterns.md from both deployed and extension source locations.

**Tasks**:
- [ ] Delete `.claude/context/meta/architecture-principles.md`
- [ ] Delete `.claude/context/meta/standards-checklist.md`
- [ ] Delete `.claude/context/meta/interview-patterns.md`
- [ ] Delete `.claude/extensions/core/context/meta/architecture-principles.md`
- [ ] Delete `.claude/extensions/core/context/meta/standards-checklist.md`
- [ ] Delete `.claude/extensions/core/context/meta/interview-patterns.md`
- [ ] Verify 6 files are gone (3 per location)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `.claude/context/meta/architecture-principles.md` - delete
- `.claude/context/meta/standards-checklist.md` - delete
- `.claude/context/meta/interview-patterns.md` - delete
- `.claude/extensions/core/context/meta/architecture-principles.md` - delete
- `.claude/extensions/core/context/meta/standards-checklist.md` - delete
- `.claude/extensions/core/context/meta/interview-patterns.md` - delete

**Verification**:
- `ls .claude/context/meta/` shows only meta-guide.md, domain-patterns.md, context-revision-guide.md
- `ls .claude/extensions/core/context/meta/` shows the same 3 files

---

### Phase 2: Rewrite domain-patterns.md [COMPLETED]

**Goal**: Slim domain-patterns.md to ~150 lines, keeping the extension domain template and development domain pattern while removing stale business/hybrid domains, phantom attributions, and broken cross-references.

**Tasks**:
- [ ] Read current domain-patterns.md to identify exact content to keep/remove
- [ ] Rewrite with these sections: Development Domain Pattern, Extension Domain Pattern (updated to current manifest format), Domain Type Detection, Agent Count Guidelines, Context File Guidelines
- [ ] Remove: Business Domain, Hybrid Domain, stale cross-references, "Maintained By: Development Team"
- [ ] Write rewritten file to `.claude/context/meta/domain-patterns.md`
- [ ] Copy identical content to `.claude/extensions/core/context/meta/domain-patterns.md`
- [ ] Count final line count for index updates in Phase 4

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/meta/domain-patterns.md` - rewrite (~150 lines)
- `.claude/extensions/core/context/meta/domain-patterns.md` - sync copy

**Verification**:
- File is under 160 lines
- No references to business domains, hybrid domains, or phantom paths
- Both copies are identical (`diff` check)

---

### Phase 3: Rewrite context-revision-guide.md [COMPLETED]

**Goal**: Update context-revision-guide.md (~280 lines) by fixing stale directory references, removing emoji characters, and updating examples to reference current files (removing references to deleted sister files).

**Tasks**:
- [ ] Read current context-revision-guide.md to identify all stale content
- [ ] Fix stale directory paths (`.claude/context/standards/`, `.claude/context/templates/`, `.claude/context/workflows/`)
- [ ] Remove emoji characters from anti-pattern headers (lines 250-253, 259-264)
- [ ] Update "Project Meta" file examples (lines 111-113) to remove deleted files
- [ ] Update example references to match current structure
- [ ] Write rewritten file to `.claude/context/meta/context-revision-guide.md`
- [ ] Copy identical content to `.claude/extensions/core/context/meta/context-revision-guide.md`
- [ ] Count final line count for index updates in Phase 4

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- `.claude/context/meta/context-revision-guide.md` - rewrite (~280 lines)
- `.claude/extensions/core/context/meta/context-revision-guide.md` - sync copy

**Verification**:
- No emoji characters in file
- No references to deleted sister files
- No references to stale directory paths
- Both copies are identical (`diff` check)

---

### Phase 4: Update Index Files and Cross-References [COMPLETED]

**Goal**: Remove deleted file entries from all index files, update line_counts for rewritten files, and fix cross-references in other context files.

**Tasks**:
- [ ] Remove 3 deleted file entries from `.claude/context/index.json`
- [ ] Update `line_count` for domain-patterns.md and context-revision-guide.md in `.claude/context/index.json`
- [ ] Remove 3 deleted file entries from `.claude/extensions/core/index-entries.json`
- [ ] Update `line_count` for rewritten files in `.claude/extensions/core/index-entries.json`
- [ ] Update `.claude/extensions.json` -- remove deleted files from `deployed_files` and `context_files` arrays
- [ ] Fix references in `.claude/docs/guides/context-loading-best-practices.md` (remove/update mentions of deleted files)
- [ ] Fix meta-guide.md "Future Extensions" section 3 reference to sister files (mark as completed or remove)
- [ ] Validate all JSON files with `jq . < file` to confirm syntax
- [ ] Run `grep -r "architecture-principles\|standards-checklist\|interview-patterns" .claude/` to verify no stale references remain (excluding git history)

**Timing**: 45 minutes

**Depends on**: 2, 3

**Files to modify**:
- `.claude/context/index.json` - remove 3 entries, update 2 line_counts
- `.claude/extensions/core/index-entries.json` - remove 3 entries, update 2 line_counts
- `.claude/extensions.json` - remove deleted files from arrays
- `.claude/docs/guides/context-loading-best-practices.md` - fix references
- `.claude/context/meta/meta-guide.md` - update Future Extensions note

**Verification**:
- `jq . .claude/context/index.json` succeeds
- `jq . .claude/extensions/core/index-entries.json` succeeds
- `jq . .claude/extensions.json` succeeds
- grep for deleted filenames returns no results outside specs/ and git history

## Testing & Validation

- [ ] All JSON index files parse cleanly with jq
- [ ] `ls .claude/context/meta/` shows exactly 3 files: meta-guide.md, domain-patterns.md, context-revision-guide.md
- [ ] `ls .claude/extensions/core/context/meta/` shows the same 3 files
- [ ] `diff .claude/context/meta/domain-patterns.md .claude/extensions/core/context/meta/domain-patterns.md` returns no differences
- [ ] `diff .claude/context/meta/context-revision-guide.md .claude/extensions/core/context/meta/context-revision-guide.md` returns no differences
- [ ] grep for deleted filenames across `.claude/` returns zero hits (excluding specs/)
- [ ] Rewritten domain-patterns.md is under 160 lines
- [ ] Rewritten context-revision-guide.md is under 300 lines
- [ ] No emoji characters in any modified file

## Artifacts & Outputs

- `specs/487_update_stale_meta_sister_files/plans/01_update-meta-sister-files.md` (this plan)
- `specs/487_update_stale_meta_sister_files/summaries/01_update-meta-sister-files-summary.md` (after implementation)

## Rollback/Contingency

All deleted files are tracked in git. To restore any deleted file:
```bash
git checkout HEAD -- .claude/context/meta/{filename}
git checkout HEAD -- .claude/extensions/core/context/meta/{filename}
```

For rewritten files, `git diff HEAD` shows exact changes. Full rollback:
```bash
git checkout HEAD -- .claude/context/meta/ .claude/extensions/core/context/meta/
git checkout HEAD -- .claude/context/index.json .claude/extensions/core/index-entries.json .claude/extensions.json
```
