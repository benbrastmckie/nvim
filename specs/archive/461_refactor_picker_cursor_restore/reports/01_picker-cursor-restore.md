# Research Report: Task #461

**Task**: 461 - Review and refactor picker cursor restoration
**Started**: 2026-04-16T00:00:00Z
**Completed**: 2026-04-16T00:15:00Z
**Effort**: small
**Dependencies**: None
**Sources/Inputs**:
- Codebase: `lua/neotex/plugins/ai/claude/commands/picker/init.lua`
- Codebase: `lua/neotex/plugins/ai/shared/extensions/picker.lua`
- Codebase: `lua/neotex/plugins/ai/opencode/commands/picker.lua`
- Codebase: `lua/neotex/plugins/ai/opencode/extensions/picker.lua`
- Git diff of uncommitted changes
**Artifacts**:
- `specs/461_refactor_picker_cursor_restore/reports/01_picker-cursor-restore.md`
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The `register_completion_callback + vim.schedule + set_selection` approach in commands picker is correct and well-suited for descending sorting_strategy; it searches by name rather than index, avoiding off-by-one issues with sort order.
- The extensions picker (`shared/extensions/picker.lua`) is clean with no leftover debugging artifacts. It uses a different but valid cursor restore approach (`default_selection_index`).
- Five other close/reopen cycles exist in the commands picker (Ctrl-l, Ctrl-u, Ctrl-s, Load All, extension toggle via Enter) but only the extension toggle needs cursor restore -- the others operate on different artifact types where returning to the top is acceptable.
- A shared helper is not strongly warranted: the two pickers use fundamentally different restore strategies (name-based vs index-based), and the commands picker only needs restore for one action.
- The OpenCode commands picker is a thin facade delegating to the same `init.lua`, so cursor restore works there automatically.
- The `ext/actions.close` reorder on line 164-168 (moving `local ext = selection.value` before `actions.close`) is a minor but correct safety improvement.

## Context & Scope

Task 463 implemented conditional artifact display in the commands picker. Prior to that, task 461 (this review) was created to examine the cursor-position-restore feature that was added to the commands picker during a debugging session. The feature ensures that after loading/unloading an extension (which closes and reopens the picker), the cursor returns to the extension entry that was just toggled.

### Files Under Review

1. `lua/neotex/plugins/ai/claude/commands/picker/init.lua` -- main commands picker
2. `lua/neotex/plugins/ai/shared/extensions/picker.lua` -- standalone extensions picker
3. `lua/neotex/plugins/ai/opencode/commands/picker.lua` -- OpenCode facade (delegates to #1)
4. `lua/neotex/plugins/ai/opencode/extensions/picker.lua` -- OpenCode extensions facade (delegates to #2)

## Findings

### 1. Commands Picker Cursor Restore (init.lua)

**The implementation** (lines 28-91 in current file):

- `opts._restore_extension_name` is extracted and cleaned from opts at the top of `show_commands_picker`
- When present, a `register_completion_callback` is set on the picker instance
- Inside the callback, `vim.schedule` defers execution to ensure the picker's result manager is populated
- The callback iterates through results to find the entry matching `restore_ext_name` by name
- `self:set_selection(self:get_row(idx))` positions the cursor

**Assessment**: This approach is robust for descending sorting_strategy because:
- It searches by entry name, not by numeric index, so sort order is irrelevant
- The `self.manager` nil check prevents errors if the picker closes before results load
- `vim.schedule` correctly handles the async completion of Telescope's finder population

**The `_restore_extension_name` convention**: The underscore prefix correctly signals this is an internal/private option not part of the public API. It is cleaned from `opts` immediately after extraction (line 30) to prevent leakage.

**The close reorder (line 164-168)**: Moving `local ext = selection.value` before `actions.close(prompt_bufnr)` is a minor safety improvement. After `actions.close`, the picker buffer is destroyed, so accessing `action_state` data after close could theoretically be unreliable. Extracting `ext` first is the safer ordering.

### 2. Extensions Picker (shared/extensions/picker.lua)

**Assessment**: The file is clean with no leftover debugging artifacts. It uses a different cursor restore strategy:

- Lines 179-180: Captures `selection_index` via `picker:get_index(picker:get_selection_row())`
- Line 193: Passes `default_selection_index = selection_index` when reopening

This index-based approach works because the extensions picker uses the default (ascending) sorting strategy, where `default_selection_index` maps directly to result position. It would NOT work correctly with descending strategy (which is why the commands picker uses name-based lookup instead).

### 3. Close/Reopen Cycles in Commands Picker

| Action | Lines | Entry Types | Close/Reopen? | Cursor Restore Needed? |
|--------|-------|-------------|---------------|----------------------|
| Enter (extension toggle) | 166-181 | extension | Yes | Yes (implemented) |
| Enter (Load All) | 116-129 | load_all | Yes | No (global action, return to top is fine) |
| Ctrl-l (load locally) | 185-206 | any artifact | Yes | Low value -- artifact list changes |
| Ctrl-u (update from global) | 209-230 | any artifact | Yes | Low value -- same reasoning |
| Ctrl-s (save to global) | 233-254 | any artifact | Yes | Low value -- same reasoning |
| Ctrl-e (edit file) | 257-278 | any artifact | No (opens editor) | N/A |
| Ctrl-n (new command) | 281-284 | N/A | No (opens editor) | N/A |
| Ctrl-r (run script) | 287-295 | script | No (opens editor) | N/A |
| Ctrl-t (run test) | 298-306 | test | No (opens editor) | N/A |

**Analysis**: Only the extension toggle (Enter on extension entry) truly benefits from cursor restore. The other close/reopen cycles (Ctrl-l, Ctrl-u, Ctrl-s, Load All) perform sync operations where the entry list may change, and returning to the top of the list is the expected UX. Adding cursor restore to these would add complexity for minimal UX gain.

### 4. Shared Helper Evaluation

**Arguments for a shared helper**:
- Both pickers have close/reopen patterns
- DRY principle

**Arguments against**:
- The two strategies are fundamentally different (name-based vs index-based)
- The commands picker only needs restore for one action type (extensions)
- The extensions picker already has a working, simpler approach
- A generic helper would need to abstract over both strategies, adding complexity for only two call sites
- The commands picker's `register_completion_callback` approach is tightly coupled to Telescope internals

**Verdict**: Not warranted. The implementations are small (15 lines for commands, 2 lines for extensions), use different strategies, and a shared abstraction would be more complex than the sum of the two implementations.

### 5. OpenCode Picker

`lua/neotex/plugins/ai/opencode/commands/picker.lua` is a 21-line facade that delegates entirely to `internal.show_commands_picker(opts, config)`. The cursor restore feature works automatically for OpenCode because the same `init.lua` code path is used. No separate implementation needed.

Similarly, `lua/neotex/plugins/ai/opencode/extensions/picker.lua` delegates to the shared `extensions/picker.lua`, so cursor restore works there too.

## Decisions

- The current `register_completion_callback + vim.schedule + set_selection` approach is correct and should be kept
- Cursor restore should NOT be added to Ctrl-l, Ctrl-u, Ctrl-s, or Load All cycles
- A shared helper should NOT be extracted
- The `_restore_extension_name` convention is appropriate and does not need additional documentation beyond the inline comment
- The `ext/actions.close` reorder is a correct improvement

## Recommendations

1. **Commit the current uncommitted changes as-is** -- the implementation is clean and correct. The diff shows: (a) the cursor restore feature in init.lua, (b) the close reorder safety fix, and (c) the simplified status indicator in entries.lua. All are good changes.

2. **No further refactoring needed** -- the task description raised five review questions and all have been answered favorably. The code is in good shape.

3. **Consider adding a brief comment** at the extension toggle block (line 166-181) explaining why this is the only close/reopen cycle that uses cursor restore, to prevent future developers from adding it to other cycles unnecessarily. This is optional.

## Risks & Mitigations

- **Risk**: `self.manager` could theoretically be nil if the picker is closed very quickly after opening. **Mitigation**: Already handled by the nil check on line 79.
- **Risk**: If an extension name changes between close and reopen (unlikely), the name-based lookup would fail silently. **Mitigation**: This is acceptable -- cursor simply stays at default position.
- **Risk**: The `vim.defer_fn(..., 100)` delay could be too short on slow systems. **Mitigation**: 100ms is standard for Telescope close/reopen patterns throughout the codebase.

## Appendix

### Uncommitted Changes Summary (git diff)

Three files modified:
1. `init.lua`: Added cursor restore via `_restore_extension_name` + `register_completion_callback`; reordered `ext` extraction before `actions.close`
2. `entries.lua`: Simplified extension status indicator (asterisk prefix conveys active/inactive, so only `[update]` badge is shown)

### Search Queries
- `Glob: lua/neotex/plugins/ai/opencode/**/*.lua` -- found OpenCode picker files
- `Read` on all four picker files
- `git diff` on modified files
