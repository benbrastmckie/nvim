# Implementation Summary: Fix scoped commit dropping staged deletions

- **Task**: Fix scoped commit dropping staged deletions
- **Status**: [COMPLETED]
- **Started**: 2026-09-18T00:00:00Z
- **Completed**: 2026-09-18T01:00:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_scoped-commit-staged-deletions.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`git-commit-scoped.sh`'s V2 safety gate classified every positive pathspec as either "matched"
or "unmatched", so a staged deletion (`git rm`, or the delete half of a `git mv`) — absent from
both the working tree and the index — was silently dropped and never reached the commit, even
though the script exited 0 and reported success. The fix replaces the two-way classification
with a three-way one (matched / already-staged-deletion / genuinely-unmatched) and decouples the
`git add` pathspec set from the `git commit --` pathspec set, since an already-staged deletion
must be committed but must never be handed to `git add` (which aborts the entire all-or-nothing
add call on such a path). Work was red-first: three regression tests (T8/T9/T10) were added and
confirmed failing against the unpatched script before the fix landed.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-git-commit-scoped.sh` — added T8 (deletion-only
  scoped commit), T9 (deletion mixed with a modification in the same path set — the case that
  catches a wrongly-scoped `git add` array), and T10 (in-scope rename, both halves in scope).
  Also fixed two pre-existing shellcheck SC2329 false positives (`info()`, `cleanup()`) with
  disable directives so the file is fully shellcheck-clean.
- `agent-system/extensions/core/scripts/git-commit-scoped.sh` — V2 gate's classification loop now
  builds two arrays: `filtered_pathspecs` (used for `git commit --`) and `add_pathspecs` (used for
  `git add`). A path absent from disk and the index but present in `HEAD` (an already-staged
  deletion, guarded by `git rev-parse --verify -q HEAD` then `git cat-file -e "HEAD:$p"`) is
  added to `filtered_pathspecs` only. The `git add` call now uses `add_pathspecs` and is skipped
  entirely when it carries no positive entries (a deletion-only commit). The `git commit --`
  invocations and the V3 post-filter degenerate-list gate are unchanged, both still operating on
  the full `filtered_pathspecs`/`pathspecs` set. The header's V2 documentation bullet was rewritten
  to describe the three outcomes, and a new sentence records the out-of-scope-deletion ruling
  (silently left out of the commit, uniformly with every other out-of-scope change type, per
  `context/standards/git-staging-scope.md`'s "under-stage, never over-stage" direction — no
  refuse logic added).
- Deployed `.claude/` tree refreshed via `deploy-headless.sh` (default resync mode); source-store
  and deployed copies of `git-commit-scoped.sh` are byte-identical, and `.claude/` remains
  gitignored/untracked so the refresh contributed nothing to any commit.

## Decisions

- The out-of-scope-deletion question (should a deletion outside the declared path scope be
  silently ignored or refused?) was resolved during planning/research against
  `context/standards/git-staging-scope.md`'s existing "under-stage, never over-stage" fail-safe
  direction: preserve current silent-ignore behavior uniformly across all out-of-scope change
  types; no refuse logic was added. This is a documented decision, not a `user_decision` item.
- `git cat-file -e "HEAD:$p"` (guarded by `git rev-parse --verify -q HEAD`) was used as the
  sufficient signal for "already-staged deletion", per the research report's verified fix design;
  `git diff --cached` was confirmed not independently needed.
- Two pre-existing shellcheck SC2329 false positives in the test file were fixed incidentally
  (disable directives + rationale comments) to meet the phase's own "shellcheck clean"
  verification bar; the main script's three pre-existing SC1091/SC2329 findings were left
  untouched since they are common throughout this codebase's sanctioned scripts (e.g.
  `task-lock.sh` carries the same class of findings) and fixing them was outside this phase's
  Scope Hypothesis — verified instead by diffing shellcheck output before/after to confirm zero
  new findings were introduced.

## Plan Deviations

- Phase 4's conditional "if `deploy-headless.sh` cannot run in this environment, mark the phase
  `[BLOCKED]`" branch was not exercised: `deploy-headless.sh` ran successfully
  (`RESULT=landed_verify_clean`), so this branch is annotated as skipped/not-applicable rather
  than executed.

## Verification

- Build: N/A (shell scripts)
- Tests: Passed — `test-git-commit-scoped.sh` reports 10 passed, 0 failed (T1-T7 unchanged
  regression guards plus T8/T9/T10, all green)
- Files verified: Yes — `diff` between source-store and deployed `git-commit-scoped.sh` is empty

## Impacts

- Every caller of `git-commit-scoped.sh` (the sole sanctioned scoped-commit implementation used
  throughout the dispatch pipeline) now correctly commits a staged deletion or rename whose paths
  fall within the declared pathspec scope, closing a defect that previously left deletions
  staged-but-uncommitted after an apparently successful commit.
- No change to callers' own invocation contracts — the fix is entirely internal to the script's
  V2 gate and `git add` call.

## Follow-ups

- Consumer-repo deploy propagation (getting this fix into other repositories that vendor
  `git-commit-scoped.sh`) is a standing gap filed separately in this topic and is out of scope
  here.

## References

- Plan: `specs/226_fix_scoped_commit_dropping_staged_deletions/plans/01_scoped-commit-staged-deletions.md`
- Research: `specs/226_fix_scoped_commit_dropping_staged_deletions/reports/01_scoped-commit-staged-deletions.md`
- Progress files: `specs/226_fix_scoped_commit_dropping_staged_deletions/progress/phase-{1,2,3,4}-progress.json`
