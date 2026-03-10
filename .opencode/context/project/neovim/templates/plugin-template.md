# Plugin Specification Template

Boilerplate templates for lazy.nvim plugin specifications.

## Basic Plugin

```lua
-- lua/plugins/my-plugin.lua
return {
  "username/plugin-name",
  event = "VeryLazy",
  opts = {
    -- Plugin options
  },
}
```

## Plugin with Dependencies

```lua
return {
  "username/plugin-name",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  event = "VeryLazy",
  opts = {},
}
```

## Plugin with Keymaps

```lua
return {
  "username/plugin-name",
  keys = {
    { "<leader>px", "<cmd>PluginCommand<cr>", desc = "Plugin action" },
    { "<leader>py", function() require("plugin").action() end, desc = "Another action" },
  },
  opts = {},
}
```

## Plugin with Full Config

```lua
return {
  "username/plugin-name",
  dependencies = {
    "dep1/plugin",
  },
  event = { "BufReadPost", "BufNewFile" },
  keys = {
    { "<leader>xx", "<cmd>Cmd<cr>", desc = "Action" },
  },
  opts = {
    option1 = "value",
    option2 = true,
    nested = {
      key = "value",
    },
  },
  config = function(_, opts)
    require("plugin").setup(opts)
    -- Additional configuration
    vim.keymap.set("n", "<leader>xy", function()
      require("plugin").special_action()
    end, { desc = "Special action" })
  end,
}
```

## Colorscheme

```lua
return {
  "username/colorscheme",
  lazy = false,
  priority = 1000,
  config = function()
    require("colorscheme").setup({
      style = "dark",
    })
    vim.cmd.colorscheme("colorscheme-name")
  end,
}
```

## LSP Plugin

```lua
return {
  "username/lsp-plugin",
  dependencies = {
    "neovim/nvim-lspconfig",
  },
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    -- Attach to LSP attach event
    vim.api.nvim_create_autocmd("LspAttach", {
      callback = function(args)
        local bufnr = args.buf
        require("plugin").attach(bufnr)
      end,
    })
  end,
}
```

## Filetype-Specific Plugin

```lua
return {
  "username/lang-plugin",
  ft = { "python", "lua" },
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
  },
  opts = {
    -- Language-specific options
  },
}
```

## Command-Loaded Plugin

```lua
return {
  "username/tool-plugin",
  cmd = { "ToolOpen", "ToolRun" },
  keys = {
    { "<leader>to", "<cmd>ToolOpen<cr>", desc = "Open tool" },
  },
  opts = {},
}
```

## Development Plugin

```lua
return {
  dir = "~/projects/my-dev-plugin",
  name = "my-dev-plugin",
  dev = true,
  event = "VeryLazy",
  config = function()
    require("my-dev-plugin").setup()
  end,
}
```

## Optional/Conditional Plugin

```lua
return {
  "username/optional-plugin",
  enabled = function()
    return vim.fn.executable("external-tool") == 1
  end,
  cond = function()
    return not vim.g.vscode
  end,
  opts = {},
}
```

## Plugin with Build Step

```lua
return {
  "username/compiled-plugin",
  build = "make",
  -- or
  build = ":TSUpdate",
  -- or
  build = function()
    local ok, err = pcall(vim.cmd, "MakePlugin")
    if not ok then
      vim.notify("Build failed: " .. err, vim.log.levels.ERROR)
    end
  end,
  opts = {},
}
```

## Multiple Related Plugins

```lua
-- lua/plugins/completion.lua
return {
  -- Main completion engine
  {
    "hrsh7th/nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
        mapping = cmp.mapping.preset.insert({
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
        }),
      })
    end,
  },

  -- Snippet engine
  {
    "L3MON4D3/LuaSnip",
    lazy = true,
    dependencies = {
      "rafamadriz/friendly-snippets",
    },
    config = function()
      require("luasnip.loaders.from_vscode").lazy_load()
    end,
  },
}
```
