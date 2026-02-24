# Implementation Plan: Fix WezTerm New Tab Spawn Directory

- **Task**: 94 - Fix WezTerm new tab spawn directory by overriding Leader+c keybinding
- **Status**: [COMPLETED]
- **Effort**: 0.5 hours
- **Dependencies**: None
- **Research Inputs**: [research-001.md](../reports/research-001.md)
- **Artifacts**: plans/implementation-001.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: neovim

## Overview

Replace the existing `Leader+c` keybinding in `/home/benjamin/.dotfiles/config/wezterm.lua` that uses `act.SpawnTab("CurrentPaneDomain")` with a custom `wezterm.action_callback` that reads the foreground process's actual CWD from `/proc/PID/cwd`. This bypasses WezTerm's OSC 7 metadata, which becomes stale after exiting programs like Neovim. The fix includes a fallback to the default `SpawnTab` behavior when process info is unavailable (remote panes, process exit race conditions).

### Research Integration

Research report research-001.md confirmed all required APIs are available in the installed WezTerm version (0-unstable-2026-01-17):
- `pane:get_foreground_process_info()` returns `LocalProcessInfo` with `cwd` field
- `act.SpawnCommandInNewTab` accepts a `cwd` parameter to override OSC 7
- `wezterm.action_callback` is already used in this config file (line 247)
- The simpler approach (foreground process CWD directly, no ppid lookup) was recommended

## Goals & Non-Goals

**Goals**:
- New tabs spawned via `Leader+c` open at the foreground process's actual CWD
- After exiting Neovim, new tabs open at the shell's `$PWD` (not stale OSC 7 directory)
- Graceful fallback when process info is unavailable

**Non-Goals**:
- Changing CWD resolution for other tab spawn methods (middle-click, menu, etc.)
- Modifying OSC 7 emission behavior (that is Task 92's scope)
- Adding shell detection or parent process lookup logic

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| `get_foreground_process_info()` returns nil on remote panes | Low | Low | Fallback to `SpawnTab("CurrentPaneDomain")` |
| `cwd` field is empty string | Low | Low | Check `cwd ~= ""` before using |
| WezTerm API changes in future versions | Low | Low | Using stable, documented APIs available since 2022 |

## Implementation Phases

### Phase 1: Replace Leader+c Keybinding [COMPLETED]

**Goal:** Replace the static `SpawnTab("CurrentPaneDomain")` keybinding with a custom callback that reads the foreground process's actual CWD from `/proc`, bypassing stale OSC 7 metadata.

**Tasks:**
- [ ] Edit `/home/benjamin/.dotfiles/config/wezterm.lua` lines 427-431
- [ ] Replace `act.SpawnTab("CurrentPaneDomain")` with `wezterm.action_callback` that queries `pane:get_foreground_process_info()` for the real CWD
- [ ] Include fallback to `SpawnTab("CurrentPaneDomain")` when process info is unavailable
- [ ] Verify WezTerm loads the updated config without errors

**Exact code change -- replace lines 427-431:**

Current code:
```lua
  -- Tab management with Ctrl+Space leader
  {
    key = "c",
    mods = "LEADER",
    action = act.SpawnTab("CurrentPaneDomain"),
  },
```

New code:
```lua
  -- Tab management with Ctrl+Space leader
  {
    key = "c",
    mods = "LEADER",
    action = wezterm.action_callback(function(window, pane)
      -- Read the foreground process's actual CWD from /proc/PID/cwd
      -- This bypasses WezTerm's OSC 7 metadata which may be stale
      -- (e.g., after exiting Neovim, OSC 7 still reports Neovim's directory)
      local info = pane:get_foreground_process_info()
      if info and info.cwd and info.cwd ~= "" then
        window:perform_action(
          act.SpawnCommandInNewTab {
            domain = "CurrentPaneDomain",
            cwd = info.cwd,
          },
          pane
        )
      else
        -- Fallback: use default SpawnTab behavior (OSC 7 -> process CWD -> default)
        window:perform_action(act.SpawnTab("CurrentPaneDomain"), pane)
      end
    end),
  },
```

**Timing:** 15 minutes

**Files to modify:**
- `/home/benjamin/.dotfiles/config/wezterm.lua` - Replace Leader+c keybinding (lines 427-431)

**Verification:**
- WezTerm reloads config without errors (check WezTerm debug overlay or log)
- `cd /tmp && nvim` then `:q` then `Leader+c` opens new tab at `/tmp` (not Neovim's CWD)
- `cd /tmp` then `Leader+c` opens new tab at `/tmp`
- While inside Neovim, `Leader+c` opens new tab at Neovim's CWD (project directory)

## Testing & Validation

- [ ] WezTerm config reloads without errors after edit
- [ ] Scenario: At shell prompt in `/tmp`, press `Leader+c` -- new tab opens at `/tmp`
- [ ] Scenario: Run `nvim` from `/tmp`, exit with `:q`, press `Leader+c` -- new tab opens at `/tmp` (not stale Neovim CWD)
- [ ] Scenario: Inside Neovim (CWD is project dir), press `Leader+c` -- new tab opens at Neovim's CWD
- [ ] Scenario: Multiple `cd` operations, then `Leader+c` -- new tab follows the latest `$PWD`

## Artifacts & Outputs

- `/home/benjamin/.dotfiles/config/wezterm.lua` - Modified keybinding
- `specs/094_fix_wezterm_new_tab_spawn_directory_parent_shell_cwd/summaries/implementation-summary-20260224.md` - Implementation summary

## Rollback/Contingency

Revert the keybinding change by restoring the original single line:
```lua
action = act.SpawnTab("CurrentPaneDomain"),
```
This restores the default WezTerm behavior. The change is isolated to one keybinding entry with no side effects on other configuration.
