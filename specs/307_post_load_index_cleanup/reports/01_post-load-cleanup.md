# Research Report: Post-Load Index Cleanup

**Task**: 307 - Add post-load index cleanup to extension loader
**Date**: 2026-03-26
**Status**: Researched

## Problem Statement

The extension loader's orphan cleanup (added by task 301) uses `remove_index_entries_by_prefix()` during `manager.unload()`, but this approach has two fundamental gaps:

### Root Cause 1: Unload is never called during sparse reloads

The extension picker (`shared/extensions/picker.lua`) toggles individual extensions one at a time via `manager.load()` and `manager.unload()`. When a user opens a new project and loads only a subset of extensions (e.g., web, filetypes, memory), extensions that were previously loaded (e.g., lean4) are **not** explicitly unloaded -- `manager.unload()` is never called for them. Their index entries persist as orphans.

The picker has no batch "load only these" operation. Each `load()` call is independent (line 160 in `picker.lua`), and `unload()` is only called when a user explicitly selects an active extension to toggle it off (line 157).

### Root Cause 2: Path mismatch for pitch-deck entries

The `present` extension's manifest declares `provides.context: ["project/present"]`, but some of its entries were historically rewritten to `project/filetypes/` paths. The prefix-based cleanup in `remove_index_entries_by_prefix()` uses the manifest's `provides.context` prefixes, so it cannot match entries whose paths were rewritten to a different prefix.

## Source Code Analysis

### Extension loader: `init.lua`

- **File**: `lua/neotex/plugins/ai/shared/extensions/init.lua`
- **Load flow** (lines 306-364): `manager.load()` copies files, loads core index entries, processes merge targets (including `append_index_entries`), then updates state.
- **Unload flow** (lines 399-493): `manager.unload()` reverses merge targets (including `remove_index_entries_tracked`), then calls `remove_index_entries_by_prefix()` (lines 448-462).
- **No post-load hook**: After `manager.load()` completes, there is no mechanism to clean entries from non-loaded extensions.

### Merge module: `merge.lua`

- **File**: `lua/neotex/plugins/ai/shared/extensions/merge.lua`
- **`append_index_entries()`** (lines 362-405): Appends entries with deduplication by path. Normalizes paths via `normalize_index_path()`.
- **`remove_index_entries_by_prefix()`** (lines 457-510): Removes entries matching given path prefixes. Used in unload flow.
- **Insertion point for new function**: After line 510 (after `remove_index_entries_by_prefix()`), a new `remove_orphaned_index_entries()` function should be added.

### extensions.json structure

- **File**: `{project_dir}/.claude/extensions.json` (per-project state file)
- Contains `extensions` object keyed by extension name
- Each extension has `status`, `installed_files`, `installed_dirs`, `merged_sections`, etc.
- Only currently-loaded extensions appear as entries

### Extension manifests

- **Location**: `.claude/extensions/{name}/manifest.json`
- **`provides.context` field**: Array of path prefixes owned by the extension
  - lean: `["project/lean4"]`
  - present: `["project/present"]`
  - web: `["project/web"]`
  - memory: `["project/memory"]`
  - filetypes: `["project/filetypes"]`
- These prefixes define the "owned" namespace for each extension's index entries

## Proposed Implementation

### New function: `remove_orphaned_index_entries()` in `merge.lua`

```lua
--- Remove orphaned index entries from non-loaded extensions
--- Called after all extensions are loaded to clean entries from previous loads.
--- Keeps: core entries (domain="core"), entries with valid prefixes from loaded
--- extensions, and entries not under "project/" (safety catch).
--- @param index_path string Path to index.json
--- @param valid_prefixes table Array of path prefixes from loaded extensions' provides.context
--- @return boolean success True if cleanup succeeded
--- @return number removed_count Number of entries removed
function M.remove_orphaned_index_entries(index_path, valid_prefixes)
```

**Logic**:
1. Read index.json
2. Normalize valid_prefixes with trailing slashes
3. For each entry, keep if ANY of:
   - `entry.domain == "core"` (core entries always kept)
   - `entry.path` does not start with `"project/"` (safety: don't touch non-project entries)
   - `entry.path` starts with one of the valid prefixes
4. Remove everything else (orphans from non-loaded extensions)
5. Write filtered index.json

### Integration point in `init.lua`

The function should be called at the end of `manager.load()`, after the state is written (line 378). At that point, the extensions.json has been updated with the newly loaded extension, so we can read it to determine the full set of loaded extensions.

**Alternative (better)**: Add a new `manager.cleanup_orphaned_entries()` method that:
1. Reads extensions.json via `state_mod.read()` to get all loaded extensions
2. For each loaded extension, reads its manifest to get `provides.context`
3. Builds the valid prefix set
4. Calls `merge_mod.remove_orphaned_index_entries(index_path, valid_prefixes)`

This method should be called at the end of `manager.load()`, after state is written. It handles the cross-extension concern (cleaning other extensions' orphans) that individual load/unload can't handle.

### Relationship to task 301

Task 301's `remove_index_entries_by_prefix()` remains useful as a utility for explicit unload operations. The new post-load cleanup is complementary -- it catches orphans that survive because unload was never called. The unload-time cleanup (task 301) can optionally be simplified or removed, but it's not harmful to keep both.

## Effort Estimate

- **Implementation**: 1-2 hours
  - New function in merge.lua: ~30 lines
  - Integration in init.lua: ~20 lines
  - Testing: manual verification with sparse reload scenario
