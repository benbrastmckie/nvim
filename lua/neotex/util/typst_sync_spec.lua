-- Tests for the Typst <-> PDF sync helper (markup stripping, socket and registry paths,
-- live-mode state, RPC argument validation).
-- Run with: nvim --headless -c "lua require('plenary.test_harness').test_file('lua/neotex/util/typst_sync_spec.lua')"

local sync = require("neotex.util.typst_sync")

describe("neotex.util.typst_sync", function()
  describe("plain_text()", function()
    it("keeps prose untouched", function()
      local line = "Reproducibility supports a pair of counterfactual conditionals."
      assert.equals(line, sync.plain_text(line))
    end)

    it("strips emphasis markers but keeps the emphasized words", function()
      local result = sync.plain_text("the effect _would have followed_ had the cause been present")
      assert.equals("the effect would have followed had the cause been present", result)
    end)

    it("removes function calls along with their arguments", function()
      local result = sync.plain_text("as shown in #cite(<frame-check>) the posit holds")
      assert.equals("as shown in the posit holds", result)
    end)

    it("removes labels and cross references", function()
      assert.equals("The Task Frame", sync.plain_text("= The Task Frame <sec-task-frame>"))
      assert.equals("see above", sync.plain_text("see @sec-task-frame above"))
    end)

    it("removes inline math, which has no textual counterpart to match", function()
      assert.equals("whenever is coherent", sync.plain_text("whenever $s ->_0 t$ is coherent"))
    end)

    it("strips heading markers at any depth", function()
      assert.equals("Contexts", sync.plain_text("== Contexts"))
      assert.equals("Contexts", sync.plain_text("=== Contexts"))
    end)

    it("drops characters that would break sioyek's command parsing", function()
      -- `;` separates macro steps and parentheses delimit an argument, so a line
      -- carrying them must not reach the command line intact.
      local result = sync.plain_text("first; second (third)")
      assert.is_nil(result:find(";", 1, true))
      assert.is_nil(result:find("(", 1, true))
      assert.is_nil(result:find(")", 1, true))
    end)

    it("collapses whitespace left behind by stripping", function()
      local result = sync.plain_text("a #cite(<x>) b")
      assert.equals("a b", result)
      assert.is_nil(result:find("  ", 1, true))
    end)

    it("returns an empty string for a line with no prose", function()
      assert.equals("", sync.plain_text("$"))
      assert.equals("", sync.plain_text("#import \"../template.typ\": *"))
    end)
  end)

  describe("socket_path()", function()
    it("stays well inside the 108-byte AF_UNIX limit for a deep project path", function()
      local deep = "/home/someone/" .. string.rep("a-long-directory-name/", 12) .. "project"
      assert.is_true(#sync.socket_path(deep) < 108)
    end)

    it("is stable for the same root", function()
      local root = "/home/someone/Projects/doc"
      assert.equals(sync.socket_path(root), sync.socket_path(root))
    end)

    it("is insensitive to a trailing slash, matching the project-root key", function()
      assert.equals(
        sync.socket_path("/home/someone/Projects/doc"),
        sync.socket_path("/home/someone/Projects/doc/")
      )
    end)

    it("distinguishes different roots", function()
      assert.are_not.equals(
        sync.socket_path("/home/someone/Projects/one"),
        sync.socket_path("/home/someone/Projects/two")
      )
    end)
  end)

  describe("registry_path()", function()
    it("keys on the PDF path and lands under the cache directory", function()
      local pdf = "/home/someone/Projects/doc/main.pdf"
      local path = sync.registry_path(pdf)
      local prefix = vim.fn.stdpath("cache") .. "/typst-sync/"
      assert.equals(prefix, path:sub(1, #prefix))
      -- The sioyek dispatcher recomputes this key with sha256sum, so the derivation
      -- must stay exactly the first twelve hex digits of the SHA-256 of the path.
      assert.equals(vim.fn.sha256(pdf):sub(1, 12) .. ".json", vim.fn.fnamemodify(path, ":t"))
    end)

    it("distinguishes different PDFs", function()
      assert.are_not.equals(
        sync.registry_path("/home/someone/a.pdf"),
        sync.registry_path("/home/someone/b.pdf")
      )
    end)
  end)

  describe("live mode", function()
    it("is off until turned on, and live_off() is safe to repeat", function()
      sync.live_off()
      assert.is_false(sync.live_active())
      sync.live_off()
      assert.is_false(sync.live_active())
    end)
  end)

  describe("inverse_rpc()", function()
    -- A malformed call arrives from a detached viewer, so it must be refused rather
    -- than dispatched with coerced nonsense.
    local function refuses(args)
      local reached = false
      local saved = sync.inverse
      sync.inverse = function()
        reached = true
      end
      pcall(sync.inverse_rpc, args)
      sync.inverse = saved
      return not reached
    end

    it("refuses a non-table argument", function()
      assert.is_true(refuses("2 1 2 abc"))
      assert.is_true(refuses(nil))
    end)

    it("refuses a non-numeric position", function()
      assert.is_true(refuses({ "x", 1.0, 2.0, "46a2c702b26c" }))
    end)

    it("refuses a key that is not hex, which could otherwise escape the cache directory", function()
      assert.is_true(refuses({ 2, 1.0, 2.0, "../../etc/passwd" }))
    end)

    it("refuses a well-formed call whose registry entry is absent", function()
      -- Hex-shaped but never written, so there is no PDF to resolve against.
      assert.is_true(refuses({ 2, 1.0, 2.0, "ffffffffffff" }))
    end)
  end)
end)
