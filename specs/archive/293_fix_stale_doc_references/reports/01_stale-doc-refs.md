# Research Report: Task #293

**Task**: 293 - Fix stale path references in docs and context files
**Generated**: 2026-03-25
**Source**: Post-refactor audit of tasks 286-292
**Status**: Researched

---

## Context Summary

**Purpose**: Fix remaining stale `context/core/` references missed by task 288/291
**Scope**: 3 references in 1 file
**Affected Components**: .claude/docs/guides/context-loading-best-practices.md
**Domain**: meta
**Language**: meta

## Findings

The task 288 flatten updated 144 files but missed 3 references in one documentation file. All are bash commands in diagnostic examples that still use the old `context/core` path.

### File: `.claude/docs/guides/context-loading-best-practices.md`

| Line | Stale Text | Corrected Text |
|------|-----------|---------------|
| 772 | `find .claude/context/core -name "*.md" ...` | `find .claude/context -name "*.md" ...` |
| 826 | `find .claude/context/core -name "*.md" ...` | `find .claude/context -name "*.md" ...` |
| 854 | `find .claude/context/core -name "*.md" ...` | `find .claude/context -name "*.md" ...` |

### Search Coverage

Full search of all 520 markdown files in `.claude/` confirmed these are the only remaining stale references to `context/core/`, `context/project/meta/`, `context/project/repo/`, `context/project/processes/`, or `context/project/hooks/`.

## Implementation

Simple find-and-replace: `context/core` -> `context` in the 3 bash command lines.

## Effort Assessment

- **Estimated Effort**: 15 minutes
- **Complexity**: Trivial — 3 line edits in 1 file

---

*Generated from post-refactor audit of tasks 286-292.*
