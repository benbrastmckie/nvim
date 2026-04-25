---
paths: specs/**/*
---

# State Management Rules

## File Synchronization

TODO.md and state.json MUST stay synchronized. Any update to one requires updating the other.

### Canonical Sources
- **state.json**: Machine-readable source of truth
  - next_project_number
  - active_projects array with status, task_type
  - Faster to query (12ms vs 100ms for TODO.md parsing)

- **TODO.md**: User-facing source of truth
  - Human-readable task list with descriptions
  - Status markers in brackets: [STATUS]
  - Single `## Tasks` section (new tasks prepended at top)

## Status Transitions

### Permissive Model

Any command can run from any non-terminal status. Only terminal states block transitions:

```
Terminal states: [COMPLETED], [ABANDONED], [EXPANDED]

Any non-terminal status -> any command (research, plan, implement, revise)
Any status -> [BLOCKED] (with reason)
Any status -> [ABANDONED] (moves to archive)
Any non-terminal -> [EXPANDED] (when divided into subtasks)
[IMPLEMENTING] -> [PARTIAL] (on timeout/error)
```

### Restrictions
- Cannot transition from terminal states (completed, abandoned, expanded)
- Cannot mark COMPLETED without all phases done

## Two-Phase Update Pattern

When updating task status:

### Phase 1: Prepare
```
1. Read current state.json
2. Read current TODO.md
3. Validate task exists in both
4. Prepare updated content in memory
5. Validate updates are consistent
```

### Phase 2: Commit
```
1. Write state.json (machine state first)
2. Write TODO.md (user-facing second)
3. Verify both writes succeeded
4. If either fails: log error, preserve original state
```

## Error Handling

### On Write Failure
1. Do not update either file partially
2. Log error with context
3. Preserve original state
4. Return error to caller

### On Inconsistency Detection
1. Log the inconsistency
2. Use git blame to determine latest
3. Sync to latest version
4. Use git for recovery of overwritten versions

## Schema Reference

For complete field schemas, status values mapping, artifact linking formats, and directory creation patterns, see:
- [State Management Schema](.claude/context/reference/state-management-schema.md)
