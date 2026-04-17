# Filetype Plugin Patterns

Patterns for filetype-specific configurations.

## Directory Structure

```
~/.config/nvim/
├── after/
│   └── ftplugin/
│       ├── lua.lua
│       ├── python.lua
│       ├── javascript.lua
│       └── markdown.lua
└── ftplugin/
    └── custom_filetype.lua
```

## Basic ftplugin

```lua
-- after/ftplugin/python.lua

-- Local options (buffer-local)
vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.expandtab = true

-- Buffer-local keymaps
vim.keymap.set("n", "<leader>r", ":!python %<CR>", {
  buffer = true,
  desc = "Run Python file",
})
```

## Common Ftplugin Patterns

### Lua

```lua
-- after/ftplugin/lua.lua
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true

-- Fold on functions
vim.opt_local.foldmethod = "expr"
vim.opt_local.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt_local.foldlevel = 99
```

### Python

```lua
-- after/ftplugin/python.lua
vim.opt_local.tabstop = 4
vim.opt_local.shiftwidth = 4
vim.opt_local.expandtab = true
vim.opt_local.textwidth = 88  -- Black default

-- Run file
vim.keymap.set("n", "<leader>r", function()
  vim.cmd("!python " .. vim.fn.shellescape(vim.fn.expand("%")))
end, { buffer = true, desc = "Run Python" })

-- Run pytest
vim.keymap.set("n", "<leader>tp", function()
  vim.cmd("!pytest " .. vim.fn.shellescape(vim.fn.expand("%")))
end, { buffer = true, desc = "Run pytest" })
```

### JavaScript/TypeScript

```lua
-- after/ftplugin/javascript.lua
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true

-- Also applies to TypeScript via shared file or symlink
```

### Markdown

```lua
-- after/ftplugin/markdown.lua
vim.opt_local.wrap = true
vim.opt_local.linebreak = true
vim.opt_local.spell = true
vim.opt_local.spelllang = "en_us"
vim.opt_local.conceallevel = 2
vim.opt_local.textwidth = 80
```

### JSON

```lua
-- after/ftplugin/json.lua
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true
vim.opt_local.conceallevel = 0
```

### Help Files

```lua
-- after/ftplugin/help.lua
-- Close help with q
vim.keymap.set("n", "q", ":close<CR>", { buffer = true, silent = true })

-- Open links with Enter
vim.keymap.set("n", "<CR>", "<C-]>", { buffer = true })
```

## Using vim.opt_local

```lua
-- Buffer-local options
vim.opt_local.number = true
vim.opt_local.relativenumber = true

-- Window-local options
vim.wo.wrap = true

-- Buffer options via bo
vim.bo.filetype = "custom"
```

## Custom Filetypes

Define custom filetype detection:

```lua
-- lua/custom/filetypes.lua or in init.lua
vim.filetype.add({
  extension = {
    mdx = "markdown.mdx",
    typ = "typst",
  },
  filename = {
    [".env"] = "dotenv",
    ["Dockerfile"] = "dockerfile",
  },
  pattern = {
    ["%.config/hypr/.*%.conf"] = "hyprlang",
  },
})
```

## Autocommand Alternative

For more complex logic:

```lua
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("PythonSettings", { clear = true }),
  pattern = "python",
  callback = function()
    vim.opt_local.tabstop = 4
    vim.opt_local.shiftwidth = 4

    -- Check for Django project
    if vim.fn.filereadable("manage.py") == 1 then
      vim.keymap.set("n", "<leader>dm", function()
        vim.cmd("!python manage.py runserver")
      end, { buffer = true })
    end
  end,
})
```

## Avoiding Duplicate Settings

```lua
-- after/ftplugin/python.lua

-- Guard against multiple loads
if vim.b.did_ftplugin then
  return
end
vim.b.did_ftplugin = true

-- Your settings here
vim.opt_local.tabstop = 4
```

## Shared Settings

For multiple similar filetypes:

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

-- after/ftplugin/css.lua
require("config.ft.web").setup()
```
