# Concurrent-Dispatch Isolation Posture — Implementation Summary

## Outcome

All 11 phases closed. Phase 11 is `[COMPLETED WITH EXCLUSIONS]`: every gate ran and passed, with
consumer-repo confirmation deferred (see Excluded below).

## The Decision

A split verdict, not a single posture:

- **Per-dispatch git-worktree isolation** for `lean4`/`cslib` implement dispatches, where build
  artifacts and long edit sessions make shared-tree contention both likely and expensive.
- **Shared tree plus a contended-path commit refusal** for `general`/`meta`/`markdown` dispatches,
  where isolation would cost more than the contention it prevents.
- **Hunk-level staging rejected outright.** No per-task hunk or line attribution mechanism exists
  anywhere in the codebase, and building one is not cheaper than worktree isolation once honestly
  costed.

## What Shipped

- `dispatch-worktree.sh` — the full lifecycle: `provision` (free-space floor of 5 GiB, a 3-worktree
  cap, hardlink-cloned `.claude/` and `.lake`, and an assertion that `PROJECT_ROOT` resolves inside
  the worktree), `path`, `release` (strips untracked scratch first so a clean release is never
  falsely refused as dirty), `prune` (age-based, unconditionally sparing the calling session), and
  `land` (merge-back with a `specs/**` refusal, dirty-overlap refusal, and conflict abort-and-preserve).
- **Dispatch-site wiring** in `orchestrate-cycle-plan.sh` (mechanical selection predicate, provision
  call that defers rather than silently falling through to a shared tree on failure, and new
  `isolation`/`worktree_path` row fields) and `orchestrate-build-dispatch.sh` (a `--worktree` flag
  rendering an `## Isolated Working Tree` section).
- **Postflight wiring** that re-derives isolation status via `dispatch-worktree.sh path` rather than
  threading new flags through the orchestrate skill — chosen specifically to keep that file out of
  the footprint.
- **Contended-path manifest producer** and the matching refusal in `git-commit-scoped.sh`.
- **Acceptance fixture** reproducing the observed batch shape: two concurrent lean4 implement
  dispatches, one shared markdown file, one unguarded build.
- **Documentation**: the decision record with the full option/failure-mode scoring table, the build
  guard's opt-in bypass hazard, and the staging-insufficiency qualification.

## Measurements That Shaped the Design

- The incident repository's `.lake` measures 16 GiB against 27 GiB free, so a naive
  independent-`.lake`-per-worktree design was near-prohibitive. A hardlink clone reproduces the tree
  in 0.83s with zero measured disk growth, which is what made worktree isolation viable at all.
- Lake writes build outputs via atomic temp+rename, confirmed by an inode-divergence test rather
  than assumed — the precondition the hardlink approach depends on.
- Worktrees share one object database (`worktree add` at 0.089s, no object copy), so merge-back is
  an ordinary `git merge`. A genuine same-line collision becomes an explicit conflict instead of the
  silent bleed observed in the original incidents.

## Deliberate Divergences

- **Script-provisioned worktrees over the harness's own isolation parameter.** The research phase
  recommended the built-in parameter; implementation diverged because a fresh worktree has no
  deployed `.claude/` (it is gitignored), so it must be hardlink-cloned in — and because `specs/` is
  tracked, a worktree carries a HEAD-stale state file, which is why `land` refuses any branch
  touching `specs/**`.
- **A claimed symlink failure mode did not reproduce.** The plan asserted that a symlinked `.claude/`
  would defeat `PROJECT_ROOT` resolution; under this system's shell both symlink and hardlink
  resolved inside the worktree. Hardlink-over-symlink still stands, but for a different and verified
  reason: ephemeral runtime-state bleed through a shared physical directory.

## Verification

580 assertions across the seven task suites, zero failures. `verify-deploy.sh` 33/33.
`check-task-references.sh` clean. Full `run-all.sh` at 96/104 with every failure individually
attributed to a pre-batch baseline failure, a load-sensitive timing suite that passes standalone, or
another session's uncommitted work — none to this task. The failing-suite set is byte-identical
before and after this work.

`shellcheck` could not run (dangling interpreter path in this environment); `bash -n` is clean on all
six touched files. Recorded rather than skipped silently.

## Excluded

- **Consumer-repo confirmation.** The consumer checkout has not been redeployed since these changes.
  Regeneration is manual-only, and that repository had an active session, so deploying into it was
  not attempted. Re-run the deploy there when idle and confirm `dispatch-worktree.sh --help` responds
  and `lean4.md` carries the opt-in note.
- **PATH-shim build wrapper.** The build mutex remains opt-in; making it unbypassable via a `lake`
  shim was scoped out as a follow-up decision rather than built here.

## Note on Authorship

Phases 1-10 were implemented by dispatched agents across three dispatches. The dispatched agent for
the final dispatch terminated on an account usage limit partway through Phase 11; the orchestrator
completed that phase, which is verification-only, and recorded the results above.
