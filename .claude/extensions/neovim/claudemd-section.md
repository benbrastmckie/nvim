## Neovim Extension

This project includes Neovim configuration development support via the neovim extension.

### Language Routing

| Language | Research Tools | Implementation Tools |
|----------|----------------|---------------------|
| `neovim` | WebSearch, WebFetch, Read | Read, Write, Edit, Bash (nvim --headless) |

### Skill-Agent Mapping

| Skill | Agent | Purpose |
|-------|-------|---------|
| skill-neovim-research | neovim-research-agent | Neovim/plugin research |
| skill-neovim-implementation | neovim-implementation-agent | Neovim configuration implementation |

### Coding Standards

- Lua indentation: 2 spaces
- Module pattern: `local M = {}` with `return M`
- Use `vim.keymap.set` with descriptions
- Use `vim.opt` over `vim.o`
- Always use augroups with `clear = true`
- Use `pcall` for optional module loading

### Plugin Specifications

lazy.nvim format with lazy loading conditions:
- `event` for buffer/mode events
- `cmd` for commands
- `ft` for filetypes
- `keys` for key mappings
