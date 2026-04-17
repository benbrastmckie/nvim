# Neovim Plugin Ecosystem

Overview of the Neovim plugin ecosystem and common plugins.

## Plugin Manager: lazy.nvim

The recommended plugin manager for modern Neovim configurations.

### Key Features
- Automatic lazy-loading
- Lockfile for reproducibility (lazy-lock.json)
- Built-in profiler
- UI for plugin management (`:Lazy`)
- Automatic compilation

### Installation

```lua
-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
```

## Essential Plugin Categories

### Completion

| Plugin | Purpose |
|--------|---------|
| nvim-cmp | Completion engine |
| cmp-nvim-lsp | LSP completion source |
| cmp-buffer | Buffer word completion |
| cmp-path | Path completion |
| LuaSnip | Snippet engine |
| cmp_luasnip | Snippet completion source |

### LSP

| Plugin | Purpose |
|--------|---------|
| nvim-lspconfig | LSP configuration |
| mason.nvim | LSP/DAP/linter installer |
| mason-lspconfig.nvim | Bridge between mason and lspconfig |
| none-ls.nvim | Inject diagnostics, formatting |

### Treesitter

| Plugin | Purpose |
|--------|---------|
| nvim-treesitter | Treesitter integration |
| nvim-treesitter-textobjects | Custom text objects |
| nvim-ts-autotag | Auto close/rename HTML tags |
| nvim-ts-context-commentstring | Context-aware commenting |

### UI/Navigation

| Plugin | Purpose |
|--------|---------|
| telescope.nvim | Fuzzy finder |
| nvim-tree.lua | File explorer |
| lualine.nvim | Statusline |
| which-key.nvim | Keybinding hints |
| bufferline.nvim | Buffer tabs |

### Editing

| Plugin | Purpose |
|--------|---------|
| nvim-autopairs | Auto close brackets |
| Comment.nvim | Code commenting |
| nvim-surround | Surround text objects |
| indent-blankline.nvim | Indent guides |

### Git

| Plugin | Purpose |
|--------|---------|
| gitsigns.nvim | Git decorations |
| fugitive.vim | Git commands |
| diffview.nvim | Diff viewer |

## Plugin Specification Basics

```lua
-- Basic spec
{ "username/repo" }

-- With version pinning
{ "username/repo", tag = "v1.0.0" }

-- With configuration
{
  "username/repo",
  opts = {
    -- Plugin options
  },
}

-- With lazy loading
{
  "username/repo",
  event = "BufReadPre",
  config = function()
    require("plugin").setup()
  end,
}
```

## Common Lazy Loading Events

| Event | When |
|-------|------|
| `VeryLazy` | After UI is ready |
| `BufReadPre` | Before reading a buffer |
| `BufReadPost` | After reading a buffer |
| `InsertEnter` | Entering insert mode |
| `CmdlineEnter` | Entering command-line mode |

## Plugin Dependencies

```lua
{
  "username/plugin",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
  },
}
```

## Colorschemes

Popular colorscheme plugins:
- tokyonight.nvim
- catppuccin/nvim
- rose-pine/neovim
- folke/tokyonight.nvim
- rebelot/kanagawa.nvim

```lua
{
  "folke/tokyonight.nvim",
  lazy = false, -- Load during startup
  priority = 1000, -- Load before other plugins
  config = function()
    vim.cmd.colorscheme("tokyonight")
  end,
}
```

## Plugin Debugging

```vim
:Lazy profile    " View load times
:Lazy log        " View update log
:Lazy health     " Check plugin health
```
