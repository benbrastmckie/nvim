# Neovim Configuration Project Context

## Project Overview

**Neotex** is a comprehensive Neovim configuration for LaTeX/academic writing with Lua-based configuration, lazy.nvim plugin management, and extensive customization for technical writing workflows.

**Purpose**: Provide a productive Neovim environment optimized for academic writing, LaTeX document preparation, and general software development.

**Repository**: ~/.config/nvim

## Technology Stack

**Primary Language:** Lua (Neovim Lua API)
**Plugin Manager:** lazy.nvim
**LSP Support:** Native Neovim LSP with nvim-lspconfig
**Completion:** nvim-cmp with multiple sources
**File Navigation:** Telescope.nvim
**Syntax Highlighting:** Tree-sitter

## Project Structure

```
nvim/                      # Main configuration
  init.lua                # Entry point
  lua/                    # Lua modules
    neotex/              # Main namespace
      core/              # Core configuration
        options.lua      # Editor options
        keymaps.lua      # Key mappings
        autocmds.lua     # Autocommands
      plugins/           # Plugin specifications
        lsp/             # LSP configurations
        completion/      # Completion setup
        editing/         # Editing enhancements
        ui/              # UI components
        tools/           # Development tools
      utils/             # Utility functions
  after/                 # Filetype-specific overrides
    ftplugin/           # Filetype plugins
      tex.lua           # LaTeX settings
      markdown.lua      # Markdown settings
      lua.lua           # Lua settings
  plugin/               # Auto-loaded plugins
    neotex.lua         # Configuration initialization

docs/                    # Project documentation
  README.md             # Usage guide
  ARCHITECTURE.md       # Architecture overview
  CODE_STANDARDS.md     # Coding conventions

.opencode/              # AI agent system
  agent/                # Primary agents + specialists
  commands/             # Slash commands
  context/              # Knowledge base for agents
  specs/                # Project artifacts (plans, reports)
```

## Core Architecture

### lazy.nvim Plugin System

**Plugin Specifications**: Located in `lua/neotex/plugins/`
- One file per plugin group (lsp.lua, completion.lua, etc.)
- Return table of plugin specs
- Use event-based lazy loading

**Lazy Loading Strategy**:
- `event = "VeryLazy"` - Most plugins
- `ft = "tex"` - LaTeX-specific
- `cmd = "Command"` - Command-triggered
- `keys = {...}` - Key-triggered

### Configuration Layers

| Layer | Location | Purpose |
|-------|----------|---------|
| Core | `lua/neotex/core/` | Base options, keymaps, autocmds |
| Plugins | `lua/neotex/plugins/` | Plugin specifications |
| Filetype | `after/ftplugin/` | Language-specific settings |
| Utils | `lua/neotex/utils/` | Shared utilities |

## Development Workflow

### Standard Neovim Development

1. **Research**: Explore plugin documentation, Neovim API
2. **Design**: Plan plugin configuration, keymaps
3. **Implementation**: Write Lua configuration
4. **Validation**: Test with `nvim --headless`
5. **Documentation**: Update inline comments

### AI-Assisted Workflow

1. **Research**: `/research` - Plugin docs, Neovim API
2. **Planning**: `/plan` - Create implementation plans
3. **Implementation**: `/implement` - Execute configuration changes
4. **Review**: `/review` - Analyze configuration quality

## Quality Standards

### Lua Code Quality

- **Style**: Follow lua-style-guide.md
- **Module Structure**: Use local M = {} pattern
- **Error Handling**: Use pcall for optional requires
- **Documentation**: Inline comments for complex logic
- **Naming**: snake_case for variables/functions

### Plugin Specifications

```lua
-- Standard plugin spec
{
  'owner/plugin',
  dependencies = { 'dep1' },
  event = 'VeryLazy',
  config = function()
    require('plugin').setup({
      -- options
    })
  end,
}
```

### Keymap Conventions

```lua
-- Always include description
vim.keymap.set('n', '<leader>x', function()
  -- action
end, { desc = 'Action description' })
```

### Build Requirements

- Configuration loads without errors: `nvim --headless -c 'qa!'`
- Lua syntax valid: `luac -p file.lua`
- Checkhealth passes: `:checkhealth`

## Key Files

**Core Configuration**:
- `init.lua` - Entry point, loads neotex
- `lua/neotex/init.lua` - Main module initialization
- `lua/neotex/core/options.lua` - Editor options
- `lua/neotex/core/keymaps.lua` - Key mappings

**Plugin Management**:
- `lua/neotex/plugins/` - Plugin specifications
- `lazy-lock.json` - Plugin version lock

**LSP Configuration**:
- `lua/neotex/plugins/lsp/init.lua` - LSP setup
- `lua/neotex/plugins/lsp/servers/` - Per-server configs

## Common Commands

**Validation**:
```bash
# Validate configuration loads
nvim --headless -c 'qa!'

# Validate Lua syntax
luac -p lua/neotex/plugins/example.lua

# Run checkhealth
nvim --headless -c 'checkhealth' -c 'qa!'
```

**Development**:
```bash
# Clear plugin cache
rm -rf ~/.local/share/nvim/lazy

# Update plugins
nvim --headless "+Lazy! sync" +qa

# Check for errors
nvim --headless -c 'lua print(vim.inspect(vim.diagnostic.get(0)))' -c 'qa!'
```

**AI System**:
```bash
# See .opencode/README.md for all AI commands
/research <topic>            # Research plugins and patterns
/plan <task>                 # Create implementation plan
/implement <nums>            # Execute configuration changes
/review                      # Analyze configuration quality
```

## Related Resources

**Documentation**:
- [Neovim Lua Guide](https://neovim.io/doc/user/lua-guide.html)
- [lazy.nvim](https://github.com/folke/lazy.nvim)
- [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)

**AI System**:
- [.opencode/README.md](../../README.md) - AI system overview
- [.opencode/OPENCODE.md](../../OPENCODE.md) - Configuration reference
- [.opencode/docs/guides/user-guide.md](../../docs/guides/user-guide.md) - User guide
