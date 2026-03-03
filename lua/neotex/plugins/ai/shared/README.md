# Shared AI Infrastructure

This directory contains shared infrastructure modules that power both Claude and OpenCode pickers.

## Directory Structure

```
shared/
├── extensions/          # Shared extension management system
│   ├── config.lua      # Extension system configuration (claude/opencode presets)
│   ├── init.lua        # Extension manager factory
│   ├── loader.lua      # File copy/remove operations
│   ├── manifest.lua    # Manifest parsing and discovery
│   ├── merge.lua       # Config file merge operations
│   └── state.lua       # Extension state tracking
└── picker/             # Shared picker configuration
    ├── config.lua      # Picker configuration presets
    └── config_spec.lua # Tests for picker config
```

## Shared Picker Architecture

The picker is parameterized to support both `.claude/` and `.opencode/` directory structures.

### Configuration Presets

```lua
local config = require("neotex.plugins.ai.shared.picker.config")

-- Claude configuration
local claude_config = config.claude()

-- OpenCode configuration
local opencode_config = config.opencode()
```

### Key Differences

| Aspect | Claude | OpenCode |
|--------|--------|----------|
| Base directory | `.claude` | `.opencode` |
| Agents location | `agents/` | `agent/subagents/` |
| Settings file | `settings.local.json` | `settings.json` |
| Config file | `CLAUDE.md` | `OPENCODE.md` |
| Hooks | Supported | Not used |

## Shared Extensions System

The extension system allows domain-specific capabilities (lean, latex, typst, etc.) to be loaded on-demand.

### Using Extensions

```lua
-- Claude extensions
local claude_ext = require("neotex.plugins.ai.claude.extensions")
claude_ext.load("lean", { confirm = true })

-- OpenCode extensions
local opencode_ext = require("neotex.plugins.ai.opencode.extensions")
opencode_ext.load("lean", { confirm = true })
```

### Extension Locations

- Claude: `~/.config/nvim/.claude/extensions/`
- OpenCode: `~/.config/nvim/.opencode/extensions/`

## Keymaps

| Keymap | Mode | Command | Description |
|--------|------|---------|-------------|
| `<leader>ac` | Normal | `:ClaudeCommands` | Claude artifacts picker |
| `<leader>ac` | Visual | (function) | Send selection to Claude with prompt |
| `<leader>ao` | Normal | `:OpencodeCommands` | OpenCode artifacts picker |
| `<leader>ao` | Visual | (function) | Send selection to OpenCode with prompt |

**Note**: Extension pickers are available via commands (`:ClaudeExtensions`, `:OpencodeExtensions`) but no longer have dedicated keymaps.
