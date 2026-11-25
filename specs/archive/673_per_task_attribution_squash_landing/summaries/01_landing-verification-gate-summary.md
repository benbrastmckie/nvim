# Implementation Summary: Task #673

- **Task**: 673 - Land one reviewable commit per completed task on the integration branch and verify it before the status write
- **Status**: [COMPLETED]
- **Started**: 2026-11-23T11:16:00Z
- **Completed**: 2026-11-23T14:55:00Z
- **Effort**: 3.7 hours
- **Dependencies**: 669 (completed)
- **Artifacts**: plans/01_landing-verification-gate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

A task's completion status can no longer be written unless a landing verification passes first.
`update-task-status.sh postflight <N> implement` now runs `task-landing-verify.sh` (V1 to V5)
ahead of its state write and exits 7, writing nothing, when the task's work is not verifiably
on the integration branch or work sits in the working tree that no commit carries. On a pass it
records one landing proof per task in the batch record. The `milestone-ref-land.sh` calls are
gone from postflight, and `milestone-review-handoff.sh` reads the integration branch and the
proofs. All seven phases are done and the tree is redeployed.

## What Changed

All paths are under `agent-system/extensions/core/` unless they start with `specs/`.

- `scripts/task-landing-verify.sh` — new. The predicate, the proof writer, `--check`,
  `--modified-files-from`, `--print-body`. Exit 0 pass, 2 usage, 10 V1, 11 V2, 12 V4, 13 V5.
- `scripts/update-task-status.sh` — PHASE 0.6 landing gate after the completion-deploy gate;
  exit 7 documented in the header table.
- `scripts/orchestrate-cycle-postflight.sh` — for an implemented dispatch the order is now:
  commit leftover work, status write (which runs the gate), per-cycle completion commit. Exit 7
  from the write sets `landing_refusal`. The completion commit's body carries the proof's phase
  list, commits, end commit and second-repository commits. The milestone calls are removed and
  the verdict key `milestone_landing` is now `landing`. WORK (h)'s comparison is the function
  `compute_scope_excursions`.
- `scripts/lib/batch-admission-lib.sh` — `batch_admission_record_for_task` and
  `batch_admission_append_landing_proof`.
- `scripts/milestone-review-handoff.sh` — steps 3 to 6 rewritten: resolves the integration
  branch, lists per task the completion subject, commit count and end commit from its proof,
  flags `shared_paths`, sets `review.ref` to `refs/heads/<integration branch>`.
- `scripts/milestone-ref-land.sh` — header only: a snapshot utility no lifecycle script calls.
- `context/standards/orchestrator-runtime-files.md` — the `landing_proofs` element shape.
- `context/patterns/ref-plumbing-landing.md` — a "The Landing Mechanism" section; the idiom
  stays documented.
- `manifest.json`, `scripts/tests/suite-classification.data` — two new suites registered, plus
  the missing row for `test-batch-admission-lib.sh`.
- `index-entries.json` — two `line_count` values corrected by the redeploy's auto-repair.
- Suites: new `scripts/tests/test-task-landing-verify.sh` (88 cases) and
  `scripts/tests/test-postflight-landing-gate.sh` (34 cases); extended
  `test-batch-admission-lib.sh`, `test-orchestrate-cycle-postflight.sh` (cases 993 to 997, the
  three landing groups); rewritten `test-milestone-review-handoff.sh`; one case repaired in
  `test-orchestrate-conclusion-roadmap.sh`.
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` — three dated
  `Amended by` notes. `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`
  — an appended "Implementation clarifications" section.

## Decisions

- **Attribution bound when `created` is absent.** 30 of 137 active tasks carry no `created`
  timestamp. Such a task is bounded by the oldest `admitted_at` among the batch records listing
  it. With neither, the predicate prints a named inconclusive line and passes through, because
  an unbounded match would attribute an earlier holder of a reused number.
- **Leftover commit scope.** It carries only reported paths outside the state territory that
  still differ from HEAD. Task-directory and state files stay in the completion commit.
  `proposed_file_scope` is merged into `file_scope` before the leftover commit, since the
  completion write that used to merge it now comes later.
- **Empty path set.** A task whose commits touch only the state territory passes with an empty
  path set; any recorded proof with an empty set makes a re-run a no-op.
- **`--check` and `--dry-run` take no mutex and write no proof.**
- **`review.ref`** is `refs/heads/<integration branch>`, resolved from the newest batch record
  listing a milestone task, else the declaration, else the branch HEAD names.

## Plan Deviations

- **Task 2.3** altered: fallback attribution bound for a task with no `created` (above).
- **Task 2.9** altered: also added the missing classification row for `test-batch-admission-lib.sh`.
- **Task 3.2** altered: leftover commit scope and the early `proposed_file_scope` merge
  (above); the refusal variable was renamed `landing_refusal` in Phase 3 instead of Phase 6.
- **Task 5.5** altered: no pre-existing fixture was refused by the gate, so none needed
  seeding. Their task entries have no `created` and no batch record, so the predicate is
  inconclusive for them. `test-update-task-status.sh` was not edited.
- **Task 6.2** altered: only the verdict key was renamed in Phase 6.
- **Phase 7** altered: `test-orchestrate-conclusion-roadmap.sh` Case H was repaired here. It
  asserted the milestone ref as `review.ref` and passed before the redeploy only because that
  suite resolves the deployed copy of the handoff script first. The path is outside the
  declared file list.
- **Verification method** altered in Phases 2 to 6: `verify-touched.sh` runs deployed copies
  and rejects undeployed suite names, so the same suite selections were run through the
  source-store `run-all.sh`. It was run as planned in Phase 7, after the redeploy.

## Verification

- Build: N/A
- Tests: the four owned criteria, each tied to evidence.
  - Criterion 1 (ruling before code): the ruling record exists and names the assertions it
    amends; Phase 1 added the three `Amended by` notes before any code commit.
  - Criterion 2 (one reviewable unit per task, phase list recorded, branch unchanged):
    `test-task-landing-verify.sh` "positive: two interleaved tasks" (one proof per task,
    completed phases in the proof, HEAD names the same branch), and
    `test-orchestrate-cycle-postflight.sh` case 997 end to end.
  - Criterion 3 (a failing task leaves commits and refs intact while its sibling lands):
    `test-task-landing-verify.sh` "negative V4" and "negative V5" (refs and batch record
    byte-identical, sibling passes).
  - Criterion 4 (no completion write without the verification): `test-postflight-landing-gate.sh`
    "negative: work left uncommitted". Observed writing `completed` with the gate's refusal
    disabled, then exit 7 with `specs/state.json` and the plan file byte-identical with it
    present. Both observations are in `issues.jsonl`, as are the six predicate fixtures'.
  - Phase 5 and Phase 7 are full-tier phases discharged at the scoped tier under the Batch
    Gate Deferral. The complete gate set was not run in this dispatch and is deferred to the
    batch-level stage.
  - Phase 7 `verify-touched.sh` against the redeployed tree: 80 suites selected, 76 passed, 1
    skipped, 3 failed; its owed fallback set passed 98 of 98. The three failures:
    `test-gate-cache-equivalence.sh` (expected by the runner);
    `test-orchestrate-conclusion-roadmap.sh` Case H (caused by this task, repaired, 35 of 35
    afterwards); `test-lint-unit-integration-boundary.sh` (not caused by this task, still red,
    see Follow-ups).
  - `sync-manifest-scripts.sh --check` passed. Deployed `check-task-references.sh`: 0
    occurrences. `check-record-versioning.sh` timed out at 150 seconds; the pattern library run
    directly over this task's 15 files found no blocking or advisory hit.
  - `skills/skill-orchestrate/SKILL.md` and `commands/orchestrate.md` are byte-identical to
    their state before the task.
- Files verified: Yes. The three deployed copies exist and the deployed
  `update-task-status.sh` equals the source copy.

## Impacts

- Every implement completion, through every caller, now passes the gate. This task's own
  completion is its first live run. The deployed predicate, run read-only, reports task 673
  verified; the expected proof lists this task's phase commits and its 16 source-store paths.
- V5 can refuse a correct completion while a sibling in the same working tree holds an
  uncommitted edit to a file this task also committed (`manifest.json` and
  `suite-classification.data` are the likely ones). The false-refusal rate is unmeasured.
- A task completed before the gate existed has no proof and cannot be re-verified once a
  dependent has edited its files: the deployed predicate refuses task 669 on V4, naming this
  task's commits. Its status write is a no-op, so nothing is blocked.
- The verdict JSON key is `landing`. Its only reader was the cycle-postflight suite.
- `stack_pr_submission_from_integration_branch` (685) receives the proof shape documented in
  `orchestrator-runtime-files.md`. No review ref is built here.

## Follow-ups

- `test-lint-unit-integration-boundary.sh` is red on four suites with no classification row
  that predate this task: `test-lean-challenge-observe.sh`, `test-sapience-remember.sh`,
  `test-sapience-tag-pending.sh`, `test-scope-excursion-record-lib.sh`. The batch-level gate
  will report it. Not fixed here.
- Not every task-creation path writes `created`. Until it does, a task with no `created` that
  is completed outside an admitted batch passes the gate as inconclusive.
- `orchestrate-stage5-postflight.sh` discards the status write's return code and still
  propagates a completion summary after a refusal (it does the same for exit 6). It has no
  live caller.
- `test-orchestrate-close-status-bind.sh` lacks its exec bit and is skipped by the runner.
- `git-workflow-narrative.md` and `conclusion-stage.md` still describe the milestone landing;
  they belong to `branch_topology_documentation_parity` (675).
- Measure V5 refusals over the first live batches.

## References

- Plan: `specs/673_per_task_attribution_squash_landing/plans/01_landing-verification-gate.md`
- Report: `specs/673_per_task_attribution_squash_landing/reports/01_isolation-off-landing-ruling.md`
- Ruling: `specs/decisions/isolation-off-landing-verification-and-review-time-squash.md`
- Progress and per-phase verification notes: `specs/673_per_task_attribution_squash_landing/progress/`
- Issue log: `specs/673_per_task_attribution_squash_landing/issues.jsonl`
