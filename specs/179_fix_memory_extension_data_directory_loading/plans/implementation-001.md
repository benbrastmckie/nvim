# Implementation Plan: Task #179

**Task**: 179 - Fix memory extension data directory loading
**Version**: 001
**Created**: 2026-03-10
**Language**: neovim
**Status**: [NOT STARTED]
**Effort**: 0.5-1 hours
**Type**: neovim
**Standards File**: /home/benjamin/.config/nvim/CLAUDE.md
**Research Reports**: [research-002.md](../reports/research-002.md)

## Overview

The memory extension loader places data in the wrong directory (`.opencode/memory/` instead of project root) and uses the wrong name (`memory/` instead of `.memory/`). Two targeted fixes are needed: a one-line parameter change in `init.lua` and a manifest/directory rename in the memory extension.

### Research Integration

Research report v2 identified both bugs with exact line numbers and confirmed that existing safeguards (merge-copy semantics, conflict detection, unload behavior) already use `project_dir` correctly and require no changes.

## Goals & Non-Goals

**Goals**:
- Fix data directory base path to use project root instead of `.opencode/`
- Fix data directory name to use `.memory` (dot-prefixed) matching all documentation
- Preserve existing merge-copy and unload behavior

**Non-Goals**:
- Refactoring the extension loader architecture
- Adding new extension loader features
- Migrating existing incorrectly-placed data directories

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Existing `.opencode/memory/` data orphaned | L | M | Document in summary; user can manually move |
| Hidden directory `.memory` confuses users | L | L | Already documented in EXTENSION.md |

## Implementation Phases

### Phase 1: Fix base directory parameter [NOT STARTED]

**Goal**: Change the `copy_data_dirs` call to use `project_dir` instead of `target_dir`

**Tasks**:
- [ ] Edit `init.lua` line 297: change `target_dir` to `project_dir`
- [ ] Verify the fix with headless Neovim module load test

**Timing**: 15 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/shared/extensions/init.lua` - Line 297: `target_dir` to `project_dir`

**Verification**:
- Module loads without error: `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"`
- Grep confirms no remaining `target_dir` usage in `copy_data_dirs` calls

---

### Phase 2: Fix manifest and source directory naming [NOT STARTED]

**Goal**: Update manifest `data` field and rename source directory to use dot-prefix

**Tasks**:
- [ ] Update `.opencode/extensions/memory/manifest.json` line 11: `"memory"` to `".memory"`
- [ ] Rename source directory `data/memory/` to `data/.memory/`
- [ ] Verify manifest JSON is valid
- [ ] Verify directory rename succeeded and contents intact

**Timing**: 15 minutes

**Files to modify**:
- `.opencode/extensions/memory/manifest.json` - data array entry: `"memory"` to `".memory"`
- `.opencode/extensions/memory/data/memory/` - Rename to `.opencode/extensions/memory/data/.memory/`

**Verification**:
- `jq . .opencode/extensions/memory/manifest.json` parses without error
- `ls -la .opencode/extensions/memory/data/.memory/` shows expected vault structure
- `ls .opencode/extensions/memory/data/memory` returns error (directory no longer exists)

---

## Testing & Validation

- [ ] Module loads cleanly: `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions')" -c "q"`
- [ ] Manifest JSON validates: `jq . .opencode/extensions/memory/manifest.json`
- [ ] Source data directory exists at new path: `ls .opencode/extensions/memory/data/.memory/`
- [ ] Old source data directory removed: `! ls .opencode/extensions/memory/data/memory/`

## Artifacts & Outputs

- Modified `lua/neotex/plugins/ai/shared/extensions/init.lua` (1 line change)
- Modified `.opencode/extensions/memory/manifest.json` (1 field change)
- Renamed `.opencode/extensions/memory/data/memory/` to `data/.memory/`

## Rollback/Contingency

1. Revert init.lua line 297 to `target_dir`
2. Revert manifest data field to `"memory"`
3. Rename `data/.memory/` back to `data/memory/`

All changes are isolated and independently revertible via `git checkout`.
