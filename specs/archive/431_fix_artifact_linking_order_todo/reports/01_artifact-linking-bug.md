# Research Report: Artifact Linking Order and Missing Blank Line in TODO.md

- **Task**: 431 - Fix artifact linking order and missing blank line in TODO.md
- **Started**: 2026-04-14T12:00:00Z
- **Completed**: 2026-04-14T12:30:00Z
- **Effort**: small
- **Dependencies**: None
- **Sources/Inputs**:
  - `specs/TODO.md` -- current state and git history
  - `.claude/scripts/link-artifact-todo.sh` -- artifact linking script
  - `.claude/context/reference/state-management-schema.md` -- expected format spec
  - `.claude/skills/skill-researcher/SKILL.md` -- research postflight
  - `.claude/skills/skill-planner/SKILL.md` -- planner postflight
  - `.claude/skills/skill-implementer/SKILL.md` -- implementer postflight
  - `.claude/skills/skill-team-implement/SKILL.md` -- team implementer postflight
  - Git history: commits d3e4196c through 7da48de1 (task 429 lifecycle)
- **Artifacts**: specs/431_fix_artifact_linking_order_todo/reports/01_artifact-linking-bug.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report.md

## Executive Summary

- Two distinct bugs exist in artifact linking: (1) Research links placed BELOW `**Description**:` instead of above it, and (2) Plan/Summary insertion consuming the blank line above `**Description**:`.
- The `link-artifact-todo.sh` script itself has correct insertion logic for its scope, but **it is not always used** -- some skills and the task creation command link artifacts manually via Edit tool, bypassing the script entirely.
- Task 429's malformed entry was caused by the task creation commit (d3e4196c) placing a `- **Report**:` line BELOW `**Description**:`, which was never corrected. The plan script then correctly inserted `- **Plan**:` above `**Description**:` but this created a split where Research was below and Plan was above.
- Task 428 exhibits the same missing-blank-line bug: `**Description**:` immediately follows `- **Summary**:` with no blank line separator.
- The `specs/` prefix inconsistency is a secondary issue: the script strips `specs/` from paths, but manual Edit-based linking preserves it, leading to mixed link formats.

## Context & Scope

The expected TODO.md task entry format (from state-management-schema.md) is:

```markdown
### {NUMBER}. {TITLE}
- **Effort**: {estimate}
- **Status**: [{STATUS}]
- **Task Type**: {type}
- **Research**: [link](path)
- **Plan**: [link](path)
- **Summary**: [link](path)
- **Completed**: {date}

**Description**: {text}
```

Key format requirements:
1. Artifact links (Research, Plan, Summary) appear BETWEEN metadata fields and `**Description**:`
2. Artifact links appear in order: Research, Plan, Summary
3. A blank line separates the last metadata/artifact line from `**Description**:`
4. Link paths are relative to `specs/` (no `specs/` prefix in the path)

## Findings

### Bug 1: Research Link Placed Below Description (Root Cause: Task Creation)

**Evidence**: Git commit d3e4196c (`task 429: create with docs audit report`) shows the initial task 429 entry:

```markdown
### 429. Update .claude/docs/ to reflect task 428 changes
- **Effort**: small
- **Status**: [NOT STARTED]
- **Task Type**: meta

**Description**: Update .claude/docs/ ...
- **Report**: [docs-audit](specs/429_.../reports/01_docs-audit.md)
```

The `- **Report**:` line was placed AFTER `**Description**:`. This violates the expected format where artifact links go between metadata and description. Additionally, the field name `**Report**` is non-standard -- it should be `**Research**`.

**Impact**: When the research agent later updated this entry (commit dfe54afc), it corrected `**Report**` to `**Research**` and appended the second research link, but it did NOT move the line above `**Description**:`. The Research line remained below Description.

When the plan script then inserted `- **Plan**:` above `**Description**:` (commit 02f1d4b2), the result was:

```markdown
- **Plan**: [02_docs-update-plan.md](429_.../plans/02_docs-update-plan.md)
**Description**: Update .claude/docs/ ...
- **Research**: [docs-audit](...), [docs-update-research](...)
```

This placed Plan ABOVE Description and Research BELOW Description -- the "out of order" appearance.

**Root cause**: The task creation process (which created the initial entry in d3e4196c) placed the artifact link in the wrong position. This is NOT a bug in `link-artifact-todo.sh` -- it's a bug in whoever created the initial task entry (likely the `/task` command or manual agent edit during task creation).

### Bug 2: Missing Blank Line Above Description

**Evidence**: Task 428 (lines 63-64 of current TODO.md):

```markdown
- **Summary**: [01_implementation-summary.md](428_.../summaries/01_implementation-summary.md)
**Description**: Systematic agent system refactoring...
```

No blank line between Summary and Description.

**Root cause in the script**: When `link-artifact-todo.sh` inserts a new field line using Case 1 (lines 124-134), it uses:

```bash
sed -i "${actual_next_line}i\\${new_line}" "$TODO_FILE"
```

This inserts the new line AT the position of `**Description**:`, pushing Description down. If there was originally a blank line above Description at position N and Description at position N+1, after insertion:

- Line N: (blank line)
- Line N+1: new artifact line (inserted)
- Line N+2: **Description** (pushed down)

The blank line ends up ABOVE the artifact line, not between the artifact line and Description. After multiple insertions, the blank line drifts further up and the last artifact line is directly adjacent to Description with no separator.

**Specific scenario for task 428**:
1. Research inserted before Plan/Description -- blank line preserved above Research
2. Plan inserted before Description -- blank line now above Plan, Plan adjacent to Description... but then research was already above plan
3. Summary inserted before Description -- Summary now directly above Description with no blank line

The fundamental issue: **the script inserts before the `next_field` target but does not ensure a blank line remains between the inserted line and `**Description**:`**. When `next_field="**Description**"`, the script should insert before the blank line, not at the Description line itself.

### Bug 3: Inconsistent `specs/` Prefix in Link Paths

**Evidence**: Task 429:
- Research (line 50): `(specs/429_.../reports/...)` -- has `specs/` prefix
- Plan (line 51): `(429_.../plans/...)` -- no `specs/` prefix
- Summary (line 52): `(specs/429_.../summaries/...)` -- has `specs/` prefix

**Root cause**: The `link-artifact-todo.sh` script strips the `specs/` prefix (line 69: `todo_link_path="${artifact_path#specs/}"`). Manual Edit-based linking by agents does NOT strip the prefix. Entries created by the script lack `specs/`, entries created manually by agents include it.

This affects tasks 428 and 429 (Plan links created by script lack `specs/`, Research and Summary links created by agents include it). Older tasks (427, 421) have consistent formatting because they were either all-manual or all-script.

### Bug 4: Summary Uses Same `next_field` as Plan

Both Plan and Summary skills call the script with `next_field="**Description**"`:

```bash
# Plan:
bash .claude/scripts/link-artifact-todo.sh $task_number '**Plan**' '**Description**' "$artifact_path"

# Summary:
bash .claude/scripts/link-artifact-todo.sh $task_number '**Summary**' '**Description**' "$artifact_path"
```

If Plan already exists, Summary should ideally be inserted AFTER Plan, not at Description. Currently the script finds `**Description**:` and inserts Summary directly before it. This works in terms of ordering (Summary ends up between Plan and Description), but it means Summary is always directly adjacent to Description with no blank line.

**Better approach**: Summary's `next_field` could be `**Completed**` or `**Description**`, and the script could be taught to preserve the blank line above Description.

### Comparison: Well-Formatted Entries

Task 427 (lines 66-73) is correctly formatted:

```markdown
### 427. Remove Co-Authored-By trailers...
- **Effort**: large
- **Status**: [COMPLETED]
- **Task Type**: meta
- **Research**: [01_coauthored-by-removal.md](...)
- **Plan**: [01_coauthored-by-removal.md](...)
- **Summary**: [01_coauthored-by-removal-summary.md](...)

**Description**: Two issues remain...
```

This entry has correct ordering, consistent path format, and a blank line before Description. It was likely formatted entirely by manual agent edits, not by the script.

Task 421 (lines 177-185) is also correctly formatted with a blank line before Description.

## Decisions

1. The artifact linking issues have three independent root causes that require three separate fixes.
2. The `link-artifact-todo.sh` script needs to be enhanced to preserve blank lines above `**Description**:`.
3. The task creation process needs to place artifact links above `**Description**:`, not below it.
4. The `specs/` prefix handling needs to be standardized.

## Recommendations

### R1: Fix blank line preservation in `link-artifact-todo.sh` (HIGH priority)

When inserting before `**Description**:`, the script should:
1. Check if the line immediately above `**Description**:` is blank
2. If so, insert the new artifact line ABOVE the blank line (i.e., at `actual_next_line - 1`)
3. This keeps the blank line between the last artifact field and Description

Affected code: Lines 124-134 (Case 1 insertion) and lines 156-178 (Case 3 insertion).

### R2: Fix task creation artifact placement (HIGH priority)

The initial task entry in commit d3e4196c placed `- **Report**:` below `**Description**:`. Investigate the `/task` command or the meta-builder-agent to ensure artifact links are placed in the correct position (between metadata and Description). Also fix the field name from `**Report**` to `**Research**`.

Files to investigate: `.claude/commands/task.md`, `.claude/skills/skill-meta/SKILL.md`, `.claude/agents/meta-builder-agent.md`.

### R3: Standardize `specs/` prefix handling (MEDIUM priority)

Either:
- (a) Remove `specs/` stripping from the script (line 69) so all paths include `specs/`, OR
- (b) Ensure manual agent edits also strip `specs/` (update skill instructions)

Option (a) is simpler since TODO.md is inside `specs/` and relative links from `specs/TODO.md` should include the `specs/` path component for cross-directory links. However, examining the current entries, the links without `specs/` are broken relative links if TODO.md is at `specs/TODO.md`. The links WITH `specs/` are also broken since they'd resolve to `specs/specs/...` from the TODO.md location.

Actually, since TODO.md links are rendered from the project root (not from `specs/`), the correct path format depends on rendering context. The current script strips `specs/` which is correct for project-root-relative links. The manual agent edits that include `specs/` are also correct for project-root-relative links (since paths like `specs/429_.../reports/...` are valid from project root). This is actually consistent -- both formats work when rendered from project root. The inconsistency is cosmetic, not functional.

**Revised recommendation**: Standardize on one format for consistency. Since the schema reference shows links without `specs/` prefix (`[file]({NNN}_{SLUG}/reports/...)`), update the script to match the schema (keep `specs/` stripping), and update skill instructions to strip `specs/` prefix in manual edits.

### R4: Add Summary-specific `next_field` ordering (LOW priority)

Consider updating Summary's `next_field` from `**Description**` to `**Completed**`. When Summary is added, `**Completed**` is also typically added. The script could insert Summary before Completed, keeping Description further down. However, this is lower priority since R1 (blank line preservation) solves the immediate formatting issue.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Fixing blank line logic in sed may have edge cases | Test with --dry-run on multiple task entries before applying |
| Task creation fix may require changes to multiple commands | Audit all task creation paths (task, meta, fix-it, review, errors, spawn) |
| Standardizing specs/ prefix may break existing rendered links | Check rendering context; cosmetic-only change |

## Appendix

### Affected Files

| File | Role | Change Needed |
|------|------|---------------|
| `.claude/scripts/link-artifact-todo.sh` | Artifact linking | Preserve blank line above Description (R1) |
| `.claude/commands/task.md` (or equivalent) | Task creation | Place artifacts above Description (R2) |
| `.claude/skills/skill-researcher/SKILL.md` | Research postflight | Verify script invocation is correct |
| `.claude/skills/skill-planner/SKILL.md` | Planner postflight | Verify script invocation is correct |
| `.claude/skills/skill-implementer/SKILL.md` | Implementer postflight | Verify script invocation is correct |
| `.claude/skills/skill-team-implement/SKILL.md` | Team implementer postflight | Verify script invocation is correct |

### Git Evidence Timeline (Task 429)

| Commit | Action | Effect on TODO.md |
|--------|--------|-------------------|
| d3e4196c | Task creation | `- **Report**:` placed BELOW `**Description**:` |
| dfe54afc | Research complete | `**Report**` renamed to `**Research**`, 2nd link appended, still below Description |
| 02f1d4b2 | Plan created | `- **Plan**:` inserted BEFORE `**Description**:` by script; blank line consumed; Research still below |
| 7da48de1 | Implementation | Agent manually reorganized: moved Research above Plan, added Summary and Completed |

### Script Parameterization Reference

| Skill | field_name | next_field | Artifact Path |
|-------|-----------|------------|---------------|
| skill-researcher | `**Research**` | `**Plan**` | `specs/{NNN}_{SLUG}/reports/{MM}_{slug}.md` |
| skill-planner | `**Plan**` | `**Description**` | `specs/{NNN}_{SLUG}/plans/{MM}_{slug}.md` |
| skill-implementer | `**Summary**` | `**Description**` | `specs/{NNN}_{SLUG}/summaries/{MM}_{slug}.md` |
| skill-team-research | `**Research**` | `**Plan**` | `specs/{NNN}_{SLUG}/reports/{MM}_{slug}.md` |
| skill-team-plan | `**Plan**` | `**Description**` | `specs/{NNN}_{SLUG}/plans/{MM}_{slug}.md` |
| skill-team-implement | `**Summary**` | `**Description**` | `specs/{NNN}_{SLUG}/summaries/{MM}_{slug}.md` |
| skill-reviser | `**Plan**` | `**Description**` | `specs/{NNN}_{SLUG}/plans/{MM}_{slug}.md` |
