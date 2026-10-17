# Shared-Worktree History-Read Discipline

Parallel dispatches share one working tree by design (per-agent worktree isolation is a settled
non-goal, not an open question — see `specs/decisions/worktree-isolation-removal-reaffirmation.md`).
A tree-wide or path-reverting git operation therefore reverts work a sibling dispatch or the user
has not committed yet, with no reliable per-session recovery. When the actual need is to inspect
historical file state, reach for a read-only technique instead.

## Read history

```bash
git show HEAD:path/to/file      # file content as of HEAD
git show <ref>:path/to/file     # file content as of any other commit/ref
```

## Read differences

```bash
git diff HEAD -- path/to/file
```

## Mutable copy

If an experiment genuinely needs a writable copy of historical content, extract it to the
session scratchpad directory (the path the environment block names) — never materialize it back
into the shared tree.

## Never, on a shared tree

- `git stash` (bare or whole-tree) — reverts every uncommitted path to HEAD, not just the one
  under inspection, out from under concurrent writers.
- `git checkout -- <path>` — discards the path's uncommitted content in place, with no entry to
  recover it from.
- `git restore <path>` (without `--staged`) — the same discard, under `restore`'s newer name.

Each of these reverts the tree out from under concurrent writers, who share this one working
tree by design.

## Detached worktree — READ-ONLY INSPECTION TECHNIQUE, not an isolation strategy

A detached worktree (`git worktree add --detach <path> <ref>`) may be used to *run* a command
against historical state rather than merely read a file's text — for example, to execute a test
suite as it existed at an older commit. This is a READ-ONLY INSPECTION TECHNIQUE: it is created
and torn down within one dispatch, writes nothing to the shared tree, and is not a substitute for
or a reopening of the settled per-dispatch worktree-isolation question above. It differs from
that settled question in both duration (seconds, inside one dispatch) and effect (zero writes to
the shared tree), and nothing here proposes, defers, or re-argues it.

## Placement

This is a standalone page rather than a section of an existing standards document. `git-safety.md`
is a before/during risky-operation safety-commit/rollback playbook with no natural home for
point-of-use read-only guidance, and no implementation agent definition references it at all, so
amending it would not by itself improve reachability. `git-workflow-narrative.md` already carries
the full incident narrative but is a lazily-loaded reactive elaboration, read only once an agent
is already following the core rules — the opposite of findable at the moment a git command is
chosen. Both were surveyed and rejected for the same reason `post-incident-verification-checklist.md`
rejected them for closely analogous content: a page that must be findable at the point of use
needs its own named page, not a buried subsection.

See `context/standards/git-workflow-narrative.md`'s incident section for full mechanism detail.
