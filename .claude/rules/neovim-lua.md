# Neovim Lua Development Rules

## Path Pattern

Applies to: `lua/**/*.lua`, `after/**/*.lua`, `*.lua`

## Coding Standards

### Indentation
- Use 2 spaces for indentation
- Never use tabs
- Maximum line length: 100 characters

### Naming Conventions
- Variables and functions: `snake_case`
- Module tables: `PascalCase` (when used as constructors)
- Constants: `SCREAMING_SNAKE_CASE`
- Private functions: prefix with underscore `_helper()`

### Module Structure
```lua
local M = {}

-- Private functions first
local function _helper()
  -- ...
end

-- Public API
function M.setup(opts)
  opts = opts or {}
  -- ...
end

return M
```

## Neovim API Patterns

### Keymaps

Always use `vim.keymap.set` with description:
```lua
vim.keymap.set("n", "<leader>x", function()
  -- action
end, { desc = "Description" })
```

### Options

Prefer `vim.opt` over `vim.o`:
```lua
vim.opt.number = true
vim.opt.tabstop = 2
```

### Autocommands

Always use augroups with `clear = true`:
```lua
local group = vim.api.nvim_create_augroup("GroupName", { clear = true })
vim.api.nvim_create_autocmd("Event", {
  group = group,
  callback = function()
    -- action
  end,
})
```

## Plugin Specifications

### lazy.nvim Format
```lua
return {
  "author/plugin",
  dependencies = { "dep1" },
  event = "VeryLazy",  -- or specific event
  opts = {
    -- options
  },
}
```

### Lazy Loading
Always specify loading conditions:
- `event` - For buffer/mode events
- `cmd` - For commands
- `ft` - For filetypes
- `keys` - For key mappings

## Error Handling

### Protected Calls
Use `pcall` for optional modules:
```lua
local ok, module = pcall(require, "optional")
if not ok then
  return
end
```

### Validation
Use `vim.validate` for function arguments:
```lua
vim.validate({
  opts = { opts, "table", true },
})
```

## Documentation

### LuaDoc Comments
```lua
--- Brief description
--- @param name type Description
--- @return type Description
function M.func(name)
  return result
end
```

## Testing

### Verification Commands
```bash
# Test module loads
nvim --headless -c "lua require('module')" -c "q"

# Run checkhealth
nvim --headless -c "checkhealth" -c "q"
```

## Do Not

- Use global variables (use module locals)
- Forget to handle nil values
- Create circular dependencies
- Skip lazy loading conditions
- Omit keymap descriptions
- Use deprecated APIs (vim.cmd("set X") vs vim.opt.X)

## Related Context

Load for detailed patterns:
- `@.claude/context/project/neovim/standards/lua-style-guide.md`
- `@.claude/context/project/neovim/patterns/plugin-spec.md`
- `@.claude/context/project/neovim/patterns/keymap-patterns.md`
