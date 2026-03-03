# Implementation Summary: Task #120

**Completed**: 2026-03-03
**Duration**: ~2 hours

## Changes Made

Fixed the Telescope picker's `[Hook Events]` section so that PreToolUse and PostToolUse events (and any other events using inline `bash -c '...'` commands) correctly display the `*` (local) marker. Added inline hook detection with synthetic entries so the previewer shows useful command details. Consolidated duplicate hook event description tables into a single source of truth in `registry.lua`.

## Files Modified

- `lua/neotex/plugins/ai/claude/commands/parser.lua` - Extended `build_hook_dependencies` with inline hook detection (fallback when `.sh` regex fails), synthetic hook entry creation, event-level locality tracking, and updated `get_extended_structure` to pass locality flag and capture `event_is_local` return value
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Updated `format_hook_event` to accept `is_event_local` parameter and check event-level locality before individual hook `is_local` flags; updated `create_hooks_entries` to read `structure.event_is_local` and pass per-event value; removed local `descriptions` table in favor of registry
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Updated `preview_hook_event` to use `registry.HOOK_EVENT_DESCRIPTIONS` for descriptions and render inline hooks with command snippet instead of filepath; removed local `event_descriptions` table
- `lua/neotex/plugins/ai/claude/commands/picker/artifacts/registry.lua` - Added `HOOK_EVENT_DESCRIPTIONS` table with `short` (for entry display) and `long` (for previewer) variants for all 9 hook event types

## Verification

- Parser module loads: Pass
- Entries module loads: Pass
- Previewer module loads: Pass
- Registry has HOOK_EVENT_DESCRIPTIONS: Pass
- Inline hook detection creates synthetic entries: Pass
- Inline hook event_is_local set to true: Pass
- No duplicate description tables in entries.lua or previewer.lua: Pass (grep confirmed)

## Technical Approach

### Inline Hook Detection (Phase 1)
The `.sh` filename regex fallback pattern: when `hook_config.command:match("([^/%s]+%.sh)")` returns nil, a synthetic hook entry is created with:
- `name`: `[inline:N]` format (counter-based to avoid collisions)
- `is_inline`: true (flag for conditional rendering in previewer)
- `command`: truncated to 80 chars for display
- `filepath`: points to the settings file that defines it

### Event-Level Locality (Phases 1-2)
`build_hook_dependencies` now returns a second value `event_is_local` mapping event names to booleans. This is passed as the `is_local_settings` parameter and applies to all events found in that settings file. The `format_hook_event` function checks this flag first, before iterating individual hook `is_local` fields - ensuring inline hooks (which don't have separate .sh files) still trigger the `*` marker.

### Description Consolidation (Phases 3-4)
Removed duplicate description tables from both `entries.lua` (local `descriptions`) and `previewer.lua` (local `event_descriptions`). Both now require `registry` and use `registry.HOOK_EVENT_DESCRIPTIONS[event_name].short` and `.long` respectively.

## Notes

- OpenCode picker (hooks_subdir = nil) is unaffected - the hooks block in `get_extended_structure` is guarded by `if hooks_subdir then`
- The `.sh` regex detection path is unchanged - inline detection only triggers when the regex returns nil
- Synthetic inline hooks have `filepath` pointing to the settings file, not a standalone `.sh` script. Edit/sync operations that check for real filepaths will see the settings file path, which is intentional for the "edit settings" action.
- When `project_dir == global_dir` (working in `~/.config`), all settings are treated as local (`is_local_settings = true`)
