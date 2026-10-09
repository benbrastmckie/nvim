# Implementation Summary: Task #311

- **Task**: 311 - Measured co-scheduling signal and isolation posture (two folded parts)
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T23:00:07Z
- **Completed**: 2026-10-09T00:49:57Z
- **Effort**: ~1.9 hours
- **Dependencies**: None
- **Artifacts**: plans/01_measured-build-weight-isolation-posture.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Part 1 replaced the build-heavy co-scheduling admission rule's static `task_type` family
membership test with a measured wall-clock signal read from each candidate's own
`metrics.jsonl`, so a measured-light `lean4`/`cslib` implement candidate is no longer
categorically refused co-scheduling alongside a genuinely heavy build. Part 2 appended two
later-observed hazard classes and a CoW/reflink/overlayfs/clone-nothing evaluation to
`batch-orchestration-guardrails.md`'s isolation posture section. All six plan phases completed;
Phase 6 closed `[COMPLETED WITH EXCLUSIONS]` for two gate failures traced to a pre-existing,
unrelated, independently-corroborated defect outside this task's scope.

## What Changed

- `agent-system/extensions/core/scripts/lib/task-classification-lib.sh` — renamed
  `BUILD_HEAVY_TASK_TYPES` to `BUILD_HEAVY_CANDIDATE_TASK_TYPES` (demoted to a candidacy
  pre-filter), added `BUILD_HEAVY_WALL_CLOCK_THRESHOLD_SECONDS`/`BUILD_HEAVY_MIN_SAMPLES`
  env-overridable constants, added `build_heavy_measure_signal()` (max-aggregated,
  min-sample-gated, malformed-line-tolerant, omission-not-zeroing-safe), and rewrote
  `task_is_build_heavy_implement()` as a three-rung ladder with a conservative
  default-to-heavy fallback for any unmeasured candidate.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — hoisted the
  `task_lookup_dir`-based task-directory resolution to serve both the forced-implement-plan
  gate and the build-heavy check; passed the resolved directory as the predicate's third
  argument; surfaced the admitted candidate's own signal basis in the `deferred[]` reason
  (captured at admission time into a new `build_heavy_implement_admitted_basis` variable, since
  the shared `BUILD_HEAVY_SIGNAL_BASIS` global is overwritten by each subsequent evaluation);
  updated the script header's Mode 2 narrative.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — added a
  `write_g32_metrics` fixture helper and Group 32 cases (v)-(xii), extending the pre-existing 4
  cases to 12: the headline two-measured-light-candidates co-schedule case, the min-samples
  guard, the max-not-mean proof, omission-not-zeroing, the candidacy pre-filter proof,
  malformed-line tolerance, basis observability, and explicit regression safety.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — added
  `### Two Later-Observed Hazard Classes` (repo-scanning pollution from in-tree worktree
  provisioning; mode 2's guard-bypass-via-bare-invocation recurrence) and
  `### CoW / Reflink / Overlayfs / Clone-Nothing Evaluation`; added the reaffirmation decision
  record's exact filename to "Related Documents"; restated the Mode 2 principle for the
  measured signal; replaced a stale "stated intent, not implemented" hedge with the implemented
  fact; corrected the critical-path entry count (13 -> 16).
- `agent-system/extensions/core/index-entries.json` — refreshed the `line_count` entry for
  `batch-orchestration-guardrails.md` twice (once per content-growing phase), isolated to a
  single hunk each time via a safe single-hunk-staging technique to avoid sweeping in a
  concurrent sibling task's own uncommitted edits to the same shared ledger file.

## Decisions

- The basis shown in a build-heavy defer's reason is the ALREADY-ADMITTED candidate's own
  signal basis, captured at admission time, not a direct read of the shared global at defer
  time (which would show the wrong candidate's basis).
- Case (vii)'s fixture uses 3 `metrics.jsonl` entries (not the plan's suggested 2) for clean
  margin on both sides of the 900s threshold while still satisfying the 2-sample floor.
- Added `-r` to the `build_heavy_measure_signal()` `jq -R -s` invocation (the plan's literal
  text omitted it); without it, the piped string stays JSON-quoted and corrupts the subsequent
  `awk` field split into count/max — caught by direct functional testing across all fixture
  directions before any test-suite coverage was written.

## Plan Deviations

- **Task 1.4** (`build_heavy_measure_signal` jq invocation) altered: added `-r` for correctness.
- **Task 3.3/3.4** (predicate call-site variable naming; deferred-reason basis source) altered:
  reused the hoisted `_p5_task_dir_abs` name rather than a new `_task_dir_abs`; the deferred
  reason's basis is the admitted candidate's own basis, captured at admission time.
- **Task 4 case (vii)** altered: 3 fixture entries instead of 2, for threshold margin.
- **Task 6.4/6.5** (full gate set and full test corpus) altered: closed with 2 reasoned
  exclusions (Gates 8 and 13) plus 4 pre-existing skips, all traced to one pre-existing,
  unrelated cause (a `detect-noop-bash.sh` runtime-file naming gap in
  `deploy-orphan-detection.md`'s exclusion list) and one unrelated prior exec-bit regression,
  neither caused by this task. See the plan's Phase 6 `#### Reasoned Exclusions` table for the
  full evidence record.

## Verification

- Build: N/A (meta task, no build step)
- Tests: Passed, with 2 reasoned exclusions and 4 pre-existing skips (see Plan Deviations above)
  — `bash .claude/scripts/verify-deploy.sh` (33/35 checks green) and
  `bash agent-system/extensions/core/scripts/tests/run-all.sh` (123 passed, 1 failed for the
  excluded cause, 4 skipped for the unrelated exec-bit regression)
- Files verified: Yes — all five touched source-store files confirmed matching their deployed
  counterparts (`index-entries.json` verified via its merged destination,
  `.claude/context/index.json`)

## Impacts

- Two measured-light `lean4`/`cslib` implement candidates can now co-schedule in the same
  `/orchestrate` cycle, where the prior static family-list rule categorically refused this —
  the binding constraint the dispatch description named as the primary motivation.
- Every unmeasured candidate (no task directory, no `metrics.jsonl`, or fewer than
  `BUILD_HEAVY_MIN_SAMPLES` usable entries) retains today's exact conservative behavior,
  byte-for-byte — this change is strictly a relaxation applied only where evidence exists.
- `batch-orchestration-guardrails.md`'s isolation posture record is now complete with the two
  later-observed hazard classes and the CoW/reflink/overlayfs/clone-nothing evaluation,
  cross-referenced to the reaffirmation decision record, so a future re-opening of the
  worktree-isolation question starts from a complete evidence base.

## Follow-ups

- A small, dedicated follow-up should add `tmp/noop-bash-shapes-*` to
  `deploy-orphan-detection.md`'s Runtime Artifact exclusion class (alongside the existing
  `tmp/noop-bash-count-*` entry), which is currently causing Gates 8 and 13 to fail in any
  busy, multi-session repository state — confirmed independently by this task and by a
  concurrently-dispatched sibling task in the same cycle.
- A separate follow-up should restore the executable bit on `test-dispatch-metrics.sh`,
  `test-lint-agent-contracts-heartbeat.sh`, `test-script-inventory.sh`, and
  `test-task-lock-liveness.sh`, which are currently silently skipped by `run-all.sh`.
- Not pursued, per the dispatch's own explicit non-goals: restoring per-dispatch `git worktree`
  isolation (reaffirmed removed), and a Lake/Mathlib shared-cache feasibility spike (named as a
  possible future spike, not requested here).

## References

- Plan: `specs/311_measured_co_scheduling_signal_and_isolation_posture/plans/01_measured-build-weight-isolation-posture.md`
- Research report: `specs/311_measured_co_scheduling_signal_and_isolation_posture/reports/01_co-scheduling-signal-isolation-posture.md`
- Evidence base: `specs/archive/301_reopen_worktree_isolation_verdict/reports/02_worktree-isolation-reopened.md`,
  `specs/decisions/worktree-isolation-removal-reaffirmation.md`
