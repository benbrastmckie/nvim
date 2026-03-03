# Postflight Control Pattern

## Overview

This pattern enables uninterrupted workflow execution by using a marker file to signal when postflight operations are pending. The SubagentStop hook checks for this marker and blocks premature termination.

## Problem Solved

OpenCode has a known limitation (GitHub Issue #17351): nested skills return to the main session instead of the invoking skill. This causes workflow interruptions requiring user "continue" input between skill return and orchestrator postflight.

## Solution Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  SKILL EXECUTION FLOW                                       │
│                                                             │
│  1. Skill creates postflight marker                         │
│  2. Skill invokes subagent via Task tool                    │
│  3. Subagent executes and returns                          │
│  4. SubagentStop hook detects marker → blocks stop          │
│  5. Skill continues with postflight operations              │
│  6. Skill removes marker                                    │
│  7. Normal stop allowed                                     │
└─────────────────────────────────────────────────────────────┘
```

## Marker File Protocol

### Location

```
specs/.postflight-pending
```

### Format

```json
{
  "session_id": "sess_1736700000_abc123",
  "skill": "skill-lean-research",
  "task_number": 259,
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "2026-01-18T10:00:00Z",
  "stop_hook_active": false
}
```

### Fields

| Field | Required | Description |
|-------|----------|-------------|
| `session_id` | Yes | Current session identifier |
| `skill` | Yes | Name of skill that created marker |
| `task_number` | Yes | Task being processed |
| `operation` | Yes | Operation type (research, plan, implement) |
| `reason` | Yes | Human-readable description of pending work |
| `created` | Yes | ISO 8601 timestamp |
| `stop_hook_active` | No | Set to true to bypass hook (prevents loops) |

## Skill Integration

### Creating the Marker (Before Subagent Invocation)

```bash
# Create postflight marker
cat > specs/.postflight-pending << 'EOF'
{
  "session_id": "$session_id",
  "skill": "skill-lean-research",
  "task_number": $task_number,
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
```

### Removing the Marker (After Postflight Complete)

```bash
# Remove marker after postflight is complete
rm -f specs/.postflight-pending
rm -f specs/.postflight-loop-guard
```

### Emergency Bypass (If Stuck in Loop)

```bash
# Set stop_hook_active to force stop on next iteration
jq '.stop_hook_active = true' specs/.postflight-pending > /tmp/marker.json && \
  mv /tmp/marker.json specs/.postflight-pending
```

## SubagentStop Hook Behavior

The hook at `.opencode/hooks/subagent-postflight.sh`:

1. **Checks for marker file**: `specs/.postflight-pending`
2. **If marker exists**:
   - Checks `stop_hook_active` flag (bypass if true)
   - Checks loop guard counter (max 3 continuations)
   - Returns `{"decision": "block", "reason": "..."}` to continue execution
3. **If no marker**: Returns `{}` to allow normal stop

### Loop Guard

To prevent infinite loops, the hook maintains a counter in `specs/.postflight-loop-guard`:
- Incremented on each blocked stop
- After 3 continuations, cleanup and allow stop
- Reset when marker is removed normally

## Complete Skill Example

```markdown
## Skill Execution Flow

### Stage 1: Create Postflight Marker

Before invoking the subagent, create the marker file:

\`\`\`bash
cat > specs/.postflight-pending << EOF
{
  "session_id": "${session_id}",
  "skill": "skill-lean-research",
  "task_number": ${task_number},
  "operation": "research",
  "reason": "Postflight pending: status update, artifact linking, git commit",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "stop_hook_active": false
}
EOF
\`\`\`

### Stage 2: Invoke Subagent

Invoke the subagent via Task tool as normal.

### Stage 3: Subagent Returns

Subagent writes metadata to `.return-meta.json` and returns brief summary.

### Stage 4: Execute Postflight (Hook Ensures We Reach Here)

1. Read `.return-meta.json`
2. Update specs/state.json status
3. Update specs/TODO.md status
4. Link artifacts
5. Git commit changes

### Stage 5: Cleanup

\`\`\`bash
rm -f specs/.postflight-pending
rm -f specs/.postflight-loop-guard
rm -f specs/${task_number}_*/. return-meta.json
\`\`\`

### Stage 6: Return Brief Summary

Return a brief 3-6 bullet summary (NO JSON).
```

## Debugging

### View Hook Logs

```bash
cat .opencode/logs/subagent-postflight.log
```

### Check Marker State

```bash
cat specs/.postflight-pending | jq .
```

### Check Loop Guard

```bash
cat specs/.postflight-loop-guard
```

### Manual Cleanup (Emergency)

```bash
rm -f specs/.postflight-pending
rm -f specs/.postflight-loop-guard
```

## Error Scenarios

### Scenario 1: Hook Never Fires

**Symptom**: "Continue" prompts still appear

**Check**:
1. Verify SubagentStop hook is in settings.json
2. Verify hook script is executable
3. Verify marker file is being created

### Scenario 2: Infinite Loop

**Symptom**: Execution loops endlessly

**Solution**:
1. Press Ctrl+C to interrupt
2. Run: `rm -f specs/.postflight-pending specs/.postflight-loop-guard`
3. Restart session

**Prevention**: Loop guard limits to 3 continuations

### Scenario 3: Marker Not Cleaned Up

**Symptom**: All commands trigger hook

**Solution**:
```bash
rm -f specs/.postflight-pending
```

## Related Documentation

- `.opencode/hooks/subagent-postflight.sh` - Hook script implementation
- `.opencode/settings.json` - Hook configuration
- `.opencode/context/core/patterns/file-metadata-exchange.md` - Metadata file protocol
- `.opencode/context/core/troubleshooting/workflow-interruptions.md` - Full troubleshooting guide
