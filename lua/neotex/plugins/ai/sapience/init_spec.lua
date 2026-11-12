-- Tests for the sf1 Sapience chat public API (command construction, styling fallback,
-- validation).
-- Run with: nvim --headless -c "lua require('plenary.test_harness').test_file('lua/neotex/plugins/ai/sapience/init_spec.lua')"

local function fresh_init()
  package.loaded["neotex.plugins.ai.sapience.init"] = nil
  package.loaded["neotex.plugins.ai.sapience.terminal"] = nil
  return require("neotex.plugins.ai.sapience.init")
end

describe("sapience.init", function()
  describe("_command() via open()/is_visible() (styling enabled, the default)", function()
    it("invokes the proxy with --separator blank and the -- terminator before sf1", function()
      local sapience = fresh_init()
      sapience.setup({ project = false })

      local backend = require("neotex.plugins.ai.sapience.terminal")
      local seen_cmd = nil
      local orig_visible = backend.visible
      backend.visible = function(cmd)
        seen_cmd = cmd
        return false
      end

      sapience.is_visible()
      backend.visible = orig_visible

      assert.is_not_nil(seen_cmd)
      assert.truthy(seen_cmd:match("sf1_proxy%.py"))
      assert.truthy(seen_cmd:match("%-%-separator blank"))
      -- The `--` terminator must precede the sf1 argv so `--project` lands on the child,
      -- never on the proxy's own argument parser.
      local term_idx = seen_cmd:find(" %-%- ")
      local sf1_idx = seen_cmd:find("sf1$") or seen_cmd:find("sf1 ")
      assert.is_not_nil(term_idx)
      assert.is_not_nil(sf1_idx)
      assert.is_true(term_idx < sf1_idx)
    end)
  end)

  describe("_command() with styling.enabled = false", function()
    it("returns the bare sf1 command string byte-for-byte, unchanged from today", function()
      local sapience = fresh_init()
      sapience.setup({ project = "cwd", styling = { enabled = false, separator = "blank" } })

      local backend = require("neotex.plugins.ai.sapience.terminal")
      local seen_cmd = nil
      local orig_visible = backend.visible
      backend.visible = function(cmd)
        seen_cmd = cmd
        return false
      end

      sapience.is_visible()
      backend.visible = orig_visible

      local expected_project = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
      assert.equals("sf1 --project " .. vim.fn.shellescape(expected_project), seen_cmd)
    end)
  end)

  describe("setup() validation", function()
    it("rejects an invalid styling.separator value", function()
      local sapience = fresh_init()
      assert.has_error(function()
        sapience.setup({ styling = { enabled = true, separator = "not-a-real-value" } })
      end)
    end)

    it("rejects a non-boolean styling.enabled value", function()
      local sapience = fresh_init()
      assert.has_error(function()
        sapience.setup({ styling = { enabled = "yes", separator = "blank" } })
      end)
    end)

    it("accepts the default styling table unchanged", function()
      local sapience = fresh_init()
      assert.has_no.errors(function()
        sapience.setup({})
      end)
    end)
  end)
end)
