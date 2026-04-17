# Implementation Summary: Task #461

**Completed**: 2026-04-16
**Duration**: 10 minutes

## Overview

Committed the existing cursor-restore implementation for the commands picker and added a clarifying inline comment explaining the design rationale. Research confirmed the implementation was correct; this task was primarily a review-and-commit operation.

## What Changed

### Commands Picker (init.lua)
- **Cursor restore feature**: Name-based cursor restoration after extension toggle (load/unload) via `register_completion_callback` + `vim.schedule` + `set_selection`. The picker reopens with the cursor on the previously selected extension entry.
- **Close-reorder safety fix**: Moved `actions.close(prompt_bufnr)` after capturing `selection.value` to prevent accessing stale data.
- **Clarifying comment**: Added a 3-line comment at the extension toggle block explaining why only this close/reopen cycle uses cursor restore (the entry list is stable across toggle, unlike artifact sync operations).

### Entries Display (entries.lua)
- **Simplified status indicator**: Removed redundant `[active]`/`[inactive]` text labels since the asterisk prefix already conveys active/inactive state. Only `[update]` is shown when an update is available.

## Files Modified

- `lua/neotex/plugins/ai/claude/commands/picker/init.lua` - Cursor restore, close-reorder fix, clarifying comment
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Simplified extension status indicator

## Decisions

- No shared cursor-restore helper between commands and extensions pickers (different strategies: name-based vs index-based)
- No cursor restore for Ctrl-l, Ctrl-u, Ctrl-s, or Load All cycles (list changes make cursor reset expected behavior)

## Verification

- Build: N/A (Lua configuration, no build step)
- Tests: Manual verification required (toggle extension, verify cursor position)
- Files verified: Yes

## References

- Research report: `specs/461_refactor_picker_cursor_restore/reports/01_picker-cursor-restore.md`
- Implementation plan: `specs/461_refactor_picker_cursor_restore/plans/01_picker-cursor-restore.md`
