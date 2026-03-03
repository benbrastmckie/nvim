-- Tests for shared picker configuration
-- Run with: nvim --headless -c "lua require('plenary.test_harness').test_file('lua/neotex/plugins/ai/shared/picker/config_spec.lua')"

local config = require("neotex.plugins.ai.shared.picker.config")

describe("shared.picker.config", function()
  describe("claude()", function()
    it("returns Claude-specific configuration", function()
      local c = config.claude()

      assert.equals(".claude", c.base_dir)
      assert.equals("Claude", c.label)
      assert.equals("commands", c.commands_subdir)
      assert.equals("skills", c.skills_subdir)
      assert.equals("agents", c.agents_subdir)
      assert.equals("hooks", c.hooks_subdir)
      assert.equals("settings.local.json", c.settings_file)
      assert.equals("CLAUDE.md", c.root_config_file)
      assert.equals("ClaudeCommands", c.user_command)
      assert.equals("neotex.plugins.ai.claude.extensions", c.extensions_module)
    end)

    it("accepts custom global_dir", function()
      local c = config.claude("/custom/path")
      assert.equals("/custom/path", c.global_source_dir)
    end)
  end)

  describe("opencode()", function()
    it("returns OpenCode-specific configuration", function()
      local c = config.opencode()

      assert.equals(".opencode", c.base_dir)
      assert.equals("OpenCode", c.label)
      assert.equals("commands", c.commands_subdir)
      assert.equals("skills", c.skills_subdir)
      assert.equals("agent/subagents", c.agents_subdir)
      assert.is_nil(c.hooks_subdir)
      assert.equals("settings.json", c.settings_file)
      assert.equals("OPENCODE.md", c.root_config_file)
      assert.equals("OpencodeCommands", c.user_command)
      assert.equals("neotex.plugins.ai.opencode.extensions", c.extensions_module)
    end)

    it("handles different agents directory structure", function()
      local claude_config = config.claude()
      local opencode_config = config.opencode()

      -- Claude uses flat agents/ directory
      assert.equals("agents", claude_config.agents_subdir)

      -- OpenCode uses nested agent/subagents/ directory
      assert.equals("agent/subagents", opencode_config.agents_subdir)
    end)
  end)

  describe("create()", function()
    it("validates required fields", function()
      -- Should not error with valid config
      local c = config.create({
        base_dir = ".test",
        label = "Test",
        commands_subdir = "commands",
        skills_subdir = "skills",
        agents_subdir = "agents",
        settings_file = "settings.json",
        root_config_file = "TEST.md",
        user_command = "TestCommands",
      })

      assert.equals(".test", c.base_dir)
      assert.equals("Test", c.label)
    end)

    it("allows optional hooks_subdir to be nil", function()
      local c = config.create({
        base_dir = ".test",
        label = "Test",
        commands_subdir = "commands",
        skills_subdir = "skills",
        agents_subdir = "agents",
        hooks_subdir = nil,
        settings_file = "settings.json",
        root_config_file = "TEST.md",
        user_command = "TestCommands",
      })

      assert.is_nil(c.hooks_subdir)
    end)
  end)
end)
