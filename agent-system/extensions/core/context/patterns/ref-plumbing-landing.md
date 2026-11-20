# Ref-Plumbing Landing Pattern

**Purpose**: Define, once, the `git commit-tree` + `git update-ref` idiom this system uses to
land a completed task's work onto a review-ready ref without ever touching the shared working
tree, the index, or `HEAD` — and the prohibition on reaching for `checkout` to do the same job
in a shared tree.
**Audience**: `agent-system/extensions/core/scripts/milestone-ref-land.sh` and any future script
that needs to advance a ref representing a batch of completed work.
**Related**: `specs/decisions/branch-topology-and-landing-strategy.md` (the ruling this
implements), `specs/decisions/worktree-isolation-removal-verdict.md` and
`worktree-isolation-removal-reaffirmation.md` (the binding evidence against reinstating tree
isolation), `../standards/git-workflow-narrative.md`'s Branch Strategy section.

---

## The Idiom

```bash
tree="$(git rev-parse HEAD^'{tree}')"
# parent = the target ref's current tip, or the integration branch's tip for the first landing
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
  `<old>` asserts the ref must not already exist (for a ref's first landing). This is the only
  sanctioned way to move the target ref — never `-f`, never a plain two-argument update.

## The Concurrency-Safety Property

Every dispatch in this repository runs in the one shared working tree
(`specs/decisions/worktree-isolation-removal-verdict.md`). A landing mechanism built from
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

A landing script that reads a target ref's tip, computes a new commit on top of it, and then
updates the ref with a plain (non-conditional) `git update-ref` has a race: two dispatches
landing onto the same ref at nearly the same time can both read the same tip, both compute a
commit, and the second `update-ref` silently drops the first's work (whichever lands last wins,
with no error). The three-argument compare-and-swap form closes this: the second writer's
`update-ref` fails because the ref no longer points at the `<old>` value it read, so the
failure is loud and retryable rather than silent data loss.

A landing script MUST therefore:
- Read the target ref's current tip immediately before computing the new commit, not earlier.
- Use the three-argument `git update-ref <ref> <new> <old>` form.
- On a compare-and-swap failure, re-read the tip, recompute, and retry — never force the update.
- Serialize the retry loop under the existing commit mutex (`task-lock.sh commit-acquire`/
  `commit-release`), never a new lock, fail-open with a named warning on acquisition failure
  (matching `git-commit-scoped.sh`'s own commit-mutex convention).

## The Prohibition

Reaching for `git checkout`/`git switch` to land work onto a ref — "check out the target branch,
merge or cherry-pick, check back out" — is never sanctioned in this system, for any landing
mechanism, because it repoints the one shared tree's `HEAD` for the duration of the operation.
Any script implementing a ref-plumbing landing MUST contain no `git checkout`, `git switch`,
`git merge`, `git push`, or `git reset` invocation; a static grep for these strings (outside
comments) over the script file is the cheapest test for this property, and the test suite for
every ref-plumbing landing script in this codebase asserts it.
