# Implementation Plan: Fix Loader Root-Level Context Files

- **Task**: 470 - Fix loader to handle root-level context files
- **Status**: [COMPLETED]
- **Effort**: 1 hour
- **Dependencies**: None
- **Research Inputs**: [specs/470_fix_loader_root_level_context_files/reports/01_loader-context-fix.md]
- **Artifacts**: plans/01_loader-context-fix.md (this file)
- **Standards**: plan-format.md; status-markers.md; artifact-management.md; tasks.md
- **Type**: neovim

## Overview

The `copy_context_dirs()` function in `loader.lua` only handles directory entries via `vim.fn.isdirectory()`, silently skipping root-level files listed in a manifest's `provides.context` array. The core extension has 5 root-level files (`README.md`, `routing.md`, `validation.md`, `core-index-entries.json`, `index.schema.json`) that are never deployed by the loader. The fix mirrors the existing `copy_docs()` pattern, which already handles both files and directories correctly.

### Research Integration

Integrated report: `reports/01_loader-context-fix.md` -- confirmed root cause (missing `filereadable` fallback), identified reference pattern (`copy_docs()`), verified unload path requires no changes, and catalogued all 5 affected files.

## Goals & Non-Goals

- **Goals**:
  - Add `filereadable` fallback to `copy_context_dirs()` so individual files in `provides.context` are copied
  - Update core manifest `provides.context` to include the 5 root-level file names
  - Remove manually committed workaround files from `.claude/context/` (added by task 469)
  - Verify loader correctly deploys and removes root-level context files

- **Non-Goals**:
  - Renaming `source_ctx_dir`/`target_ctx_dir` variables (cosmetic, out of scope)
  - Adding file support to `check_conflicts()` for context entries
  - Auto-scanning context directories (bypasses manifest's explicit enumeration)

## Risks & Mitigations

- **Risk**: Removing workaround files before verifying the fix could leave `.claude/context/` missing files. **Mitigation**: Phase 3 (verification) runs between the code fix and the workaround removal, confirming deployment works before cleanup.
- **Risk**: Variable names `source_ctx_dir`/`target_ctx_dir` misleading for file entries. **Mitigation**: Add inline comment clarifying dual file/directory usage; renaming is out of scope.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1    | 1, 2   | --         |
| 2    | 3      | 1, 2       |
| 3    | 4      | 3          |

Phases within the same wave can execute in parallel.

### Phase 1: Add filereadable fallback to copy_context_dirs [COMPLETED]

- **Goal:** Enable `copy_context_dirs()` to handle individual file entries in `provides.context`, matching the `copy_docs()` pattern.
- **Tasks:**
  - [ ] Add `elseif vim.fn.filereadable(source_ctx_dir) == 1 then` branch after the existing `isdirectory` check at line 219 in `loader.lua`
  - [ ] Inside the new branch, call `copy_file(source_ctx_dir, target_ctx_dir, false)` and insert into `copied_files`
  - [ ] Add inline comment: `-- Handle individual files at context root (mirrors copy_docs pattern)`
- **Timing:** 10 minutes
- **Depends on:** none

### Phase 2: Update core manifest provides.context [COMPLETED]

- **Goal:** List root-level files in the core manifest so the loader knows to deploy them.
- **Tasks:**
  - [ ] Edit `.claude/extensions/core/manifest.json` to add `"README.md"`, `"routing.md"`, `"validation.md"`, `"core-index-entries.json"`, `"index.schema.json"` to the `provides.context` array
  - [ ] Place file entries before the directory entries for clarity
- **Timing:** 5 minutes
- **Depends on:** none

### Phase 3: Verify deployment [COMPLETED]

- **Goal:** Confirm the loader correctly deploys root-level context files after the fix.
- **Tasks:**
  - [ ] Remove the manually committed workaround copies from `.claude/context/` (README.md, routing.md, validation.md) to test fresh deployment
  - [ ] Trigger extension reload (headless or manual)
  - [ ] Verify all 5 files exist in `.claude/context/` after reload
  - [ ] Verify module loads without error: `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.loader')" -c "q"`
- **Timing:** 15 minutes
- **Depends on:** 1, 2

### Phase 4: Verify unload and reload cycle [COMPLETED]

- **Goal:** Confirm unload removes root-level files and reload re-creates them.
- **Tasks:**
  - [ ] Trigger extension unload and verify the 5 root-level files are removed from `.claude/context/`
  - [ ] Trigger extension reload and verify the files reappear
  - [ ] Confirm no orphaned directories or files remain after unload
- **Timing:** 10 minutes
- **Depends on:** 3

## Testing & Validation

- [ ] `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.loader')" -c "q"` exits cleanly
- [ ] After reload: `ls .claude/context/README.md .claude/context/routing.md .claude/context/validation.md .claude/context/core-index-entries.json .claude/context/index.schema.json` all exist
- [ ] After unload: those 5 files are removed
- [ ] After re-reload: files are restored
- [ ] Non-core extensions still load correctly (no regressions)

## Artifacts & Outputs

- `specs/470_fix_loader_root_level_context_files/plans/01_loader-context-fix.md` (this plan)
- `specs/470_fix_loader_root_level_context_files/summaries/01_loader-context-fix-summary.md` (post-implementation)
- Modified files:
  - `lua/neotex/plugins/ai/shared/extensions/loader.lua` (4 lines added)
  - `.claude/extensions/core/manifest.json` (5 entries added)
  - `.claude/context/README.md`, `routing.md`, `validation.md` (removed -- workaround files)

## Rollback/Contingency

- Revert the `loader.lua` change (single `elseif` block) and restore the 3 workaround files via `git checkout`
- The manifest change is additive and harmless without the loader fix (entries are silently skipped)
