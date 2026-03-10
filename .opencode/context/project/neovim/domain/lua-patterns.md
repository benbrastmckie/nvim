# Lua Patterns for Neovim

Lua idioms and patterns specific to Neovim configuration.

## Module Pattern

Standard Lua module structure for Neovim:

```lua
-- lua/mymodule.lua
local M = {}

-- Private function (not exported)
local function helper()
  return "helper result"
end

-- Public function
function M.setup(opts)
  opts = opts or {}
  -- Setup logic here
end

function M.my_function()
  return helper()
end

return M
```

## Lazy Loading Pattern

Defer loading until needed:

```lua
-- Lazy require pattern
local function get_telescope()
  return require("telescope")
end

-- Only loads telescope when called
vim.keymap.set("n", "<leader>ff", function()
  get_telescope().builtin.find_files()
end)
```

## Protected Calls

Handle missing modules gracefully:

```lua
-- pcall for safe require
local ok, module = pcall(require, "optional-plugin")
if not ok then
  vim.notify("Optional plugin not installed", vim.log.levels.WARN)
  return
end

-- Use module safely
module.setup({})
```

## Options Pattern

Common pattern for plugin configuration:

```lua
local defaults = {
  enabled = true,
  theme = "dark",
  keymaps = true,
}

function M.setup(user_opts)
  local opts = vim.tbl_deep_extend("force", defaults, user_opts or {})
  -- Use merged opts
end
```

## Functional Patterns

### Map/Filter

```lua
-- Filter a list
local function filter(tbl, fn)
  local result = {}
  for _, v in ipairs(tbl) do
    if fn(v) then
      table.insert(result, v)
    end
  end
  return result
end

-- Using vim.tbl_filter (built-in)
local even = vim.tbl_filter(function(n) return n % 2 == 0 end, {1, 2, 3, 4})

-- Map over a list using vim.tbl_map
local doubled = vim.tbl_map(function(n) return n * 2 end, {1, 2, 3})
```

### Reduce

```lua
local function reduce(tbl, fn, init)
  local acc = init
  for _, v in ipairs(tbl) do
    acc = fn(acc, v)
  end
  return acc
end

local sum = reduce({1, 2, 3, 4}, function(a, b) return a + b end, 0)
```

## Closure Pattern

Capture state in closures:

```lua
local function create_counter()
  local count = 0
  return function()
    count = count + 1
    return count
  end
end

local counter = create_counter()
print(counter()) -- 1
print(counter()) -- 2
```

## Memoization

Cache expensive computations:

```lua
local cache = {}

local function expensive_fn(key)
  if cache[key] then
    return cache[key]
  end

  -- Expensive computation
  local result = compute_something(key)
  cache[key] = result
  return result
end
```

## Debounce Pattern

Prevent rapid repeated calls:

```lua
local timer = nil

local function debounce(fn, ms)
  return function(...)
    local args = {...}
    if timer then
      timer:stop()
    end
    timer = vim.defer_fn(function()
      fn(unpack(args))
    end, ms)
  end
end

-- Usage: only runs 300ms after last call
local search = debounce(function(query)
  -- search logic
end, 300)
```

## Error Handling

Standard error handling pattern:

```lua
local function safe_call(fn, ...)
  local ok, result = pcall(fn, ...)
  if not ok then
    vim.notify("Error: " .. tostring(result), vim.log.levels.ERROR)
    return nil
  end
  return result
end
```

## Type Checking

Validate function arguments:

```lua
local function setup(opts)
  vim.validate({
    opts = { opts, "table", true }, -- optional table
    ["opts.enabled"] = { opts and opts.enabled, "boolean", true },
    ["opts.path"] = { opts and opts.path, "string" },
  })
  -- Continue with validated opts
end
```
