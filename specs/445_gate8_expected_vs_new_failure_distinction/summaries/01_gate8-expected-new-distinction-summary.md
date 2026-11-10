# Implementation Summary: Task #445

- **Task**: 445 - Give verify-deploy.sh's Gate 8 an expected-versus-NEW failure distinction
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T02:19:00Z
- **Completed**: 2026-11-10T03:36:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None blocking (task 411's gate-registry refactor confirmed complete at plan time)
- **Artifacts**: plans/01_gate8-expected-new-distinction.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Gate 8 of `verify-deploy.sh` wrapped `tests/run-all.sh` and collapsed every non-zero child exit
into a blocking `fail()`, discarding the EXPECTED/NEW classification `run-all.sh` already
computes and prints via its own `--fail-on-new` flag and `known-failures.txt` manifest.
`gate8_run()` now passes `--fail-on-new` and branches three ways on the child's exit code plus
the presence of its `[run-all] Failing suites (` roster header: a clean run passes, an
all-declared-expected run is non-blocking but visible via `warn_advisory()` (a `WARN-FINDING
gate8` line, never `FINDING gate8`), and any run containing at least one NEW failure still fails
exactly as before, through the unmodified `fail()` branch and its anchored
`verify_deploy_extract_verdict_lines '[FAIL]'` extraction.

## What Changed

- `agent-system/extensions/core/scripts/verify-deploy.sh` — `gate8_run()`'s three-way verdict
  branch (`--fail-on-new`, the roster-header discriminator, `pass()`/`warn_advisory()`/`fail()`),
  plus an extended header comment documenting the chosen semantics.
- `agent-system/extensions/core/scripts/tests/test-gate8-expected-new-distinction.sh` — new
  regression suite: Cases A-D (all-expected, genuinely-NEW, clean, mixed), consumer-level
  assertions (`deploy_findings_snapshot` filtering, pre/post baseline-skew, `--skip-unchanged`
  cache-ineligibility, zero-check-under-filter), and 6 non-vacuousness probes (22 assertions
  total, all passing).
- `agent-system/extensions/core/scripts/tests/test-run-all-failure-reporting.sh` — 3 new
  roster-header format-stability assertions pinning the `[run-all] Failing suites (` discriminator
  Gate 8 relies on.
- `agent-system/extensions/core/manifest.json` — registered the new suite in `provides.scripts`.
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — registered the new
  suite as `integration`.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — consumer-side
  documentation of Gate 8's new semantics and the accepted mixed-failure residual.
- `agent-system/extensions/core/index-entries.json` — repaired the `line_count` for
  `shell-script-testing.md` after it grew (out-of-scope follow-up, landed via a scoped commit).
- Regenerated deployed `.claude/` tree (`deploy-headless.sh`).

## Decisions

- **Chosen semantics**: an all-declared-expected failing run exits 0, distinguishable on three
  independent channels (a `[WARN]` stderr narrative, a `WARN-FINDING gate8` line invisible to
  `deploy_findings_snapshot`'s strict `grep '^FINDING '`, and a `GATE_DIRTY_LIST` append that
  preserves `--skip-unchanged` cache-invalidation). A NEW failure still fails the gate,
  unconditionally.
- **Discriminator**: presence of the `[run-all] Failing suites (` roster header, never the
  numeric tally — a safer degrade direction (a missing header degrades to `PASS`, never to a
  missed NEW failure).
- **Mixed-failure residual accepted as a named scope boundary**: a run with at least one NEW
  failure still folds every failing suite's line (EXPECTED ones included) into `FINDINGS_LIST`,
  via the unmodified `fail()` extraction. Documented rather than closed; closing it would need a
  second NEW-specific anchor or a roster cross-reference, judged not worth the cost here.

## Plan Deviations

- **Phase 2**: `test-lint-unit-integration-boundary.sh` (named in the phase's own Verification
  Tier suite set) fails against the live corpus on 3 pre-existing violations wholly unrelated to
  this task's two registration edits — confirmed via `git log` to belong to unrelated,
  already-completed tasks (29, 360, 419). Closed `[COMPLETED WITH EXCLUSIONS]` with a full
  Reasoned Exclusions record; the registration itself is independently confirmed correct by the
  other two named suites passing.
- **Phase 3**: non-vacuousness probes use independent `*-novac` fixture copies rather than
  mutating and reverting the shared Case A-D fixtures in place — same evidentiary purpose,
  without a mutate/restore step.
- **Phase 5**: the plan's original expectation (today's real-world corpus shows a clean,
  all-expected `[WARN]` outcome) did not hold at implementation time — the live corpus carries 7
  NEW failures unrelated to this task's `file_scope` (confirmed via `git log` against unrelated
  tasks 409/418/328/435), so Gate 8 correctly reports `[FAIL]`. This is the fix working as
  designed; per this dispatch's Batch Gate Deferral directive, resolving those 7 unrelated
  failures is deferred to the once-per-batch stage rather than this task's own closure, which
  relies on a scoped `--only-gate 3,4,9` check (clean).

## Verification

- Build: N/A (shell scripts; `bash -n` syntax checks passed for every edited script).
- Tests: Phase-scoped suite sets all pass (Phase 1: 5/5; Phase 2: 12/12 new assertions, one
  pre-existing unrelated suite excluded with evidence; Phase 3: 22/22 new-suite assertions plus
  5/5 consumer suites). Full gate set run once for diagnostic value: Gate 8 itself behaves
  correctly (FAILs on genuinely NEW failures elsewhere in the corpus); scoped `--only-gate 3,4,9`
  closure check passes clean.
- Files verified: Yes — every edited file re-read immediately before its edit; no foreign
  commit or uncommitted modification observed on any touched path across all 5 phases.

## Impacts

- A phase closure anywhere in the repository whose only Gate 8 failure is the declared-expected
  set no longer needs a hand-written Reasoned Exclusions record — Gate 8 itself now makes that
  outcome legible via `[WARN]`/`WARN-FINDING`.
- `tests/known-failures.txt`'s accuracy is now load-bearing for Gate 8's verdict in a way worth
  noting for future maintenance: a stale EXPECTED row understates how much of a failing run is
  genuinely new.

## Follow-ups

- The 7 NEW failures observed live in the corpus during Phase 5 (`test-double-loading-check.sh`,
  `test-lint-unit-integration-boundary.sh`, `test-orchestrate-cycle-postflight.sh`,
  `test-orchestrate-predispatch-review.sh`, `test-orchestrate-unwind-dispatch.sh`,
  `test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`) are outside this
  task's scope and were not introduced by it; their resolution or exclusion is left to the
  once-per-batch gate stage or a future task.
- The mixed-failure residual (documented in Phase 4's doc update) remains open as a named,
  accepted scope boundary — not a defect, but a candidate for a future task if the cost of a
  second NEW-specific anchor is ever judged worth paying.

## References

- Plan: `specs/445_gate8_expected_vs_new_failure_distinction/plans/01_gate8-expected-new-distinction.md`
- Report: `specs/445_gate8_expected_vs_new_failure_distinction/reports/01_gate8-expected-new-distinction.md`
- Progress files: `specs/445_gate8_expected_vs_new_failure_distinction/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/445_gate8_expected_vs_new_failure_distinction/handoffs/phase-{1..5}-handoff-*.md`
