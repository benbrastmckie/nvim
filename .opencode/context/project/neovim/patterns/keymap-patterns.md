# Keymap Patterns

Patterns for defining keybindings in Neovim.

## vim.keymap.set

The modern, recommended API:

```lua
-- Basic usage
vim.keymap.set("n", "<leader>w", ":write<CR>", { desc = "Save file" })

-- With options
vim.keymap.set("n", "<leader>q", ":quit<CR>", {
  silent = true,     -- Don't show command
  noremap = true,    -- Don't remap (default true)
  desc = "Quit",     -- Description for which-key
})
```

## Mode Strings

| Mode | Description |
|------|-------------|
| `"n"` | Normal mode |
| `"i"` | Insert mode |
| `"v"` | Visual mode |
| `"x"` | Visual block mode |
| `"s"` | Select mode |
| `"o"` | Operator-pending |
| `"t"` | Terminal mode |
| `"c"` | Command-line mode |
| `""` | All modes |

Multiple modes:
```lua
vim.keymap.set({"n", "v"}, "<leader>y", '"+y')
```

## Callback Functions

```lua
-- Function callback
vim.keymap.set("n", "<leader>f", function()
  vim.lsp.buf.format()
end, { desc = "Format buffer" })

-- With arguments
vim.keymap.set("n", "<leader>t", function()
  local word = vim.fn.expand("<cword>")
  print("Word under cursor: " .. word)
end)
```

## Buffer-Local Keymaps

```lua
-- In an autocmd or config
vim.keymap.set("n", "<leader>x", function()
  -- action
end, { buffer = true })  -- current buffer

-- Specific buffer
vim.keymap.set("n", "<leader>x", function()
  -- action
end, { buffer = bufnr })
```

## Expression Mappings

```lua
vim.keymap.set("i", "<Tab>", function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true })
```

## Leader Key

```lua
-- Set leader key (do this before other keymaps)
vim.g.mapleader = " "
vim.g.maplocalleader = ","

-- Then use <leader> in mappings
vim.keymap.set("n", "<leader>ff", ":Telescope find_files<CR>")
```

## Common Keymap Groups

### File Operations

```lua
vim.keymap.set("n", "<leader>w", ":write<CR>", { desc = "Save" })
vim.keymap.set("n", "<leader>q", ":quit<CR>", { desc = "Quit" })
vim.keymap.set("n", "<leader>x", ":wq<CR>", { desc = "Save and quit" })
```

### Buffer Navigation

```lua
vim.keymap.set("n", "<S-h>", ":bprevious<CR>", { desc = "Previous buffer" })
vim.keymap.set("n", "<S-l>", ":bnext<CR>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete buffer" })
```

### Window Navigation

```lua
vim.keymap.set("n", "<C-h>", "<C-w>h", { desc = "Window left" })
vim.keymap.set("n", "<C-j>", "<C-w>j", { desc = "Window down" })
vim.keymap.set("n", "<C-k>", "<C-w>k", { desc = "Window up" })
vim.keymap.set("n", "<C-l>", "<C-w>l", { desc = "Window right" })
```

### Window Resizing

```lua
vim.keymap.set("n", "<C-Up>", ":resize +2<CR>")
vim.keymap.set("n", "<C-Down>", ":resize -2<CR>")
vim.keymap.set("n", "<C-Left>", ":vertical resize -2<CR>")
vim.keymap.set("n", "<C-Right>", ":vertical resize +2<CR>")
```

### Better Defaults

```lua
-- Move selected lines up/down
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")

-- Keep cursor centered
vim.keymap.set("n", "<C-d>", "<C-d>zz")
vim.keymap.set("n", "<C-u>", "<C-u>zz")
vim.keymap.set("n", "n", "nzzzv")
vim.keymap.set("n", "N", "Nzzzv")

-- Don't overwrite register on paste in visual mode
vim.keymap.set("x", "<leader>p", '"_dP')
```

## which-key Integration

```lua
{
  "folke/which-key.nvim",
  config = function()
    local wk = require("which-key")

    wk.register({
      ["<leader>f"] = { name = "+file" },
      ["<leader>ff"] = { "<cmd>Telescope find_files<cr>", "Find files" },
      ["<leader>fg"] = { "<cmd>Telescope live_grep<cr>", "Live grep" },
    })
  end,
}
```

## Deleting Keymaps

```lua
-- Delete a keymap
vim.keymap.del("n", "<leader>w")

-- Delete buffer-local keymap
vim.keymap.del("n", "<leader>w", { buffer = bufnr })
```

## Keymap Utility Module

```lua
-- lua/utils/keymap.lua
local M = {}

function M.map(mode, lhs, rhs, opts)
  opts = opts or {}
  opts.silent = opts.silent ~= false
  vim.keymap.set(mode, lhs, rhs, opts)
end

function M.nmap(lhs, rhs, opts)
  M.map("n", lhs, rhs, opts)
end

return M
```
