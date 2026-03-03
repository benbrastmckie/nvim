# Implementation Plan: Fix PreToolUse Hook Picker Display

- **Task**: 120 - fix_pretooluse_hook_picker_display
- **Status**: [COMPLETED]
- **Effort**: 3-4 hours
- **Dependencies**: None
- **Research Inputs**:
  - [research-001.md](../reports/research-001.md) - Inline-command hook detection, synthetic hook entries, event-level locality tracking
  - [research-002.md](../reports/research-002.md) - Broader picker architecture, dynamic artifact management, hardcoded list elimination
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: false

## Overview

The `[Hook Events]` section of the Telescope picker fails to display the `*` (local) marker for hook events whose hooks use inline `bash -c '...'` commands rather than `.sh` file references. The root cause is that `build_hook_dependencies` in `parser.lua` uses a regex (`([^/%s]+%.sh)`) that only matches `.sh` filenames, so inline hooks produce empty hook lists. Additionally, the picker has duplicate hardcoded description tables for hook events in both `entries.lua` and `previewer.lua`. This plan addresses both the immediate inline hook bug and the broader architecture cleanup by consolidating descriptions into `registry.lua` and improving the previewer to render inline hook details.

### Research Integration

**From research-001**: The combined Approach A+B is adopted -- synthetic hook entries for inline commands (so the previewer can show hook details) plus event-level locality tracking (so the `*` marker works regardless of hook type). The `is_local` determination uses the settings file path comparison already present in `get_extended_structure`.

**From research-002**: The filtering recommendation (skip events with zero manageable artifacts) is NOT adopted because it would hide events that have inline hooks -- the whole point is to make those visible. Instead, inline hooks get synthetic entries so events always have content. The description consolidation into `registry.lua` is adopted to eliminate the duplicate tables.

## Goals & Non-Goals

**Goals**:
- PreToolUse and PostToolUse events display `*` marker when their hooks are defined in the local project's settings.json
- Inline command hooks appear in the previewer with a truncated command snippet
- Hook event descriptions exist in a single source of truth (registry.lua)
- The fix follows the existing `is_local` convention used by commands, skills, and agents

**Non-Goals**:
- Refactoring root file lists or subdir maps (low priority per research-002)
- Making the hook events section fully filesystem-driven (it correctly derives from settings.json)
- Supporting OpenCode hooks (hooks_subdir is nil for OpenCode; no changes needed)
- Merging multiple settings files (local + global) for the same event

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing .sh-based hook detection | High | Low | The .sh regex path is unchanged; inline detection is a fallback only triggered when regex returns nil |
| Synthetic hook entries confusing other picker operations (edit, sync) | Medium | Low | Mark synthetic hooks with `is_inline = true`; edit/sync operations skip entries without a filepath |
| Registry changes breaking existing tests | Medium | Low | registry_spec.lua tests can be extended; descriptions are data, not logic |
| Event-level locality incorrect when project_dir == global_dir | Low | Low | When both dirs are the same, all settings are inherently local; existing `parse_with_fallback` handles this pattern |

## Implementation Phases

### Phase 1: Extend parser.lua with inline hook detection and event locality [COMPLETED]

**Goal**: Make `build_hook_dependencies` recognize inline-command hooks and track whether each event comes from the local settings file.

**Tasks**:
- [ ] Add `is_local` parameter to `build_hook_dependencies` function signature
- [ ] After the `.sh` regex match fails (line 355), add fallback that creates a synthetic hook name for inline commands (format: `[inline:N]` where N is a counter)
- [ ] Create synthetic hook entries and insert them into the `hooks` array with fields: `name`, `description` ("Inline command hook"), `filepath` (settings_path), `is_local` (from parameter), `events` ({event_name}), `is_inline` (true), `command` (truncated to 80 chars)
- [ ] Track event-level locality: build a second return value `event_is_local` table mapping event_name to boolean
- [ ] Update `get_extended_structure` to determine `is_local_settings` before calling `build_hook_dependencies`, and pass it as the new parameter
- [ ] Capture the second return value (`event_is_local`) and add it to the returned structure table

**Timing**: 1 hour

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/parser.lua` - `build_hook_dependencies` (lines 330-377) and `get_extended_structure` (lines 713-717)

**Verification**:
- Load the picker with `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.parser').build_hook_dependencies({}, '/path/to/settings')" -c "q"` to verify no errors
- Verify that hook_events for PreToolUse and PostToolUse contain synthetic names
- Verify that event_is_local maps correctly

---

### Phase 2: Update entries.lua to use event-level locality for the * marker [COMPLETED]

**Goal**: Make `format_hook_event` and `create_hooks_entries` use event-level locality data so inline hook events show the `*` prefix.

**Tasks**:
- [ ] Add `is_event_local` parameter to `format_hook_event` function signature
- [ ] In `format_hook_event`, set `has_local_hook = true` if `is_event_local` is true (before checking individual hooks)
- [ ] In `create_hooks_entries`, read `structure.event_is_local` and pass the per-event value to `format_hook_event`
- [ ] Pass `event_is_local` flag into the entry value table so the previewer can access it

**Timing**: 30 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - `format_hook_event` (lines 16-48) and `create_hooks_entries` (lines 498-543)

**Verification**:
- Open the picker and confirm PreToolUse and PostToolUse show `*` prefix
- Confirm existing .sh-based events still show `*` when local

---

### Phase 3: Update previewer.lua to render inline hook details [COMPLETED]

**Goal**: Make `preview_hook_event` display useful information for inline hooks instead of showing "0 hook(s)".

**Tasks**:
- [ ] In `preview_hook_event`, detect hooks with `is_inline = true`
- [ ] For inline hooks, display "Inline command" label followed by the truncated command string from `hook.command` instead of the filepath
- [ ] Keep the existing filepath display for regular .sh hooks
- [ ] Show the correct hook count (including inline hooks)

**Timing**: 30 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - `preview_hook_event` (lines 319-347)

**Verification**:
- Select a PreToolUse event in the picker and verify the previewer shows inline command details
- Select a Stop event and verify regular .sh hooks still display with filepath

---

### Phase 4: Consolidate hook event descriptions into registry.lua [COMPLETED]

**Goal**: Eliminate the duplicate hook event description tables from entries.lua and previewer.lua by moving them into a single table in `registry.lua`.

**Tasks**:
- [ ] Add `HOOK_EVENT_DESCRIPTIONS` table to `registry.lua` with both short and long description variants for each event (Stop, SessionStart, SessionEnd, SubagentStop, Notification, PreToolUse, PostToolUse, UserPromptSubmit, PreCompact)
- [ ] Update `format_hook_event` in `entries.lua` to use `registry.HOOK_EVENT_DESCRIPTIONS[event_name].short` instead of the local `descriptions` table
- [ ] Update `preview_hook_event` in `previewer.lua` to use `registry.HOOK_EVENT_DESCRIPTIONS[event_name].long` instead of the local `event_descriptions` table
- [ ] Remove the now-unused local description tables from both files
- [ ] Add `local registry = require(...)` import to both files if not already present

**Timing**: 45 minutes

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/artifacts/registry.lua` - Add `HOOK_EVENT_DESCRIPTIONS` table
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Replace local descriptions with registry reference
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Replace local descriptions with registry reference

**Verification**:
- Open the picker and verify hook event descriptions still display correctly in the entry list
- Open the previewer for a hook event and verify the long description displays correctly
- Grep for `event_descriptions` and `descriptions = {` in entries.lua and previewer.lua to confirm removal

---

### Phase 5: End-to-end testing and verification [COMPLETED]

**Goal**: Validate the complete fix works end-to-end with no regressions.

**Tasks**:
- [ ] Test with `nvim --headless` that parser module loads without errors: `nvim --headless -c "lua local p = require('neotex.plugins.ai.claude.commands.parser'); print(vim.inspect(type(p.build_hook_dependencies)))" -c "q"`
- [ ] Test that entries module loads without errors: `nvim --headless -c "lua local e = require('neotex.plugins.ai.claude.commands.picker.display.entries'); print('OK')" -c "q"`
- [ ] Test that previewer module loads without errors: `nvim --headless -c "lua local p = require('neotex.plugins.ai.claude.commands.picker.display.previewer'); print('OK')" -c "q"`
- [ ] Test that registry module loads and has the new descriptions table: `nvim --headless -c "lua local r = require('neotex.plugins.ai.claude.commands.picker.artifacts.registry'); assert(r.HOOK_EVENT_DESCRIPTIONS, 'missing HOOK_EVENT_DESCRIPTIONS'); print('OK')" -c "q"`
- [ ] Test build_hook_dependencies with a mock settings structure that includes inline commands, verifying synthetic entries are created
- [ ] Verify no hardcoded description tables remain in entries.lua or previewer.lua (grep check)
- [ ] Open the picker interactively and verify: (a) PreToolUse/PostToolUse show `*`, (b) previewer shows inline command details, (c) .sh-based events still work correctly

**Timing**: 30 minutes

**Files to modify**:
- No files modified; testing only

**Verification**:
- All headless tests pass with exit code 0
- Grep confirms no duplicate description tables
- Interactive verification confirms correct display

## Testing & Validation

- [ ] All modules load without errors via `nvim --headless`
- [ ] PreToolUse and PostToolUse events display `*` marker in picker
- [ ] Previewer shows inline command details for inline hooks
- [ ] Previewer still shows filepath for .sh-based hooks
- [ ] Hook event descriptions display correctly from registry.lua
- [ ] No duplicate description tables in entries.lua or previewer.lua
- [ ] Existing .sh-based hook events retain correct `*` markers and previewer behavior
- [ ] OpenCode picker (hooks_subdir = nil) is unaffected

## Artifacts & Outputs

- `lua/neotex/plugins/ai/claude/commands/parser.lua` - Extended build_hook_dependencies with inline hook detection and event locality
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Updated format_hook_event with event-level locality
- `lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua` - Updated preview_hook_event for inline hooks
- `lua/neotex/plugins/ai/claude/commands/picker/artifacts/registry.lua` - New HOOK_EVENT_DESCRIPTIONS table
- `specs/120_fix_pretooluse_hook_picker_display/plans/implementation-001.md` - This plan
- `specs/120_fix_pretooluse_hook_picker_display/summaries/implementation-summary-YYYYMMDD.md` - Post-implementation summary

## Rollback/Contingency

All changes are in 4 Lua files. If the implementation causes regressions:
1. Revert the 4 modified files via `git checkout HEAD -- lua/neotex/plugins/ai/claude/commands/parser.lua lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua lua/neotex/plugins/ai/claude/commands/picker/display/previewer.lua lua/neotex/plugins/ai/claude/commands/picker/artifacts/registry.lua`
2. The synthetic hook approach is isolated -- removing it restores the original behavior where inline hooks are invisible but cause no errors
3. The description consolidation can be reverted independently of the inline hook fix
