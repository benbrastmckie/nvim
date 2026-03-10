# Filetype Plugin Template

Boilerplate templates for after/ftplugin/ files.

## Basic Template

```lua
-- after/ftplugin/{filetype}.lua

-- Guard against multiple loads
if vim.b.did_user_ftplugin then
  return
end
vim.b.did_user_ftplugin = true

-- Local options
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true

-- Buffer-local keymaps
vim.keymap.set("n", "<leader>r", function()
  vim.cmd("!run-command %")
end, { buffer = true, desc = "Run file" })
```

## Language-Specific Templates

### lua.lua

```lua
-- after/ftplugin/lua.lua

if vim.b.did_user_ftplugin then
  return
end
vim.b.did_user_ftplugin = true

-- Neovim Lua development settings
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true

-- Treesitter-based folding
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt_local.foldlevel = 99

-- Quick reload current module
vim.keymap.set("n", "<leader>lr", function()
  local file = vim.fn.expand("%:p")
  local module = file:match("lua/(.+)%.lua$")
  if module then
    module = module:gsub("/", ".")
    package.loaded[module] = nil
    require(module)
    vim.notify("Reloaded: " .. module)
  end
end, { buffer = true, desc = "Reload Lua module" })
```

### python.lua

```lua
-- after/ftplugin/python.lua

if vim.b.did_user_ftplugin then
  return
end
vim.b.did_user_ftplugin = true

-- PEP 8 style
vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.expandtab = true
vim.opt_local.textwidth = 88  -- Black formatter default

-- Run current file
vim.keymap.set("n", "<leader>pr", function()
  vim.cmd("!python " .. vim.fn.shellescape(vim.fn.expand("%")))
end, { buffer = true, desc = "Run Python file" })

-- Run pytest on current file
vim.keymap.set("n", "<leader>pt", function()
  vim.cmd("!pytest " .. vim.fn.shellescape(vim.fn.expand("%")) .. " -v")
end, { buffer = true, desc = "Run pytest" })

-- Run pytest on current function
vim.keymap.set("n", "<leader>pf", function()
  local function_name = vim.fn.expand("<cword>")
  vim.cmd("!pytest " .. vim.fn.shellescape(vim.fn.expand("%")) .. " -v -k " .. function_name)
end, { buffer = true, desc = "Run current test" })
```

### javascript.lua / typescript.lua

```lua
-- after/ftplugin/javascript.lua (also symlink to typescript.lua)

if vim.b.did_user_ftplugin then
  return
end
vim.b.did_user_ftplugin = true

vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true

-- Run with node
vim.keymap.set("n", "<leader>nr", function()
  vim.cmd("!node " .. vim.fn.shellescape(vim.fn.expand("%")))
end, { buffer = true, desc = "Run with Node" })

-- Run tests
vim.keymap.set("n", "<leader>nt", function()
  vim.cmd("!npm test")
end, { buffer = true, desc = "Run npm test" })
```

### markdown.lua

```lua
-- after/ftplugin/markdown.lua

if vim.b.did_user_ftplugin then
  return
end
vim.b.did_user_ftplugin = true

-- Word wrap for prose
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.breakindent = true

-- Spell checking
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_us"

-- Concealing for cleaner display
vim.opt_local.conceallevel = 2

-- Text width for hard wrapping (if desired)
vim.opt_local.textwidth = 80

-- Navigate by visual lines
vim.keymap.set("n", "j", "gj", { buffer = true })
vim.keymap.set("n", "k", "gk", { buffer = true })

-- Toggle checkbox
vim.keymap.set("n", "<leader>x", function()
  local line = vim.api.nvim_get_current_line()
  local new_line
  if line:match("%[ %]") then
    new_line = line:gsub("%[ %]", "[x]")
  elseif line:match("%[x%]") then
    new_line = line:gsub("%[x%]", "[ ]")
  else
    return
  end
  vim.api.nvim_set_current_line(new_line)
end, { buffer = true, desc = "Toggle checkbox" })
```

### help.lua

```lua
-- after/ftplugin/help.lua

if vim.b.did_user_ftplugin then
  return
end
vim.b.did_user_ftplugin = true

-- Close help with q
vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = true, silent = true })

-- Open links with Enter
vim.keymap.set("n", "<CR>", "<C-]>", { buffer = true })

-- Go back with Backspace
vim.keymap.set("n", "<BS>", "<C-T>", { buffer = true })
```

### gitcommit.lua

```lua
-- after/ftplugin/gitcommit.lua

if vim.b.did_user_ftplugin then
  return
end
vim.b.did_user_ftplugin = true

-- Git commit message conventions
vim.opt_local.textwidth = 72
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_us"

-- Start in insert mode
vim.cmd("startinsert")
```

### json.lua

```lua
-- after/ftplugin/json.lua

if vim.b.did_user_ftplugin then
  return
end
vim.b.did_user_ftplugin = true

vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true

-- Don't conceal quotes
vim.opt_local.conceallevel = 0
```

## Shared Configuration Pattern

For filetypes that share settings:

```lua
-- lua/config/ft/web.lua
local M = {}

function M.setup()
  vim.opt_local.tabstop = 2
  vim.opt_local.shiftwidth = 2
  vim.opt_local.expandtab = true
end

return M

-- after/ftplugin/javascript.lua
require("config.ft.web").setup()

-- after/ftplugin/typescript.lua
require("config.ft.web").setup()

-- after/ftplugin/html.lua
require("config.ft.web").setup()

-- after/ftplugin/css.lua
require("config.ft.web").setup()
```

## Cleanup Pattern

For resetting state when leaving buffer:

```lua
-- after/ftplugin/special.lua

if vim.b.did_user_ftplugin then
  return
end
vim.b.did_user_ftplugin = true

-- Setup
vim.opt_local.wrap = true

-- Cleanup on buffer leave
vim.api.nvim_create_autocmd("BufLeave", {
  buffer = 0,
  callback = function()
    -- Cleanup actions
  end,
  once = true,
})
```
