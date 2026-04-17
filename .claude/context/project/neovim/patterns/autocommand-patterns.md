# Autocommand Patterns

Patterns for creating autocommands in Neovim.

## Basic Autocommand

```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    -- Action before saving
  end,
})
```

## With Augroup

Always use groups to prevent duplicate autocommands:

```lua
local group = vim.api.nvim_create_augroup("MyAutoGroup", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = group,
  pattern = "*.lua",
  callback = function()
    vim.lsp.buf.format()
  end,
})
```

## Callback Arguments

```lua
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function(args)
    -- args.buf - buffer number
    -- args.file - file path
    -- args.match - matched pattern
    -- args.event - event name
    -- args.id - autocommand id

    print("Entered: " .. args.file)
  end,
})
```

## Common Events

### Buffer Events

| Event | When |
|-------|------|
| `BufEnter` | After entering a buffer |
| `BufLeave` | Before leaving a buffer |
| `BufRead` / `BufReadPost` | After reading a file |
| `BufWrite` / `BufWritePre` | Before writing a file |
| `BufWritePost` | After writing a file |
| `BufNew` | After creating a new buffer |
| `BufDelete` | Before deleting a buffer |

### File Events

| Event | When |
|-------|------|
| `FileType` | Filetype is set |
| `BufNewFile` | Creating new file |
| `BufReadPre` | Before reading file |

### Window Events

| Event | When |
|-------|------|
| `WinEnter` | After entering window |
| `WinLeave` | Before leaving window |
| `WinNew` | After creating window |
| `WinClosed` | After closing window |

### Other Events

| Event | When |
|-------|------|
| `VimEnter` | After Neovim startup |
| `VimLeave` | Before Neovim exit |
| `InsertEnter` | Entering insert mode |
| `InsertLeave` | Leaving insert mode |
| `CursorHold` | Cursor idle (updatetime) |
| `TextChanged` | Text changed in normal mode |
| `TextChangedI` | Text changed in insert mode |

## Patterns

### File Patterns

```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.lua",  -- Single pattern
  callback = function() end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.lua", "*.py" },  -- Multiple patterns
  callback = function() end,
})
```

### Buffer Patterns

```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  buffer = 0,  -- Current buffer only
  callback = function() end,
})
```

## Common Autocommand Patterns

### Format on Save

```lua
local format_group = vim.api.nvim_create_augroup("FormatOnSave", { clear = true })

vim.api.nvim_create_autocmd("BufWritePre", {
  group = format_group,
  pattern = { "*.lua", "*.py", "*.js", "*.ts" },
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})
```

### Highlight on Yank

```lua
vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("HighlightYank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
})
```

### Remove Trailing Whitespace

```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  group = vim.api.nvim_create_augroup("TrimWhitespace", { clear = true }),
  pattern = "*",
  callback = function()
    local save_cursor = vim.fn.getpos(".")
    vim.cmd([[%s/\s\+$//e]])
    vim.fn.setpos(".", save_cursor)
  end,
})
```

### Restore Cursor Position

```lua
vim.api.nvim_create_autocmd("BufReadPost", {
  group = vim.api.nvim_create_augroup("RestoreCursor", { clear = true }),
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})
```

### Auto-resize Splits

```lua
vim.api.nvim_create_autocmd("VimResized", {
  group = vim.api.nvim_create_augroup("AutoResize", { clear = true }),
  callback = function()
    vim.cmd("tabdo wincmd =")
  end,
})
```

### Filetype-Specific Settings

```lua
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("FileTypeSettings", { clear = true }),
  pattern = "python",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4
    vim.opt_local.expandtab = true
  end,
})
```

### Check for External Changes

```lua
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  group = vim.api.nvim_create_augroup("CheckTime", { clear = true }),
  callback = function()
    vim.cmd("checktime")
  end,
})
```

## Deleting Autocommands

```lua
-- Delete by group
vim.api.nvim_del_augroup_by_name("MyAutoGroup")

-- Delete by id
local id = vim.api.nvim_create_autocmd(...)
vim.api.nvim_del_autocmd(id)
```

## One-Shot Autocommand

```lua
vim.api.nvim_create_autocmd("BufEnter", {
  once = true,  -- Only fires once
  callback = function()
    -- One-time setup
  end,
})
```
