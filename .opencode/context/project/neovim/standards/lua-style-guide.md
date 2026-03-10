# Lua Style Guide for Neovim

Coding conventions for Neovim Lua configurations.

## Indentation and Formatting

- Use 2 spaces for indentation (not tabs)
- Maximum line length: 100 characters
- Use trailing commas in multi-line tables

```lua
-- Good
local config = {
  option1 = "value",
  option2 = true,  -- trailing comma
}

-- Bad
local config = {
  option1 = "value",
  option2 = true
}
```

## Naming Conventions

### Variables and Functions

- Use `snake_case` for variables and functions
- Use `PascalCase` for classes/modules that act like constructors
- Use `SCREAMING_SNAKE_CASE` for constants

```lua
-- Variables
local my_variable = "value"
local buffer_count = 10

-- Functions
local function get_current_buffer()
  return vim.api.nvim_get_current_buf()
end

-- Constants
local MAX_RETRIES = 3
local DEFAULT_TIMEOUT = 5000

-- Module (PascalCase if constructable)
local MyModule = {}
```

### Private Functions

Prefix private module functions with underscore:

```lua
local M = {}

local function _helper()
  -- Private helper
end

function M.public_function()
  _helper()
end

return M
```

## Module Structure

```lua
-- lua/mymodule.lua

local M = {}

-- Constants at top
local DEFAULT_OPTION = "value"

-- Private functions next
local function helper()
  return "result"
end

-- Public functions
function M.setup(opts)
  opts = opts or {}
  -- Setup logic
end

function M.do_something()
  return helper()
end

-- Return module at end
return M
```

## String Handling

- Prefer double quotes for strings
- Use `..` for concatenation
- Use `string.format` for complex formatting

```lua
-- Simple strings
local msg = "Hello world"

-- Concatenation
local greeting = "Hello, " .. name .. "!"

-- Complex formatting
local info = string.format("Buffer %d: %s", bufnr, filename)

-- Multi-line strings
local template = [[
Line 1
Line 2
Line 3
]]
```

## Tables

### Short Tables

```lua
local short = { "a", "b", "c" }
local map = { key = "value", another = "thing" }
```

### Long Tables

```lua
local config = {
  option1 = "value",
  option2 = true,
  nested = {
    key1 = "value1",
    key2 = "value2",
  },
}
```

### Array Style

```lua
local list = {
  "item1",
  "item2",
  "item3",
}
```

## Functions

### Anonymous Functions

```lua
-- Short anonymous functions on one line
vim.keymap.set("n", "<leader>w", function() vim.cmd("write") end)

-- Longer ones on multiple lines
vim.keymap.set("n", "<leader>f", function()
  vim.lsp.buf.format({ async = true })
  vim.notify("Formatted")
end)
```

### Function Parameters

```lua
-- Few parameters
function do_thing(a, b, c)
  return a + b + c
end

-- Many parameters - use options table
function setup(opts)
  opts = vim.tbl_deep_extend("force", {
    enabled = true,
    timeout = 1000,
  }, opts or {})
end
```

## Error Handling

```lua
-- Use pcall for potentially failing operations
local ok, result = pcall(require, "optional-module")
if not ok then
  vim.notify("Module not found", vim.log.levels.WARN)
  return
end

-- Validate function arguments
function setup(opts)
  vim.validate({
    opts = { opts, "table", true },
    ["opts.enabled"] = { opts and opts.enabled, "boolean", true },
  })
end
```

## Comments

```lua
-- Single line comment

--[[
Multi-line comment
for longer explanations
]]

--- Documentation comment (LuaDoc style)
--- @param name string The name to greet
--- @return string The greeting message
function greet(name)
  return "Hello, " .. name
end
```

## Control Flow

```lua
-- if/elseif/else
if condition then
  -- action
elseif other_condition then
  -- other action
else
  -- default action
end

-- Early returns preferred
function process(data)
  if not data then
    return nil
  end

  if data.invalid then
    return nil, "Invalid data"
  end

  return data.value
end
```

## Loops

```lua
-- ipairs for arrays
for i, item in ipairs(list) do
  print(i, item)
end

-- pairs for tables
for key, value in pairs(tbl) do
  print(key, value)
end

-- Numeric for
for i = 1, 10 do
  print(i)
end

-- while (avoid when possible)
while condition do
  -- action
  if should_break then
    break
  end
end
```

## Imports

```lua
-- At top of file
local api = vim.api
local fn = vim.fn
local uv = vim.loop

-- Local requires
local utils = require("myconfig.utils")
local lspconfig = require("lspconfig")

-- Inline require for rarely used modules
local function do_thing()
  local telescope = require("telescope.builtin")
  telescope.find_files()
end
```

## File Organization

```
lua/
├── config/           # Core configuration
│   ├── options.lua   # vim.opt settings
│   ├── keymaps.lua   # Keybindings
│   └── autocmds.lua  # Autocommands
├── plugins/          # Plugin specs for lazy.nvim
│   ├── init.lua      # Main plugin list
│   ├── ui.lua        # UI plugins
│   └── editor.lua    # Editor plugins
└── utils/            # Utility functions
    └── init.lua
```
