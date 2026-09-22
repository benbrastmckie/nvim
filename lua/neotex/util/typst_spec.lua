-- Tests for the shared Typst helper (project root, main-file detection, pin state)
-- Run with: nvim --headless -c "lua require('plenary.test_harness').test_file('lua/neotex/util/typst_spec.lua')"

local typst = require("neotex.util.typst")

local function write_file(path, content)
  vim.fn.writefile(vim.split(content, "\n"), path)
end

local function make_tempdir()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

describe("neotex.util.typst", function()
  describe("main_file()", function()
    it("prefers the file that #includes the chapter over alphabetical order", function()
      local dir = make_tempdir()
      vim.fn.mkdir(dir .. "/chapters", "p")
      write_file(dir .. "/chapters/c.typ", "= Chapter C\n")
      -- A.typ sorts first alphabetically but does NOT include the chapter.
      write_file(dir .. "/A.typ", "= Unrelated document\n")
      -- Z.typ sorts last but DOES include the chapter -- this is the regression case.
      write_file(dir .. "/Z.typ", '#include "chapters/c.typ"\n')

      local result = typst.main_file(dir .. "/chapters/c.typ")
      assert.equals(dir .. "/Z.typ", result)
    end)

    it("detects an #import form with a trailing clause", function()
      local dir = make_tempdir()
      vim.fn.mkdir(dir .. "/chapters", "p")
      write_file(dir .. "/chapters/c.typ", "= Chapter C\n")
      write_file(dir .. "/Main.typ", '#import "chapters/c.typ": *\n')

      local result = typst.main_file(dir .. "/chapters/c.typ")
      assert.equals(dir .. "/Main.typ", result)
    end)

    it("falls back to main.typ when no includer is found", function()
      local dir = make_tempdir()
      vim.fn.mkdir(dir .. "/chapters", "p")
      write_file(dir .. "/chapters/c.typ", "= Chapter C\n")
      write_file(dir .. "/main.typ", "= Main document\n")

      local result = typst.main_file(dir .. "/chapters/c.typ")
      assert.equals(dir .. "/main.typ", result)
    end)

    it("resolves a non-chapter file to itself", function()
      local dir = make_tempdir()
      write_file(dir .. "/doc.typ", "= Standalone document\n")

      local result = typst.main_file(dir .. "/doc.typ")
      assert.equals(dir .. "/doc.typ", result)
    end)

    it("lets a pin override detection, and unpin restores it", function()
      local dir = make_tempdir()
      vim.fn.mkdir(dir .. "/chapters", "p")
      write_file(dir .. "/chapters/c.typ", "= Chapter C\n")
      write_file(dir .. "/main.typ", "= Main document\n")
      write_file(dir .. "/Other.typ", "= Pinned override\n")

      local root = typst.project_root(dir .. "/chapters/c.typ")
      typst.pin(root, dir .. "/Other.typ")
      assert.equals(dir .. "/Other.typ", typst.main_file(dir .. "/chapters/c.typ"))

      typst.unpin(root)
      assert.equals(dir .. "/main.typ", typst.main_file(dir .. "/chapters/c.typ"))
    end)
  end)

  describe("project_root()", function()
    it("prefers typst.toml over .git when typst.toml is nearer", function()
      local dir = make_tempdir()
      vim.fn.mkdir(dir .. "/.git", "p")
      vim.fn.mkdir(dir .. "/sub/chapters", "p")
      write_file(dir .. "/sub/typst.toml", "")
      write_file(dir .. "/sub/chapters/c.typ", "= Chapter C\n")

      local result = typst.project_root(dir .. "/sub/chapters/c.typ")
      assert.equals(dir .. "/sub", result)
    end)

    it("falls back to the repo top when only .git is present", function()
      local dir = make_tempdir()
      vim.fn.mkdir(dir .. "/.git", "p")
      vim.fn.mkdir(dir .. "/sub/chapters", "p")
      write_file(dir .. "/sub/chapters/c.typ", "= Chapter C\n")

      local result = typst.project_root(dir .. "/sub/chapters/c.typ")
      assert.equals(dir, result)
    end)

    it("TYPST_ROOT env var overrides both markers", function()
      local dir = make_tempdir()
      vim.fn.mkdir(dir .. "/.git", "p")
      write_file(dir .. "/typst.toml", "")

      local prev = vim.env.TYPST_ROOT
      local ok = pcall(function()
        vim.env.TYPST_ROOT = "/tmp/typst-root-override"
        local result = typst.project_root(dir .. "/anything.typ")
        assert.equals("/tmp/typst-root-override", result)
      end)
      vim.env.TYPST_ROOT = prev
      assert.is_true(ok)
    end)
  end)
end)
