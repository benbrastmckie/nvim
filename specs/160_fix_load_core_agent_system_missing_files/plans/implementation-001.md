# Implementation Plan: Task #160

- **Task**: 160 - Fix Load Core Agent System Missing Files
- **Status**: [NOT STARTED]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false
- **Date**: 2026-03-07
- **Feature**: Fix previewer scan in Load Core Agent System picker to show all synced files
- **Estimated Hours**: 1-2 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

The "Load Core Agent System" picker action has a dual-scan bug: the previewer uses its own non-recursive `scan_directory_for_sync` function (lines 19-40 of `previewer.lua`) that only finds top-level files, while the actual sync operation in `sync.lua` correctly uses the shared recursive `scan.scan_directory_for_sync`. The previewer also misses entire artifact categories (agents, context, root_files) and skills YAML files. The fix replaces the previewer's local scan with calls to `sync.lua`'s `scan_all_artifacts`, ensuring preview counts always match what the sync will do.

### Research Integration

Research confirmed that `scan_all_artifacts` in `sync.lua` (lines 161-264) is a local function that handles all categories correctly with recursive scanning, exclude patterns, and multi-system support. The shared `scan.scan_directory_for_sync` in `scan.lua` (lines 53-120) is the recursive utility it uses. The previewer's local function at lines 19-40 is a simplified non-recursive duplicate that must be eliminated.

## Goals & Non-Goals

**Goals**:
- Make the previewer display accurate file counts matching the actual sync operation
- Add missing categories: agents, context, root_files, skills YAML
- Eliminate the duplicated non-recursive scan function from previewer.lua
- Single source of truth for artifact scanning

**Non-Goals**:
- Changing the actual sync behavior (it works correctly)
- Adding new artifact categories beyond what sync already handles
- Refactoring the overall picker architecture

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| scan_all_artifacts is a local function in sync.lua, not exported | M | H | Export it as a module function or extract scan logic to shared scan.lua |
| Recursive scan in previewer could slow preview rendering | L | L | The scan is filesystem glob-based and fast; sync already does this without issues |
| Changing previewer display format for new categories may break expectations | L | L | Follow existing display format pattern exactly |

## Implementation Phases

### Phase 1: Export scan_all_artifacts from sync.lua [NOT STARTED]

**Goal**: Make `scan_all_artifacts` accessible to the previewer module by exporting it from `sync.lua`.

**Tasks**:
- [ ] Read current `scan_all_artifacts` function signature and dependencies (CONTEXT_EXCLUDE_PATTERNS)
- [ ] Change `local function scan_all_artifacts(...)` to `function M.scan_all_artifacts(...)` in sync.lua
- [ ] Verify all internal callers of `scan_all_artifacts` within sync.lua are updated to `M.scan_all_artifacts`
- [ ] Ensure CONTEXT_EXCLUDE_PATTERNS is accessible (it is module-level, so no change needed)

**Timing**: 0.25 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Export scan_all_artifacts as M.scan_all_artifacts

**Verification**:
- Grep sync.lua for all calls to `scan_all_artifacts` and confirm they use `M.scan_all_artifacts`
- Load the module in headless Neovim and call `M.scan_all_artifacts` to verify it returns expected structure

---

### Phase 2: Replace previewer scan with sync's scan_all_artifacts [NOT STARTED]

**Goal**: Rewrite `preview_load_all` in previewer.lua to use the exported `scan_all_artifacts` instead of the local non-recursive scan, adding all missing categories.

**Tasks**:
- [ ] Remove the local `scan_directory_for_sync` function (lines 19-40) from previewer.lua
- [ ] Remove the local `count_actions` helper if it becomes unused (check other callers first)
- [ ] Import sync module: `local sync_ops = require("neotex.plugins.ai.claude.commands.picker.operations.sync")`
- [ ] Rewrite `preview_load_all` to call `sync_ops.scan_all_artifacts(global_dir, project_dir, config)`
- [ ] Add display lines for new categories: Agents, Context, Root Files
- [ ] Update skills display to show combined md+yaml count
- [ ] Update total calculation to include all categories
- [ ] Keep the existing display format (category name, new count, replace count)

**Timing**: 0.75 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Rewrite preview_load_all, remove local scan function

**Verification**:
- Open picker in Neovim, hover over "Load Core Agent System" entry
- Verify all categories appear in preview with accurate counts
- Verify counts match what the sync operation would actually process
- Confirm no Lua errors in `:messages`

---

### Phase 3: Testing and validation [NOT STARTED]

**Goal**: Verify the fix works end-to-end and no regressions exist.

**Tasks**:
- [ ] Run `nvim --headless -c "lua local s = require('neotex.plugins.ai.claude.commands.picker.operations.sync'); print(vim.inspect(s.scan_all_artifacts))" -c "q"` to verify export
- [ ] Open the picker with `<leader>ao` and verify the "Load Core Agent System" preview shows all categories
- [ ] Compare preview counts against manual file count in global .claude/ directory
- [ ] Test that the actual sync operation (pressing Enter) still works correctly
- [ ] Test with a project that has existing .claude/ artifacts (replace counts should be non-zero)
- [ ] Test with a fresh project (all should show as "new")

**Timing**: 0.25 hours

**Files to modify**:
- None (testing only)

**Verification**:
- All preview counts match actual file counts in global directory
- Sync operation completes successfully
- No Lua errors during preview or sync

## Testing & Validation

- [ ] Previewer shows agents category with correct file count
- [ ] Previewer shows context category with correct file count (md + json + yaml)
- [ ] Previewer shows root_files category with correct file count
- [ ] Previewer shows skills with both md and yaml files counted
- [ ] Previewer shows docs with nested files counted (recursive)
- [ ] Preview total matches sum of all categories
- [ ] Actual sync operation still functions correctly after changes
- [ ] No Lua errors in Neovim messages

## Artifacts & Outputs

- Modified `sync.lua` with exported `scan_all_artifacts`
- Modified `previewer.lua` with rewritten `preview_load_all` using shared scan
- Removed duplicate `scan_directory_for_sync` from previewer.lua

## Rollback/Contingency

Both files are tracked in git. If the fix causes issues:
1. `git checkout -- lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
2. `git checkout -- lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua`
