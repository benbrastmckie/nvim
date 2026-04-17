---
paths: .claude/**/*
---

# Error Handling Rules

## Error Categories

### Operational Errors
Errors during command execution:
- `delegation_hang` - Subagent not responding
- `timeout` - Operation exceeded time limit
- `validation_failed` - Input validation failure

### State Errors
Errors in state management:
- `status_sync_failure` - TODO.md/state.json desync
- `file_not_found` - Expected file missing
- `parse_error` - JSON/YAML parse failure

### External Errors
Errors from external systems:
- `git_commit_failure` - Git operation failed
- `build_error` - Build command failed
- `tool_unavailable` - MCP tool not responding
- `mcp_abort_error` - MCP tool aborted or timed out (error code -32001)
- `delegation_interrupted` - Agent interrupted before completion (metadata shows in_progress)
- `jq_parse_failure` - jq command parse error (often due to Issue #1132)

## Error Response Pattern

When an error occurs:

### 1. Log the Error
Record in errors.json:
```json
{
  "id": "err_{timestamp}",
  "timestamp": "ISO_DATE",
  "type": "error_type",
  "severity": "critical|high|medium|low",
  "message": "Error description",
  "context": {
    "session_id": "sess_1736700000_abc123",
    "command": "/implement",
    "task": 259,
    "phase": 2,
    "checkpoint": "GATE_OUT"
  },
  "trajectory": {
    "delegation_path": ["orchestrator", "implement", "skill-implementer", "general-implementation-agent"],
    "failed_at_depth": 3
  },
  "recovery": {
    "suggested_action": "Run /implement 259 to resume from phase 2",
    "auto_recoverable": true
  },
  "fix_status": "unfixed"
}
```

### Session-Aware Error Aggregation

Errors with the same session_id belong to the same operation. Use session_id to:
- Link related errors in multi-step operations
- Identify recurring patterns across operations
- Enable trajectory reconstruction for debugging

### 2. Preserve Progress
- Never lose completed work
- Keep partial results
- Mark phases as [PARTIAL] not failed

### 3. Enable Resume
- Store resume point information
- Next invocation continues from failure point

### 4. Report Clearly
Return structured error:
```json
{
  "status": "failed|partial",
  "error": {
    "type": "error_type",
    "message": "What happened",
    "recovery": "How to fix"
  },
  "progress": {
    "completed": ["phase1", "phase2"],
    "failed_at": "phase3"
  }
}
```

## Severity Levels

| Severity | Description | Response |
|----------|-------------|----------|
| critical | System unusable | Stop, alert, require manual fix |
| high | Feature broken | Log, attempt recovery |
| medium | Degraded function | Log, continue with workaround |
| low | Minor issue | Log, ignore |

## Recovery Strategies

### Timeout Recovery
```
1. Save partial progress
2. Mark current phase [PARTIAL]
3. Git commit progress
4. Next /implement resumes
```

### State Sync Recovery
```
1. Read both files
2. Use git blame for latest
3. Sync to latest version
4. Log resolution
```

### Build Error Recovery
```
1. Capture error output
2. Log to errors.json
3. Keep source unchanged
4. Report error with context
```

### jq Parse Failure Recovery
```
1. Capture jq error output (INVALID_CHARACTER, syntax error)
2. Log to errors.json with original command
3. Retry using "| not" pattern from jq-escaping-workarounds.md
4. If retry succeeds, log recovery
```

**Note**: jq failures are often caused by Claude Code Issue #1132 variants:
- **Pipe injection**: `|` in quoted strings triggers `< /dev/null` injection
- **`!=` escaping**: The `!=` operator gets escaped as `\!=`

**Solution**: Use `select(.type == "X" | not)` instead of `select(.type != "X")`.
See `.claude/context/patterns/jq-escaping-workarounds.md` for full documentation.

### MCP Abort Error Recovery
```
1. Log the error with tool name and context
2. Retry once after 5-second delay
3. Try alternative tool if available
4. Write partial status to metadata file with partial_progress
5. Continue with available information or return partial
```

**Note**: MCP AbortError -32001 is often caused by resource contention. Retry the operation
after a brief delay.

### Delegation Interrupted Recovery
```
1. Check metadata file for status="in_progress"
2. Extract partial_progress to determine resume point
3. Keep task status unchanged (still "researching" or "implementing")
4. Log error with partial_progress context
5. Display guidance: "Run command again to resume"
```

**Note**: Delegation interrupted occurs when an agent is terminated (by timeout, MCP error, or
Claude Code abort) before writing final metadata. The early-metadata-pattern.md ensures
metadata exists for recovery.

## Non-Blocking Errors

These should not stop execution:
- Git commit failures
- Metric collection failures
- Non-critical logging failures

Log and continue, report at end.
