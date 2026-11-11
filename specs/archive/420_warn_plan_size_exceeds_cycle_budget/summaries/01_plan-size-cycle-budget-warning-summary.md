# Implementation Summary: Task #420

- **Task**: 420 - Surface a plan-size versus per-run cycle-budget mismatch at plan time or at admission
- **Status**: [COMPLETED]
- **Started**: 2026-11-07T15:00:00Z
- **Completed**: 2026-11-09T20:45:00Z
- **Effort**: 6 hours
- **Dependencies**: None (sequenced after a concurrent file-territory task, not a blocking edge)
- **Artifacts**: plans/01_plan-size-cycle-budget-warning.md, reports/01_plan-size-cycle-budget-warning.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`orchestrate-cycle-plan.sh` previously held the per-run shared cycle budget without ever reading
a task's plan size, so an operator learned a plan would not finish in one invocation only by
exhausting the budget. This implementation adds a purely additive, advisory
`cycle_budget_advisory` object to the per-task dispatch row at admission time: computed from the
plan file's own `### Phase N:` headings against the shared batch cycle pool
(`batch_cycle_budget - sum(cycle_counts)`), with a mode-aware threshold
(`remaining_phases > remaining_cycles * K`, `K=2` base / `K=1` hard) drawn from the research
report's measured phases-per-cycle distribution. The notice is paired with a human-readable
stderr line and never alters dispatch/deferred/blocked/stop, any status, or any exit code.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — unconditional
  `phase-heading-patterns.sh` sourcing; a new sibling computation block (after the
  `probed_dispatch_post_h1` build loop, before the dry-run fork) that resolves each
  implement-phase candidate's latest plan file, scans phase headings (skipping on a
  non-conforming scan or a zero/absent phase count), computes remaining phases vs. remaining
  shared-pool cycles, applies the mode-aware threshold, and on a fire both emits a
  `[orchestrate]`-prefixed stderr line and populates an advisory record; the additive
  `cycle_budget_advisory` fragment merged onto both dispatch-row construction sites (dry-run and
  live), present only when the threshold fires.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new Group 36
  fixture set: the originating 11-phase/phase-0/5-cycle-budget shape; a comfortably-within-budget
  non-fire case; no-plan and zero/non-conforming-heading non-fire cases; a mode-aware case where
  base fires and `--hard` does not for the same plan; the phase-10-of-11 real-history
  counter-case; and a byte-identical-dispatch non-interference diff (with the advisory field
  stripped from both sides, including `.stop`/`.blocked`).
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — new advisory
  subsection in `## MAX_CYCLES Enforcement` stating both operands, the threshold with its
  measured sample size, the heuristic-not-impossibility framing, and the two sanctioned remedies;
  explicit shared-pool framing added to the surrounding prose.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — one new
  ADVISORY row in the Classification Table, confined to the admission-layer material per this
  task's sequencing note.
- The deployed `.claude/` tree, regenerated via `deploy-headless.sh` and confirmed
  byte-identical to the source store for `orchestrate-cycle-plan.sh`.

## Decisions

- Both threshold operands (`phases_total`, `phases_done`) are derived from the plan file's own
  phase headings, never the handoff's `phases_completed` — the plan file is the only source that
  exists before a task's first dispatch and is already the authoritative signal the other three
  phase-accounting consumers use.
- An inconclusive (non-conforming) heading scan suppresses the advisory entirely rather than
  acquiring any blocking posture; that response stays H1's, and only in hard mode.
- The stderr line re-emits on every cycle the condition holds rather than deduplicating, since
  the remaining-budget operand shrinks monotonically and the `--dry-run` path (the overwhelming
  majority of the test suite's invocations) never persists a dedup flag.
- Only implement-phase candidates receive an advisory; research/plan candidates have no plan
  size to measure yet.

## Plan Deviations

- **Task 5.3 / Testing & Validation's final item**: altered. This dispatch carried a Batch Gate
  Deferral directive overriding Phase 5's own full-gate-set task for this one dispatch: the
  complete gate set was deferred to the once-per-invocation batch stage rather than independently
  run here. Discharged instead against a scoped narrowing invocation — `run-all.sh --only`
  covering the union of suites named across Phases 1-4's own Tier Justifications, plus the
  gate-3/gate-4 doc-lint and task-reference checks run directly — which found this task's own
  changed surface (`orchestrate-cycle-plan.sh`, its test file, both edited docs) fully green.

## Verification

- Build: N/A (shell script)
- Tests: `test-orchestrate-cycle-plan.sh` 398 passed, 0 failed (including the new Group 36),
  run standalone against the deployed tree.
- Files verified: Yes — deployed `orchestrate-cycle-plan.sh` is byte-identical to its source-store
  copy; `git status --porcelain -- .claude/` is empty.
- Scoped gate run (`run-all.sh --only <26-suite union>`): 20 passed, 7 failed. All 7 failures were
  investigated and traced to a cause entirely outside this task's own changes (see Impacts).
- `check-extension-docs.sh --quiet` (gate 3) and `check-task-references.sh --quiet` (gate 4): both
  run standalone; task-reference lint passed with 0 occurrences; doc-lint's one finding is the
  same cross-task cause described in Impacts.

## Impacts

- Operators running `/orchestrate` on a plan whose remaining phase count materially exceeds what
  the remaining per-run cycle budget can plausibly absorb now see the mismatch at admission,
  before dispatching, rather than discovering it only when the budget trips mid-run.
- During Phase 5's scoped verification, 7 test suites unrelated to this task's own file_scope
  (`test-deploy-baseline-lib.sh`, `test-lint-deploy-caller-wrap.sh`,
  `test-orchestrate-cycle-postflight.sh`, `test-orchestrate-predispatch-review.sh`,
  `test-orchestrate-unwind-dispatch.sh`, `test-postflight-deploy-gate.sh`,
  `test-redeploy-checkpoint-promotion.sh`) were found failing. Root cause, confirmed by manual
  reproduction: `state-write.sh` now sources `lib/project-number-inuse.sh` (added by a separate,
  already-committed task), but each of these suites' own isolated fixture-repo builders carries a
  `REQUIRED_LIBS`/`REQUIRED_SCRIPTS` array that predates that addition and never copies the new
  dependency into its fixture tree, so every `update-task-status.sh` invocation inside the
  fixture dies with "No such file or directory" instead of its expected exit code. This is a
  pre-existing, independently-reproducing cross-task regression — none of the 7 suites'
  `[SUBJECT]` files is anything this task edited — and was not fixed forward here (it would mean
  editing seven other tasks' test fixtures on a heavily concurrent working tree). Recorded via
  `issue-record.sh` (class: cross-task regression surfaced during verification, severity costly).
- Separately, the deploy's own internal fast-gate check flagged `core: Content differs from
  source: scripts/state-write.sh` (gate 3 / the manifest-driven check) — traced to a concurrent
  sibling task's currently-uncommitted, in-progress edit to that same file. Not attributable to
  this task and not touched.
- Gate 4 and Gate 10 TIMEOUTs inside the concurrent fast-gate run were resource-contention
  artifacts of this environment's heavy concurrent load (multiple live Claude sessions,
  `uptime` load average ~8): both passed/failed consistently and well under their own timeout
  budgets when re-run standalone. Gate 10's standalone failure (`next_project_number` already in
  use) is a `specs/state.json` counter collision from concurrent task creation elsewhere in the
  system, not from this task.

## Follow-ups

- The 7-suite fixture-builder regression (missing `project-number-inuse.sh` in several tests'
  `REQUIRED_LIBS`/`REQUIRED_SCRIPTS` arrays) should be fixed by whichever task owns those test
  files; it was recorded as an issue rather than fixed here to respect file territory on this
  shared working tree.
- The `next_project_number` counter collision flagged by `validate-state.sh --deep` (Check 12)
  is a system-wide `specs/state.json` consistency issue caused by concurrent task creation,
  unrelated to this task; left for the state-management maintenance path to repair.

## References

- `specs/420_warn_plan_size_exceeds_cycle_budget/plans/01_plan-size-cycle-budget-warning.md`
- `specs/420_warn_plan_size_exceeds_cycle_budget/reports/01_plan-size-cycle-budget-warning.md`
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
