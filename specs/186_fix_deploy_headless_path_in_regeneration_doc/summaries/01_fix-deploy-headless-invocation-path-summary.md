# Implementation Summary: Task #186

- **Task**: 186 - Fix the wrong deploy-headless.sh invocation path documented in regeneration-is-manual-only.md
- **Status**: [COMPLETED]
- **Started**: 2026-09-08T22:52:00Z
- **Completed**: 2026-09-09T00:10:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_fix-deploy-headless-invocation-path.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md

## Overview

Corrected the wrong `bash scripts/deploy-headless.sh` invocation form documented in
`regeneration-is-manual-only.md` (the file the deploy gate's own remedy text sends blocked
operators to) and repeated in seven operator-facing runtime remedy strings and three comments
across five core scripts -- 12 defect sites across 6 files, all under
`agent-system/extensions/core/`. Added a mechanical regression guard to `check-extension-docs.sh`
so the defect class cannot silently reappear, deployed the corrected source store, and confirmed
the fix landed clean with zero regressions against a green 34-check gate baseline.

## What Changed

- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` -- corrected
  both code-fence invocation lines to `bash .claude/scripts/deploy-headless.sh`; added a
  "Two-root convention" paragraph disambiguating invocation vs. reference forms, documenting the
  exit-127/stderr-only failure mode, and noting the legitimate source-store-relative CI-bootstrap
  exception.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` -- corrected four operator-facing
  `advisory()` remedy strings (lines 316, 331, 446, 453); added
  `check_deploy_headless_invocation_regression()`, a project-wide `fail()`-severity check that
  scans `agent-system/` for the bare `bash scripts/deploy-headless.sh` form and is wired into the
  project-wide checks sequence.
- `agent-system/extensions/core/scripts/task-lock.sh` -- corrected one runtime `echo` remedy and
  one comment (lines 221, 214).
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` -- corrected one runtime
  `echo` remedy and one comment (lines 353, 349).
- `agent-system/extensions/core/scripts/deploy-root-guard.sh` -- corrected one runtime `echo`
  remedy (line 27).
- `agent-system/extensions/core/scripts/system-defect-record.sh` -- corrected one comment
  (line 52).
- Deployed the corrected source store to the (gitignored) `.claude/` tree via
  `bash .claude/scripts/deploy-headless.sh` -- `RESULT=landed_verify_clean`, exit 0.

## Decisions

- Used the `bash `-prefixed literal `bash scripts/deploy-headless.sh` as the sole discriminator
  between defect (invocation) and correct (reference/identifier) sites, established during
  planning and re-confirmed in Phase 1: 12 hits matched exactly the planned Site Inventory, with
  zero divergence, out of 28 total `scripts/deploy-headless.sh` occurrences in the source store.
- Judged `check-extension-docs.sh:421`'s "headlessly via scripts/deploy-headless.sh" as
  Reference class (no `bash ` prefix, names the mechanism in parallel with "interactively via
  `<leader>al`" in the same sentence rather than instructing a reader to run it) and left it
  unchanged, per the plan's explicit judged-call instruction.
- Chose `fail()` over `advisory()` severity for the new regression guard: it is a deterministic
  string match on version-controlled files, needs no regeneration to satisfy, and cannot
  spuriously fire for a concurrent sibling session -- unlike the existing core-deploy-drift
  advisories in the same file.
- The regression guard's own explanatory comment initially spelled the defect string literally
  and became a self-inflicted false positive (the guard's own grep matched its own prose);
  reworded every prose occurrence to the escaped-dot form matching the grep pattern's own literal
  characters, which does not self-match.

## Plan Deviations

- **Phase 5, "run the full gate suite"**: the orchestrating session directed skipping a second
  full (non-`--skip-slow`) `verify-deploy.sh` sweep after the deploy, since Phase 1 already
  captured a full 34-check, 0-failure, exit-0 baseline on a stable tree, and the deploy's own
  inline `verify-deploy.sh --skip-slow` run was also 0 failures/exit 0 -- a second ~8-10 minute
  full sweep would have added no new information. Both runs, plus the orchestrator's independent
  cross-check of the zero-hits census in both `agent-system/` and `.claude/`, jointly satisfy the
  phase's acceptance bar (0 failures, no new failures vs. baseline).
- Phase 1's `git-snapshot.sh 186` call (run per the plan's own last task) reverted and stashed a
  set of pre-existing, task-unrelated uncommitted changes that were present in the working tree
  before this dispatch began. These were popped back from the stash immediately after with no
  conflicts and are present in the tree again, untouched by this task's edits. See the phase-1
  progress file's `notes` field for the full file list. Not a deviation from the plan's own
  tasks, but flagged here since it affected files outside this task's scope.

## Verification

- Build: N/A (documentation/shell-script text corrections)
- Tests: `bash -n` passed on all five modified shell scripts; the new regression guard verified
  to fire on a deliberately reintroduced occurrence (non-zero exit, useful message) and return
  clean after revert, with zero false positives on the four named reference-class files
- Files verified: Yes -- final census (`grep -rn 'bash scripts/deploy-headless\.sh'`) returns zero
  hits in both `agent-system/` and the deployed `.claude/` tree

## Impacts

- The canonical regeneration doc's two code fences are now runnable verbatim from a consuming
  repo root, and the seven corrected runtime remedy strings printed to a blocked operator now
  name a resolvable path -- closing the exact failure mode observed live in this session's own
  earlier dispatch (exit 127, no stdout, read as a silent no-op).
- The new `check_deploy_headless_invocation_regression()` check makes this specific defect class
  mechanically unable to reappear undetected in `agent-system/`.

## Follow-ups

- None.

## References

- `specs/186_fix_deploy_headless_path_in_regeneration_doc/plans/01_fix-deploy-headless-invocation-path.md`
- `specs/186_fix_deploy_headless_path_in_regeneration_doc/progress/phase-{1..5}-progress.json`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
