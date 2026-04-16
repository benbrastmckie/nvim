# Implementation Plan: Harden Sync Against Repo-Specific Leakage

- **Task**: 432 - Harden sync engine against repo-specific content leakage
- **Status**: [COMPLETED]
- **Effort**: 3 hours
- **Dependencies**: None (task 433 depends on this)
- **Research Inputs**: reports/01_sync-leakage-hardening.md
- **Artifacts**: plans/01_sync-leakage-hardening.md (this file)
- **Standards**:
  - .claude/rules/artifact-formats.md
  - .claude/rules/state-management.md
  - .claude/context/formats/plan-format.md
- **Type**: neovim

## Overview

The sync engine in `sync.lua` copies core agent system files to target repositories, but 35+ context files contain neovim/neotex-specific references that leak into non-Neovim repos. Current protection (`CONTEXT_EXCLUDE_PATTERNS` with 4 entries, `.syncprotect`, extension blocklist) leaves gaps. This plan implements three independent hardening mechanisms: (1) a `.sync-exclude` file for source-side exclusion with embedded audit pattern directives, (2) a post-sync content audit that warns about repo-specific references in synced files, and (3) auto-seeding of `.syncprotect` in target repos on first sync. Definition of done: all three mechanisms work, existing sync behavior is preserved for repos without `.sync-exclude`, and tests validate the new functionality.

### Research Integration

- Integrated: reports/01_sync-leakage-hardening.md (round 1)

## Goals & Non-Goals

- **Goals**:
  - Create `.sync-exclude` file format supporting path exclusions and `# audit-pattern:` directives
  - Implement `load_sync_exclude()` parser in `sync.lua`
  - Thread source-side exclude paths into `scan_all_artifacts()` alongside existing blocklist
  - Implement `audit_synced_content()` post-sync function with configurable Lua patterns
  - Auto-seed `.syncprotect` with standard entries when target repo has none
  - Populate initial `.sync-exclude` with known neovim-specific exclusion paths
  - Non-blocking warnings only (audit never prevents sync)
- **Non-Goals**:
  - Moving neovim-specific content out of core files (that is task 433)
  - Modifying the extension blocklist mechanism
  - Changing `.syncprotect` target-side behavior
  - Making audit patterns block or roll back syncs

## Risks & Mitigations

- **Risk**: Audit false positives from generic mentions of "neovim" in documentation. **Mitigation**: Audit is non-blocking informational; patterns are configurable per source repo via `.sync-exclude`.
- **Risk**: Auto-seeded `.syncprotect` overwrites user-created file. **Mitigation**: Only seed if file does not exist (explicit `filereadable` check).
- **Risk**: Performance impact of reading all synced files for content audit. **Mitigation**: Only read files actually synced (using `all_artifacts` map), and Lua pattern matching is fast for markdown files.
- **Risk**: `.sync-exclude` adds complexity to sync workflow. **Mitigation**: File is optional; absent file means zero excludes and zero audit patterns (identical to current behavior).

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 3 | 1 |
| 3 | 4 | 2, 3 |

Phases within the same wave can execute in parallel.

### Phase 1: Implement `.sync-exclude` file parser and source-side exclusion [COMPLETED]

- **Goal:** Create the `.sync-exclude` file format, implement `load_sync_exclude()`, and thread exclude paths into `scan_all_artifacts()`.
- **Tasks:**
  - [ ] Create `.sync-exclude` file at project root with initial content:
    - Comment header explaining the format (path exclusions and `# audit-pattern:` directives)
    - Known neovim-specific context paths to exclude (from research: `context/orchestration/routing.md` and other high-leakage files that are primarily neovim examples)
    - Audit pattern directives: `# audit-pattern: neovim`, `# audit-pattern: neotex`, `# audit-pattern: lazy%.nvim`, `# audit-pattern: nvim%-lspconfig`
  - [ ] Implement `load_sync_exclude(global_dir)` function in `sync.lua`:
    - Read `{global_dir}/.sync-exclude` (source repo root)
    - Parse non-comment, non-empty lines as relative paths (same as `.syncprotect` format)
    - Parse `# audit-pattern: <pattern>` lines as Lua patterns
    - Return two values: `exclude_set` (`{[path] = true}`) and `audit_patterns` (array of strings)
    - If file does not exist, return empty table and empty array
  - [ ] Modify `scan_all_artifacts()` to accept and apply source-side excludes:
    - Call `load_sync_exclude(global_dir)` at the top of `scan_all_artifacts()`
    - Pass `exclude_set` entries into the `extra_exclude` parameter of each `sync_scan()` call (merge with existing `CONTEXT_EXCLUDE_PATTERNS` for context, and apply as new excludes for other artifact types)
    - Store `audit_patterns` on the returned artifacts table (e.g., `artifacts._audit_patterns = audit_patterns`) for use in Phase 3
- **Timing:** 1.5 hours
- **Depends on:** none

### Phase 2: Auto-seed `.syncprotect` in target repos [COMPLETED]

- **Goal:** When `load_all_globally()` detects no `.syncprotect` in the target repo, create one with standard defensive entries before sync proceeds.
- **Tasks:**
  - [ ] Add auto-seed logic in `load_all_globally()` after the `load_syncprotect()` call (line 665):
    - Check if `.syncprotect` file exists at `project_dir .. "/.syncprotect"` using `vim.fn.filereadable()`
    - If file does not exist, write a default `.syncprotect` with:
      - Comment header: `# Protected files - not overwritten during sync`
      - `context/repo/project-overview.md` (defense-in-depth, already in CONTEXT_EXCLUDE_PATTERNS)
      - Comment explaining users can add paths to protect local customizations
    - Notify user: "Created .syncprotect with default entries"
    - Re-read protected_paths after seeding (call `load_syncprotect()` again or merge manually)
  - [ ] Ensure auto-seed does NOT trigger if `.syncprotect` exists but is empty/comments-only (existence check, not content check)
- **Timing:** 30 minutes
- **Depends on:** 1

### Phase 3: Post-sync content audit [COMPLETED]

- **Goal:** After `execute_sync()` completes, scan synced files for configurable warning patterns and display a non-blocking summary.
- **Tasks:**
  - [ ] Implement `audit_synced_content(project_dir, all_artifacts, audit_patterns, base_dir)` function in `sync.lua`:
    - If `audit_patterns` is nil or empty, return immediately (no-op)
    - Iterate through all artifact categories in `all_artifacts` (skip keys starting with `_`)
    - For each synced file, read its content from the target path (`local_path`)
    - Check content against each audit pattern using `string.find(content:lower(), pattern:lower())`
    - Collect matches as `{file_path, pattern, match_count}` entries
    - Return array of match results
  - [ ] Add `audit_synced_content()` call in `load_all_globally()`:
    - After `execute_sync()` returns on line 667 and before the `reinject_loaded_extensions()` block
    - Extract audit patterns from `all_artifacts._audit_patterns` (set in Phase 1)
    - Call `audit_synced_content()` with the patterns
    - Format and display results as a non-blocking notification:
      - Summary line: "Content audit: N files contain repo-specific references"
      - Top 5 files by match count with pattern details
      - Suggestion: "Review these files or add paths to .sync-exclude"
  - [ ] Handle edge cases:
    - Files that were skipped by `.syncprotect` should not be audited
    - Files that failed to sync should not be audited
    - Binary files or very large files should be skipped (size > 100KB)
- **Timing:** 1 hour
- **Depends on:** 1

### Phase 4: Testing and validation [COMPLETED]

- **Goal:** Verify all three mechanisms work correctly and do not break existing sync behavior.
- **Tasks:**
  - [ ] Manual testing: Run sync from global directory to a test project directory
    - Verify `.sync-exclude` paths are excluded from scan results
    - Verify audit patterns produce warnings for known neovim-reference files
    - Verify `.syncprotect` is auto-seeded when absent
    - Verify existing sync behavior is unchanged when `.sync-exclude` is absent
  - [ ] Verify `load_sync_exclude()` handles edge cases:
    - Missing file returns empty results
    - Empty file returns empty results
    - Comments-only file returns empty results
    - Mixed paths and audit-pattern directives parse correctly
  - [ ] Verify `audit_synced_content()` handles edge cases:
    - Empty audit patterns array produces no output
    - No matches produces no notification
    - Large file count does not cause performance issues
  - [ ] Verify auto-seed does not overwrite existing `.syncprotect` files
- **Timing:** 30 minutes
- **Depends on:** 2, 3

## Testing & Validation

- [ ] Sync to a fresh test directory (no `.syncprotect`) -- verify auto-seed creates file
- [ ] Sync to a directory with existing `.syncprotect` -- verify no overwrite
- [ ] Add paths to `.sync-exclude` -- verify those paths are excluded from scan results
- [ ] Add audit patterns to `.sync-exclude` -- verify post-sync warnings appear
- [ ] Remove `.sync-exclude` entirely -- verify sync works identically to current behavior
- [ ] Verify `CONTEXT_EXCLUDE_PATTERNS` still applies (no regression)
- [ ] Verify extension blocklist still applies (no regression)

## Artifacts & Outputs

- `.sync-exclude` (new file at project root)
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` (modified: new functions, updated `scan_all_artifacts` and `load_all_globally`)
- plans/01_sync-leakage-hardening.md (this file)
- summaries/01_sync-leakage-hardening-summary.md (after implementation)

## Rollback/Contingency

- All changes are in `sync.lua` and the new `.sync-exclude` file. Reverting the `sync.lua` changes restores original behavior.
- `.sync-exclude` is optional -- deleting it restores current behavior with zero code changes needed.
- Auto-seeded `.syncprotect` files in target repos are harmless and can be deleted or edited by users.
- If audit causes performance issues, remove the `audit_synced_content()` call from `load_all_globally()` (single line removal).
