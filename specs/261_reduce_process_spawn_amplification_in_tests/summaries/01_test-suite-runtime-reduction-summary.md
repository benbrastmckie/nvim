# Implementation Summary: Task #261

- **Task**: 261 - Reduce process-spawn amplification in tests
- **Status**: [IN PROGRESS]
- **Started**: 2026-09-26T01:14:00Z
- **Completed**: (not yet -- Phase 6 partial, Phase 7 not started)
- **Effort**: ~4 hours of the 11-hour estimate
- **Dependencies**: None
- **Artifacts**: plans/01_test-suite-runtime-reduction.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Phases 1-5 of the 7-phase plan are complete and committed: a durable `--timings`-based
measurement harness, an opt-in `--only-gate` flag for `verify-deploy.sh`, a 4x-to-1x invocation
collapse of the suite's most expensive file, a full parallelism-safety audit of all 96-97
discovered suites, and opt-in `--jobs N` parallelism for `run-all.sh` with a verified 58% wall-time
reduction (449s -> 187s at `--jobs 4`, identical pass/fail set). Phase 6 (the 3-repeated-run
flakiness decision gate) is [PARTIAL]: a real flake was found, correctly diagnosed, and fixed
along the way, but the required clean 3-run validation against the final code has not yet
completed due to two separate interruptions -- the second being genuine system-wide memory
pressure from unrelated concurrent processes on this shared development machine, which the
harness's own idle-session safeguard responded to by terminating a backgrounded validation run.
Phase 7 (coverage-equality proof, documentation, and redeploy) has not been started.

## What Changed

- `agent-system/extensions/core/scripts/tests/run-all.sh` -- added `--timings FILE` (Phase 1) and
  `--jobs N|auto` (Phase 5, default 1, byte-identical sequential branch preserved, nested-guard,
  longest-first scheduling, 5-suite load-sensitive serialization list)
- `agent-system/extensions/core/scripts/verify-deploy.sh` -- added `GATES_FILTER`,
  `gate_selected()`, `--only-gate N[,M,...]` (Phase 2), wrapping all 20 gate blocks without
  reindenting
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` -- collapsed
  3 of 4 `verify-deploy.sh` invocations to `--only-gate 20` (Phase 3), cutting its own wall time
  from ~391s to ~103s
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` -- new suite
  (Phase 2), 5/5 cases, ~87s
- `agent-system/extensions/core/scripts/tests/test-run-all-parallel.sh` -- new suite (Phase 5),
  9/9 cases against a synthetic fixture; case3/case4 redesigned from absolute-ms thresholds to a
  load-tolerant relative ratio after a real flake was found and diagnosed during Phase 6
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` -- new advisory scheduling
  hints (Phase 5), generated from Phase 1's `--timings` capture
- `specs/261_reduce_process_spawn_amplification_in_tests/progress/phase-4-audit-table.txt` -- new,
  full 96-suite (now 97, see addendum) parallelism-safety verdict table (Phase 4, read-only audit)

## Decisions

- Used `git stash push -- <path>` to obtain a TRUE pre-change baseline for Phase 1 (before any of
  this task's edits were committed); this technique stopped working from Phase 3 onward once
  Phase 1/2's edits were committed to source history, so later phases diagnosed source-vs-deployed
  drift by direct reproduction instead (rsync a fixture, run `verify-deploy.sh --findings`,
  inspect the `FINDING gate3`/`gate5` lines) rather than by stashing.
- Kept exactly one full-battery `verify-deploy.sh` invocation in
  `test-verify-deploy-context-budget.sh` (the baseline case) so the "all twenty gates run
  together, clean" contract stays covered somewhere in the suite.
- The 4 suites Phase 4's audit named load-sensitive, plus `test-run-all-parallel.sh` (found
  load-sensitive by Phase 6's own flakiness gate, since it postdates Phase 4's audit), always run
  serially, before the parallel pool, in `run-all.sh` -- an ambient-load precaution, not a
  resource-collision requirement (the audit found zero suites with a fixed port/socket/lock path
  outside their own fixture).
- Root-caused `test-run-all-parallel.sh`'s flake to genuine ambient HOST load (unrelated
  concurrent processes on this shared dev machine), not sibling-suite contention within
  `run-all.sh`'s own pool -- confirmed by testing the "serialize it" hypothesis in isolation and
  observing the flake persisted. Fixed by redesigning its timing assertions as a relative ratio
  (parallel time <= 75% of forced-sequential time, measured back-to-back) instead of absolute-ms
  thresholds, which is robust to a proportional external load multiplier.

## Plan Deviations

- **Phase 6's "run the full suite 3 times" task** deferred to a successor dispatch: two attempts
  were each interrupted (first by the `test-run-all-parallel.sh` flake needing a fix mid-run, then
  by the harness's idle-session memory-pressure safeguard reaping a backgrounded validation run
  during genuine, confirmed system-wide memory pressure from unrelated concurrent
  sessions/builds). This is an environmental constraint, not a task defect. See
  `progress/phase-6-progress.json`'s `deviations` array and the Phase 6 handoff artifact for the
  full record and exact resume command.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: Phases 1-5's own verification criteria all passed (see each phase's commit body and
  progress file for specifics: `--only-gate` cross-gate audit found zero dependencies; all 20
  gates run clean standalone; `test-verify-deploy-context-budget.sh` dropped 391s -> 103s with
  byte-identical assertion call-site counts; `--jobs 1` vs `--jobs 4` produced identical
  pass/fail sets on a real 96-97-suite run, 58% faster). Phase 6's own 3-run gate validation is
  incomplete (see Plan Deviations).
- Files verified: Yes (all new/modified files exist, are syntactically valid `bash -n`, and were
  exercised against both synthetic fixtures and the real repo tree)

## Impacts

- `test-verify-deploy-context-budget.sh` and any caller of `verify-deploy.sh --only-gate` benefit
  immediately from the ~290s saving, independent of whether Phase 6's parallelism gate ultimately
  flips the default.
- `run-all.sh --jobs N` is available today as an opt-in flag (default unchanged at `--jobs 1`);
  whether it becomes the new default depends on Phase 6's still-pending gate decision.
- `.claude/**` does not yet reflect any of these changes -- redeploy is deliberately deferred to
  Phase 7, per this task's own risk-mitigation design (never assume redeploy per-phase).

## Follow-ups

- Complete Phase 6: run the full suite 3 times at `--jobs 4` with the current, fully-fixed code,
  diff against the recorded baseline, inspect the (now 5-suite) load-sensitive set, and apply the
  gate criterion. See the Phase 6 handoff artifact for the exact resume command and the
  memory-pressure caveat.
- Complete Phase 7: coverage-equality proof, documentation in
  `context/standards/shell-script-testing.md`, and the redeploy (`deploy-headless.sh`) that
  resolves the source-vs-deployed drift finding present since Phase 1.
- Re-derive `suite-cost-hints.txt` once Phase 6/7 land, since several suites' costs changed
  materially this task (advisory only -- no correctness impact either way).

## References

- Plan: specs/261_reduce_process_spawn_amplification_in_tests/plans/01_test-suite-runtime-reduction.md
- Research: specs/261_reduce_process_spawn_amplification_in_tests/reports/01_test-suite-performance-baseline.md
- Progress files: specs/261_reduce_process_spawn_amplification_in_tests/progress/phase-{1..6}-progress.json
- Phase 4 audit table: specs/261_reduce_process_spawn_amplification_in_tests/progress/phase-4-audit-table.txt
- Handoffs: specs/261_reduce_process_spawn_amplification_in_tests/handoffs/ (one per phase boundary, plus the Phase 6 interruption handoff)
