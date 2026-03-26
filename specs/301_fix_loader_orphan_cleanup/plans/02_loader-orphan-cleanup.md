# Implementation Plan: Fix Loader Orphan Cleanup

**Task**: 301
**Date**: 2026-03-26
**Based on**: Research report 01_loader-orphan-cleanup.md

## Approach

Option A from the research report: path-prefix-based cleanup after unload.

## Phases

### Phase 1: Add `remove_index_entries_by_prefix()` to merge.lua [NOT STARTED]

Add a new public function to `merge.lua` that removes all index entries whose `path` starts with any of the given prefixes.

**Location**: After `remove_index_entries_tracked()` (line ~449)

**Function signature**:
```lua
function M.remove_index_entries_by_prefix(target_path, prefixes)
```

**Logic**:
1. Return true if file doesn't exist (nothing to clean)
2. Read index.json, return true if no entries
3. Backup the file
4. Filter entries: keep only those whose `path` does NOT start with any prefix
5. Write filtered index back
6. Return success boolean and count of removed entries

**Prefix matching**: Normalize prefixes to ensure trailing `/` for safety (e.g., `"project/lean4"` becomes `"project/lean4/"`) so `project/lean4-extra/` won't accidentally match.

### Phase 2: Call prefix cleanup from init.lua unload flow [NOT STARTED]

In `manager.unload()`, after `reverse_merge_targets()` (line ~429), add prefix-based cleanup.

**Logic**:
1. Check if extension manifest has `provides.context`
2. Check if extension manifest has `merge_targets.index` (to get target path)
3. Build target path: `project_dir .. "/" .. mt_config.target`
4. Call `merge_mod.remove_index_entries_by_prefix(target_path, prefixes)`
5. Log removed count if > 0

**Edge case**: If `extension` is nil (manifest not found during unload), the tracked removal already happened via `reverse_merge_targets()`. The prefix cleanup is a best-effort addition, so we simply skip it.

## Files Modified

| File | Change |
|------|--------|
| `lua/neotex/plugins/ai/shared/extensions/merge.lua` | Add `remove_index_entries_by_prefix()` |
| `lua/neotex/plugins/ai/shared/extensions/init.lua` | Call prefix cleanup in `manager.unload()` |

## Risk Assessment

Low risk. The prefix matching uses `provides.context` which maps directly to the path namespace convention. Extension paths are always under `project/{domain}/`, which does not overlap with core paths (`core/`, `meta/`, `patterns/`, etc.).

## Verification

1. Lua syntax check: `luacheck` or `nvim --headless -c "lua require('neotex.plugins.ai.shared.extensions.merge')" -c "q"`
2. Manual test: load extension, add external entries, unload, verify cleanup
