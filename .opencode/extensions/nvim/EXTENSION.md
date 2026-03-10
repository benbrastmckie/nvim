## Neovim Extension

This project includes Neovim configuration development support via the nvim extension.

### Language Routing

| Language | Research Skill | Implementation Skill | Tools |
|----------|----------------|---------------------|-------|
| `neovim` | `skill-neovim-research` | `skill-neovim-implementation` | WebSearch, WebFetch, Read, Bash (nvim --headless) |

### Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-neovim-research | neovim-research-agent | opus | Neovim/plugin research |
| skill-neovim-implementation | neovim-implementation-agent | - | Neovim configuration implementation |

### Rules

- neovim-lua.md - Neovim Lua development (lua/**/*.lua, after/**/*.lua)

### Neovim Patterns

- Use `vim.keymap.set` with description for all keymaps
- Use `vim.opt` over `vim.o` for options
- Always use augroups with `clear = true` for autocommands
- Use `pcall` for optional module loading

### Common Operations

- **Keymaps**: `vim.keymap.set("n", "<leader>x", fn, { desc = "Description" })`
- **Options**: `vim.opt.number = true`
- **Autocommands**: `vim.api.nvim_create_augroup("Name", { clear = true })`
- **Plugin specs**: lazy.nvim table format with event/cmd/ft/keys triggers

### Context Imports

Domain knowledge (load as needed):
- @.opencode/context/project/neovim/domain/neovim-api.md
- @.opencode/context/project/neovim/patterns/plugin-spec.md
- @.opencode/context/project/neovim/tools/lazy-nvim-guide.md
