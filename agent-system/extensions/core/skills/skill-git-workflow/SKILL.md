---
name: skill-git-workflow
description: Create scoped git commits for task operations. Invoke after task status changes or artifact creation.
allowed-tools: Bash(git:*)
# Context loaded on-demand via @-references (see Context Loading section)
---

# Git Workflow Skill

Create properly scoped git commits for task operations.

## Context Loading

Load context on-demand when needed:
- `@.claude/context/standards/git-staging-scope.md` - Canonical per-operation commit-scope
  contract (research/plan/implement staging rules, forbidden operations, fail-safe direction)
- `@.claude/context/standards/git-safety.md` - Git safety rules and best practices
- `@.claude/context/index.json` - Full context discovery index

## Relationship to `orchestrator-postflight.sh`

This skill is the **documentation front** for the commit-scope contract — it is not literally
invoked as a runtime script from bash. `.claude/scripts/orchestrator-postflight.sh` is now an
orphaned script with no live callers (confirmed by a repo-wide grep for actual invocation sites)
— it was the shared postflight-commit execution site for the three base lifecycle skills before
they were deleted. The actual execution of task-scoped commits happens today in:

- `.claude/skills/skill-orchestrate/SKILL.md`'s own dispatch-loop commit sites (single-task
  CHECKPOINT 3 and multi-task Stage MT-4 step 5.5) — the shared execution site for
  `research`/`plan`/`implement` postflight commits, branching on outcome for targeted staging
  (never staging the entire working tree).
- `.claude/agents/general-implementation-agent.md`'s Green Sub-Step Commit (per-objective) and
  Phase Checkpoint Protocol (per-phase commit) — the innermost, per-objective/per-phase commit
  sites for `implement` dispatch.

Both sites implement the same contract documented in `git-staging-scope.md`. This SKILL.md
describes that contract and where it is enforced; it does not add a third execution path.

## Trigger Conditions

This skill activates when:
- Task status changes (research, plan, implement complete)
- Artifacts are created
- Task lifecycle operations occur

## Commit Message Formats

### Task Operations

| Operation | Format | CI Triggered |
|-----------|--------|--------------|
| Create task | `task {N}: create {title}` | No |
| Complete research | `task {N}: complete research` | No |
| Create plan | `task {N}: create implementation plan` | No |
| Complete phase | `task {N} phase {P}: {phase_name}` | No |
| Complete task | `task {N}: complete implementation` | No |
| Complete task (with CI) | `task {N}: complete implementation [ci]` | Yes |
| Revise plan | `task {N}: revise plan (v{V})` | No |

### System Operations

| Operation | Format |
|-----------|--------|
| Archive tasks | `todo: archive {N} completed tasks` |
| Error fixes | `errors: create fix plan for {N} errors` |
| Code review | `review: {scope} code review` |
| State sync | `sync: reconcile TODO.md and state.json` |

## Execution Flow

```
1. Receive commit request:
   - operation_type
   - task_number (if applicable)
   - scope (files to include)
   - message_template

2. Determine appropriate files:
   - {scope}

3. Stage and commit together via `git-commit-scoped.sh`:
   - Format message
   - Execute `bash .claude/scripts/git-commit-scoped.sh --message "..." --session "${session_id}" -- {scope}`

4. Verify success:
   - Check exit code
   - Log result

5. Return result
```

## Commit Scope Rules

See `@.claude/context/standards/git-staging-scope.md` for the authoritative, canonical
per-operation commit-scope contract. Summary:

### Task-Specific Commits
Include only task-related files:
```
specs/TODO.md
specs/state.json
specs/{NNN}_{SLUG}/**
```

### Implementation Commits
Include source files modified, via the agent's self-reported `modified_files` field (see
`@.claude/context/formats/return-metadata-file.md`) — never a blanket stage of the entire
working tree:
```
Logos/**/*.lean  (for Lean tasks)
src/**/*         (for general tasks)
```

### Phase Commits
Scope to phase changes only, using the paths accumulated in that phase's progress-file
`files_touched` array (see `@.claude/context/formats/progress-file.md`):
```
Files modified in that phase
Updated plan with phase status
```

### Fail-Safe Direction

Under-stage with a loud, non-silent warning rather than over-stage. If the modified-files
self-report is absent or empty, stage only the fixed task-directory paths and print a warning —
never fall back to staging the entire working tree.

## Safety Checks

### Before Commit
```
1. git status - verify staged files
2. Check no sensitive files staged (.env, credentials)
3. Verify commit message format
```

### Never Run
- `git push --force`
- `git reset --hard` (without explicit request)
- `git rebase -i`
- `git add -A` / `git add .` (stages the entire working tree; use targeted staging per
  `@.claude/context/standards/git-staging-scope.md` instead)
- A directory or glob `git add` pathspec (e.g. `git add -- some/dir/`, `git add src/*.lean`) —
  same over-staging problem as `git add -A`/`.` in a narrower disguise; an explicit multi-file
  list (`git add -- a.lean b.lean`) remains permitted
- `git commit -am` (implicitly stages all tracked-file modifications — same over-staging problem)

## Message Template

```
{scope}: {action} {description}
```

## CI Triggering

### Overview

CI is **skipped by default** on push events. To trigger CI, add `[ci]` marker to the commit message.

### trigger_ci Parameter

When creating commits, the `trigger_ci` parameter controls whether CI runs:

| Value | Behavior | Use Case |
|-------|----------|----------|
| `false` (default) | No CI marker added | Routine commits, research, planning |
| `true` | Append `[ci]` to message | Lean changes, implementation completion |

### CI Decision Criteria

Trigger CI (`trigger_ci: true`) when:
- **Lean files modified** (.lean) - Ensures build passes
- **Implementation completed** - Final verification before merge
- **CI configuration changed** (.github/workflows/) - Validate workflow changes
- **Mathlib dependencies updated** (lakefile.lean, lake-manifest.json) - Ensure compatibility
- **Critical bug fixes** - Verify fix works

Skip CI (default) when:
- Documentation changes only (.md files)
- Research/planning artifacts
- Configuration changes (non-CI)
- Routine task management operations

### Commit Message with CI Marker

```
task {N}: complete implementation [ci]
```

### When CI Always Runs

CI runs regardless of marker on:
- Pull request events (all PRs run CI)
- Manual workflow_dispatch trigger
- Commits with `[ci]` marker

## Execution Commands

Both forms below go through `.claude/scripts/git-commit-scoped.sh`, the single sanctioned
implementation of path-scoped, mutex-serialized committing — never a bare `git add` followed by a
a bare `git commit`.

### Standard Commit
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "{message}" \
  --session "${session_id}" \
  -- {files}
```

### Task Commit
```bash
bash .claude/scripts/git-commit-scoped.sh \
  --message "task {N}: {action}" \
  --session "${session_id}" \
  -- specs/
```

## Return Format

```json
{
  "status": "completed|failed",
  "summary": "Created commit: {short_message}",
  "commit_hash": "abc123",
  "files_committed": [
    "path/to/file1",
    "path/to/file2"
  ],
  "message": "Full commit message",
  "ci_triggered": true|false
}
```

## Error Handling

### Nothing to Commit
```json
{
  "status": "committed",
  "summary": "No changes to commit",
  "commit_hash": null
}
```

### Pre-Commit Hook Failure
```json
{
  "status": "failed",
  "error": "Pre-commit hook failed",
  "recovery": "Fix issues and retry (do not use --no-verify)"
}
```

### Git Error
```json
{
  "status": "failed",
  "error": "Git command failed: {error}",
  "recovery": "Check git status and resolve manually"
}
```

## Non-Blocking Behavior

Git failures should NOT block task operations:
- Log the failure
- Continue with task
- Report to user that commit failed
- Task state is preserved regardless
