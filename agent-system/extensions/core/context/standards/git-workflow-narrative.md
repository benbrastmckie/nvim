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

## Never-Run Over-Staging Bullets — Full Per-Form Rationale

The eager core compacts the four over-staging forms into one bullet. The full per-form
rationale behind it:

- **`git add -A` (or `git add .`)** — stages the entire working tree, silently pulling in
  concurrent-session or unrelated stray edits; use targeted, work-scoped staging instead.
- **A directory or glob `git add` pathspec** (e.g. `git add -- some/dir/`, `git add some/dir`,
  `git add src/*.lean`) — stages every modified file the pathspec expands to, the identical
  over-staging harm as `git add -A`/`git add .` in a narrower disguise. The sanctioned explicit
  multi-file list (e.g. `git add -- a.lean b.lean`) is unaffected and remains permitted.
- **`git commit -am`** — implicitly stages all tracked-file modifications, the same
  over-staging problem as `git add -A`.

See `.claude/context/standards/git-staging-scope.md` for the per-operation commit-scope contract
these four forms all violate.

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

**Rollback-procedure walkthrough.** Before any intentional rollback that would otherwise be
blocked by the dirty-tree guard, run `bash .claude/scripts/git-snapshot.sh <task-number>` first,
then retry the destructive command. Pass the task number explicitly — the no-argument form only
resolves when exactly one task in `specs/state.json` has status `implementing`, which does not
hold when several tasks are in flight at once. Default (and `--branch`) mode REFUSES this
invocation, naming every offending path, when the dirty tree carries tracked modifications
outside the task's declared `file_scope` (or when the task has no declared `file_scope` at all)
— see `git-snapshot.sh --help` and `context/contracts/recovery.md`'s rollback rung. A genuine
whole-tree rollback is exactly the deliberate scenario the guard's `--allow-out-of-scope`
override exists for: append it to the invocation above
(`bash .claude/scripts/git-snapshot.sh <task-number> --allow-out-of-scope`) to proceed.

**Why the default form is never a routine checkpoint.** `git-snapshot.sh`'s default (reverting)
form must never be emitted as a routine, non-rollback checkpoint — that idiom is exactly the
incident this guard and `agents/planner-agent.md`'s corresponding MUST NOT bullet exist to close.
An ordinary defensive checkpoint before risky work belongs to `--no-revert` instead (durable,
non-reverting; see `context/patterns/checkpoint-before-overflow.md`), never to a bare
default-mode call.

## No Destructive Git on Uncommitted Work — Bare `git stash` Incident and Full Detail

The eager core keeps the forbidden/not-blocked lists, the Item 7 and Item 8 verdicts, and the
one-paragraph concurrent-writer hazard statement in full. The mechanism detail, the measured
incident, the verdicts' extended reasoning, and the known residual risk behind it:

**Mechanism**. Under concurrent writers sharing one tree, `git stash` (bare, or `git stash
push` with no pathspec) reverts the working tree to HEAD, moving the uncommitted changes into a
stash entry. That is reversible on a solo tree: a later `git stash pop` restores them. Under
concurrent writers it is not reliably reversible: if a sibling writer commits a change to the
same path while the stash is outstanding, the later `git stash pop` can abort with "local
changes would be overwritten" — git correctly refusing to silently clobber the sibling's new
commit, but as a side effect leaving the original changes unapplied. At that moment the changes
are no longer recoverable *in place*; they exist only inside the stash entry and must be
extracted path-by-path (`git stash show -p stash@{0} -- <path>` or similar), which an agent
discovering this for the first time, mid-task, is unlikely to do before moving on or quietly
dropping the stash.

**Incident (observed 2026-10-07, re-derived at implementation time from the task record; every
figure below is a carried figure to re-confirm, not an established count)**. During a multi-task
`/orchestrate` batch of four tasks sharing one working tree in a separate consumer repository,
two independent implementation agents each ran a bare, whole-tree `git stash` for the same
legitimate purpose — isolating a pre-existing test failure from their own edit — and both passed
the guard correctly, per the rule as it was written at the time (`git stash` was listed
**Not blocked**). One stash spanned a build reported at roughly 375 seconds while sibling
agents kept committing; its `git stash pop` subsequently aborted and applied nothing. Roughly
thirty files of the user's pre-session uncommitted work — a freshly-deployed configuration tree
plus its extension-state file — were reverted out of the working tree by the first `git stash`
and captured by no commit, surviving only inside a 53-file stash entry; a second, 3-file stash
entry came from the other agent's independent stash. Sibling *commits* were unharmed throughout,
which is exactly why a commits-only verification pass cleared both incidents falsely; the
verification-scope half of that finding is filed and tracked separately and is not covered here.

**Item 7 verdict, extended reasoning (pathspec-scoped `git stash push -- <pathspec>` stays
permitted)**. A pathspec-scoped stash's blast radius is bounded to the named paths — the same
shape already granted to `git restore --staged <path>` and non-forced `checkout`/`switch`
between branches. Blocking it as well as the whole-tree form would leave agents with no safe
way to stash at all under a shared tree, which contradicts the territory-contract model this
codebase already uses for concurrent dispatch (each agent's own declared `file_scope` is
exactly the set of paths a scoped stash would touch). The hazard that makes the bare form
dangerous — an unbounded set of paths that a sibling might also touch — does not apply once the
set is named and bounded by the agent itself.

**Item 8 verdict, extended reasoning (`git stash pop` / `git stash apply` stay permitted)**. The
data-loss moment in the measured incident is the *push* (the tree revert), not the recovery
step. A `pop` or `apply` that would overwrite a sibling's intervening write is refused by git
itself — it leaves the stash entry intact (`pop`'s failure mode) or leaves conflict markers for
manual resolution (`apply`'s), never a silent discard. This is the identical safe-failure shape
that already keeps non-forced `checkout`/`switch` permitted: the operation either succeeds
cleanly or refuses loudly, and the forbidden-list membership in this rule is reserved for
operations that can succeed while silently discarding something.

**Known residual risk — `git-snapshot.sh`'s own internal stash**. `scripts/git-snapshot.sh`'s
default mode internally runs `git stash push -u` as its own snapshot primitive before the
caller's destructive command proceeds. That internal call carries a narrower form of the exact
same concurrency hazard this section describes: a recovery `git stash pop` issued later against
that internal stash could itself be refused by an intervening sibling write. It is
subprocess-invisible to `guard-destructive-git.sh` — the identical invisibility precedent the
hook's own header already documents for `git-commit-scoped.sh`'s internal git calls — so the
`stash_revert` detector neither blocks nor needs to exempt it; snapshotting continues to work
exactly as before. The stash-provenance mechanism below resolves this invisibility gap for
SESSION-SCOPED pop authorization specifically: a pre-call snapshot plus a post-call diff
(across the whole Bash call that invokes `git-snapshot.sh`) correctly attributes the internally
created stash sha to the calling session, so the sanctioned rollback pop it prints still passes.
The CONCURRENT-WRITER hazard this paragraph originally described — a sibling's intervening
commit causing the pop itself to abort — is unchanged and still open; this is flagged here as a
known, accepted residual risk for a future task if it recurs in practice, and is deliberately
**not** fixed by this change — redesigning `git-snapshot.sh`'s internal mechanism remains out of
scope.

**Wrong-identity hazard (`git stash pop`/`apply` of a FOREIGN entry)**. A separate hazard from
the sibling-conflict one above, closed by a different mechanism: a `git stash pop`/`apply` with
NOTHING of the caller's own on the stack still succeeds — it simply applies whatever entry sits
at the named (or default `stash@{0}`) position — and silently DROPS that entry on success. This
is dangerous specifically because it needs no conflict and no concurrent writer at all: it fires
even on a solo tree, even on a CLEAN tree, whenever the caller's own preceding `git stash push`
saved nothing of its own ("No local changes to save") and the caller then pops anyway, assuming
the entry on the stack is its own. Evidence (consumer repository, 2026-10-09): while diagnosing
a test failure, an implementation agent ran `git stash push -- <path>` (which saved nothing) and
then `git stash pop`; with nothing of its own on the stack, the pop applied and DROPPED
`stash@{0}`, an unrelated pre-existing user WIP entry from another task. The net tree effect
happened to be zero in that incident, but the user's stash entry was permanently removed from
the list, recoverable only via `git fsck --unreachable`. This hazard is closed by SESSION
IDENTITY, not by the sibling-conflict safe-failure argument the Item 8 verdict above states —
that argument is still correct for the hazard it was written against (a pop that WOULD conflict
refuses loudly rather than silently discarding); it says nothing about a pop that conflicts with
NOTHING because the caller never put anything of its own on the stack in the first place. See
`guard-destructive-git.sh`'s tree-state-blind stash-provenance predicate, which refuses a
`pop`/`apply` whose target sha a per-session ledger
(`scripts/lib/stash-provenance-lib.sh`) does not record as created by the calling session,
pending a `stash_pop_foreign` grant.

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
