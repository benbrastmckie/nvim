# Implementation Summary: Task #148

- **Task**: 148 - Port hard-mode counters, loop guard and auxiliary dispatches into the batch engine as per-dispatch options
- **Status**: [COMPLETED]
- **Started**: 2026-09-04
- **Completed**: 2026-09-07
- **Effort**: ~13.5 hours (8 phases across multiple dispatches)
- **Dependencies**: 143 (`orchestrate-cycle-postflight.sh`) — completed
- **Artifacts**: plans/01_port-single-task-features.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Stage A.5 of `specs/PATH.md` ("One engine, batch of one"): every capability that existed only in
`skill-orchestrate/SKILL.md`'s single-task Stages 1-8 now also exists as a script or a per-dispatch
option in the batch engine (`orchestrate-cycle-plan.sh` / `orchestrate-cycle-postflight.sh`), the
precondition for a successor task to delete the single-task engine outright. Team fan-out (item 1)
was withdrawn by dispatch addendum before implementation began (team mode was already deleted by
a predecessor task); hard-mode churn/three-strikes/burnout counters (item 2), the per-task
cumulative cycle budget (item 3), and the four auxiliary-dispatch kinds — drift-inspection,
blocker-research, plan-revision, divergence-audit (item 4) — were all ported in full, and a single
task number can now be routed through the batch engine behind an opt-in, temporary flag (item 5).
`SKILL.md`'s single-task Stages 1-8 remain on disk, untouched, and remain the DEFAULT path for a
single task number — this task never made them unreachable; it only built the batch-engine
equivalent alongside them, satisfying the successor deletion task's precondition.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — per-task cumulative cycle
  budget (`cycle_counts`/`max_cycles_per_task` maps, durable backing via
  `orchestrate-loop-guard-init.sh`, `--continue-budget` reset); the H1 hard-mode per-phase-dispatch
  heading-scan/conformance-gate/marker-crosscheck/territory machinery; the `aux_dispatch[]`
  emission (decision + build, now placed at the genuine top of the cycle — see Plan Deviations).
- `agent-system/extensions/core/scripts/orchestrate-churn.sh` — new. Task-directory-scoped
  churn/three-strikes detection (returns an audit REQUEST, never dispatches) and a
  `--burnout-signal` mode.
- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` — new. Writes
  `specs/{NNN}_{slug}/.dispatch/{seq}-aux-{kind}.md` for the four fixed-agent aux kinds; never
  touches memory retrieval, the `--lit` briefing, or `command-route-agent.sh`; resolves `model`
  from the agent's own frontmatter.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — `--hard` flag, calls
  `orchestrate-churn.sh`, persists `aux_pending[task]` (divergence-audit / drift-inspection /
  blocker-research signals) to the resolved state store.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — `--phase-number N`
  ("## Phase Mission" section) for H1's per-phase hard-mode dispatch.
- `agent-system/extensions/core/scripts/orchestrate-loop-guard-init.sh` — extended into a
  read/seed/flush helper for the durable per-task cycle-budget counter.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Stage MT-4 gains a second,
  adjacent `aux_dispatch[]` composition loop (`orchestrator_mode: false`, no `handoff_path`); a
  new "MT-3-hard" burnout circuit-breaker self-check calling `orchestrate-churn.sh
  --burnout-signal`; `--hard` threaded into the MT-4 postflight call (previously missing entirely).
- `agent-system/extensions/core/commands/orchestrate.md` — STAGE 0 gated on `ORCHESTRATE_BATCH_OF_ONE`
  (env var, experimental/temporary) to route a single task number through the multi-task dispatch
  block unchanged; two stale "accepted-and-ignored" notices for `--research`/`--plan`/`--implement`
  corrected (they are honored per-task via `force_phases_remaining`, and have been since before
  this task — the notices had simply never been updated).
- `agent-system/extensions/core/docs/architecture/orchestrate-cycle-postflight.md` and
  `orchestrate-state-machine.md` — WORK-list / aux-row / MT-3-hard documentation.
- `agent-system/extensions/core/manifest.json` — registers the two new scripts and their tests.
- Five test suites extended (`test-orchestrate-cycle-plan.sh`: 59 -> 77 cases across Groups 8/9/10;
  `test-orchestrate-build-dispatch.sh`; `test-orchestrate-cycle-postflight.sh`;
  `test-loop-guard-budget-override.sh`: a new direct-engine TARGET 2 section, 41 cases;
  `test-loop-guard-staleness.sh`: scope note only, detector not ported) and two new suites created
  (`test-orchestrate-churn.sh`, `test-orchestrate-build-aux-dispatch.sh`: 18 cases).
- `specs/state.json` — this task's own `file_scope` widened (via `+=`) to the full set of files
  Phases 6-7 actually touched, per the plan's own declared-widening note.

## Decisions

- **Decision 1** (Phase 1): the batch-wide `default_max_cycles` scalar is retired; a per-task
  `cycle_counts`/`max_cycles_per_task` map pair replaces it, durably backed by the pre-existing
  `${TASK_DIR}/.orchestrator-loop-guard` file — preserving the cumulative-across-invocations
  guarantee `test-session-runtime-files.sh` Case 3 already protects for the single-task engine.
- **Decision 2** (Phase 5): `aux_dispatch[]` is a sibling array to `dispatch[]`, never widening its
  `phase` vocabulary. Agents are fixed by kind (`fork`, `fork`, `reviser-agent`, the task's own
  stored `research_agents[t]`), never task-type-routed. Aux rows never reach
  `orchestrate-cycle-postflight.sh` and never contribute to `failed_tasks`.
- **Decision 3** (Phase 2): `orchestrate-churn.sh` requests an audit; it never dispatches one
  itself (no script in this codebase invokes the Agent tool).
- **Decision 4** (Phase 4): H1's two single-task refusal paths (`EXIT (partial)`) become per-task
  `blocked[]` rows in the batch engine, carrying the same reason text verbatim.

## Plan Deviations

- **Phase 5 / Phase 8**: a genuine placement bug was found and fixed during Phase 8's live
  acceptance runs (not by any of the 77+18 test cases written in Phases 5-7, none of which
  happened to construct a fixture where the aux-emitting task was ALSO terminal-for-this-cycle).
  `orchestrate-cycle-plan.sh`'s AUX DECISION section correctly computed which aux kind to emit
  before the all-terminal check, but the actual row-BUILDING step (both `--dry-run` rendering and
  the live build) was placed much later, reachable only through the normal dispatch/live fork —
  which every early-exit path (`all_terminal`, `no_eligible_stuck`, `convergence_guard`,
  `max_cycles`) bypasses via its own `emit_and_exit` call. Since a `blocked` verdict from
  `orchestrate-cycle-postflight.sh` both records a `blocker-research` aux signal AND charges the
  task to `failed_tasks` in the SAME cycle, the very escalation a stuck task needs was silently
  dropped the instant the batch had nothing else to do. Fixed by moving row-building to run
  immediately after the AUX DECISION section, genuinely before every early-exit check. Re-verified
  live (Acceptance C now correctly chains blocker-research -> plan-revision across an all-terminal
  cycle) and covered by a new dedicated regression case (`test-orchestrate-cycle-plan.sh` Group 10
  Case I).
- No other deviations; all eight phases completed as planned.

## Verification

- Build: N/A (bash/markdown, no compiled artifacts)
- Tests: `scripts/tests/run-all.sh` 70/70 passed on the settled run (two earlier runs each showed
  a single different, non-reproducible timing-sensitive failure — `test-four-tier-conflict.sh`
  Case 6 and `test-lint-scoped-commit-boundary.sh`/`test-state-write-concurrency.sh` on separate
  occasions — each confirmed pre-existing and unrelated via `git status` showing zero local
  modifications to the failing file, plus 3 clean isolated re-runs)
- `scripts/check-task-references.sh`: PASS, 0 unexempted occurrences
- `scripts/verify-deploy.sh`: 1 finding, confirmed attributable to a DIFFERENT, concurrently
  running task (`specs/153_lean_comparator_clean_room_runner/`) whose own uncommitted
  `agent-system/extensions/lean/scripts/lean-comparator-run.sh` modification is outside this
  task's `file_scope` and was never touched by this task (verified via `git status`) — an
  observation-duty item, not a regression from this work
- Files verified: Yes (all new scripts executable, all new tests green in isolation and in the
  full suite)
- Live acceptance runs (real fixture, real deployed scripts, no test-harness stubs):
  - **Acceptance A** (hard-mode churn): 4 chained `orchestrate-cycle-postflight.sh --hard`
    invocations against one blocker target produced `aux_signal: {"kind":"divergence-audit",...}`
    on the 4th (three-strikes); the following `orchestrate-cycle-plan.sh --hard` invocation
    emitted the `divergence-audit` `aux_dispatch[]` row (`agent: general-research-agent`,
    a real dispatch file written and quoted in Phase 8's own progress notes).
  - **Acceptance B** (budget exhaustion): a fixture at `cycle_count=13` (hard-mode `max_cycles`)
    stopped with `reason: max_cycles` and the honest message; the SAME task with
    `--continue-budget` dispatched, reset `cycle_count` to 0 then charged it to 1, and preserved
    `dispatch_seq_counter`/`detected_defects` across the reset.
  - **Acceptance C** (blocker escalation): a `blocked`-verdict postflight run recorded a
    `blocker-research` aux signal; the following cycle-plan run emitted the
    `blocker-research` `aux_dispatch[]` row DESPITE the batch's own `all_terminal` stop (the exact
    scenario the Phase 8 bugfix above addresses); after simulating the fork's own
    `.blocker-research.json` output, the NEXT cycle-plan run correctly chained it into a
    `plan-revision` row (`agent: reviser-agent`) and consumed the marker file.
- PATH.md capability-table row-by-row (Stage A.5's own scope, `specs/PATH.md` lines 138-147 and
  237): phase forcing, hard-mode contract injection, hard-mode churn/burnout, the loop
  guard/cycle budget, and `--dry-run` all have confirmed live homes in the batch engine; handoff
  staleness/`dispatch_seq` gates were already done by task 143; "research phase on demand" is
  explicitly out of scope (a future task, 150); team fan-out is confirmed withdrawn (no
  `orchestrate-team-fanout.sh`, no `team` field anywhere, grep-verified).

## Impacts

- `/orchestrate N` (a single task number) can now optionally run through the SAME MT-1..MT-5
  batch-engine stages as a multi-task invocation, behind `ORCHESTRATE_BATCH_OF_ONE` — but this is
  NOT the default; `SKILL.md`'s single-task Stages 1-8 remain the default, unconditional path for
  a lone task number.
- The successor task (deleting the single-task engine, `specs/PATH.md` Stage A.6) can now proceed:
  every capability Stages 1-8 provide has a live batch-engine equivalent, verified live.
- Temporary duplication between the two engines is expected and accepted for the flag's lifetime,
  per this task's own Non-Goals.

## Follow-ups

- The successor task (Stage A.6) should delete `SKILL.md`'s single-task Stages 1-8,
  `ORCHESTRATE_BATCH_OF_ONE`'s gating in `commands/orchestrate.md` (making the batch path
  unconditional for every task count), and the now-redundant `SKILL.md`-extracted sentinel-region
  cases in `test-loop-guard-budget-override.sh` (TARGET 2 in that file becomes the sole target).
- The hard-only `loop-guard-staleness` detector (`plan_version`/mtime drift) was never in this
  task's scope and has no batch-engine equivalent; a future task should decide whether to port it
  or retire it, per this task's own Non-Goals.
- An unrelated `verify-deploy.sh` finding (the `lean` extension's `lean-comparator-run.sh` not
  registered in `provides.scripts`) was observed during this task's own gate runs, attributable to
  a different, concurrently in-flight task (`specs/153_lean_comparator_clean_room_runner/`) — flagged
  here for visibility, not actioned (out of this task's scope and ownership).

## References

- Plan: `specs/148_port_single_task_features_to_batch_engine/plans/01_port-single-task-features.md`
- Research: `specs/148_port_single_task_features_to_batch_engine/reports/01_port-single-task-features.md`
- Progress files: `specs/148_port_single_task_features_to_batch_engine/progress/phase-{1..8}-progress.json`
- Handoffs: `specs/148_port_single_task_features_to_batch_engine/handoffs/phase-{4,5,7}-handoff-*.md`
- Reference doc: `specs/PATH.md`, "One engine, batch of one"
- Commits: `928e78d63` (Phase 1), `d38f7fef8` (Phase 2), `e9c845a82` (Phase 3), `e7d68329a`
  (Phase 4), `f15964004` (Phase 5), `3f640ab2b` (Phase 6), `5b9b2e507` (Phase 7), plus this
  summary's own Phase 8 commit
