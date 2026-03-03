# MCP Tool Recovery Pattern

**Created**: 2026-02-27
**Purpose**: Defensive patterns for handling MCP tool failures, especially AbortError -32001
**Audience**: Agent developers, particularly lean-research-agent and lean-implementation-agent

---

## Overview

MCP tools (particularly lean-lsp tools) can fail with AbortError -32001 due to:
- Request timeout (60s default)
- Resource contention from multiple concurrent lean-lsp instances
- Connection issues between OpenCode and MCP servers
- Shared AbortController cascading errors

This pattern provides defensive strategies for graceful degradation when MCP tools fail.

---

## Error Types

### AbortError -32001 (Request Timeout)

**Cause**: MCP tool call exceeded timeout, often due to resource contention from multiple concurrent lean-lsp-mcp instances via STDIO transport.

**Symptoms**:
- Tool call hangs for 30-60 seconds
- Returns `AbortError: The operation was aborted`
- Agent may terminate without completing cleanup

**Contributing Factors** (from lean-lsp-mcp Issues #118, #115):
- Multiple concurrent `lake build` processes exhausting memory (>16GB possible)
- Diagnostic processing hangs under concurrent load
- STDIO transport single-threaded limitation

### Tool Unavailable

**Cause**: MCP server not responding or not configured.

**Symptoms**:
- Tool returns error immediately
- May indicate MCP not in user scope

---

## Recovery Strategy: Conceptual Pattern

When an MCP tool call fails, apply this recovery sequence:

### Step 1: Log the Error

Record error context for debugging:
- Tool name that failed
- Error type and message
- Task context (task_number, session_id)
- What operation was attempted

### Step 2: Attempt Retry (Once)

If the error appears transient:
- Wait 5 seconds before retry
- Make one retry attempt
- If retry succeeds, continue normally

**When to retry**:
- AbortError -32001 (timeout may be transient)
- Connection errors

**When NOT to retry**:
- Tool unavailable errors (configuration issue)
- Repeated failures (indicates systemic issue)

### Step 3: Try Alternative Tool

If the primary tool fails, use fallback alternatives:

| Primary Tool | Alternative 1 | Alternative 2 |
|--------------|---------------|---------------|
| `lean_leansearch` | `lean_loogle` | `lean_leanfinder` |
| `lean_loogle` | `lean_leansearch` | `lean_leanfinder` |
| `lean_leanfinder` | `lean_leansearch` | `lean_loogle` |
| `lean_local_search` | (no alternative - but no rate limit) | Continue with partial |
| `lean_diagnostic_messages` | `lean_goal` (BLOCKED - use this) | `lake build` via Bash |
| `lean_state_search` | `lean_hammer_premise` | Manual tactic exploration |

### Step 4: Write Partial Status

If all recovery attempts fail:
1. Update metadata file with `status: "partial"`
2. Document what was attempted
3. Include `partial_progress` field with:
   - What was accomplished before failure
   - Where failure occurred
   - Recovery recommendations

### Step 5: Continue with Available Information

Don't block on MCP failures:
- Use information gathered before the failure
- Note in report/summary what couldn't be retrieved
- Provide recommendations for manual follow-up

---

## Implementation in Agents

### For Research Agents

```markdown
### MCP Tool Error Recovery

When MCP tool calls fail (AbortError -32001 or similar):

1. **Log the error context** (tool, operation, task)
2. **Retry once** after 5-second delay for timeout errors
3. **Try alternative search tool** per fallback table above
4. **If all fail**: Continue with codebase-only findings
5. **Update metadata** with partial status if significant results lost
6. **Document in report** what searches failed and recommendations
```

### For Implementation Agents

```markdown
### MCP Tool Error Recovery

When MCP tool calls fail during proof development:

1. **Log the error context** (tool, operation, proof state)
2. **Retry once** after 5-second delay for timeout errors
3. **lean_diagnostic_messages is BLOCKED**: Use `lean_goal` or `lake build` instead
4. **If lean_goal fails**: Use Bash to run lake build and capture errors
5. **Save partial progress** before returning
6. **Update metadata** with partial status and recovery info
7. **Document in summary** what couldn't be verified
```

---

## Error Logging Format

When MCP errors occur, they should be logged to errors.json with:

```json
{
  "id": "err_{timestamp}",
  "timestamp": "ISO_DATE",
  "type": "mcp_abort_error",
  "severity": "high",
  "message": "MCP tool {tool_name} aborted with error -32001",
  "context": {
    "session_id": "sess_...",
    "command": "/research or /implement",
    "task": 259,
    "tool_name": "lean_local_search",
    "error_code": -32001,
    "retry_attempted": true,
    "alternative_used": "lean_loogle"
  },
  "recovery": {
    "suggested_action": "Retry command or check lean-lsp configuration",
    "auto_recoverable": true
  }
}
```

---

## Prevention Strategies

### For Users

1. **Pre-build the project** before starting sessions:
   ```bash
   cd /path/to/Logos/Theory && lake build
   ```
   This prevents concurrent build triggers when multiple agents start.

2. **Limit concurrent Lean sessions** during implementation work:
   - If experiencing timeouts, reduce concurrent Lean operations
   - Non-Lean work (general tasks, LaTeX, meta) is unaffected

3. **Configure environment variables** in MCP server config:
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

### For Agents

1. **Write early metadata** (see early-metadata-pattern.md)
2. **Use rate-limited tools sparingly**
3. **Prefer lean_local_search** (no rate limit)
4. **Check goals incrementally** rather than batching

---

## Related Documentation

- `.opencode/context/core/patterns/early-metadata-pattern.md` - Early metadata file creation
- `.opencode/rules/error-handling.md` - Error handling rules and mcp_abort_error type
- `.opencode/context/core/formats/return-metadata-file.md` - Metadata file schema with partial_progress
