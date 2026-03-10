# Implementation Plan: Rename /learn Command to /fix-it

- **Task**: 173 - Rename /learn command to /fix-it
- **Status**: [NOT STARTED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Date**: 2026-03-10
- **Feature**: Rename /learn command to /fix-it across .claude/ system
- **Estimated Hours**: 1-2 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

Rename the `/learn` command to `/fix-it` throughout the `.claude/` system using a clean-break approach (no backwards compatibility). This involves renaming 2 files and 1 directory, then updating approximately 67 references across 8 files. The `.opencode/` system already completed an equivalent rename (`/learn` -> `/fix`), confirming the pattern is straightforward. Definition of done: `grep -rn "/learn\|skill-learn" .claude/` returns zero results (excluding specs/ archives).

### Research Integration

Research report research-001.md identified all 8 files requiring changes with exact line numbers and reference counts. Key finding: no Lua/Neovim files, agent frontmatter, or context/index.json entries reference `/learn`, limiting scope to `.claude/` command infrastructure and documentation.

## Goals & Non-Goals

**Goals**:
- Rename command file from `learn.md` to `fix-it.md`
- Rename skill directory from `skill-learn/` to `skill-fix-it/`
- Rename example file from `learn-flow-example.md` to `fix-it-flow-example.md`
- Update all internal references to use `/fix-it` and `skill-fix-it`
- Maintain zero broken references in `.claude/` documentation

**Non-Goals**:
- Modifying `.opencode/` system files (separate system, already renamed)
- Updating `specs/archive/` historical records
- Adding backwards compatibility or deprecation wrappers
- Changing the command's functionality or behavior

## Risks & Mitigations

- **Risk**: Missing a reference causing broken documentation links. Impact: Low. Likelihood: Low. Mitigation: Post-implementation grep verification in Phase 3.
- **Risk**: Git history discontinuity from file renames. Impact: Low. Likelihood: Low. Mitigation: Use `git mv` for renames to preserve history tracking.

## Implementation Phases

### Phase 1: Rename Files and Directories [NOT STARTED]

- **Goal:** Rename command file, skill directory, and example file using `git mv` to preserve history.
- **Tasks:**
  - [ ] Rename `.claude/commands/learn.md` to `.claude/commands/fix-it.md` using `git mv`
  - [ ] Rename `.claude/skills/skill-learn/` to `.claude/skills/skill-fix-it/` using `git mv`
  - [ ] Rename `.claude/docs/examples/learn-flow-example.md` to `.claude/docs/examples/fix-it-flow-example.md` using `git mv`
- **Timing:** 10 minutes
- **Files to modify:**
  - `.claude/commands/learn.md` -> `.claude/commands/fix-it.md`
  - `.claude/skills/skill-learn/` -> `.claude/skills/skill-fix-it/`
  - `.claude/docs/examples/learn-flow-example.md` -> `.claude/docs/examples/fix-it-flow-example.md`
- **Verification:** All three renames complete without error; `ls` confirms new paths exist and old paths do not.

---

### Phase 2: Update All Content References [NOT STARTED]

- **Goal:** Update all internal references from `/learn` and `skill-learn` to `/fix-it` and `skill-fix-it` across all affected files.
- **Tasks:**
  - [ ] Update `.claude/commands/fix-it.md`: Change heading `# /learn Command` to `# /fix-it Command` and update 4 usage examples from `/learn` to `/fix-it`
  - [ ] Update `.claude/skills/skill-fix-it/SKILL.md`: Change `name: skill-learn` to `name: skill-fix-it`, update description, heading, and commit message prefix (4 references)
  - [ ] Update `.claude/CLAUDE.md`: Update command reference table entry and multi-task creation compliance table entry (2 references)
  - [ ] Update `.claude/docs/README.md`: Update tree entry and link text/target (2 references)
  - [ ] Update `.claude/docs/guides/user-guide.md`: Update TOC entry, section header, usage syntax, examples, and quick reference table (7 references)
  - [ ] Update `.claude/docs/reference/standards/multi-task-creation-standard.md`: Update table entries, example comments, section headers, and file references (6 references)
  - [ ] Update `.claude/docs/examples/fix-it-flow-example.md`: Update all ~40 references to `/learn`, `skill-learn`, `learn.md`, and related strings throughout the file
- **Timing:** 40 minutes
- **Files to modify:**
  - `.claude/commands/fix-it.md` - 5 references
  - `.claude/skills/skill-fix-it/SKILL.md` - 4 references
  - `.claude/CLAUDE.md` - 2 references
  - `.claude/docs/README.md` - 2 references
  - `.claude/docs/guides/user-guide.md` - 7 references
  - `.claude/docs/reference/standards/multi-task-creation-standard.md` - 6 references
  - `.claude/docs/examples/fix-it-flow-example.md` - ~40 references
- **Verification:** Each file saved without errors; spot-check key references are updated.

---

### Phase 3: Verification and Cleanup [NOT STARTED]

- **Goal:** Confirm zero remaining references to `/learn` or `skill-learn` in `.claude/` (excluding specs/ archives) and validate documentation links.
- **Tasks:**
  - [ ] Run `grep -rn "/learn\|skill-learn\|learn\.md\|learn-flow" .claude/` and confirm zero results
  - [ ] Run `grep -rn "fix-it" .claude/commands/fix-it.md` to confirm the renamed command file has correct references
  - [ ] Run `grep -rn "skill-fix-it" .claude/skills/skill-fix-it/SKILL.md` to confirm skill references are correct
  - [ ] Verify `.claude/docs/README.md` link target resolves to the renamed example file
  - [ ] Verify `.claude/docs/guides/user-guide.md` anchor links are consistent with renamed section headers
- **Timing:** 10 minutes
- **Verification:** All grep checks pass with expected results; no stale references remain.

## Testing & Validation

- [ ] `grep -rn "/learn" .claude/` returns zero results (excluding specs/)
- [ ] `grep -rn "skill-learn" .claude/` returns zero results
- [ ] `grep -rn "learn-flow-example" .claude/` returns zero results
- [ ] `grep -rn "learn\.md" .claude/` returns zero results (excluding specs/)
- [ ] `.claude/commands/fix-it.md` exists and contains `/fix-it` heading
- [ ] `.claude/skills/skill-fix-it/SKILL.md` exists and contains `name: skill-fix-it`
- [ ] `.claude/docs/examples/fix-it-flow-example.md` exists

## Artifacts & Outputs

- plans/implementation-001.md (this file)
- summaries/implementation-summary-20260310.md (upon completion)
- Renamed files: `fix-it.md`, `skill-fix-it/`, `fix-it-flow-example.md`

## Rollback/Contingency

Use `git checkout` to restore original files if issues arise. Since all renames use `git mv`, the full history is preserved and reverting is straightforward:
```bash
git mv .claude/commands/fix-it.md .claude/commands/learn.md
git mv .claude/skills/skill-fix-it/ .claude/skills/skill-learn/
git mv .claude/docs/examples/fix-it-flow-example.md .claude/docs/examples/learn-flow-example.md
```
Then revert content changes with `git checkout HEAD -- .claude/`.
