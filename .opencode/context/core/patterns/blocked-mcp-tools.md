# Blocked MCP Tools Reference

**Last Updated**: 2026-02-27

This document is the authoritative reference for blocked MCP tools. These tools must NOT be called directly due to known issues.

## Quick Reference

| Tool | Bug | Alternative |
|------|-----|-------------|
| `lean_diagnostic_messages` | lean-lsp-mcp #118 | `lean_goal` or `lake build` |
| `lean_file_outline` | lean-lsp-mcp #115 | `Read` + `lean_hover_info` |

## Blocked Tools

### lean_diagnostic_messages

**Status**: BLOCKED (DO NOT USE)
**Bug Reference**: [lean-lsp-mcp #118](https://github.com/joshuaferrara/lean-lsp-mcp/issues/118)
**Tool ID**: `mcp__lean-lsp__lean_diagnostic_messages`

**Problem**: Returns inconsistent or incorrect diagnostic information. Can cause agent confusion and incorrect error handling decisions.

**Alternatives**:
- `lean_goal` - Check proof state at a specific line to see errors in context
- `lake build` via Bash - Get authoritative build errors from the Lean toolchain

**When Blocked**: 2026-01-15 (approximately)

---

### lean_file_outline

**Status**: BLOCKED (DO NOT USE)
**Bug Reference**: [lean-lsp-mcp #115](https://github.com/joshuaferrara/lean-lsp-mcp/issues/115)
**Tool ID**: `mcp__lean-lsp__lean_file_outline`

**Problem**: Returns incomplete or malformed outline information. The tool's output is unreliable for determining file structure.

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
5. Update OPENCODE.md to remove from blocked list
6. Update deprecated agent files if still relevant
7. Update mcp-tools-guide.md to restore detailed documentation

## Related Documentation

- `.opencode/OPENCODE.md` - Main blocked tools warning in "Lean 4 Integration" section
- `.opencode/context/project/lean4/tools/mcp-tools-guide.md` - MCP tool reference
- `.opencode/agent/lean-research-agent.md` - Agent with blocked tools warning
- `.opencode/agent/lean-implementation-agent.md` - Agent with blocked tools warning
