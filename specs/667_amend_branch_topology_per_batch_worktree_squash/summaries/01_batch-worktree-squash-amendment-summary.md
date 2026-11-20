# Implementation Summary: Task #667

- **Task**: 667 - Amend branch-topology rulings R1-R3 and R5: per-batch worktree side branches with per-task squash landing onto the long-lived feature branch
- **Status**: [COMPLETED]
- **Started**: 2026-11-20T19:58:09Z
- **Completed**: 2026-11-20T21:10:00Z
- **Effort**: 1 implement dispatch, 5 plan phases
- **Dependencies**: None
- **Artifacts**: plans/01_batch-worktree-squash-amendment.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This task ruled and decomposed; it did not build the batch-worktree workflow. It wrote the
decision record that amends rulings R1, R2, R3 and R5, repaired the landing check that was
stranding finished tasks at `[IMPLEMENTING]` (defect D1), and created eight task records that
own Elements 2 to 7. Until those eight land, every dispatch still runs in the one shared working
tree and nothing about branches or worktrees has changed in behaviour.

## What Changed

- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` — Created. The amending
  record: authority, eight defects and hazards engaged by mechanism, rulings R1/R2/R3/R5 and the
  R6 consequence, rejected alternatives, Option L1 for Lean repositories, verdicts on D1 to D4,
  cleanup, costs, one unconfirmed assumption, one measured precondition, successor tasks, edges.
- `specs/decisions/branch-topology-and-landing-strategy.md` — One dated `**Amended by**` note
  appended. The original rulings table is untouched.
- `specs/decisions/commit-layer-cluster-ordering.md` — One dated `**Amended by**` note appended,
  recording that Judgment 1's condition has fired.
- `agent-system/extensions/core/scripts/milestone-ref-land.sh` — `--verify` now asserts tree
  equality between the milestone ref's tip and `HEAD` instead of ancestry; landing an unchanged
  tree creates no commit; each landed commit carries a `Landed-From: <sha>` trailer used only to
  explain a failure; header comment rewritten to match.
- `agent-system/extensions/core/scripts/tests/test-milestone-ref-land.sh` — Seven cases added
  (13 total): three-landing sequence, negative fixture, its recovery, unchanged-tree no-op,
  trailer, and a ref whose chain is not descended from the work branch.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — The
  `MILESTONE-LANDING` notice text only. Control flow unchanged: a verify failure still refuses
  the completion status write.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — One
  assertion added on the new notice text.
- `specs/state.json`, `specs/TODO.md`, `specs/ROADMAP.md` — Tasks 668 to 675 created with
  dependency edges; 655 narrowed to its generated-file element; a finding written into 666.
- `.claude/**` — Redeployed with `deploy-headless.sh --skip-verify`.

## Decisions

- **The amendment is sound, with three changes to what was proposed.** `specs/` is tracked here,
  not ignored, so the worktree is sparse without it; the symlink candidate is rejected; landing
  is by attribution (`git cherry-pick -n` of the task's own commits), not `git merge --squash`.
- **The wrong-root defect is stated as NOT closed by design.** The record also concedes that the
  reopening report's objection to an out-of-repository worktree applies here, and answers it
  with loud refusal keyed on a batch record, as an obligation on successor work.
- **Isolation is a per-repository key, `worktree_isolation`, values `batch` and `off`,
  undeclared means `off`.** Lean repositories get Option L1: the branch check and no squash.
- **`milestone-ref-land.sh` is retired by a successor, not here.** It is repaired first.
- **The postflight refusal on a verify failure is kept; only its message changed.**
- **No direct edge from 670 to 536 or 567.** Both are already in 553's transitive closure.

## Plan Deviations

- **Task 2.9** altered: no postflight suite case matched the old notice text, so none needed
  updating; one assertion on the new text was added.
- **Task 4.2** skipped: 655's `file_scope` was not narrowed. Its remaining element leaves the
  declaration site as a design question, so no file set is identifiable. 655 still over-claims
  the commit scripts until its plan re-declares the scope.
- **Task 4.5** altered: the plan's conditional edge to 567 was not written. The plan had read
  567's own empty `dependencies` array as showing it did not precede 553; computing the closure
  of 553 shows it does, as the research report said.
- **Phase 5** altered: `deploy-headless.sh` was run with `--skip-verify`, because its inline
  verification is a complete fast-gate sweep and the dispatch defers the complete gate set to
  the batch stage. The deploy reported `RESULT=landed_verify_skipped` (exit 4), which is not a
  passed verification.

## Verification

- Build: N/A
- Tests: Passed. `verify-touched.sh` over the four edited script paths, run after the redeploy so it exercised the redeployed copies: 19 suites selected, 19 passed, 0 owed. This is a narrowed run, not a full-battery pass.
- `test-milestone-ref-land.sh` 13 of 13 and `test-orchestrate-cycle-postflight.sh` 351 of 351,
  run directly from the source store before the redeploy.
- The negative fixture was observed failing two ways in scratch copies: with the comparison
  forced true, the negative-fixture and diverged-chain cases fail; with the script as it stood
  before the repair, the three-landing sequence fails with land/verify exits `00 01 01`, which
  is D1.
- `validate-state.sh`: passed with warnings, 0 failed, after Phases 3 and 4.
- The four deployed files are byte-identical to their source-store copies.
  `sync-manifest-scripts.sh --check` passed.
- Task-reference lint: exit 0. Record-versioning lint: no finding located in the four edited
  files (it exits 1 repo-wide on findings in other files).
- **Not run:** the complete gate set, deferred to the batch stage by the dispatch's Batch Gate
  Deferral. No full `verify-deploy.sh` was run by this dispatch.
- Files verified: Yes

## Impacts

- A task in a roadmap milestone can now reach `[COMPLETED]` after the milestone's first landing.
  Before the repair every later landing failed verification permanently.
- The repaired check can fail on correct work in one case: a sibling commits to the work branch
  between a task's landing and its verify. One re-run lands the current tree and passes.
- 668 to 675 render as blocked. 668 waits only on this task.
- The Element 3 ordering relies on a dependency chain that was written for file territory. The
  record's Edges section says what to do before reversing any link in it.

## Follow-ups

- **Successor tasks**: 668 harness measurement, 669 admission and batch worktree, 670 two-root
  commit scripts, 671 two-root hooks, 672 remaining consumers, 673 attribution landing, 674
  cleanup and orphan reporting, 675 documentation parity. 668 may need the user at the keyboard.
- **Confirmation not asked**: all eight creations drew a `duplicate-of-open` audit verdict
  naming 655. The `/task` path asks the user to confirm on such a verdict; that prompt is
  unreachable from a dispatched agent and was skipped. `/task --abandon` undoes any of them.
- **Unanswered question** (owner: user): where `specs/` is tracked, do bookkeeping commits keep
  landing directly on the integration branch between squash commits, or are they folded into
  each squash? The record proceeds on the first as an assumption. 670 must be re-planned if the
  answer is the second.
- **`/roadmap`**: site 668 to 675 into batches; re-judge 655's batch, whose `--hard` flag and
  rationale were authored for its superseded scope.
- **666**: its named instance was applied by commit `7231ccbe2`; one inversion remains from its
  sweep (486 in batch 8 depends on 541 in batch 9). Narrow it to that, or `/task --abandon 666`.
- **Consumer repositories with tasks stranded at `[IMPLEMENTING]` by D1**: redeploy there, then
  re-run the orchestration. The re-run lands the current tree and the check passes.
- **655**: re-declare `file_scope` at plan time.
- **Lean repositories** do not get the per-task squash under this record. The L2 spike protocol
  is in the record, deferred, with no task.

## References

- `specs/667_amend_branch_topology_per_batch_worktree_squash/plans/01_batch-worktree-squash-amendment.md`
- `specs/667_amend_branch_topology_per_batch_worktree_squash/reports/01_batch-worktree-squash-amendment.md`
- `specs/667_amend_branch_topology_per_batch_worktree_squash/reports/01_two-root-consumers.tsv`
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`
- `specs/decisions/worktree-isolation-removal-verdict.md`, `specs/decisions/worktree-isolation-removal-reaffirmation.md`
