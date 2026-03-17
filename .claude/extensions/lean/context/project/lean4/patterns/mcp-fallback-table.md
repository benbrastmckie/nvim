# Lean MCP Tool Fallback Table

Extension-specific fallback table for Lean MCP tool recovery.

See [MCP Tool Recovery Pattern](../../../../../context/core/patterns/mcp-tool-recovery.md) for the general recovery strategy.

---

## Search Tool Fallbacks

| Primary Tool | Alternative 1 | Alternative 2 | Notes |
|--------------|---------------|---------------|-------|
| `lean_leansearch` | `lean_loogle` | `lean_leanfinder` | Rate-limited APIs |
| `lean_loogle` | `lean_leansearch` | `lean_leanfinder` | Rate-limited APIs |
| `lean_leanfinder` | `lean_leansearch` | `lean_loogle` | Rate-limited APIs |
| `lean_local_search` | (no rate limit) | Continue with partial | Prefer this tool |

**Note**: `lean_local_search` has no rate limit - prefer it when searching local codebase.

---

## Diagnostic Tool Fallbacks

| Primary Tool | Alternative 1 | Alternative 2 | Notes |
|--------------|---------------|---------------|-------|
| `lean_diagnostic_messages` | `lean_goal` | `lake build` via Bash | BLOCKED - see below |
| `lean_goal` | `lean_verify` | `lake build` via Bash | For proof state |
| `lean_verify` | `lean_goal` | `lake build` via Bash | For file verification |

### lean_diagnostic_messages is BLOCKED

**Status**: Currently blocked due to resource contention issues.

**Use Instead**: `lean_goal` for proof state, or run `lake build` via Bash tool.

**Bash Fallback**:
```bash
cd /path/to/project && lake build 2>&1
```

---

## Proof Assistance Fallbacks

| Primary Tool | Alternative 1 | Alternative 2 | Notes |
|--------------|---------------|---------------|-------|
| `lean_state_search` | `lean_hammer_premise` | Manual tactic exploration | For tactic suggestions |
| `lean_hammer_premise` | `lean_state_search` | `lean_local_search` | For premise hints |

---

## Tool Blocking Status

| Tool | Status | Reason | Unblock Procedure |
|------|--------|--------|-------------------|
| `lean_diagnostic_messages` | BLOCKED | Resource contention | Check lean-lsp-mcp issues |
| `lean_file_outline` | BLOCKED | Performance issues | Check lean-lsp-mcp issues |

**To check current blocking status**: See `.claude/extensions/lean/context/project/lean4/tools/blocked-mcp-tools.md`

---

## Prevention Strategies for Lean

1. **Pre-build before sessions**:
   ```bash
   cd /path/to/project && lake build
   ```

2. **Limit concurrent Lean operations** when experiencing timeouts

3. **Configure environment variables**:
   ```json
   {
     "mcpServers": {
       "lean-lsp": {
         "env": {
           "LEAN_LOG_LEVEL": "WARNING"
         }
       }
     }
   }
   ```

4. **See multi-instance optimization**: `operations/multi-instance-optimization.md`

---

## Related Documentation

- [MCP Tool Recovery Pattern](../../../../../context/core/patterns/mcp-tool-recovery.md) - General recovery strategy
- [MCP Tools Guide](../tools/mcp-tools-guide.md) - Lean MCP tool reference
- [Multi-Instance Optimization](../operations/multi-instance-optimization.md) - Concurrent session setup
