# Research Report: Task #435

**Task**: 435 - Fix CLAUDE.md hierarchy for project portability
**Started**: 2026-04-14T18:00:00Z
**Completed**: 2026-04-14T18:15:00Z
**Effort**: Small
**Dependencies**: None
**Sources/Inputs**:
- Codebase: All CLAUDE.md files in the /home/benjamin/.config/ hierarchy
- Claude Code documentation behavior (observed from system-reminder loading)
**Artifacts**:
- specs/435_fix_claudemd_hierarchy_for_project_portability/reports/01_claudemd-hierarchy.md
**Standards**: report-format.md, artifact-management.md

## Executive Summary

- The `/home/benjamin/.config/CLAUDE.md` file explicitly references nvim paths and "Neovim Configuration Guidelines", leaking nvim-specific context into any sibling project (zed, ghostty, etc.)
- The `/home/benjamin/.config/.claude/CLAUDE.md` file is entirely nvim-specific (titled "Neovim Configuration Agent System" with all paths pointing to `nvim/` subdirectories)
- When Claude Code runs in `/home/benjamin/.config/zed/`, it walks up and loads both parent files, injecting irrelevant nvim instructions into the zed context
- The fix requires making the two parent-level files project-agnostic while preserving nvim functionality via nvim's own CLAUDE.md files (which already exist and are comprehensive)

## Context & Scope

Claude Code discovers CLAUDE.md files by walking up the directory tree from the working directory. The hierarchy is:

```
/home/benjamin/
  .config/
    CLAUDE.md                    <-- Loaded by ALL child projects
    .claude/
      CLAUDE.md                  <-- Loaded by ALL child projects
    nvim/                        (git repo)
      CLAUDE.md                  <-- nvim-specific, correctly scoped
      .claude/
        CLAUDE.md                <-- nvim-specific, correctly scoped
    zed/                         (git repo)
      .claude/
        CLAUDE.md                <-- zed-specific, correctly scoped
    ghostty/
    alacritty/
    ... (50+ other config directories)
```

When Claude Code starts in `/home/benjamin/.config/zed/`, it loads:
1. `/home/benjamin/.config/CLAUDE.md` -- **leaks nvim content**
2. `/home/benjamin/.config/.claude/CLAUDE.md` -- **leaks nvim content**
3. `/home/benjamin/.config/zed/.claude/CLAUDE.md` -- correct, zed-specific

The nvim project is unaffected because its own CLAUDE.md files override/extend the parent, but ALL other projects under `.config/` receive irrelevant nvim instructions.

## Findings

### File-by-File Analysis

#### 1. `/home/benjamin/.config/CLAUDE.md` (19 lines)

**Nvim-specific content (100% of substantive content):**
- Line 7: `[Neovim Configuration Guidelines](nvim/CLAUDE.md)` -- direct nvim reference
- Line 8: `[Agent System Configuration](.claude/CLAUDE.md)` -- points to nvim-focused .claude
- Line 9: `[Standards Documentation](.claude/docs/README.md)` -- points to nvim agent docs

**Assessment**: The entire "Primary Configuration" section is nvim-specific. The "Standards Discovery" section is generic but references CLAUDE.md files that are nvim-specific.

#### 2. `/home/benjamin/.config/.claude/CLAUDE.md` (16 lines)

**Nvim-specific content (100%):**
- Line 1: Title is "Neovim Configuration Agent System"
- Line 3: "This repository uses nvim/.claude/ as the primary Claude Code configuration."
- Line 7: Links to `nvim/.claude/CLAUDE.md`
- Lines 9-13: All quick links point to `nvim/` paths:
  - `nvim/specs/TODO.md`
  - `nvim/specs/state.json`
  - `nvim/.claude/commands/`
  - `nvim/.claude/skills/`
  - `nvim/.claude/agents/`

**Assessment**: This file is entirely nvim-specific. Every line references nvim paths or nvim concepts. It has no project-agnostic content at all.

#### 3. `/home/benjamin/.config/nvim/CLAUDE.md` (74 lines) -- No changes needed

Correctly scoped to nvim. Contains Lua code style, neotex namespaces, vim.keymap references, lazy.nvim format, etc. This file is only loaded when Claude Code runs inside the nvim directory.

#### 4. `/home/benjamin/.config/nvim/.claude/CLAUDE.md` (352 lines) -- No changes needed

Correctly scoped. Contains the full agent system documentation. Only loaded within the nvim project.

#### 5. `/home/benjamin/.config/zed/.claude/CLAUDE.md` (352 lines) -- Not in scope

Zed's own agent system configuration. Independent and correctly scoped.

### Impact Assessment

Any project under `/home/benjamin/.config/` that does NOT have its own CLAUDE.md will inherit ONLY the nvim-focused parent files. Projects with their own CLAUDE.md (nvim, zed) get their content PLUS the nvim parent content, creating confusion.

Affected directories (partial list of 50+):
- `ghostty/`, `alacritty/` -- terminal emulators
- `fish/` -- shell config
- `git/` -- git config
- `fonts/` -- font config

## Decisions

1. The parent `/home/benjamin/.config/CLAUDE.md` should become a generic project-agnostic index
2. The parent `/home/benjamin/.config/.claude/CLAUDE.md` should become generic or be removed entirely
3. All nvim-specific content already exists in the nvim-scoped files, so removing it from parents loses nothing

## Recommendations

### Priority 1: Rewrite `/home/benjamin/.config/CLAUDE.md`

Replace the nvim-specific content with a project-agnostic configuration index:

```markdown
# Configuration Repository Index

This directory contains configuration files for multiple applications.
Each subdirectory is an independent project with its own standards.

## Standards Discovery

Each subdirectory may contain its own CLAUDE.md with project-specific
coding standards and guidelines. Subdirectory CLAUDE.md files take
precedence over this file.

## Subdirectories

Projects with Claude Code configuration:
- `nvim/` - Neovim configuration (has own CLAUDE.md and .claude/)
- `zed/` - Zed editor configuration (has .claude/)

## Notes

Do not add project-specific content to this file. Each project should
maintain its own CLAUDE.md at its root level.
```

### Priority 2: Rewrite `/home/benjamin/.config/.claude/CLAUDE.md`

Two options:

**Option A (Recommended): Make it generic**

```markdown
# Shared Configuration

This .claude/ directory exists at the parent level of multiple
independent projects. Project-specific agent systems, commands,
and skills are defined within each project's own .claude/ directory.

## Convention

Each project (nvim/, zed/, etc.) maintains its own:
- .claude/CLAUDE.md - Project-specific agent system
- specs/ - Task management
- .claude/commands/ - Slash commands

Do not add project-specific configuration here.
```

**Option B: Remove it entirely**

If the `.claude/` directory at `/home/benjamin/.config/.claude/` contains only nvim-forwarding content with no shared utilities, it could be removed or its CLAUDE.md deleted. This would eliminate the leakage entirely.

**Evaluation**: Option A is safer because other files may exist in `/home/benjamin/.config/.claude/` that serve a purpose. Option B is cleaner but requires auditing the full directory.

### Priority 3: Audit `/home/benjamin/.config/.claude/` directory contents

Before deciding on Option A vs B, check what else lives in `/home/benjamin/.config/.claude/` besides CLAUDE.md. If it contains shared commands, rules, or docs that nvim and zed both use, it should be kept generic. If it only contains nvim-forwarding content, Option B applies.

### What NOT to change

- `/home/benjamin/.config/nvim/CLAUDE.md` -- correctly scoped, no changes needed
- `/home/benjamin/.config/nvim/.claude/CLAUDE.md` -- correctly scoped, no changes needed
- `/home/benjamin/.config/zed/.claude/CLAUDE.md` -- independent project, no changes needed

## Risks & Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Removing parent content breaks nvim agent system | Low | All content already duplicated in nvim-scoped files; parent just forwards |
| Other projects rely on parent .claude/ content | Low | Audit .claude/ directory before changes |
| Parent CLAUDE.md removal breaks standards discovery | None | We are rewriting, not removing; child files still work |
| Zed already inherits confusing nvim context | Current | This fix directly addresses this |

### Priority 3 (Updated): Audit Results for `/home/benjamin/.config/.claude/`

The parent `.claude/` directory contains a FULL agent system installation:

```
/home/benjamin/.config/.claude/
  agents/          -- 6 agent definitions (including neovim-specific agents)
  commands/        -- 10 command definitions
  skills/          -- Full skill directory
  rules/           -- Rule definitions
  context/         -- Context files
  docs/            -- Documentation
  hooks/           -- Git/command hooks
  settings.json    -- Claude Code settings
  README.md        -- 34KB README
  scripts/         -- Utility scripts
  templates/       -- Templates
```

This is significant: the parent `.claude/` is a complete agent system that gets loaded by ALL child projects. The nvim project has its own `.claude/` that extends/overrides this, but zed and other projects inherit ALL of this parent content including nvim-specific agents like `neovim-implementation-agent.md` and `neovim-research-agent.md`.

**Recommendation update**: Option B (remove) is not viable since this directory contains real shared infrastructure. Instead, the CLAUDE.md within it should be made generic, and any nvim-specific agents/content should be moved to the nvim project's own `.claude/` directory. This may warrant a separate task for the full migration.

## Appendix

### Claude Code CLAUDE.md Loading Order

When running in `/home/benjamin/.config/zed/`:
1. Walk up: `/home/benjamin/.config/CLAUDE.md` (loaded)
2. Walk up: `/home/benjamin/.config/.claude/CLAUDE.md` (loaded)
3. Stop at home dir (no CLAUDE.md at `/home/benjamin/`)
4. Project root: `/home/benjamin/.config/zed/.claude/CLAUDE.md` (loaded)

### Nvim-Specific Terms Found in Parent Files

Terms that should NOT appear in project-agnostic parent files:
- "Neovim" / "nvim" / "neovim"
- "neotex" (nvim plugin namespace)
- "Lua" (nvim language)
- "lazy.nvim" (nvim plugin manager)
- "vim.keymap" (nvim API)
- Any path starting with `nvim/`

### Directory Structure Verification

```
/home/benjamin/.config/  -- NOT a git repo
/home/benjamin/.config/nvim/  -- git repo (master branch)
/home/benjamin/.config/zed/  -- git repo (separate)
```

Each is an independent git repository. The parent directory is not version-controlled.
