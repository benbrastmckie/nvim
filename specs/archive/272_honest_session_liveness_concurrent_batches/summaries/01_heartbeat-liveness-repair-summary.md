# Implementation Summary: Task #272

- **Task**: 272 - Honest session liveness for concurrent same-repo batches
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T06:52:00Z
- **Completed**: 2026-10-08T12:10:00Z
- **Effort**: ~5.5 hours
- **Dependencies**: 351 (per `specs/state.json`); ordering notes honored for 51, 165, 275 (see plan)
- **Artifacts**: plans/01_heartbeat-liveness-repair.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md, source-store-deploy-boundary.md

## Overview

All 8 plan phases landed, covering Piece 1 (heartbeat-silence diagnosis plus a system-wide
dispatch-boundary fix and an advisory adoption lint), Piece 2 (a third `held-live` lock state
and a matching `cmd_acquire` overlap-pass escalation, both consuming the shared
`session_liveness()` verdict and keyed on `session_id` never `pid`), Piece 3 (registry
`file_scope` re-derivation on heartbeat), and both absorbed defects (waking the dead Class E
contention review; fixing the self-contradicting batch-size message). `orchestrate-batch-admit.sh`
was never touched. Every edit lives under `agent-system/extensions/core/`; no file under
`.claude/**` was hand-authored.

## What Changed

- `agent-system/extensions/core/context/patterns/task-lock.md` — new "Heartbeat Coverage Is
  Per-Caller, Not Repo-Wide" section (Piece 1 verdict, probe, adoption inventory, two scope
  reductions); new "`held-live`: stale-heartbeat-but-pid-alive" section (Piece 2 contract,
  naming/exit-code rationale, cross-task overlap escalation); Session-Registry CLI section
  updated for Piece 3's re-derivation.
- `agent-system/extensions/core/scripts/lib/phase-heartbeat-lib.sh` — NEW. Extracted
  `phase_heartbeat_pulse()` from `update-phase-status.sh`'s inlined
  `heartbeat_after_phase_transition()`, with an explicit-parameter signature so dispatch-boundary
  callers can pulse the identical mechanism.
- `agent-system/extensions/core/scripts/update-phase-status.sh` — sources the lib; calls it with
  the real phase number; byte-identical trace-log output preserved.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — dispatch-start heartbeat
  pulse, labelled `dispatch-start`.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — dispatch-end heartbeat
  pulse, labelled `dispatch-end`, gated by `is_live()`.
- `agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh` — new advisory
  `check_i_heartbeat_mechanization_adoption()` (Check I): PASS when an in-scope agent invokes
  `update-phase-status.sh`, WARN when it is on the dated migration inventory, FAIL when it is
  neither (a newly introduced gap).
- `agent-system/extensions/core/scripts/task-lock.sh` — `cmd_check`'s stale branch gains the
  additive `held-live` state (exit code 1, reused from `held-fresh`); `cmd_acquire`'s cross-task
  overlap stale-WARN branch escalates to ABORT on a `pid-alive` foreign session; new
  `derive_union_file_scope()` helper shared by `cmd_session_register` and
  `cmd_session_heartbeat` (Piece 3).
- `agent-system/extensions/core/commands/orchestrate.md` — `batch_session_id` minted before the
  Pre-Dispatch Review call, with `--session-id` threaded in (absorbed defect a); corrected
  MAX_TASKS message (absorbed defect b); trimmed to stay within Gate 20's 21,000 B ceiling.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — the identical
  corrected MAX_TASKS message, kept verbatim with the command file.
- `agent-system/extensions/core/scripts/tests/test-task-lock-liveness.sh` — NEW. 15 cases: the
  stale-but-pid-alive `held-live` case, three fallback cases (missing/corrupt/dead-pid registry
  entry), a held-fresh-unaffected sanity case, the two-live-sessions overlap ABORT case, and its
  dead-pid WARN-and-proceed mirror.
- `agent-system/extensions/core/scripts/tests/test-lint-agent-contracts-heartbeat.sh` — NEW. 6
  cases proving Check I WARNs on the 13 inventoried offenders (exit 0) and FAILs on a
  non-inventoried one (exit propagates), using a sed/awk-patched copy of the real script rather
  than ever touching the deployed/source script.
- `agent-system/extensions/core/scripts/tests/test-phase-heartbeat.sh` — extended with Case 9
  (dispatch-boundary pulse writes a trace line with no phase transition).
- `agent-system/extensions/core/scripts/test-session-registry.sh` — extended with Case 11
  (widen-then-heartbeat re-derivation) and Case 12 (register-output-unchanged).
- `agent-system/extensions/core/manifest.json` — registered the 3 new source files in
  `provides.scripts` (found by Gate 3/5 during the Phase 8 sweep).
- `agent-system/extensions/core/index-entries.json` — corrected `patterns/task-lock.md`'s
  `line_count` (found by Gate 3 during the Phase 8 sweep).
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` — allowlisted the two
  new test fixtures' scratch-`state.json` mutations (found by Gate 12 during the Phase 8 sweep).

## Decisions

- Piece 1's gap is a design gap (incomplete propagation of an already-correct mechanization),
  not a routing regression — recorded in writing, with a reproducible probe, before any fix
  landed (Phase 1, per the task's own ACCEPTANCE ordering requirement).
- The dispatch-boundary pulse closes the functional gap system-wide without editing any of the
  13 un-migrated cross-extension agent files (outside this task's `file_scope`); the residual
  per-agent adoption gap is kept visible via an advisory lint (Check I) rather than silently
  dropped.
- `held-live` reuses `held-fresh`'s exit code 1 instead of minting a new one, since every
  existing `task-lock.sh check` consumer gates on 0/1/2 with a catch-all and code 1 already means
  "a live session may be working" — the exactly-right behavior at every site with zero
  consumer-side changes.
- Both new liveness checks (Piece 2a's `cmd_check` branch and Piece 2b's `cmd_acquire` escalation)
  resolve the holder's session strictly by `session_id`, never by comparing pids — two
  independent `/orchestrate` sessions can legitimately share a pid via `pid_source:
  ancestor-claude`.

## Plan Deviations

- Phase 4 and Phase 6's new test fixtures initially used literal "task NNN" phrasing for
  fictional fixture project numbers; self-caught via `check-task-references.sh` during Phase 7
  and reworded to "project NNN" / "fixture project NNN".
- The Phase 4/5 two-live-sessions test fixture's first construction gave the registered session
  the same `task_numbers`/`file_scope` as the held task, which caused the PRE-EXISTING
  `session_contention()` pass to independently ABORT too, confounding the pristine-vs-modified
  differential. Corrected by decoupling the registered entry's `task_numbers`/`file_scope`
  ([999]/[]) from the held task's own overlap, isolating the held-lock pass under test.
- `## Testing & Validation`'s "run-all.sh and verify-deploy.sh both green" item is checked with
  an annotated caveat rather than a bare completion: both are green for every suite/gate this
  task's logic touches; the residual findings are a pre-existing, unrelated flaky suite
  (`test-gate-out-repair-reporting.sh`) and expected source-store-vs-not-yet-redeployed-`.claude/`
  drift for this task's own new/changed files (see Follow-ups).

## Verification

- Build: N/A (shell scripts + markdown prose; no compiled build step)
- Tests: Passed — every suite this task's phases touch is green:
  `tests/test-phase-heartbeat.sh` (22/22), `test-session-registry.sh` (13/13),
  `tests/test-task-lock-liveness.sh` (15/15), `tests/test-lint-agent-contracts-heartbeat.sh`
  (6/6), `test-lint-agent-contracts.sh` (32/32), `test-task-lock-reap.sh` (6/6),
  `test-conflict-predicate.sh` (33/33), `test-four-tier-conflict.sh` (13/13 on re-run; one
  timing-budget case was transiently flaky under concurrent machine load, confirmed
  reproducible against the pristine pre-task script too), `tests/test-orchestrate-build-dispatch.sh`
  (141/141), `tests/test-orchestrate-cycle-postflight.sh` (184/184),
  `tests/test-dispatch-metrics.sh` (11/11), `tests/test-handoff-dispatch-identity.sh` (13/13),
  `tests/test-orchestrate-cycle-plan.sh` (351/351), `tests/test-orchestrate-predispatch-review.sh`
  (34/34), `tests/test-force-phases.sh` (36/36), `tests/test-lint-state-writer-boundary.sh`
  (8/8). Full `scripts/tests/run-all.sh` sweep: 116+ passed, 0 genuine failures attributable to
  this task (see Follow-ups for the one pre-existing, unrelated failing suite).
- Files verified: Yes — every file in `## What Changed` read back and diffed against intent.
- shellcheck: clean on every touched/new script (zero NEW findings vs. a pre-existing baseline
  re-confirmed after every edit): `task-lock.sh`, `update-phase-status.sh`,
  `lib/phase-heartbeat-lib.sh`, `orchestrate-build-dispatch.sh`, `orchestrate-cycle-postflight.sh`,
  `lint/lint-agent-contracts.sh`, `lint/lint-state-writer-boundary.sh`,
  `test-session-registry.sh`, `tests/test-phase-heartbeat.sh`, `tests/test-task-lock-liveness.sh`,
  `tests/test-lint-agent-contracts-heartbeat.sh`.

## ACCEPTANCE Evidence (per the task description's explicit ACCEPTANCE bullets)

1. **Piece 1 answer recorded in writing before any fix landed**: Phase 1's commit
   (`55975b338`) added `context/patterns/task-lock.md`'s "Heartbeat Coverage Is Per-Caller, Not
   Repo-Wide" section, landing before Phase 2's functional fix. Visible in the trace log: at
   implementation time, `grep -c "noop:session-mismatch" .agent-logs/heartbeat-trace.log` ->
   `0` against 4304 total lines (4287 `ok`, 15 `noop:no-entry`, 2 `noop:no-holder`).
2. **Fixture reproduces both named cases, failing against the pristine scripts**:
   - Stale-but-pid-alive: pristine `task-lock.sh` (via `git show HEAD:`) on the fixture reports
     `held-stale session=sess_probe_pidalive heartbeat_age_min=33 threshold_min=30
     never_heartbeated=true` / exit 2. The modified script reports `held-live ...
     liveness_reason=pid-alive` / exit 1 for the identical fixture.
   - Two-live-sessions overlap: pristine `cmd_acquire` on the isolated fixture (held-lock pass
     only, decoupled from the pre-existing session-registry contention pass) reports
     `WARN: task 810's file_scope overlaps ... proceeding without modifying it` / exit 0. The
     modified script reports `ABORT: ... liveness_reason=pid-alive` / exit 1 for the identical
     fixture.
3. **`orchestrate-batch-admit.sh` untouched**: `git diff --stat` across every task-272 phase
   commit shows zero lines for this file.
4. **Existing consumers keep working**: `held-fresh`/`held-stale` line prefixes and exit codes
   are byte-identical for every non-`pid-alive` case; `test-task-lock-reap.sh`,
   `test-session-registry.sh`, `test-conflict-predicate.sh`, `test-four-tier-conflict.sh` all
   pass unmodified.
5. **Clean shellcheck**: see Verification above.

## Impacts

- A task routed to any of the 13 (of 14) phase-heading-owning implementation agents that never
  call `update-phase-status.sh` now gets heartbeat coverage via the dispatch-start/dispatch-end
  pulses, closing the functional gap this task's live incident surfaced.
- `task-lock.sh check` and `cmd_acquire`'s cross-task overlap pass no longer treat a
  demonstrably-live session's lock as advisory purely because its heartbeat drifted.
- The session registry's `file_scope` now tracks the current state of `specs/state.json` rather
  than a point-in-time registration snapshot.
- Task 275 (per-repo orchestration queue) can build on an honest liveness signal.

## Follow-ups

- Per the task's own recorded, non-blocking `user_decision` (answered: "keep this task
  core-only"), a separate follow-up task should migrate the 13 cross-extension implementation
  agents to call `update-phase-status.sh` directly, retiring their entries from
  `lint-agent-contracts.sh`'s `HEARTBEAT_ADOPTION_MIGRATION_INVENTORY_DATED_20261008` as each
  lands.
- The deployed `.claude/` tree has not been redeployed to reflect this task's source-store edits
  (expected and correct per `source-store-deploy-boundary.md`; redeployment is a separate,
  repo-wide operational step outside this task's mandate, and running it mid-task risked
  deploying concurrently in-flight sibling tasks' incomplete source edits).
- `test-gate-out-repair-reporting.sh` fails 6/15 cases independent of this task (confirmed via a
  clean-env rerun and a pre-task-272 worktree checkout); a separate task should investigate
  `skill-base.sh`'s `SKILL_VALIDATE_FIXES`/`SKILL_VALIDATE_FIXED_FILES` global-state reset logic.
- 5 `index-entries.json` line_count mismatches (plan-format.md, state-management-schema.md,
  state-schema.json, shell-script-testing.md, todo-archival-reference.md) belong to
  concurrently in-flight sibling tasks (271/366) and were deliberately left untouched.

## References

- Plan: `specs/272_honest_session_liveness_concurrent_batches/plans/01_heartbeat-liveness-repair.md`
- Research: `specs/272_honest_session_liveness_concurrent_batches/reports/01_heartbeat-liveness-diagnosis.md`
- Dispatch: `specs/272_honest_session_liveness_concurrent_batches/.dispatch/14.md`
