# Implementation Summary: Task #287

- **Task**: 287 - No co-schedule build-heavy implement (Mode 2 admission rule)
- **Status**: [COMPLETED]
- **Started**: 2026-09-30
- **Completed**: 2026-09-30
- **Effort**: ~2.5 hours
- **Dependencies**: `specs/decisions/worktree-isolation-removal-verdict.md` ("Mode 2 Ruling: an Admission Rule, Not a PATH Shim")
- **Artifacts**: plans/01_build-heavy-coschedule-rule.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Closed concurrency failure Mode 2 (shared build-directory contention) by adding a cycle-split
admission rule to `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`: the orchestrator
now never dispatches two build-heavy implement tasks in the same cycle. A second build-heavy
implement candidate in the same cycle defers to a later cycle with its own named reason, exactly
as a `file_scope_collision` defers today. This closes the blocking prerequisite for removing
worktree isolation named in `specs/decisions/worktree-isolation-removal-verdict.md`.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — hoisted the
  `WORKTREE_ISOLATED_TASK_TYPES`/`task_selected_for_worktree_isolation()` block above the
  bucketing loop (required: the predicate is defined inside the single
  `orchestrate_cycle_plan_main` function body, so a call site earlier than its definition would
  silently return a swallowed exit 127 under `set -euo pipefail`), renamed the array to
  `BUILD_HEAVY_TASK_TYPES` to state its now-dual meaning, added the Mode 2 admission check inside
  the bucketing loop (one scalar tracking the first build-heavy implement candidate admitted per
  cycle; any further build-heavy implement candidate defers with its own named reason), and added
  header-contract documentation (a new "Decision (this task)" paragraph plus an update to the
  `isolation` paragraph naming `BUILD_HEAVY_TASK_TYPES`).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — added Group 32
  with the four acceptance-case fixtures (two build-heavy candidates defer one; one build-heavy +
  one ordinary candidate both dispatch; two build-heavy candidates in different phases both
  dispatch; `--dry-run`/live parity is byte-for-byte identical). Also split Group 30's pre-existing
  Cases D-F live fixture into two cycles (see Plan Deviations) to decouple its own concern
  (per-candidate isolation/provision-failure handling) from the new cross-task Mode 2 rule.

## Decisions

- The array/predicate block had to be hoisted (not just renamed) above the bucketing loop: every
  line from `orchestrate_cycle_plan_main() {` through EOF is the body of one function, and a
  nested function definition is only registered once execution reaches it. A call from the
  bucketing loop to a predicate still defined further down would hit "command not found" (exit
  127), silently swallowed as `false` by an `if` guard under `set -euo pipefail` — the rule would
  compile, shellcheck clean, and never fire. This was flagged as a research-recommendation
  correction in the plan and verified empirically before Phase 2 added any call site.
- The new rule reuses `task_selected_for_worktree_isolation()` itself (never re-iterating
  `BUILD_HEAVY_TASK_TYPES` directly) so "single array, single reader" holds literally.
- The defer reason is a distinct, grep-able string (`build-heavy implement co-scheduling:
  candidate #<N> is already this cycle's one build-heavy implement dispatch; deferring to a later
  cycle`) — never the `file_scope_collision` string, whose payload fields would be empty here.
- No `defer_ledger` entry was added for the new reason (per the plan's Non-Goals: no consumer
  reads `defer_ledger` contents for behavior).

## Plan Deviations

- **Group 30's Cases D-F fixture** (pre-existing, not touched by Phases 1-2) was discovered during
  Phase 2/3 verification to co-schedule two build-heavy implement candidates (3004 lean4 + 3005
  cslib) in one live cycle — exactly the combination the new Mode 2 rule now forbids. The new rule
  correctly deferred 3005 for its own new reason before the lock-probe/provision step Case E was
  designed to exercise ever ran, breaking that one assertion. This is the new rule working exactly
  as specified, exposing an old fixture whose shape is no longer a valid "two build-heavy tasks
  safely co-scheduled" scenario. Fixed by splitting the live fixture into two cycles (3004+3006,
  then 3005 alone), decoupling Group 30's own concern (per-candidate isolation selection and
  provision-failure handling) from Group 32's new concern (cross-task co-scheduling). Every
  original Group 30 assertion is preserved unchanged, only the cycle grouping changed. Reported
  here explicitly per the plan's own Phase 2 verification guidance ("a real finding to report, not
  a fixture to silence") rather than silently patched.
- Phase 2's "manual two-candidate smoke run" verification step was folded into writing Phase 3's
  Group 32 Case (i) directly rather than a separate throwaway smoke test, since Group 32 needed
  the identical fixture shape anyway; Group 32 Case (i) is the smoke-test evidence.

## Verification

- Build: N/A (bash scripts; `bash -n` syntax check passed on both edited files)
- Tests: `test-orchestrate-cycle-plan.sh` — 339 passed, 0 failed (targeted suite, includes the new
  Group 32 and the repaired Group 30)
- Wider harness: `run-all.sh` — 101 passed, 5 failed (4 pre-existing EXPECTED entries already in
  `known-failures.txt`; the 5th, `test-typst-element-lint.sh`, traces to a pre-existing,
  uncommitted, concurrently in-flight change to `typst-element-lint.sh` from an unrelated task,
  outside this task's file scope and outside the orchestrate-cycle-plan suite entirely —
  `known-failures.txt`'s own header documents and excludes this exact scenario for this exact
  file). No failure is attributable to this task's changes.
- Shellcheck: both edited files are byte-for-byte identical (message content, not just counts) to
  their own true pre-edit baselines, confirmed via `git stash` comparison
  (`orchestrate-cycle-plan.sh`: 4×SC2154, 8×SC1091, 5×SC2012, 60×SC2016; `test-orchestrate-cycle-plan.sh`:
  3×SC2319, 2×SC2034, 2×SC2016, 1×SC2329 — all pre-existing, unrelated to this task's edits; the
  plan's own recorded baselines were slightly stale relative to the actual repo state at
  implementation time, not a discrepancy this task introduced).
- Task-reference lint: 0 unexempted occurrences in both edited files.
- Files verified: Yes (both edited files exist, are non-empty, and `bash -n` clean).

## Impacts

- `/orchestrate` now refuses to co-schedule two build-heavy (`lean4`/`cslib`) implement tasks in
  the same cycle, closing the one concurrency failure mode declared `file_scope` structurally
  cannot cover (no task declares `.lake/` in its `file_scope`). This is the blocking prerequisite
  for a future task to remove worktree isolation per
  `specs/decisions/worktree-isolation-removal-verdict.md`.
- A bare build-tool invocation from outside an orchestration (an operator's own shell, or a script
  this system does not own) still bypasses `lake-build-guard.sh`'s opt-in lock — this residual is
  named and deliberately declined in the decision record, not solved here (no PATH-shim wrapper
  was built, per the plan's Non-Goals).

## Follow-ups

- None required by this task. The decision record's declined PATH-shim residual remains available
  as a future task if that gap becomes a live problem.

## References

- Plan: `specs/287_no_coschedule_build_heavy_implement/plans/01_build-heavy-coschedule-rule.md`
- Research: `specs/287_no_coschedule_build_heavy_implement/reports/01_build-heavy-coschedule-admission.md`
- Decision record: `specs/decisions/worktree-isolation-removal-verdict.md`
- Edited files: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
