# Editor Enhancement Plugins

This directory contains plugins that enhance the core editing experience in Neovim, providing navigation, formatting, terminal integration, and user interface improvements.

## File Structure

```
editor/
├── README.md           # This documentation
├── init.lua           # Editor plugins loader
├── formatting.lua     # Code formatting (conform.nvim)
├── linting.lua        # Code linting (nvim-lint)
├── telescope.lua      # Fuzzy finder and navigation
├── toggleterm.lua     # Terminal integration
├── treesitter.lua     # Syntax highlighting and parsing
└── which-key.lua      # Keybinding discovery system
```

## Module Overview

### Core Editor Plugins

#### Formatting (`formatting.lua`)
Code formatting integration using `conform.nvim` for consistent code style across multiple languages.

**Key Features:**
- Multi-language formatting support (JavaScript, TypeScript, Python, Lua, Markdown, etc.)
- Integration with LSP for fallback formatting
- Async formatting to prevent UI blocking
- Custom formatters for specific languages:
  - **JavaScript/TypeScript**: Prettier
  - **Python**: Black + isort (import sorting)  
  - **Lua**: StyLua with custom configuration
  - **Markdown/CSS/HTML/YAML/JSON**: Prettier

**Configuration:**
- Format on save can be enabled per-filetype
- Timeout settings for slow formatters
- LSP fallback when dedicated formatters unavailable

#### Linting (`linting.lua`)
Code linting integration using `nvim-lint` for real-time error detection and code quality.

**Key Features:**
- Automatic linting on file events (save, insert leave, text change)
- Multi-language linter support
- Integration with LSP diagnostics
- Configurable lint triggers per filetype
- Error highlighting and navigation

**Supported Linters:**
- **Python**: Flake8, pylint, mypy
- **JavaScript/TypeScript**: ESLint
- **Lua**: Luacheck
- **Markdown**: markdownlint
- **Shell**: shellcheck

#### Telescope (`telescope.lua`)
Fuzzy finder and navigation plugin for files, buffers, LSP symbols, and more.

**Key Features:**
- Fast file and text searching across projects
- LSP symbol navigation (definitions, references, implementations)
- Git integration (commits, branches, status)
- Buffer and help tag searching
- Custom pickers for citations (BibTeX), undo history
- Integration with other plugins (yanky, todo-comments)

**Custom Extensions:**
- **BibTeX**: Citation searching and insertion
- **Undo**: Visual undo tree with diff preview
- **File Browser**: Enhanced file navigation
- **Git**: Commit history, branch switching, file status

**UI Configuration:**
- Custom themes (ivy, dropdown, cursor)
- Preview windows for file contents
- Syntax highlighting in previews
- Smart sorting and filtering

#### Terminal Integration (`toggleterm.lua`)
Enhanced terminal integration with persistent terminals and advanced features.

**Key Features:**
- Multiple persistent terminal instances
- Floating, horizontal, and vertical terminal layouts
- Integration with external tools (lazygit, Python REPL)
- Custom terminal configurations per use case
- Window management and resizing

**Special Terminals:**
- **LazyGit**: Full-screen git interface
- **Python REPL**: Interactive Python development
- **General Terminal**: System command execution
- **Development Shell**: Project-specific environments

#### Treesitter (`treesitter.lua`)
Advanced syntax highlighting and code parsing using Tree-sitter.

**Key Features:**
- Accurate syntax highlighting for 100+ languages
- Code folding based on syntax structure
- Incremental selection and text objects
- Rainbow parentheses for nested structures
- Context-aware indentation

**Language Support:**
- Core languages (Python, JavaScript, TypeScript, Lua, etc.)
- Markup languages (Markdown, HTML, CSS, LaTeX)
- Configuration files (JSON, YAML, TOML)
- Documentation formats (vimdoc, query)

**Text Objects:**
- Function definitions and calls
- Class and method boundaries  
- Parameter lists and arguments
- Comment blocks and documentation

#### Which-Key (`which-key.lua`)
Keybinding discovery and organization system for improved workflow, implementing a hybrid approach for filetype-dependent mappings.

**Key Features:**
- Interactive keybinding menus with descriptions
- Hierarchical organization by functionality
- Visual icons for different command types
- Modern v3 API with improved performance
- Custom trigger configuration (leader-only mode)
- **Hybrid filetype mapping system** (see Technical Implementation below)

**Organization Structure:**
- **Application Groups**: LaTeX, Git, LSP, Jupyter, etc.
- **Functional Groups**: Find, Actions, Text manipulation
- **Context Groups**: Sessions, Templates, TODO management
- **Visual Icons**: Semantic icons for quick recognition

**Filetype-Dependent Groups:**
- **LaTeX** (`<leader>l`): Only visible in `.tex`, `.latex`, `.bib`, `.cls`, `.sty` files
- **Jupyter** (`<leader>j`): Only visible in `.ipynb` files
- **Markdown** (`<leader>m`): Only visible in `.md`, `.markdown` files
- **Pandoc** (`<leader>p`): Visible in convertible formats (markdown, tex, org, rst, html, docx)
- **Templates** (`<leader>T`): Only visible in LaTeX files
- **Actions** (`<leader>a*`): Python, Lean, and Markdown-specific actions appear contextually

**Process Management (`<leader>x`):**

Alongside the existing text manipulation mappings (`xa`, `xA`, `xd`, `xs`, `xw`), the `<leader>x` group includes process management for background servers:

| Keymap | Description |
|--------|-------------|
| `<leader>xl` | Launch current file (filetype-aware: slidev for `.md`, typst-preview for `.typ`) |
| `<leader>xp` | Open telescope process picker (view/kill running processes) |
| `<leader>xk` | Kill all background processes |
| `<leader>xo` | Open current file's process port in browser |

The launch action auto-detects available ports (starting from 3030), opens the browser automatically, and prevents duplicate launches. See `lua/neotex/util/process.lua` for the underlying process manager API.

**Technical Implementation:**
Due to a limitation in which-key.nvim v3 where `cond` parameters are only evaluated once at startup, this configuration uses a **hybrid approach**:

1. **Dynamic Group Headers**: Use modern `cond` functions for group visibility
   ```lua
   {
     "<leader>l",
     group = function()
       return vim.tbl_contains({ "tex", "latex" }, vim.bo.filetype) and "latex" or nil
     end,
     cond = function()
       return vim.tbl_contains({ "tex", "latex" }, vim.bo.filetype)
     end
   }
   ```

2. **Individual Mappings**: Use FileType autocmds for proper runtime registration
   ```lua
   vim.api.nvim_create_autocmd("FileType", {
     pattern = { "python" },
     callback = function()
       wk.add({
         { "<leader>ap", "<cmd>TermExec cmd='python %:p'<CR>", desc = "python", buffer = 0 },
         { "<leader>am", "<cmd>TermExec cmd='./Code/dev_cli.py %:p'<CR>", desc = "model checker", buffer = 0 },
       })
     end,
   })
   ```

This approach ensures:
- Groups appear/disappear dynamically based on filetype
- Individual mappings are properly registered when entering relevant filetypes
- Optimal user experience with working conditional mappings

**UI Enhancements:**
- Clean minimal interface (no status bar)
- Rounded borders and proper spacing
- Icon-based command identification
- Fast response with configurable delay

## Plugin Dependencies

### Core Dependencies
- **plenary.nvim**: Common utilities for Lua plugins
- **nvim-web-devicons**: File type icons and visual enhancements

### External Tools
- **ripgrep (rg)**: Fast text searching for Telescope
- **fd**: Fast file finding for Telescope  
- **lazygit**: Terminal git interface
- **Language-specific tools**: formatters and linters per language

## Configuration Integration

### LSP Integration
- Formatting falls back to LSP when dedicated formatters unavailable
- Linting complements LSP diagnostics without duplication
- Telescope provides LSP symbol navigation
- Which-key organizes LSP commands under logical groups

### File Type Support
- Automatic configuration based on file extensions
- Buffer-local settings for optimal experience
- Integration with after/ftplugin configurations
- Consistent behavior across related file types

### Performance Optimization
- Lazy loading for improved startup time
- Async operations prevent UI blocking
- Efficient caching and memory management
- Conditional loading based on file types and conditions

## Keybinding Organization

All keybindings are comprehensively documented in [MAPPINGS.md](../../../docs/MAPPINGS.md), which provides:

- Complete reference of all keybindings
- Organization by context (global, leader-based, buffer-specific)
- Mode-specific mappings with detailed descriptions
- Plugin-specific keybindings and their functions

The which-key plugin provides interactive discovery of these mappings during use, while the documentation serves as a complete reference guide.

## Plugin Analysis

To verify editor plugins are properly loaded and categorized:

```vim
:luafile scripts/check_plugins.lua
```

This shows the EDITOR category with all editor enhancement plugins. See [`scripts/README.md`](../../../scripts/README.md) for complete script documentation and the main [plugins README](../README.md#plugin-analysis-and-maintenance) for detailed analysis procedures.

## Related Modules

- **UI Components**: Visual enhancements → [ui/](../ui/)
- **Text Processing**: Language-specific tools → [text/](../text/)  
- **Development Tools**: Additional utilities → [tools/](../tools/)
- **LSP Configuration**: Language servers → [lsp/](../lsp/)

This organization ensures editor enhancements are separated from language-specific tools while maintaining clear integration points for a cohesive editing experience.

## Navigation

- [Tools Plugins →](../tools/README.md)
- [LSP Configuration →](../lsp/README.md)
- [UI Plugins →](../ui/README.md)
- [AI Plugins →](../ai/README.md)
- [Text Plugins →](../text/README.md)
- [← Plugins Overview](../README.md)