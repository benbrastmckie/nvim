# Implementation Plan: Task #477

- **Task**: 477 - Fix generated CLAUDE.md duplicate header, restore README.md, and improve generation
- **Status**: [NOT STARTED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/477_fix_generated_claudemd_and_restore_readme/reports/01_fix-claudemd-generation.md
- **Artifacts**: plans/01_fix-claudemd-generation.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: true

## Overview

Fix the duplicate `# Agent System` header in the generated `.claude/CLAUDE.md` by removing the heading from the core merge-source fragment (since the header template already provides it). Update the two broken `@.claude/README.md` references in the merge-source to point to `@.claude/docs/README.md`. Add a root `@README.md` reference to the Context Imports section of the merge-source. Regenerate the CLAUDE.md to verify all fixes.

### Research Integration

The research report identified the root cause of the duplicate header: both the header template (`claudemd-header.md`) and the core merge-source (`claudemd.md`) start with `# Agent System`. The report also traced the broken `@.claude/README.md` references to task 467's file move and confirmed that `.claude/docs/README.md` is the installed copy. The report recommended updating references rather than restoring the file, which avoids conflicting with task 467's consolidation intent.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

- Advances "Subagent-return reference cleanup" indirectly -- this task fixes broken references in generated output, establishing a pattern for reference maintenance.
- Advances "Zero stale references to removed/renamed files" success metric.

## Goals & Non-Goals

**Goals**:
- Eliminate the duplicate `# Agent System` header from generated CLAUDE.md
- Fix the two broken `@.claude/README.md` references
- Add a root `@README.md` reference to the generated CLAUDE.md
- Verify the fix by regenerating CLAUDE.md

**Non-Goals**:
- Refactoring the `generate_claudemd()` function itself
- Adding a generation timestamp (low priority per research)
- Fixing the `inject_section()` seed path (low priority, different code path)
- Restoring `.claude/README.md` as a file (updating references is cleaner)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Removing heading breaks fragment readability | L | L | Fragment is a merge source, not standalone documentation |
| Reference path change missed somewhere | M | L | Grep for all `@.claude/README.md` occurrences before and after |
| Regeneration produces unexpected output | M | L | Diff generated file before and after to verify only expected changes |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Fix merge-source content [NOT STARTED]

**Goal**: Remove the duplicate heading and fix broken references in the core merge-source fragment.

**Tasks**:
- [ ] Remove line 1 (`# Agent System`) and the blank line after it from `.claude/extensions/core/merge-sources/claudemd.md`
- [ ] Update line 3 reference `@.claude/README.md` to `@.claude/docs/README.md` (the "For comprehensive documentation" line, which will be line 1 after heading removal)
- [ ] Update line 10 reference `@.claude/README.md` to `@.claude/docs/README.md` (the Architecture quick-reference line)
- [ ] Add `@README.md` to the Context Imports section (alongside `@.claude/context/repo/project-overview.md`)
- [ ] Grep the entire `.claude/` directory for any other `@.claude/README.md` references and fix them

**Timing**: 0.5 hours

**Depends on**: none

**Files to modify**:
- `.claude/extensions/core/merge-sources/claudemd.md` - Remove duplicate heading, fix references, add root README reference

**Verification**:
- The merge-source no longer starts with `# Agent System`
- No `@.claude/README.md` references remain in merge-sources
- `@README.md` appears in Context Imports section
- Grep confirms no remaining broken references in `.claude/`

---

### Phase 2: Regenerate and validate [NOT STARTED]

**Goal**: Regenerate the CLAUDE.md file and verify the output is correct.

**Tasks**:
- [ ] Regenerate `.claude/CLAUDE.md` using the extension loader (`nvim --headless` with appropriate command, or manually trigger `<leader>ac`)
- [ ] Verify the generated file starts with exactly one `# Agent System` heading
- [ ] Verify no `@.claude/README.md` references exist in the generated file
- [ ] Verify `@README.md` appears in the Context Imports section
- [ ] Diff the generated file against the previous version to confirm only expected changes

**Timing**: 0.5 hours

**Depends on**: 1

**Files to modify**:
- `.claude/CLAUDE.md` - Regenerated output (no manual edits)

**Verification**:
- `grep -c "^# Agent System" .claude/CLAUDE.md` returns exactly 1
- `grep "@.claude/README.md" .claude/CLAUDE.md` returns no matches
- `grep "@README.md" .claude/CLAUDE.md` returns at least one match
- The file structure is otherwise unchanged

## Testing & Validation

- [ ] Generated CLAUDE.md has exactly one `# Agent System` heading
- [ ] No broken `@.claude/README.md` references in generated output
- [ ] Root `@README.md` referenced in Context Imports
- [ ] No regressions in other sections of generated CLAUDE.md
- [ ] Extension loading still works correctly after merge-source changes

## Artifacts & Outputs

- `.claude/extensions/core/merge-sources/claudemd.md` - Fixed merge-source fragment
- `.claude/CLAUDE.md` - Regenerated output with fixes applied

## Rollback/Contingency

All changes are to tracked files. If the fix causes issues:
1. `git checkout -- .claude/extensions/core/merge-sources/claudemd.md` to restore the merge-source
2. `git checkout -- .claude/CLAUDE.md` to restore the generated file
3. Re-evaluate the approach based on the failure mode
