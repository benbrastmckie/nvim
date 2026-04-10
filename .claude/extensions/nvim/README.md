# Nvim Extension

Neovim configuration development support for this repository itself. Provides research and implementation agents for Lua-based Neovim configuration work with lazy.nvim, plugin specs, keymaps, autocommands, and the neotex module hierarchy. This is the highest-traffic extension because the repository IS a Neovim configuration.

## Overview

| Task Type | Agent | Purpose |
|-----------|-------|---------|
| `neovim` | neovim-research-agent | Neovim/plugin/Lua research |
| `neovim` | neovim-implementation-agent | Neovim configuration implementation |

The extension applies the `neovim-lua.md` rule file to all `.lua` source files and loads Neovim-specific domain knowledge on demand.

## Installation

Loaded via `<leader>ac` in Neovim. Since the repository itself is a Neovim configuration, this extension is typically auto-loaded during development sessions.

## Commands

This extension provides no commands of its own. Use the core `/research`, `/plan`, and `/implement` commands with tasks typed as `neovim`.

## Architecture

```
nvim/
├── manifest.json              # Extension configuration
├── EXTENSION.md               # CLAUDE.md merge content
├── index-entries.json         # Context discovery entries
├── README.md                  # This file
│
├── skills/
│   ├── skill-neovim-research/       # Research wrapper
│   └── skill-neovim-implementation/ # Implementation wrapper
│
├── agents/
│   ├── neovim-research-agent.md     # Research agent (opus model)
│   └── neovim-implementation-agent.md # Implementation agent
│
├── rules/
│   └── neovim-lua.md          # Auto-applied to lua/**/*.lua and after/**/*.lua
│
└── context/
    └── project/
        └── neovim/
            ├── domain/        # Neovim API reference, plugin patterns
            ├── patterns/      # plugin-spec, keymap, autocommand patterns
            ├── standards/     # Coding conventions for this repo
            └── tools/         # lazy.nvim, telescope, plenary guides
```

## Skill-Agent Mapping

| Skill | Agent | Model | Purpose |
|-------|-------|-------|---------|
| skill-neovim-research | neovim-research-agent | opus | Neovim/plugin/Lua research |
| skill-neovim-implementation | neovim-implementation-agent | - | Neovim configuration implementation |

## Language Routing

| Task Type | Research Skill | Implementation Skill | Tools |
|-----------|----------------|---------------------|-------|
| `neovim` | skill-neovim-research | skill-neovim-implementation | WebSearch, WebFetch, Read, Write, Edit, Bash(nvim --headless) |

## Workflow

```
/research <task>            (task_type: neovim)
    |
    v
skill-neovim-research -> neovim-research-agent
    |  (web search for plugin docs, codebase exploration, pattern lookup)
    v
specs/{NNN}_{SLUG}/reports/MM_{slug}.md
    |
    v
/plan <task>
    |
    v
specs/{NNN}_{SLUG}/plans/MM_{slug}.md
    |
    v
/implement <task>
    |
    v
skill-neovim-implementation -> neovim-implementation-agent
    |  (edits lua/**/*.lua files, runs headless nvim checks)
    v
specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md
```

## Output Artifacts

| Phase | Artifact |
|-------|----------|
| Research | `specs/{NNN}_{SLUG}/reports/MM_{slug}.md` |
| Plan | `specs/{NNN}_{SLUG}/plans/MM_{slug}.md` |
| Implementation | `lua/neotex/**/*.lua` edits plus `specs/{NNN}_{SLUG}/summaries/MM_{slug}-summary.md` |

## Key Patterns

### Plugin Specs (lazy.nvim)

Plugin specs live under `lua/neotex/plugins/` and follow the lazy.nvim table format with lazy-loading triggers:

```lua
return {
  "author/plugin.nvim",
  event = "VeryLazy",       -- or BufReadPre, CmdlineEnter, etc.
  cmd = "CommandName",      -- load on command
  ft = { "lua", "python" }, -- load on filetype
  keys = { ... },           -- load on keymap
  config = function()
    require("plugin").setup({ ... })
  end,
}
```

### Keymaps

Always use `vim.keymap.set` with a description:

```lua
vim.keymap.set("n", "<leader>x", function()
  -- action
end, { desc = "Description for which-key" })
```

### Options

Prefer `vim.opt` over `vim.o`:

```lua
vim.opt.number = true
vim.opt.shiftwidth = 2
```

### Autocommands

Always use an augroup with `clear = true`:

```lua
local group = vim.api.nvim_create_augroup("MyGroup", { clear = true })
vim.api.nvim_create_autocmd("BufReadPost", {
  group = group,
  pattern = "*.lua",
  callback = function() ... end,
})
```

### pcall for Optional Modules

Wrap optional plugin requires in `pcall` so missing plugins degrade gracefully:

```lua
local ok, plugin = pcall(require, "plugin")
if not ok then return end
```

### Module Namespaces

All custom Lua modules live under `neotex.` (core, plugins, util). The `core/` namespace contains always-loaded setup code; `plugins/` contains lazy-loadable specs; `util/` contains shared helpers.

## Rules Applied

- `neovim-lua.md` - auto-applied to `lua/**/*.lua` and `after/**/*.lua`
  - Enforces `vim.keymap.set` with `desc`
  - Enforces `vim.opt` over `vim.o`
  - Enforces augroups with `clear = true` for autocommands
  - Enforces `pcall` for optional module loading

## Test Protocols

The repository uses `vim-test` plus plenary.nvim for Lua unit tests. See the root `nvim/CLAUDE.md` for the full testing standards.

**Test commands**:
- `:TestNearest` - test at cursor
- `:TestFile` - current file
- `:TestSuite` - all tests
- `:TestLast` - re-run

**Test file patterns**:
- `*_spec.lua`
- `test_*.lua`
- Located in `tests/` or adjacent to source

## Context References

- `@.claude/extensions/nvim/context/project/neovim/domain/neovim-api.md`
- `@.claude/extensions/nvim/context/project/neovim/patterns/plugin-spec.md`
- `@.claude/extensions/nvim/context/project/neovim/tools/lazy-nvim-guide.md`

## References

- [Neovim Lua API](https://neovim.io/doc/user/lua.html)
- [lazy.nvim](https://github.com/folke/lazy.nvim)
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [vim-test](https://github.com/vim-test/vim-test)
