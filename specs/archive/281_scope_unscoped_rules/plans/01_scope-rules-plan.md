# Implementation Plan: Scope Unscoped Rules

**Task**: 281
**Language**: meta
**Created**: 2026-03-25

## Phases

### Phase 1: Add paths frontmatter to neovim-lua.md [COMPLETED]

Add `paths:` YAML frontmatter to `~/.config/.claude/rules/neovim-lua.md` so it only loads for Lua files.

**Files Modified**:
- `~/.config/.claude/rules/neovim-lua.md`

**Verification**: File has valid YAML frontmatter with paths field.

### Phase 2: Deduplicate and scope git-workflow.md [COMPLETED]

Keep the nvim-specific copy at `~/.config/nvim/.claude/rules/git-workflow.md` (canonical, more up-to-date artifact path example). Replace the global copy at `~/.config/.claude/rules/git-workflow.md` with a symlink to the nvim copy. Add `paths:` frontmatter to the canonical copy.

**Files Modified**:
- `~/.config/nvim/.claude/rules/git-workflow.md` - Add paths frontmatter
- `~/.config/.claude/rules/git-workflow.md` - Replace with symlink

**Verification**: Symlink resolves correctly; canonical file has valid frontmatter.

### Phase 3: Update task state [COMPLETED]

Mark task 281 as completed in state.json and TODO.md.

**Files Modified**:
- `specs/state.json`
- `specs/TODO.md`
