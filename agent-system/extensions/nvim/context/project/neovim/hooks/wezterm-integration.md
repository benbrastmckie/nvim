# WezTerm Tab Integration

This document describes the WezTerm terminal integration for Claude Code, providing tab title updates and visual notifications.

## Overview

The integration enables:
- Task number display in WezTerm tab titles (e.g., `nvim #792`)
- Lifecycle-aware tab coloring with dim-to-bold transitions within same hue families
- Automatic notification clearing when the user views or responds

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│ WezTerm Tab Title                                               │
│ "1 nvim #792"                                                   │
└─────────────────────────────────────────────────────────────────┘
                    ▲                           ▲
                    │                           │
         ┌─────────┴─────────┐       ┌─────────┴─────────┐
         │ OSC 7             │       │ OSC 1337          │
         │ file://host/path  │       │ SetUserVar=...    │
         └─────────┬─────────┘       └─────────┬─────────┘
                   │                           │
    ┌──────────────┴──────────┐    ┌──────────┴──────────────┐
    │ Shell / Neovim          │    │ Claude Code Hooks        │
    │                         │    │                          │
    │ Directory updates from  │    │ wezterm-task-number.sh   │
    │ shells and Neovim       │    │ wezterm-notify.sh        │
    │ autocmds                │    │ wezterm-preflight-status │
    └─────────────────────────┘    └──────────────────────────┘
```

## Hook Files

### wezterm-notify.sh

**Path**: `.claude/hooks/wezterm-notify.sh`
**Hook Event**: `Stop` (also called directly by `update-task-status.sh`)
**Purpose**: Set tab notification color based on lifecycle state

Sets `CLAUDE_STATUS` via OSC 1337 to the pane TTY. The WezTerm `format-tab-title` handler reads this variable and applies color-coded background to inactive tabs.

Uses shared TTY discovery from `wezterm-utils.sh`.

**Usage**:
- `bash wezterm-notify.sh` -- Sets `CLAUDE_STATUS=needs_input` (Stop hook, gray tab)
- `bash wezterm-notify.sh researched` -- Sets `CLAUDE_STATUS=researched` (bright green tab)
- `bash wezterm-notify.sh completed` -- Sets `CLAUDE_STATUS=completed` (bright gold tab)

### wezterm-preflight-status.sh

**Path**: `.claude/hooks/wezterm-preflight-status.sh`
**Hook Event**: `UserPromptSubmit`
**Purpose**: Set in-progress tab coloring immediately when user submits a lifecycle command

3-tier logic:
- **Tier 1** (lifecycle commands): Sets dim in-progress color before Claude responds
- **Tier 2** (other slash commands): Clears CLAUDE_STATUS and workflow-active marker
- **Tier 3** (free text): Preserves CLAUDE_STATUS (no-op)

Also clears the workflow-active marker on Tier 2 to handle ESC-cancel edge cases.

### wezterm-utils.sh

**Path**: `.claude/hooks/wezterm-utils.sh`
**Purpose**: Shared TTY discovery and OSC write functions (sourced by other hooks)

Provides:
- `get_pane_tty()`: Returns writable TTY path for the current WezTerm pane
- `set_user_var()`: Sets a WezTerm user variable via OSC 1337

### wezterm-task-number.sh

**Path**: `.claude/hooks/wezterm-task-number.sh`
**Hook Event**: `UserPromptSubmit`
**Purpose**: Extract and display task number in tab title

Parses user prompt for workflow patterns using 3-tier logic:
- `/research N` or `/research N, N-N, N` (multi-task)
- `/plan N` or `/plan N, N-N`
- `/implement N` or `/implement N, N-N, N`
- `/revise N`
- `/spawn N`
- `/task --recover N`
- `/task --expand N`
- `/task --abandon N`
- `/task --review N`
- `/errors --fix N`

**Behavior**:
- **Workflow command with task number**: Sets `TASK_NUMBER` to compact spec (e.g., `7,22-24,59`)
- **Slash command without task number**: Clears `TASK_NUMBER` user variable
- **Free text / follow-up**: Preserves `TASK_NUMBER` (no change)

## Workflow-Active Marker

**Path**: `.claude/tmp/workflow-active`
**Purpose**: Suppress Stop hook during mid-workflow orchestrator pauses

The workflow-active marker prevents the Stop hook from resetting the tab color during
orchestrator pauses between subagent calls (the primary cause of mid-workflow color resets).

**Lifecycle**:
1. Written by `update-task-status.sh` preflight (contains task number and timestamp)
2. Stop hook checks for marker: if present, exits silently (no color override)
3. Cleared by `wezterm-preflight-status.sh` Tier 2 on non-lifecycle slash commands
4. `skill-refresh` can also clean stale marker files if needed

This replaces the former signal file mechanism (`lifecycle-signal`) which only suppressed
the first Stop after postflight (not mid-workflow pauses).

## User Variables

| Variable | Purpose | Values |
|----------|---------|--------|
| `TASK_NUMBER` | Task number for tab title | Numeric string or compact multi-task spec (e.g., "792", "7,22-24,59") |
| `CLAUDE_STATUS` | Notification/lifecycle state | See lifecycle states below, or empty |

### CLAUDE_STATUS Lifecycle States

Only lifecycle states are used (no artifact-type vocabulary). Dim-to-bold transitions within
the same hue family indicate workflow progress:

| Value | Trigger | Tab Color | Description |
|-------|---------|-----------|-------------|
| `needs_input` | Stop hook (default) | Gray (#3a3a3a) | Claude awaits user input |
| `researching` | Preflight: research starting | Dim green (#1a3a1a / #607060) | Research in progress |
| `researched` | Postflight: research done | Bright green (#2a5a2a / #d0d0d0) | Research phase completed |
| `planning` | Preflight: planning starting | Dim blue (#1a1a3a / #606070) | Planning in progress |
| `planned` | Postflight: planning done | Bright blue (#2a2a6a / #d0d0d0) | Planning phase completed |
| `implementing` | Preflight: impl starting | Dim gold (#3a3a1a / #707060) | Implementation in progress |
| `completed` | Postflight: impl done | Bright gold (#5a5a2a / #d0d0d0) | Implementation completed |
| `blocked` | Postflight: task blocked | Red (#5a2a2a / #d0d0d0) | Task is blocked |
| (empty) | User views tab / Tier 2 command | Default (#202020) | Normal inactive tab |
| (unknown) | Any unrecognized value | Default (#202020) | Safe degradation |

**Color Format**: `{ bg, fg }` — bg is background, fg is foreground text color.

**Dim-to-Bold Pattern**: Each lifecycle phase uses the same hue family:
- Research: green (dim → bright when researched)
- Planning: blue (dim → bright when planned)
- Implementation: gold (dim → bright when completed)

**Safe Degradation**: Unknown `CLAUDE_STATUS` values fall through to default inactive tab styling.

**Clearing**: CLAUDE_STATUS is cleared (reset to empty) when:
1. The user switches to the tab (via `update-status` handler in wezterm.lua)
2. The user submits a non-lifecycle slash command (via `wezterm-preflight-status.sh` Tier 2)

## Configuration

### Disabling Notifications

Set environment variable before starting Claude Code:

```bash
export WEZTERM_NOTIFY_ENABLED=0
```

### Hook Registration

Hooks are registered in `.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [{
      "matcher": "*",
      "hooks": [{
        "type": "command",
        "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/claude-stop-notify.sh 2>/dev/null || echo '{}'"
      }]
    }],
    "UserPromptSubmit": [{
      "matcher": "*",
      "hooks": [
        {
          "type": "command",
          "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/wezterm-task-number.sh 2>/dev/null || echo '{}'"
        },
        {
          "type": "command",
          "command": "bash \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/wezterm-preflight-status.sh 2>/dev/null || echo '{}'"
        }
      ]
    }]
  }
}
```

## Global Tab Numbering

### Overview

Tab numbers in the WezTerm tab bar use **global creation order** rather than per-window indexes. This ensures tab numbers match TTS announcements, which also use global ordering.

### Algorithm

Tab IDs (`tab.tab_id`) are globally unique integers assigned at creation time. The global position is computed by:

1. Collecting all tab IDs across all windows via `wezterm.mux.all_windows()`
2. Sorting the tab IDs (ascending = creation order)
3. Finding the position of the current tab's ID in the sorted list

```lua
local function get_global_tab_position(current_tab_id)
  local ok, result = pcall(function()
    local all_tab_ids = {}
    for _, mux_window in ipairs(wezterm.mux.all_windows()) do
      for _, mux_tab in ipairs(mux_window:tabs()) do
        table.insert(all_tab_ids, mux_tab:tab_id())
      end
    end
    table.sort(all_tab_ids)
    for i, tid in ipairs(all_tab_ids) do
      if tid == current_tab_id then
        return i
      end
    end
    return nil
  end)
  return ok and result or nil
end
```

### Fallback Behavior

If the global position computation fails (e.g., mux unavailable), the tab number falls back to `tab.tab_index + 1` (per-window index). This ensures tabs always display a number.

## Technical Details

### TTY Access Pattern

Claude Code hooks run with redirected stdio (stdout is a socket to Claude). To emit OSC sequences visible to WezTerm, hooks must write directly to the pane's TTY.

The shared `wezterm-utils.sh` provides this abstraction:

```bash
# Source the shared utilities
source "$SCRIPT_DIR/wezterm-utils.sh"

# Get TTY path (returns empty and exits 1 if unavailable)
PANE_TTY=$(get_pane_tty) || exit_success

# Set a user variable via OSC 1337
set_user_var "CLAUDE_STATUS" "$STATUS" "$PANE_TTY"
```

### OSC Escape Sequence Format

| Sequence | Format | Purpose |
|----------|--------|---------|
| OSC 7 | `ESC ] 7 ; file://hostname/path BEL` | Directory update |
| OSC 1337 | `ESC ] 1337 ; SetUserVar=name=base64value BEL` | User variable |

Values are base64-encoded in OSC 1337 to handle special characters safely.

### WezTerm Handler Location

The `format-tab-title` and `update-status` handlers that consume these variables are in `~/.dotfiles/config/wezterm.lua`.

## Integration with Neovim

When Claude Code runs inside Neovim (via claude-code.nvim), the Neovim autocmds in `~/.config/nvim/lua/neotex/config/autocmds.lua` provide complementary integration:

- **OSC 7**: Neovim emits directory updates on DirChanged, VimEnter, BufEnter
- **Task Number**:
  - **Shell hook**: Handles set/clear logic on `UserPromptSubmit` (workflow vs non-workflow)
  - **Neovim monitor**: Only clears TASK_NUMBER when Claude terminal closes

This separation ensures:
1. Task numbers persist during Claude's responses (no buffer monitoring)
2. Task numbers clear correctly on non-workflow commands (shell hook handles)
3. Task numbers clear when terminal closes (Neovim autocmd handles)

## Related Documentation

- **WezTerm configuration**: `~/.dotfiles/docs/terminal.md`
- **Neovim integration**: `~/.config/nvim/lua/neotex/config/README.md`
- **Hook source files**: `.claude/hooks/wezterm-*.sh`
- **TTS integration**: `.claude/context/project/neovim/guides/tts-stt-integration.md`
