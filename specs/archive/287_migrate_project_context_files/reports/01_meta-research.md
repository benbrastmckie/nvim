# Research Report: Task #287

**Task**: 287 - Reassign project context files to correct owners (extensions or core)
**Generated**: 2026-03-25
**Updated**: 2026-03-25
**Source**: /meta interview (auto-generated), revised after project context audit
**Status**: Pre-populated from interview context, revised

---

## Context Summary

**Purpose**: Move each file in .claude/context/project/ to its correct owner (core agent system or extension)
**Scope**: Audit and reassign all 17 files currently in .claude/context/project/
**Affected Components**: .claude/context/project/, nvim extension context, index.json entries
**Domain**: meta
**Language**: meta

## Task Requirements

Audit revealed that `.claude/context/project/` contains zero true project conventions. All 17 files belong to either the core agent system or the nvim extension.

### File Disposition

| File | Current Location | Destination | Reason |
|------|-----------------|-------------|--------|
| `meta/meta-guide.md` | `project/meta/` | `.claude/context/meta/` | Core agent system — meta-builder patterns |
| `meta/architecture-principles.md` | `project/meta/` | `.claude/context/meta/` | Core agent system design |
| `meta/context-revision-guide.md` | `project/meta/` | `.claude/context/meta/` | Core context management |
| `meta/domain-patterns.md` | `project/meta/` | `.claude/context/meta/` | Core system patterns |
| `meta/interview-patterns.md` | `project/meta/` | `.claude/context/meta/` | Core research patterns |
| `meta/standards-checklist.md` | `project/meta/` | `.claude/context/meta/` | Core standards |
| `processes/implementation-workflow.md` | `project/processes/` | `.claude/context/processes/` | Core workflow — cross-cutting |
| `processes/planning-workflow.md` | `project/processes/` | `.claude/context/processes/` | Core workflow — cross-cutting |
| `processes/research-workflow.md` | `project/processes/` | `.claude/context/processes/` | Core workflow — cross-cutting |
| `repo/project-overview.md` | `project/repo/` | `.claude/context/repo/` | Core repo info — system metadata |
| `repo/self-healing-implementation-details.md` | `project/repo/` | `.claude/context/repo/` | Core system patterns |
| `repo/update-project.md` | `project/repo/` | `.claude/context/repo/` | Core system tooling |
| `neovim/standards/box-drawing-guide.md` | `project/neovim/` | nvim extension context | Neovim-specific standard |
| `neovim/standards/documentation-policy.md` | `project/neovim/` | nvim extension context | Neovim-specific standard |
| `neovim/standards/emoji-policy.md` | `project/neovim/` | nvim extension context | Neovim-specific standard |
| `neovim/standards/lua-assertion-patterns.md` | `project/neovim/` | nvim extension context | Neovim/Lua-specific patterns |
| `hooks/wezterm-integration.md` | `project/hooks/` | nvim extension context | Terminal integration for nvim workflow |

### Group 1: Core Agent System (12 files)

These files stay in `.claude/context/` but move up from the `project/` subdirectory:
- `project/meta/` → `.claude/context/meta/` (6 files)
- `project/processes/` → `.claude/context/processes/` (3 files)
- `project/repo/` → `.claude/context/repo/` (3 files)

This aligns with the flatten in task 288 — these become peer directories alongside the existing `core/` contents.

### Group 2: nvim Extension (5 files)

These files move to the nvim extension's context directory:
- `project/neovim/standards/` (4 files) → `.claude/extensions/nvim/context/project/neovim/standards/`
- `project/hooks/wezterm-integration.md` → `.claude/extensions/nvim/context/project/neovim/` (or similar)

The nvim extension already has 12 context files for patterns, tools, domain, and templates. These 5 files complete the picture — the extension loader will copy them to `.claude/context/` when the nvim extension is loaded.

### Migration Steps

1. Move 5 neovim/hooks files to nvim extension context directory
2. Move 12 core files up from `project/` to `.claude/context/` peers (meta/, processes/, repo/)
3. Update `.claude/context/index.json` — remove `project/` prefix from core file paths
4. Update nvim extension's `index-entries.json` — add entries for the 5 moved files
5. Remove empty `project/` directory
6. Verify no broken @-references

### Key Change from Original Plan

**Original**: Migrate repo/, processes/, hooks/ to `.context/`
**Revised**: Nothing goes to `.context/`. Core files stay in `.claude/context/` (promoted out of `project/`). Neovim files go to the nvim extension.

## Integration Points

- **Component Type**: file migration
- **Affected Area**: .claude/context/project/, nvim extension
- **Action Type**: reassign
- **Related Files**:
  - `.claude/context/index.json` (update paths)
  - `.claude/extensions/nvim/context/` (receives 5 files)
  - `.claude/extensions/nvim/index-entries.json` (add entries)

## Dependencies

- Task #286: Create .context/ directory structure (for the schema, even though no files migrate there)

## Interview Context

### User-Provided Information
Audit of all 17 files in `.claude/context/project/` showed that every file belongs to either the core agent system or the nvim extension. No files are truly project conventions. The nvim extension already owns 12 context files — the 4 neovim standards + 1 hooks file complete its context set.

### Effort Assessment
- **Estimated Effort**: 2 hours (reduced — simpler than migrating to new directory)
- **Complexity Notes**: Straightforward file moves and index updates. The nvim extension already has the right directory structure.

---

*This research report was auto-generated during task creation via /meta command.*
*Revised 2026-03-25 after audit showed all project/ files belong to core or extensions.*
*For deeper investigation, run `/research 287 [focus]` with a specific focus prompt.*
