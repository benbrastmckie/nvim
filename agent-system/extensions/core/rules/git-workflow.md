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
- Each implementation phase completion — **exactly one** commit per phase, carrying that phase's
  wrap-up provenance (heading marker, progress file, self-review annotations, phase-end handoff)
  alongside its work; see `context/standards/git-staging-scope.md`'s `### implement` section for
  the ruling and its rationale.
- Final implementation completion (includes summary)
- Task archival operations

### Do Not Commit
- Partial/incomplete work — half-applied, unverified edits (a file half-written, an edit made but
  not yet checked to exist/be non-empty, a step abandoned mid-way). This does not forbid a
  declared `Commit Mode: atomic-batch` phase's expected-red intermediate per-file states — see
  the "Atomic-batch objectives" bullet under Commit-Per-Green-Substep Mandate below for that
  carve-out; it applies only to an explicitly pre-declared batch, never an ad hoc one.
- Failed operations (rollback instead)
- A trailing, provenance-only commit (e.g. a phase-end handoff) issued after a phase's closing
  commit has already fired — a plan phase closes with exactly one commit, per
  `context/standards/git-staging-scope.md`'s `### implement` section.

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
- `git push --force` to main/master. All `git push` is prohibited (`/please` exception,
  `pr-prohibition.md`).
- `git reset --hard` on uncommitted work without a snapshot first — see
  "No Destructive Git on Uncommitted Work" below for the full rule and exemptions
- Bare `git commit --amend` or a HEAD-moving `git reset` while another writer is live in this
  repo — see "No History Rewrites While Another Writer Is Live" below
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

**Enforced by `guard-destructive-git.sh`**: the over-staging bullets (`git add -A`/`.`, the
directory-or-glob pathspec, `git commit -am`) are enforced by this hook via `exit 2` on a dirty
tree, no snapshot exemption. The history-rewrite bullet is enforced by a **separate,
concurrency-gated** predicate in the same hook that ignores tree dirtiness and has no snapshot
exemption either.

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
`bash .claude/scripts/git-snapshot.sh <task-number>` first (task number explicit, not the
no-argument form), then retry the destructive command. Agents MUST NOT emit `git-snapshot.sh` in
its default (reverting) form as a routine, non-rollback checkpoint — use `--no-revert` for an
ordinary defensive checkpoint instead. See
`context/standards/git-workflow-narrative.md`'s "No Destructive Git on Uncommitted Work —
Snapshot Mode Detail" section for the full rollback-procedure walkthrough, the
`file_scope`/`--allow-out-of-scope` refusal mechanics, and `context/patterns/checkpoint-before-overflow.md`
for the `--no-revert` checkpoint pattern.

**Not blocked** (do not discard uncommitted changes): `git stash` (push),
`git stash pop` / `git stash apply`, `git restore --staged <path>`, and non-forced
`git checkout` / `git switch` between branches.

### No History Rewrites While Another Writer Is Live

Agents MUST NOT run a bare `git commit --amend` or a HEAD-moving `git reset` while another
writer is live in this repo. Commits go through `.claude/scripts/git-commit-scoped.sh`.

Unlike the rule above (dirtiness-scoped), this one is scoped by *concurrency of writers* and
fires on a clean tree too — the hazard is rewriting history another writer may have extended.
Permitted: `git-commit-scoped.sh`, solo `--amend` with no live writer, pathspec-only `reset`, and
`--amend`-mentioning messages.

**Enforcement**: `guard-destructive-git.sh`'s predicate refuses with `exit 2` (operator override
`GUARD_ALLOW_HISTORY_REWRITE=1`; agents MUST NOT use it). Detail:
`context/standards/git-workflow-narrative.md`; design: `git-safety.md`.

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
