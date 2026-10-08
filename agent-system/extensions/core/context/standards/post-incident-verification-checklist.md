# Post-Incident Verification Checklist

Run this immediately after any destructive or tree-wide git action on a shared working tree
(a bare stash, a reset, a forced checkout/switch, a clean). Verification that stops at sibling
commits and your own edits misses exactly the one category with no other recovery path.

## The clean-status trap

A reverted file matches HEAD. It therefore reads as clean to `git status`, to `git diff`, and to
every naive check — absence of a modification is indistinguishable from absence of a problem
unless you compare against the stash entry or the reflog. **A clean `git status` is not evidence
of no loss.**

## The four mandatory checks, in this order

### 1. Pre-session uncommitted tracked modifications (check this first)

```bash
git stash list
git diff --stat HEAD stash@{N}        # per outstanding entry
git stash show -p -u stash@{N}        # -u is required: a bare 'show -p' omits untracked content
```

If the entry you need is no longer in `git stash list` (dropped or popped-and-failed):

```bash
git fsck --unreachable --no-reflog | grep commit
git show --stat <sha>                 # on each candidate
```

### 2. Untracked files

```bash
git status --porcelain --ignored=no
```

Cross-check against the stash's untracked parent (`stash@{N}^3`) when the entry was created
with `-u`.

### 3. Sibling commits

```bash
git log --oneline <pre-incident-sha>..HEAD
```

Compare against each sibling's reported work.

### 4. Your own edits

Confirm your declared `file_scope` is fully present in the working tree.

## Why this order, not another

Ordered by **recoverability**, not convenience. A sibling commit survives in history regardless
of what you do next. Your own edit can be redone. Pre-session uncommitted work exists in exactly
one place — the stash entry or the reflog — and once reverted it reads as clean, so it must be
checked first, while there is still time to extract it before that entry is dropped or
garbage-collected. The same four checks in a different order would reproduce the original
failure: disclosure can be prompt and complete, and the loss still goes undetected, because the
defect is in what gets checked, not in whether it is reported.

## Placement

This is a standalone page, not a section of an existing standards document:
`git-safety.md` is a before/during risky-operation playbook; `git-staging-scope.md` is a
pre-commit staging contract; `git-workflow-narrative.md` is a lazily-loaded reactive elaboration,
read only once an agent is already following the core rules; `context/contracts/recovery.md` is
a build-error fix-forward ladder. A checklist that must be findable under incident conditions —
after the fact, often by a different agent than the one who acted — needs its own named page
rather than a buried subsection.

See `context/standards/git-workflow-narrative.md`'s incident section for full mechanism detail.
