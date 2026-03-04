# Implementation Plan: Task #130

**Task**: OC_130 - Make .opencode system self-contained
**Version**: 001
**Created**: 2026-03-04
**Language**: meta

## Overview

This plan makes the `.opencode` system self-contained by removing dependencies on the `.claude` directory. It involves replacing deprecated format files with their active standards, renaming the `claudemd_suggestions` metadata field to `readme_suggestions` (reflecting the recent consolidation to `.opencode/README.md`), updating all documentation and agent references to point to internal `.opencode/` paths, and handling hook scripts. The goal is to ensure OpenCode operates independently of Claude Code artifacts.

## Phases

### Phase 1: Foundation & Formats

**Status**: [COMPLETED]
**Estimated effort**: 1 hour

**Objectives**:
1.  Replace the deprecated `.opencode/context/core/formats/plan-format.md` with the content from `.claude/context/core/formats/plan-format.md`.
2.  Update internal references within the migrated `plan-format.md` to point to `.opencode/` standards.
3.  Establish `.opencode/hooks/` directory and populate it with hook scripts if they are intended to be part of the OpenCode distribution, or update `wezterm-integration.md` to reflect the correct location.

**Files to modify**:
- `.opencode/context/core/formats/plan-format.md` - Overwrite with valid content.
- `.opencode/context/project/hooks/wezterm-integration.md` - Update path references.
- `.opencode/hooks/` - Create directory and copy hooks if needed.

**Steps**:
1.  Read content of `.claude/context/core/formats/plan-format.md`.
2.  Write that content to `.opencode/context/core/formats/plan-format.md`.
3.  Edit the new file to replace `.claude/` references with `.opencode/`.
4.  Check `.claude/hooks/` content.
5.  Create `.opencode/hooks/` and copy relevant scripts (or symlink if they must remain shared, but "self-contained" implies copy).
6.  Update `wezterm-integration.md` to point to `.opencode/hooks/`.

**Verification**:
- `read .opencode/context/core/formats/plan-format.md` confirms no "DEPRECATED" notice.
- `ls .opencode/hooks/` shows scripts.

---

### Phase 2: Metadata Field Migration

**Status**: [NOT STARTED]
**Estimated effort**: 1 hour

**Objectives**:
1.  Rename `claudemd_suggestions` to `readme_suggestions` in all definitions and usage points.
2.  Update the `/todo` command to consume the new field name.

**Files to modify**:
- `.opencode/context/core/formats/return-metadata-file.md` - Rename field in schema.
- `.opencode/rules/state-management.md` - Rename field in rules.
- `.opencode/commands/todo.md` - Update consumer logic.
- `.opencode/agent/subagents/general-implementation-agent.md` - Update producer logic.

**Steps**:
1.  Edit `return-metadata-file.md`: change `claudemd_suggestions` to `readme_suggestions`.
2.  Edit `state-management.md`: update field name and descriptions (referencing `README.md` instead of `CLAUDE.md`).
3.  Edit `commands/todo.md`: update logic to look for `readme_suggestions`.
4.  Edit `general-implementation-agent.md`: update instruction to output `readme_suggestions`.

**Verification**:
- `grep -r "claudemd_suggestions" .opencode` returns no results (except perhaps in migration notes if we add any, but ideally zero).

---

### Phase 3: Path Reference Updates

**Status**: [NOT STARTED]
**Estimated effort**: 1 hour

**Objectives**:
1.  Update all remaining references to `.claude/` in documentation and agents.

**Files to modify**:
- `.opencode/agent/subagents/planner-agent.md`
- `.opencode/docs/guides/creating-agents.md`
- `.opencode/docs/guides/user-guide.md`
- `.opencode/context/index.md`
- `.opencode/commands/implement.md`
- `.opencode/commands/research.md`

**Steps**:
1.  Run `grep -r ".claude/" .opencode` to find all remaining occurrences.
2.  Systematically edit each file to point to the equivalent `.opencode/` path.
3.  For links to files that might not exist in `.opencode` (e.g., specific guides), verify if they should be copied or if the link should be removed/changed.

**Verification**:
- `grep` check shows only intentional external references (like `~/.claude.json`).

---

## Dependencies

- None

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Breaking `/todo` command | Verify the variable name change in `todo.md` carefully matches the schema change. |
| Missing referenced files | If a `.claude` file is referenced but doesn't exist in `.opencode`, the link will break. I will check for existence and copy the file if necessary (migrating it) during Phase 3. |

## Success Criteria

- [ ] `.opencode/context/core/formats/plan-format.md` is a valid, standalone standard.
- [ ] `claudemd_suggestions` is fully replaced by `readme_suggestions`.
- [ ] No unintentional references to `.claude/` directories remain in `.opencode/`.
