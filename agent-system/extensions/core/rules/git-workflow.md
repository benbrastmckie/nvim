---
paths: ["specs/**/*", ".claude/**/*"]
---

# Git Workflow Rules

## Commit Conventions

### Task-Scoped Commits

All commits related to tasks use this format:
```
task {N}: {action} {description}
```

### Standard Actions

| Operation | Commit Message |
|-----------|----------------|
| Create task | `task {N}: create {title}` |
| Complete research | `task {N}: complete research` |
| Create plan | `task {N}: create implementation plan` |
| Green sub-step (in-progress phase) | `task {N} phase {P}.{O}: {objective_description}` |
| Complete phase | `task {N} phase {P}: {phase_name}` |
| Complete implementation | `task {N}: complete implementation` |
| Revise plan | `task {N}: revise plan (v{V})` |

### System Operations

| Operation | Commit Message |
|-----------|----------------|
| Archive tasks | `todo: archive {N} completed tasks` |
| Error fixes | `errors: create fix plan for {N} errors (task {M})` |
| Review | `review: {summary}` |
| State sync | `sync: reconcile TODO.md and state.json` |

## Commit Timing

### Create Commits After
- Task creation (includes TODO.md + state.json updates)
- Research completion (includes report file)
- Plan creation (includes plan file)
- Each implementation phase completion
- Final implementation completion (includes summary)
- Task archival operations

### Do Not Commit
- Partial/incomplete work — half-applied, unverified edits (a file half-written, an edit made but
  not yet checked to exist/be non-empty, a step abandoned mid-way). This does not forbid a
  declared `Commit Mode: atomic-batch` phase's expected-red intermediate per-file states — see
  the "Atomic-batch objectives" bullet under Commit-Per-Green-Substep Mandate below for that
  carve-out; it applies only to an explicitly pre-declared batch, never an ad hoc one.
- Failed operations (rollback instead)

### Commit-Per-Green-Substep Mandate

**Every verified-green sub-step is committed as it happens — this is a mandate, not an
optional-when-convenient practice.** "Intermediate states during multi-phase operations" is NOT
a reason to withhold a commit: an intermediate state that is *green* (its own verification
criteria passed — see `checkpoint-before-overflow.md`'s green/RED distinction) MUST be
committed, not held back until the whole phase or task finishes. This replaces an earlier,
contradictory version of this rule that listed "intermediate states" as uncommittable; that
language conflicted directly with the checkpoint-before-overflow and progress-file granularity
this codebase already relies on for crash recovery, and has been removed.

See `context/standards/git-workflow-narrative.md` for the sub-step granularity definition,
the atomic-batch carve-out, the staging-reuse mechanism, and the message-convention pointer.

## Commit Scope

See `.claude/context/standards/git-staging-scope.md` for the authoritative per-operation
commit-scope contract (`research`/`plan`/`implement` staging rules, the proven scoped-staging
template, and the fail-safe under-stage-not-over-stage direction).

## Git Safety

### Never Run
- `git push --force` to main/master
- `git reset --hard` on uncommitted work without a snapshot first — see
  "No Destructive Git on Uncommitted Work" below for the full rule and exemptions
- Bare `git commit --amend` while any other dispatched writer is live in this repo — see
  "No History Rewrites While Another Writer Is Live" below for the full rule, the incident that
  motivates it, and what stays permitted
- A HEAD-moving `git reset` (`--soft`, `--mixed`, bare, or `--hard` given a commit-ish) while any
  other dispatched writer is live in this repo — see "No History Rewrites While Another Writer Is
  Live" below; pathspec-only unstaging (`git reset -- <path>`, `git reset HEAD -- <path>`) is
  unaffected
- `git rebase -i` (interactive mode not supported)
- Any destructive operations without user confirmation
- `git add -A` (or `git add .`) — stages the entire working tree, silently pulling in
  concurrent-session or unrelated stray edits; use targeted, work-scoped staging instead. See
  `.claude/context/standards/git-staging-scope.md` for the per-operation commit-scope contract.
- A **directory or glob `git add` pathspec** (e.g. `git add -- some/dir/`, `git add some/dir`,
  `git add src/*.lean`) — stages every modified file the pathspec expands to, the identical
  over-staging harm as `git add -A`/`git add .` in a narrower disguise. The sanctioned explicit
  multi-file list (e.g. `git add -- a.lean b.lean`) is unaffected and remains permitted.
- `git commit -am` — implicitly stages all tracked-file modifications, the same over-staging
  problem as `git add -A`

**Enforced by `guard-destructive-git.sh`**: the over-staging bullets above (`git add -A`/`git
add .`, the directory-or-glob `git add` pathspec, and `git commit -am`) are enforced mechanically
by the same `guard-destructive-git.sh` PreToolUse Bash hook described below for the
destructive-command class — its over-staging predicate blocks them on a dirty working tree via
`exit 2`, with NO snapshot-marker exemption (a snapshot makes a destructive command recoverable;
it does not make scope pollution acceptable). The history-rewrite bullets above are enforced by
that same hook's **separate, concurrency-gated** predicate: unlike every other predicate in this
file, it does not consult tree dirtiness at all and has no snapshot-marker exemption — it
refuses purely on evidence of a live concurrent writer.

### No Destructive Git on Uncommitted Work

Agents MUST NOT run git operations that discard working-tree changes while
uncommitted changes exist, unless a snapshot was just taken. This is enforced by
the `guard-destructive-git.sh` PreToolUse Bash hook (registered in `settings.json`),
which blocks the commands below via `exit 2` + stderr guidance when the tree is
dirty and no fresh snapshot exists.

**Forbidden on a dirty tree** (discards uncommitted changes):
- `git reset --hard`
- `git checkout -- <path>` (pathspec discard form)
- `git restore <path>` (without `--staged`; `--staged` only unstages and is safe)
- `git clean -fd` (or any flag ordering/clustering that combines `-f` and `-d`)
- `git stash drop` / `git stash clear`
- Forced `git checkout` / `git switch` (`-f` / `--force`) — can silently overwrite
  local changes when switching branches

**Exemption — allowed when EITHER**:
1. The working tree is already clean (`git status --porcelain` is empty) — there is
   nothing to lose, so the hook exits 0 immediately. This is also how the sanctioned
   `/todo` safety-commit rollback flow (see `.claude/context/standards/git-safety.md`)
   stays exempt: the safety commit makes the tree clean *before* the
   `git reset --hard {sha}` / `git clean -fd` rollback runs, so it is never blocked.
2. A snapshot was just taken via `bash .claude/scripts/git-snapshot.sh` (the
   sanctioned way to snapshot). See `context/standards/git-workflow-narrative.md` for the
   per-mode detail (default / `--branch` / `--no-revert`).

Before any intentional rollback that would otherwise be blocked, run
`bash .claude/scripts/git-snapshot.sh <task-number>` first, then retry the destructive
command. Pass the task number explicitly — the no-argument form only resolves when
exactly one task in `specs/state.json` has status `implementing`, which does not hold
when several tasks are in flight at once. Default (and `--branch`) mode REFUSES this
invocation, naming every offending path, when the dirty tree carries tracked
modifications outside the task's declared `file_scope` (or when the task has no declared
`file_scope` at all) — see `git-snapshot.sh --help` and
`context/contracts/recovery.md`'s rollback rung. A genuine whole-tree rollback (the case
this paragraph documents) is exactly the deliberate scenario the guard's
`--allow-out-of-scope` override exists for: append it to the invocation above
(`bash .claude/scripts/git-snapshot.sh <task-number> --allow-out-of-scope`) to proceed.

**Never emit `git-snapshot.sh` in its default (reverting) form as a routine,
non-rollback checkpoint** — that idiom is exactly the incident this guard and
`agents/planner-agent.md`'s corresponding MUST NOT bullet exist to close. An ordinary
defensive checkpoint before risky work belongs to `--no-revert` instead (durable,
non-reverting; see `context/patterns/checkpoint-before-overflow.md`), never to a bare
default-mode call.

**Not blocked** (do not discard uncommitted changes): `git stash` (push),
`git stash pop` / `git stash apply`, `git restore --staged <path>`, and non-forced
`git checkout` / `git switch` between branches.

### No History Rewrites While Another Writer Is Live

Agents MUST NOT run a bare `git commit --amend` or a HEAD-moving `git reset` while any other
dispatched writer is live in this repo. All commits go through
`.claude/scripts/git-commit-scoped.sh`, never a raw `git commit`/`git reset` invocation.

**The distinction from the rule above, stated explicitly**: the rule above ("No Destructive Git
on Uncommitted Work") is scoped by *dirtiness of the working tree* — it exists to stop a command
from discarding uncommitted changes, and it exempts a clean tree because there is nothing left to
lose. This rule is scoped by an entirely different variable: *concurrency of writers*. Both
`git commit --amend` and a non-`--hard` `git reset` are non-destructive to the working tree —
that is exactly why the rule above structurally cannot fire on them, on a dirty tree or a clean
one. The hazard here is rewriting **already-committed history** that a different writer may have
extended in the interim, which has nothing to do with tree state.

**Incident (observed 2026-09-02)**. During a multi-task `/orchestrate` run with five concurrent
implementation agents committing to master, one agent ran a bare `git commit --amend` intending
to add an attribution trailer to what it believed was its own most recent commit. Between its
commit and the amend, a sibling agent's commit had landed on top, so the amend rewrote the
sibling's commit instead — preserving that commit's tree content but overwriting its message.
The agent then ran `git reset --mixed <own-sha>` to undo the mistake, which rewound HEAD past
three further legitimate commits and intermingled their changes in the working tree. It caught
this and restored HEAD via the reflog. Verified afterward: the trees were identical throughout
and zero content was lost; the only residual damage is one commit left with a mislabeled message.
Reconstructible reflog evidence: `539561c39` (the correct commit), `9c5b790b6` (the orphaned
original), `fd50fabfd` (tree-identical to `9c5b790b6`, carrying the wrong message).

**What stays permitted**:
- Every commit made through `.claude/scripts/git-commit-scoped.sh` — its internal git invocations
  run as a subprocess and are invisible at the hook's observation boundary; this is the
  sanctioned path and needs no special-casing.
- Solo interactive `git commit --amend` when no other writer is live — the discriminating
  variable is concurrency, not the command itself.
- Bare `git reset`, `git reset -- <path>`, and `git reset HEAD -- <path>` (pathspec-only
  unstaging; none of these move HEAD).
- A commit message that merely contains the literal text `--amend`.

**Practical guidance for the incident's actual motive**: if a commit already carries a missing
trailer or a wrong message, and other writers may be active, **leave it alone** — add a
follow-up commit or record the discrepancy. Never amend to fix it under concurrency; the fix is
not worth the risk of rewriting a sibling's history.

**Enforcement**: `guard-destructive-git.sh`'s concurrency-gated history-rewrite predicate refuses
the matched command with `exit 2` when evidence of a live concurrent writer exists. There is a
documented, auditable operator-only override, `GUARD_ALLOW_HISTORY_REWRITE=1` prefixed onto the
command — **agents MUST NOT use this override**; it exists solely for a human operator working
the branch interactively.

### Always Check Before Commit
- `git status` to verify staged files
- `git diff --staged` to review changes
- Ensure no sensitive files (.env, credentials) are staged
- See `.claude/context/standards/git-staging-scope.md` for the required `git status --short` /
  `git diff --staged` review flow before any targeted commit

## Commit Message Format

```
{scope}: {action} {description}

Session: {session_id}
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

See `context/standards/git-workflow-narrative.md` for the Session ID lifecycle, Branch Strategy,
and commit-failure Error Handling narrative.

### Examples

<!-- task-ref-ok:begin canonical rendered commit-message example -->
```
task 259 phase 2: implement modal semantics evaluator

Session: sess_1736701234_d4e5f6
```
<!-- task-ref-ok:end -->
