# Implementation Summary: Task #395

- **Task**: 395 - Surface a failed per-cycle scoped commit into the dispatched task's own status
- **Status**: [COMPLETED]
- **Started**: 2026-10-16T00:00:00Z
- **Completed**: 2026-10-17T00:30:00Z
- **Effort**: 5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_commit-failure-status-demotion.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`orchestrate-cycle-postflight.sh` previously wrote an implement dispatch's `completed` status to
`state.json` at WORK (f), hundreds of lines before WORK (i) attempted that cycle's scoped commit,
so a genuinely failed commit (`git-commit-scoped.sh` exit 2/3/4/5) left a task at `[COMPLETED]`
with its deliverable changes uncommitted on disk. This implementation adds a narrowly-gated
corrective block inside WORK (i): when the same dispatch window's commit for a just-completed
implement dispatch demonstrably did not land, the task is demoted to `partial` with a named
handoff blocker, the cycle's verdict flips from `ok` to `defer`, and a loud `STATUS DEMOTED` line
is emitted. Both polarities (demotion and its negatives — exit 6, a `planned` dispatch, exit 1)
are pinned by new regression-test cases, the sanctioned terminal-state exception is documented in
two places, and the change has been deployed and gate-checked.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — added a second,
  narrowly-gated block immediately after the existing `2|3|4|5|6)` exit-code case (left
  byte-for-byte unchanged): on exit 2/3/4/5 for an implement dispatch that was just marked
  `completed` (gated on `dispatch_status`, `implemented_gate_passed`,
  `deploy_pending_refusal`, `derived_staleness_refusal` — the exact conjunction WORK (f) used),
  it calls `skill_postflight_update ... partial`, amends `.orchestrator-handoff.json` in place
  (new `blockers[]` entry, `status: "partial"`, both continuation-pointer forms nulled), sets
  `verdict="defer"`, and emits a `STATUS DEMOTED:` stderr line. Rewrote the trailing `HARD
  CONSTRAINT` comment block to document the new carve-out instead of standing stale.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — added
  positive-case coverage (stub exit 3: `persisted_status == "partial"`, `verdict == "defer"`,
  `halt == false`, `infra_exempt_cycle == false`, a `STATUS DEMOTED` stderr line, and the
  fixture's handoff carrying a non-empty `blockers[]` with both continuation forms nulled) plus
  negative cases (exit 6 does not demote; exit 3 on a `planned` dispatch does not demote; exit 1
  keeps its existing non-blocking WARNING path unchanged) and a clean-baseline companion run.
- `agent-system/extensions/core/context/standards/status-markers.md` — the `[COMPLETED]` section's
  valid-transitions line and the terminal-states list entry both now name the single sanctioned
  exception (a postflight-synthesized demotion to `partial` on a non-landing per-cycle commit),
  so the two statements in the file no longer contradict each other.
- `agent-system/extensions/core/context/standards/git-staging-scope.md` — the "Recorded
  caller-escalation residual" paragraph now states the implemented behavior (exits 2-5 demote;
  exit 6 and exit 7 deliberately do not) instead of describing an unimplemented follow-up.
- `specs/395_surface_failed_per_cycle_commit_into_task_status/plans/01_commit-failure-status-demotion.md`
  — all four phase headings closed (`[COMPLETED]` x3, `[COMPLETED WITH EXCLUSIONS]` for Phase 4),
  checklist items annotated, Phase 4's Reasoned Exclusions table added, Testing & Validation
  checklist checked off.

## Decisions

- Option (b) (a narrowly-scoped corrective write) was used, not option (a) (reordering WORK (f)
  and WORK (i)), because splitting the per-cycle commit would break the one-commit-per-cycle
  contract `git-workflow.md` and `dispatch-metrics.sh` both rest on — confirmed against the live
  file during planning, unchanged at implementation time.
- Exit 6 (and exit 7, via the `*)` catch-all) are excluded from the demotion set: both mean a
  commit landed, per `git-staging-scope.md`'s own exit-code table, and the pre-existing case 980
  assertion (`.verdict` unchanged between the exit-6 probe and the exit-0 baseline) remains green
  unmodified rather than being amended to accommodate an unjustified demotion.
- The demotion write itself is never committed by this task — it lands on disk uncommitted and is
  picked up by whichever later cycle's commit succeeds, since `state.json` is machine truth read
  directly by the next cycle's triage.

## Plan Deviations

- **Phase 4, task 4** (run the complete gate set) altered: this dispatch's `.dispatch/11.md`
  carries a `## Batch Gate Deferral` section (this task is one of several `implement`-phase
  dispatches in one multi-task `/orchestrate` batch invocation). Discharged the phase against the
  scoped narrowing the directive names
  (`run-all.sh --only test-orchestrate-cycle-postflight.sh,test-skill-base-lifecycle.sh,test-handoff-reader-parity.sh,test-lint-lifecycle-status-var.sh,test-todo-move-pair-staging.sh`
  — 5 passed, 0 failed, 0 skipped) instead of independently running the full gate-8 shell-suite
  battery, which `deploy-headless.sh`'s own fast-gate `verify-deploy.sh` pass (36 checks, 0
  failures) explicitly logged as deferred. The full gate set runs once, at the end of this
  `/orchestrate` batch invocation, and is attributed back to this task via `modified_files`. See
  the plan's Phase 4 Reasoned Exclusions table.

## Verification

- Build: N/A (bash scripts and prose)
- Tests: Passed — `bash -n` clean; `lint-scoped-commit-boundary.sh` exits 0 (0 violations across
  1340 files); the five scoped suites named above all PASS (5 passed, 0 failed, 0 skipped);
  `deploy-headless.sh` completed with `RESULT=landed_verify_clean` and its fast-gate
  `verify-deploy.sh` pass reported 36 checks / 0 failures.
- Files verified: Yes — the deployed `.claude/scripts/orchestrate-cycle-postflight.sh` and the
  other three task files are byte-identical to their source-store copies, confirmed both before
  and after the deploy run.

## Impacts

- A genuinely failed per-cycle scoped commit for an implement dispatch now leaves the dispatched
  task's own `state.json` status at `partial` (not `completed`), with a named handoff blocker
  routing the next `/orchestrate` cycle to `needs_human` instead of a redundant re-dispatch.
- The sanctioned exception to `[COMPLETED]`'s terminal-state rule is now documented in both
  places `status-markers.md` asserts terminality, closing the risk of a future reader concluding
  the demotion code is a bug.

## Follow-ups

- The full gate-8 shell-suite battery for this task's file scope is attributed to the
  once-per-invocation batch-level gate run at the end of this `/orchestrate` cycle, per the
  dispatch's Batch Gate Deferral directive — not independently re-run by a later dispatch.
- Adopting exit `7` into the explicit exit-code list remains a separately-named future pass in
  `git-staging-scope.md`'s residual paragraph (deliberately out of this task's scope).

## References

- `specs/395_surface_failed_per_cycle_commit_into_task_status/plans/01_commit-failure-status-demotion.md`
- `specs/395_surface_failed_per_cycle_commit_into_task_status/reports/01_commit-failure-status-surfacing.md`
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/context/standards/status-markers.md`
- `agent-system/extensions/core/context/standards/git-staging-scope.md`
