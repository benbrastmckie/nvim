# Implementation Plan: Task #161

- **Task**: 161 - fix_opencode_source_missing_files_and_scan_bugs
- **Status**: [IMPLEMENTING]
- **Effort**: 1-2 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: /home/benjamin/.config/nvim/CLAUDE.md
- **Type**: neovim
- **Lean Intent**: false
- **Date**: 2026-03-07
- **Feature**: Fix opencode sync: missing files, templates scan bug, orphaned .sh cleanup
- **Estimated Hours**: 1-2 hours
- **Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
- **Research Reports**: [research-001.md](../reports/research-001.md)

## Overview

Three targeted fixes for the `<leader>ao` Load Core Agent System picker. The sync mechanism in `sync.lua` has a templates scan bug (only scans `*.yaml`, missing `*.json` files), and the `update_artifact_from_global` function hardcodes `.yaml` for templates. Additionally, 4 orphaned `.sh` files in `.opencode/context/core/patterns/` need deletion. The 9 missing core files will be synced automatically once the scan bug is fixed; no manual copy is needed.

### Research Integration

Research confirmed: (1) all 9 files exist in `.claude/` and are absent from `.opencode/` -- a data sync gap, not a code bug; (2) templates scan on line 199 uses `*.yaml` but the only template is `settings.json`; (3) the 4 `.sh` files in `.opencode/context/core/patterns/` are orphaned documentation artifacts with no `.claude/` counterpart and no codebase references.

## Goals & Non-Goals

**Goals**:
- Fix templates scan in `sync.lua` to include `*.json` files alongside `*.yaml`
- Fix `update_artifact_from_global` subdir_map to handle templates with `.json` extension
- Delete 4 orphaned `.sh` files from `.opencode/context/core/patterns/`
- Verify the 9 missing files sync correctly after the fix

**Non-Goals**:
- Manually copying the 9 missing files (sync mechanism handles this)
- Adding `.sh` scanning to the context scanner (the files are orphans to delete, not sync)
- Addressing the additional ~16 missing files identified in research (sync handles them)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Templates multi-extension pattern breaks existing YAML templates | M | L | Additive change; existing YAML scan unchanged, just adding JSON |
| update_artifact_from_global ext change breaks other artifact types | M | L | Only changing template entry; all other types keep their extensions |
| Orphaned .sh files referenced somewhere missed by grep | L | L | Research confirmed no references; files are documentation content with wrong extension |

## Implementation Phases

### Phase 1: Fix templates scan and subdir_map [COMPLETED]

**Goal**: Make the templates scanner discover both `*.yaml` and `*.json` files, and fix the `update_artifact_from_global` function to reconstruct template filenames correctly.

**Tasks**:
- [ ] Edit `sync.lua` line 199: replace single-line `sync_scan("templates", "*.yaml")` with multi-extension pattern matching skills (lines 186-194) and context (lines 206-214)
- [ ] Edit `sync.lua` subdir_map (line 390): change template entry to use dynamic extension detection instead of hardcoded `.yaml`

**Timing**: 0.5 hours

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Lines 199 (templates scan) and 390 (subdir_map template ext)

**Verification**:
- Load neovim and run `:lua print(vim.inspect(require("neotex.plugins.ai.claude.commands.picker.operations.sync")))` to confirm module loads without errors
- Verify `settings.json` appears in scanned templates by running the picker scan logic

---

### Phase 2: Delete orphaned .sh files [COMPLETED]

**Goal**: Remove the 4 orphaned `.sh` files from `.opencode/context/core/patterns/` that have no source counterpart in `.claude/`.

**Tasks**:
- [ ] Delete `.opencode/context/core/patterns/command-execution.sh`
- [ ] Delete `.opencode/context/core/patterns/command-integration.sh`
- [ ] Delete `.opencode/context/core/patterns/core-command-execution.sh`
- [ ] Delete `.opencode/context/core/patterns/lean-command-execution.sh`

**Timing**: 0.1 hours

**Files to modify**:
- `.opencode/context/core/patterns/command-execution.sh` - Delete
- `.opencode/context/core/patterns/command-integration.sh` - Delete
- `.opencode/context/core/patterns/core-command-execution.sh` - Delete
- `.opencode/context/core/patterns/lean-command-execution.sh` - Delete

**Verification**:
- Confirm no `.sh` files remain in `.opencode/context/core/patterns/` via glob
- Confirm no broken references by grepping for these filenames across the codebase

---

### Phase 3: Validate sync and test [COMPLETED]

**Goal**: Verify the complete fix works end-to-end by loading the module and confirming the scan finds `settings.json`.

**Tasks**:
- [ ] Run `nvim --headless` test to confirm `sync.lua` loads without errors
- [ ] Verify templates scan returns `settings.json` by running scan logic headlessly
- [ ] Verify the 4 orphaned files are gone
- [ ] Run the `<leader>ao` picker "Load Core Agent System" action to confirm it works (or headless equivalent)

**Timing**: 0.25 hours

**Files to modify**:
- None (verification only)

**Verification**:
- `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "q"` exits cleanly
- No `.sh` files in `.opencode/context/core/patterns/`
- Templates scan discovers `settings.json`

## Testing & Validation

- [ ] sync.lua module loads without error in headless nvim
- [ ] Templates scan finds `*.json` files (specifically `settings.json`)
- [ ] Templates scan still finds `*.yaml` files (backward compatibility)
- [ ] `update_artifact_from_global` correctly resolves template paths for `.json` files
- [ ] No orphaned `.sh` files remain in `.opencode/context/core/patterns/`
- [ ] No broken references to deleted files across codebase

## Artifacts & Outputs

- Modified `sync.lua` with multi-extension templates scan and fixed subdir_map
- 4 deleted orphaned `.sh` files from `.opencode/context/core/patterns/`

## Rollback/Contingency

Revert the single modified file (`sync.lua`) via `git checkout` if the templates fix causes issues. The deleted `.sh` files are orphaned artifacts with no references, so their deletion is safe and does not require rollback capability.
