# Implementation Summary: Task #387

- **Task**: 387 - Whole-tree regeneration scope claim (Part A) + plan-cache force-phases bypass (Part B)
- **Status**: [COMPLETED]
- **Started**: 2026-11-04T18:16:00Z
- **Completed**: 2026-11-04T21:15:00Z
- **Effort**: ~6 hours (7 of 7 planned phases)
- **Dependencies**: None
- **Artifacts**: plans/01_whole-tree-claim-and-cache-key.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Implemented both parts of a two-part orchestrator fix across all 7 of the plan's phases. Part B
closes a plan-cache replay defect in `orchestrate-cycle-plan.sh` where an aux-only composition
could cache a permanently-stuck replay, and where a `--force-phases` override could not break a
cache replay. Part A adds a new `whole_tree_claim` admission dimension to
`orchestrate-batch-admit.sh` so that two tasks whose plans both regenerate the whole deployed
tree serialize even when their declared `file_scope` sets are strictly disjoint. Phase 7
(redeploy and full gate) is now `[COMPLETED]`: its original clean-working-tree precondition was
withdrawn as structurally unsatisfiable in a plan revision (see Plan Deviations) and replaced
with a measurement-integrity baseline-delta gate, which this dispatch satisfied.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — Part B: tightened the
  `plan_cache` write guard to require >=1 real `dispatch` row (dropped the `aux_dispatch`
  disjunct); added `force_phases` to the cached object and the replay-match check; added a new
  `whole_tree_claim)` case arm to the `defer_reason` dispatch (a gap found while documenting
  Phase 4, not originally scoped to Part B); updated header/inline comments.
- `agent-system/extensions/core/scripts/orchestrate-batch-admit.sh` — Part A: added the
  `whole_tree_claim` admission dimension by relabeling the existing collision scan's own `$hit`
  in place when it matches the reserved sentinel, rather than a separately-evaluated trailing
  stage (see Decisions below); added `whole_tree_claim: true` to every sentinel-carrying
  candidate's verdict; applied the `--phase-map` research/plan exemption; bumped `$schema` to
  `orchestrate-batch-admit-v7`; updated header field/enum documentation.
- `agent-system/extensions/core/scripts/lib/file-scope-overlap.sh` — added the
  `whole_tree_claim_sentinel: "__WHOLE_TREE__"` named jq constant.
- `agent-system/extensions/core/context/formats/plan-format.md` — new "Whole-tree-claim
  declaration rule" subsection.
- `agent-system/extensions/core/agents/planner-agent.md` — new Stage 4 step 9 giving the planner
  the matching authoring obligation.
- `agent-system/extensions/core/docs/architecture/batch-admit-schema.md` — v7 Version History
  entry, new example verdict, new field rows, a "NEW in v7" precedence paragraph, and a new
  Deferral-Direction bullet.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new
  "Whole-Tree Regeneration Hazard: The Sixth Admission Dimension" section (mechanism, rejected
  zero-code alternative, explicit non-goal) plus a pointer paragraph in "The Three Existing
  Admission Layers".
- `agent-system/extensions/core/context/patterns/file-footprint-overlap.md` — new "Reserved
  sentinels" subsection and a new Consumers bullet.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — 8 new cases
  (Part B's 4 red-then-green cases, plus Group 34b's 4 cases for the `whole_tree_claim` case-arm
  fix).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-admit.sh` — 4 new cases
  (`WHOLE-TREE-CODISPATCH`, `WHOLE-TREE-PHASE-EXEMPT`, `WHOLE-TREE-NO-SENTINEL`,
  `WHOLE-TREE-INERT-PATH`) plus the `$schema` v7 pin update.
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` — Case 22 pinning
  the sentinel harvests verbatim.
- `agent-system/extensions/core/scripts/test-conflict-predicate.sh`,
  `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` — incidental `$schema`
  v7 literal updates, found by Phase 4's enumeration grep outside the plan's declared scope.
- `agent-system/extensions/core/index-entries.json` — `line_count` corrections for every markdown
  file this task edited.
- No additional source files changed in Phase 7: it invokes `deploy-headless.sh` (read-only) and
  the reserved `__WHOLE_TREE__` sentinel declaration in the plan (not a source file edit).

## Decisions

- **Part A's admission mechanism is RELABELING, not a trailing dimension.** An implementation-time
  fixture (Phase 2) proved the plan's literal "new dimension evaluated LAST, only on an
  otherwise-admit candidate" design cannot reach the same-sentinel in-batch case: two candidates
  declaring the identical `__WHOLE_TREE__` literal already produce an ordinary exact match under
  the EXISTING `file_scope_collision` scan, which intercepts and defers the pair first (under
  the wrong reason) before any trailing stage would run. The fix (Phase 4) inspects which path
  the collision scan's own `$hit` already matched on and branches the VERDICT SHAPE on that,
  leaving `$hit`'s own selection/deferral-direction logic completely untouched — preserving
  `file_scope_collision`'s non-regression guarantee for every real-path collision.
- **`orchestrate-cycle-plan.sh` needed its own `whole_tree_claim` case arm**, discovered while
  documenting Phase 4 (not part of Phase 4's own declared scope): without it, every
  `whole_tree_claim` defer would silently land in `unrecognized_defer_reason_ledger` with a loud
  warning rather than a clean `defer_ledger` entry. Added in Phase 6, with its own regression test.
- **`docs/architecture/orchestrate-state-machine.md` was investigated, not edited**: despite the
  plan's Scope Hypothesis anticipating it might enumerate admission dimensions needing an update,
  it contains no such enumeration at all.
- Two files outside the plan's declared scope (`test-conflict-predicate.sh`,
  `orchestrate-suggest-next-batch.sh`) were updated for `$schema` consistency — mechanical,
  low-risk, and required to avoid breaking `test-conflict-predicate.sh`'s own pin.

## Plan Deviations

- **Phase 4** altered the literal "separately-evaluated last dimension" mechanism to "relabel the
  collision scan's own result in place" — see Decisions above. All ACCEPTANCE criteria and
  observable fields are satisfied; only the internal mechanism differs from the plan's prose.
- **Phase 6**'s `docs/architecture/orchestrate-state-machine.md` task was discharged via
  investigation (confirmed no enumeration exists) rather than an edit.
- **Phase 6** additionally fixed `orchestrate-cycle-plan.sh`'s missing `whole_tree_claim` case
  arm — a necessary consequence of properly documenting Phase 4's own work, beyond Phase 6's
  literal task list.
- **Phase 7** originally self-blocked (dispatch_seq 29) on a clean-working-tree precondition,
  attributing 62-64 dirty paths to "concurrent sibling tasks in this same /orchestrate batch
  invocation". That attribution was later found FALSE (one live session, strictly serial
  dispatch; 52 of 63 dirty paths predated the run entirely) and the plan was revised
  (dispatch_seq 31, `.plan-revised.json`): the clean-tree gate was withdrawn as structurally
  unsatisfiable (`deploy-headless.sh` never reads `git status`, and the orchestrator's own
  EXCURSION DROPPED containment predicate manufactures uncommitted dirt every cycle by design)
  and replaced with the `deploy-baseline-lib.sh` capture -> confirm -> attribute pipeline already
  built for measurement-integrity risk. This dispatch (dispatch_seq 32) executed the revised
  Phase 7 as written and closed it `[COMPLETED]`.

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: `test-orchestrate-cycle-plan.sh` 384 passed/0 failed; `test-orchestrate-batch-admit.sh`
  15 passed/0 failed; `test-plan-file-scope-harvest.sh` all passed; `test-conflict-predicate.sh`
  33 passed/0 failed. `bash -n` clean on all 8 touched scripts.
- Files verified: Yes (doc-lint and task-reference lint clean for this task's own edits; all 13
  files this task touched confirmed byte-identical between the deployed `.claude/` tree and the
  source store after Phase 7's redeploy)
- Full gate set (`bash .claude/scripts/verify-deploy.sh`, no narrowing): exit 1, 9 findings
  (8x gate8 failing suites unrelated to this task's edits — test-gate-cache-equivalence,
  test-gate-lock, test-orchestrate-cycle-postflight, test-orchestrate-predispatch-review,
  test-orchestrate-unwind-dispatch, test-postflight-deploy-gate, test-redeploy-checkpoint-promotion,
  test-verify-deploy-context-budget; plus 1x gate16 lean routing_hard/routing_agents_hard
  migration warning). All 9 findings are byte-identical to the pre-deploy baseline established
  for this same orchestration cycle; `deploy_baseline_new_findings` over the two sets is empty
  (no finding newly introduced by this task's redeploy), and
  `deploy_baseline_unattributable_findings`/`deploy_baseline_self_attributable_findings`
  confirm none of the 9 findings name an identifier matching this task's own `modified_files`.
  Per Phase 7's own verification criterion, this non-zero exit does not block.
- Full shell suite (`bash agent-system/extensions/core/scripts/tests/run-all.sh`, no `--only`):
  cited from the identical invocation embedded in the `verify-deploy.sh` run above (its gate8
  step runs this exact command); exit 1, same 8 failing suites, none naming this task's files.
- `bash agent-system/extensions/core/scripts/validate-state.sh`: exit 0 (12 passed, 12
  pre-existing warnings unrelated to this task, 0 failed).

## Impacts

- Two co-dispatched tasks whose plans both regenerate the whole deployed tree will now serialize
  even with strictly disjoint `file_scope`, closing a live-observed co-dispatch hazard.
- A `--force-phases` override can now reliably break a stuck plan-cache replay, closing a
  live-observed defect where the human's override lever was silently ignored.
- Every future plan phase that invokes whole-tree regeneration must declare the `__WHOLE_TREE__`
  sentinel per the new producer-side convention (Phase 5); a plan that omits it falls back to the
  pre-existing fail-open deploy mutex, with no regression.

## Follow-ups

- The 8 persisting gate8 failing suites and the 1 gate16 lean warning are pre-existing and
  unattributable to this task; `test-verify-deploy-context-budget.sh`'s failure is a known
  host-state fixture leak tracked under a separate, open task (not this one's responsibility).
- The explicit non-goal recorded in Phase 6: this task does NOT close the stale-deploy READ
  hazard (a gate run reading a deployed tree that lags a sibling's already-committed source
  edits) — that remains covered by the existing inter-cycle redeploy checkpoint and the
  postflight completion-deploy gate.

## References

- Plan: `specs/387_whole_tree_regeneration_scope_claim/plans/01_whole-tree-claim-and-cache-key.md`
- Research: `specs/387_whole_tree_regeneration_scope_claim/reports/01_whole_tree_regeneration_scope_claim.md`
- Progress files: `specs/387_whole_tree_regeneration_scope_claim/progress/phase-{1..7}-progress.json`
- Handoffs: `specs/387_whole_tree_regeneration_scope_claim/handoffs/phase-{1..7}-handoff-*.md`
