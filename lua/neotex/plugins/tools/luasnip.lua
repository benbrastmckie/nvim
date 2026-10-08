return {
  {
    "L3MON4D3/LuaSnip",
    version = "v2.3.0",  -- Pin to stable version that works with blink.cmp
    lazy = true,
    event = "InsertEnter",
    dependencies = {
      {
        "rafamadriz/friendly-snippets",
        config = function() end, -- Empty config to prevent auto-loading
      },
    },
    build = "make install_jsregexp", -- Important for NixOS
    config = function()
      -- Set all disabling flags before requiring luasnip
      vim.g.luasnip_no_community_snippets = true
      vim.g.luasnip_no_jsregexp = true
      vim.g.luasnip_no_vscode_loader = true

      -- Initialize LuaSnip with minimal configuration
      local ls = require("luasnip")
      ls.setup({
        history = true,
        update_events = "TextChanged,TextChangedI",
        enable_autosnippets = true,
        -- Store visual selection for use in snippets
        store_selection_keys = "<Tab>",
        -- Exit snippet on unmatched events
        ext_opts = {
          [require("luasnip.util.types").choiceNode] = {
            active = {
              virt_text = {{"●", "DiagnosticWarn"}},
            },
          },
        },
      })

      -- Load snippets immediately
      local ok, loader = pcall(require, "luasnip.loaders.from_snipmate")
      if ok and loader then
        loader.load({ paths = { vim.fn.stdpath("config") .. "/snippets" } })
      end
      
      -- Setup region check events for better snippet interaction
      ls.config.set_config({
        region_check_events = "CursorMoved,CursorMovedI",
        delete_check_events = "TextChanged,TextChangedI",
      })

      -- Let blink.cmp handle Tab navigation primarily
      -- Only set up select mode mapping for when snippet placeholders are selected
      vim.keymap.set("s", "<Tab>", function()
        if ls.jumpable(1) then
          ls.jump(1)
        else
          -- Feed Tab key to let it behave normally
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
        end
      end, { silent = true, desc = "Jump to next snippet placeholder" })
      
      vim.keymap.set("s", "<S-Tab>", function()
        if ls.jumpable(-1) then
          ls.jump(-1)
        else
          -- Feed S-Tab key to let it behave normally
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<S-Tab>", true, false, true), "n", false)
        end
      end, { silent = true, desc = "Jump to previous snippet placeholder" })

      -- Clear snippet jump points when leaving insert mode
      vim.api.nvim_create_autocmd("InsertLeave", {
        callback = function()
          if ls.session.current_nodes[vim.api.nvim_get_current_buf()] 
            and not ls.session.jump_active then
            ls.unlink_current()
          end
        end,
      })
      
      -- Debug command to check snippet state
      vim.api.nvim_create_user_command("LuaSnipInfo", function()
        local info = {
          in_snippet = ls.in_snippet(),
          jumpable_forward = ls.jumpable(1),
          jumpable_backward = ls.jumpable(-1),
          active_node = ls.session.current_nodes[vim.api.nvim_get_current_buf()] and "yes" or "no",
          mode = vim.fn.mode()
        }
        print(vim.inspect(info))
      end, {})
    end
  }
}
