# Research: Scope Unscoped Rules

## Problem

Two rules files in `~/.config/.claude/rules/` lack `paths:` frontmatter, causing them to load on every file in every project:

| File | Lines | Current Scope | Should Scope To |
|------|-------|---------------|-----------------|
| `git-workflow.md` | 163 | None (global) | `specs/**`, `.claude/**` |
| `neovim-lua.md` | 147 | None (global) | `**/*.lua`, `after/**/*.lua` |

## Duplicate Detection

`git-workflow.md` exists in near-identical form in two locations:
- `~/.config/.claude/rules/git-workflow.md` (163 lines)
- `~/.config/nvim/.claude/rules/git-workflow.md` (163 lines)
- Diff: 1 line difference (artifact path example)

## Fix Plan

### git-workflow.md
1. Add `paths:` frontmatter to scope it to `specs/**/*` and `.claude/**/*` (where git workflow matters)
2. Remove the duplicate in `~/.config/nvim/.claude/rules/` since the global one covers it
3. Alternatively, keep only the nvim-specific copy and remove the global one

### neovim-lua.md
1. Add proper `paths:` frontmatter: `paths: ["**/*.lua", "after/**/*.lua"]`
2. The file already has a comment `Applies to: nvim/**/*.lua, after/**/*.lua` but no machine-readable frontmatter

## Impact

- Saves ~310 lines of context per file touch in non-matching projects
- Eliminates cross-project Lua rule bleeding (e.g., Logos gets neovim-lua rules)
