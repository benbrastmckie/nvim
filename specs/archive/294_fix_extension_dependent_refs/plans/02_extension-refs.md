# Implementation Plan: Fix Extension-Dependent References

## Task 294: Fix extension-dependent @-references in root CLAUDE.md and code-reviewer agent

### Summary

Fix 8 references across 2 files that point to extension-provided paths which only exist when extensions are loaded. Point them to canonical extension source locations instead.

### Phase 1: Fix root CLAUDE.md references

**Files**: `CLAUDE.md`

Replace 4 neovim standards paths from `.claude/context/project/neovim/standards/` to `.claude/extensions/nvim/context/project/neovim/standards/`:

| Line | Old Path | New Path |
|------|----------|----------|
| 34 | `.claude/context/project/neovim/standards/documentation-policy.md` | `.claude/extensions/nvim/context/project/neovim/standards/documentation-policy.md` |
| 37 | `.claude/context/project/neovim/standards/box-drawing-guide.md` | `.claude/extensions/nvim/context/project/neovim/standards/box-drawing-guide.md` |
| 40 | `.claude/context/project/neovim/standards/emoji-policy.md` | `.claude/extensions/nvim/context/project/neovim/standards/emoji-policy.md` |
| 63 | `.claude/context/project/neovim/standards/lua-assertion-patterns.md` | `.claude/extensions/nvim/context/project/neovim/standards/lua-assertion-patterns.md` |

### Phase 2: Fix code-reviewer-agent.md references

**Files**: `.claude/agents/code-reviewer-agent.md`

Replace 4 @-references to extension context paths:

| Line | Old Path | New Path | Verified |
|------|----------|----------|----------|
| 43 | `@.claude/context/project/neovim/standards/lua-style-guide.md` | `@.claude/extensions/nvim/context/project/neovim/standards/lua-style-guide.md` | Yes |
| 44 | `@.claude/context/project/neovim/lua-patterns.md` | `@.claude/extensions/nvim/context/project/neovim/domain/lua-patterns.md` | Yes (note: domain/ subdir) |
| 47 | `@.claude/context/project/web/standards/web-style-guide.md` | `@.claude/extensions/web/context/project/web/standards/web-style-guide.md` | Yes |
| 48 | `@.claude/context/project/web/astro-framework.md` | `@.claude/extensions/web/context/project/web/astro-framework.md` | Yes |

### Verification

- All 8 target files confirmed to exist via Glob
- `lua-patterns.md` is at `domain/lua-patterns.md` (not directly under `neovim/`)

### Risks

- None: all target files are part of extension definitions and always exist
