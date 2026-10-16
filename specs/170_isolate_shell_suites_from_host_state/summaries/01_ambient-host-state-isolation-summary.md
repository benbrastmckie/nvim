# Implementation Summary: Task #170

- **Task**: 170 - Isolate shell test suites from ambient host state (memory and timing axes) and record the isolation convention
- **Status**: [COMPLETED]
- **Started**: 2026-10-16T12:00:00Z
- **Completed**: 2026-10-16T15:35:00Z
- **Effort**: ~6 hours (across six phases, two implement dispatches)
- **Dependencies**: 206, 215, 250, 251, 366 (all archived/completed)
- **Artifacts**: plans/01_ambient-host-state-isolation.md, reports/01_ambient-host-state-audit.md, reports/02_corpus-triage-ledger.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Audited all 153 shell test suites under `agent-system/extensions/**` for assertions whose
outcome depends on ambient host state (memory, wall-clock timing, load/CPU, network, disk,
process table), isolated the two confirmed in-scope instances at their own seams, triaged the
remaining corpus with a recorded verdict for every suite, and recorded the resulting isolation
convention in `shell-script-testing.md`. Every suite in the corpus now carries one of six
verdicts; two genuinely out-of-scope real defects and one newly-discovered secondary timing race
were each given a `known-failures.txt` row or a spawned follow-up task rather than being folded
into this task's own fix work.

## What Changed

- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — Case 6's wall-clock window
  assertion (`elapsed_ms` within `[BUDGET_MS, 2*BUDGET_MS)`) replaced with a PATH-shimmed fake
  `sleep` plus an exact `sleep_count == BUDGET_MS/POLL_MS` causal invariant; Case 5's redundant
  `elapsed_ms -lt 500` clause dropped (its `rc`/`NOTE:`-count pair already proved the property).
  Case 1 confirmed clean and left unchanged. Non-vacuousness demonstrated at two budget values.
- `agent-system/extensions/core/scripts/tests/test-detect-noop-bash.sh` — Both "no stray `tmp/`
  directory" checks converted from absolute existence checks to delta-based (snapshot at suite
  start, fail only on a genuine before/after delta, loud skip on the pre-existing branch) via a
  shared `shared_path_delta_status`/`check_shared_path_not_stray` pair.
- `agent-system/extensions/core/scripts/tests/known-failures.txt` — Two new `real-defect` rows
  added (`test-guard-git-push.sh`, `test-verify-deploy-context-budget.sh`), each live-output-
  matched and durable-anchor-owned, plus a header note distinguishing them from the suite case
  immediately above.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — New
  `## Ambient-host-state isolation` section: the defect class and blast radius, the seam-first
  rule for readable-input axes, the timing-axis ladder (inject-clock / assert-causality /
  bounded-widening-last-resort), the shared-path delta-check sub-shape, the timeout sub-shape,
  the mandatory non-vacuousness check, and the threshold-relaxation prohibition — cross-
  referencing, not restating, the existing Fixture convention, Loud-skip discipline, and `--jobs`
  sections.
- `specs/170_isolate_shell_suites_from_host_state/reports/02_corpus-triage-ledger.md` — New
  report: a recorded verdict for every one of the 153 corpus suites (3 affected-and-isolated, 30
  false-positive-with-reason, 6 fixture-completeness-resolved, 2 real-defect, 0
  legitimately-host-dependent, 118 no-hit).
- `specs/state.json` / `specs/TODO.md` — Three follow-up tasks created: 422
  (`test-guard-git-push.sh` grant-matching defect), 423 (`test-verify-deploy-context-budget.sh`
  eager-load baseline drift), 424 (`test-four-tier-conflict.sh` case 1's backgrounded-releaser
  fixture race, discovered during this task's own Phase 6 load-testing).

## Decisions

- Instance A (`test-lake-build-guard.sh`, memory axis) was re-verified closed by research and
  deliberately left out of `file_scope` — no reproducing defect, and the 2026-09-22 "reopened"
  claim never pinned a failing case.
- The timing axis needed a different technique than the memory axis's seam-redirection: case 6
  uses the "inject the clock" rung (a `PATH`-shimmed fake `sleep`, zero production-code changes,
  since `cmd_acquire_retry` calls bare `sleep`); case 5 uses the "assert causality directly"
  rung (dropping the redundant elapsed clause entirely rather than widening it).
- `test-detect-noop-bash.sh`'s stray-directory defect is a distinct sub-shape of this same class
  (a shared, non-fixture, live-tree path) rather than memory/timing/load/network/disk/
  process-table proper — named explicitly in the new convention section rather than forced into
  an existing axis.
- Two live-reproducing, load-independent real defects found during corpus-wide triage
  (`test-guard-git-push.sh`, `test-verify-deploy-context-budget.sh`) were deliberately NOT fixed
  here — out of this task's defect class and non-goals — but given evidenced manifest rows and
  spawned owners (tasks 422, 423) rather than left ambiguous.
- A third, newly-discovered, lower-probability timing race in `test-four-tier-conflict.sh`
  case 1's own fixture (not its assertion) was found during this task's own Phase 6
  load-reproduction work. Deliberately not fixed in this dispatch — Phase 2 had already closed
  case 1 as correct based on a narrower, correct read, and widening that closed decision under
  time pressure was judged worse than a clean follow-up task (424) with the reproduction method
  already recorded.
- This dispatch's `## Batch Gate Deferral` directive discharged Phase 6's own
  `**Verification Tier**: full` obligation against a scoped tier (the five suites this task's
  phases touched, run twice via `run-all.sh --only`) rather than the full three-run/
  full-`verify-deploy.sh` acceptance bar, which is owed once at the batch's conclusion instead.
  The plan's own `**Verification Tier**: full` field was left unedited, per the Batch-aware
  deferral contract.

## Plan Deviations

- **Phase 2, task "optional generous backstop"** skipped: the backstop was omitted entirely
  rather than retained, since the causal `sleep_count` assertion is already strictly stronger
  than the window it replaced.
- **Phase 6, "three consecutive full runs"** deferred to the once-per-batch stage via the
  dispatch's own Batch Gate Deferral directive; discharged instead via a scoped two-run
  `run-all.sh --only` pass over the five suites this task touched (see Verification below).
- **Phase 6, "full `verify-deploy.sh` run"** deferred to the same once-per-batch stage.
- **Phase 6, new case-1 finding**: a third timing race (fixture-level, not assertion-level) was
  discovered beyond the plan's own scope and deferred to follow-up task 424 rather than fixed
  in-dispatch.

## Verification

- `run-all.sh --only test-four-tier-conflict.sh` (Phase 2): 1 passed, 0 failed via `--only`;
  14 passed, 0 failed direct, including the case-6 non-vacuousness check at a second budget
  (`sleep_count=10` at 1000/100ms, `sleep_count=5` at 500/100ms).
- `run-all.sh --only test-detect-noop-bash.sh` (Phase 3): 1 passed, 0 failed via `--only`; 52
  passed, 0 failed direct; both directions of the non-vacuousness check confirmed (planted
  mid-run turns it red; pre-existing at suite start produces a loud skip).
- `run-all.sh --only test-run-all-failure-reporting.sh` (Phase 4): 1 passed, 0 failed — manifest
  parses correctly after the two new `known-failures.txt` rows.
- `run-all.sh --only test-guard-git-push.sh,test-verify-deploy-context-budget.sh` (Phase 4):
  `2 expected, 0 NEW` — both new rows annotate EXPECTED, not NEW.
- `verify-deploy.sh --skip-slow --only-gate 3,4 <repo-root>` (Phase 5, after a required
  `deploy-headless.sh` redeploy): gate 4 zero findings; gate 3's sole finding is a pre-existing,
  concurrent-session lean-extension index gap, confirmed via `git status`/`git log` to be
  unrelated to this task's own edits (reported, not fixed, per the Observation Duty).
- `measure-eager-context.sh --check`: `TOTAL: 67088 B`, identical before and after Phase 5's
  edit — confirms `shell-script-testing.md` is not eager-loaded.
- Load-reproduction (Phase 6): a pre-fix copy of `test-four-tier-conflict.sh` (extracted via
  `git show 46dcd6e5d:...`, scratchpad only, working tree untouched) failed cases 5 and 6 under
  28 concurrent `yes` busy-loop workers (1-minute load average 12.55 at run end), exactly matching
  the originally recorded symptom. The post-fix suite passed cleanly under the same mechanism
  across two independent passes (load averages 15.17 and 20.45).
- Scoped batch-gate-deferral discharge (Phase 6): `run-all.sh --only
  test-four-tier-conflict.sh,test-detect-noop-bash.sh,test-guard-git-push.sh,
  test-verify-deploy-context-budget.sh,test-run-all-failure-reporting.sh`, run twice
  consecutively, both times `3 passed, 2 failed (2 expected, 0 NEW), 0 skipped, 5 total`; every
  one of the five suites individually re-run via `run-all.sh --only <basename>` agrees exactly
  with its batch verdict.
- Build: N/A (meta task, no compiled artifact).
- Files verified: Yes (all five modified/created production and report files confirmed present
  and non-empty).

## Impacts

- `agent-system/extensions/core/scripts/tests/run-all.sh`'s Gate-8-covering shell-test-suite
  battery is now robust to ambient CPU contention for the two previously-flaky suites — a
  loaded `/orchestrate` batch will no longer intermittently defer on either of them.
- Future suite authors inherit a documented, cited isolation convention (seam-first for readable
  inputs, the timing ladder for wall-clock, the shared-path delta-check sub-shape, the mandatory
  non-vacuousness check) rather than having to re-derive the technique from first principles.
- Three follow-up tasks (422, 423, 424) now own three distinct, evidenced, reproducible defects
  this task's audit surfaced but correctly did not fold into its own scope.

## Follow-ups

- Task 422: fix `test-guard-git-push.sh`'s grant-matching/test-isolation defect.
- Task 423: resolve `test-verify-deploy-context-budget.sh`'s eager-load baseline drift (988 B
  over the 66,100 B baseline, independently re-measured at 67,088 B).
- Task 424: harden `test-four-tier-conflict.sh` case 1's backgrounded-releaser fixture against
  the extreme-CPU-contention race discovered during this task's own Phase 6 load-testing.
- The complete, unscoped three-run/full-`verify-deploy.sh` acceptance bar this task's Phase 6
  would ordinarily discharge independently is owed once, at the current `/orchestrate` batch's
  conclusion, per the dispatch's own Batch Gate Deferral directive — not a gap in this task's own
  closure, but worth naming so the batch-level stage's result is read as covering it.

## References

- Plan: `specs/170_isolate_shell_suites_from_host_state/plans/01_ambient-host-state-isolation.md`
- Research: `specs/170_isolate_shell_suites_from_host_state/reports/01_ambient-host-state-audit.md`
- Ledger: `specs/170_isolate_shell_suites_from_host_state/reports/02_corpus-triage-ledger.md`
- Progress files: `specs/170_isolate_shell_suites_from_host_state/progress/phase-{1..6}-progress.json`
- Handoffs: `specs/170_isolate_shell_suites_from_host_state/handoffs/phase-{1..6}-handoff-*.md`
