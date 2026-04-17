# Implementation Summary: Task #463

**Completed**: 2026-04-16
**Duration**: 15 minutes

## Changes Made

Refactored the commands picker to conditionally display artifact sections based on extension load state and removed asterisk prefixes from all non-extension artifacts.

### Asterisk Removal (entries.lua)

Replaced 15 `is_local and "*" or " "` patterns with `" "` across all non-extension entry creation functions:
- `format_hook_event()` -- also simplified by removing the `has_local_hook` detection logic (event-level and per-hook checks) since the prefix is now always a space
- `format_command()`, `format_skill()`, `format_agent()`, `format_root_file()` -- local functions
- `create_context_entries()`, `create_memory_entries()` (2 locations: index + individual memories), `create_rules_entries()`, `create_docs_entries()`, `create_lib_entries()`, `create_templates_entries()`, `create_scripts_entries()`, `create_tests_entries()` -- module functions

The asterisk prefix in `create_extensions_entries()` for active extensions (`ext.status == "active"`) was preserved unchanged.

### Conditional Display Gate (entries.lua)

Added an early-return gate in `create_picker_entries()` after creating special and extensions entries. The gate checks if any extensions are loaded via the config's `extensions_module` (defaulting to Claude's module). When no extensions are loaded, only Special entries (Load Core, Help) and the Extensions section are returned. When extensions are loaded, all artifact sections are created as before.

### Picker Guard Relaxation (init.lua)

Replaced the guard that prevented the picker from opening when no commands were found with a fallback that provides an empty structure. This ensures the picker always opens -- allowing users to access the Extensions section and Load Core button even in fresh projects without any synced artifacts.

## Files Modified

- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Removed 15 asterisk prefixes from non-extension artifacts, simplified `format_hook_event()`, added conditional display gate in `create_picker_entries()`
- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Replaced empty-commands guard with structure fallback so picker always opens

## Verification

- Build: N/A (Neovim plugin)
- Syntax: Both files pass `loadfile()` check via nvim headless
- Asterisk audit: Only 1 asterisk pattern remains (extensions active status, line 916)
- Files verified: Yes

## Notes

- Phase 2 (integration testing) is manual-only and requires opening the picker in Neovim with various extension states
- The `is_event_local` parameter and `event_hooks` parameter in `format_hook_event()` are still accepted for API compatibility but no longer influence the display prefix
- OpenCode variant uses the same `create_picker_entries()` path and benefits from the same changes via `config.extensions_module`
