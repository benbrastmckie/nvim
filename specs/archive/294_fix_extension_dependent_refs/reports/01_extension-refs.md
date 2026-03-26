# Research Report: Task #294

**Task**: 294 - Fix extension-dependent @-references in root CLAUDE.md and code-reviewer agent
**Generated**: 2026-03-25
**Source**: Post-refactor audit of tasks 286-292
**Status**: Researched

---

## Context Summary

**Purpose**: Fix references to extension-provided files that only exist when extensions are loaded
**Scope**: 8 references across 2 files
**Affected Components**: Root CLAUDE.md, code-reviewer-agent.md
**Domain**: meta
**Language**: meta

## Findings

Two files reference `.claude/context/project/{domain}/` paths that only exist after the extension loader copies them from `.claude/extensions/*/context/`. These references break when extensions aren't loaded.

### File 1: Root CLAUDE.md (`/home/benjamin/.config/nvim/CLAUDE.md`)

4 references to neovim standards files:

| Line | Reference | Status |
|------|----------|--------|
| 34 | `.claude/context/project/neovim/standards/documentation-policy.md` | Broken pre-load |
| 37 | `.claude/context/project/neovim/standards/box-drawing-guide.md` | Broken pre-load |
| 40 | `.claude/context/project/neovim/standards/emoji-policy.md` | Broken pre-load |
| 63 | `.claude/context/project/neovim/standards/lua-assertion-patterns.md` | Broken pre-load |

**Root cause**: These references predate the refactor. The root CLAUDE.md is always loaded (not extension-dependent), but these files only exist when the nvim extension is active.

**Recommended fix**: Since this IS a neovim config repo and the nvim extension is almost always loaded, either:
- (a) Point to the canonical source in the extension: `.claude/extensions/nvim/context/project/neovim/standards/`
- (b) Add a note that these require the nvim extension to be loaded
- (c) Move these 4 standards references into the nvim extension's EXTENSION.md instead of root CLAUDE.md

Option (c) is cleanest — these are neovim-specific standards that belong in the extension's documentation section, not the root config.

### File 2: `.claude/agents/code-reviewer-agent.md`

4 @-references to extension-dependent context:

| Line | Reference | Extension |
|------|----------|-----------|
| 43 | `@.claude/context/project/neovim/standards/lua-style-guide.md` | nvim |
| 44 | `@.claude/context/project/neovim/lua-patterns.md` | nvim |
| 47 | `@.claude/context/project/web/standards/web-style-guide.md` | web |
| 48 | `@.claude/context/project/web/astro-framework.md` | web |

**Root cause**: The code-reviewer is a core agent but references extension-specific context. These @-refs will fail when the relevant extension isn't loaded.

**Recommended fix**: Mark these as conditional with comments, or restructure to use index.json discovery instead of hardcoded @-refs. The agent should gracefully handle missing extension context.

### Verification: context-layers.md is correct

The architecture document at `.claude/context/architecture/context-layers.md` correctly states extension context is "rebuilt each time extensions are loaded" — no misleading permanence claims.

## Implementation

1. Move neovim standards references from root CLAUDE.md to nvim EXTENSION.md
2. Add conditional markers or index-based discovery to code-reviewer-agent.md
3. Verify no other core agents have hardcoded extension paths

## Effort Assessment

- **Estimated Effort**: 1 hour
- **Complexity**: Moderate — requires design decision on how to handle conditional references

---

*Generated from post-refactor audit of tasks 286-292.*
