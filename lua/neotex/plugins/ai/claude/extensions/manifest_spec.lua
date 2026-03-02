-- Tests for neotex.plugins.ai.claude.extensions.manifest
-- Run with: nvim --headless -c "PlenaryBustedFile %"

local manifest = require("neotex.plugins.ai.claude.extensions.manifest")

describe("manifest", function()
  describe("validate", function()
    it("should accept valid minimal manifest", function()
      local m = {
        name = "test-ext",
        version = "1.0.0",
        description = "A test extension",
      }
      local valid, err = manifest.validate(m)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should accept valid manifest with provides", function()
      local m = {
        name = "test-ext",
        version = "1.0.0",
        description = "A test extension",
        provides = {
          agents = { "agent1.md", "agent2.md" },
          commands = { "cmd.md" },
        },
      }
      local valid, err = manifest.validate(m)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should accept valid manifest with merge_targets", function()
      local m = {
        name = "test-ext",
        version = "1.0.0",
        description = "A test extension",
        merge_targets = {
          claudemd = {
            source = "section.md",
            target = ".claude/CLAUDE.md",
            section_id = "ext_test",
          },
          settings = {
            source = "settings.json",
            target = ".claude/settings.local.json",
          },
        },
      }
      local valid, err = manifest.validate(m)
      assert.is_true(valid)
      assert.is_nil(err)
    end)

    it("should reject manifest without name", function()
      local m = {
        version = "1.0.0",
        description = "A test extension",
      }
      local valid, err = manifest.validate(m)
      assert.is_false(valid)
      assert.is_not_nil(err:match("Missing required field: name"))
    end)

    it("should reject manifest without version", function()
      local m = {
        name = "test-ext",
        description = "A test extension",
      }
      local valid, err = manifest.validate(m)
      assert.is_false(valid)
      assert.is_not_nil(err:match("Missing required field: version"))
    end)

    it("should reject manifest without description", function()
      local m = {
        name = "test-ext",
        version = "1.0.0",
      }
      local valid, err = manifest.validate(m)
      assert.is_false(valid)
      assert.is_not_nil(err:match("Missing required field: description"))
    end)

    it("should reject manifest with empty name", function()
      local m = {
        name = "",
        version = "1.0.0",
        description = "A test extension",
      }
      local valid, err = manifest.validate(m)
      assert.is_false(valid)
      assert.is_not_nil(err:match("non%-empty string: name"))
    end)

    it("should reject manifest with invalid provides category", function()
      local m = {
        name = "test-ext",
        version = "1.0.0",
        description = "A test extension",
        provides = {
          invalid_category = { "file.md" },
        },
      }
      local valid, err = manifest.validate(m)
      assert.is_false(valid)
      assert.is_not_nil(err:match("Invalid provides category"))
    end)

    it("should reject manifest with invalid merge_targets type", function()
      local m = {
        name = "test-ext",
        version = "1.0.0",
        description = "A test extension",
        merge_targets = {
          invalid_type = {
            source = "file.md",
            target = "target.md",
          },
        },
      }
      local valid, err = manifest.validate(m)
      assert.is_false(valid)
      assert.is_not_nil(err:match("Invalid merge_targets type"))
    end)

    it("should reject merge_targets without source", function()
      local m = {
        name = "test-ext",
        version = "1.0.0",
        description = "A test extension",
        merge_targets = {
          claudemd = {
            target = ".claude/CLAUDE.md",
          },
        },
      }
      local valid, err = manifest.validate(m)
      assert.is_false(valid)
      assert.is_not_nil(err:match("source is required"))
    end)

    it("should reject merge_targets without target", function()
      local m = {
        name = "test-ext",
        version = "1.0.0",
        description = "A test extension",
        merge_targets = {
          claudemd = {
            source = "section.md",
          },
        },
      }
      local valid, err = manifest.validate(m)
      assert.is_false(valid)
      assert.is_not_nil(err:match("target is required"))
    end)
  end)

  describe("list_extensions", function()
    it("should list extensions from global directory", function()
      local global_dir = vim.fn.expand("~/.config/nvim")
      local extensions = manifest.list_extensions(global_dir)

      -- Should be an array
      assert.is_table(extensions)

      -- Should find the lean extension we created
      local found_lean = false
      for _, ext in ipairs(extensions) do
        if ext.name == "lean" then
          found_lean = true
          assert.is_not_nil(ext.path)
          assert.is_not_nil(ext.manifest)
          assert.equals("lean", ext.manifest.name)
        end
      end
      assert.is_true(found_lean, "Should find lean extension")
    end)

    it("should return empty array for non-existent directory", function()
      local extensions = manifest.list_extensions("/non/existent/path")
      assert.is_table(extensions)
      assert.equals(0, #extensions)
    end)
  end)

  describe("read", function()
    it("should read and validate lean extension manifest", function()
      local global_dir = vim.fn.expand("~/.config/nvim")
      local lean_path = global_dir .. "/.claude/extensions/lean"

      local m, err = manifest.read(lean_path)
      assert.is_not_nil(m)
      assert.is_nil(err)
      assert.equals("lean", m.name)
      assert.equals("1.0.0", m.version)
      assert.is_not_nil(m.provides)
      assert.is_not_nil(m.merge_targets)
    end)

    it("should return error for non-existent directory", function()
      local m, err = manifest.read("/non/existent/path")
      assert.is_nil(m)
      assert.is_not_nil(err)
    end)
  end)

  describe("get_extension", function()
    it("should find extension by name", function()
      local ext = manifest.get_extension("lean")
      assert.is_not_nil(ext)
      assert.equals("lean", ext.name)
    end)

    it("should return nil for non-existent extension", function()
      local ext = manifest.get_extension("non_existent_extension")
      assert.is_nil(ext)
    end)
  end)
end)
