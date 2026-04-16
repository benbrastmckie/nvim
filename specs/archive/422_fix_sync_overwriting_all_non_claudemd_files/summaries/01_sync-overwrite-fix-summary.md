# Implementation Summary: Task #422

- **Task**: 422 - Fix sync.lua overwriting all non-CLAUDE.md files in target repos
- **Status**: [COMPLETED]
- **Started**: 2026-04-13T00:00:00Z
- **Completed**: 2026-04-13T00:30:00Z
- **Effort**: 1 hour
- **Dependencies**: None
- **Artifacts**:
  - [Research Report](../reports/01_sync-overwrite-diagnosis.md)
  - [Implementation Plan](../plans/01_sync-overwrite-fix.md)
  - [Summary](../summaries/01_sync-overwrite-fix-summary.md) (this file)
- **Standards**: status-markers.md, artifact-management.md, tasks.md, summary-format.md

## Overview

Fixed three root causes of unwanted file overwrites during sync operations: generated JSON files (index.json) being included in context sync, README.md files not being skipped by scan_directory_for_sync, and no mechanism for target repos to protect locally-customized files. All three fixes are additive and backward-compatible.

## What Changed

- Added `index.json` and `index.json.backup` to `CONTEXT_EXCLUDE_PATTERNS` in sync.lua, and applied the patterns to ctx_json and ctx_yaml scan calls (previously only ctx_md used them)
- Added README.md skip logic in `scan_directory_for_sync` in scan.lua, aligning it with the existing `scan_directory` behavior
- Created `load_syncprotect()` function that reads `.claude/.syncprotect` (or `.opencode/.syncprotect`) from target repos
- Modified `sync_files()` to accept protected_paths and skip protected files during replace operations
- Modified `execute_sync()` to thread protected_paths through all sync calls and report protected file counts in notifications
- Modified `load_all_globally()` to load the syncprotect list before executing sync

## Decisions

- Used exact path matching for .syncprotect (no glob/wildcard support) to keep implementation simple and predictable
- Protection only applies to "replace" actions; new files ("copy") are never blocked by .syncprotect
- Protected file count only appears in the notification when > 0, avoiding clutter
- Placed load_syncprotect as a local function in sync.lua rather than in scan.lua, since it is sync-specific logic

## Impacts

- Target repos can now create `.claude/.syncprotect` to prevent specific files from being overwritten during "Sync all"
- Generated index.json files will no longer be synced, preventing extension loader conflicts
- README.md files in subdirectories (e.g., agents/README.md) will no longer be overwritten with the global repo's version

## Follow-ups

- None required; all changes are backward-compatible and opt-in

## References

- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua` - Main sync logic
- `lua/neotex/plugins/ai/claude/commands/picker/utils/scan.lua` - Directory scanning
- `specs/422_fix_sync_overwriting_all_non_claudemd_files/reports/01_sync-overwrite-diagnosis.md` - Research report
