# Git Workflow Narrative and Elaboration

This is the lazily-loaded companion to `rules/git-workflow.md`. The eager core there carries every
commit-format table, forbidden-operation list, and write-gating prohibition an agent must know
**before** committing or running a destructive git command. This file carries the reactive
elaboration: mechanism detail, lifecycle description, and narrative that is useful once an agent
is already following the core's rules, but is never itself a pre-action gate.

## Commit-Per-Green-Substep Mandate — Elaboration

The eager core states the mandate in one binding sentence. The mechanism detail behind it:

- **Sub-step granularity**: a "sub-step" is a `progress-file.md` objective transitioning to
  `status: "done"` — the same unit `files_touched` accumulates against (see
  `.claude/context/formats/progress-file.md`).
- **"Green" means verified, not merely attempted**: the objective's own verification criteria
  passed (a check ran and succeeded, files were confirmed to exist and be non-empty, or a
  build/test step passed where applicable) — per `checkpoint-before-overflow.md`'s green/RED
  distinction. "Some tool calls happened" is NOT green; an unverified edit is still
  partial/incomplete work per the "Do Not Commit" list and stays uncommitted until it can be
  confirmed green.
- **Atomic-batch objectives**: a plan may declare a phase `Commit Mode: atomic-batch` (see
  `context/formats/plan-format.md`'s `## Verification Tiers` section, the authoritative home of
  the `Commit Mode` field definition). When it does, the sub-step IS the whole batch: one
  `progress-file.md` objective spans the phase's declared file set, and intermediate per-file
  states are expected to be red and MUST NOT be committed. This is consistent with, not an
  exception to, the sub-step granularity definition above — "a `progress-file.md` objective
  transitioning to `status: "done"`" was already unit-agnostic; this bullet makes the
  multi-file case explicit rather than redefining it. The objective's own green criterion is the
  batch-level verification taken at the phase's declared tier; one commit then covers the whole
  batch. **Anti-abuse guard**: the batch must be declared in the plan in advance — an implementer
  may NOT retroactively widen a batch to avoid committing already-green work.
- **Staging reuses the existing `implement` scope verbatim** — task dir + `plan_path` + the
  agent's self-reported `modified_files` (`.claude/context/standards/git-staging-scope.md`) and
  `checkpoint-before-overflow.md`'s green-commit branch. This is NOT a second staging codepath:
  the same under-stage-never-over-stage discipline and the same forbidden `git add -A` /
  `git commit -am` operations apply identically to sub-step commits.
- **Message convention**: see the `task {N} phase {P}.{O}: {objective_description}` row in the
  eager core's Standard Actions table — finer-grained than the existing per-phase row, used
  specifically for a single objective's green commit within a phase still in progress.

## No Destructive Git on Uncommitted Work — Snapshot Mode Detail

The eager core keeps the forbidden-operations list and the "snapshot first via
`git-snapshot.sh`" instruction in full. The mode-by-mode detail behind the snapshot exemption:

A snapshot was just taken via `bash .claude/scripts/git-snapshot.sh` (the sanctioned way to
snapshot). The helper writes a durable `.patch` under `specs/{NNN}_{SLUG}/` plus a
belt-and-suspenders `git stash` (default mode), a WIP commit on a scratch branch (`--branch`
mode), or a non-mutating stored stash plus an `untracked-backup-{ts}/` copy (`--no-revert` mode),
then refreshes a short-lived, single-use freshness marker that the hook consumes on the next
matching destructive command.

**The default and `--branch` modes both REVERT the working tree.** Both leave it clean
at HEAD, with the uncommitted edits recoverable only from the reported patch, stash, or
branch; `--branch` changes the recovery handle, not whether the revert happens. That is
the intended behavior at this call site, because the snapshot sits immediately before an
already-decided destructive command. For a purely defensive checkpoint where work
continues afterwards, use `--no-revert`, which leaves the tree untouched.

## No History Rewrites While Another Writer Is Live — Incident and Full Detail

The eager core keeps the rule, the one-sentence dirtiness-vs-concurrency distinction, a brief
permitted-forms summary, and the enforcement pointer in full. The incident record and the
complete permitted/guidance detail behind it:

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

**What stays permitted, in full**:
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

**The operator override in full**: `GUARD_ALLOW_HISTORY_REWRITE=1` prefixed onto the command
falls through `guard-destructive-git.sh`'s concurrency-gated predicate. It is detected in the
scanned command text only, never the hook's own environment, so any use stays visible in the
transcript. It exists solely for a human operator working the branch interactively —
**agents MUST NOT use it**.

## Session ID Lifecycle

1. Generated at CHECKPOINT 1 (GATE IN)
2. Passed through delegation to skill/agent
3. Included in error logs for traceability
4. Included in final git commit

## Branch Strategy

### Main Development
- Work on `main` or feature branches
- Commit frequently with descriptive messages
- Keep commits atomic (one logical change per commit)

### Task Branches (Optional)
For complex multi-phase implementations:
```
task-{N}-{slug}
```

## Error Handling (Commit Failures)

### On Commit Failure
1. Log the failure
2. Do not block the operation
3. Preserve changes for manual commit
4. Report to user that commit failed

### On Pre-Commit Hook Failure
1. Do not use --no-verify
2. Fix the issue
3. Create new commit (never amend failed commits)
