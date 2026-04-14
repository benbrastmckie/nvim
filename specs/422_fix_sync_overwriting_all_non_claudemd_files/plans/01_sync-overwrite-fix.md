# Implementation Plan: Fix sync.lua overwriting all non-CLAUDE.md files in target repos

- **Task**: 422 - Fix sync.lua overwriting all non-CLAUDE.md files in target repos
- **Status**: [NOT STARTED]
- **Effort**: 2.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/422_fix_sync_overwriting_all_non_claudemd_files/reports/01_sync-overwrite-diagnosis.md
- **Artifacts**: plans/01_sync-overwrite-fix.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/rules/neovim-lua.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The sync mechanism in sync.lua has three root causes for unwanted overwrites in target repos: (1) generated JSON files (index.json, index.json.backup) are included in context sync despite being generated per-repo by the extension loader, (2) scan_directory_for_sync does not skip README.md files unlike its sibling scan_directory, and (3) there is no mechanism for target repos to protect locally-customized files from replacement during "Sync all" operations. This plan addresses all three issues through built-in exclusions, README.md consistency, and a new .syncprotect file feature.

### Research Integration

The research report identified three distinct root causes from analysis of sync.lua and scan.lua, cross-referenced with a zed task 62 audit that found 5 DISCARD files across 19 changed files. Key findings: extensions.json is NOT synced by sync.lua (out of scope), index.json files are generated per-repo and should never be synced, README.md files are already skipped by scan_directory but not scan_directory_for_sync, and per-repo file protection requires a new opt-in mechanism.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md consulted.

## Goals & Non-Goals

**Goals**:
- Prevent generated JSON files (index.json, index.json.backup) from being synced to target repos
- Make scan_directory_for_sync skip README.md files, consistent with scan_directory behavior
- Add .syncprotect file support so target repos can protect locally-customized files from replacement
- Provide user feedback when files are skipped due to protection

**Non-Goals**:
- Fixing extensions.json key reordering (not a sync issue; caused by extension loader)
- Adding section preservation for additional markdown files beyond CLAUDE.md/OPENCODE.md (future work)
- Interactive per-file sync selection UI
- Glob/wildcard patterns in .syncprotect (keep it simple with exact relative paths)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Excluding index.json breaks fresh project setup | L | L | Fresh projects get index.json via extension loading, not sync |
| README.md skip hides wanted README updates | L | L | Matches existing scan_directory behavior; users can manually copy |
| .syncprotect path matching edge cases (nested paths) | M | L | Use normalized relative paths from base_dir; test with subdirectory paths |
| Function signature changes break callers | M | L | sync_files and execute_sync are internal; only called within sync.lua |
| Protected file notification clutter | L | L | Only show protected count when > 0 |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 2 | -- |
| 2 | 3 | -- |
| 3 | 4 | 1, 2, 3 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Add built-in exclusions for generated JSON files [NOT STARTED]

**Goal**: Prevent index.json and index.json.backup from being included in context sync operations.

**Tasks**:
- [ ] Add `"index.json"` and `"index.json.backup"` to the `CONTEXT_EXCLUDE_PATTERNS` table in sync.lua (line 23-26)
- [ ] Update the comment on the constant to mention generated files alongside repository-specific files
- [ ] Verify the ctx_json scan on line 440 passes no extra_exclude, so the CONTEXT_EXCLUDE_PATTERNS must be threaded through -- check that the ctx_md scan already uses CONTEXT_EXCLUDE_PATTERNS and ctx_json does not, then add it to the ctx_json call

**Timing**: 20 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Add entries to CONTEXT_EXCLUDE_PATTERNS, add CONTEXT_EXCLUDE_PATTERNS to ctx_json scan call (line 440)

**Verification**:
- CONTEXT_EXCLUDE_PATTERNS contains 4 entries (2 existing + 2 new)
- ctx_json scan call includes CONTEXT_EXCLUDE_PATTERNS as extra_exclude parameter
- ctx_yaml scan should also get CONTEXT_EXCLUDE_PATTERNS for consistency

---

### Phase 2: Make scan_directory_for_sync skip README.md [NOT STARTED]

**Goal**: Align scan_directory_for_sync with scan_directory by skipping README.md files during sync scanning.

**Tasks**:
- [ ] Add README.md filename check inside the file processing loop in scan_directory_for_sync (scan.lua, after line 100, before exclude check)
- [ ] Extract filename using `vim.fn.fnamemodify(global_file, ":t")` and skip if `== "README.md"`
- [ ] Use `goto continue` pattern consistent with existing skip logic in the function

**Timing**: 15 minutes

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Add README.md skip in scan_directory_for_sync loop body

**Verification**:
- scan_directory_for_sync returns no results with name "README.md"
- Existing scan_directory README.md skip behavior is preserved

---

### Phase 3: Add .syncprotect file support [NOT STARTED]

**Goal**: Allow target repos to protect specific files from being overwritten during "Sync all" operations via a .syncprotect file.

**Tasks**:
- [ ] Create `load_syncprotect(project_dir, base_dir)` function in sync.lua that reads `{project_dir}/{base_dir}/.syncprotect` and returns a set of protected relative paths
  - Parse lines, trim whitespace, skip empty lines and comment lines starting with `#`
  - Use `io.open` with graceful nil return if file does not exist
- [ ] Modify `sync_files` signature to accept an optional `protected_paths` parameter (table, default `{}`)
- [ ] Add protection check in `sync_files`: when `file.action == "replace"`, compute the file's relative path from the base directory and check against protected_paths set; skip if protected
- [ ] Track protected skip count separately for notification
- [ ] Modify `execute_sync` to:
  - Accept a `protected_paths` parameter
  - Pass it through to each `sync_files` call
  - Include protected count in notification if > 0
- [ ] Modify `load_all_globally` to:
  - Call `load_syncprotect` before `execute_sync`
  - Pass the result to `execute_sync`
- [ ] Compute relative paths for protection matching: for each artifact type, the relative path is from the `base_dir` root (e.g., `rules/git-workflow.md`, `agents/README.md`, `CLAUDE.md`)
  - For root_files: rel_path is just the filename
  - For subdirectory files: rel_path is `{subdir}/{rel_path_within_subdir}`

**Timing**: 1.5 hours

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - New load_syncprotect function, modified sync_files, execute_sync, and load_all_globally signatures and logic

**Verification**:
- Without .syncprotect file: behavior is identical to current (no files skipped)
- With .syncprotect containing `rules/git-workflow.md`: that file is not overwritten during "Sync all"
- Protected file count appears in sync notification when > 0
- Comment lines and empty lines in .syncprotect are ignored
- Root files like `CLAUDE.md` can be protected

---

### Phase 4: Testing and verification [NOT STARTED]

**Goal**: Verify all three fixes work correctly through manual testing and code review.

**Tasks**:
- [ ] Load the sync.lua module in nvim headless mode to verify no syntax errors: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "q"`
- [ ] Load the scan.lua module similarly to verify no syntax errors
- [ ] Review the complete diff of changes for:
  - Correct Lua style (2-space indent, snake_case, LuaDoc comments)
  - No accidental removal of existing functionality
  - Consistent use of `goto continue` pattern
  - Proper nil handling in load_syncprotect
- [ ] Verify CONTEXT_EXCLUDE_PATTERNS entries use correct exact-match format compatible with the exclude_patterns matching logic in scan_directory_for_sync
- [ ] Verify the relative path computation in sync_files protection check matches the format used in .syncprotect entries

**Timing**: 30 minutes

**Depends on**: 1, 2, 3

**Files to modify**:
- None (verification only)

**Verification**:
- Both modules load without errors
- Code review passes with no style violations
- All three root causes from the research report are addressed

## Testing & Validation

- [ ] Module loads: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.operations.sync')" -c "q"` exits cleanly
- [ ] Module loads: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.utils.scan')" -c "q"` exits cleanly
- [ ] CONTEXT_EXCLUDE_PATTERNS contains index.json and index.json.backup entries
- [ ] scan_directory_for_sync skips README.md files (code inspection)
- [ ] load_syncprotect returns empty table when file does not exist
- [ ] load_syncprotect correctly parses comment lines and empty lines
- [ ] sync_files skips protected files during replace operations
- [ ] Notification includes protected count when applicable

## Artifacts & Outputs

- Modified `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - CONTEXT_EXCLUDE_PATTERNS additions, load_syncprotect function, modified sync_files/execute_sync/load_all_globally
- Modified `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - README.md skip in scan_directory_for_sync

## Rollback/Contingency

All changes are additive or modify internal functions only. Rollback is straightforward via git revert of the implementation commit(s). The .syncprotect feature is fully opt-in (no .syncprotect file = no behavior change). The CONTEXT_EXCLUDE_PATTERNS additions and README.md skip are safe removals if issues arise, as they only prevent files from being synced -- they never delete or modify existing files.
