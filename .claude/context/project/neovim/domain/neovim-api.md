# Neovim API Reference

Core Neovim Lua API patterns.

## vim.api

Low-level Neovim API access:

### Buffer Operations

```lua
-- Get current buffer
local bufnr = vim.api.nvim_get_current_buf()

-- Get buffer lines
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

-- Set buffer lines
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {"line1", "line2"})

-- Get/set buffer option
local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

-- Buffer-local variable
vim.api.nvim_buf_set_var(bufnr, "my_var", "value")
local val = vim.api.nvim_buf_get_var(bufnr, "my_var")
```

### Window Operations

```lua
-- Get current window
local winnr = vim.api.nvim_get_current_win()

-- Get window dimensions
local width = vim.api.nvim_win_get_width(winnr)
local height = vim.api.nvim_win_get_height(winnr)

-- Set cursor position
vim.api.nvim_win_set_cursor(winnr, {row, col})

-- Get cursor position
local pos = vim.api.nvim_win_get_cursor(winnr)
```

### Command Execution

```lua
-- Execute Ex command
vim.api.nvim_command("write")
vim.cmd("write") -- shorthand

-- Execute multiple commands
vim.cmd([[
  set number
  set relativenumber
]])
```

### Keymaps

```lua
-- Set keymap
vim.api.nvim_set_keymap("n", "<leader>w", ":write<CR>", {
  noremap = true,
  silent = true,
})

-- Buffer-local keymap
vim.api.nvim_buf_set_keymap(bufnr, "n", "<leader>w", ":write<CR>", {
  noremap = true,
  silent = true,
})
```

## vim.keymap

Modern keymap API (recommended):

```lua
-- Basic mapping
vim.keymap.set("n", "<leader>w", ":write<CR>")

-- With options
vim.keymap.set("n", "<leader>w", ":write<CR>", {
  silent = true,
  desc = "Save file",
})

-- Function callback
vim.keymap.set("n", "<leader>f", function()
  vim.lsp.buf.format()
end, { desc = "Format buffer" })

-- Multiple modes
vim.keymap.set({"n", "v"}, "<leader>y", '"+y', { desc = "Yank to clipboard" })

-- Buffer-local
vim.keymap.set("n", "<leader>x", function()
  -- buffer action
end, { buffer = bufnr })

-- Delete keymap
vim.keymap.del("n", "<leader>w")
```

## vim.opt

Options interface:

```lua
-- Set options
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

-- List options (append/prepend/remove)
vim.opt.wildignore:append("*.pyc")
vim.opt.path:prepend("**")
vim.opt.shortmess:remove("F")

-- Get option value
local ts = vim.opt.tabstop:get()
```

## vim.fn

Vimscript function access:

```lua
-- Call vimscript function
local home = vim.fn.expand("~")
local exists = vim.fn.filereadable("/path/to/file")
local result = vim.fn.system("ls -la")

-- User input
local input = vim.fn.input("Enter name: ")

-- Check feature
if vim.fn.has("nvim-0.9") == 1 then
  -- Neovim 0.9+ code
end
```

## vim.notify

Notifications:

```lua
-- Basic notification
vim.notify("Hello world")

-- With level
vim.notify("Error occurred", vim.log.levels.ERROR)
vim.notify("Warning", vim.log.levels.WARN)
vim.notify("Info", vim.log.levels.INFO)
vim.notify("Debug", vim.log.levels.DEBUG)
```

## vim.schedule

Defer execution:

```lua
-- Run after current execution context
vim.schedule(function()
  vim.notify("Scheduled message")
end)

-- Defer with delay (ms)
vim.defer_fn(function()
  vim.notify("After 1 second")
end, 1000)
```

## Autocommands

```lua
-- Create autocommand
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.lua",
  callback = function()
    vim.lsp.buf.format()
  end,
})

-- With group
local group = vim.api.nvim_create_augroup("MyGroup", { clear = true })
vim.api.nvim_create_autocmd("BufEnter", {
  group = group,
  pattern = "*",
  callback = function(args)
    -- args.buf, args.file, args.match available
  end,
})
```

## User Commands

```lua
vim.api.nvim_create_user_command("MyCommand", function(opts)
  -- opts.args, opts.fargs, opts.bang, etc.
  print("Args: " .. opts.args)
end, {
  nargs = "*",
  desc = "My custom command",
})
```

## Highlights

```lua
-- Set highlight group
vim.api.nvim_set_hl(0, "MyHighlight", {
  fg = "#ffffff",
  bg = "#000000",
  bold = true,
})

-- Link to existing group
vim.api.nvim_set_hl(0, "MyHighlight", { link = "Comment" })
```

## Useful vim.* modules

| Module | Purpose |
|--------|---------|
| `vim.fs` | Filesystem utilities |
| `vim.json` | JSON encode/decode |
| `vim.loop` | libuv event loop (uv) |
| `vim.treesitter` | Treesitter integration |
| `vim.ui` | UI utilities (input, select) |
| `vim.tbl_*` | Table utilities |
