# Telescope.nvim Guide

Fuzzy finder and picker for Neovim.

## Installation

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
    { "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
  },
  config = function()
    local telescope = require("telescope")
    local actions = require("telescope.actions")

    telescope.setup({
      defaults = {
        mappings = {
          i = {
            ["<C-j>"] = actions.move_selection_next,
            ["<C-k>"] = actions.move_selection_previous,
            ["<C-q>"] = actions.send_to_qflist + actions.open_qflist,
          },
        },
        file_ignore_patterns = { "node_modules", ".git" },
      },
    })

    telescope.load_extension("fzf")
  end,
}
```

## Built-in Pickers

### File Pickers

| Command | Description |
|---------|-------------|
| `find_files` | Find files in cwd |
| `git_files` | Git tracked files |
| `oldfiles` | Recently opened files |
| `live_grep` | Search with ripgrep |
| `grep_string` | Grep current word |

### Vim Pickers

| Command | Description |
|---------|-------------|
| `buffers` | Open buffers |
| `command_history` | Command history |
| `search_history` | Search history |
| `marks` | Vim marks |
| `registers` | Vim registers |
| `keymaps` | Key mappings |
| `colorscheme` | Colorschemes |

### Git Pickers

| Command | Description |
|---------|-------------|
| `git_commits` | Commit history |
| `git_bcommits` | Buffer commits |
| `git_branches` | Branches |
| `git_status` | Changed files |
| `git_stash` | Stash entries |

### LSP Pickers

| Command | Description |
|---------|-------------|
| `lsp_references` | References |
| `lsp_definitions` | Definitions |
| `lsp_implementations` | Implementations |
| `lsp_document_symbols` | Document symbols |
| `lsp_workspace_symbols` | Workspace symbols |
| `diagnostics` | LSP diagnostics |

## Configuration

### Defaults

```lua
require("telescope").setup({
  defaults = {
    -- Layout
    layout_strategy = "horizontal",
    layout_config = {
      horizontal = {
        prompt_position = "top",
        preview_width = 0.5,
      },
      width = 0.9,
      height = 0.8,
    },
    sorting_strategy = "ascending",

    -- Appearance
    prompt_prefix = " ",
    selection_caret = " ",
    entry_prefix = "  ",
    borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },

    -- Behavior
    path_display = { "truncate" },
    file_ignore_patterns = { "node_modules", ".git", "%.lock" },

    -- Performance
    vimgrep_arguments = {
      "rg",
      "--color=never",
      "--no-heading",
      "--with-filename",
      "--line-number",
      "--column",
      "--smart-case",
      "--hidden",
    },
  },
})
```

### Picker-Specific Config

```lua
require("telescope").setup({
  pickers = {
    find_files = {
      hidden = true,
      theme = "dropdown",
    },
    buffers = {
      show_all_buffers = true,
      sort_mru = true,
      mappings = {
        i = {
          ["<C-d>"] = "delete_buffer",
        },
      },
    },
    live_grep = {
      additional_args = function()
        return { "--hidden" }
      end,
    },
  },
})
```

## Custom Keymaps

```lua
local builtin = require("telescope.builtin")
local actions = require("telescope.actions")

-- File navigation
vim.keymap.set("n", "<leader>ff", builtin.find_files)
vim.keymap.set("n", "<leader>fg", builtin.live_grep)
vim.keymap.set("n", "<leader>fb", builtin.buffers)
vim.keymap.set("n", "<leader>fh", builtin.help_tags)

-- Git
vim.keymap.set("n", "<leader>gc", builtin.git_commits)
vim.keymap.set("n", "<leader>gb", builtin.git_branches)
vim.keymap.set("n", "<leader>gs", builtin.git_status)

-- LSP
vim.keymap.set("n", "gr", builtin.lsp_references)
vim.keymap.set("n", "gd", builtin.lsp_definitions)
vim.keymap.set("n", "gi", builtin.lsp_implementations)
```

## Extensions

### fzf-native

Fast fuzzy matching:

```lua
telescope.load_extension("fzf")
```

### ui-select

Replace vim.ui.select:

```lua
{
  "nvim-telescope/telescope-ui-select.nvim",
  config = function()
    require("telescope").load_extension("ui-select")
  end,
}
```

### file-browser

File browser extension:

```lua
{
  "nvim-telescope/telescope-file-browser.nvim",
  dependencies = { "nvim-telescope/telescope.nvim" },
  keys = {
    { "<leader>fe", "<cmd>Telescope file_browser<cr>" },
  },
  config = function()
    require("telescope").load_extension("file_browser")
  end,
}
```

## Custom Picker

```lua
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values

local function my_picker()
  pickers.new({}, {
    prompt_title = "My Picker",
    finder = finders.new_table({
      results = { "item1", "item2", "item3" },
    }),
    sorter = conf.generic_sorter({}),
  }):find()
end

vim.keymap.set("n", "<leader>mp", my_picker)
```

## Mappings Reference

### Insert Mode (Default)

| Key | Action |
|-----|--------|
| `<C-n>/<Down>` | Next item |
| `<C-p>/<Up>` | Previous item |
| `<CR>` | Select (default) |
| `<C-x>` | Split |
| `<C-v>` | Vsplit |
| `<C-t>` | Tab |
| `<C-u>` | Scroll preview up |
| `<C-d>` | Scroll preview down |
| `<C-c>/<Esc>` | Close |

### Normal Mode (Default)

| Key | Action |
|-----|--------|
| `j/k` | Navigate |
| `<CR>` | Select |
| `gg/G` | First/last |
| `?` | Show mappings |

## Themes

```lua
-- dropdown
builtin.find_files(require("telescope.themes").get_dropdown())

-- ivy (bottom pane)
builtin.find_files(require("telescope.themes").get_ivy())

-- cursor (small popup at cursor)
builtin.find_files(require("telescope.themes").get_cursor())
```

## Performance Tips

1. Use `fzf-native` extension
2. Add file ignore patterns
3. Use `git_files` for git repos
4. Limit preview for large files
5. Use `follow = true` carefully
