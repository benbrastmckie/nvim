# Git Safety Guide

**Version**: 1.0.0  
**Created**: 2025-12-29  
**Purpose**: Define git-based safety patterns for risky operations (NO backup files)

---

## Overview

Logos/Theory uses **git as the primary safety mechanism** for all risky operations.

**Core Principle**: Never create `.bak` files. Use git commits for safety.

---

## When to Use Git Safety

Create safety commits before:

1. **Bulk deletions** - Archiving tasks, removing files
2. **State modifications** - Updating specs/TODO.md, specs/state.json
3. **Multi-file atomic operations** - Operations that modify multiple files
4. **Irreversible operations** - Operations that can't be easily undone

**Examples**:
- `/todo` command (archives tasks, moves directories)
- Bulk status updates
- Registry updates
- Configuration changes

---

## Git Safety Pattern

### Standard Pattern

```xml
<stage id="N" name="CreateSafetyCommit">
  <action>Create git safety commit before risky operation</action>
  <process>
    1. Stage files that will be modified:
       ```bash
       git add {file1} {file2} {file3}
       ```
    2. Create safety commit:
       ```bash
       git commit -m "safety: pre-{operation} snapshot"
       ```
    3. Store commit SHA for rollback:
       ```bash
       safety_commit=$(git rev-parse HEAD)
       ```
    4. Verify commit created:
       ```bash
       git log -1 --oneline
       ```
  </process>
  <checkpoint>Safety commit created, SHA stored</checkpoint>
</stage>

<stage id="N+1" name="ExecuteRiskyOperation">
  <action>Execute risky operation</action>
  <process>
    1. Execute operation (modify files, move directories, etc.)
    2. If operation fails:
       - Trigger rollback (see Rollback Pattern)
       - Return error to user
    3. If operation succeeds:
       - Proceed to final commit
  </process>
  <checkpoint>Operation executed or rolled back</checkpoint>
</stage>

<stage id="N+2" name="CreateFinalCommit">
  <action>Create final commit with actual changes</action>
  <process>
    1. Stage all changes:
       ```bash
       git add {modified_files}
       ```
    2. Create final commit:
       ```bash
       git commit -m "{operation}: {description}"
       ```
    3. Verify commit created
  </process>
  <checkpoint>Final commit created</checkpoint>
</stage>
```

### Rollback Pattern

```xml
<git_rollback>
  <trigger>Operation fails after safety commit</trigger>
  <process>
    1. Reset to safety commit:
       ```bash
       git reset --hard {safety_commit_sha}
       ```
    2. Clean untracked files:
       ```bash
       git clean -fd
       ```
    3. Verify rollback:
       ```bash
       git status
       ```
    4. Log rollback event to errors.json:
       {
         "type": "git_rollback",
         "operation": "{operation}",
         "safety_commit": "{safety_commit_sha}",
         "timestamp": "{ISO8601}",
         "reason": "{failure_reason}"
       }
    5. Return error to user with rollback confirmation
  </process>
  <user_message>
    Error: {operation} failed
    
    System rolled back to safety commit: {safety_commit_sha}
    All changes reverted.
    
    Recommendation: {recovery_instructions}
  </user_message>
</git_rollback>
```

---

## Commit Message Standards

### Safety Commits

**Format**: `safety: pre-{operation} snapshot`

**Examples**:
- `safety: pre-todo archival snapshot`
- `safety: pre-bulk-status-update snapshot`
- `safety: pre-registry-update snapshot`

**Purpose**: Mark commits as safety checkpoints for easy identification

### Final Commits

**Format**: `{area}: {what}` or `{operation}: {description}`

**Examples**:
- `todo: archive 5 completed tasks`
- `implement: task 195 - LeanSearch integration`
- `review: update registries and create 3 tasks`
- `commands: add targeted git commit rules (task 156)`

**Guidelines**:
- Keep imperative, concise, and scoped to staged changes
- Include task/plan IDs when known (e.g., `(task 156)`)
- No emojis in messages

**Purpose**: Describe actual changes made

### Rollback Commits

**Format**: `rollback: {operation} failed - reverted to {sha}`

**Examples**:
- `rollback: todo archival failed - reverted to abc123`

**Purpose**: Document rollback events (if manual rollback needed)

---

## Scoping Rules for Commits

### When to Commit
- After artifacts are written (code, docs, reports, plans, summaries)
- After status/state/TODO updates are applied
- Once validation steps for the scope are done (e.g., `lake build`, `lake exe test`, lint or file-level checks when code changed)

### Scoping Best Practices
- Stage only files relevant to the current task/feature
- **Avoid repo-wide adds**: Do not use `git add -A` or `git commit -am`
- Use targeted staging: `git add <file1> <file2>`
- Split unrelated changes into separate commits
- Prefer smaller, cohesive commits
- Exclude build artifacts, lockfiles, or generated files unless intentionally changed

### Recommended Commit Flow
1. Review changes: `git status --short`, `git diff --stat` (and `git diff` for details)
2. Stage target files only: `git add path/to/file1 path/to/file2`
3. Re-check scope: `git status --short` to confirm only intended files are staged
4. Run relevant checks (as needed): `lake build`, `lake exe test`, formatters/linters
5. Commit with a focused message: `git commit -m "<area>: <summary> (task 156)"`
6. Leave unstaged any out-of-scope changes for follow-up commits

### Safety Checks Before Commit
- Ensure artifacts exist and references are updated (TODO/state/IMPLEMENTATION_STATUS/SORRY_REGISTRY/TACTIC_REGISTRY when applicable)
- Avoid committing during blocked/abandoned states
- Verify only intended files are staged

---

## Example: /todo Command

### Before (with .bak files)

```xml
<stage id="5" name="AtomicUpdate">
  <process>
    **Phase 1 (Prepare)**:
    1. Backup current state:
       - Backup specs/TODO.md → specs/TODO.md.bak
       - Backup specs/state.json → specs/state.json.bak
       - Backup specs/archive/state.json → specs/archive/state.json.bak
    2. Validate all updates
    
    **Phase 2 (Commit)**:
    1. Write updated files
    2. If any operation fails:
       - Restore from .bak files
       - Delete .bak files
       - Return error
    3. On success:
       - Delete .bak files
  </process>
</stage>
```

### After (with git safety)

```xml
<stage id="5" name="CreateSafetyCommit">
  <action>Create git safety commit</action>
  <process>
    1. Stage files that will be modified:
       ```bash
       git add specs/TODO.md
       git add specs/state.json
       git add specs/specs/archive/state.json
       ```
    2. Create safety commit:
       ```bash
       git commit -m "safety: pre-todo archival snapshot"
       ```
    3. Store commit SHA:
       ```bash
       safety_commit=$(git rev-parse HEAD)
       ```
  </process>
  <checkpoint>Safety commit created</checkpoint>
</stage>

<stage id="6" name="AtomicUpdate">
  <process>
    **Phase 1 (Prepare)**:
    1. Validate all updates in memory
    2. Verify all target paths are writable
    
    **Phase 2 (Commit)**:
    1. Write updated specs/TODO.md
    2. Write updated specs/state.json
    3. Write updated specs/archive/state.json
    4. Move project directories
    5. If any operation fails:
       - Execute git_rollback()
       - Return error
    6. On success:
       - Proceed to final commit
  </process>
  <git_rollback>
    If any write fails:
    1. git reset --hard {safety_commit}
    2. git clean -fd
    3. Log rollback to errors.json
    4. Return error with rollback confirmation
  </git_rollback>
  <checkpoint>Files updated or rolled back</checkpoint>
</stage>

<stage id="7" name="CreateFinalCommit">
  <action>Create final commit</action>
  <process>
    1. Stage all changes:
       ```bash
       git add specs/TODO.md
       git add specs/state.json
       git add specs/archive/
       ```
    2. Create final commit:
       ```bash
       git commit -m "todo: archive {N} completed/abandoned tasks"
       ```
    3. If commit fails:
       - Log error (non-critical, changes already made)
       - Continue (archival complete)
  </process>
  <checkpoint>Final commit created</checkpoint>
</stage>
```

---

## Benefits of Git Safety

### vs Backup Files

| Aspect | Backup Files (.bak) | Git Safety |
|--------|---------------------|------------|
| **Clutter** | Creates .bak files | No extra files |
| **History** | Lost after cleanup | Preserved in git history |
| **Debugging** | Hard to trace | Easy to trace (git log) |
| **Rollback** | Manual file copy | Automatic (git reset) |
| **Verification** | Manual check | Git status |
| **Cleanup** | Manual deletion | Automatic (part of history) |

### Advantages

1. **No file clutter** - No .bak files to manage
2. **Full history** - All safety commits in git log
3. **Easy debugging** - `git log --grep="safety:"` shows all safety points
4. **Atomic rollback** - `git reset --hard` reverts everything
5. **Verification** - `git status` shows clean state after rollback
6. **No cleanup** - Safety commits are part of history

---

## Git Safety Checklist

Before implementing git safety in a command:

- [ ] Identify risky operation (bulk delete, state modification, etc.)
- [ ] Determine which files will be modified
- [ ] Add CreateSafetyCommit stage before risky operation
- [ ] Store safety commit SHA
- [ ] Add rollback logic to risky operation stage
- [ ] Add CreateFinalCommit stage after successful operation
- [ ] Test rollback scenario
- [ ] Remove any .bak file creation code
- [ ] Update error handling to use git rollback

---

## Testing Git Safety

### Test Successful Operation

1. Run command with risky operation
2. Verify safety commit created: `git log -1 --grep="safety:"`
3. Verify operation succeeded
4. Verify final commit created
5. Verify no .bak files created: `find . -name "*.bak"`

### Test Failed Operation

1. Simulate failure (e.g., make file read-only)
2. Run command with risky operation
3. Verify safety commit created
4. Verify operation failed
5. Verify rollback executed: `git log -1`
6. Verify state restored: `git status`
7. Verify error logged to errors.json
8. Verify user received rollback confirmation

### Test Rollback

```bash
# Create safety commit
git add file1 file2
git commit -m "safety: pre-test snapshot"
safety_commit=$(git rev-parse HEAD)

# Make changes
echo "test" >> file1
echo "test" >> file2

# Simulate failure and rollback
git reset --hard $safety_commit
git clean -fd

# Verify rollback
git status  # Should show clean working tree
cat file1   # Should show original content
```

---

## Common Patterns

### Pattern 1: Single File Update

```xml
<stage id="N" name="UpdateFileWithSafety">
  <action>Update file with git safety</action>
  <process>
    1. Create safety commit:
       git add {file}
       git commit -m "safety: pre-{operation} snapshot"
       safety_commit=$(git rev-parse HEAD)
    2. Update file
    3. If update fails:
       git reset --hard $safety_commit
       Return error
    4. Create final commit:
       git add {file}
       git commit -m "{operation}: {description}"
  </process>
</stage>
```

### Pattern 2: Multi-File Atomic Update

```xml
<stage id="N" name="AtomicUpdateWithSafety">
  <action>Atomically update multiple files with git safety</action>
  <process>
    1. Create safety commit:
       git add {file1} {file2} {file3}
       git commit -m "safety: pre-{operation} snapshot"
       safety_commit=$(git rev-parse HEAD)
    2. Update all files
    3. If any update fails:
       git reset --hard $safety_commit
       git clean -fd
       Return error
    4. Create final commit:
       git add {file1} {file2} {file3}
       git commit -m "{operation}: {description}"
  </process>
</stage>
```

### Pattern 3: Directory Operations

```xml
<stage id="N" name="DirectoryOperationWithSafety">
  <action>Move/delete directories with git safety</action>
  <process>
    1. Create safety commit:
       git add {directory}
       git commit -m "safety: pre-{operation} snapshot"
       safety_commit=$(git rev-parse HEAD)
    2. Execute directory operation (move, delete, etc.)
    3. If operation fails:
       git reset --hard $safety_commit
       git clean -fd
       Return error
    4. Create final commit:
       git add {affected_paths}
       git commit -m "{operation}: {description}"
  </process>
</stage>
```

---

## Error Handling

### Git Commit Failure (Safety Commit)

```xml
<error_handling>
  <error_type name="safety_commit_failure">
    <detection>git commit fails when creating safety commit</detection>
    <handling>
      1. Check git status
      2. If nothing to commit:
         - Log warning (no changes to protect)
         - Proceed without safety commit
      3. If git error:
         - Return error to user
         - Recommendation: "Fix git issue and retry"
    </handling>
    <recovery>
      Error: Failed to create safety commit
      
      Git status: {git_status}
      
      Recommendation: Ensure git is configured and working directory is clean
    </recovery>
  </error_type>
</error_handling>
```

### Git Commit Failure (Final Commit)

```xml
<error_handling>
  <error_type name="final_commit_failure">
    <detection>git commit fails when creating final commit</detection>
    <handling>
      1. Log error to errors.json
      2. Continue (operation already succeeded)
      3. Return success with warning
    </handling>
    <recovery>
      Warning: Operation succeeded but git commit failed
      
      Changes made:
      - {change_1}
      - {change_2}
      
      Manual commit required:
        git add {files}
        git commit -m "{operation}: {description}"
      
      Error: {git_error}
    </recovery>
  </error_type>
</error_handling>
```

### Rollback Failure

```xml
<error_handling>
  <error_type name="rollback_failure">
    <detection>git reset --hard fails during rollback</detection>
    <handling>
      1. Log critical error to errors.json
      2. Provide manual recovery instructions
      3. Include safety commit SHA
    </handling>
    <recovery>
      CRITICAL ERROR: Automatic rollback failed
      
      Safety commit: {safety_commit_sha}
      
      Manual recovery steps:
      1. Check git status: git status
      2. Reset to safety commit: git reset --hard {safety_commit_sha}
      3. Clean untracked files: git clean -fd
      4. Verify state: git status
      
      Or restore from git reflog:
      1. View reflog: git reflog
      2. Find safety commit: {safety_commit_sha}
      3. Reset: git reset --hard {safety_commit_sha}
      
      Error: {git_error}
    </recovery>
  </error_type>
</error_handling>
```

---

## Migration Checklist

When removing .bak files and adding git safety:

- [ ] Search for `.bak` creation: `grep -r "\.bak" .opencode/`
- [ ] Search for `backup` keyword: `grep -r "backup" .opencode/`
- [ ] For each backup location:
  - [ ] Add CreateSafetyCommit stage before operation
  - [ ] Remove .bak file creation code
  - [ ] Add git rollback to error handling
  - [ ] Add CreateFinalCommit stage after operation
  - [ ] Update error messages to mention git rollback
  - [ ] Test successful operation
  - [ ] Test failed operation with rollback
- [ ] Verify no .bak files created: `find . -name "*.bak"`
- [ ] Update documentation to reflect git safety

---

## References

- **Command Structure**: `.opencode/context/core/standards/command-structure.md`
- **Subagent Structure**: `.opencode/context/core/standards/subagent-structure.md`
- **Error Handling**: `.opencode/context/core/standards/error-handling.md`
- **Example**: `.opencode/commands/todo.md` (after Phase 4 conversion)
