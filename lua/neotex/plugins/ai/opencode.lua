-- neotex.plugins.ai.opencode
-- OpenCode.nvim plugin configuration using NickvanDyke variant
-- Provides embedded TUI experience for opencode CLI with powerful context placeholders

return {
  "NickvanDyke/opencode.nvim",
  event = "VeryLazy",
  dependencies = {
    {
      "folke/snacks.nvim",
      opts = {
        input = {},
        picker = {},
        terminal = {},
      },
    },
  },
  init = function()
    -- Configure plugin via vim.g.opencode_opts table (NOT setup() function)
    vim.g.opencode_opts = {
      -- Provider configuration (use snacks.nvim for UI)
      provider = {
        enabled = "snacks",
        snacks = {
          auto_close = false, -- Keep terminal open even if opencode exits
          win = {
            position = "right",
            width = 0.40, -- 40% window width per user standards
            enter = true, -- Enter terminal on toggle
          },
        },
      },

      -- Events configuration
      reload_on_edit = true, -- Auto-reload buffer when opencode edits files
      events = {
        enabled = true,
        reload = true,
        permissions = {
          enabled = false, -- Disable permission UI to prevent prompts
        },
      },

      -- UI providers
      input_provider = "snacks",
      picker_provider = "snacks",

      -- Context configuration
      include_diagnostics = true,
      include_buffer = true,
      include_visible = true,

      -- Disable ALL default keymaps (prevent conflicts with Vim defaults)
      keys = {},
    }

    -- Enable autoread for buffer reloading
    vim.o.autoread = true
  end,
  config = function()
    -- Plugin loaded successfully
    -- Run :checkhealth opencode manually to verify configuration

    -- Register OpencodeCommands command (main artifact picker)
    vim.api.nvim_create_user_command("OpencodeCommands", function()
      require("neotex.plugins.ai.opencode.commands.picker").show_commands_picker()
    end, { desc = "Browse OpenCode commands, skills, agents, and extensions" })

    -- Register OpencodeExtensions command (extension management)
    vim.api.nvim_create_user_command("OpencodeExtensions", function()
      require("neotex.plugins.ai.opencode.extensions.picker").show()
    end, { desc = "Manage OpenCode extensions" })
  end,
  -- Disable default plugin keymaps at lazy.nvim level
  keys = {},
}
