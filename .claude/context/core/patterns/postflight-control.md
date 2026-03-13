# Postflight Control Pattern

## Overview

This pattern enables uninterrupted workflow execution by using a marker file to signal when postflight operations are pending. The SubagentStop hook checks for this marker and blocks premature termination.

## Purpose

Claude Code skill returns can bypass the invoking skill and return directly to the main session (GitHub Issue #17351). This pattern uses a marker file to ensure postflight operations execute after subagent return.

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
specs/{NNN}_{SLUG}/.postflight-pending
```

Where `{N}` is the task number and `{SLUG}` is the project name (e.g., `specs/259_prove_completeness/.postflight-pending`).

This task-scoped location enables safe concurrent agent execution on different tasks while maintaining single-agent-per-task guarantees.

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
# Ensure task directory exists
mkdir -p "specs/OC_${padded_num}_${project_name}"

# Create postflight marker in task directory
cat > "specs/OC_${padded_num}_${project_name}/.postflight-pending" << 'EOF'
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
rm -f "specs/OC_${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/OC_${padded_num}_${project_name}/.postflight-loop-guard"
```

### Emergency Bypass (If Stuck in Loop)

```bash
# Set stop_hook_active to force stop on next iteration
marker_file=$(find specs -maxdepth 3 -name ".postflight-pending" -type f | head -1)
if [ -n "$marker_file" ]; then
    jq '.stop_hook_active = true' "$marker_file" > /tmp/marker.json && \
      mv /tmp/marker.json "$marker_file"
fi
```

## SubagentStop Hook Behavior

The hook at `.claude/hooks/subagent-postflight.sh`:

1. **Searches for marker file**: Uses `find specs -maxdepth 3 -name ".postflight-pending"` to locate task-scoped markers
2. **Falls back to global marker**: For backward compatibility, checks `specs/.postflight-pending` if no task-scoped marker found
3. **If marker exists**:
   - Checks `stop_hook_active` flag (bypass if true)
   - Checks loop guard counter (max 3 continuations)
   - Returns `{"decision": "block", "reason": "..."}` to continue execution
4. **If no marker**: Returns `{}` to allow normal stop

### Loop Guard

To prevent infinite loops, the hook maintains a counter in the task directory:
- Location: `specs/OC_{NNN}_{SLUG}/.postflight-loop-guard` (same directory as marker)
- Incremented on each blocked stop
- After 3 continuations, cleanup and allow stop
- Reset when marker is removed normally

## Complete Skill Example

```markdown
## Skill Execution Flow

### Stage 1: Create Postflight Marker

Before invoking the subagent, create the marker file:

\`\`\`bash
# Ensure task directory exists
mkdir -p "specs/OC_${padded_num}_${project_name}"

cat > "specs/OC_${padded_num}_${project_name}/.postflight-pending" << EOF
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
2. Update state.json status
3. Update TODO.md status
4. Link artifacts
5. Git commit changes

### Stage 5: Cleanup

\`\`\`bash
rm -f "specs/OC_${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/OC_${padded_num}_${project_name}/.postflight-loop-guard"
rm -f "specs/OC_${padded_num}_${project_name}/.return-meta.json"
\`\`\`

### Stage 6: Return Brief Summary

Return a brief 3-6 bullet summary (NO JSON).
```

## Debugging

### View Hook Logs

```bash
cat .claude/logs/subagent-postflight.log
```

### Check Marker State

```bash
# Find and display current marker
marker=$(find specs -maxdepth 3 -name ".postflight-pending" -type f | head -1)
if [ -n "$marker" ]; then
    echo "Marker found at: $marker"
    cat "$marker" | jq .
else
    echo "No postflight marker found"
fi
```

### Check Loop Guard

```bash
# Find and display loop guard
guard=$(find specs -maxdepth 3 -name ".postflight-loop-guard" -type f | head -1)
if [ -n "$guard" ]; then
    echo "Loop guard at: $guard"
    cat "$guard"
else
    echo "No loop guard found"
fi
```

### Manual Cleanup (Emergency)

```bash
# Clean specific task
rm -f "specs/OC_${padded_num}_${project_name}/.postflight-pending"
rm -f "specs/OC_${padded_num}_${project_name}/.postflight-loop-guard"

# Clean all orphaned markers (across all tasks)
find specs -maxdepth 3 -name ".postflight-pending" -delete
find specs -maxdepth 3 -name ".postflight-loop-guard" -delete
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
2. Run: `find specs -maxdepth 3 -name ".postflight-pending" -delete && find specs -maxdepth 3 -name ".postflight-loop-guard" -delete`
3. Restart session

**Prevention**: Loop guard limits to 3 continuations

### Scenario 3: Marker Not Cleaned Up

**Symptom**: All commands trigger hook

**Solution**:
```bash
# Find and remove orphaned marker
find specs -maxdepth 3 -name ".postflight-pending" -delete
find specs -maxdepth 3 -name ".postflight-loop-guard" -delete
```

## Related Documentation

- `.claude/hooks/subagent-postflight.sh` - Hook script implementation
- `.claude/settings.json` - Hook configuration
- `.claude/context/core/patterns/file-metadata-exchange.md` - Metadata file protocol
- `.claude/context/core/troubleshooting/workflow-interruptions.md` - Full troubleshooting guide
