# Implementation Plan: Fix CLAUDE.md Hierarchy for Cross-Project Portability

- **Task**: 435 - Fix CLAUDE.md hierarchy for cross-project portability
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/435_fix_claudemd_hierarchy_for_project_portability/reports/01_claudemd-hierarchy.md
- **Artifacts**: plans/01_claudemd-hierarchy.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Two parent-level CLAUDE.md files (`/home/benjamin/.config/CLAUDE.md` and `/home/benjamin/.config/.claude/CLAUDE.md`) contain 100% nvim-specific content. When Claude Code runs in any sibling project (zed, ghostty, etc.), it walks up the directory tree and loads these files, injecting irrelevant Neovim instructions into the session context. The fix rewrites both files to be project-agnostic while relying on the existing, correctly-scoped nvim-specific CLAUDE.md files inside the nvim directory.

### Research Integration

The research report confirmed:
- Both parent files are entirely nvim-specific (titles, links, quick-link paths all reference `nvim/`)
- The parent `.claude/` directory contains a full agent system installation shared by all child projects
- Nvim's own CLAUDE.md files already contain all needed content, so removing it from parents loses nothing
- Option A (rewrite to generic) is recommended over Option B (remove) since the parent `.claude/` directory contains shared infrastructure

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Make `/home/benjamin/.config/CLAUDE.md` a project-agnostic configuration index
- Make `/home/benjamin/.config/.claude/CLAUDE.md` a generic shared-config description
- Ensure no nvim-specific terms appear in either parent file

**Non-Goals**:
- Moving nvim-specific agents/content out of the parent `.claude/` directory (separate task)
- Modifying any nvim-scoped or zed-scoped CLAUDE.md files
- Restructuring the parent `.claude/` agent system

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Parent rewrites break nvim agent system | H | L | All content already exists in nvim-scoped files; parent just forwards |
| Zed or other projects depend on parent content | M | L | Parent content is nvim-specific, so non-nvim projects benefit from removal |
| Parent .claude/ shared infrastructure loses documentation | M | L | New generic CLAUDE.md still documents the shared directory's purpose |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Rewrite Parent CLAUDE.md Files [COMPLETED]

**Goal**: Replace nvim-specific content in both parent-level CLAUDE.md files with project-agnostic content.

**Tasks**:
- [ ] Rewrite `/home/benjamin/.config/CLAUDE.md` to be a generic config-repo index that lists child projects with Claude Code configuration (nvim, zed) and documents the standards discovery convention
- [ ] Rewrite `/home/benjamin/.config/.claude/CLAUDE.md` to describe the shared `.claude/` directory generically, noting that project-specific agent systems live within each child project
- [ ] Verify neither file contains nvim-specific terms (neovim, nvim, neotex, Lua, lazy.nvim, vim.keymap, or any `nvim/` path)

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `/home/benjamin/.config/CLAUDE.md` - Replace entire content with generic config index
- `/home/benjamin/.config/.claude/CLAUDE.md` - Replace entire content with generic shared-config description

**Verification**:
- Grep both files for nvim-specific terms; expect zero matches
- Both files are valid markdown with clear purpose statements

---

### Phase 2: Verify No Breakage [COMPLETED]

**Goal**: Confirm that both the nvim and zed projects still load correctly and that the parent files no longer inject nvim-specific content.

**Tasks**:
- [ ] Read `/home/benjamin/.config/nvim/CLAUDE.md` and `/home/benjamin/.config/nvim/.claude/CLAUDE.md` to confirm they are unchanged and still contain all needed nvim content
- [ ] Read `/home/benjamin/.config/zed/.claude/CLAUDE.md` to confirm it is unchanged
- [ ] Grep the rewritten parent files for any of: `nvim`, `neovim`, `neotex`, `Lua`, `lazy.nvim`, `vim.keymap`
- [ ] Verify the parent CLAUDE.md still lists child projects that have Claude Code configuration

**Timing**: 10 minutes

**Depends on**: 1

**Files to modify**:
- None (read-only verification)

**Verification**:
- Zero nvim-specific terms in parent files
- Nvim-scoped CLAUDE.md files unchanged
- Zed-scoped CLAUDE.md files unchanged

## Testing & Validation

- [ ] Parent `/home/benjamin/.config/CLAUDE.md` contains no nvim-specific terms
- [ ] Parent `/home/benjamin/.config/.claude/CLAUDE.md` contains no nvim-specific terms
- [ ] Nvim project's CLAUDE.md files are untouched
- [ ] Zed project's CLAUDE.md files are untouched
- [ ] Both parent files are valid, well-structured markdown

## Artifacts & Outputs

- `specs/435_fix_claudemd_hierarchy_for_project_portability/plans/01_claudemd-hierarchy.md` (this plan)
- `/home/benjamin/.config/CLAUDE.md` (rewritten)
- `/home/benjamin/.config/.claude/CLAUDE.md` (rewritten)

## Rollback/Contingency

Both files are tracked by git (the nvim repo). Use `git checkout` to restore originals:
```bash
git checkout HEAD -- /home/benjamin/.config/CLAUDE.md
git checkout HEAD -- /home/benjamin/.config/.claude/CLAUDE.md
```

If the parent directory is not a git repo, the original content is small enough to reconstruct from the research report which includes the full file analysis.
