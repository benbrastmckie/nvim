# Implementation Summary: Prevent Extension Loader Overwriting Repo Customizations

- **Task**: 420 - Prevent extension loader sync from overwriting repo-specific CLAUDE.md customizations
- **Status**: [COMPLETED]
- **Started**: 2026-04-13T00:00:00Z
- **Completed**: 2026-04-13T00:30:00Z
- **Effort**: 30 minutes
- **Dependencies**: None
- **Artifacts**: plans/01_prevent-loader-overwrite.md, summaries/01_prevent-loader-overwrite-summary.md
- **Standards**: status-markers.md, artifact-management.md, tasks.md

## Overview

The core sync operation (`sync.load_all_globally()`) performed a full-file overwrite of config markdown files (CLAUDE.md, OPENCODE.md) when syncing from the global source, destroying extension-injected `<!-- SECTION -->` blocks and any extension merge target content (settings.json, index.json). A two-layer defense was implemented: (1) section-aware sync that preserves `<!-- SECTION -->` blocks during overwrite, and (2) post-sync re-injection that re-runs all merge targets for loaded extensions.

## What Changed

- Added `preserve_sections()` function that extracts all `<!-- SECTION: {id} -->...<!-- END_SECTION: {id} -->` blocks from local config markdown files before overwrite
- Added `restore_sections()` function that appends preserved section blocks to the new global content, with idempotency checks to avoid duplication
- Modified `sync_files()` to detect config markdown files (CLAUDE.md, OPENCODE.md) and automatically preserve/restore sections during replace operations
- Added `reinject_loaded_extensions()` function that re-runs merge targets (inject_section, merge_settings, append_index_entries, merge_opencode_agents) for all loaded extensions after a full sync
- Called `reinject_loaded_extensions()` at the end of `load_all_globally()` after `execute_sync()` returns, only in full sync mode (not merge-only)
- Added `state_mod` and `merge_mod` as new dependencies to sync.lua
- Added local `read_file_string()` and `read_json()` helpers for re-injection (avoids coupling to init.lua's local functions)

## Decisions

- Used two-layer defense (section preservation + re-injection) rather than either alone, providing redundancy
- Placed re-injection logic in sync.lua rather than extracting `process_merge_targets` from init.lua to avoid circular imports
- Re-injection only triggers on full sync (not merge-only) since merge-only skips replace operations
- Section preservation only applies to CONFIG_MARKDOWN_FILES (CLAUDE.md, OPENCODE.md), not all files

## Impacts

- Full sync (`Sync all`) now preserves extension-injected content in CLAUDE.md and OPENCODE.md
- Full sync also re-injects settings.json and index.json extension content
- Merge-only sync (`New only`) behavior is unchanged (it already skips replace operations)
- No impact on extension load/unload operations (they continue to use init.lua's process_merge_targets)
- Two new module-level requires added to sync.lua (state_mod, merge_mod) -- minimal performance impact

## Follow-ups

- None required. The implementation is complete and self-contained.

## References

- `specs/420_prevent_extension_loader_overwriting_repo_customizations/reports/01_extension-loader-sync.md`
- `specs/420_prevent_extension_loader_overwriting_repo_customizations/plans/01_prevent-loader-overwrite.md`
- `lua/neotex/plugins/ai/claude/commands/picker/operations/sync.lua`
- `lua/neotex/plugins/ai/shared/extensions/merge.lua`
- `lua/neotex/plugins/ai/shared/extensions/init.lua`
