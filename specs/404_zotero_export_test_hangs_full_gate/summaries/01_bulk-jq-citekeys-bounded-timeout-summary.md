# Implementation Summary: Task #404

- **Task**: 404 - Fix test-zotero-generate-export.sh hanging indefinitely and breaking every full verify-deploy.sh run
- **Status**: [COMPLETED]
- **Started**: 2026-10-14T16:11:00Z
- **Completed**: 2026-10-15T23:55:00Z
- **Effort**: 4.25 hours (plan estimate; actual across all 4 phases including this verification phase)
- **Dependencies**: None
- **Artifacts**: plans/01_bulk-jq-citekeys-bounded-timeout.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`test-zotero-generate-export.sh` did not deadlock -- it ran an algorithmically quadratic
`synthesize_citekeys()` loop (two full-array `jq` subprocess spawns per item) that completed far
outside any applied timeout, so every caller observed an apparent hang. The fix rewrote that
function as a single bulk `jq` pass and gave the suite its own bounded wall-clock guard, closing
the repo-wide blocker that made the "verify-deploy.sh exits 0" final-phase criterion
unsatisfiable for every other task.

## What Changed

- `agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh` -- added a
  `citekey-synthesis` characterization scenario pinning current citekey output (Phase 1); added
  `EXPORT_TIMEOUT` (`${ZOTERO_EXPORT_TEST_TIMEOUT:-60}`), wrapped both generator invocation sites
  in `timeout`, added shared rc=124 loud-FAIL handling, and added a `timeout-guard-fires`
  scenario proving the bound fires against a deliberately stalled command (Phase 3).
- `agent-system/extensions/literature/scripts/zotero-generate-export.sh` -- rewrote
  `synthesize_citekeys()` from a per-item bash loop (two `jq` subprocess spawns per item, O(N)
  spawns x O(N) re-serialized JSON) into a single `reduce .[] as $item` bulk `jq` pass, with a
  loud stderr-diagnostic failure path replacing the prior silent per-item swallow (Phase 2).
- `specs/404_zotero_export_test_hangs_full_gate/plans/01_bulk-jq-citekeys-bounded-timeout.md` --
  checked off all 4 phases; Phase 4 closed `[COMPLETED WITH EXCLUSIONS]` with a Reasoned
  Exclusions record (see Plan Deviations below).

## Decisions

- Adopted Research Recommendation 3 option (b): the bound-fires proof drives a plain `sleep`
  through the same `timeout` wrapper the real invocation sites use, rather than adding a
  test-only stall hook to the production generator.
- The bulk-`jq` rewrite uses `reduce .[] as $item` (not `reduce range(0; length)`), carrying
  `{out, counts}` state -- equivalent and avoids a per-step re-index lookup.
- On a `jq` failure the new function emits nothing on stdout (never `[]`, which would be
  indistinguishable from a genuinely empty library) so the existing `FINAL_COUNT` shrink guard at
  the call site aborts loudly with no write.

## Plan Deviations

- **Phase 4, Tasks 2-3** altered: the plan's literal verification criteria ("run-all.sh exits 0",
  "verify-deploy.sh exits 0") were not met. Both commands terminated deterministically (the
  repo-wide blocker this task exists to fix) but exited non-zero: run-all.sh failed 4 of 144
  suites, and the full gate set failed 4 of 37 checks. Every one of the 4 gate failures is
  pre-existing and unrelated to this task's two-file scope -- see the plan's Phase 4 `#### Reasoned
  Exclusions` table for the full per-item reason/evidence record. Phase 4 was closed
  `[COMPLETED WITH EXCLUSIONS]` rather than `[PARTIAL]` because all five admission conditions in
  `context/standards/status-markers.md` hold: each failure is a deliberate, tightly-scoped,
  documented, evidenced exclusion, and none leaves residual work for this task.

## Verification

- Build: N/A (bash/jq scripts, no build step)
- Tests:
  - `timeout 600 bash agent-system/extensions/literature/scripts/tests/test-zotero-generate-export.sh`
    -- exit 0, 13 scenarios, 13 passed / 0 failed, wall time ~12s (vs. the 600s outer bound --
    roughly a 50x margin). `timeout-guard-fires` is among the PASSes.
  - `bash agent-system/extensions/core/scripts/tests/run-all.sh` (all suites) -- terminated in
    ~28m34s: 139 passed, 4 failed (pre-existing, unrelated -- see Plan Deviations), 1 skipped,
    144 total. `test-zotero-generate-export.sh` itself reported `[PASS]`.
  - `bash agent-system/extensions/core/scripts/verify-deploy.sh` (complete gate set, no
    `--skip-slow`, no `--only-gate`) -- terminated in ~23m50s: `FAIL -- 4 of 37 check(s) failed`.
    All 4 failures pre-existing and unrelated (3 named in this task's dispatch baseline; the 4th,
    a task-reference-lint self-match on its own doc's illustrative example text, confirmed
    pre-existing via `git log` on the flagged file).
  - Gate 5 (manifest-driven category parity + content-hash equality) reported PASS, confirming no
    source-store/deployed-`.claude/scripts/`-copy divergence for either edited file -- no deploy
    refresh was needed.
- Files verified: Yes

### Pre-fix vs. post-fix timings (carried from Phases 2-3, restated here for the record)

| Measurement | Pre-fix | Post-fix |
|---|---|---|
| `short-mid-page` scenario (2828 items) | ~121.7s (CARRIED-UNVERIFIED from research) | ~6.3s (measured Phase 2) |
| Standalone bulk-jq-only timing (2828 items) | n/a | ~0.27s (measured Phase 2) |
| Whole suite (13 scenarios) | unbounded / hung | ~12s, exit 0 |
| `EXPORT_TIMEOUT` bound | none (no per-suite timeout existed anywhere upstream) | 60s default, >1 order of magnitude above the measured post-fix cost |

## Impacts

- Every other task whose final implementation phase declares "verify-deploy.sh exits 0 -- the
  complete gate set" as a verification criterion can now reach a definite, non-hanging result
  from that gate again. A FAIL from one of the 4 pre-existing, unrelated issues is now a readable
  outcome instead of an indefinite wait.
- A future regression of this algorithmic-cost shape in `zotero-generate-export.sh` now fails
  loudly within `EXPORT_TIMEOUT` seconds instead of hanging a batch for minutes to tens of
  minutes.

## Follow-ups

- The 4 pre-existing gate failures surfaced during this phase's full verification remain open and
  are explicitly out of this task's scope: Gate 3 doc-lint (missing index.json entry, issue
  `iss_1792019093789_pEpEft`), the task-reference-lint self-match in
  `agent-system/extensions/core/context/standards/task-reference-exemptions.md:48` (newly
  observed this dispatch, not previously tracked -- recorded via `issue-record.sh` against this
  task's own `issues.jsonl`, `--suggested-channel follow_up_task`), the 4-suite run-all.sh
  failure set (issue `iss_1792019093909_Zk3nZO`), and the Gate 20 eager-load budget overage
  (issue `iss_1792015798103_u6yBQB`).

## References

- `specs/404_zotero_export_test_hangs_full_gate/plans/01_bulk-jq-citekeys-bounded-timeout.md`
- `specs/404_zotero_export_test_hangs_full_gate/reports/02_quadratic-citekey-synthesis-diagnosis.md`
- `specs/404_zotero_export_test_hangs_full_gate/reports/01_hang-localized-to-orchestrator-mode.md`
- `specs/404_zotero_export_test_hangs_full_gate/progress/phase-1-progress.json` through `phase-4-progress.json`
- `specs/404_zotero_export_test_hangs_full_gate/issues.jsonl`
