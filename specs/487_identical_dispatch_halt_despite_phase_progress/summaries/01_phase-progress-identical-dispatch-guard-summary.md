# Implementation Summary: Task #487

- **Task**: 487 - Stop the identical-dispatch convergence guard halting a task on cycle 2 even when cycle 1 closed a real plan phase
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T13:18:24Z
- **Completed**: 2026-11-10T13:56:58Z
- **Effort**: ~2.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_phase-progress-identical-dispatch-guard.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented an independent-signal streak freeze for the identical-dispatch convergence guard in
`orchestrate-cycle-plan.sh`, modelled directly on the existing `deploy_pending` freeze: a
per-task persisted plan-file completed-phase count now freezes the identical-dispatch streak
(rather than charging it as churn) whenever the dispatch hash matches the previous cycle's AND
that count strictly increased in between. This fixes the defect where an ordinary
(non-hard-mode) multi-phase `implement` dispatch, whose composed body carries no phase-progress
content at all, was misread as non-convergence the instant a real plan phase landed between two
cycles. Corrected `cycle_plan_dispatch_hash()`'s header to document the exception its own
assertion previously assumed away, and pinned both the non-halting and still-halting outcomes
with four new regression fixtures.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — added
  `last_dispatch_phases_completed //= {}` to the mt_state initializer chain; added an
  implement-scoped plan-file phase-progress signal (resolved via the same task-directory lookup
  the `deploy_pending` branch already performs) and a sibling freeze branch inside the Fix 2
  hash-match arm; persists the new count unconditionally whenever the signal is available;
  extended `cycle_plan_dispatch_hash()`'s header with the exception note and a third DECIDED
  AND RECORDED entry naming the new field as a persisted side-channel, never dispatch-body
  content.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — added Group 37
  (four arms: non-halt pin, still-halts companion, unavailable-signal degradation,
  seed-not-freeze) plus a `g37_write_two_phase_plan` fixture helper.
- Deployed `.claude/` tree regenerated via `deploy-headless.sh`; both edited files confirmed
  byte-identical between source store and deployed copies.

## Decisions

- The independent signal is the plan file's own `[COMPLETED]`/`[COMPLETED WITH EXCLUSIONS]`
  phase-heading count, never the handoff's self-reported `phases_completed` — the plan file is
  ground truth already committed by the time the next cycle composes.
- Implemented the independent-signal freeze alone, declining the research report's layered
  recommendation to also emit phase progress into the hashed dispatch body: doing so would make
  the freeze branch dead code in base mode (the body-divergence would fire on every cycle the
  freeze would otherwise fire) and would break an existing deliberate pin asserting the
  `implement` dispatch body is insensitive to plan-file content.
- Freeze, never suppress, re-arming every cycle: a hash match with advanced progress holds the
  persisted streak at its current value (never incrementing, never resetting to 1), and the new
  count is persisted unconditionally so the next comparison re-arms.
- A missing prior measurement seeds the field rather than freezing (first repeat is never
  forgiven for free); a non-conforming heading or unresolvable plan file makes the signal
  UNAVAILABLE, never zero (an unavailable signal must never read as an advance).
- Scoped the whole mechanism to `implement` dispatches only — research/plan phases have no
  plan-phase concept and their hash accounting is byte-for-byte unchanged.

## Plan Deviations

- Phase 3, task 2: cloned Group 27 Case C/D's lighter inline fixture shape instead of Group
  29's heavier `g29_write_task_fixture`/`g29_seed_state_and_mt` helpers, which simulate
  `deploy_pending`/reconcile machinery irrelevant to this signal.
- Phase 3, task 9: followed Group 27's single-candidate `"file_scope": []` precedent instead of
  giving each candidate a distinct non-empty scope, since each arm dispatches exactly one
  candidate per cycle (the absent-scope defer this guards against needs 2+ concurrent
  candidates to fire at all).
- Arm A's fixture used `[NOT STARTED]` rather than the plan's suggested `[IN PROGRESS]` for
  Phase 2 — both are OPEN, neither is DONE, behaviorally identical for this signal.

## Verification

- Build: N/A (shell scripts; `bash -n` passed on both edited files at every phase)
- Tests: `test-orchestrate-cycle-plan.sh` passed 420/420 (every existing group plus the new
  Group 37). The measured `--only` suite selections (25-suite union across both touched files)
  showed 20/25 passing, with the other 5 failures confirmed pre-existing and unrelated by
  reproducing them identically against the unmodified pre-phase file content. `shellcheck`
  showed only pre-existing finding instances (same already-accepted idiom, no new finding
  class). `verify-deploy.sh --only-gate 4,5,22` (task-reference lint, content-hash parity/drift,
  shellcheck lint — the Batch Gate Deferral directive's scoped narrowing for this plan's final
  phase): gates 4 and 5 passed; gate 22 reduced to the same 3 pre-existing, unrelated findings.
  The complete, unscoped gate set is deferred to the batch-level stage per that directive and
  runs once for the whole invocation.
- Files verified: Yes (deployed tree confirmed byte-identical to source store for both edited
  files)

## Impacts

- Every `/orchestrate N` invocation over a multi-phase, non-hard-mode `implement` plan can now
  make genuine multi-cycle progress within one run instead of being capped at one phase of
  progress by a false non-convergence halt.
- The guard still fires correctly for genuine non-convergence (a cycle that closes nothing still
  halts after a second identical dispatch), and the `deploy_pending` freeze, the
  hash-degradation posture, and both pre-existing DECIDED AND RECORDED strip-pattern rulings are
  unchanged.

## Follow-ups

- None.

## References

- Plan: `specs/487_identical_dispatch_halt_despite_phase_progress/plans/01_phase-progress-identical-dispatch-guard.md`
- Research: `specs/487_identical_dispatch_halt_despite_phase_progress/reports/01_phase-progress-identical-dispatch-guard.md`
- Phase handoffs: `specs/487_identical_dispatch_halt_despite_phase_progress/handoffs/`
