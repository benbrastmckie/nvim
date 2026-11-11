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
    -- Only non-function options can go in vim.g (Neovim serializes vim.g to msgpack;
    -- functions are dropped silently). Server functions are set in config() below.
    vim.g.opencode_opts = {
      events = {
        enabled = true,
        reload = true,
        permissions = {
          enabled = false, -- Disable permission UI to prevent prompts
        },
      },
    }

    -- Enable autoread for buffer reloading
    vim.o.autoread = true
  end,
  config = function()
    -- Set server functions directly on opts (bypasses vim.g serialization limitation)
    local opts = require("opencode.config").opts

    local port = 3000 + (vim.fn.getpid() % 1000)
    local attach_cmd = "opencode --port " .. port
    local opencode_win_opts = {
      win = {
        position = "right",
        width = 0.40,
        enter = true,
      },
    }
    opts.server = {
      port = port,
      start = function()
        local term = require("snacks.terminal").get(attach_cmd, opencode_win_opts)
        if not term then
          require("snacks.terminal").open(attach_cmd, opencode_win_opts)
        end
      end,
      stop = function()
        local term = require("snacks.terminal").get(attach_cmd, opencode_win_opts)
        if term then term:close() end
      end,
      toggle = function()
        require("snacks.terminal").toggle(attach_cmd, opencode_win_opts)
      end,
    }

    -- Regenerate opencode.json on startup to ensure it reflects currently loaded extensions
    local ok_regen, regen_err = pcall(function()
      local merge_mod = require("neotex.plugins.ai.shared.extensions.merge")
      local ext_config_mod = require("neotex.plugins.ai.shared.extensions.config")
      local project_dir = vim.fn.getcwd()
      local cfg = ext_config_mod.opencode(project_dir)
      merge_mod.generate_opencode_json(project_dir, cfg)
    end)
    if not ok_regen then
      vim.schedule(function()
        vim.notify("Warning: opencode.json regeneration failed on startup: " .. tostring(regen_err), vim.log.levels.WARN)
      end)
    end

    -- Register OpencodeCommands command (main artifact picker)
    vim.api.nvim_create_user_command("OpencodeCommands", function()
      require("neotex.plugins.ai.opencode.commands.picker").show_commands_picker()
    end, { desc = "Browse OpenCode commands, skills, agents, and extensions" })

    -- Register OpencodeExtensions command (extension management)
    vim.api.nvim_create_user_command("OpencodeExtensions", function()
      require("neotex.plugins.ai.opencode.extensions.picker").show()
    end, { desc = "Manage OpenCode extensions" })

    -- Register OpenCodeLinkDiscord command (link session to Discord thread)
    vim.api.nvim_create_user_command("OpenCodeLinkDiscord", function()
      require("neotex.plugins.ai.opencode.discord-link").link_current_session()
    end, { desc = "Link current OpenCode session to Discord thread" })

    -- Register DiscordSessions command (browse linked Discord sessions)
    vim.api.nvim_create_user_command("DiscordSessions", function()
      require("neotex.plugins.ai.opencode.discord-session-picker").show()
    end, { desc = "Browse linked Discord sessions" })
  end,
  keys = {
    { "<leader>ar", "<cmd>OpenCodeLinkDiscord<CR>", desc = "link discord" },
    { "<leader>ad", "<cmd>DiscordSessions<CR>", desc = "discord sessions" },
  },
}
