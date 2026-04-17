# lazy.nvim Plugin Specification

Patterns for defining plugins with lazy.nvim.

## Basic Specifications

### Minimal Spec

```lua
{ "username/repo" }
```

### With Options

```lua
{
  "username/repo",
  opts = {
    option1 = "value",
    option2 = true,
  },
}
```

### With Config Function

```lua
{
  "username/repo",
  config = function()
    require("plugin").setup({
      option1 = "value",
    })
  end,
}
```

## Lazy Loading

### By Event

```lua
{
  "username/repo",
  event = "BufReadPre",  -- Single event
}

{
  "username/repo",
  event = { "BufReadPre", "BufNewFile" },  -- Multiple events
}
```

Common events:
- `VeryLazy` - After UI loads
- `BufReadPre` / `BufReadPost` - Buffer reading
- `InsertEnter` - Insert mode
- `CmdlineEnter` - Command line

### By Command

```lua
{
  "username/repo",
  cmd = "PluginCommand",  -- Single command
}

{
  "username/repo",
  cmd = { "Cmd1", "Cmd2" },  -- Multiple commands
}
```

### By Filetype

```lua
{
  "username/repo",
  ft = "python",  -- Single filetype
}

{
  "username/repo",
  ft = { "python", "lua" },  -- Multiple filetypes
}
```

### By Keys

```lua
{
  "username/repo",
  keys = {
    { "<leader>f", "<cmd>PluginCommand<cr>", desc = "Plugin action" },
  },
}
```

## Dependencies

```lua
{
  "username/repo",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
    {
      "another/plugin",
      config = function()
        -- Dependency config
      end,
    },
  },
}
```

## Version Control

### Pin to Version

```lua
{
  "username/repo",
  tag = "v1.0.0",
}

{
  "username/repo",
  version = "*",  -- Latest stable
}

{
  "username/repo",
  commit = "abc123",
}
```

### Branch

```lua
{
  "username/repo",
  branch = "develop",
}
```

## Build Steps

```lua
{
  "username/repo",
  build = "make",  -- Shell command
}

{
  "username/repo",
  build = ":TSUpdate",  -- Neovim command
}

{
  "username/repo",
  build = function()
    -- Lua function
  end,
}
```

## Priority and Loading Order

```lua
{
  "username/colorscheme",
  lazy = false,      -- Load at startup
  priority = 1000,   -- Load before other plugins
}
```

## Conditional Loading

```lua
{
  "username/repo",
  cond = function()
    return vim.fn.executable("node") == 1
  end,
}

{
  "username/repo",
  enabled = vim.fn.has("nvim-0.9") == 1,
}
```

## Init Function

Run before plugin loads (for setting globals):

```lua
{
  "username/repo",
  init = function()
    vim.g.plugin_option = "value"
  end,
}
```

## Complete Example

```lua
{
  "nvim-telescope/telescope.nvim",
  tag = "0.1.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    {
      "nvim-telescope/telescope-fzf-native.nvim",
      build = "make",
    },
  },
  cmd = "Telescope",
  keys = {
    { "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
    { "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
    { "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "Buffers" },
  },
  opts = {
    defaults = {
      file_ignore_patterns = { "node_modules", ".git" },
    },
  },
  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)
    telescope.load_extension("fzf")
  end,
}
```

## Organizing Plugins

### Single File

```lua
-- lua/plugins/init.lua
return {
  { "plugin1" },
  { "plugin2" },
}
```

### Multiple Files

```lua
-- lua/plugins/ui.lua
return {
  { "colorscheme" },
  { "statusline" },
}

-- lua/plugins/editor.lua
return {
  { "autopairs" },
  { "comment" },
}
```

lazy.nvim automatically merges all files in the plugins directory.
