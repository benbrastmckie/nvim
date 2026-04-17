# Git Integration Standards

## Overview

All state-changing operations MUST create git commits for traceability and rollback capability.

## Git Commit Delegation Pattern

### When to Create Commits

Create git commits for:
- Task creation (`/task "description"`)
- Task recovery (`/task --recover`)
- Task expansion (`/task --expand`)
- Task synchronization (`/task --sync`)
- Task abandonment (`/task --abandon`)
- Status updates (`/implement`, `/research`, `/plan`, etc.)

### Delegation Pattern

After successful state-changing operation:

1. Delegate to git-workflow-manager:
   ```
   - scope_files: [list of modified files]
   - message_template: "{operation}: {summary}"
   - task_context: {operation-specific context}
   - session_id: {session_id}
   - delegation_depth: {depth + 1}
   - delegation_path: [...path, "git-workflow-manager"]
   ```

2. Wait for return from git-workflow-manager

3. If git commit succeeds:
   - Extract commit_hash from return
   - Log: "Git commit created: {commit_hash}"
   - Include commit hash in success message

4. If git commit fails:
   - Log warning: "Git commit failed (non-critical): {error}"
   - Continue with success message (files already updated)

### Commit Message Formats

**Task Creation**:
```
task: create task {number} - {title}
```

**Task Recovery**:
```
task: recover {count} tasks from archive ({ranges})

Examples:
- task: recover 1 task from archive (350)
- task: recover 3 tasks from archive (343-345)
- task: recover 4 tasks from archive (337, 343-345)
```

**Task Division**:
```
task: divide task {parent_number} into {subtask_count} subtasks ({subtask_range})

Examples:
- task: divide task 326 into 3 subtasks (327-329)
- task: divide task 350 into 5 subtasks (351-355)
```

**Task Synchronization**:
```
task: sync TODO.md and state.json for {count} tasks ({ranges or 'all'})

Conflict resolution:
- Task {number}: {fields_count} fields resolved ({sources})
- Task {number}: {fields_count} fields resolved ({sources})

Total: {conflicts_count} conflicts resolved using git blame

Examples:
- task: sync TODO.md and state.json for 1 task (343)
- task: sync TODO.md and state.json for 3 tasks (343-345)
- task: sync TODO.md and state.json for 150 tasks (all)
```

**Task Abandonment**:
```
task: abandon {count} tasks ({ranges})

Examples:
- task: abandon 1 task (350)
- task: abandon 3 tasks (343-345)
- task: abandon 4 tasks (337, 343-345, 350)
```

## Non-Critical Failure Handling

Git commit failures are NON-CRITICAL:
- Log warning with error details
- Continue with operation success
- Files already updated atomically
- Git commit is best-effort for traceability

Rationale:
- State changes are atomic (via status-sync-manager)
- Git commit happens AFTER atomic state update
- Git failure doesn't invalidate state changes
- User can manually commit if needed

## Commit Hash Logging

Always log commit hash for traceability:
```
Git commit created: {commit_hash}
Files: {files}
Message: {commit_message}
```

This enables:
- Audit trail for all state changes
- Easy rollback via git revert
- Debugging state inconsistencies
- Tracking operation history

## Error Scenarios

### Scenario 1: Nothing to Commit
```
Error: nothing to commit, working tree clean
Cause: Files already committed (e.g., by previous operation)
Action: Log warning, continue with success
```

### Scenario 2: Git Not Available
```
Error: git command not found
Cause: Git not installed or not in PATH
Action: Log warning, continue with success
```

### Scenario 3: Merge Conflict
```
Error: merge conflict in {file}
Cause: Concurrent modifications
Action: Log error, recommend manual resolution
```

## Best Practices

1. **Atomic State Updates First**: Always update state files atomically BEFORE creating git commit
2. **Non-Blocking Commits**: Never fail operation due to git commit failure
3. **Clear Messages**: Use descriptive commit messages with operation context
4. **Scoped Commits**: Only commit files modified by operation
5. **Traceability**: Include task numbers, counts, and ranges in messages

## Integration with status-sync-manager

status-sync-manager handles atomic state updates:
- Two-phase commit for TODO.md and state.json
- Rollback on failure
- Validation of updates

git-workflow-manager handles git commits:
- Stages specified files
- Creates commit with formatted message
- Returns commit hash or error
- Non-blocking on failure

Separation of concerns:
- status-sync-manager: State consistency
- git-workflow-manager: Version control traceability
- Command files: Orchestration and delegation

## Example Flow

```
User: /task --recover 343-345

1. task.md Stage 4 (RecoverTasks):
   - Parse ranges: [343, 344, 345]
   - Delegate to status-sync-manager (unarchive_tasks)
   - Wait for return (status: completed)
   
2. status-sync-manager:
   - Validate tasks exist in archive
   - Update TODO.md, state.json, archive/state.json atomically
   - Return success with files_updated
   
3. task.md Stage 4 (continued):
   - Delegate to git-workflow-manager
   - Wait for return (commit_hash: a1b2c3d)
   
4. git-workflow-manager:
   - Stage files: TODO.md, state.json
   - Create commit: "task: recover 3 tasks from archive (343-345)"
   - Return commit_hash
   
5. task.md Stage 4 (continued):
   - Format success message with commit hash
   - Return to user

Result:
✅ Recovered 3 tasks from archive: 343-345
Git commit: a1b2c3d
```

## Notes

- Git integration added in Phase B of TASK_COMMAND_REMAINING_WORK_PLAN.md
- All task lifecycle operations now create git commits
- Commit failures are non-critical (logged but don't fail operation)
- Enables full audit trail and easy rollback
