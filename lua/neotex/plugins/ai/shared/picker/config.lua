-- neotex.plugins.ai.shared.picker.config
-- Parameterized configuration for shared commands picker
-- Supports both .claude/ and .opencode/ directory structures

local M = {}

--- Create a picker configuration
--- @param opts table Configuration options
--- @return table config Picker configuration
function M.create(opts)
  vim.validate({
    base_dir = { opts.base_dir, "string" },
    label = { opts.label, "string" },
    commands_subdir = { opts.commands_subdir, "string" },
    skills_subdir = { opts.skills_subdir, "string" },
    agents_subdir = { opts.agents_subdir, "string" },
    hooks_subdir = { opts.hooks_subdir, "string", true },
    settings_file = { opts.settings_file, "string" },
    root_config_file = { opts.root_config_file, "string" },
    user_command = { opts.user_command, "string" },
    extensions_module = { opts.extensions_module, "string", true },
    global_source_dir = { opts.global_source_dir, "string", true },
  })

  return {
    -- Base directory name (.claude or .opencode)
    base_dir = opts.base_dir,

    -- Label for UI display ("Claude" or "OpenCode")
    label = opts.label,

    -- Subdirectory names
    commands_subdir = opts.commands_subdir,
    skills_subdir = opts.skills_subdir,
    agents_subdir = opts.agents_subdir,
    hooks_subdir = opts.hooks_subdir,

    -- Configuration files
    settings_file = opts.settings_file,
    root_config_file = opts.root_config_file,

    -- User command name (ClaudeCommands or OpencodeCommands)
    user_command = opts.user_command,

    -- Extensions module path
    extensions_module = opts.extensions_module,

    -- Global source directory (defaults to ~/.config/nvim)
    global_source_dir = opts.global_source_dir or vim.fn.expand("~/.config/nvim"),

    -- Optional callback run after Load Core Agent System completes
    on_load_all = opts.on_load_all,
  }
end

--- Claude-specific configuration preset
--- @param global_dir string|nil Global directory (defaults to ~/.config/nvim)
--- @return table config Claude picker configuration
function M.claude(global_dir)
  return M.create({
    base_dir = ".claude",
    label = "Claude",
    commands_subdir = "commands",
    skills_subdir = "skills",
    agents_subdir = "agents",
    hooks_subdir = "hooks",
    settings_file = "settings.local.json",
    root_config_file = "CLAUDE.md",
    user_command = "ClaudeCommands",
    extensions_module = "neotex.plugins.ai.claude.extensions",
    global_source_dir = global_dir or vim.fn.expand("~/.config/nvim"),
  })
end

--- OpenCode-specific configuration preset
--- @param global_dir string|nil Global directory (defaults to ~/.config/nvim)
--- @return table config OpenCode picker configuration
function M.opencode(global_dir)
  return M.create({
    base_dir = ".opencode",
    label = "OpenCode",
    commands_subdir = "commands",
    skills_subdir = "skills",
    agents_subdir = "agent/subagents",
    hooks_subdir = nil, -- OpenCode doesn't use hooks
    settings_file = "settings.json",
    root_config_file = "OPENCODE.md",
    user_command = "OpencodeCommands",
    extensions_module = "neotex.plugins.ai.opencode.extensions",
    global_source_dir = global_dir or vim.fn.expand("~/.config/nvim"),
    on_load_all = function()
      local core = require("neotex.plugins.ai.opencode.core")
      local ok, msg = core.install_base_opencode_json()
      local helpers_mod = require("neotex.plugins.ai.claude.commands.picker.utils.helpers")
      if ok then
        helpers_mod.notify("opencode.json: " .. (msg or "installed"), "INFO")
      end
    end,
  })
end

return M
