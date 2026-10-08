# NeoVim Configuration

A feature-rich Neovim configuration with AI integration optimized for LaTeX, Markdown, Jupyter Notebooks, and managing NixOS.

> **Looking for a user-friendly alternative?** See the [Zed Configuration](https://github.com/benbrastmckie/zed) for a more approachable editor setup that requires less initial investment than NeoVim.

This setup provides a streamlined environment for academic writing, code development, and system management.
The AI integration makes it easy to learn and configure this setup for your specific needs.
Every subdirectory includes a `README.md` file which documents the modules contained in that directory.

## Installation

**Recommended**: See the [Claude Code-Assisted Installation Guide](docs/CLAUDE_CODE_INSTALL.md) for AI-powered setup assistance that automates dependency checking, troubleshooting, and configuration validation.

**Migrating from Existing Config**: See the [Migration Guide](docs/MIGRATION_GUIDE.md) for systematic instructions on moving from your current Neovim setup while preserving your customizations, keybindings, and preferences.

**Traditional Setup**: See the [Installation Guide](docs/INSTALLATION.md) for manual step-by-step setup instructions, including how to fork the repository, install dependencies, and run health checks.

**Want to customize notifications?** See the [Notification System Documentation](docs/NOTIFICATIONS.md) for configuring notification behavior across all modules and plugins.

## File Structure

```
nvim/
├── init.lua              # Main configuration entry point
├── lazy-lock.json        # Plugin version lockfile
├── CLAUDE.md             # Project guidelines and policies
├── after/                # Post-load configurations
│   ├── ftdetect/         # File type detection rules
│   └── ftplugin/         # File type specific settings
├── lua/neotex/           # Main configuration modules
│   ├── bootstrap.lua     # Plugin system initialization
│   ├── config/           # Core Neovim settings
│   ├── plugins/          # Plugin configurations
│   └── util/             # Utility functions
├── templates/            # Document templates
│   ├── *.tex             # LaTeX templates
│   ├── report/           # Multi-chapter documents
│   └── springer/         # Publisher templates
├── snippets/             # Code snippet collections
├── scripts/              # Maintenance utilities
├── sessions/             # Saved editor sessions
└── spell/                # Custom spell check dictionaries
```

## Features Overview

This Neovim configuration includes specialized support for:

- **LaTeX Editing**: Comprehensive LaTeX support through VimTeX with custom templates, PDF viewing, citation management, LaTeX-specific text surrounds, and more
- **Markdown Writing**: Enhanced Markdown editing with smart list handling, checkboxes, markdown-specific text surrounds, and live preview
- **AI Assistance**: Multiple AI integration options for code completion and development workflows:
  - [Claude Code](lua/neotex/plugins/ai/claude/README.md) - Primary AI integration with session management and worktree support
  - [OpenCode](lua/neotex/plugins/ai/README.md#opencode) - Alternative AI TUI with context placeholders
  - [Lectic](lua/neotex/plugins/ai/README.md#lectic) - AI-assisted writing for markdown files
- **Jupyter Notebooks**: Interactive notebook support with cell execution, navigation, and conversion between formats
- **NixOS Management**: Convenient commands for managing NixOS configurations, packages, and updates
- **Development Tools**: LSP configuration, syntax highlighting, Git integration, and diagnostics
- **Session Management**: Save and restore editing sessions with persistent workspaces
- **File Navigation**: Telescope integration for fuzzy finding, project navigation, and more
- **Code Operations**: LSP-powered code actions, diagnostics, and reference exploration
- **Unified Notifications**: Intelligent notification system with category-based filtering and module-specific controls
- **Performance Optimized**: Fast startup with optimized lazy-loading and efficient autocmd configuration

### Dashboard Overview

NeoVim will open with the dashboard which includes the following options:

| Key | Description                                           |
|-----|-------------------------------------------------------|
| `s` | Restore Session - Load a saved session                |
| `r` | Recent Files - Browse and open recently edited files  |
| `e` | Explorer - Toggle the NvimTree file explorer          |
| `f` | Find File - Search for files in your project          |
| `g` | Find Text - Search for text content across files      |
| `n` | New File - Create and start editing a new file        |
| `c` | Config - Browse Neovim configuration files            |
| `i` | Info - View Neovim configuration information          |
| `m` | Manage Plugins - Open the Lazy plugin manager         |
| `h` | Checkhealth - Run Neovim's health diagnostics         |
| `q` | Quit - Exit Neovim                                    |

The dashboard provides quick access to common actions and makes it easy to start working on your projects such as:
- Resume previous work in a session
- Navigate recent files
- Start new projects
- Access configuration
- Manage your Neovim setup

Press the corresponding key to activate any option, or use your mouse to click on the desired action.

### Prerequisites

This configuration requires several dependencies including Neovim (≥ 0.9.0), Git, Node.js, Python 3, and the `uv` package manager for MCP-Hub AI integration. 

**For complete installation requirements and step-by-step setup instructions, see the [Installation Guide](docs/INSTALLATION.md).**

## Documentation Structure

This configuration features comprehensive documentation following [DOCUMENTATION_STANDARDS.md](docs/DOCUMENTATION_STANDARDS.md). Every directory contains a README.md with detailed information about its purpose, components, and usage.

### Central Documentation (docs/)

Topic-focused documentation covering major systems and workflows:

- **[Architecture](docs/ARCHITECTURE.md)** - System design, initialization flow, and component architecture
- **[Installation](docs/INSTALLATION.md)** - Setup instructions, dependencies, and health checks
- **[Mappings](docs/MAPPINGS.md)** - Complete keybinding reference organized by context
- **[AI Tooling](docs/AI_TOOLING.md)** - Git worktrees with OpenCode for parallel development
- **[Research Tooling](docs/RESEARCH_TOOLING.md)** - LaTeX, Markdown, Jupyter, and academic workflows
- **[NIX Workflows](docs/NIX_WORKFLOWS.md)** - NixOS system integration and management
- **[Formal Verification](docs/FORMAL_VERIFICATION.md)** - Lean 4 and model-checker integration
- **[Notifications](docs/NOTIFICATIONS.md)** - Unified notification system
- **[Code Standards](docs/CODE_STANDARDS.md)** - Lua coding conventions
- **[Documentation Standards](docs/DOCUMENTATION_STANDARDS.md)** - Documentation requirements

### Module Documentation (lua/neotex/)

Detailed READMEs in every directory documenting modules and functionality:

- **[NeoTeX Namespace](lua/neotex/README.md)** - Configuration overview and bootstrap process
- **[Configuration Core](lua/neotex/config/README.md)** - Essential Neovim settings (options, keymaps, autocommands)
- **[Plugin System](lua/neotex/plugins/README.md)** - Plugin organization and management
  - [AI Integration](lua/neotex/plugins/ai/README.md) - Claude Code, OpenCode, Lectic, and MCP Hub
  - [Editor Enhancements](lua/neotex/plugins/editor/README.md) - Navigation, formatting, and terminal integration
  - [LSP Configuration](lua/neotex/plugins/lsp/README.md) - Language server setup and completion
  - [Text Processing](lua/neotex/plugins/text/README.md) - LaTeX, Markdown, Jupyter, and Lean support
  - [Development Tools](lua/neotex/plugins/tools/README.md) - Git, snippets, and productivity enhancements
  - [UI Components](lua/neotex/plugins/ui/README.md) - File explorer, status line, and visual elements
- **[Core Functionality](lua/neotex/core/README.md)** - Fundamental utilities and base functionality
- **[Utility Functions](lua/neotex/util/README.md)** - Helper functions and performance optimization tools
- **[Deprecated Code](lua/neotex/deprecated/README.md)** - Legacy code preserved for reference

### Additional Documentation

- **[File Type Support](after/README.md)** - Language-specific configurations and detection
- **[Templates](templates/README.md)** - Document templates for LaTeX, presentations, and academic writing
- **[Code Snippets](snippets/README.md)** - Custom snippet collections for rapid development
- **[Scripts](scripts/README.md)** - Maintenance and diagnostic utilities

### Navigation Standards

Each README follows [DOCUMENTATION_STANDARDS.md](docs/DOCUMENTATION_STANDARDS.md) and includes:
- **Purpose Statement**: Clear description of directory role
- **Module Documentation**: Details for each file with examples
- **Related Documentation**: Cross-references to relevant docs
- **Navigation Links**: Parent and subdirectory relationships

This documentation structure ensures information is easily accessible with consistent organization throughout the configuration.

## Maintenance and Troubleshooting

The [`scripts/`](scripts/README.md) directory contains utility scripts for maintaining and troubleshooting the configuration:

- **Plugin Analysis**: `scripts/check_plugins.lua` - Verify plugin loading and organization
- **MCP Integration**: Scripts for testing and repairing AI tool integration
- **Diagnostics**: Comprehensive tests for configuration components

See [`scripts/README.md`](scripts/README.md) for detailed script documentation and usage instructions.

### Making Configuration Changes

1. **Check for Conflicts**: Before adding new keybindings, check for conflicts with:
   ```
   :verbose map <key-combo>
   ```
   This shows if the key is already mapped and in which file.

2. **Test Changes Incrementally**: Make small changes and test them before proceeding to more complex modifications.

3. **Update Documentation**: Always update docstrings in the corresponding files when making changes:
   - For keymappings: Update comments in `keymaps.lua`
   - For which-key entries: Update the reference at the top of `which-key.lua`
   - For new features: Add documentation to this README.md

4. **Organize Related Functions**: Keep related functionality together in appropriate files:
   - Core settings: `lua/neotex/core/`
   - Plugin configurations: `lua/neotex/plugins/`
   - Filetype-specific settings: `after/ftplugin/`

## AI Integration

This configuration integrates multiple AI tools for code assistance, development workflows, and writing. Claude Code serves as the primary AI interface, with OpenCode as an alternative TUI and Lectic for AI-assisted writing.

For details on the agent system architecture that powers automated task management, see [.claude/docs/docs-README.md](.claude/docs/docs-README.md).

### Claude Code (Primary)

Claude Code provides AI-powered development assistance directly within Neovim through a terminal sidebar with session management and git worktree support.

> [Info] The `leader` key is set to `space`.

| Key | Action |
|-----|--------|
| `<C-CR>` | Toggle Claude Code (all modes) |
| `<leader>ac` | Claude commands (normal) / send selection to Claude (visual) |
| `<leader>as` | Claude sessions |
| `<leader>ay` | Toggle yolo mode (skip permission prompts) |
| `<leader>am` | Select Claude model |

Claude Code is particularly useful for understanding and modifying this Neovim configuration. You can ask it to explain features, help with keybindings, customize settings, troubleshoot issues, or generate configuration snippets.

### OpenCode (Alternative TUI)

OpenCode provides an alternative AI interface with context placeholders for buffer contents, diagnostics, and more.

| Key | Action |
|-----|--------|
| `<C-g>` | Toggle OpenCode (normal/insert) |
| `<leader>ao` | OpenCode commands |
| `<leader>ab` | OpenCode with buffer context |
| `<leader>ad` | OpenCode with diagnostics context |
| `<leader>ah` | OpenCode session history |

### Using AI for Configuration Help

When modifying this Neovim configuration, the AI tools can help ensure consistency and prevent conflicts.

1. **Explore Features**: Ask about specific features, e.g., "How do I use VimTeX in this configuration?"
2. **Get Help with Keymappings**: Ask "What are the keybindings for this [feature]?"
3. **Customize Settings**: Ask "How can I change [setting]?" or "Help me add a new keybinding for [action]"
4. **Troubleshoot Issues**: Describe any problems you encounter for guided troubleshooting
5. **Generate Configuration**: Get help creating new plugin configurations or keybinding setups

## Keybinding Reference

This configuration provides extensive keybinding customizations to enhance productivity and provide a cohesive editing experience. The keybindings are organized through two main systems:

### Keybinding Documentation

For complete keybinding reference, see:
- **[Complete Mappings Documentation](docs/MAPPINGS.md)** - Comprehensive reference of all keybindings organized by context and functionality
- **[Which-Key Configuration](lua/neotex/plugins/editor/README.md#which-key-whichkeylua)** - Interactive keybinding discovery system with contextual menus
- **[Core Keymaps Configuration](lua/neotex/config/README.md#keymaps-keymapslua)** - Base keybinding definitions and customizations

### Key Configuration Files

#### Core Keybindings (`lua/neotex/config/keymaps.lua`)
Defines the fundamental key mappings including:
- **Navigation**: Window movement, buffer switching, and cursor positioning
- **Editing**: Text manipulation, folding, and basic operations
- **Terminal**: Terminal mode bindings and window management
- **File operations**: Basic file handling and URL opening

#### Interactive Keybinding Discovery (`lua/neotex/plugins/editor/which-key.lua`)
Provides the which-key system for:
- **Leader-based mappings**: Organized hierarchical command structure under `<space>`
- **Contextual help**: On-screen menus showing available key combinations
- **Filetype-specific bindings**: Dynamic keybindings that appear based on current file type
- **Plugin integration**: Unified access to plugin functionality

### Quick Access

- **Leader key**: `<space>` - Access to all major functionality through organized menus
- **Help system**: Press `<leader>` and wait to see available commands
- **Complete reference**: See [docs/MAPPINGS.md](docs/MAPPINGS.md) for full details
- **Claude Code integration**: Toggle Claude Code with `<C-CR>` or run commands with `<leader>ac`

## Further Features

### Lectic Integration

Lectic provides AI-assisted writing for markdown files with these features:

1. **Quick File Creation**: `<leader>mn` creates a new Lectic file with a template
2. **Full-File Processing**: `<leader>ml` runs Lectic on the entire file
3. **Visual Selection Processing**: 
   - Select text in visual mode (`v`, `V`, or `<C-v>`)
   - Press `<Esc>` to exit visual mode
   - Press `<leader>ms` to process the selected text
   - You'll be prompted to add a message/question about the selection in a multi-line input box
   - Both the selected text and your message will be added to the end of the file with appropriate formatting
   - Lectic will then process the entire file

Use Lectic for AI-assisted writing, brainstorming, or refining your markdown documents.

### Text Surround System

This configuration uses nvim-surround with filetype-aware buffer configurations to provide context-appropriate text manipulation. The same keybindings produce different outputs depending on the file type.

#### Basic Keybindings (All Filetypes)

- `ys{motion}{char}` - Add surround around motion
- `ds{char}` - Delete surrounding character
- `cs{old}{new}` - Change surround from old to new
- `S{char}` - Surround visual selection (visual mode)

Examples:
- `ysiw"` - Surround word with double quotes
- `ds{` - Delete surrounding curly braces
- `cs"'` - Change double quotes to single quotes

#### Filetype-Specific Surrounds

**Markdown Files (.md)**
Special surrounds available only in markdown:

| Key | Result | Description |
|-----|--------|-------------|
| `b` | `**text**` | Bold (strong emphasis) |
| `i` | `*text*` | Italic (emphasis) |
| `` ` `` | `` `text` `` | Inline code |
| `c` | `` ```lang\ntext\n``` `` | Fenced code block (prompts for language) |
| `l` | `[text](url)` | Link (prompts for URL) |
| `~` | `~~text~~` | Strikethrough (GFM) |

**LaTeX Files (.tex)**
Special surrounds available only in LaTeX:

| Key | Result | Description |
|-----|--------|-------------|
| `e` | `\begin{env}...\end{env}` | Environment (prompts for name) |
| `b` | `\textbf{text}` | Bold text |
| `i` | `\textit{text}` | Italic text |
| `t` | `\texttt{text}` | Typewriter (monospace) |
| `q` | `` `text' `` | LaTeX single quotes |
| `Q` | `` ``text'' `` | LaTeX double quotes |
| `$` | `$text$` | Math mode |

**Filetype Isolation**
This design prevents cross-filetype pollution - pressing `ysiw + b` on "word" produces:
- `**word**` in markdown files (markdown bold)
- `\textbf{word}` in LaTeX files (LaTeX bold)

For complete surround documentation, see:
- [Tools Plugin README](lua/neotex/plugins/tools/README.md#surround-operations)
- [File Type Plugin README](after/ftplugin/README.md)

### Folding System

This configuration includes a smart folding system with the following features:

1. **Performance-Focused**: Default folding method is `manual` for better performance
2. **Smart Toggling**: Press `<leader>mf` to toggle between:
   - Manual folding (better performance)
   - Smart folding (expr for markdown, indent for other filetypes)
3. **Persistent Settings**: Your folding preference persists between Neovim sessions
4. **Markdown-Aware**: When smart folding is enabled for markdown files, folds will be created at headers
5. **Comprehensive Mappings**:
   - `<leader>ma` - Toggle all folds open/closed
   - `<leader>mf` - Toggle fold under cursor
   - `<leader>mt` - Toggle folding method (manual/smart)
   - All standard Vim folding keys (za, zo, zc, zR, zM) also work

The system is integrated throughout the configuration to provide a consistent experience
across all file types while prioritizing performance.

### URL Handling System

This configuration includes a comprehensive URL handling system for all file types:

1. **Universal Functionality**: Works in any file type, not just markdown
2. **Multiple URL Types**: Recognizes various URL formats:
   - Standard URLs (https://, http://, file://)
   - Markdown links ([text](url))
   - HTML links (<a href="url">text</a>)
   - Email addresses (user@example.com)
3. **Convenient Access**:
   - Press `gx` to open URL under cursor
   - `Ctrl+Click` to open URL at mouse position
   - `<leader>mu` to open URL under cursor via keybinding
4. **Cross-Platform**: Works on Linux, macOS, and Windows

### Jupyter Notebook Integration

This configuration provides comprehensive support for working with Jupyter notebooks through three integrated plugins:

1. **Jupytext**: Converts between Jupyter notebooks (.ipynb) and text formats (.md, .py)
2. **NotebookNavigator**: Enables cell-based navigation and execution
3. **Iron.nvim**: Provides REPL integration for Python, Julia, R, and Lua

#### Key Features

- **Notebook Mode**: Work with notebook-style cells in markdown or Python files
- **Format Conversion**: Convert between .ipynb, .md, and .py formats
- **Cell Navigation**: Move between code/markdown cells with keyboard shortcuts
- **Cell Execution**: Run cells directly and see output in a REPL
- **Interactive REPL**: Send code snippets, lines, or files to the REPL
- **Smooth Workflow**: Integrated keybindings for all notebook operations

#### Jupyter Keybindings (`<leader>j`)

| Key           | Action                          |
|---------------|----------------------------------|
| `<leader>je`  | Execute current cell             |
| `<leader>jj`  | Navigate to next cell            |
| `<leader>jk`  | Navigate to previous cell        |
| `<leader>jn`  | Execute cell and move to next    |
| `<leader>jo`  | Insert new cell below            |
| `<leader>jO`  | Insert cell above                |
| `<leader>js`  | Split cell at cursor position    |
| `<leader>jc`  | Comment current cell             |
| `<leader>ja`  | Run all cells in file            |
| `<leader>jb`  | Run current and all cells below  |
| `<leader>ju`  | Merge with cell above            |
| `<leader>jd`  | Merge with cell below            |
| `<leader>ji`  | Start IPython REPL               |
| `<leader>jt`  | Send motion to REPL              |
| `<leader>jl`  | Send current line to REPL        |
| `<leader>jf`  | Send entire file to REPL         |
| `<leader>jv`  | Send visual selection to REPL    |
| `<leader>jq`  | Exit REPL                        |
| `<leader>jr`  | Clear REPL screen                |
| `<leader>jc`  | Show jupytext config             |

#### Cell Markers

The system recognizes cells based on these markers:
- **Python**: Cells are delimited by `# %%` or `#%%` comments
- **Markdown**: Cells are delimited by code blocks starting/ending with ``` (triple backticks)

#### Workflow Example

1. Create a Python or Markdown file with cell markers
2. Navigate between cells with `<leader>jj` and `<leader>jk`
3. Execute cells with `<leader>je` or execute and move to next with `<leader>jn`
4. Add new cells with `<leader>jo` (below) or `<leader>jO` (above)
5. Use additional features like `<leader>js` (split cell), `<leader>jc` (comment cell), or `<leader>ja` (run all cells)

This integration provides a seamless experience for data analysis, scientific computing, and literate programming without leaving Neovim.

### NixOS Management

This configuration includes convenient keybindings for managing NixOS systems directly from Neovim, streamlining system administration tasks:

#### System Management (`<leader>n`)

| Key              | Action                        |
|------------------|-------------------------------|
| `<leader>nr`     | Rebuild system from flake     |
| `<leader>nh`     | Apply home-manager changes    |
| `<leader>nu`     | Update flake dependencies     |
| `<leader>ng`     | Clean up old nix packages     |
| `<leader>nd`     | Enter nix development shell   |

#### Quick Access Resources

| Key              | Action                        |
|------------------|-------------------------------|
| `<leader>np`     | Open NixOS packages website   |
| `<leader>nm`     | Open MyNixOS website          |

#### Key Features

1. **System Rebuilding**: Quickly rebuild your NixOS configuration from flakes
2. **Home Manager**: Apply user-specific configuration changes
3. **Package Management**: Update dependencies and clean up old generations
4. **Development Environment**: Enter development shells for project-specific dependencies
5. **Resource Access**: Quick links to NixOS package search and configuration tools

These commands integrate NixOS system management into your development workflow, allowing you to manage system configuration, packages, and environments without leaving your editor.

### Performance Optimization

This configuration is optimized for fast startup and responsive editing:

#### Performance Features
- **Optimized Lazy-Loading**: Plugins load precisely when needed, not earlier
  - Session Manager loads on VeryLazy event (after startup complete)
  - LSP file operations load on BufReadPost (when reading files)
  - nvim-surround loads on BufReadPost (ready for text manipulation)
- **Efficient Autocommands**: File reload detection uses FocusGained and BufEnter events
  - No CursorHold/CursorHoldI events that cause cursor pause lag
  - Reduced autocmd fires by 98% compared to cursor-based detection
- **Enhanced Icons**: nvim-web-devicons includes common file type icons (TypeScript, Rust, Go, YAML, TOML, Dockerfile, .env)
- **Clean Logging**: Markdown preview uses 'warn' log level (90% reduction in debug output)

#### Performance Analysis Tools
Built-in tools for analyzing and improving performance:

1. **Startup Analysis**: Run `:AnalyzeStartup` to identify bottlenecks in your NeoVim startup process
2. **Plugin Profiling**: Use `:ProfilePlugins` to measure load times for all plugins
3. **Optimization Reports**: Generate comprehensive reports with `:OptimizationReport`
4. **Lazy-Loading Suggestions**: Get plugin-specific recommendations with `:SuggestLazyLoading`

These tools provide actionable insights to help you maintain a fast and responsive editing environment. See the comprehensive documentation in `lua/neotex/utils/README.md` for more details on the optimization workflow.

### Testing Your Changes

After making changes:

1. Source the modified file with `<leader>rr` or (better) restart Neovim
2. Test the functionality in realistic scenarios
3. Check for any error messages in `<leader>rs`
4. Use `:checkhealth` to verify plugin health (also linked in the dashboard `<leader>rd`)
5. If issues occur, use `:verbose` commands to debug

Remember that a well-documented configuration is easier to maintain and extend.
Take the time to add clear comments and keep this README updated as the configuration evolves.

## Navigation

### Core Configuration Areas
- [Configuration →](lua/neotex/config/README.md) - Options, keymaps, and autocommands
- [Plugins →](lua/neotex/plugins/README.md) - Plugin system and organization
- [Utilities →](lua/neotex/util/README.md) - Helper functions and optimization tools

### Specialized Documentation
- [Templates →](templates/README.md) - LaTeX document templates
- [Snippets →](snippets/README.md) - Code snippet collections
- [Scripts →](scripts/README.md) - Maintenance and diagnostic utilities
- [File Types →](after/README.md) - Language-specific configurations

### Additional Resources
- [Installation Guide →](docs/INSTALLATION.md) - Setup instructions
- [Keybinding Reference →](docs/MAPPINGS.md) - Complete keymap documentation

### Troubleshooting and Debugging

#### Viewing Debug Messages

By default, debug messages are hidden to keep your Neovim experience clean. If you need to see these messages for troubleshooting:

1. **View all notification levels**: 
   ```lua
   :lua vim.notify_level = vim.log.levels.DEBUG
   ```

2. **View even more verbose messages** (including trace level):
   ```lua
   :lua vim.notify_level = vim.log.levels.TRACE
   ```

3. **Check notification history**:
   Press `<leader>rm` to view the notification history, which includes all past messages.

4. **Return to normal notifications** (hide debug messages again):
   ```lua
   :lua vim.notify_level = vim.log.levels.INFO
   ```

These debug messages can be helpful when diagnosing plugin loading issues, performance problems, or other configuration concerns.
