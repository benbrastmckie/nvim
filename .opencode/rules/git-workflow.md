# Git Workflow Rules

## Commit Conventions

### Task-Scoped Commits

All commits related to OpenCode tasks use this format:
```
task OC_{N}: {action} {description}
```

The `OC_` prefix distinguishes OpenCode tasks from Claude Code tasks (which use unprefixed numbers).

### Standard Actions

| Operation | Commit Message |
|-----------|----------------|
| Create task | `task OC_{N}: create {title}` |
| Complete research | `task OC_{N}: complete research` |
| Create plan | `task OC_{N}: create implementation plan` |
| Complete phase | `task OC_{N} phase {P}: {phase_name}` |
| Complete implementation | `task OC_{N}: complete implementation` |
| Revise plan | `task OC_{N}: revise plan (v{V})` |

### System Operations

| Operation | Commit Message |
|-----------|----------------|
| Archive tasks | `todo: archive {N} completed tasks` |
| Error fixes | `errors: create fix plan for {N} errors (task {M})` |
| Review | `review: {summary}` |
| State sync | `sync: reconcile specs/TODO.md and specs/state.json` |

## Commit Timing

### Create Commits After
- Task creation (includes specs/TODO.md + specs/state.json updates)
- Research completion (includes report file)
- Plan creation (includes plan file)
- Each implementation phase completion
- Final implementation completion (includes summary)
- Task archival operations

### Do Not Commit
- Partial/incomplete work
- Failed operations (rollback instead)
- Intermediate states during multi-phase operations

## Commit Scope

### Single-Task Operations
Include only files related to that task:
```
task OC_17: complete research

Modified:
  specs/TODO.md
  specs/state.json
  specs/OC_017_task_slug/reports/research-001.md
```

### Multi-Task Operations
Group related changes:
```
todo: archive 5 completed tasks

Modified:
  specs/TODO.md
  specs/state.json
  specs/archive/state.json
```

## Git Safety

### Never Run
- `git push --force` to main/master
- `git reset --hard` without explicit user request
- `git rebase -i` (interactive mode not supported)
- Any destructive operations without user confirmation

### Always Check Before Commit
- `git status` to verify staged files
- `git diff --staged` to review changes
- Ensure no sensitive files (.env, credentials) are staged

## Commit Message Format

```
{scope}: {action} {description}

Session: {session_id}

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

### Session ID

Session ID links commits to their originating command execution.

**Format**: `sess_{unix_timestamp}_{6_char_random}`
**Example**: `sess_1736700000_a1b2c3`

**Generation**:
```bash
# Portable command (works on NixOS, macOS, Linux - no xxd dependency)
session_id="sess_$(date +%s)_$(od -An -N3 -tx1 /dev/urandom | tr -d ' ')"
```

**Lifecycle**:
1. Generated at CHECKPOINT 1 (GATE IN)
2. Passed through delegation to skill/agent
3. Included in error logs for traceability
4. Included in final git commit

### Examples

```
task OC_17: create LaTeX documentation for Logos system

Session: sess_1736700000_a1b2c3

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

```
task OC_25 phase 2: implement modal semantics evaluator

Session: sess_1736701234_d4e5f6

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

```
todo: archive 3 completed tasks (OC_12, OC_15, OC_18)

Session: sess_1736702000_789abc

Co-Authored-By: OpenCode <noreply@opencode.ai>
```

## Branch Strategy

### Main Development
- Work on `main` or feature branches
- Commit frequently with descriptive messages
- Keep commits atomic (one logical change per commit)

### Task Branches (Optional)
For complex multi-phase implementations:
```
task-OC_{N}-{slug}
```

## Error Handling

### On Commit Failure
1. Log the failure
2. Do not block the operation
3. Preserve changes for manual commit
4. Report to user that commit failed

### On Pre-Commit Hook Failure
1. Do not use --no-verify
2. Fix the issue
3. Create new commit (never amend failed commits)
