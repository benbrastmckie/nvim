# Implementation Summary: Task #152

- **Task**: 152 - Stop hand-maintained line_count drift and unrelated red gates from blocking task completion and whole batches
- **Status**: [COMPLETED]
- **Started**: 2026-09-07T23:44:16Z
- **Completed**: 2026-09-08T02:05:00Z
- **Effort**: ~7 hours (matches plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/01_decouple-stale-declarations.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md

## Overview

Cut the coupling that let three stale hand-maintained `line_count` declarations stall an entire
`/orchestrate` batch, on two independent axes named by the dispatch: (a) `line_count` is now
derived automatically at every deploy instead of hand-maintained, so a drift can never reach
`check-extension-docs.sh`'s Rule R silently; and (b) `orchestrate-cycle-plan.sh`'s inter-cycle
redeploy checkpoint now implements the same three-branch (a)/(b)/(c) failure contract
`command-gate-out.sh` already implemented, via a new shared library both call sites source, so a
pre-existing unrelated red gate no longer defers a whole batch. `deploy-headless.sh` additionally
gained a `RESULT=`/`CONSUMERS_STALE=` marker vocabulary so its three confounded exit-3 causes
(deploy did not land / deploy landed with a red gate / other consumer repos are stale) are
distinguishable by a caller without parsing prose.

## What Changed

- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` — new shared library:
  `deploy_findings_snapshot` (verify-deploy.sh `--findings` snapshot with exit-2 sentinel
  folding) and `deploy_baseline_new_findings` (the `comm -13` set difference), sourced by both
  `command-gate-out.sh` and `orchestrate-cycle-plan.sh`.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — the inter-cycle redeploy
  checkpoint now captures `deploy-headless.sh`'s exit code explicitly, excludes ONLY exit 1/2
  from the baseline comparison (previously ALL non-zero exits, including exit 3, were
  unconditionally deferred — the actual defect), sources the shared library, and corrects a
  stale comment claiming the checkpoint was "always a no-op today."
- `agent-system/extensions/core/scripts/command-gate-out.sh` — adopts the shared library at its
  existing rc==6 handler, deleting the duplicate inline `_gate_out_deploy_findings()` and inline
  `comm -13`, with no message-text or behavior change (pure substitution).
- `agent-system/extensions/core/scripts/deploy-headless.sh` — runs the deployed
  `generate-context-line-counts.sh --write` before the nvim deploy invocation (guarded, reported,
  skipped under `--dry-run`); emits `RESULT=not_landed|landed_verify_clean|landed_verify_red` and
  `CONSUMERS_STALE=<n>` marker lines; tightened header documentation.
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — Rule R's mismatch and
  missing-key messages now name the remedy command; the missing-source-file case is left as a
  plain hard failure (genuinely unfixable automatically), per the dispatch's own instruction.
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` — new, 7 unit cases.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — 8 new Group 11
  cases driving the checkpoint through all three branches with a stubbed `deploy-headless.sh` and
  a call-counting stubbed `verify-deploy.sh`; also fixed its own collaborator-copy list, which was
  missing `lib/deploy-baseline-lib.sh` (broke all 70 pre-existing cases via a source failure).
- `agent-system/extensions/core/scripts/tests/test-loop-guard-budget-override.sh` — fixed its own,
  independent TARGET-2 collaborator-copy list, which was also missing
  `lib/deploy-baseline-lib.sh` after Phase 2 added the new source line to
  `orchestrate-cycle-plan.sh`.
- `agent-system/extensions/core/manifest.json` — registered `lib/deploy-baseline-lib.sh` and
  `tests/test-deploy-baseline-lib.sh` in `provides.scripts`.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — scoped
  branch (a) explicitly to exit 1/2, documented exit 3's routing to the baseline comparison, and
  noted both call sites now share one sourced library.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — marked the
  exit-3 follow-up DONE and corrected its stale edit-target pointer; documented the
  `RESULT=`/`CONSUMERS_STALE=` marker vocabulary and the `line_count` auto-repair mechanism.
- `agent-system/extensions/core/index-entries.json` — 2 `line_count` values auto-corrected by the
  new deploy-time repair, firing on this task's own Phase 6 doc edits (a live demonstration of
  the mechanism, not a manual edit).

## Decisions

- **`line_count` stays declared, not derived at read time or dropped.** Four real consumers
  (`validate-context-budgets.sh`, `validate-index.sh`, `validate-context-index.sh`,
  `install-extension.sh`) read it for token-budget math. Repair-before-gate (option ii from the
  dispatch) was chosen over derive-at-read (i) or drop (iii, rejected on evidence per the
  dispatch's own instruction to check before choosing it).
- **The (b) fix is a straight port, not a redesign.** `command-gate-out.sh`'s rc==6 handler
  already implemented the correct three-branch contract; the checkpoint in
  `orchestrate-cycle-plan.sh` was the one call site that never caught up. Extracting the shared
  behavior into `scripts/lib/deploy-baseline-lib.sh` and sourcing it at both sites closes the
  drift-apart risk permanently rather than just fixing the one instance.
- **The third confound (stale consumer repos) needed no code fix**, confirmed by an actual
  runtime trace (`bash -x`) against this repo's own real, populated consumer registry, not merely
  by reading the code: `verify_rc` is fixed before the consumer-freshness block runs and the
  block's own exit code is unconditionally absorbed by `|| true`. Only a `CONSUMERS_STALE=<n>`
  reporting marker was needed.
- **Dropped the durable `index_line_count_auto_repair` events.jsonl row for the line_count
  auto-repair**, per the plan's own risk-table contingency: `deploy-headless.sh` has no natural
  session-id source (it deliberately never sources `lib/common.sh`, the same self-overwrite
  reasoning that already excludes `task-lock.sh`), and an inline `sess_$(date` synthesis tripped
  `test-common-lib.sh`'s single-source assertion. The console report (unconditional, on both the
  repaired and clean path) is the durable record instead.

## Plan Deviations

- **Phase 4, task 3** ("If the runtime check refutes it... fix the leak") skipped: the runtime
  check confirmed the guard holds rather than refuting it, so this conditional branch was
  inapplicable — annotated in the plan as a deviation, not a completed task.
- **Phase 6, task 5** (`docs/architecture/orchestrate-state-machine.md` conditional update):
  confirmed unnecessary — the `mt_state_file` key set (`deployed_critical_paths`,
  `verify_deploy_baseline_notices`, `deferred_deploy_checkpoint`, `defer_ledger`) is unchanged
  from before Phase 2, verified by grepping the checkpoint's own `mt_set` calls.
- **Two unplanned fixes surfaced only by running the full `run-all.sh` suite** (not caught by the
  individual suites the plan named): the inline session-id lint regression in
  `deploy-headless.sh`, and a second, independent test fixture
  (`test-loop-guard-budget-override.sh`) with its own collaborator-copy list also missing the new
  library. Both fixed within Phase 7 rather than deferred.

## Verification

- Build: N/A (shell scripts + markdown docs)
- Tests: `test-deploy-baseline-lib.sh` 7/7, `test-orchestrate-cycle-plan.sh` 85/85 (including 8
  new Group 11 checkpoint-branch cases), `test-gate-out-repair-reporting.sh` 19/19,
  `test-loop-guard-budget-override.sh` 41/41, `scripts/tests/run-all.sh` 73/73 suites,
  `bash .claude/scripts/verify-deploy.sh` (full gate set) 30 checks / 0 failures — all run
  against a real redeployed `.claude/` tree (two full self-deploys of this repo).
- Files verified: Yes

## Acceptance Demonstrations

1. **`line_count` drift cannot occur silently.** In a scratch clone of `agent-system/extensions/`
   (Phase 5), appended a line to an indexed core context file, leaving its `line_count`
   declaration untouched. A subsequent `deploy-headless.sh` run auto-repaired it (declared
   364 → actual 365) and reported "1 entry/entries corrected from wc -l (extensions: core)";
   `check-extension-docs.sh`'s Rule R then reported zero findings for that entry, with no manual
   edit. Reproduced for real on this repo's own source store during Phase 6/7: two genuinely
   stale entries (my own doc edits) were auto-corrected and reported (`agent-system/extensions/core/index-entries.json`
   diff: `469→519`, `928→939`) rather than blocking.
2. **A pre-existing, unrelated red gate no longer defers a whole batch.** `test-orchestrate-cycle-plan.sh`
   Group 11 case (c): a stubbed `deploy-headless.sh` exits 3 with a stubbed `verify-deploy.sh`
   reporting the SAME finding pre- and post-redeploy. Result: `deferred_deploy_checkpoint` stays
   empty, a `verify_deploy_baseline_notices` entry is recorded, and `deployed_critical_paths` is
   updated — the batch proceeds. This is the exact branch that was structurally unreachable
   before this task.
3. **A genuinely new failure still stops the batch.** Group 11 case (b): the same exit-3 stub,
   but the post-redeploy snapshot contains one finding absent from the pre-redeploy snapshot.
   Result: `deferred_deploy_checkpoint` contains the task, no baseline notice is recorded — the
   tolerance is proven narrow, not merely assumed narrow.
4. **The three confounded exit-3 causes are distinguishable by a caller.** Demonstrated three
   `RESULT=` values directly: `RESULT=not_landed` on a usage error (target not a directory),
   `RESULT=landed_verify_red` on a scratch deploy with an inline verify failure, and
   `RESULT=landed_verify_clean` on this repo's own clean real self-deploy — where
   `CONSUMERS_STALE=44` was ALSO present simultaneously, proving the marker is independent of
   `RESULT=`/the exit code rather than folded into it.

## Impacts

- Any future `/orchestrate` batch that touches an orchestrator-critical path and lands with a
  pre-existing, unrelated `verify-deploy.sh` finding will now proceed (with a recorded notice)
  instead of stalling every remaining task in the batch — the exact failure mode the dispatch was
  filed against.
- No indexed context file's `line_count` will need a hand-edit again; every deploy self-corrects
  it, reported, before Rule R evaluates.
- `command-gate-out.sh` and `orchestrate-cycle-plan.sh` can no longer independently drift apart on
  this contract — they share one library.

## Follow-ups

- None required by this task. The sibling task fixing the two live `line_count` gate failures
  named in the dispatch is out of scope here (this task owns the defect class, not the
  instances) and was observed, mid-implementation, to already be in flight under a concurrent
  session (task 151's plan status flipped to `[COMPLETED]` during this dispatch — not this
  agent's work, left untouched).

## References

- `specs/152_decouple_stale_declarations_from_deploy_gating/reports/01_decouple-stale-declarations.md`
- `specs/152_decouple_stale_declarations_from_deploy_gating/plans/01_decouple-stale-declarations.md`
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
