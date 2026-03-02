# LSP Integration Guide

## Overview

The Lean 4 LSP server provides real-time type checking, diagnostics, goal state information, and code intelligence.

## Connection Management

### Persistent Connection

```yaml
connection:
  protocol: "JSON-RPC 2.0"
  transport: "stdio" or "TCP"
  initialization:
    - Send initialize request with client capabilities
    - Wait for initialize response
    - Send initialized notification
```

## Core LSP Messages

### Document Synchronization

**textDocument/didOpen**:
```json
{
  "jsonrpc": "2.0",
  "method": "textDocument/didOpen",
  "params": {
    "textDocument": {
      "uri": "file:///path/to/file.lean",
      "languageId": "lean4",
      "version": 1,
      "text": "theorem example : 1 + 1 = 2 := rfl"
    }
  }
}
```

### Diagnostics

**textDocument/publishDiagnostics** (server -> client):
```json
{
  "method": "textDocument/publishDiagnostics",
  "params": {
    "uri": "file:///path/to/file.lean",
    "diagnostics": [
      {
        "range": {...},
        "severity": 1,
        "message": "type mismatch: expected Nat, got Int"
      }
    ]
  }
}
```

**Severity Levels**:
- 1: Error
- 2: Warning
- 3: Information
- 4: Hint

### Goal State

**textDocument/goalState** (custom Lean 4 request):
```json
{
  "method": "textDocument/goalState",
  "params": {
    "textDocument": {"uri": "file:///path/to/file.lean"},
    "position": {"line": 5, "character": 10}
  }
}
```

**Response**:
```json
{
  "result": {
    "goals": [
      {
        "hypotheses": [
          {"name": "n", "type": "Nat"},
          {"name": "h", "type": "n > 0"}
        ],
        "conclusion": "n + 1 > 1"
      }
    ]
  }
}
```

### Hover Information

**textDocument/hover**:
```json
{
  "method": "textDocument/hover",
  "params": {
    "textDocument": {"uri": "file:///path/to/file.lean"},
    "position": {"line": 3, "character": 15}
  }
}
```

## Timeout Handling

```yaml
timeouts:
  validation: 5s
  goal_state: 3s
  hover: 2s
  completion: 2s
```

## Caching Strategy

```yaml
caching:
  ttl:
    diagnostics: 5m
    goal_state: 2m
    hover: 10m
  invalidation:
    - File content changed
    - Imports changed
```

## Best Practices

### Connection Management

1. **Persistent Connection**: Maintain single persistent connection per project
2. **Heartbeat**: Implement heartbeat to detect connection issues
3. **Graceful Shutdown**: Close connections cleanly on exit

### Request Management

1. **Timeout All Requests**: Never wait indefinitely
2. **Cancel Stale Requests**: Cancel requests for outdated file versions
3. **Prioritize User Requests**: User-initiated requests take priority

### Error Handling

1. **Always Have Fallback**: Never fail completely
2. **Log All Errors**: Log for debugging
3. **Degrade Gracefully**: Provide reduced functionality when LSP unavailable

## References

- [LSP Specification](https://microsoft.github.io/language-server-protocol/)
- [Lean 4 LSP Extensions](https://github.com/leanprover/lean4/tree/master/src/Lean/Server)
