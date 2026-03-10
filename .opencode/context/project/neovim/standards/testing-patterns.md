# Testing Patterns for Neovim

Patterns for testing Neovim Lua code.

## plenary.nvim Testing

### Setup

```lua
-- Install plenary.nvim via lazy.nvim
{
  "nvim-lua/plenary.nvim",
  lazy = true,  -- Only needed for development
}
```

### Basic Test Structure

```lua
-- tests/mymodule_spec.lua
local mymodule = require("mymodule")

describe("mymodule", function()
  describe("setup", function()
    it("should initialize with defaults", function()
      mymodule.setup()
      assert.is_true(mymodule.is_initialized())
    end)

    it("should accept custom options", function()
      mymodule.setup({ enabled = false })
      assert.is_false(mymodule.is_enabled())
    end)
  end)
end)
```

### Assertions

```lua
-- Equality
assert.are.equal(expected, actual)
assert.are.same({ a = 1 }, { a = 1 })  -- Deep equality

-- Boolean
assert.is_true(value)
assert.is_false(value)
assert.is_nil(value)
assert.is_not_nil(value)

-- Type
assert.is_string(value)
assert.is_number(value)
assert.is_table(value)
assert.is_function(value)

-- Errors
assert.has_error(function() error("boom") end)
assert.has_no_error(function() return 1 end)
```

### Running Tests

```bash
# Run all tests
nvim --headless -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

# Run single test file
nvim --headless -c "PlenaryBustedFile tests/mymodule_spec.lua"
```

### Minimal Init

```lua
-- tests/minimal_init.lua
vim.opt.rtp:append(".")
vim.opt.rtp:append("~/.local/share/nvim/lazy/plenary.nvim")
vim.cmd("runtime plugin/plenary.vim")
```

## Test Organization

```
tests/
├── minimal_init.lua    # Minimal Neovim config for tests
├── helpers/
│   └── init.lua        # Test utilities
├── unit/
│   ├── utils_spec.lua
│   └── config_spec.lua
└── integration/
    └── plugin_spec.lua
```

## Mocking

### Mock vim.api

```lua
describe("buffer operations", function()
  local original_get_current_buf

  before_each(function()
    original_get_current_buf = vim.api.nvim_get_current_buf
    vim.api.nvim_get_current_buf = function()
      return 42  -- Mock buffer number
    end
  end)

  after_each(function()
    vim.api.nvim_get_current_buf = original_get_current_buf
  end)

  it("should use mocked buffer", function()
    assert.are.equal(42, vim.api.nvim_get_current_buf())
  end)
end)
```

### Mock Module

```lua
-- Using plenary's mock functionality
local mock = require("luassert.mock")

describe("lsp operations", function()
  local lsp_mock

  before_each(function()
    lsp_mock = mock(vim.lsp.buf, true)
  end)

  after_each(function()
    mock.revert(lsp_mock)
  end)

  it("should call format", function()
    require("mymodule").format_buffer()
    assert.stub(lsp_mock.format).was_called()
  end)
end)
```

## Test Helpers

```lua
-- tests/helpers/init.lua
local M = {}

function M.create_test_buffer()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "line 1",
    "line 2",
    "line 3",
  })
  return buf
end

function M.cleanup_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end
end

return M
```

## Async Testing

```lua
local async = require("plenary.async")

describe("async operations", function()
  async.it("should complete async task", function()
    local result = async.wrap(function(callback)
      vim.defer_fn(function()
        callback("done")
      end, 100)
    end, 1)()

    assert.are.equal("done", result)
  end)
end)
```

## Headless Testing Script

```bash
#!/bin/bash
# scripts/test.sh

set -e

NVIM=${NVIM:-nvim}

$NVIM --headless --noplugin -u tests/minimal_init.lua \
  -c "PlenaryBustedDirectory tests/ {minimal_init='tests/minimal_init.lua', sequential=true}"
```

## GitHub Actions

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Neovim
        uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
          version: stable

      - name: Install plenary.nvim
        run: |
          git clone --depth 1 https://github.com/nvim-lua/plenary.nvim \
            ~/.local/share/nvim/lazy/plenary.nvim

      - name: Run tests
        run: ./scripts/test.sh
```

## Integration Testing Tips

1. Use `vim.wait()` for async operations
2. Clean up buffers/windows after each test
3. Reset global state in `after_each`
4. Use minimal init to reduce test flakiness
5. Test user-facing behavior, not implementation details
