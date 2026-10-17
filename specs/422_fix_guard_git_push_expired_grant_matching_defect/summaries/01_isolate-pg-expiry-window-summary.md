# Implementation Summary: Task #422

- **Task**: 422 - Fix guard-git-push expired-grant matching defect
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T00:00:00Z
- **Completed**: 2026-10-17T00:30:00Z
- **Effort**: 0.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_isolate-pg-expiry-window.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`test-guard-git-push.sh`'s single failing case was not a grant-matching or test-isolation defect
in the guard or the grant-selection logic: the suite isolated two of `push-grant-lib.sh`'s three
environment-overridable knobs (`PUSH_GRANT_KEY_PATH`, `PUSH_GRANT_DIR`) but not the third,
`PG_EXPIRY_WINDOW`, which this machine exports as `1800` for every session. The suite's fixed
700s "expired" fixture was genuinely still fresh against a 1800s window, so the guard correctly
exited 0. Both plan phases executed exactly as diagnosed by the research, with no diagnostic or
tracing work needed and no production-code change.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` — added
  `unset PG_EXPIRY_WINDOW` to the fixture-isolation block (alongside the existing
  `PUSH_GRANT_KEY_PATH`/`PUSH_GRANT_DIR` overrides); extended the `CRITICAL environmental
  requirement` header paragraph to name all three isolated knobs and explain why
  `PG_EXPIRY_WINDOW` must be unset; added an inline comment at the 700s backdating site noting
  its dependency on `push-grant-lib.sh`'s 600s default and on the header's `unset`.
- `agent-system/extensions/core/scripts/tests/known-failures.txt` — removed the
  `test-guard-git-push.sh|real-defect|...` row; repaired the seed-narrative recorded-row count
  from 4 to 3; repaired the comment block directly above the removed row from plural ("the two
  rows below ... both are ...") to singular, now describing only the surviving
  `test-verify-deploy-context-budget.sh` row (whose own "confirmed NOT to be that defect class"
  claim was left unchanged).

## Decisions

- Used `unset PG_EXPIRY_WINDOW` rather than `export PG_EXPIRY_WINDOW=600`, per the research's
  reasoning: `unset` re-derives `push-grant-lib.sh`'s own current default at run time instead of
  hardcoding a duplicate value that would need hand-syncing if the library's default ever
  changes.
- Phase 2's `Verification Tier: full` was discharged against a scoped narrowing invocation
  (`run-all.sh --only test-orchestrate-cycle-plan.sh,test-run-all-failure-reporting.sh,test-run-all-selection.sh`
  — the three suites `suite_selection_select` maps `known-failures.txt` to) per this dispatch's
  Batch Gate Deferral directive, rather than independently running `verify-deploy.sh` at full
  depth. The complete gate set still runs once for the whole `/orchestrate` batch and is
  attributed back to this task via its `modified_files`.

## Plan Deviations

- **Task 2.6** altered: ran the scoped narrowing invocation instead of the full
  `verify-deploy.sh` gate set, per the dispatch's Batch Gate Deferral directive (see Decisions
  above). Not a skip — the full gate set is deferred to the batch stage, not forgiven.

## Verification

- Direct run: `bash agent-system/extensions/core/scripts/tests/test-guard-git-push.sh` ->
  47 passed, 0 failed, confirmed with the ambient `PG_EXPIRY_WINDOW=1800` still exported.
- `run-all.sh --only test-guard-git-push.sh,test-please-grant.sh` -> 2 passed, 0 failed.
- `run-all.sh --only test-orchestrate-cycle-plan.sh,test-run-all-failure-reporting.sh,test-run-all-selection.sh`
  (Phase 2's scoped gate discharge) -> 3 passed, 0 failed.
- `grep -c 'test-guard-git-push' known-failures.txt` -> 0.
- `git diff`/`git status --short` confirm each phase's commit touched only its one named file
  plus the task directory's own tracked state (plan, progress, handoffs, `.return-meta.json`).
- Build: N/A (shell scripts only). Tests: Passed. Files verified: Yes.

## Impacts

- `test-guard-git-push.sh` now passes 47/47 under the real ambient environment this machine
  always exports, not only under an artificially cleaned one — closing the gap between CI-clean
  and real-session execution for this suite.
- `known-failures.txt` stays internally consistent (no stale row, no stale count) and no longer
  misattributes this now-refuted diagnosis to `push-grant-lib.sh`'s grant-matching logic.

## Follow-ups

- The research's Context Extension Recommendation (naming "deliberately-exported session-
  configuration env vars read via `${VAR:-default}`" as a fourth ambient-host-state coupling
  axis, distinct from the three this task's dispatch originated from) remains open as a
  documentation follow-up outside this task's scope.

## References

- `specs/422_fix_guard_git_push_expired_grant_matching_defect/plans/01_isolate-pg-expiry-window.md`
- `specs/422_fix_guard_git_push_expired_grant_matching_defect/reports/01_push-grant-expiry-window-env-leak.md`
- `specs/422_fix_guard_git_push_expired_grant_matching_defect/progress/phase-1-progress.json`,
  `phase-2-progress.json`
- `specs/422_fix_guard_git_push_expired_grant_matching_defect/handoffs/phase-1-handoff-20261017T000000Z.md`,
  `phase-2-handoff-20261017T003000Z.md`
