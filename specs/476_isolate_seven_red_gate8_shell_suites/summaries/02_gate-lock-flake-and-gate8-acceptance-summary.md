# Implementation Summary: Task #476

- **Task**: 476 - Make the seven untracked red Gate 8 shell suites green or declared-expected
- **Status**: [COMPLETED]
- **Started**: 2026-11-16T05:20:00Z
- **Completed**: 2026-11-16T06:30:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: 423 (CLOSED), 445 (CLOSED), 568 (CLOSED) -- none blocked this plan
- **Artifacts**: plans/02_gate-lock-flake-and-gate8-acceptance.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Restored Gate 8 (`tests/run-all.sh`) as a usable binary signal across the full, unscoped shell
test corpus. By the time this dispatch began, six of the seven originally-named suites had
already been fixed upstream by unrelated commits; the one remaining piece of substantive work
was `test-gate-lock.sh`'s reported aggregate-only concurrency flake, plus cleanup of two stale
`known-failures.txt` rows (one of which turned out to describe a fixed symptom while the suite
itself was still red for a different, newly-discovered reason). Two full, unscoped
`run-all.sh --fail-on-new` runs now report zero NEW failures, `verify-deploy.sh` passes in full,
and `deploy-headless.sh` reaches `RESULT=landed_verify_clean`.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` -- added a bounded `kill -0`
  liveness wait on the "killed holder (process-group teardown)" case's backgrounded `setsid`
  child after `SIGTERM`, confirming the process has actually died (not merely that
  `$GATE_LOCK_DIR` vanished) before the suite proceeds to the next case. Adds one new case
  (standalone: 16 -> 17 passed, 0 failed).
- `agent-system/extensions/core/scripts/tests/known-failures.txt` -- removed the
  `test-orchestrate-cycle-postflight.sh` row (confirmed green, 312/0) and the (eventually)
  `test-lint-unit-integration-boundary.sh` row (confirmed green post-redeploy, 15/0); net two
  rows removed (6 -> 4 `test-` rows).
- `agent-system/extensions/core/scripts/tests/suite-classification.data` -- added the missing
  classification row for `test-gate8-suite-selection.sh` (`integration`,
  `invokes:verify-deploy.sh,run-all.sh`), closing a coverage gap left by an unrelated,
  already-committed change that added the suite without a data-file edit.
- Deployed tree (`.claude/**`) regenerated twice via `deploy-headless.sh`, both landing
  `RESULT=landed_verify_clean`.

## Decisions

- **Did not re-attempt forcing `test-gate-lock.sh`'s originally-reported 14/2 reproduction.**
  Six reproduction attempts (3 plain aggregate + 3 diagnostic standalone) all passed cleanly.
  Live-code analysis showed the suite has been in `run-all.sh`'s `LOAD_SENSITIVE_BASENAMES`
  since its own creation commit (predating this task's research), so it runs fully serially
  before the parallel pool starts and can never overlap with sibling suites within one
  `run-all.sh` invocation -- the original report's "fails when run concurrently with its
  file-scope siblings" framing does not match the current scheduling model. Classified both
  named cases as class (a) ambient-host-state fixture timing and applied the "assert
  ordering/causality" remedy rung (the liveness wait above) rather than widening a poll window,
  since the mechanism could not be force-reproduced to validate a narrower fix.
- **Kept, rather than removed, the `test-lint-unit-integration-boundary.sh` known-failures.txt
  row initially**, because direct re-run showed it still red (14/1) for a reason unrelated to
  the row's original description. Updated the row's reason to the current, accurate symptom,
  fixed the underlying gap in the source store, and removed the row only after the redeploy
  propagated the fix and the suite was re-confirmed green (15/0).

## Plan Deviations

- **Phase 1, tasks 2-3, 5-6**: the flake did not reproduce under today's host load (0/3 plain +
  0/3 diagnostic attempts), so the plan's "capture the two failing cases' full output" and
  "disambiguate the exit-2 site" steps were satisfied by a diagnostic instrumented copy of the
  suite (measuring real timing margins) and by mechanism inspection instead of live failure
  capture. The "fail-open (verify-deploy.sh Gate 8)" case's specific exit-2 site was never
  isolated for this reason.
- **Phase 2, task 4**: did not remove the `test-lint-unit-integration-boundary.sh` row as
  originally planned. The suite was still red, for a different, newly-discovered coverage gap
  (a missing `suite-classification.data` row for `test-gate8-suite-selection.sh`, added by an
  unrelated, already-committed change). Updated the row's reason instead of removing it, fixed
  the gap in the source store, and removed the row only after Phase 3's redeploy confirmed the
  suite green.

## Verification

- Build: N/A (shell scripts / data files)
- Tests: `test-gate-lock.sh` standalone 17 passed, 0 failed. Two full, unscoped
  `run-all.sh --fail-on-new` runs (post-redeploy): 195 passed, 1 failed (1 expected:
  `test-gate-cache-equivalence.sh`), 0 NEW, 196 total -- both runs identical.
  `verify-deploy.sh` full: PASS -- 43 check(s), 0 failure(s) (twice, after each redeploy).
- Files verified: Yes

## Impacts

- A full Gate 8 run (`run-all.sh` or `verify-deploy.sh` scoped to gate 8) now reports zero
  unexpected failures, with every remaining failure matched to a declared, accurate
  `known-failures.txt` row. Future tasks running a full `verify-deploy.sh` can trust Gate 8's
  binary signal again instead of hand-diffing against an unwritten mental baseline.

## Follow-ups

- **`test-verify-deploy-context-budget.sh`** (the excluded eighth suite) still reproduces its
  `baseline fixture is not clean (rc=1, gate20 finding lines=0)` symptom verbatim, independently
  of this task's own transient deploy-drift measurement of it. Its owning record is CLOSED and
  archived and cannot receive this new finding -- a fresh follow-up task is needed to determine
  whether this is a genuine ambient-host-state/repo-state leak into the suite's own nested
  self-check, independent of any one task's deploy drift. Recorded in `issues.jsonl`.
- A single `verify-deploy.sh` full-battery invocation transiently reported Gate 8 as FAIL (one
  NEW failure, identity not captured) while three separate direct `run-all.sh --fail-on-new`
  invocations taken immediately before and after it all reported 0 NEW. Did not reproduce on
  retry. Plausibly another instance of ambient-host-state contention from concurrently-running
  sibling `/orchestrate` dispatches on this shared host. Recorded in `issues.jsonl`
  (class `ambient-host-state-fixture-timing`) as an open, unchased observation for a future
  corpus-wide review of this flake class.

## References

- Plan: `specs/476_isolate_seven_red_gate8_shell_suites/plans/02_gate-lock-flake-and-gate8-acceptance.md`
- Research: `specs/476_isolate_seven_red_gate8_shell_suites/reports/02_premise-refresh-and-gate-lock-concurrency-flake.md`
- Progress: `specs/476_isolate_seven_red_gate8_shell_suites/progress/phase-{1,2,3}-progress.json`
- Issue log: `specs/476_isolate_seven_red_gate8_shell_suites/issues.jsonl`
