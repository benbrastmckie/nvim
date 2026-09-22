# Implementation Summary: Task #173

- **Task**: 173 - Guarantee lake-build-guard.sh writes a terminal record on every exit path and exposes the build verdict through a result subcommand
- **Status**: [COMPLETED]
- **Started**: 2026-09-22T00:10:00Z
- **Completed**: 2026-09-22T02:25:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None outstanding (bounded-build-waiter idiom task already COMPLETED)
- **Artifacts**: plans/01_guard-terminal-record-result.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-script-testing.md

## Overview

Made `lake-build-guard.sh`'s on-disk build record terminal on every exit path (including a
trapped kill and, as discovered mid-implementation, an ordinary failing build) and exposed the
recorded verdict through a new `result` subcommand whose own exit code carries a build's pass/
fail with no text parsing and no pipeline required. All five planned phases landed: the
EXIT/INT/TERM trap and idempotency guard, the `result` subcommand with its enumerated exit band
and orphan detection, `--expect-pid`/`--expect-scope` ownership assertions, a belt-and-braces
STATUS stderr line, and full documentation. The regression suite grew from 29 to 47 passing
checks (34 numbered cases, 11 mutation checks), all in the source store
(`agent-system/extensions/core/scripts/`), never `.claude/**`.

## What Changed

- `agent-system/extensions/core/scripts/lake-build-guard.sh` — Added an optional `state`/
  `abort_reason` parameter pair to `finalize_record()`; added the `_RECORD_FINALIZED` idempotency
  flag and `_abort_record_trap()` handler, installed as an EXIT/INT/TERM trap in `run_as_holder()`
  immediately after the in-flight record is written; fixed a pre-existing bug in
  `run_lake_foreground()` where its own internal `set -e` reactivation, before its tail
  `return "$rc"`, triggered errexit-driven premature termination for any FAILING (nonzero-exit)
  build, skipping `finalize_record()` entirely and leaving `state=in_flight` forever with no
  signal involved; added the `result` subcommand (`cmd_result()`) with an enumerated exit band
  (0/20/21/22/23/24), non-blocking-`flock`-based orphan detection, and `--expect-pid`/
  `--expect-scope` ownership assertions; added the `lake-build-guard: STATUS: exit_status=N`
  stderr line on the holder and no-flock paths (never on REPLAY, never inside the capture files);
  documented all four `.lake/build-guard.{result,stdout,stderr,log}` paths, the `result` usage
  line, the exit band, and a READING THE VERDICT rule in both the header and `print_help()`.
- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` — Added cases 23-34
  (killed-holder terminal record, post-kill non-blocking rebuild, `result` verdict/orphan
  reporting, `--expect-pid`/`--expect-scope` assertions, the STATUS line and its documentation)
  and mutations G-K; updated cases 1 and 3 to strip the one documented STATUS line before their
  byte-equality comparison (the line is now genuinely guard-emitted on every real build); updated
  the suite's header pass-count sentence throughout.

## Decisions

- Killed-holder tests read `holder_pid` back from the record itself (never bash's `$!`) as the
  process-group handle for `kill -TERM -- -$pgid`, since `setsid`'s fork behavior is ambiguous
  depending on the calling shell's own process-group state, but `holder_pid` (the guard's own
  `$$`) is always accurate.
- `_RECORD_FINALIZED` is a global (never `local`), so it is reliably visible to the trap handler
  regardless of bash's dynamic-scoping subtleties across a signal-delivery boundary.
- The `result` exit band stays entirely outside the existing reserved 75-79 usage band, per the
  plan's Decision 3.

## Plan Deviations

- **Unplanned fix in Phase 2**: `run_lake_foreground()`'s internal `set -e` reactivation, before
  its own `return "$rc"`, was a pre-existing defect (confirmed present before this task) that
  caused ANY failing build (not just a killed one) to skip `finalize_record()` and leave
  `state=in_flight` forever. This is the same "terminal record on every exit path" goal Phase 1
  targets, one exit path wider than the plan named. Fixed by removing the redundant internal
  `set -e` restore; callers already bracket the call in their own `set +e`/`set -e`.
- **Cases 1 and 3 updated (Phase 4)**: their original "zero guard-emitted bytes" byte-equality
  assertion was in direct tension with the STATUS line's unconditional emission on every real
  build. Updated both to strip the one documented STATUS line before comparing, preserving the
  core "real lake output is byte-identical" guarantee rather than weakening the STATUS line's own
  contract.

## Verification

- Build: N/A (shell script, no compiled artifact)
- Tests: Passed — `bash agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` reports 47 PASS, 0 FAIL
- Files verified: Yes — shellcheck clean on the main script (0 findings); test file carries only
  info-level SC2016/SC2329 findings matching the pre-existing baseline pattern
- Task-reference check: 0 occurrences (`check-task-references.sh` on the source-store scripts tree)
- `git diff --stat` confirms only the two `file_scope` paths changed, nothing under `.claude/**`
- Acceptance demo: a failing fixture's `result --dir FIXTURE; echo $?` returns 20, with the real
  recorded `exit_status=1` visible on stdout, no pipeline

## Impacts

- Any waiter or consumer polling `holder_pid` via `kill -0` now always observes a terminal state
  (`complete`, `aborted`, or an orphan-detected `in_flight`) instead of a permanently-stuck
  `in_flight` record, closing the original leaked-poll-loop defect one layer down.
- A consumer can now obtain a truthful build verdict from the guard's own exit code alone,
  closing the false-"exit 0" defect absorbed from the former result-subcommand task.
- `decide_sharing()`, the 75-79 reserved band, the exit-77 subcommand allowlist, the REPLAY
  marker contract, and `--timeout`'s lock-wait-only semantics are all unchanged (verified via
  byte-identical `git diff` hunks and the existing cases 4-20 staying green).

## Follow-ups

- Consumer-side contract corrections (wiring lean4 agents/context to use `result` instead of a
  piped invocation) are explicitly out of scope here — a separate dependent task, per the plan's
  Non-Goals.

## References

- Plan: `specs/173_guard_terminal_record_every_exit/plans/01_guard-terminal-record-result.md`
- Report: `specs/173_guard_terminal_record_every_exit/reports/01_guard-terminal-record-and-result.md`
- Progress files: `specs/173_guard_terminal_record_every_exit/progress/phase-{1..5}-progress.json`
