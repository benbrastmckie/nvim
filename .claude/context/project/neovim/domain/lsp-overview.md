# Neovim LSP Overview

Built-in Language Server Protocol support in Neovim.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Neovim    │────▶│  LSP Client │────▶│  LS Server  │
│   Buffer    │◀────│  (built-in) │◀────│  (external) │
└─────────────┘     └─────────────┘     └─────────────┘
```

## Core Components

### nvim-lspconfig

Standard configurations for language servers:

```lua
{
  "neovim/nvim-lspconfig",
  config = function()
    local lspconfig = require("lspconfig")

    -- Configure lua_ls
    lspconfig.lua_ls.setup({
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim" } },
          workspace = { library = vim.api.nvim_get_runtime_file("", true) },
        },
      },
    })
  end,
}
```

### mason.nvim

LSP server installer:

```lua
{
  "williamboman/mason.nvim",
  build = ":MasonUpdate",
  config = function()
    require("mason").setup()
  end,
}
```

### mason-lspconfig.nvim

Bridge between mason and lspconfig:

```lua
{
  "williamboman/mason-lspconfig.nvim",
  dependencies = { "mason.nvim", "nvim-lspconfig" },
  config = function()
    require("mason-lspconfig").setup({
      ensure_installed = { "lua_ls", "pyright", "ts_ls" },
      automatic_installation = true,
    })
  end,
}
```

## LSP Keybindings

Standard keybindings pattern:

```lua
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local bufnr = args.buf
    local opts = { buffer = bufnr }

    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
    vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
    vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
    vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>f", function()
      vim.lsp.buf.format({ async = true })
    end, opts)
  end,
})
```

## Diagnostics

Configure diagnostic display:

```lua
vim.diagnostic.config({
  virtual_text = true,
  signs = true,
  underline = true,
  update_in_insert = false,
  severity_sort = true,
  float = {
    border = "rounded",
    source = "always",
  },
})
```

Diagnostic keybindings:

```lua
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next)
vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float)
vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist)
```

## Common Language Servers

| Language | Server | Config |
|----------|--------|--------|
| Lua | lua_ls | `lspconfig.lua_ls` |
| Python | pyright | `lspconfig.pyright` |
| TypeScript | ts_ls | `lspconfig.ts_ls` |
| Rust | rust_analyzer | `lspconfig.rust_analyzer` |
| Go | gopls | `lspconfig.gopls` |
| C/C++ | clangd | `lspconfig.clangd` |

## Capabilities

Enable additional LSP features:

```lua
local capabilities = vim.lsp.protocol.make_client_capabilities()

-- Add nvim-cmp capabilities
capabilities = require("cmp_nvim_lsp").default_capabilities(capabilities)

lspconfig.lua_ls.setup({
  capabilities = capabilities,
})
```

## Formatting

Format on save pattern:

```lua
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*",
  callback = function()
    vim.lsp.buf.format({ async = false })
  end,
})
```

## Debugging LSP

```vim
:LspInfo           " Show active clients
:LspLog            " Open LSP log
:LspRestart        " Restart LSP clients
:checkhealth lsp   " Health check
```

## none-ls (null-ls successor)

For tools without native LSP:

```lua
{
  "nvimtools/none-ls.nvim",
  config = function()
    local null_ls = require("null-ls")
    null_ls.setup({
      sources = {
        null_ls.builtins.formatting.stylua,
        null_ls.builtins.formatting.prettier,
        null_ls.builtins.diagnostics.eslint,
      },
    })
  end,
}
```
