# Implementation Plan: Task #247

- **Task**: 247 - Make leader-am model picker write to project-level .claude/settings.local.json
- **Status**: [COMPLETED]
- **Effort**: 1-1.5 hours
- **Dependencies**: None
- **Research Inputs**: [01_project-local-model-picker.md](../reports/01_project-local-model-picker.md)
- **Artifacts**: plans/01_project-local-picker.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

Modify the `<leader>am` model picker keymap in which-key.lua to write Claude Code model selection to project-local `.claude/settings.local.json` instead of the global `~/.claude/settings.local.json`. The implementation detects git root via `git rev-parse --show-toplevel`, checks for or creates the `.claude/` directory, and falls back to global settings when not in a git repository. UI notifications will indicate whether the model was saved to project-local or global scope.

### Research Integration

Integrated findings from 01_project-local-model-picker.md:
- Claude Code settings priority: project-local `settings.local.json` (priority 3) overrides global (priority 5)
- Existing git helper module at `lua/neotex/plugins/ai/claude/claude-session/git.lua` provides `get_git_root()` and `is_git_repo()` functions
- Directory existence pattern: `vim.fn.isdirectory(path) == 1` and `vim.fn.mkdir(path, "p")` for creation
- Auto-create `.claude/` directory recommendation (matches Claude Code expected structure)

## Goals & Non-Goals

**Goals**:
- Detect current project's git root using existing git helper module
- Write to `{git_root}/.claude/settings.local.json` when git root exists
- Auto-create `.claude/` directory if git root exists but directory does not
- Fall back gracefully to `~/.claude/settings.local.json` when not in a git repo
- Update notification to show scope (project vs global)

**Non-Goals**:
- User confirmation for directory creation (auto-create per research recommendation)
- Changing the model list or picker UI behavior
- Supporting non-git project roots (only git-based detection)
- Modifying other Claude-related keymaps

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Git command delay | Low | Low | git rev-parse is fast (<10ms); acceptable for user-initiated action |
| Creating .claude/ in wrong location | Medium | Low | Only create when git rev-parse succeeds; validates git-managed directory |
| File permission issues | Medium | Low | Existing error handling catches write failures; show clear error message |
| Breaking existing global behavior | High | Low | Fallback to global path when not in git repo preserves existing behavior |

## Implementation Phases

### Phase 1: Add path determination helper function [COMPLETED]

**Goal**: Create a local helper function that determines the appropriate settings path (project-local or global) based on git repository detection.

**Tasks**:
- [ ] Import the existing git helper module
- [ ] Create `get_claude_settings_path()` function that:
  - Gets git root using `git.get_git_root()`
  - Validates git root is valid (non-empty and no shell error)
  - Checks if `.claude/` directory exists at git root
  - Creates `.claude/` directory if git root exists but directory does not
  - Returns path and scope indicator ("project" or "global")
- [ ] Position helper function near the top of the model picker handler (local to the function)

**Timing**: 20 minutes

**Files to modify**:
- `lua/neotex/plugins/editor/which-key.lua` - Lines 367-429 (model picker section)

**Verification**:
- Helper function compiles without errors
- Function returns correct path and scope for various scenarios

---

### Phase 2: Update config path usage [COMPLETED]

**Goal**: Replace the hardcoded global path with calls to the new helper function throughout the picker handler.

**Tasks**:
- [ ] Replace line 368 `local config_path = vim.fn.expand("~/.claude/settings.local.json")` with call to helper
- [ ] Store the scope indicator for later use in notification
- [ ] Update the initial read operation (lines 377-387) to use the new path
- [ ] Update the write operation (lines 399-416) to use the new path

**Timing**: 15 minutes

**Files to modify**:
- `lua/neotex/plugins/editor/which-key.lua` - Lines 367-429

**Verification**:
- Read operation uses determined path
- Write operation uses same path
- No hardcoded `~/.claude/settings.local.json` references remain in the handler

---

### Phase 3: Update notification with scope indicator [COMPLETED]

**Goal**: Modify the success notification to display whether the model was saved to project-local or global settings.

**Tasks**:
- [ ] Update the notification message format (lines 423-427)
- [ ] Include scope label in notification: "Model set to {label} ({scope} settings, takes effect on next Claude Code open)"
- [ ] Add scope to the notification metadata object

**Timing**: 10 minutes

**Files to modify**:
- `lua/neotex/plugins/editor/which-key.lua` - Lines 423-427

**Verification**:
- Notification shows "project settings" when in git repo
- Notification shows "global settings" when not in git repo

---

### Phase 4: Test and verify fallback scenarios [COMPLETED]

**Goal**: Validate all scenarios work correctly: git repo with .claude/, git repo without .claude/, and non-git directory.

**Tasks**:
- [ ] Test in git repo with existing .claude/ directory - should use project path
- [ ] Test in git repo without .claude/ directory - should create directory and use project path
- [ ] Test outside git repo - should use global path with "global settings" notification
- [ ] Test file permission error handling - should show error notification
- [ ] Verify model selection persists correctly in each scenario

**Timing**: 15 minutes

**Files to modify**:
- None (testing only)

**Verification**:
- All three scenarios produce expected behavior
- No regressions in existing functionality
- Error messages are clear for failure cases

## Testing & Validation

- [ ] Verify model picker opens correctly with `<leader>am`
- [ ] Select a model in a git repo with existing `.claude/` - verify project-local file is updated
- [ ] Select a model in a git repo without `.claude/` - verify directory is created and file is written
- [ ] Select a model outside a git repo - verify global file is used
- [ ] Read back the saved model on next picker open - verify it shows as current selection
- [ ] Check notification shows correct scope indicator

## Artifacts & Outputs

- `plans/01_project-local-picker.md` (this file)
- `summaries/01_project-local-picker-summary.md` (after implementation)

## Rollback/Contingency

If implementation causes issues:
1. Revert the changes to `which-key.lua` lines 367-429
2. Restore the original hardcoded `~/.claude/settings.local.json` path
3. Remove scope from notification message

The original behavior is fully preserved in git history and can be restored with a single file revert.
