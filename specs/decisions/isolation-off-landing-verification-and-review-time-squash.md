# Decision Record: Isolation-Off Landing Is Verification, and the Per-Task Squash Is Built at Review Time

This record rules how a completed task's work is landed, verified and handed to review in a
repository where worktree isolation is off, which by operator direction of 2026-11-23 is the
only path being built. It amends
`specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` (the "amending record") in
the places listed under "Assertions amended".

Decided 2026-11-23 by `per_task_attribution_squash_landing` (673), research dispatch, session
`sess_1795425897_6a25f2_673`. Evidence:
`specs/673_per_task_attribution_squash_landing/reports/01_isolation-off-landing-ruling.md`.
Tasks are named by slug with the number alongside.

This record rules. It builds nothing. Until the implementing plan lands, `milestone-ref-land.sh`
and its tree-equality `--verify` stay wired exactly as they are.

**Amended by** `specs/decisions/review-slices-are-declared-tasks.md`, 2026-11-23: L3 and L4, and
the "Interface to review submission" section, are amended for repositories that adopt declared
review slices. The reviewable unit becomes a slice declared before the work rather than a unit
reconstructed from landing proofs at review time. L1, L2, the verification predicate V1 to V5,
the landing proof and the retirement order are unaffected.

**Amended by** `specs/decisions/slice-command-one-path-to-review.md`, 2026-11-24: L3, L4 and the
"Interface to review submission" section are amended again. The reviewable unit is a slice, a
declared path set cut from the work-branch tip; one commit per slice is built at review time by
plumbing, and no landing proof is read to build it. L1, L2, L5, the verification predicate V1 to
V5, the landing proof and the retirement order are unaffected.

## The contradiction

R3-amended builds the per-task squash by reading a batch branch: it selects the task's commits
between the merge base and the batch tip and applies them with `git cherry-pick -n` in the
primary tree. The same record requires every ruling to hold where no worktree and no batch
branch exist. With isolation off the primary tree is already on the integration branch and each
phase commit lands there as it is made. There is no second branch to pick from, and the commits
a pick would apply are already ancestors of the tip. One commit per task cannot be produced on
the integration branch without rewriting it, and a rewrite is not a candidate:
`guard-destructive-git.sh` refuses a HEAD-moving reset while another writer is live, and
`git rebase -i` is unavailable.

## Ruling

**L1. Phase commits stay on the integration branch as made.** Nothing is picked, squashed or
rewritten there. The primary tree never changes branch.

**L2. Landing is a verification, run strictly before the completion status write, and a
recorded proof.** The predicate is in "The landing predicate". A failure refuses the status
write, changes no ref and no file, and names what it found.

**L3. The reviewable unit of a task is its attributed commit set**, not a range and not one
commit. It is recorded in the landing proof with the task's phase list, and stated in the body
of the task's completion commit, which already exists as one commit per completed task with the
subject `task {N}: complete implementation`.

**L4. One commit per task is produced at review time, on a review ref, by plumbing.** The step
that cuts a review branch builds it from the landing proofs. The integration branch is the
source and is never rewritten. That step belongs to
`stack_pr_submission_from_integration_branch` (685); the contract it receives is in "Interface
to review submission".

**L5. `milestone-ref-land.sh` is retired as a landing mechanism**, in the order stated under
"Retirement order".

In the terms of the task description this is option B at landing time with option C's squash
handed to the review step under an explicit interface. Option A is rejected.

## Why not a side ref built by plumbing (option A)

Measured in a scratch fixture (report, experiment E2), with phase commits written to a side ref
through a temporary index, `git commit-tree` and compare-and-swap `git update-ref`, `HEAD`
staying on the integration branch:

- The side ref carried the three commits and the integration branch did not move. That half
  works.
- The primary tree was dirty against `HEAD` for every path any task had "committed", for the
  whole life of the batch. `batch_admission_dirty_paths` from the live library listed both
  edited paths, so a repository that declares `integration_branch` would refuse a second
  invocation at admission for as long as the first is in flight.
- `git cherry-pick -n` of the task's side commits into the primary tree exited 128, "Your local
  changes to the following files would be overwritten". The pick R3-amended describes cannot run
  in the tree that produced the commits.
- The only landing that worked was an ordinary scoped commit of the task's paths from the
  working tree. Under option A the squash is therefore not a pick from the side ref at all. It
  is a deferred commit, and the side ref is a redundant journal beside it.

The cost is not confined to the landing. Five non-test scripts and one hook decide by
HEAD-relative dirt (`git-commit-scoped.sh`, `git-commit-phase.sh`, `git-snapshot.sh`,
`commit-source-store-path.sh`, `orchestrator-postflight.sh`, `guard-destructive-git.sh`; found
by one grep over `scripts/` and `hooks/`, not claimed complete). Each would see every task's
verified work as uncommitted. The commit-per-green-substep mandate would hold only on a ref no
ordinary tool reads. The change sits in the commit scripts, which are outside this task's
declared territory and are owned by the held two-root task (670) and the open commit-layer
chain (513, 536, 553). This is the structural objection the removal verdict records, a layer
whose correctness depends on unrelated scripts that do not know it exists, re-entered by a
different door.

The amending record already rejects "a plumbing squash inside one shared tree" because it would
put the shared `HEAD` on a side branch. Option A avoids that one reason and falls to the ones
above.

## Why not leave the squash unruled (option C alone)

Deferring the unit-of-review decision to the review step without stating what that step
receives would make it re-derive attribution, and attribution has three traps measured on this
repository's history (report, "Corpus measurements"): task numbers are reused, 108 of 700 recent
commits belong to no task, and the generated state files ride in every task's commits. The
squash is deferred; the contract is not.

## The landing predicate

Evaluated in the primary tree, under the existing `specs/.commit-lock` mutex. It reads refs and
the working tree. It does not use `modified_files` to find the work.

- **V1, branch.** `HEAD` is a symbolic ref to the integration branch named in the batch record.
  A detached `HEAD` or another branch refuses.
- **V2, attribution.** The task's commits are the non-merge commits on the integration branch
  whose subject matches `task {N}:` or `task {N} phase`, made at or after the task's `created`
  timestamp. The time bound is required, not optional: 438 task numbers in this repository have
  more than one completion commit in history, and an unbounded match attributed 22 commits to a
  task that made 9. `integration_tip_at_cut` is not the lower bound, because a resumed task has
  commits from earlier invocations. An empty set refuses.
- **V3, path set.** The union of paths those commits touched, less the state territory
  (`BATCH_ADMISSION_STATE_TERRITORY`). The generated state files ride in every task's commits
  and are not separable by path; including them refused one correct landing in fourteen.
- **V4, blob equality.** For every path in the set, the blob at the integration tip equals the
  blob at the task's end commit, its last attributed commit. A mismatch refuses and names the
  commits that touched the path after the end commit (`git log <end>..<tip> -- <path>`).
- **V5, nothing left behind.** No path in the set, and no path the dispatch reported as
  modified that lies inside the repository and outside the state territory, differs between the
  working tree and the tip. The reported paths can only add a refusal. They never establish
  that work landed.

V4 is the amending record's predicate unchanged. In one tree it is trivially true unless
another writer changed the task's paths afterwards, so V4 alone would not close defect 4. V1,
V2 and V5 are what catch the single-tree shapes of that defect: commits stranded off the
branch, no commits at all, and work on disk that no commit carried.

**Refusal replaces the "attributable to no task" rule.** On a batch branch every commit should
belong to a task, so an unattributable one is an anomaly. On the integration branch it is
normal: roadmap, archive, sync and hand commits. Refusing on their mere presence would refuse
almost every landing. The refusal is re-keyed to effect: an unattributed or foreign commit
refuses a landing exactly when it changed one of the task's paths after the task's end commit,
which is V4, and V4 names it.

**Two concurrent batches.** In one tree there is no pick and so no pick conflict. The conflict
shows as the second batch's commit changing a path in the first batch's task after that task's
end commit. V4 refuses and names the commit. Nothing was mutated, so the refs are intact by
construction. A sibling whose paths are untouched still lands (report, E1 NEG-b).

**Idempotence.** A landing proof for the task whose `end_commit` is still the task's last
attributed commit makes a re-run a no-op that passes. The short-circuit is required for
correctness, not only for cost: a dependent task that legitimately edits the same file later
would otherwise fail V4 for a task that landed correctly.

**Ordering obligation on the implementing plan.** Today the per-cycle commit of leftover
`modified_files` runs after the status write, and its failure is non-blocking ("The work is on
disk, UNCOMMITTED"). That is defect 4 in its single-tree shape and it is live. V5 is only sound
if that commit runs before the predicate. The plan must order: commit leftovers, verify, write
status, completion commit.

## The landing proof

One element appended to the batch record's `landing_proofs` array, under the commit mutex:
`task_number`, `session_id`, `landed_at`, `integration_branch`, `commits` (attributed, oldest
first), `end_commit`, `tip_at_verification`, `paths` (the V3 set), `shared_paths` (paths of the
set that a commit outside the task also touched between the task's first and end commit),
`phases` (the completed-phase list), `source_store_commits`. A resumed batch carries a new
session identity and finds the earlier record by `task_numbers` membership, as the record's
schema already provides.

## Source-store commits in a second repository

They are outside the predicate and outside any squash. The proof records each as a repository
identifier and a commit, where the dispatch reported one, and the completion commit's body
lists them. They are not verified here: `commit-source-store-path.sh` commits on whatever
branch that repository has checked out, and verifying a second repository's branch is the open
work of `source_store_commit_and_registration_review` (536). The amending record's position
stands: the unit does not extend across repositories.

## Interface to review submission

What a step that cuts review branches receives:

- **The ref it reads.** The integration branch named in the batch record. It is never rewritten
  and its history is phase commits, bookkeeping commits and other sessions' commits interleaved.
- **The range.** Not a range per task. Per task, a landing proof: an explicit commit list, an
  end commit and a path set. Per batch, `integration_tip_at_cut` to the highest
  `tip_at_verification` among its proofs, which also contains commits belonging to no member.
- **Whether it is one commit per task.** No. It is one proof per task.
- **How one commit per task is built.** Measured (report, E3): replaying a task's commits with
  `git merge-tree --write-tree --merge-base` conflicts on the generated state files in the
  simplest interleaved case. A blob overlay does not: for each task in landing order, take the
  review ref's tip tree, set each path of the proof's set to its blob at the proof's end commit,
  and write one commit with `git commit-tree`; then one trailing commit carries the remainder to
  the integration tip's tree. In the fixture this produced one commit per task and a final tree
  equal to the integration tip's, with `HEAD`, the index and the working tree untouched. Tree
  equality at the end is the check that nothing was dropped.
- **The stated limit.** A task whose proof has a non-empty `shared_paths` cannot be separated
  exactly by path: its overlay carries the other writer's lines in those files. Four of
  fourteen measured tasks had one. The review step must decide per such task between accepting
  the co-landed lines, naming them in the description, or merging the tasks into one review
  unit. It must not present such a commit as the task's work alone.
- **Tasks with no proof.** Tasks completed before this mechanism have none. Attribution by V2
  is the fallback, and the time bound is mandatory.

The review ref is a parallel history, which is defect D4 of the built-mechanism verdicts. It is
accepted here on different terms: it is built on demand for one review, is the thing merged, and
is not maintained beside the integration branch as a second landing target.

## Retirement order

The repository must never be without a pre-completion landing verification.

1. Build the predicate and its negative fixtures. Observe the negative fixtures failing.
2. Wire the predicate ahead of the completion status write. Keep the `milestone-ref-land.sh`
   calls in place while both run.
3. Remove the `milestone-ref-land.sh` landing and `--verify` calls from postflight.
4. Point `milestone-review-handoff.sh` at the integration branch and the landing proofs: it
   lists, per done task, the subject, the commit count and the end commit, and prints
   `/please push` for the integration branch. Its commit-count check against a milestone ref
   goes with the ref.
5. Existing `refs/heads/milestone/*` refs are left alone. Deleting them is the operator's.

**A hole the plan must close.** The milestone check is wired only in
`orchestrate-cycle-postflight.sh`. Completion is also written by the post-deploy reconcile path
and by `reconcile-task-status.sh`, and 24 of the 77 completion commits in the last 700 commits
came through the reconcile path. A check wired at one caller does not meet the criterion that a
completion write cannot occur without it. The one site every path shares is
`update-task-status.sh postflight <N> implement`, which already hosts the phase-count and
deploy gates. The plan either places the predicate there, widening the task's declared
territory, or wires every caller and proves the list complete.

## Assertions amended

Each is amended for the isolation-off path only. For isolation on, which is deferred, the
amending record stands as written.

| Amending record | Assertion | Now |
|---|---|---|
| R3, amended, first sentence | One squash commit per completed task lands directly on the integration branch | One landing proof per completed task; phase commits stay as made (L1 to L3). One commit per task exists on the review ref (L4) |
| R3, "Built by attribution" | The task's commits are selected on the batch branch and picked | Attribution by V2 on the integration branch; nothing is picked |
| R3, "Refusing, not skipping" | A commit attributable to no task refuses | Refusal keyed to a changed path of the task, V4 |
| R3, "Verified before the status write" | Blob equality over the task's own path set | Kept as V4, joined by V1, V2 and V5 |
| R3, "Back-merge" | Integration branch merged into the batch branch after each landing | Deferred with isolation |
| Isolation-off repositories | "What it loses. The per-task squash. Nothing else." and "the review unit there is the range of a task's commits" | It gains the verification and the proof; the unit is a commit set, not a range; the squash is recoverable at review time |
| Built-mechanism verdicts | `milestone-ref-land.sh` stays the only landing mechanism in isolation-off repositories until the successor rules | Ruled: L2 replaces it, in the order above |
| Successor tasks, 673's owned criterion | One squash commit per completed task on the integration branch | One reviewable unit per completed task, with its phase list recorded |

R3's "Idempotent" and "Serialized" bullets, the rejection of `git merge --squash`, the rejection
of full-tree equality, and R8 are not amended.

## What this does not deliver

The integration branch's own history stays one commit per phase. The operator's stated target,
side branches that merge one squashed commit per task, is delivered on the review branch and not
on the long-lived branch. The amending record already said this of isolation-off repositories.
It becomes the general case while isolation is deferred, and returns to being the exception when
isolation is reinstated.

## Implementation clarifications

Stated by the implementing plan,
`specs/673_per_task_attribution_squash_landing/plans/01_landing-verification-gate.md`. None
changes a ruling above.

- **Script name.** The predicate and proof writer is `task-landing-verify.sh`, with the suite
  `test-task-landing-verify.sh`. Nothing is squashed on the integration branch, so a name
  containing "squash" would describe the mechanism this record rejects.
- **Exit codes.** The predicate exits `0` on a pass, the idempotent no-op included, `2` on a
  usage or environment error, `10` for V1, `11` for V2, `12` for V4 and `13` for V5.
  `update-task-status.sh` exits `7`, "landing verification refused", having written no state and
  stamped no plan file.
- **End commit.** "Its last attributed commit" in V4 and in "Idempotence" means the task's last
  attributed commit that touches at least one path outside `BATCH_ADMISSION_STATE_TERRITORY`.
  The completion commit carries state files only and is attributed to the task; read literally
  it would replace the end commit after every completion and no re-run could be a no-op.
- **The script file stays.** `milestone-ref-land.sh` is unwired from postflight and stays on
  disk as a snapshot utility that no lifecycle script calls. L5 retires it as a landing
  mechanism and does not order the file deleted; deleting or reusing it is left to
  `stack_pr_submission_from_integration_branch` (685) and
  `branch_topology_documentation_parity` (675).
