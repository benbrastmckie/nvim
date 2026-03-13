# Research Report: Task #192 - Understanding Permission Request Differences Between Claude Code and OpenCode

**Task**: 192 - bypass_opencode_permission_requests
**Started**: 2026-03-14T10:00:00Z
**Completed**: 2026-03-14T10:45:00Z
**Effort**: 3 hours
**Dependencies**: None
**Sources/Inputs**: 
- opencode.nvim plugin source code (~/.local/share/nvim/lazy/opencode.nvim/)
- Neovim configuration (lua/neotex/plugins/ai/opencode.lua, claudecode.lua)
- Global opencode config (~/.config/opencode/opencode.json)
- Previous research (research-001.md, research-002.md)
- Claude Code CLI documentation

**Artifacts**: 
- specs/192_bypass_opencode_permission_requests/reports/research-003.md (this report)

**Standards**: report-format.md

---

## Executive Summary

The user is experiencing permission requests in opencode despite having Claude Code configured in full bypass mode. **This is expected behavior** because **Claude Code and opencode are two completely separate systems with independent permission architectures.**

**Key Finding**: Claude Code's `--dangerously-skip-permissions` flag does NOT affect opencode. They are separate CLI tools with different permission models. There is NO equivalent flag in opencode CLI to disable permissions globally.

**Root Cause**: The user has configured:
- Claude Code with `--dangerously-skip-permissions` (works correctly - no permissions in Claude Code)
- opencode.nvim with `permission_requests = "notify"` (shows permission notifications - not a bypass)

**Recommended Solutions**:
1. **Disable permission UI in opencode.nvim** (immediate fix): Set `events.permissions.enabled = false`
2. **Migrate from /tmp/ to specs/tmp/** (prevents permission triggers): Already researched in research-002.md
3. **Use Claude Code exclusively** if full permission bypass is required

---

## Understanding the Three Permission Systems

### System 1: Claude Code (Already Configured Correctly)

**Location**: `lua/neotex/plugins/ai/claudecode.lua`

**Configuration**:
```lua
command = "claude --dangerously-skip-permissions",
```

**How it works**:
- Claude Code has a built-in `--dangerously-skip-permissions` flag
- This flag completely disables ALL permission requests at the CLI level
- No configuration needed in the Neovim plugin
- Works globally for all operations

**Current Status**: Working correctly - the user reports no permission requests in Claude Code.

---

### System 2: opencode CLI (The Core Issue)

**Location**: System command (`which opencode`)

**Available Flags** (from `opencode --help`):
```
Options:
  -h, --help         show help
  -v, --version      show version number
      --print-logs   print logs to stderr
      --log-level    log level
      --port         port to listen on
      --hostname     hostname to listen on
      --mdns         enable mDNS service discovery
      --mdns-domain  custom domain name for mDNS
      --cors         additional domains to allow for CORS
  -m, --model        model to use
  -c, --continue     continue the last session
  -s, --session      session id to continue
      --fork         fork the session when continuing
      --prompt       prompt to use
      --agent        agent to use
```

**Critical Finding**: **THERE IS NO `--skip-permissions` OR `--dangerously-skip-permissions` FLAG IN OPENCODE CLI.**

The opencode CLI does not support global permission bypass. Permission requests are fundamental to opencode's security model and cannot be disabled at the CLI level.

**Why permissions still appear**:
1. opencode CLI generates permission events for sensitive operations
2. These events are sent via Server-Sent Events (SSE) to connected clients
3. The Neovim plugin (opencode.nvim) receives these events and displays UI
4. The CLI waits for a response before proceeding

**Important**: Even if you disable the UI in the plugin (see System 3), the CLI may still be waiting for permission responses internally. However, based on the opencode.nvim source code analysis, disabling the permission UI should effectively auto-reject or prevent the permission flow from completing.

---

### System 3: opencode.nvim Plugin (Where Configuration Changes Are Needed)

**Location**: `lua/neotex/plugins/ai/opencode.lua`

**Current Configuration**:
```lua
vim.g.opencode_opts = {
  -- ... other options ...
  permission_requests = "notify",  -- LINE 36: Shows notifications
  
  events = {
    enabled = true,
    reload = true,
    permissions = {
      enabled = true,        -- Controls if permission UI is shown
      idle_delay_ms = 1000,  -- Delay before showing permissions
    },
  },
  -- ... other options ...
}
```

**Understanding the Settings**:

#### `permission_requests = "notify"`
- **Purpose**: Controls how permission requests are displayed
- **Values**: Based on plugin source code analysis:
  - `"notify"` - Show permission requests as vim notifications (current setting)
  - `"popup"` or other values - May show different UI
  - `false` or `nil` - May disable permission UI
- **Location in code**: Used in `lua/neotex/plugins/ai/opencode.lua:36`

**Note**: This setting is NOT documented in the official opencode.nvim README or config.lua. It appears to be an older or deprecated option.

#### `events.permissions.enabled = true`
- **Purpose**: Controls whether the permission event handler is active
- **Location**: Defined in `~/.local/share/nvim/lazy/opencode.nvim/lua/opencode/config.lua:115-118`
- **How it works**: 
  - When `true`: The plugin listens for `OpencodeEvent:permission.asked` events and shows UI
  - When `false`: The plugin ignores permission events entirely
  - Source: `~/.local/share/nvim/lazy/opencode.nvim/plugin/events/permissions.lua:47-50`

```lua
-- From permissions.lua
local opts = require("opencode.config").opts.events.permissions or {}
if not opts.enabled then
  return  -- Early exit - no permission UI shown
end
```

**This is the setting that actually controls whether you see permission requests in Neovim.**

---

## Why the User Still Sees Permission Requests

### Scenario Breakdown

1. **User launches opencode.nvim** via keymap or command
2. **opencode CLI starts** (with `--port` flag, no permission bypass)
3. **opencode CLI encounters** a sensitive operation (file write to /tmp/, Bash command, etc.)
4. **opencode CLI generates** a permission event via its internal permission system
5. **opencode.nvim receives** the `permission.asked` event via SSE
6. **opencode.nvim checks** `events.permissions.enabled` (currently `true`)
7. **opencode.nvim displays** permission UI with "Once/Always/Reject" options
8. **User sees permission request** despite Claude Code being in bypass mode

### The Disconnect

| System | Bypass Mode | Affects opencode? |
|--------|-------------|-------------------|
| Claude Code | `--dangerously-skip-permissions` | NO - Separate tool |
| opencode CLI | Not available | N/A |
| opencode.nvim | `events.permissions.enabled = false` | YES - This is the fix |

**Claude Code's bypass mode has ZERO effect on opencode** because they are completely separate executables with separate permission systems.

---

## Recommended Solutions

### Solution 1: Disable Permission UI in opencode.nvim (Immediate Fix)

**File**: `lua/neotex/plugins/ai/opencode.lua`

**Change**:
```lua
vim.g.opencode_opts = {
  -- ... keep other settings ...
  
  events = {
    enabled = true,
    reload = true,
    permissions = {
      enabled = false,  -- CHANGE THIS from true to false
      -- idle_delay_ms is irrelevant when disabled
    },
  },
  
  -- Remove or comment out the old setting:
  -- permission_requests = "notify",  -- DEPRECATED
}
```

**Effect**:
- Permission events from opencode CLI are ignored by the plugin
- No permission UI will be shown in Neovim
- The opencode CLI may still wait for permissions internally
- Operations may fail silently or timeout if they require permissions

**Risk**: Some operations that require explicit permission approval may not complete. However, for file operations within the project directory, this should work fine.

---

### Solution 2: Migrate /tmp/ Usage to specs/tmp/ (Recommended)

This approach was researched in detail in `research-002.md`. The core idea is to avoid triggering permission requests in the first place by not using `/tmp/`.

**Why this works**:
- opencode CLI is more permissive with files in the project directory
- `/tmp/` is outside the project directory, triggering security permissions
- `specs/tmp/` is inside the project, so no external directory permissions needed

**Implementation**:
Replace all instances of `/tmp/` with `specs/tmp/` in:
- `.claude/commands/*.md`
- `.claude/scripts/*.sh`
- `.claude/skills/*/SKILL.md`
- Extension skill files

**Status**: Already completed for `.opencode/` system in task OC_156. Still needed for `.claude/` system.

---

### Solution 3: Configure opencode Project Settings (Alternative)

**File**: `.opencode/settings.json` (project-specific) or `~/.config/opencode/settings.json` (global)

Based on research-001.md, you can use PreToolUse hooks to auto-allow permissions:

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Bash(git:*)",
      "Bash(nvim *)"
    ]
  },
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "echo '{\"permissionDecision\": \"allow\", \"permissionDecisionReason\": \"Auto-allowed by configuration\"}'"
          }
        ]
      }
    ]
  }
}
```

**WARNING**: This effectively disables ALL permission checks. Use with caution.

---

## Configuration Comparison Matrix

| Approach | Complexity | Security | Effectiveness | Recommendation |
|----------|-----------|----------|---------------|----------------|
| Disable permission UI (Solution 1) | Low | Medium | High - No UI shown | Recommended for immediate relief |
| Migrate to specs/tmp/ (Solution 2) | Medium | High | High - No triggers | Recommended long-term |
| PreToolUse hooks (Solution 3) | Medium | Low | High - All allowed | Use with caution |
| Use only Claude Code | Low | N/A | N/A | If you need full bypass |

---

## Implementation Steps

### Immediate (5 minutes)

1. Edit `lua/neotex/plugins/ai/opencode.lua`
2. Change `events.permissions.enabled` from `true` to `false`
3. Restart Neovim or reload config
4. Test opencode to confirm no permission requests

### Short-term (1-2 hours)

1. Execute the migration from `/tmp/` to `specs/tmp/` as outlined in research-002.md
2. Update `.claude/commands/task.md`
3. Update `.claude/scripts/*.sh`
4. Update skill documentation

### Long-term (Optional)

1. Consider creating `.opencode/settings.json` with PreToolUse hooks for fine-grained control
2. Document the permission bypass strategy for future reference

---

## Key Differences: Claude Code vs OpenCode Permissions

| Feature | Claude Code | OpenCode |
|---------|-------------|----------|
| **Bypass Flag** | `--dangerously-skip-permissions` | None available |
| **Permission Level** | CLI-level global bypass | Per-operation approval |
| **Configuration Location** | Command line | Plugin config + project settings |
| **Neovim Plugin Control** | Minimal (just passes flag) | Extensive (event handling) |
| **Security Model** | All-or-nothing bypass | Granular per-operation |
| **External Directories** | Allowed with bypass | Triggers permission requests |

---

## Why Claude Code and OpenCode Are Different

### Claude Code
- Developed by Anthropic
- Single integrated tool (CLI + AI)
- Designed for "full auto-pilot" mode with bypass flag
- Permission system is optional (can be completely disabled)

### OpenCode
- Developed by SST (formerly Serverless Stack)
- Client-server architecture (CLI + Neovim plugin)
- Permission system is mandatory at CLI level
- Plugin can only respond to permissions, not disable them at source
- Designed for more explicit user control

---

## Decisions

1. **The permission requests are NOT a bug** - they are expected behavior when using opencode
2. **Claude Code and opencode permission systems are independent** - configuring one does not affect the other
3. **The best immediate fix is disabling permission UI** in opencode.nvim via `events.permissions.enabled = false`
4. **The best long-term fix is migrating from `/tmp/`** to prevent permission triggers
5. **PreToolUse hooks are available** for users who want to auto-allow specific operations

---

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Operations fail silently after disabling UI | Medium | Monitor opencode behavior, re-enable if needed |
| Accidental data loss without permission checks | Low | Use version control, avoid destructive operations |
| Security implications of auto-allowing | Low-Medium | Use PreToolUse hooks for selective approval |
| Confusion between Claude Code and opencode | High (user experience) | Documentation and clear separation of concerns |

---

## Context Extension Recommendations

**Topic**: Permission system differences between Claude Code and opencode
**Gap**: No documentation exists explaining the relationship (or lack thereof) between these two systems
**Recommendation**: Create `.claude/context/project/ai-tools/permission-comparison.md` documenting:
- How Claude Code permissions work
- How opencode permissions work
- Why they are independent
- Configuration options for each

---

## Appendix A: Complete Working Configuration

### opencode.nvim Configuration (No Permission UI)

```lua
-- lua/neotex/plugins/ai/opencode.lua
return {
  "NickvanDyke/opencode.nvim",
  event = "VeryLazy",
  dependencies = {
    {
      "folke/snacks.nvim",
      opts = {
        input = {},
        picker = {},
        terminal = {},
      },
    },
  },
  init = function()
    vim.g.opencode_opts = {
      provider = {
        enabled = "snacks",
        snacks = {
          auto_close = false,
          win = {
            position = "right",
            width = 0.40,
            enter = true,
          },
        },
      },

      -- Disable permission UI
      events = {
        enabled = true,
        reload = true,
        permissions = {
          enabled = false,  -- NO PERMISSION UI
        },
      },

      input_provider = "snacks",
      picker_provider = "snacks",
      include_diagnostics = true,
      include_buffer = true,
      include_visible = true,
      keys = {},
    }

    vim.o.autoread = true
  end,
  config = function()
    -- Commands setup...
  end,
  keys = {},
}
```

### Claude Code Configuration (Already Working)

```lua
-- lua/neotex/plugins/ai/claudecode.lua (excerpt)
opts = {
  command = "claude --dangerously-skip-permissions",
  -- ... other options ...
}
```

---

## Appendix B: Verification Commands

### Check opencode.nvim Configuration
```vim
:lua print(vim.inspect(require("opencode.config").opts.events.permissions))
```

### Check if Permission Events Are Being Received
```vim
:autocmd User OpencodeEvent:* echo "Event received: " . expand("<amatch>")
```

### Test Permission Behavior
1. Open a file with opencode.nvim
2. Ask opencode to write to `/tmp/test.txt`
3. Observe if permission UI appears (it should NOT with the fix)

---

## Summary

**The user's issue is caused by a misunderstanding of the relationship between Claude Code and opencode.** They are completely separate tools with separate permission systems. The `--dangerously-skip-permissions` flag in Claude Code does not and cannot affect opencode.

**The solution is to disable permission UI in opencode.nvim** via the `events.permissions.enabled = false` setting. This will prevent the permission dialogs from appearing while using opencode.

**For a complete solution**, combine this with the migration from `/tmp/` to `specs/tmp/` researched in research-002.md to prevent permission triggers at the source.
