# Implementation Summary: Task #451

- **Task**: 451 - Take the Lean Challenge snapshot in the plan phase, where it is still meaningful, instead of leaving it to an implement phase the status gate correctly refuses
- **Status**: [COMPLETED]
- **Started**: 2026-11-22T00:00:00Z
- **Completed**: 2026-11-22T04:10:00Z
- **Effort**: ~4 hours
- **Dependencies**: None blocking (385, 420, 435 archived; 462 is a precondition on `--check` promotion only, which this plan declines)
- **Artifacts**: plans/01_challenge-snapshot-observer-wiring.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Gave the Lean Challenge snapshot a real producing call site at the one moment the exit-73 status
gate still admits it (plan-cycle resting status `planned`), and gave `--check` its first-ever
consuming call site on the implement side, both from a single new post-task observer registered
in the lean extension's manifest. All five plan phases landed: the observer and its regression
suite, its manifest registration, end-to-end deployment and firing verification, the design
record and rule updates (plus two comment-only corrections to now-false header claims), and the
derived-index reconciliation.

## What Changed

- `agent-system/extensions/lean/scripts/lean-challenge-observe.sh` — Created. The post-task
  observer: dispatches on its sixth positional argument (`resting_status`) alone, producing a
  snapshot (no `--force`) at `planned`, running `--check` at `implementing`/`partial`/`pr_ready`/
  `completed`, and no-op otherwise. Always exits 0 in live mode.
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-observe.sh` — Created.
  22 direct-invocation cases (status dispatch, `--force` absence, non-blocking on a missing/
  non-executable/failing stub, `project_root` pin) plus 7 end-to-end cases added in Phase 3
  (resolution, inertness, non-blocking against a real hanging/nonzero fixture observer, CWD
  pin) via `run-task-observers.sh`.
- `agent-system/extensions/lean/manifest.json` — Added the `observers.lean-challenge-observe`
  block (`task_type: lean4`, `timeout_seconds: 120`, no `topic`) and two derived
  `provides.scripts` entries via `sync-manifest-scripts.sh --write`.
- `agent-system/extensions/lean/README.md` — Added an `## Observer` section (required by
  `check-extension-docs.sh` Rule X's documentation check; not an explicit plan bullet).
- `agent-system/extensions/lean/scripts/tests/test-lean-challenge-snapshot.sh` — Extended with
  6 new cases: `PRE_IMPLEMENTATION_STATUSES` literal pin, re-plan refusal (byte-identical + mtime
  unchanged), re-plan with `--force` (overwrite, no INCIDENT text since status stays `planned`),
  and the `--check` 71→0 acceptance pin.
- `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md` — Added a
  `## Producing and Consuming Call Sites` section (registration rationale, re-plan ruling,
  `timeout_seconds: 120` reasoning, `project_root` and `/orchestrate`-only limitations, the
  commit-volume side effect); widened the exit-71 table row; amended `## Gate Strength: Advisory
  Only` with the declined-promotion ruling.
- `agent-system/extensions/lean/rules/plan-compliance.md` — Amended the `ADVISORY ONLY`
  paragraph to note the new `--check` call site while retaining the advisory verdict.
- `agent-system/extensions/lean/scripts/lean-challenge-snapshot.sh` — Comment-only: corrected
  the now-false "not itself deployed" and "standalone CLI, not wired into any completion gate"
  claims. No executable line touched; `PRE_IMPLEMENTATION_STATUSES` and the status gate are
  byte-identical to before.
- `agent-system/extensions/lean/index-entries.json` — Reconciled `line_count` for
  `challenge-snapshot.md` (221 → 298) via `generate-context-line-counts.sh --write`.

## Decisions

- Registration site: a post-task **observer**, not a `postflight` lifecycle hook or a core call
  (the plan's own superseding decision over the research report, re-confirmed during
  implementation with no change).
- Re-plan ruling: REFUSE, inherited from the existing exit-73 manifest-exists refusal — no new
  idempotence logic added.
- `--check` promotion: DECLINED, verdict stays advisory (462's unlanded false-ambiguity defect,
  plus "evidence from real runs" not yet available).
- `project_root` defaults to `.`; the observer relies on its inherited working directory being
  the repo root, per the plan's single-repo assumption.

## Plan Deviations

- Phase 2 gained one addition beyond its explicit task list: a `## Observer` section in
  `agent-system/extensions/lean/README.md`, required by `check-extension-docs.sh` Rule X
  (`check_observers_documented`), which `fail()`s on a declared observer with no README mention.
  Recorded in the Phase 2 progress file's `deviations` array.
- Phase 3's M5 test case was corrected mid-implementation: `--force` overwriting an existing
  manifest while status is still `planned` does **not** print the loud INCIDENT warning — that
  text is tied exclusively to bypassing the STATUS gate (a different exit-73 site). The test and
  the design record both state this precisely rather than the plan's more general "warns"
  phrasing. Recorded as an `approaches_tried` entry in the Phase 3 progress file and reflected in
  the Testing & Validation checklist annotation.

## Verification

- Build: N/A (shell scripts, markdown, JSON)
- Tests: Passed — `test-lean-challenge-observe.sh` (29/29), `test-lean-challenge-snapshot.sh`
  (41/41), both against the freshly-deployed content.
- Files verified: Yes — `test -x` on both new scripts, `git diff --stat` confirming each phase's
  diff was scoped to its own declared files, `check-extension-docs.sh` exit 0 (Rules Q/R/X clean
  for lean), `check-task-references.sh`/`check-record-versioning.sh` clean on every touched file.
- `verify-touched.sh` ran scoped to each phase's touched set per the dispatch's Batch Gate
  Deferral directive; the complete gate set is deferred to the orchestration close. Two
  concurrent-sibling-load timing flakes (`test-gate-cache-equivalence.sh`,
  `test-verify-deploy-gate-selection.sh` case q) were observed in batch runs and confirmed
  non-reproducible when re-run in isolation — recorded via `issue-record.sh`, not treated as
  regressions.

## Impacts

- A lean4 task whose plan carries a populated `## Lean Challenge Statements` section now gets a
  Challenge manifest under `specs/{NNN}_{SLUG}/challenge/manifest.json` automatically at plan
  time, without any phase body needing to ask for it.
- `--check` has its first-ever real call site; the implement-side drift verdict is now
  obtainable for every qualifying lean4 task going forward, where previously it was never
  reachable in practice.
- Every qualifying lean4 plan cycle now commits a Challenge into the target Lean project's own
  git history automatically — an intentional structural side effect of the immutability
  mechanism, documented in the design record.

## Follow-ups

- The core `postflight` lifecycle-hook `TASK_TYPE` gap (real, generic, affects every extension)
  was identified but deliberately not fixed here — it belongs to its own record.
- `--check` promotion to a blocking gate remains declined pending 462's false-ambiguity fix and
  accumulated real-run evidence from this seam's new call site.
- The observer's reach is `/orchestrate`-only; a lean4 plan produced by `/revise` or any other
  standalone dispatch gets no snapshot from this seam — recorded as a stated limitation.

## References

- Plan: `specs/451_snapshot_lean_challenge_at_plan_time/plans/01_challenge-snapshot-observer-wiring.md`
- Research report: `specs/451_snapshot_lean_challenge_at_plan_time/reports/01_hook-registration-and-postflight-bridging.md`
- Design record: `agent-system/extensions/lean/context/project/lean4/domain/challenge-snapshot.md`
