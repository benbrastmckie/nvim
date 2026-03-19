# Research Report: Task #247

**Task**: 247 - Make leader-am model picker write to project-level .claude/settings.local.json
**Started**: 2026-03-19T00:00:00Z
**Completed**: 2026-03-19T00:15:00Z
**Effort**: 0.5-1 hours
**Dependencies**: None
**Sources/Inputs**: Codebase analysis, Claude Code documentation (web search)
**Artifacts**: specs/247_leader_am_per_project_model_picker/reports/01_project-local-model-picker.md
**Standards**: report-format.md

## Executive Summary

- The current `<leader>am` model picker writes to `~/.claude/settings.local.json` (global scope)
- Project-local `settings.local.json` has priority 3 (highest non-managed), overriding global user settings
- Existing codebase patterns provide reusable functions for git root detection, directory existence checks, and directory creation
- Implementation requires detecting git root, checking for `.claude/` directory, and falling back to global path when appropriate

## Context & Scope

The `<leader>am` keymap (lines 367-429 in `which-key.lua`) allows users to select a Claude Code model (Opus, Sonnet, Haiku). Currently it writes to the global `~/.claude/settings.local.json`, but project-specific model selection is often desirable (e.g., using Opus for complex projects, Haiku for quick scripts).

**Scope**:
- Modify model picker to detect current project's git root
- Write to `{git_root}/.claude/settings.local.json` when `.claude/` exists
- Create `.claude/` directory if git root exists but directory doesn't (with user confirmation)
- Fall back to global `~/.claude/settings.local.json` when not in a git repo

## Findings

### Claude Code Settings Priority Hierarchy

From official Claude Code documentation:

| Priority | Location | Description |
|----------|----------|-------------|
| 1 | Enterprise policies | Managed settings (cannot override) |
| 2 | Command-line args | Runtime arguments |
| **3** | `.claude/settings.local.json` | **Project-local (not committed)** |
| 4 | `.claude/settings.json` | Project-shared (committed) |
| 5 | `~/.claude/settings.json` | Global user settings |
| 6 | Default behavior | Claude defaults |

**Key insight**: `settings.local.json` at project level (priority 3) overrides both the committed `settings.json` (priority 4) and global settings (priority 5). This is the correct target for per-project model selection.

**Git ignore**: Claude Code automatically configures git to ignore `.claude/settings.local.json`, so the file won't be committed.

### Current Implementation Analysis

**Location**: `/home/benjamin/.config/nvim/lua/neotex/plugins/editor/which-key.lua`, lines 367-429

**Current behavior**:
```lua
local config_path = vim.fn.expand("~/.claude/settings.local.json")
-- ... reads and writes to this fixed path
```

**JSON handling pattern** (reusable):
```lua
-- Read
local file = io.open(config_path, "r")
if file then
  local content = file:read("*all")
  file:close()
  local ok, settings = pcall(vim.fn.json_decode, content)
  if ok and settings then
    -- use settings
  end
end

-- Write
local write_file = io.open(config_path, "w")
if write_file then
  write_file:write(vim.fn.json_encode(settings))
  write_file:close()
end
```

### Existing Codebase Patterns

#### Git Root Detection

**Existing helper module**: `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/claude-session/git.lua`

```lua
-- Get the git root directory
function M.get_git_root()
  return vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
end

-- Check if current directory is a git repository
function M.is_git_repo()
  local git_dir = vim.fn.system("git rev-parse --git-dir 2>/dev/null"):gsub("\n", "")
  return git_dir:match("%.git") ~= nil
end
```

**Alternative inline pattern** (used in multiple files):
```lua
local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
if git_root ~= "" and vim.v.shell_error == 0 then
  -- valid git root
end
```

**Error detection**: Check `vim.v.shell_error == 0` after `vim.fn.system()` calls.

#### Directory Existence Check

**Pattern from extensions/state.lua**:
```lua
if vim.fn.isdirectory(base_dir) ~= 1 then
  vim.fn.mkdir(base_dir, "p")  -- "p" = create parent directories
end
```

**Pattern from extensions/manifest.lua**:
```lua
local function dir_exists(dirpath)
  return vim.fn.isdirectory(dirpath) == 1
end
```

### Fallback Scenarios

| Scenario | Detection | Behavior |
|----------|-----------|----------|
| Not in git repo | `vim.v.shell_error ~= 0` after git command | Use global path |
| Git root exists, no `.claude/` | `vim.fn.isdirectory(git_root .. "/.claude") ~= 1` | Option 1: Create `.claude/` and use project path; Option 2: Use global path |
| Git root exists, `.claude/` exists | Directory check passes | Use project path |
| `.claude/` exists but file doesn't | File open returns nil | Create new file (JSON write will create) |

**Recommendation**: Create `.claude/` directory automatically if git root exists. Claude Code expects this directory for project-level configuration. Users can delete it if unwanted.

### Proposed Implementation Logic

```lua
-- Determine config path (project-local or global fallback)
local function get_claude_settings_path()
  local global_path = vim.fn.expand("~/.claude/settings.local.json")

  -- Try to get git root
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")

  -- If not in git repo, use global
  if git_root == "" or vim.v.shell_error ~= 0 then
    return global_path, "global"
  end

  local claude_dir = git_root .. "/.claude"
  local project_path = claude_dir .. "/settings.local.json"

  -- Check if .claude/ directory exists
  if vim.fn.isdirectory(claude_dir) == 1 then
    return project_path, "project"
  end

  -- .claude/ doesn't exist - create it (Claude Code expects this)
  vim.fn.mkdir(claude_dir, "p")
  return project_path, "project"
end
```

### UI Feedback Enhancements

The notification should indicate whether the model was saved to project-local or global settings:

```lua
-- After successful write
local scope_label = scope == "project" and "project" or "global"
notify.editor(
  string.format("Model set to %s (%s settings, takes effect on next Claude Code open)",
    choice.label, scope_label),
  notify.categories.USER_ACTION,
  { model = choice.id, scope = scope }
)
```

### Edge Cases

1. **Read-only git root**: `io.open(path, "w")` will return nil - existing error handling covers this
2. **Symlinked git root**: `git rev-parse --show-toplevel` returns canonical path - no special handling needed
3. **Nested git repos**: Uses innermost repo (git behavior) - acceptable
4. **Worktrees**: `--show-toplevel` returns worktree root, not main repo - correct for per-worktree settings

## Decisions

1. **Auto-create `.claude/` directory**: When git root exists but `.claude/` doesn't, create the directory automatically. This matches Claude Code's expected project structure.

2. **No user confirmation for directory creation**: The `.claude/` directory is expected by Claude Code. Users can delete it if unwanted (single empty directory).

3. **Reuse existing git helper module**: Import `require("neotex.plugins.ai.claude.claude-session.git")` for `get_git_root()` and `is_git_repo()` functions.

4. **Scope indication in notification**: Modify the success notification to show "project" or "global" scope so users know where the setting was saved.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Git command slowdown | Git rev-parse is fast (<10ms typically); acceptable for user-initiated action |
| Creating `.claude/` in wrong location | Only create when `git rev-parse` succeeds; validates directory is git-managed |
| File permission issues | Existing error handling catches write failures; show clear error message |
| Race condition (file changed between read/write) | Re-read before write (already implemented); acceptable for user settings |

## Implementation Checklist

- [ ] Extract path determination to helper function
- [ ] Import or inline git root detection
- [ ] Add directory existence check and creation
- [ ] Update read path (initial model display)
- [ ] Update write path (selection handler)
- [ ] Modify notification to show scope
- [ ] Test: not in git repo (should use global)
- [ ] Test: git repo without .claude/ (should create and use project)
- [ ] Test: git repo with .claude/ (should use project)
- [ ] Test: permission denied scenarios

## Appendix

### Search Queries Used
- Claude Code settings.json settings.local.json priority hierarchy project local global

### References
- [Claude Code settings - Official Docs](https://code.claude.com/docs/en/settings)
- `/home/benjamin/.config/nvim/lua/neotex/plugins/editor/which-key.lua` - Current implementation
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/claude/claude-session/git.lua` - Git helper module
- `/home/benjamin/.config/nvim/lua/neotex/plugins/ai/shared/extensions/state.lua` - Directory creation pattern

### Codebase Patterns Referenced
- Git root detection: `claude-session/git.lua`, `core/visual.lua`, `core/session.lua`
- Directory creation: `extensions/state.lua`, `himalaya/utils/file.lua`
- JSON encode/decode: `which-key.lua`, `session-manager.lua`, `worktree.lua`
