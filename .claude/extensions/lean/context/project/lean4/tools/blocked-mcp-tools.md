# Blocked MCP Tools Reference

**Last Updated**: 2026-03-16

This document is the authoritative reference for blocked Lean MCP tools. These tools must NOT be called directly due to known issues.

## Quick Reference

| Tool | Bug | Alternative |
|------|-----|-------------|
| `lean_diagnostic_messages` | lean-lsp-mcp #115 | `lean_goal` or `lake build` |
| `lean_file_outline` | No specific issue (see notes) | `Read` + `lean_hover_info` |

## Blocked Tools

### lean_diagnostic_messages

**Status**: BLOCKED (DO NOT USE)
**Bug Reference**: [lean-lsp-mcp #115](https://github.com/oOo0oOo/lean-lsp-mcp/issues/115)
**Tool ID**: `mcp__lean-lsp__lean_diagnostic_messages`

**Problem**: Server halts indefinitely when this tool is called after file imports have been edited (e.g., adding `import Mathlib`). The tool works correctly on the first call, but subsequent calls after import changes cause the MCP server to hang and never respond. Requires server restart to recover.

**Alternatives**:
- `lean_goal` - Check proof state at a specific line to see errors in context
- `lake build` via Bash - Get authoritative build errors from the Lean toolchain

**When Blocked**: 2026-01-15 (approximately)

---

### lean_file_outline

**Status**: BLOCKED (DO NOT USE)
**Bug Reference**: No specific GitHub issue exists for hanging behavior
**Tool ID**: `mcp__lean-lsp__lean_file_outline`

**Problem**: Originally blocked due to hanging behavior, but no specific GitHub issue documents this problem. Related issue [#97](https://github.com/oOo0oOo/lean-lsp-mcp/issues/97) (diagnostics truncated after file_outline) was closed in December 2025. The tool may no longer be problematic, but remains blocked pending verification testing.

**Alternatives**:
- `Read` - Read the file directly to see its full contents
- `lean_hover_info` - Get type information for specific symbols after reading the file

**When Blocked**: 2026-01-15 (approximately)

---

## Unblocking Procedure

When upstream bugs are fixed:

1. Verify the fix in the lean-lsp-mcp repository
2. Update lean-lsp-mcp package version in the project
3. Test the tool manually to confirm fix
4. Update this document to mark tool as UNBLOCKED
5. Update extension agent files if they reference blocked tools
6. Update mcp-tools-guide.md to restore detailed documentation

## Related Documentation

- [MCP Tools Guide](mcp-tools-guide.md) - Complete MCP tool reference
- [MCP Fallback Table](../patterns/mcp-fallback-table.md) - Tool fallback strategies
- [MCP Tool Recovery Pattern](../../../../../../context/core/patterns/mcp-tool-recovery.md) - General recovery patterns
