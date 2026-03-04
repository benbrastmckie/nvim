# Implementation Summary: Task #124

**Completed**: 2026-03-03
**Duration**: ~15 minutes

## Changes Made

Modified `create_docs_entries()` function in the picker entries module to show only `docs/README.md` instead of scanning for all `.md` files in the docs directory. This affects both the Claude picker (`<leader>ac`) and OpenCode picker (`<leader>ao`) since they share the same entry-creation code, differentiated only by `config.base_dir`.

The implementation:
- Replaced `scan.scan_directory` + `scan.merge_artifacts` calls with direct `vim.fn.filereadable` checks
- Checks local project README first, falls back to global README (consistent with existing merge behavior)
- Uses `helpers.get_tree_char(true)` for consistent "last item" styling (since README is always the only item)
- Hides the [Docs] section entirely when no README.md exists

## Files Modified

- `lua/neotex/plugins/ai/claude/commands/picker/display/entries.lua` - Replaced `create_docs_entries()` function body (lines 83-127)

## Verification

- Module loading: Success (nvim --headless -c "lua require('neotex.plugins.ai.claude.commands.picker.display.entries')" -c "q")
- Neovim startup: Success
- Function returns 2 entries for .claude config: README doc entry + [Docs] heading
- Function returns 2 entries for .opencode config: README doc entry + [Docs] heading
- Function returns 0 entries when no README.md exists (section hidden)
- No Lua errors in module

## Notes

The change is isolated to a single function. The `scan_directory` function was not modified because its README exclusion behavior is correct for all other artifact types (commands, skills, agents, etc.).
