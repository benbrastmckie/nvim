# Neovim Configuration Guidelines

## Commands
[Used by: /test, /test-all]

- **Linting**: `vim.keymap.set("n", "<leader>l", function() lint.try_lint() end)`
- **Formatting**: `vim.keymap.set({"n", "v"}, "<leader>mp", function() conform.format(...) end)`
- **Testing**: `:TestNearest`, `:TestFile`, `:TestSuite`, `:TestLast`

## Code Standards
[Used by: /implement, /refactor, /plan]

### Lua Code Style
- **Indentation**: 2 spaces, expandtab
- **Line length**: ~100 characters
- **Imports**: At the top of the file, ordered by dependency
- **Module structure**: Organized in `neotex.core` and `neotex.plugins` namespaces
- **Plugin definitions**: Table-based with lazy.nvim format
- **Function style**: Use local functions where possible
- **Keymaps**: Document in comments, use `vim.keymap.set` with descriptive options
- **Error handling**: Use pcall for operations that might fail
- **Naming**: Use descriptive, lowercase names with underscores for variables/functions

## Project Organization
- Core functionality in `lua/neotex/core/`
- Plugin configurations in `lua/neotex/plugins/`
- LSP settings in dedicated `lua/neotex/plugins/lsp/` directory
- Filetype-specific settings in `after/ftplugin/`
- Deprecated features moved to `lua/neotex/deprecated/`

## Documentation Policy
[Used by: /document, /plan]

See `.claude/context/project/neovim/standards/documentation-policy.md` for README requirements, structure template, and style guidelines.

## Box Drawing
See `.claude/context/project/neovim/standards/box-drawing-guide.md` for Unicode box-drawing character reference.

## Character Encoding and Emoji Policy
See `.claude/context/project/neovim/standards/emoji-policy.md` for encoding guidelines and approved alternatives.

## Testing Protocols
[Used by: /test, /test-all, /implement]

### Test Commands
- **Run nearest test**: `:TestNearest` - Test function/block under cursor
- **Test current file**: `:TestFile` - Run all tests in current file
- **Test suite**: `:TestSuite` - Run all tests in project
- **Repeat last test**: `:TestLast` - Re-run most recent test

### Test Patterns
- Test files: `*_spec.lua`, `test_*.lua`
- Test location: `tests/` directory or adjacent to source files
- Test framework: Busted, plenary.nvim, or project-specific

### Quality Standards
- All new Lua modules must have test coverage
- Public APIs require comprehensive tests
- Use `pcall` in tests for error condition testing
- Mock external dependencies appropriately

### Lua Testing Assertion Patterns
See `.claude/context/project/neovim/standards/lua-assertion-patterns.md` for correct `string:match()` assertion usage.

## Standards Discovery
[Used by: all commands]

This CLAUDE.md is the root configuration file for the Neovim configuration repository.

### Related Configuration
- `.claude/CLAUDE.md` - Task management and agent orchestration system
- This file contains Neovim-specific coding standards and guidelines
- Both files should be consulted for complete standards
