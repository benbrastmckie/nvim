# Implementation Summary: Task #266

- **Task**: 266 - deploy_pending vs identical-dispatch guard: composition defect
- **Status**: [COMPLETED]
- **Started**: 2026-09-28T21:14:00Z
- **Completed**: 2026-09-28T23:15:00Z
- **Effort**: ~7 hours
- **Dependencies**: None
- **Artifacts**: plans/01_deploy-pending-guard-composition-fix.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed the composition defect between the postflight completion-deploy gate (exit 6) and the
identical-dispatch convergence guard: a deploy-blocked task necessarily re-derives a
byte-identical dispatch next cycle, which the guard previously misread as churn and halted. The
fix wires `reconcile-task-status.sh` into the Inter-Cycle Redeploy Checkpoint's own clean-success
path (so a deploy-unblocked task converges to `completed` within the same run, before any second
dispatch is derived), adds a narrow per-task streak-freeze backstop for the residual paths where
that reconcile cannot conclude, clears the `deploy_pending` marker at the single completion
chokepoint so the freeze cannot arm permanently, corrects the misleading refusal message, and
documents the whole interaction in `batch-orchestration-guardrails.md`. All 8 plan phases
completed; the source store was deployed and end-to-end verified.

## What Changed

- `agent-system/extensions/core/scripts/update-task-status.sh` — clears `deploy_pending` /
  `deploy_pending_reason` from a task's own `.return-meta.json` at the single completion
  chokepoint (after a successful `postflight … implement` write), never on a refusal.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — (1) a post-deploy reconcile
  pass inside the Inter-Cycle Redeploy Checkpoint's three clean-success branches, running
  `reconcile-task-status.sh` for every deploy-pending task before the cycle's own status refresh
  and dispatch derivation, recording outcomes in a new `post_deploy_reconcile_notices` mt_state
  array; (2) a streak-freeze backstop in the Fix 2 identical-dispatch hashing block: when a
  task's own `.return-meta.json` carries `deploy_pending: true` and its dispatch hash matches the
  previous cycle's, `identical_dispatch_streak` is left at its current persisted value instead of
  incremented, with a distinct stderr notice.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — corrected the
  DEPLOY-PENDING refusal's trailing clause (before/after text below).
- `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` — added Case 9
  (marker cleared on a successful completion write, unrelated keys preserved) and Case 10 (marker
  preserved on an exit-6 refusal).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — added Group 29
  with Arms A-E reproducing and pinning the composition defect and its resolution.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — added an
  assertion on the corrected DEPLOY-PENDING trailing clause.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — corrected
  the "D6 — CLOSED" claim to record the identical-dispatch-guard interaction, documented the
  reconcile pass / streak-freeze / marker lifecycle, and cross-referenced the Inter-Cycle Redeploy
  Checkpoint section.
- Deployed `.claude/` mirror (generated via `deploy-headless.sh`, not hand-authored).

## Decisions

- **Freeze, not suppress**: the identical-dispatch guard's halt threshold is completely
  unmodified; only the streak counter's *input* is frozen for a deploy-pending task, so the guard
  stays fully live for every other task and for a formerly-deploy-pending task once its marker is
  cleared.
- **Per-task marker, never batch-wide `deploy_pending_any`**: the freeze reads the task's own
  `.return-meta.json` at hash time, so one sibling's deploy-pending state can never mask another
  task's genuine churn (pinned by Group 29 Arm C).
- **Reconcile inside the checkpoint's already-serialized window, not a new dispatch site**: placed
  strictly after the deploy's success is confirmed and before Move 2 issues any dispatch — the one
  point in the loop with no dispatch in flight — inheriting the existing serialization rather than
  introducing a new lock or a third automated redeploy-trigger site.
- **Rejected**: moving the deploy earlier (before the completion write is attempted). Analyzed in
  the plan's Risks table and rejected — it does not fix the composition defect and reintroduces
  the `specs/.deploy-lock` race the current design's Concurrency Posture deliberately avoids.

## Plan Deviations

- **Phase 5 Arm D** altered: a genuine implement-phase promotion is terminal (`completed`), so
  Arm A's own task cannot literally be re-dispatched to prove a post-clearing repeat halts. Arm D
  instead isolates the same invariant on a fresh candidate carrying no `deploy_pending` marker at
  all (the exact state Phase 1's clearing leaves behind). This arm passes both before and after
  the fix by construction (pre-fix code never read the marker either), which is itself the correct
  outcome — Arms A and C are the arms that actually pin the defect's reproduction/resolution.
- **Phase 6** task 2 skipped: a case asserting the exit-6 refusal for a genuinely stale extension
  was not added as a new case — it was already covered end-to-end by the pre-existing
  "Characterization: cycle_modified_files accumulates across a real exit-6 deploy-pending
  postflight refusal" case in `test-orchestrate-cycle-postflight.sh`.
- **Phase 8** task 1 altered: "every test passes" does not hold literally across the full
  cross-extension `scripts/tests/` corpus — see Verification below for the full accounting. This
  task's own three named suites are 100% green.

## Verification

- Build: N/A (shell scripts)
- Tests:
  - `test-postflight-deploy-gate.sh`: 29 passed, 0 failed.
  - `test-orchestrate-cycle-plan.sh`: 300 passed, 0 failed (285 pre-existing + 15 new Group 29
    assertions/pass-lines; every pre-existing Group 1-28 case unchanged).
  - `test-orchestrate-cycle-postflight.sh`: 128 passed, 0 failed (127 pre-existing + 1 new).
  - Pre-fix regression check: swapped `orchestrate-cycle-plan.sh` to the pre-Phase-2 commit
    (`753d2e569`), re-ran `test-orchestrate-cycle-plan.sh`: Arms A and C — the two arms that
    exercise the new reconcile/freeze logic — genuinely FAIL (293 passed, 7 failed). Arms B/D/E
    pass unaffected (expected — they do not depend on the fix). Restored the post-fix file
    (confirmed byte-identical to the committed version via `git diff --stat`).
  - Full cross-extension `run-all.sh` (97 suites): 91 passed, 6 failed, 0 skipped. All 6 failures
    are pre-existing and unrelated to this task:
    - `test-handoff-dispatch-identity.sh`, `test-orchestrate-context-growth.sh`: both fail on
      "shared library `return-meta-status-vocabulary.sh` not found" — a fixture-copying gap in
      each suite's own `REQUIRED_LIBS` list, dating to that library's introduction
      (`60881cfd6`, task 257), well before this task and never touched by it.
    - `test-lint-json-channel-discipline.sh`: flags an unrelated pre-existing violation in
      `agent-system/extensions/typst/scripts/chapter-quality-check.sh` (last touched by task 254).
    - `test-orchestrate-recover-message-findings.sh`: fails on a research-phase
      `detected_defects` assertion unrelated to the implement-phase deploy-pending gate (SUT last
      touched by task 212).
    - `test-verify-deploy-context-budget.sh`: fails on a stale content-budget baseline fixture
      (SUT last touched by task 261).
    - `test-gate-out-repair-reporting.sh` / `test-run-all-parallel.sh`: order/timing-flaky
      (passed on one run, failed on another; unrelated to any file this task touched).
  - `bash -n` clean on every edited shell script.
  - `git diff --stat` across the three touched test files: 346 insertions, 0 deletions —
    additive-only.
- `verify-deploy.sh` (full depth, no `--skip-slow`), post-deploy: 33/34 checks pass; the sole
  remaining failure is the same pre-existing gate-8 (shell test suite) class documented above.
  `deploy-headless.sh`: `RESULT=landed_verify_clean`.
- Files verified: Yes (all new/modified files confirmed to exist and contain the expected content)

### Before/after message text (dispatch verification item 4)

**Before**:
> DEPLOY-PENDING: task ${task_number}'s postflight completion write was refused by the
> completion-deploy gate (exit 6). The task remains at its current in-flight status; convergence
> is deferred to the next cycle's Inter-Cycle Redeploy Checkpoint (orchestrate-cycle-plan.sh) --
> no manual action needed.

**After**:
> DEPLOY-PENDING: task ${task_number}'s postflight completion write was refused by the
> completion-deploy gate (exit 6). The task remains at its current in-flight status; the next
> cycle's Inter-Cycle Redeploy Checkpoint (orchestrate-cycle-plan.sh) deploys and then
> automatically reconciles this task's status -- no manual action needed unless that deploy or
> its post-deploy verify fails, in which case the checkpoint emits its own named WARNING there and
> states the remedy.

## Impacts

- A deploy-pending task (any task whose `modified_files` overlap `agent-system/extensions/**`)
  now converges to `completed` within the same `/orchestrate` run once the checkpoint's deploy
  lands, with no wasted second dispatch and no risk of being halted by the identical-dispatch
  guard for its own deploy-gated re-derivation.
- The identical-dispatch guard remains fully live for every other task, including one that was
  deploy-pending earlier in its life and has since had its marker cleared.
- Operators no longer need to manually run `reconcile-task-status.sh` after a batch redeploy for
  this class of task.
- `batch-orchestration-guardrails.md` now accurately describes the composed system's convergence
  behavior instead of an aspirational guarantee.

## Follow-ups

- None required for this task's own scope. The 6 pre-existing, unrelated test-suite failures
  documented above (missing `return-meta-status-vocabulary.sh` fixture copy in two suites; an
  unrelated typst lint violation; unrelated research-phase `detected_defects` and content-budget
  fixture drift; two order/timing-flaky suites) are candidates for a separate, dedicated cleanup
  task if desired.

## References

- `specs/266_deploy_pending_vs_identical_dispatch_guard/plans/01_deploy-pending-guard-composition-fix.md`
- `specs/266_deploy_pending_vs_identical_dispatch_guard/reports/01_deploy_pending_vs_identical_dispatch_guard.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/scripts/update-task-status.sh`
