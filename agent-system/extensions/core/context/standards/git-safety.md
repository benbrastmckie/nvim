# Git Safety Guide

**Created**: 2025-12-29  
**Purpose**: Define git-based safety patterns for risky operations (NO backup files)

---

## Overview

This agent system uses **git as the primary safety mechanism** for all risky operations.

**Core Principle**: Never create `.bak` files. Use git commits for safety.

**Sanctioned commit path**: every commit shown in this guide — safety commit and final commit
alike — goes through `.claude/scripts/git-commit-scoped.sh`, the single sanctioned implementation
of the scoped-commit contract (path-scoped staging plus mutex-serialized commit; see
`context/standards/git-staging-scope.md`). Never a bare `git add` followed by a bare
bare `git add` plus a bare `git commit`.

---

## When to Use Git Safety

Create safety commits before:

1. **Bulk deletions** - Archiving tasks, removing files
2. **State modifications** - Updating TODO.md, state.json
3. **Multi-file atomic operations** - Operations that modify multiple files
4. **Irreversible operations** - Operations that can't be easily undone

**Examples**:
- `/todo` command (archives tasks, moves directories)
- Bulk status updates
- Registry updates
- Configuration changes

---

## Recovering an Unconsumed Dispatch

`guard-destructive-git.sh` (a PreToolUse Bash hook) blocks `git reset --hard`,
`git checkout -- <path>`, `git clean -fd`, and the other discard-uncommitted-work commands listed
in `context/standards/git-staging-scope.md` whenever the working tree is dirty and no fresh
snapshot was just taken. This is deliberate: on a dirty tree shared with a concurrently
dispatched task, git-based undo cannot distinguish "revert my own stray write" from "discard
someone else's in-flight work," so the guard refuses both alike. See
`context/standards/git-staging-scope.md` for the guard's full command list and the
snapshot-exemption mechanics.

When the thing to undo is a `/orchestrate` dispatch that was prepared (Move 1: a preflight status
write, a task lock, a `.dispatch/{seq}.md` file, and durable loop-guard bookkeeping) but never
issued (no agent call, no postflight), the sanctioned non-git recovery path is
`scripts/orchestrate-unwind-dispatch.sh <task_number> --session SID [--dry-run] [--commit]` — it
reverses exactly those Move 1 mutations via the normal sanctioned writers
(`state-write.sh`, `orchestrate-loop-guard-init.sh`, `task-lock.sh release`,
`git-commit-scoped.sh`), or refuses cleanly if the dispatch may already be in progress or
consumed. See `docs/architecture/orchestrate-state-machine.md`'s "Unwinding an Unconsumed
Dispatch" subsection for the full refusal-gate contract and the by-hand-only rationale.

---

## A Second Hazard Class: Rewriting Already-Committed History Under Concurrent Writers

Everything in the section above — the guard's discard-uncommitted-work predicates, the
snapshot-marker exemption, the clean-tree exemption — is scoped by **dirtiness of the working
tree**. That design cannot address a structurally different hazard: rewriting a commit that a
*different* dispatched writer already made. Bare `git commit --amend` and a HEAD-moving
`git reset` (`--soft`/`--mixed`/bare, or `--hard` given a commit-ish) are both non-destructive to
the working tree — a dirty-tree-scoped guard therefore waves them through on a dirty tree exactly
as on a clean one. This is not a gap the existing predicates can be widened to close; it needs a
predicate scoped by an entirely different variable.

**The incident (observed 2026-09-02)**: during a multi-task `/orchestrate` run with five
concurrent implementation agents committing to master, one agent's bare `git commit --amend`
(intended for its own most recent commit) rewrote a sibling agent's commit instead, because the
sibling's commit had landed on top in the interim — preserving the sibling's tree content but
overwriting its message. A follow-up `git reset --mixed <own-sha>` rewound HEAD past three further
legitimate commits, intermingling their changes in the working tree; the agent caught this and
restored HEAD via the reflog. Trees were identical throughout, zero content was lost, and the
only residual damage is one commit left with a mislabeled message.

**The chosen signal**: `guard-destructive-git.sh` carries a second, independent predicate that
consults **live writer evidence**, never tree state:

- Two record families, read directly and cwd-relatively (never via `task-lock.sh`, which sources
  `deploy-root-guard.sh` — `exit 1`ing from the source store — and anchors `PROJECT_ROOT` to its
  own `SCRIPT_DIR` rather than the caller's cwd, both fatal for a hermetically testable hook):
  `specs/{NNN}_{SLUG}/.lock/holder.json` (per-task locks) and `specs/.sessions/*.json` (the
  session registry).
- A record is **live** when its `pid` is numeric and `kill -0 "$pid"` succeeds, AND its
  `heartbeat_at` is within `HISTORY_REWRITE_LIVE_MIN` minutes (default 30, matching
  `TASK_LOCK_STALE_MIN`'s semantics).
- **Threshold: one or more** live records refuses, with no attempt to exclude "self" — the hook
  cannot correlate its own native Claude Code session UUID to an agent-system `sess_*` identity,
  and a dispatched agent's own live lock is itself proof it is running under orchestration, where
  bare rewrites are forbidden outright. A genuinely solo interactive operator has no live lock and
  no live registry entry.
- **Fails open** (permits) on any missing `specs/`, missing `jq`, unreadable record, or
  unparseable timestamp — this predicate is a net layered over a documented rule, not the rule's
  sole enforcement.
- **Response is binary** `exit 2` + stderr, no warn tier, with a documented, auditable
  operator-only override (`GUARD_ALLOW_HISTORY_REWRITE=1`, detected in the scanned command text,
  never the hook's own environment) that agents MUST NOT use.

See `.claude/rules/git-workflow.md`'s "No History Rewrites While Another Writer Is Live" section
for the full policy statement and what stays permitted (solo `--amend` with no live writer,
pathspec-only `reset` unstaging, `git-commit-scoped.sh`, and message text merely containing
`--amend`), and `context/contracts/recovery.md`'s "Green Means Fix Forward" section for how this
interacts with the fix-forward discipline.

---

## Git Safety Pattern

### Standard Pattern

```xml
<stage id="N" name="CreateSafetyCommit">
  <action>Create git safety commit before risky operation</action>
  <process>
    1. Create safety commit via the scoped-commit script (stages and commits in one call):
       ```bash
       bash .claude/scripts/git-commit-scoped.sh \
         --message "safety: pre-{operation} snapshot" \
         --session "${session_id}" \
         -- {file1} {file2} {file3}
       ```
    2. Store commit SHA for rollback:
       ```bash
       safety_commit=$(git rev-parse HEAD)
       ```
    3. Verify commit created:
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
    1. Create final commit via the scoped-commit script:
       ```bash
       bash .claude/scripts/git-commit-scoped.sh \
         --message "{operation}: {description}" \
         --session "${session_id}" \
         -- {modified_files}
       ```
    2. Verify commit created
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
- `implement: task {N} - LeanSearch integration`
- `review: update registries and create 3 tasks`
- `commands: add targeted git commit rules (task {N})`

**Guidelines**:
- Keep imperative, concise, and scoped to staged changes
- Include task/plan IDs when known (e.g., `(task {N})`)
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
- Use targeted pathspecs, passed straight to `git-commit-scoped.sh`'s trailing `-- <pathspec>...`
- Split unrelated changes into separate commits
- Prefer smaller, cohesive commits
- Exclude build artifacts, lockfiles, or generated files unless intentionally changed

### Recommended Commit Flow
1. Review changes: `git status --short`, `git diff --stat` (and `git diff` for details)
2. Identify target files only: `path/to/file1 path/to/file2`
3. Run relevant checks (as needed): `lake build`, `lake exe test`, formatters/linters
4. Commit with a focused message via the scoped-commit script:
   `bash .claude/scripts/git-commit-scoped.sh --message "<area>: <summary> (task {N})" --session "${session_id}" -- path/to/file1 path/to/file2`
5. Re-check scope with `git status --short` after the commit to confirm no unrelated file was
   swept in
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
       - Backup TODO.md → TODO.md.bak
       - Backup state.json → state.json.bak
       - Backup archive/state.json → archive/state.json.bak
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
    1. Create safety commit via the scoped-commit script:
       ```bash
       bash .claude/scripts/git-commit-scoped.sh \
         --message "safety: pre-todo archival snapshot" \
         --session "${session_id}" \
         -- specs/TODO.md specs/state.json specs/archive/state.json
       ```
    2. Store commit SHA:
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
    1. Write updated TODO.md
    2. Write updated state.json
    3. Write updated archive/state.json
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
    1. Create final commit via the scoped-commit script. Never a bare `specs/archive/`
       directory pathspec here (it would stage any OTHER concurrent session's uncommitted
       `specs/archive/` writes too) -- name `specs/archive/state.json` explicitly, the same file
       already named at stage 5's safety commit above, plus each project directory Stage 6
       actually moved into `specs/archive/`:
       ```bash
       bash .claude/scripts/git-commit-scoped.sh \
         --message "todo: archive {N} completed/abandoned tasks" \
         --session "${session_id}" \
         -- specs/TODO.md specs/state.json specs/archive/state.json {moved_directory_paths}
       ```
    2. If commit fails:
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
bash .claude/scripts/git-commit-scoped.sh \
  --message "safety: pre-test snapshot" \
  --session "${session_id}" \
  -- file1 file2
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
       bash .claude/scripts/git-commit-scoped.sh --message "safety: pre-{operation} snapshot" --session "${session_id}" -- {file}
       safety_commit=$(git rev-parse HEAD)
    2. Update file
    3. If update fails:
       git reset --hard $safety_commit
       Return error
    4. Create final commit:
       bash .claude/scripts/git-commit-scoped.sh --message "{operation}: {description}" --session "${session_id}" -- {file}
  </process>
</stage>
```

### Pattern 2: Multi-File Atomic Update

```xml
<stage id="N" name="AtomicUpdateWithSafety">
  <action>Atomically update multiple files with git safety</action>
  <process>
    1. Create safety commit:
       bash .claude/scripts/git-commit-scoped.sh --message "safety: pre-{operation} snapshot" --session "${session_id}" -- {file1} {file2} {file3}
       safety_commit=$(git rev-parse HEAD)
    2. Update all files
    3. If any update fails:
       git reset --hard $safety_commit
       git clean -fd
       Return error
    4. Create final commit:
       bash .claude/scripts/git-commit-scoped.sh --message "{operation}: {description}" --session "${session_id}" -- {file1} {file2} {file3}
  </process>
</stage>
```

### Pattern 3: Directory Operations

```xml
<stage id="N" name="DirectoryOperationWithSafety">
  <action>Move/delete directories with git safety</action>
  <process>
    1. Create safety commit:
       bash .claude/scripts/git-commit-scoped.sh --message "safety: pre-{operation} snapshot" --session "${session_id}" -- {directory}
       safety_commit=$(git rev-parse HEAD)
    2. Execute directory operation (move, delete, etc.)
    3. If operation fails:
       git reset --hard $safety_commit
       git clean -fd
       Return error
    4. Create final commit:
       bash .claude/scripts/git-commit-scoped.sh --message "{operation}: {description}" --session "${session_id}" -- {affected_paths}
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
        bash .claude/scripts/git-commit-scoped.sh --message "{operation}: {description}" --session "${session_id}" -- {files}
      
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

- [ ] Search for `.bak` creation: `grep -r "\.bak" .claude/`
- [ ] Search for `backup` keyword: `grep -r "backup" .claude/`
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

- **Command Structure**: `.claude/context/standards/command-structure.md`
- **Subagent Structure**: `.claude/context/standards/subagent-structure.md`
- **Error Handling**: `.claude/context/standards/error-handling.md`
- **Example**: `.claude/command/todo.md` (after Phase 4 conversion)
