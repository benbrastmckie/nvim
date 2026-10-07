# Implementation Summary: Task #361

- **Task**: 361 - Reclassify bare `git stash` as destructive on a shared working tree
- **Status**: [COMPLETED]
- **Started**: 2026-10-07T17:52:39Z
- **Completed**: 2026-10-07T19:29:17Z
- **Effort**: ~1.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_reclassify-stash-destructive.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Bare, whole-tree `git stash` reverted the working tree while being listed as "Not blocked" in
`rules/git-workflow.md`, under the wrong premise that a stash never discards changes -- true for
a solo tree, false under concurrent writers where a later `git stash pop` can be refused by a
sibling's intervening write, stranding the changes inside a stash entry. This task corrected the
rule's premise first, then implemented a `stash_revert` guard detector in
`hooks/guard-destructive-git.sh`, wired it into the existing snapshot-marker and grant-consume
escape hatches (both wiring points: validation registry and the `/please` mint grammar), landed
a fixture demonstrated red before the change and green after, and redeployed with a fully green
gate set.

## What Changed

- `agent-system/extensions/core/rules/git-workflow.md` -- moved bare `git stash`/`git stash push`
  from "Not blocked" into "Forbidden on a dirty tree" with a concurrent-writer hazard rationale;
  recorded the Item 7 (pathspec-scoped stash stays permitted) and Item 8 (`pop`/`apply` stay
  permitted) verdicts tersely in the "Not blocked" list.
- `agent-system/extensions/core/context/standards/git-workflow-narrative.md` -- new section
  carrying the full concurrent-writer mechanism, the measured two-agent incident, the Item 7/8
  extended reasoning, and the known residual risk in `git-snapshot.sh`'s own internal stash use.
- `agent-system/extensions/core/index-entries.json` -- regenerated line-count for the narrative
  entry.
- `agent-system/extensions/core/hooks/guard-destructive-git.sh` -- new `stash_revert` per-segment
  detector (bare/implicit-push/`-u`/`--include-untracked` block; pathspec-scoped `push --
  <path>` and read-only/recovery forms exempt); class-conditional refusal naming
  `git show HEAD:<path>`, `git diff HEAD -- <path>`, and a scratchpad-copy alternative; updated
  header and class-enumeration comments.
- `agent-system/extensions/core/scripts/lib/push-grant-lib.sh` -- `stash_revert` appended to
  `PG_ACTION_CLASSES`; header comment corrected to distinguish validation-registration from
  mint-grammar registration, with a cross-reference to `please-grant.sh`.
- `agent-system/extensions/core/hooks/please-grant.sh` -- new `stash_revert` mint arm (`git
  stash`, `stash`, `git stash push`, `stash push`), extended accepted-forms error text, and a
  reciprocal cross-reference comment pointing at `PG_ACTION_CLASSES`.
- `agent-system/extensions/core/scripts/tests/test-guard-destructive-git.sh` -- flipped the bare
  `git stash` assertion from allowed to blocked; added 6 new blocked cases (push,
  implicit-push forms, `-u`, `--include-untracked`, empty `--` separator) and 6 new allowed
  cases (pathspec-scoped, `apply`, `list`, `show`, `--help`); added a `stash_revert`
  grant-check pair mirroring the existing `reset_hard` pair.

## Decisions

- Class name `stash_revert` (distinct from the existing `stash_drop`, since the two hazards --
  discarding an existing stash vs. reverting the tree -- are different).
- Item 7 verdict: pathspec-scoped `git stash push -- <pathspec>` stays permitted (bounded blast
  radius, same shape as `git restore --staged <path>`).
- Item 8 verdict: `git stash pop`/`git stash apply` stay permitted (the data-loss moment is the
  push, not the recovery; a conflicting pop/apply is refused by git, never a silent discard).
- `git-snapshot.sh`'s own internal `git stash push -u` usage is a known, accepted residual risk,
  deliberately not fixed here (subprocess-invisible to the hook, same precedent as
  `git-commit-scoped.sh`).
- Resolved an orchestrator eager-context budget (Gate 20) collision -- caused by the Phase 1
  rule-text addition to the eager-loaded `rules/git-workflow.md` -- by compression rather than
  moving the fixed baseline, following this repo's own established precedent.

## Plan Deviations

- **Phase 1** (post-hoc, during Phase 4): the originally-committed rule text was re-compressed
  after Phase 4's full `verify-deploy.sh` run surfaced the eager-context budget collision
  described above. No semantic content was lost; extended reasoning was already relocated to the
  (non-eager) narrative file in Phase 2.
- **Phase 6 Scope Hypothesis**: the plan's "six files modified" figure was seven in actuality
  (`hooks/please-grant.sh`, Phase 5's own explicit edit target, was undercounted). Corrected and
  recorded in-line rather than silently absorbed; not scope creep.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on all four edited shell files; `shellcheck`
  unavailable in this environment, recorded as a non-fatal environment gap)
- Tests: Passed -- `test-guard-destructive-git.sh` 91/91 (89 Phase 3/4 cases + 2 Phase 5
  grant-pair cases), from both the source-store and deployed paths
- Files verified: Yes -- all 6 directly-deployed files confirmed byte-identical
  (source vs. `.claude/`) post-redeploy via `diff` + `md5sum`
- Full gate set: `verify-deploy.sh` 33/34 PASS pre-redeploy-triage-adjusted to effectively full
  green post-redeploy (sole remaining Gate 8 finding is 4 pre-existing, unrelated `run-all.sh`
  suite failures already in `known-failures.txt`, 0 NEW)
- Fixture red/green: Phase 3 baseline 77/0 -> red 82/7 (exact 7 new/flipped cases failing);
  Phase 4 green 89/0 (same 7 cases now passing, no regression)

## Impacts

- Every agent in this and sibling repositories is now blocked from running a bare, whole-tree
  `git stash` on a dirty tree, closing the data-loss mode observed in the motivating incident
  (two concurrent agents' stashes, one stranded by a sibling's intervening write).
- Agents retain a safe stash path (`git stash push -- <pathspec>`) and the existing
  snapshot-marker/`/please`-grant escape hatches, now extended to cover this new class.
- The refusal message actively teaches the three non-destructive alternatives, so the new block
  does not convert into an agent stall.

## Follow-ups

- The post-incident verification checklist task (serialized behind this one) can now cross-
  reference this finished refusal text.
- `git-snapshot.sh`'s own internal `git stash push -u` mechanism carries a narrower, accepted
  residual risk, recorded in the narrative but not fixed here -- flagged for a future task if it
  recurs in practice.

## References

- Plan: `specs/361_reclassify_bare_git_stash_as_destructive/plans/01_reclassify-stash-destructive.md`
- Research report: `specs/361_reclassify_bare_git_stash_as_destructive/reports/01_reclassify-stash-destructive.md`
- Progress files: `specs/361_reclassify_bare_git_stash_as_destructive/progress/phase-{1..6}-progress.json`
- Evidence logs: `specs/361_reclassify_bare_git_stash_as_destructive/progress/*.log`
