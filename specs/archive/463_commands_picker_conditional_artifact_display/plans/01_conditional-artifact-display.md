# Implementation Plan: Conditional Artifact Display in Commands Picker

- **Task**: 463 - Conditional Artifact Display in Commands Picker
- **Status**: [COMPLETED]
- **Effort**: 1.5 hours
- **Dependencies**: None
- **Research Inputs**: specs/463_commands_picker_conditional_artifact_display/reports/01_conditional-artifact-display.md
- **Artifacts**: plans/01_conditional-artifact-display.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim
- **Lean Intent**: true

## Overview

Refactor `entries.lua` to conditionally display artifact sections based on extension load state and remove the asterisk prefix from non-extension artifacts. The picker currently renders all 15 artifact sections unconditionally regardless of whether any extensions are loaded, and uses asterisk (`*`) to indicate local vs global origin on all artifact types. After this change, the picker will show only Extensions + special entries when no extensions are loaded, reveal all sections once extensions are active, and reserve asterisks exclusively for loaded extensions.

### Research Integration

The research report mapped all 15 asterisk locations in `entries.lua`, confirmed the extension state API (`list_loaded()` on the extensions module), and validated that no previewer changes are needed. The recommended approach -- gating non-extension section creation in `create_picker_entries()` and replacing `is_local and "*" or " "` with `" "` in all non-extension format functions -- is adopted directly.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No ROADMAP.md found.

## Goals & Non-Goals

**Goals**:
- Show only Extensions section and special entries (Load Core, Help) when no extensions are loaded
- Show full artifact listing once extensions are loaded
- Remove asterisk prefix from all non-extension artifacts (commands, skills, agents, hooks, rules, scripts, tests, docs, context, lib, templates, memories, root files)
- Preserve asterisk prefix for active extensions only
- Maintain previewer functionality and all keymaps (Ctrl-l, Ctrl-u, Ctrl-s, Ctrl-e)

**Non-Goals**:
- Adding a replacement indicator for the removed local/global distinction
- Changing previewer logic
- Modifying the OpenCode picker separately (it shares the same code path)

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Users lose local-vs-global visibility | M | M | No current user reports relying on this; previewer shows file paths |
| Extensions module fails to load | L | L | pcall guards already in place; treat failure as "no extensions loaded" |
| OpenCode variant breaks | L | L | Both configs share same `create_picker_entries`; `config.extensions_module` handles divergence |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |

Phases within the same wave can execute in parallel.

### Phase 1: Remove Asterisks and Add Conditional Display Gate [COMPLETED]

**Goal**: Remove asterisk prefix from all non-extension artifacts and gate non-extension sections behind extension load state check.

**Tasks**:
- [ ] In `format_hook_event()`: replace `has_local_hook and "*" or " "` with `" "`
- [ ] In `format_command()`: replace `command.is_local and "*" or " "` with `" "`
- [ ] In `format_skill()`: replace `skill.is_local and "*" or " "` with `" "`
- [ ] In `format_agent()`: replace `agent.is_local and "*" or " "` with `" "`
- [ ] In `format_root_file()`: replace `root_file.is_local and "*" or " "` with `" "`
- [ ] In `create_context_entries()`: replace `file.is_local and "*" or " "` with `" "`
- [ ] In `create_memory_entries()`: replace both `index_is_local and "*" or " "` and `mem.is_local and "*" or " "` with `" "`
- [ ] In `create_rules_entries()`: replace `rule.is_local and "*" or " "` with `" "`
- [ ] In `create_docs_entries()`: replace `is_local and "*" or " "` with `" "`
- [ ] In `create_lib_entries()`: replace `lib.is_local and "*" or " "` with `" "`
- [ ] In `create_templates_entries()`: replace `tmpl.is_local and "*" or " "` with `" "`
- [ ] In `create_scripts_entries()`: replace `script.is_local and "*" or " "` with `" "`
- [ ] In `create_tests_entries()`: replace `test.is_local and "*" or " "` with `" "`
- [ ] In `create_picker_entries()`: after creating special and extensions entries, check `extensions.list_loaded()` via config's `extensions_module`. If no extensions are loaded, return early with only special + extensions entries
- [ ] Remove now-unused `has_local_hook` logic in `format_hook_event()` (the entire `is_event_local` / loop check block can be simplified since prefix is always `" "`)

**Timing**: 1 hour

**Depends on**: none

**Files to modify**:
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Remove 15 asterisk prefixes, add extension load check gate in `create_picker_entries()`

**Verification**:
- All `is_local and "*" or " "` patterns replaced with `" "` in non-extension functions
- `create_extensions_entries()` still uses `(ext.status == "active") and "*" or " "` (unchanged)
- `create_picker_entries()` returns early when no extensions loaded
- File loads without syntax errors: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q"`

---

### Phase 2: Integration Testing [NOT STARTED]

**Goal**: Verify the refactored picker behaves correctly in all states.

**Tasks**:
- [ ] Open picker with no extensions loaded: confirm only Extensions section, Load Core, and Help are visible
- [ ] Load an extension via the picker (Enter on an extension entry)
- [ ] Reopen picker: confirm all artifact sections now appear without asterisk prefixes on non-extension entries
- [ ] Confirm active extension still shows asterisk prefix
- [ ] Test Ctrl-l (load artifact), Ctrl-u (update from global), Ctrl-s (save to global), Ctrl-e (edit) on visible entries
- [ ] Test Ctrl-r (run script) and Ctrl-t (run test) on script/test entries
- [ ] Unload the extension, reopen picker: confirm sections collapse back to Extensions-only view
- [ ] Verify cursor restoration works after extension load/unload (the uncommitted `_restore_extension_name` feature)

**Timing**: 30 minutes

**Depends on**: 1

**Files to modify**:
- None (manual testing only)

**Verification**:
- All test scenarios pass
- No regressions in previewer display
- Keymaps continue to function on all entry types

## Testing & Validation

- [ ] Picker shows only Extensions + special entries when no extensions loaded
- [ ] Picker shows all sections when extensions are loaded
- [ ] No asterisk prefix on any non-extension entry
- [ ] Active extensions still show asterisk prefix
- [ ] Previewer displays correct content for all entry types
- [ ] All keymaps (Enter, Ctrl-l, Ctrl-u, Ctrl-s, Ctrl-e, Ctrl-n, Ctrl-r, Ctrl-t) work
- [ ] Cursor restoration after extension toggle works
- [ ] Module loads cleanly: `nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q"`

## Artifacts & Outputs

- `specs/463_commands_picker_conditional_artifact_display/plans/01_conditional-artifact-display.md` (this plan)
- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` (modified)

## Rollback/Contingency

Revert the single modified file using `git checkout -- lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua`. The uncommitted changes from prior task 463 work (extension status indicator simplification and cursor restoration) would also need to be re-applied if reverted, so a targeted `git stash` before implementation is recommended.
