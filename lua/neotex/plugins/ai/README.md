# AI Plugins

This directory contains all AI-related plugin configurations and integrations for the Neovim setup.

## Purpose

The AI plugins directory organizes artificial intelligence tools and assistants, providing a centralized location for AI-powered development assistance, code generation, and intelligent editing capabilities.

## Modules

### init.lua
Main entry point that loads and returns all AI plugin specifications. Includes error handling for safe module loading and validates plugin specs before returning them to lazy.nvim.

### avante.lua
Configuration for the Avante AI assistant plugin (`yetone/avante.nvim`). Provides multiple AI provider support (Claude, GPT, Gemini), MCP-Hub integration, system prompt management, and UI enhancements with inline suggestions.

### claudecode.lua
External plugin configuration wrapper for `greggh/claude-code.nvim`. Manages window settings, file refresh detection, git integration, shell configuration, and terminal behavior. Bridges the external plugin with the internal Claude system.

**Buffer Management**: Uses precise terminal-specific pattern matching to unlist only Claude Code terminal buffers while preserving normal file buffers (including .claude/ directory files). The autocmd checks `buftype == "terminal"` before pattern matching to avoid false positives. See [specs/reports/038_buffer_persistence_root_cause.md](../../../specs/reports/038_buffer_persistence_root_cause.md) for details.

### mcp-hub.lua
MCP-Hub integration plugin configuration (`mcp-hub`) with cross-platform compatibility. Provides automatic installation method detection, clean Avante integration with lazy loading, and fallback to bundled installation when needed.

### lectic.lua
Configuration for the Lectic plugin (`gleachkr/lectic`) for markdown editing and management. Handles markdown and lectic.markdown filetypes with dependency installation and runtime path configuration.

### sapience-plugin.lua
lazy.nvim virtual plugin spec for sf1, the Sapience terminal chat client. Points `dir` at the
sibling `sapience/` implementation directory, registers the `:Sf1` toggle command, and supplies
the module's `on_open` hook, which hides a visible Claude Code or OpenCode window so sf1 takes
the split rather than sharing the screen with a coding agent. See
[sapience/](sapience/README.md) for the full module and configuration documentation.

### opencode.lua
Configuration for the OpenCode plugin (`NickvanDyke/opencode.nvim`). Provides embedded TUI experience for the OpenCode CLI with powerful context placeholders (@this, @buffer, @diagnostics), built-in prompt library, and statusline integration.

**Key Features**:
- Context placeholders for granular control (@this, @buffer, @diagnostics, @visible, @diff, @grapple)
- Built-in prompt library (9 prompts: diagnostics, diff, document, explain, fix, implement, optimize, review, test)
- Embedded TUI rendering within Neovim terminal
- Automatic buffer reloading when OpenCode edits files
- Session management with persistence

**Configuration**:
- Provider: snacks.nvim for UI components
- Terminal window: right side, 40% width (user standard)
- All default keymaps disabled to prevent conflicts
- Custom keymaps defined in which-key.lua and keymaps.lua

**Dependencies**:
- `folke/snacks.nvim` (required) - UI provider for terminal, input, and picker
- `cbochs/grapple.nvim` (optional) - For @grapple context placeholder
- OpenCode CLI v0.9.1+ (currently using v1.0.119)

## Subdirectories

- [claude/](claude/README.md) - Comprehensive internal Claude AI integration system (9,626+ lines across 20 files)
- [sapience/](sapience/README.md) - sf1 Sapience terminal chat integration

## Key Features

### AI Assistant Integration
- **Multiple AI providers** - Claude, GPT, Gemini support through Avante
- **Visual selection prompting** - Send selected code to Claude with custom prompts (`<leader>ac` in visual mode)
- **Smart session management** - Context-aware Claude sessions with persistence
- **MCP protocol support** - Tool communication and custom prompt systems

### Development Workflow
- **Git worktree integration** - Isolated development environments with AI context
- **Terminal detection** - Multi-terminal support (Kitty, WezTerm, Alacritty)
- **File change detection** - Automatic refresh and context updates
- **Session persistence** - Save and restore AI conversation state

### User Interface
- **Which-key integration** - Organized keybindings under `<leader>a` namespace
- **Telescope pickers** - Session browsing and command selection
- **Progress notifications** - User feedback during AI operations
- **Error handling** - Comprehensive validation and user-friendly messages

## Usage Examples

### Visual Selection with Claude
```vim
" Select code in visual mode
v}
" Send to Claude with custom prompt
<leader>ac
" Enter prompt: "Please explain this function"
```

### AI Assistant Commands
```vim
:AvanteAsk           " Ask Avante AI assistant
:ClaudeCommands      " Browse Claude command hierarchy
:ClaudeSessions      " Open Claude session browser
:MCPHub              " Launch MCP-Hub interface
:Opencode toggle     " Toggle OpenCode TUI interface
:checkhealth opencode " Run OpenCode health check
```

### OpenCode Context Placeholders
```vim
" Use context placeholders in prompts for granular control
" Example 1: Fix errors using diagnostics
"Fix errors in @this using @diagnostics"

" Example 2: Explain selected code with buffer context
(visual select code)
<leader>aoa
"Explain @this in the context of @buffer"

" Example 3: Review changes using git diff
"Review the changes in @diff and suggest improvements"

" Available placeholders:
" @this        - Current visual selection or cursor position
" @buffer      - Current buffer content
" @buffers     - All open buffers
" @visible     - Visible text on screen
" @diagnostics - Current buffer diagnostics
" @quickfix    - Quickfix list entries
" @diff        - Git diff of current file
" @grapple     - Grapple-tagged files (if grapple.nvim installed)
```

### Session Management
```lua
local ai = require("neotex.plugins.ai.claude")
ai.smart_toggle()                    -- Smart Claude toggle
ai.create_worktree_with_claude(opts) -- Create isolated dev environment
ai.send_visual_to_claude_with_prompt() -- Visual selection with prompt
```

## Configuration

### Keybindings (in which-key.lua and keymaps.lua)

**Global AI Toggles** (defined in keymaps.lua):
- `<C-CR>` - Unified AI smart toggle (all modes):
  - Nothing running → opens Stage 1 agent picker (ClaudeCode / OpenCode)
  - One tool running → toggles that tool's window (show/hide)
  - Both tools running → cycles: just OpenCode → just Claude → neither → just OpenCode → …
- `<C-g>` - Toggle OpenCode interface (all modes)

**Leader-based AI Commands** (defined in which-key.lua):
- `<leader>a` - AI tools group
- `<leader>ac` - AI agent picker (Stage 1: choose tool, then session action)
- `<leader>al` - Load AI commands/agents picker
- `<leader>ad` - Discord sessions
- `<leader>ai` - OpenCode info (send diagnostics as context)
- `<leader>as` - Toggle sf1 Sapience chat (hides a visible coding agent)
- `<leader>ay` - Toggle Claude yolo mode (skip permissions)

**OpenCode Commands** (`<leader>ao` submenu):
- `<leader>aoo` - Toggle OpenCode interface
- `<leader>aoa` - Ask with context (normal/visual mode)
- `<leader>aos` - Select action from prompt library
- `<leader>aop` - Add context to prompt (normal/visual mode)
- `<leader>aob` - Inject buffer context (@buffer)
- `<leader>aod` - Inject diagnostics context (@diagnostics)
- `<leader>aon` - Create new session
- `<leader>aol` - List sessions

**Lectic Commands** (`<leader>al`, `<leader>an`, `<leader>ak`):
- Only active in .lec and .md files

### Plugin Dependencies
- `nvim-lua/plenary.nvim` - Lua utilities
- `nvim-telescope/telescope.nvim` - UI pickers
- `folke/which-key.nvim` - Keybinding management
- External AI services (Claude API, OpenAI, etc.)

## Architecture

### Separation of Concerns
```
External Plugin Configs (ai/*.lua) ──→ Internal Systems (ai/claude/)
         │                                    │
         ├─ Plugin management                 ├─ Business logic
         ├─ Configuration bridging            ├─ Session management
         └─ Initialization orchestration      └─ Feature implementation
```

### Integration Flow
1. **Plugin Loading** - lazy.nvim loads plugin specifications from ai/*.lua
2. **Configuration** - External plugins configured with options and keymaps
3. **Internal System** - Advanced features implemented in ai/claude/ directory
4. **User Interface** - Which-key provides organized command access

## Troubleshooting

### Plugin Loading Issues
- Check `:lazy` for plugin status and errors
- Verify dependencies are installed: `:checkhealth`
- Test individual plugins: `:lua require('neotex.plugins.ai.avante')`

### OpenCode Issues
- Run health check: `:checkhealth opencode`
- Verify OpenCode CLI version: `opencode --version` (requires v0.9.1+, currently using v1.0.119)
- Check snacks.nvim dependency: `:Lazy` and search for "snacks"
- Buffer auto-reload not working: Verify `vim.o.autoread = true` is set
- Default keymaps still active: Verify `keys = {}` in plugin spec and `vim.g.opencode_opts.keys = {}`
- Provider configuration: Ensure snacks.nvim is loaded with `input`, `picker`, and `terminal` options
- Terminal not opening: Check `:messages` for errors, verify window position/width settings

### AI Service Connectivity
- Verify API keys and authentication
- Check network connectivity for external services
- Test with `:ClaudeCommands` or `:AvanteAsk`
- OpenCode CLI: Ensure opencode CLI is authenticated and functional in terminal

### Keybinding Conflicts
- Verify which-key configuration: `:lua print(require('which-key'))`
- Check for duplicate mappings in visual vs normal mode
- Test mappings with `:map <leader>a`
- Verify `<C-o>` OpenCode toggle doesn't conflict with Vim's jump-back command (jump-back preserved in normal mode)

## Navigation
- [← Parent Directory](../README.md) - Plugins overview
- [Claude System](claude/README.md) - Comprehensive Claude AI integration
- [Plugin Configurations](../../../README.md) - Main configuration documentation