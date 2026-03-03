# LSP Integration Guide

**Purpose**: Guide for integrating with LEAN 4 Language Server Protocol (LSP)

**Last Updated**: December 16, 2025

---

## Overview

The LEAN 4 LSP server provides real-time type checking, diagnostics, goal state information, and code intelligence. This guide covers integration patterns for specialist agents.

---

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
  heartbeat:
    - Ping every 30 seconds
    - Timeout after 5 seconds
    - Reconnect if no response
```

### Auto-Reconnection

```yaml
reconnection_strategy:
  trigger:
    - Connection lost
    - LSP server crash
    - Timeout on request
  backoff:
    type: "exponential"
    initial_delay: 1s
    max_delay: 30s
    max_attempts: 5
  recovery:
    - Clear pending requests
    - Re-initialize connection
    - Resend critical requests
    - Resume normal operation
```

---

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

**textDocument/didChange**:
```json
{
  "jsonrpc": "2.0",
  "method": "textDocument/didChange",
  "params": {
    "textDocument": {
      "uri": "file:///path/to/file.lean",
      "version": 2
    },
    "contentChanges": [
      {
        "text": "theorem example : 1 + 1 = 2 := by rfl"
      }
    ]
  }
}
```

**textDocument/didClose**:
```json
{
  "jsonrpc": "2.0",
  "method": "textDocument/didClose",
  "params": {
    "textDocument": {
      "uri": "file:///path/to/file.lean"
    }
  }
}
```

### Diagnostics

**textDocument/publishDiagnostics** (server → client):
```json
{
  "jsonrpc": "2.0",
  "method": "textDocument/publishDiagnostics",
  "params": {
    "uri": "file:///path/to/file.lean",
    "version": 2,
    "diagnostics": [
      {
        "range": {
          "start": {"line": 0, "character": 8},
          "end": {"line": 0, "character": 15}
        },
        "severity": 1,
        "code": "type_mismatch",
        "source": "Lean 4",
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

**textDocument/goalState** (custom LEAN 4 request):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "textDocument/goalState",
  "params": {
    "textDocument": {
      "uri": "file:///path/to/file.lean"
    },
    "position": {
      "line": 5,
      "character": 10
    }
  }
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
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
  "jsonrpc": "2.0",
  "id": 2,
  "method": "textDocument/hover",
  "params": {
    "textDocument": {
      "uri": "file:///path/to/file.lean"
    },
    "position": {
      "line": 3,
      "character": 15
    }
  }
}
```

**Response**:
```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "result": {
    "contents": {
      "kind": "markdown",
      "value": "```lean\nNat.add : Nat → Nat → Nat\n```\nAddition of natural numbers"
    },
    "range": {
      "start": {"line": 3, "character": 14},
      "end": {"line": 3, "character": 17}
    }
  }
}
```

---

## Timeout Handling

### Request Timeouts

```yaml
timeouts:
  validation: 5s
  goal_state: 3s
  hover: 2s
  completion: 2s
  definition: 3s
  
handling:
  on_timeout:
    - Cancel request
    - Log timeout event
    - Return cached result (if available)
    - Return error with degraded status
  retry_strategy:
    - Retry once with same timeout
    - If fails again, use fallback
```

---

## Caching Strategy

### Cache Key

```yaml
cache_key:
  components:
    - file_path: string
    - content_hash: SHA256
    - request_type: enum
  example: "file.lean:abc123:diagnostics"
```

### Cache Entry

```yaml
cache_entry:
  key: string
  value: object (LSP response)
  timestamp: datetime
  ttl: duration
  access_count: integer
  last_access: datetime
```

### Eviction Policy

```yaml
eviction:
  strategy: "LRU"
  max_entries: 1000
  max_memory: "100MB"
  ttl:
    diagnostics: 5m
    goal_state: 2m
    hover: 10m
    completion: 5m
```

### Invalidation

```yaml
invalidation:
  triggers:
    - File content changed
    - File deleted
    - Imports changed
    - Manual invalidation
  scope:
    - Single file
    - File and dependencies
    - Entire project
```

---

## Error Handling

### LSP Server Errors

```yaml
error_types:
  connection_failed:
    action: "Attempt reconnection with backoff"
    fallback: "Use cached results"
    
  server_crashed:
    action: "Restart LSP server"
    fallback: "Degraded mode (syntax-only)"
    
  request_timeout:
    action: "Cancel and retry once"
    fallback: "Use cached results or return error"
    
  parse_error:
    action: "Log error and skip"
    fallback: "Return empty result"
    
  invalid_response:
    action: "Log error and validate"
    fallback: "Return error with details"
```

### Graceful Degradation

```yaml
degradation_levels:
  full_service:
    - LSP connected
    - All features available
    - Real-time validation
    
  degraded_service:
    - LSP disconnected
    - Use cached results
    - Syntax-only validation
    - Limited features
    
  minimal_service:
    - No LSP available
    - No caching available
    - Basic syntax checking only
    - Manual validation required
```

---

## Performance Optimization

### Batching

```yaml
batching:
  strategy: "Batch multiple file validations"
  batch_size: 10
  batch_timeout: 100ms
  benefits:
    - Reduced LSP overhead
    - Better throughput
    - Lower latency for batched requests
```

### Incremental Updates

```yaml
incremental:
  strategy: "Send only changed portions"
  implementation:
    - Track file changes
    - Compute diff
    - Send incremental update
    - Receive incremental diagnostics
  benefits:
    - Faster validation
    - Lower bandwidth
    - Better responsiveness
```

### Parallel Requests

```yaml
parallelism:
  max_concurrent: 5
  queue_size: 100
  priority:
    - High: User-initiated validation
    - Medium: Background validation
    - Low: Batch validation
```

---

## Best Practices

### Connection Management

1. **Persistent Connection**: Maintain single persistent connection per project
2. **Connection Pooling**: Use connection pool for multiple projects
3. **Heartbeat**: Implement heartbeat to detect connection issues early
4. **Graceful Shutdown**: Close connections cleanly on exit

### Request Management

1. **Timeout All Requests**: Never wait indefinitely
2. **Cancel Stale Requests**: Cancel requests for outdated file versions
3. **Prioritize User Requests**: User-initiated requests take priority
4. **Batch When Possible**: Batch non-urgent requests

### Caching

1. **Cache Aggressively**: Cache all LSP responses
2. **Invalidate Correctly**: Invalidate cache on file changes
3. **Monitor Hit Rate**: Track and optimize cache hit rate
4. **Limit Cache Size**: Prevent unbounded cache growth

### Error Handling

1. **Always Have Fallback**: Never fail completely
2. **Log All Errors**: Log for debugging and monitoring
3. **Degrade Gracefully**: Provide reduced functionality when LSP unavailable
4. **Recover Automatically**: Auto-reconnect and resume

---

## Integration Checklist

- [ ] Implement persistent connection with auto-reconnect
- [ ] Handle all LSP message types needed
- [ ] Implement timeout handling for all requests
- [ ] Implement caching with proper invalidation
- [ ] Handle all error types gracefully
- [ ] Implement graceful degradation
- [ ] Add performance optimizations (batching, incremental)
- [ ] Add monitoring and logging
- [ ] Test with LSP server crashes
- [ ] Test with network issues
- [ ] Test with large files
- [ ] Test with rapid file changes
- [ ] Measure and optimize cache hit rate
- [ ] Measure and optimize request latency

---

## References

- [LSP Specification](https://microsoft.github.io/language-server-protocol/)
- [LEAN 4 LSP Extensions](https://github.com/leanprover/lean4/tree/master/src/Lean/Server)
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)
