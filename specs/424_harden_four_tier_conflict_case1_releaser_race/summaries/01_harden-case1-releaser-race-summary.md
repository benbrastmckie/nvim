# Implementation Summary: Task #424

- **Task**: 424 - Harden four-tier-conflict Case 1's releaser race
- **Status**: [COMPLETED]
- **Started**: 2026-10-18T00:00:00Z
- **Completed**: 2026-10-18T02:15:00Z
- **Effort**: 2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_harden-case1-releaser-race.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`test-four-tier-conflict.sh` Case 1 reliably reproduced a load-dependent failure under heavy CPU
contention: a fixed-delay backgrounded releaser could remove a foreign lock before the
foreground `task-lock.sh acquire-retry` call's first attempt had even started, flipping the
fixture's assumed ordering. This task replaced the fixed delay with a signal-file-gated
construction that enforces ordering by direct evidence rather than a wall-clock margin, verified
the fix live under the same induced-load reproduction method that found the defect, and
redeployed with the full gate set run.

## What Changed

- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` — Case 1's fixed-delay
  releaser (`sleep 0.3` then `rm -rf .../.lock`) replaced with a signal-file-gated construction:
  a distinctly-named `CASE1_SLEEP_SHIM_DIR` / `CASE1_SIGNAL_FILE` PATH-shimmed `sleep` (reusing
  the same external seam Case 6 already exploits, but as a real-sleep ordering signal rather
  than an instant-return iteration counter) touches a marker the instant the foreground call's
  first attempt has observed the lock held; the releaser polls for that marker instead of racing
  a fixed delay. Case 1's header comment documents the construction. The `PATH` override is a
  command-scoped prefix on the single `"$TL" acquire-retry` invocation only, never exported.
- `.claude/scripts/test-four-tier-conflict.sh` — regenerated deploy artifact (gitignored, not a
  git-tracked change), confirmed byte-identical to the source-store copy.

## Decisions

- Signal-file-gated releaser, not a widened delay — a larger constant would only raise the
  race's threshold rather than removing it; the signal-file construction removes it by
  construction and was shown to hold at higher loads (22.62-26.98) than the two loads that broke
  the original construction (18.33, 23.66).
- No production-code change — `task-lock.sh` remains read-only; the fix reuses the existing bare
  `sleep` PATH seam Case 6 already exploits, for a distinct ordering-signal mechanism under
  distinctly-named variables (`CASE1_SLEEP_SHIM_DIR` / `CASE1_SIGNAL_FILE`).
- RED-first ordering: Phase 1 established two independent live reproductions against the
  unmodified, committed file before any edit landed, making the Phase 2 fix's non-vacuousness
  evidence stronger than a reverted-copy comparison would have been.

## Plan Deviations

- **Task 3.2** altered: ran the loaded A/B verification via a direct invocation of
  `test-four-tier-conflict.sh` rather than through the `run-all.sh --only` wrapper named in the
  plan's literal text, because `run-all.sh` only prints per-case detail on a FAIL, not on a
  PASS, and the task's own next step requires explicitly confirming each of Cases 2-13
  individually passed. The direct invocation runs the identical suite code path, so this is
  strictly more evidence, not less — recorded in `progress/phase-3-progress.json`'s
  `deviations` array.

## Verification

- Build: N/A (shell test fixture change, no build step)
- Tests: Passed, with one recorded exclusion
  - Unloaded: `run-all.sh --only test-four-tier-conflict.sh` reports 14/14 pass both before
    (Phase 1 control) and after (Phase 2) the fix.
  - Loaded (fix): three independent induced-load passes against the committed file (loads
    22.62, 24.97, 26.98 — all meeting/exceeding the dispatch's 12.6-20.5 range) each report
    14/14 pass, with every one of Cases 2-13 individually confirmed `[PASS]`.
  - Loaded (original, non-vacuousness): the unmodified fixture reproduced the reported failure
    (`rc=0 note_count=0 abort_count=0`) twice under the same harness (loads 18.33, 23.66) before
    the fix was applied.
  - `shellcheck -S warning` on the modified file: clean.
  - Grep confirmed: no `export PATH`/standalone `PATH=` line introduced; Case 6's shim variable
    names untouched; Case 1's `sleep 0.3` is gone.
  - `deploy-headless.sh` redeploy: `RESULT=landed_verify_clean`; deployed
    `test-four-tier-conflict.sh` is byte-identical to the source-store copy (`diff` empty).
  - `run-all.sh` (unfiltered, at quiet host load): `158 passed, 1 failed (1 expected, 0 NEW)` —
    the one failure is the pre-existing, out-of-scope `test-gate-cache-equivalence.sh`;
    `test-four-tier-conflict.sh` itself `[PASS]`. Two suites that failed transiently in an
    earlier, load-contended run of the same unfiltered battery
    (`test-lint-state-writer-boundary.sh`, `test-update-task-status.sh`) were independently
    confirmed as load-induced noise via isolated re-runs that passed cleanly.
  - `verify-deploy.sh` (full, unfiltered): `FAIL -- 1 of 38 check(s) failed`, recorded as a
    reasoned exclusion (plan Phase 4's `#### Reasoned Exclusions` subsection) — gate 8 treats
    any non-zero `run-all.sh` exit as FAIL with no expected/new distinction, and the sole cause
    is the same pre-existing, out-of-scope `test-gate-cache-equivalence.sh` failure.
- Files verified: Yes

## Impacts

- `test-four-tier-conflict.sh`'s Case 1 no longer depends on a wall-clock margin for its
  foreground/background ordering, removing a secondary, lower-probability timing defect found
  during a separate audit's load-reproduction work. Cases 2-13 and the rest of the suite corpus
  are unaffected.

## Follow-ups

- Deferred (explicitly out of this task's single-file scope): add the "backgrounded helper's
  fixed-delay release racing a foreground call's scheduling latency" sub-shape to
  `context/standards/shell-script-testing.md`'s timing-axis catalogue, documenting this
  construction as a reusable pattern for future ambient-host-state isolation work.
- The pre-existing, independently-tracked `test-gate-cache-equivalence.sh` standing failure and
  `verify-deploy.sh` gate 8's binary (no expected/new distinction) propagation of any
  `run-all.sh` non-zero exit remain outside this task's scope and were not touched.

## References

- Plan: `specs/424_harden_four_tier_conflict_case1_releaser_race/plans/01_harden-case1-releaser-race.md`
- Report: `specs/424_harden_four_tier_conflict_case1_releaser_race/reports/01_harden-case1-releaser-race.md`
- Progress: `specs/424_harden_four_tier_conflict_case1_releaser_race/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/424_harden_four_tier_conflict_case1_releaser_race/handoffs/`
