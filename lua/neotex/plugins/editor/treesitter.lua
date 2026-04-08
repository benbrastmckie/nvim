return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    event = { "BufReadPost", "BufNewFile" },
    build = ":TSUpdate",
    config = function()
      -- Parsers to auto-install
      local parsers = {
        "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline",
        "python", "bash", "nix", "json", "yaml", "toml", "gitignore",
        "c", "haskell", "css", "html", "javascript", "scss", "regex",
        "typst", "astro", "typescript", "tsx",
      }

      -- Filetypes to disable treesitter for
      local disabled_filetypes = {
        plaintex = true, tex = true, context = true, bibtex = true,
      }

      -- Enable treesitter highlighting and indentation for supported filetypes
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("TreesitterSetup", { clear = true }),
        callback = function(args)
          local ft = vim.bo[args.buf].filetype

          -- Skip disabled filetypes
          if disabled_filetypes[ft] then
            vim.opt_local.syntax = "on"
            return
          end

          -- Try to start treesitter highlighting
          pcall(vim.treesitter.start, args.buf)

          -- Enable treesitter indentation
          pcall(function()
            vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end)
        end,
      })

      -- Enable treesitter-based folding
      vim.opt.foldmethod = "expr"
      vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
      vim.opt.foldlevel = 99

      -- Auto-install parsers
      vim.defer_fn(function()
        for _, lang in ipairs(parsers) do
          local ok = pcall(vim.treesitter.language.inspect, lang)
          if not ok then
            pcall(function()
              vim.cmd("TSInstall! " .. lang)
            end)
          end
        end
      end, 100)
    end,
  },

  {
    "JoosepAlviste/nvim-ts-context-commentstring",
    lazy = true,
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("ts_context_commentstring").setup({
        enable_autocmd = false,
      })
    end,
  },

  {
    "windwp/nvim-ts-autotag",
    lazy = true,
    ft = { "html", "xml", "jsx", "tsx", "vue", "svelte", "php", "markdown", "astro" },
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    opts = {
      opts = {
        enable_close = true,
        enable_rename = true,
        enable_close_on_slash = false,
      },
    },
  }
}
