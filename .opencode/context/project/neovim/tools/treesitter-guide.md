# Tree-sitter Guide for Neovim

Native tree-sitter integration in Neovim.

## Installation

```lua
{
  "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("nvim-treesitter.configs").setup({
      ensure_installed = {
        "lua", "vim", "vimdoc",
        "javascript", "typescript",
        "python", "rust", "go",
        "html", "css", "json",
        "markdown", "markdown_inline",
      },
      auto_install = true,
      highlight = {
        enable = true,
      },
    })
  end,
}
```

## Core Features

### Syntax Highlighting

```lua
highlight = {
  enable = true,
  disable = { "latex" },  -- Disable for specific languages
  additional_vim_regex_highlighting = false,
}
```

### Incremental Selection

```lua
incremental_selection = {
  enable = true,
  keymaps = {
    init_selection = "<CR>",
    node_incremental = "<CR>",
    scope_incremental = "<S-CR>",
    node_decremental = "<BS>",
  },
}
```

### Indentation

```lua
indent = {
  enable = true,
}
```

## Text Objects

With `nvim-treesitter-textobjects`:

```lua
{
  "nvim-treesitter/nvim-treesitter-textobjects",
  dependencies = "nvim-treesitter/nvim-treesitter",
  config = function()
    require("nvim-treesitter.configs").setup({
      textobjects = {
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            ["]m"] = "@function.outer",
            ["]]"] = "@class.outer",
          },
          goto_previous_start = {
            ["[m"] = "@function.outer",
            ["[["] = "@class.outer",
          },
        },
        swap = {
          enable = true,
          swap_next = {
            ["<leader>a"] = "@parameter.inner",
          },
          swap_previous = {
            ["<leader>A"] = "@parameter.inner",
          },
        },
      },
    })
  end,
}
```

## Commands

| Command | Description |
|---------|-------------|
| `:TSInstall {lang}` | Install parser |
| `:TSUninstall {lang}` | Uninstall parser |
| `:TSUpdate` | Update all parsers |
| `:TSInstallInfo` | List installed parsers |
| `:TSModuleInfo` | List enabled modules |
| `:InspectTree` | View syntax tree |

## Folding

```lua
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldlevel = 99
vim.opt.foldlevelstart = 99
```

## Context (Show Current Function)

```lua
{
  "nvim-treesitter/nvim-treesitter-context",
  dependencies = "nvim-treesitter/nvim-treesitter",
  config = function()
    require("treesitter-context").setup({
      enable = true,
      max_lines = 3,
    })
  end,
}
```

## Auto Tag

For HTML/JSX tag auto-close:

```lua
{
  "windwp/nvim-ts-autotag",
  dependencies = "nvim-treesitter/nvim-treesitter",
  event = "InsertEnter",
  config = function()
    require("nvim-ts-autotag").setup()
  end,
}
```

## Rainbow Delimiters

Colorize matching brackets:

```lua
{
  "HiPhish/rainbow-delimiters.nvim",
  dependencies = "nvim-treesitter/nvim-treesitter",
  config = function()
    require("rainbow-delimiters.setup").setup({})
  end,
}
```

## Custom Queries

Define custom text objects:

```lua
-- queries/lua/textobjects.scm
(function_declaration
  body: (block) @function.inner) @function.outer

(for_statement
  body: (block) @loop.inner) @loop.outer
```

## Treesitter Playground

Explore syntax trees:

```lua
{
  "nvim-treesitter/playground",
  cmd = "TSPlaygroundToggle",
  dependencies = "nvim-treesitter/nvim-treesitter",
}
```

Commands:
- `:TSPlaygroundToggle` - Open tree view
- `:TSHighlightCapturesUnderCursor` - Show highlight groups

## Performance

```lua
-- Disable for large files
highlight = {
  enable = true,
  disable = function(lang, buf)
    local max_filesize = 100 * 1024 -- 100 KB
    local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
    if ok and stats and stats.size > max_filesize then
      return true
    end
  end,
}
```

## Injections

Handle embedded languages:

```lua
-- queries/markdown/injections.scm
(fenced_code_block
  (info_string
    (language) @_lang)
  (code_fence_content) @injection.content
  (#set! injection.language @_lang))
```

## Debugging

```lua
-- Check parser health
:checkhealth nvim-treesitter

-- View current tree
:InspectTree

-- Verify language
:lua print(vim.treesitter.get_parser():lang())

-- List captures at cursor
:TSHighlightCapturesUnderCursor
```
