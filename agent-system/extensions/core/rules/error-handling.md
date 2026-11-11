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
Record the error via `bash .claude/scripts/issue-record.sh`, the general-purpose capture path
for a dispatch-time error inside a task context:

```bash
bash .claude/scripts/issue-record.sh --task-dir "$TASK_DIR" --kind issue \
  --class "CLASS" --severity blocking|costly|minor|none \
  --what-happened "What happened" [--phase research|plan|implement|conclusion|other] \
  [--dispatch-seq N] [--evidence-path PATH] [--resolution fixed_inline|worked_around|open] \
  >/dev/null 2>&1 || echo "Note: issue recording failed (non-fatal)" >&2
```

See `context/formats/issue-log.md` for the full field contract, the severity scale's admission
tests, the seed class enum (including `infrastructure/transport unavailable`, the class an
external-system failure belongs to — see "External Errors Mapped Onto the Class Vocabulary"
below), and the CAPTURE ONLY boundary this call must respect.

**No-task-context route**: `issue-record.sh` hard-requires a task directory and structurally
cannot serve a session with no task directory at all. When no task directory exists, capture via
`events-append.sh` instead, with `--task` omitted (nullable by design, not a workaround):

```bash
bash .claude/scripts/events-append.sh --event-type "error" --category blocker \
  --session "$session_id" --message "What happened" [--detail-json '{"...":"..."}'] \
  >/dev/null 2>&1 || echo "Note: event recording failed (non-fatal)" >&2
```

See `context/formats/events-format.md`'s `category` closed-enum discussion for the full
nullable-`task` contract this route relies on.

#### Where Errors Are Stored

See `context/formats/issue-log.md`'s "The Three-Store Topology" section for the full three-way
verdict. In short: `issues.jsonl` (via `issue-record.sh`, above) is the general-purpose capture
path for task-scoped work; `events.jsonl` (via `events-append.sh`, above) is the append-only
lifecycle store and the capture path when no task directory exists.

`specs/errors.json` (via `scripts/errors-append.sh`) and the `/errors` command are a narrower,
decoupled triage surface with their own living-record schema (`context/schemas/errors-schema.json`,
`context/formats/errors-format.md`) — not the general error-handling write path described above.
`errors-append.sh` has exactly one caller today, `core/commands/errors.md`, and that caller only
ever invokes its `update` subcommand (never `append`) to mutate an existing record's fix status.
Whether `errors.json`, `errors-append.sh`, and `/errors` should be retired outright is an open
question left to a follow-up — a decision that would delete a command and a schema, deliberately
not taken here.

#### External Errors Mapped Onto the Class Vocabulary

Two of the External Errors categories above correspond directly to `issues.jsonl`'s
`infrastructure/transport unavailable` seed class: `tool_unavailable` (an MCP tool not
responding) and `mcp_abort_error` (an MCP tool aborted or timed out). An entry of that class
records infrastructure being unavailable, not the task's own work failing — nothing in cycle
accounting reads it today.

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
