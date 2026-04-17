# lazy.nvim Guide

Comprehensive guide to the lazy.nvim plugin manager.

## Installation

```lua
-- Bootstrap lazy.nvim in init.lua
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
```

## Basic Setup

```lua
require("lazy").setup({
  spec = {
    -- Import plugins from lua/plugins/
    { import = "plugins" },
  },
  defaults = {
    lazy = true,  -- Lazy load by default
  },
  install = {
    colorscheme = { "tokyonight" },
  },
  checker = {
    enabled = true,  -- Auto-check for updates
  },
})
```

## Plugin Directory Structure

```
lua/plugins/
├── init.lua          # Can return main plugin list
├── ui.lua            # UI-related plugins
├── editor.lua        # Editor enhancements
├── lsp.lua           # LSP configuration
├── treesitter.lua    # Treesitter configuration
└── git.lua           # Git plugins
```

Each file returns a table of plugin specs.

## Commands

| Command | Description |
|---------|-------------|
| `:Lazy` | Open lazy.nvim UI |
| `:Lazy sync` | Install/update/clean plugins |
| `:Lazy update` | Update plugins |
| `:Lazy install` | Install missing plugins |
| `:Lazy clean` | Remove unused plugins |
| `:Lazy check` | Check for updates |
| `:Lazy restore` | Restore plugins from lockfile |
| `:Lazy profile` | View load times |
| `:Lazy log` | View recent changes |
| `:Lazy health` | Run health checks |

## Lazy Loading Strategies

### Event-Based Loading

```lua
{
  "plugin/name",
  event = "VeryLazy",  -- After startup
}

{
  "plugin/name",
  event = { "BufReadPost", "BufNewFile" },  -- File events
}

{
  "plugin/name",
  event = "InsertEnter",  -- Mode events
}
```

### Command-Based Loading

```lua
{
  "plugin/name",
  cmd = "PluginCommand",
}
```

### Filetype-Based Loading

```lua
{
  "plugin/name",
  ft = { "lua", "python" },
}
```

### Key-Based Loading

```lua
{
  "plugin/name",
  keys = {
    { "<leader>f", desc = "Finder" },
    { "<leader>g", mode = { "n", "v" }, desc = "Grep" },
  },
}
```

## Configuration Options

### opts vs config

```lua
-- Simple: opts table passed to setup()
{
  "plugin/name",
  opts = {
    option = "value",
  },
}

-- Advanced: full control with config
{
  "plugin/name",
  config = function(_, opts)
    require("plugin").setup(opts)
    -- Additional configuration
  end,
}
```

### init Function

Runs before plugin loads (for globals):

```lua
{
  "plugin/name",
  init = function()
    vim.g.plugin_setting = "value"
  end,
}
```

### build Function

Runs after install/update:

```lua
{
  "plugin/name",
  build = "make",  -- Shell command
}

{
  "plugin/name",
  build = ":TSUpdate",  -- Vim command
}

{
  "plugin/name",
  build = function()
    -- Lua function
  end,
}
```

## Dependencies

```lua
{
  "main-plugin",
  dependencies = {
    "dep1",
    {
      "dep2",
      opts = { ... },
    },
  },
}
```

Dependencies are loaded before the main plugin.

## Version Control

```lua
-- Latest stable
{ "plugin/name", version = "*" }

-- Specific version
{ "plugin/name", tag = "v1.0.0" }

-- Specific commit
{ "plugin/name", commit = "abc123" }

-- Branch
{ "plugin/name", branch = "develop" }
```

## Lockfile

`lazy-lock.json` tracks exact versions:

```json
{
  "plugin-name": { "branch": "main", "commit": "abc123" }
}
```

Commands:
- `:Lazy restore` - Install versions from lockfile
- Commit `lazy-lock.json` for reproducibility

## Priority and Loading Order

```lua
{
  "colorscheme-plugin",
  lazy = false,     -- Load at startup
  priority = 1000,  -- Load first
}
```

Higher priority = loads earlier.

## Conditional Loading

```lua
-- Based on condition
{
  "plugin/name",
  cond = function()
    return vim.fn.executable("node") == 1
  end,
}

-- Simple boolean
{
  "plugin/name",
  enabled = not vim.g.vscode,
}
```

## Local Development

```lua
{
  dir = "~/projects/my-plugin",
  name = "my-plugin",
  dev = true,
}
```

Or use dev.path:

```lua
require("lazy").setup({
  dev = {
    path = "~/projects",
  },
})
```

## Performance Tips

1. Use `event = "VeryLazy"` for non-essential plugins
2. Lazy load by filetype when possible
3. Use `cmd` for rarely used plugins
4. Profile with `:Lazy profile`
5. Keep dependencies minimal

## Debugging

```lua
-- Check if plugin is loaded
require("lazy.core.loader").get_status("plugin-name")

-- Force load a plugin
require("lazy").load({ plugins = { "plugin-name" } })

-- View plugin spec
:lua print(vim.inspect(require("lazy.core.config").spec.plugins["name"]))
```

## Migration from Other Managers

### From packer.nvim

| packer | lazy.nvim |
|--------|-----------|
| `use` | Table entry |
| `run` | `build` |
| `requires` | `dependencies` |
| `ft` | `ft` |
| `cmd` | `cmd` |
| `after` | `dependencies` |
| `config` | `config` or `opts` |
