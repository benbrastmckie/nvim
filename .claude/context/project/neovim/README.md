# Neovim Context

Domain knowledge for Neovim configuration development.

## Directory Structure

```
project/neovim/
├── README.md           # This file
├── domain/             # Core Neovim concepts
│   ├── lua-patterns.md
│   ├── plugin-ecosystem.md
│   ├── lsp-overview.md
│   └── neovim-api.md
├── patterns/           # Common implementation patterns
│   ├── plugin-spec.md
│   ├── keymap-patterns.md
│   ├── autocommand-patterns.md
│   └── ftplugin-patterns.md
├── standards/          # Coding conventions
│   ├── lua-style-guide.md
│   └── testing-patterns.md
├── tools/              # Tool-specific guides
│   ├── lazy-nvim-guide.md
│   ├── treesitter-guide.md
│   └── telescope-guide.md
└── templates/          # Boilerplate templates
    ├── plugin-template.md
    └── ftplugin-template.md
```

## Loading Strategy

**Always load first**:
- This README for overview
- `domain/neovim-api.md` for vim.* API patterns

**Load for plugin work**:
- `patterns/plugin-spec.md` for lazy.nvim specs
- `tools/lazy-nvim-guide.md` for lazy.nvim features

**Load for keymapping**:
- `patterns/keymap-patterns.md` for vim.keymap.set
- References to which-key if using that plugin

**Load for autocmds**:
- `patterns/autocommand-patterns.md` for vim.api.nvim_create_autocmd

**Load for filetype work**:
- `patterns/ftplugin-patterns.md` for after/ftplugin structure

## Configuration Assumptions

This context assumes:
- Neovim 0.9+ (stable API features)
- lazy.nvim as plugin manager
- Lua-based configuration (not vimscript)
- Standard XDG paths (~/.config/nvim)

## Key Concepts

### Plugin Manager: lazy.nvim

lazy.nvim is the recommended plugin manager providing:
- Lazy loading by event, command, filetype
- Automatic dependency resolution
- UI for plugin management
- Lockfile for reproducibility

### LSP Integration

Neovim has built-in LSP support via:
- nvim-lspconfig for server configuration
- mason.nvim for LSP server installation
- Built-in vim.lsp.* API

### Tree-sitter

Native tree-sitter support provides:
- Syntax highlighting
- Code folding
- Incremental selection
- Text objects

## Agent Context Loading

Agents should load context based on task type:

| Task Type | Required Context |
|-----------|-----------------|
| New plugin | plugin-spec.md, plugin-template.md |
| Keybinding | keymap-patterns.md |
| Autocmd | autocommand-patterns.md |
| Filetype | ftplugin-patterns.md, ftplugin-template.md |
| LSP setup | lsp-overview.md |
| General | neovim-api.md, lua-style-guide.md |
