# Ref-Plumbing Landing Pattern

**Purpose**: Define, once, the `git commit-tree` + `git update-ref` idiom for building or
advancing a ref from objects already in the database without ever touching the shared working
tree, the index, or `HEAD` — and the prohibition on reaching for `checkout` to do the same job
in a shared tree. It also states where the idiom is used and where it is not: see "The Landing
Mechanism".
**Audience**: any script that needs to build or advance a ref representing completed work, and
`agent-system/extensions/core/scripts/milestone-ref-land.sh`, the worked implementation.
**Related**: `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md` (how
a task's work lands, and its "Interface to review submission" section for where a review ref is
built), `specs/decisions/branch-topology-and-landing-strategy.md` (the ruling the idiom was
defined under), `specs/decisions/worktree-isolation-removal-verdict.md` and
`worktree-isolation-removal-reaffirmation.md` (the binding evidence against reinstating tree
isolation), `../standards/git-workflow-narrative.md`'s Branch Strategy section.

---

## The Landing Mechanism

The idiom below does not land a task's work. A task's phase commits are made on the integration
branch and stay there as made; nothing is picked, squashed or rewritten on that branch. Landing
is a verification plus a record: `scripts/task-landing-verify.sh` runs inside
`scripts/update-task-status.sh` ahead of the completion status write, refuses the write (exit 7)
when the task's work is not verifiably on the integration branch or when work remains in the
working tree that no commit carries, and on a pass appends the task's landing proof to the batch
record (`../standards/orchestrator-runtime-files.md`, "The batch record").

The idiom is used where a ref has to be built without a checkout. The case the ruling record
names is the review ref: one commit per task, built at review time from the landing proofs by
overlaying each proof's path set at its end commit, with the integration branch as the source
and never rewritten. `scripts/milestone-ref-land.sh` implements the idiom as a snapshot utility;
no lifecycle script calls it.

---

## The Idiom

```bash
tree="$(git rev-parse HEAD^'{tree}')"
# parent = the target ref's current tip, or the integration branch's tip for the ref's first commit
new_commit="$(git commit-tree "$tree" -p "$parent" <<<"$message")"
# Compare-and-swap: fails if the ref moved since $old_tip was read
git update-ref "$target_ref" "$new_commit" "$old_tip"
```

- `git rev-parse HEAD^'{tree}'` reads the tree object HEAD already points at — no new tree is
  computed from the working tree or the index.
- `git commit-tree` writes a new, immutable commit object straight into the object database. It
  reads nothing and writes nothing outside the object database.
- `git update-ref <ref> <new> <old>` is the three-argument compare-and-swap form: it moves
  `<ref>` to `<new>` only if it currently points at `<old>`, and fails otherwise. An empty
  `<old>` asserts the ref must not already exist (for a ref's first commit). This is the only
  sanctioned way to move the target ref — never `-f`, never a plain two-argument update.

## The Concurrency-Safety Property

Every dispatch in this repository runs in the one shared working tree
(`specs/decisions/worktree-isolation-removal-verdict.md`). A mechanism built from
`git checkout`/`git switch`/`git merge` would repoint that shared tree's `HEAD` out from under
any concurrent sibling dispatch — exactly the hazard class the worktree-isolation removal
verdict and its reaffirmation record as the controlling reason tree isolation was removed rather
than narrowed.

`git commit-tree` and `git update-ref` touch **neither the working tree, nor the index, nor
`HEAD`**. A script built entirely from these two primitives is therefore structurally
unaffected by — and has no effect on — anything a concurrent sibling dispatch is doing in that
same shared tree. This is a stronger guarantee than "usually safe": there is no shared mutable
state for a sibling's commit, checkout, or build to collide with, because nothing this idiom
does is visible outside the object database and the one ref it moves.

## The Compare-And-Swap Obligation

A script that reads a target ref's tip, computes a new commit on top of it, and then
updates the ref with a plain (non-conditional) `git update-ref` has a race: two dispatches
writing the same ref at nearly the same time can both read the same tip, both compute a
commit, and the second `update-ref` silently drops the first's work (whichever lands last wins,
with no error). The three-argument compare-and-swap form closes this: the second writer's
`update-ref` fails because the ref no longer points at the `<old>` value it read, so the
failure is loud and retryable rather than silent data loss.

A script advancing a ref this way MUST therefore:
- Read the target ref's current tip immediately before computing the new commit, not earlier.
- Use the three-argument `git update-ref <ref> <new> <old>` form.
- On a compare-and-swap failure, re-read the tip, recompute, and retry — never force the update.
- Serialize the retry loop under the existing commit mutex (`task-lock.sh commit-acquire`/
  `commit-release`), never a new lock, fail-open with a named warning on acquisition failure
  (matching `git-commit-scoped.sh`'s own commit-mutex convention).

## The Prohibition

Reaching for `git checkout`/`git switch` to put work onto a ref — "check out the target branch,
merge or cherry-pick, check back out" — is never sanctioned in this system, for any mechanism,
because it repoints the one shared tree's `HEAD` for the duration of the operation.
Any script implementing this idiom MUST contain no `git checkout`, `git switch`,
`git merge`, `git push`, or `git reset` invocation; a static grep for these strings (outside
comments) over the script file is the cheapest test for this property, and the test suite for
every script built on the idiom in this codebase asserts it.
