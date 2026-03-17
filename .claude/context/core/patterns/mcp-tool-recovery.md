# MCP Tool Recovery Pattern

**Purpose**: Defensive patterns for handling MCP tool failures, especially AbortError -32001
**Audience**: Agent developers using MCP tool integrations

---

## Overview

MCP tools can fail with AbortError -32001 due to:
- Request timeout (60s default)
- Resource contention from multiple concurrent MCP server instances
- Connection issues between Claude Code and MCP servers
- Claude Code's shared AbortController cascading errors (Issue #6594)

This pattern provides defensive strategies for graceful degradation when MCP tools fail.

---

## Error Types

### AbortError -32001 (Request Timeout)

**Cause**: MCP tool call exceeded timeout, often due to resource contention.

**Symptoms**:
- Tool call hangs for 30-60 seconds
- Returns `AbortError: The operation was aborted`
- Agent may terminate without completing cleanup

### Tool Unavailable

**Cause**: MCP server not responding or not configured.

**Symptoms**:
- Tool returns error immediately
- May indicate MCP not in user scope (check ~/.claude.json)

---

## Recovery Strategy

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

If the primary tool fails, consult extension-specific fallback tables.

**Core Pattern**:
```
Primary Tool → Alternative 1 → Alternative 2 → Continue with partial
```

**Extension Fallback Tables**:
- Lean: `.claude/extensions/lean/context/project/lean4/patterns/mcp-fallback-table.md`
- Other extensions: Check `{extension}/context/*/patterns/` for fallback tables

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
3. **Try alternative tool** per extension fallback table
4. **If all fail**: Continue with codebase-only findings
5. **Update metadata** with partial status if significant results lost
6. **Document in report** what searches failed and recommendations
```

### For Implementation Agents

```markdown
### MCP Tool Error Recovery

When MCP tool calls fail during execution:

1. **Log the error context** (tool, operation, state)
2. **Retry once** after 5-second delay for timeout errors
3. **Consult extension fallback table** for alternative tools
4. **If no alternative**: Use Bash/CLI fallback if available
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
    "tool_name": "tool_name_here",
    "error_code": -32001,
    "retry_attempted": true,
    "alternative_used": "alternative_tool_name"
  },
  "recovery": {
    "suggested_action": "Retry command or check MCP configuration",
    "auto_recoverable": true
  }
}
```

---

## Prevention Strategies

### For Users

1. **Pre-initialize resources** before starting Claude sessions:
   - Build projects to cache dependencies
   - Warm up language servers
   - This prevents concurrent initialization when multiple agents start

2. **Limit concurrent operations** when experiencing timeouts:
   - If one domain's tools timeout, reduce concurrent operations in that domain
   - Non-MCP work is unaffected

3. **Configure MCP servers** in `~/.claude.json`:
   ```json
   {
     "mcpServers": {
       "your-mcp-server": {
         "env": {
           "LOG_LEVEL": "WARNING"
         }
       }
     }
   }
   ```

### For Agents

1. **Write early metadata** (see early-metadata-pattern.md)
2. **Use rate-limited tools sparingly**
3. **Prefer local/codebase tools** when available
4. **Check state incrementally** rather than batching

---

## State Machine

```
MCP Tool Call
     │
     ▼
┌─────────────┐
│ Call Tool   │
└──────┬──────┘
       │
   ┌───┴───┐
success  error
   │       │
   ▼       ▼
┌─────┐ ┌─────────────┐
│Done │ │ Log Error   │
└─────┘ └──────┬──────┘
               │
               ▼
        ┌─────────────┐
        │ Transient?  │
        └──────┬──────┘
          ┌────┴────┐
         yes       no
          │         │
          ▼         ▼
    ┌─────────┐ ┌─────────────┐
    │ Retry   │ │ Alternative │
    │ (once)  │ │ tool?       │
    └────┬────┘ └──────┬──────┘
         │        ┌────┴────┐
    ┌────┴────┐  yes       no
  success  fail   │         │
    │       │     ▼         ▼
    ▼       │ ┌─────────┐ ┌─────────┐
┌─────┐     │ │ Try alt │ │ Partial │
│Done │     │ └────┬────┘ │ status  │
└─────┘     │      │      └─────────┘
            └──────┤
              ┌────┴────┐
            success  fail
              │       │
              ▼       ▼
          ┌─────┐ ┌─────────┐
          │Done │ │ Partial │
          └─────┘ │ status  │
                  └─────────┘
```

---

## Related Documentation

- [Early Metadata Pattern](early-metadata-pattern.md) - Early metadata file creation for interruption recovery
- [Error Handling Rule](../../rules/error-handling.md) - Error handling rules and mcp_abort_error type
- [Return Metadata Format](../formats/return-metadata-file.md) - Metadata file schema with partial_progress
