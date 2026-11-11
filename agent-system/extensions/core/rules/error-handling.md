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
Record the error non-fatally via `bash .claude/scripts/issue-record.sh --task-dir "$TASK_DIR"
--kind issue --class "CLASS" --severity ... --what-happened "..."` — the general-purpose capture
path for a dispatch-time error inside a task context. See `context/formats/issue-log.md` for the
full CLI/field contract, the severity scale, the seed class enum (including
`infrastructure/transport unavailable`, the class an external-system failure belongs to — see
"External Errors Mapped" below), and the CAPTURE ONLY boundary.

**No-task-context route**: when no task directory exists (where `issue-record.sh` structurally
cannot serve), capture via `bash .claude/scripts/events-append.sh --event-type "error" --category
blocker --session "$session_id" --message "..."` instead, with `--task` omitted (nullable by
design). See `context/formats/events-format.md`'s `category` enum discussion for the full
nullable-`task` contract.

#### Where Errors Are Stored

See `context/formats/issue-log.md`'s "The Three-Store Topology" section for the full verdict:
`issues.jsonl` is the general capture path for task-scoped work; `events.jsonl` is the
append-only lifecycle store and the no-task-context path. `specs/errors.json`/`errors-append.sh`/
`/errors` are a narrower, decoupled triage surface with their own schema — not this write path.
`errors-append.sh` has exactly one caller today (`core/commands/errors.md`, `update` only, never
`append`). Retiring `errors.json`/`errors-append.sh`/`/errors` outright is an open question left
to a follow-up, not taken here.

#### External Errors Mapped

`tool_unavailable` and `mcp_abort_error` above are `issues.jsonl`'s `infrastructure/transport
unavailable` class: infrastructure unavailable, not the task's own work failing — nothing in
cycle accounting reads it today.

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

## Write-Gating Constraint: Never Discard Uncommitted Changes for a Build Fix

On a build error: fix forward — correct the source to resolve the error. **Never discard
uncommitted changes to reach a passing build** — see `.claude/context/contracts/recovery.md` for
the full recovery ladder (fix forward -> strategic-sorry skeleton -> snapshot-then-rollback) and
the "No Destructive Git on Uncommitted Work" rule in `git-workflow.md`.

See `context/standards/error-recovery-strategies.md` for the full per-error-type recovery
strategies (Timeout, State Sync, Build Error, jq Parse Failure, MCP Abort Error, Delegation
Interrupted).

## Non-Blocking Errors

These should not stop execution:
- Git commit failures
- Metric collection failures
- Non-critical logging failures

Log and continue, report at end.
