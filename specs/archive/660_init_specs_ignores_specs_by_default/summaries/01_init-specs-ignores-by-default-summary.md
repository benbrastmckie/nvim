# Implementation Summary: Task #660

- **Task**: 660 - Init specs ignores specs by default
- **Status**: [COMPLETED]
- **Started**: 2026-11-20T03:30:00Z
- **Completed**: 2026-11-20T06:45:00Z
- **Effort**: ~3.5 hours
- **Dependencies**: None blocking (task 658 already completed; task 338 shares territory,
  confirmed still `not_started` at close, declared not blocking)
- **Artifacts**: plans/01_init-specs-ignores-by-default.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

A newly initialized repository now gets its whole `specs/` tree gitignored from the first
`init-specs.sh` run, via a managed block written to the consumer's own repo-root `.gitignore` --
the only placement that can make `git check-ignore -q -- specs` succeed. A repository that
already tracks `specs/` (this repository is the reference case) is never written to at the root
by any init, deploy, redeploy, or loader run, proven against the git index rather than inferred
from any script's exit code. `check-runtime-file-tracking.sh`'s Check C is now posture-aware,
both postures are pinned by tests, and `orchestrator-runtime-files.md` documents the split plus
a manual opt-in runbook for an already-tracked consumer that wants to switch.

## What Changed

- `agent-system/extensions/core/scripts/lib/runtime-file-patterns.sh` -- new
  `specs_tree_ignore_block()` renderer emitting the one-line `/specs/` managed-block body;
  `runtime_ignore_block()`/`runtime_specs_ignore_block()` left byte-identical.
- `agent-system/extensions/core/scripts/init-specs.sh` -- new Step 5b: fresh-repo detection
  (`git ls-files -- specs/` empty) writes the repo-root `specs-tree-ignore` managed block via
  `git rev-parse --show-toplevel`-resolved target; an already-tracked repo is left untouched at
  the root with a named SKIP. Header comment updated to describe both postures.
- `agent-system/extensions/core/scripts/check-runtime-file-tracking.sh` -- Check C now gates on
  `specs_tree_is_gitignored()` (sourced from `lib/specs-ignore-lib.sh`): SKIPPED (named, exit
  status unaffected) under the whole-tree-ignored posture; unchanged otherwise. Summary line
  distinguishes a skipped Check C from "all three checks passed".
- `agent-system/extensions/core/scripts/tests/test-init-specs.sh` -- three new cases (fresh
  bootstrap writes the root block and `check-ignore` exits 0; idempotence; tracked-posture
  negative control asserted against `git ls-files`); Case 6 reconciled (seeds a tracked file
  first so it keeps pinning the tracked posture / `specs/.gitignore`-only coverage it always
  existed to protect, rather than colliding with the new default).
- `agent-system/extensions/core/scripts/tests/test-runtime-file-tracking.sh` -- new Case 6
  (posture-aware Check C SKIP) and Case 7 (doc-sync pin for the new fenced block, mirroring
  Case 3's extraction idiom with its own distinct fence tag).
- `agent-system/extensions/core/context/standards/orchestrator-runtime-files.md` -- new
  "Fresh-Repo Default: Whole `specs/` Tree Ignored" section: the repo-root-only rationale, the
  tracked-posture hard guarantee, the inner-block disposition, the manual opt-in runbook, and a
  `Verification` section update naming the posture-aware Check C and cross-referencing
  `git-staging-scope.md`.
- `agent-system/extensions/core/index-entries.json` -- `line_count` kept in sync with the
  standards file via `generate-context-line-counts.sh --write` (two re-syncs, matching the
  document's two content revisions).
- Deployed `.claude/` tree regenerated via `deploy-headless.sh`.

## Decisions

- Reconciled `test-init-specs.sh`'s Case 6 by seeding a tracked file before the first
  `init-specs.sh` call, rather than re-pointing it at the "exit 0 with Check C SKIPped"
  expectation -- the complementary skip scenario is covered separately by
  `test-runtime-file-tracking.sh`'s new Case 6, so both halves of the plan's either/or are
  satisfied without dropping the original specs/.gitignore-only assertion.
- Tagged the new fenced gitignore block `gitignore-specs-tree-ignore` (not the plain
  `gitignore` tag `runtime_ignore_block()`'s block already uses), since the existing Case 3
  extraction is unanchored to one specific fence and would otherwise concatenate both blocks.
- Reworded the manual opt-in runbook's commit step to prose (no literal `git commit -m` text, no
  bare `specs/` directory pathspec) after the post-deploy fast-gate battery caught both as
  self-inflicted lint collisions (lint 17 and lint 23) against pre-existing repo-wide lints.

## Plan Deviations

- None (both items above were decisions within plan-left-open choices, not deviations from an
  explicit instruction).

## Verification

- Build: N/A (shell scripts; `bash -n` syntax-checked on every edited script)
- Tests: Passed -- both suites re-verified against the edited source-store scripts directly
  (30/0 and 15/0 respectively, including every new case and Case 3's own unaffected verdict),
  since the deployed-tree-first test resolution otherwise exercises stale pre-redeploy copies
  until the Phase 6 redeploy landed.
- Files verified: Yes
- Negative control (blocking, this repository): all four assertions PASS -- tracked-file count
  11643/11643 unchanged, `check-ignore` rc 1/1 unchanged, root `.gitignore` sha256 identical with
  no `specs-tree-ignore` sentinel, no staged deletions under `specs/`.
- Positive control (scratch repo, deployed scripts): whole `specs/` tree ignored
  (`check-ignore` exits 0) after one run; full lifecycle on top of it (`state-write.sh` task
  creation, `generate-todo.sh`, `check-runtime-file-tracking.sh` exit 0 with Check C SKIPPED)
  all green.
- Gate 3 (doc-lint) and gate 4 (task-reference lint): both report real results (no SKIP) for the
  source-store markdown edit, after fixing a genuine Rule R `line_count` drift this phase's own
  additions caused.

## Impacts

- A freshly initialized consumer repository's task-management history stays local to the
  working copy by default, is shared by every branch checked out in it, and never appears in a
  pull request -- closing the gap this task's description identified.
- An already-tracked consumer (this repository among them) is provably unaffected by the new
  default across every init/deploy/redeploy/loader path exercised.
- `check-runtime-file-tracking.sh` now has a defined, non-silent behavior for the new posture
  instead of a hard-coded assertion that would otherwise fire on every freshly bootstrapped repo.

## Follow-ups

- A pre-existing, unrelated defect in `agent-system/extensions/core/scripts/tests/run-all.sh`
  (gate 27, subject-resolution declaration lint: `common_test_resolve_subject` called without a
  paired `common_test_declare_subject`) was observed during this task's redeploy verification.
  It predates this task (confirmed present in the very first `verify-touched.sh` run of Phase 1,
  before any of this task's edits landed) and the file is outside this task's `file_scope`; it
  was logged via `issue-record.sh` rather than fixed here and needs its own follow-up task.
- The shared-territory ruling with task 338 (sweep_task_support_file_tracked_or_ignored) still
  applies going forward: that task remained `not_started` throughout this implementation and
  was re-confirmed immediately before the Phase 6 redeploy; whichever of the two lands second
  must re-read the other's result rather than assume this plan's enumeration.

## References

- Plan: `specs/660_init_specs_ignores_specs_by_default/plans/01_init-specs-ignores-by-default.md`
- Report: `specs/660_init_specs_ignores_specs_by_default/reports/01_init-specs-ignores-by-default.md`
- Progress: `specs/660_init_specs_ignores_specs_by_default/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/660_init_specs_ignores_specs_by_default/handoffs/phase-{1..5}-handoff-*.md`
