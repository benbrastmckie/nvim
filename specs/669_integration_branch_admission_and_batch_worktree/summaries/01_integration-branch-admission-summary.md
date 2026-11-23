# Implementation Summary: Task #669

- **Task**: 669 - Add integration-branch admission and the isolation declaration
- **Status**: [COMPLETED]
- **Started**: 2026-11-23T09:45:00Z
- **Completed**: 2026-11-23T10:52:34Z
- **Effort**: about 1.25 hours
- **Dependencies**: 517, 541, 667, 668 (all completed)
- **Artifacts**: plans/01_integration-branch-admission.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`orchestrate-cycle-plan.sh` now passes every `/orchestrate` invocation through an admission
gate before any dispatch is composed. The gate reads two new repo-level declarations,
`integration_branch` and `worktree_isolation`, refuses through the script's existing `stop`
object, and on admit writes one batch record per invocation at
`specs/.orchestration/batch/{session_id}.json`. All four plan phases are complete and the source
store is redeployed. Everything was built and verified with isolation off; worktree creation
stays with the held task `batch_worktree_creation_when_isolation_on`.

## What Changed

All paths are under `agent-system/extensions/core/`.

- `context/standards/repo-level-declarations.md` — two new sections, "The `integration_branch`
  Declaration" and "The `worktree_isolation` Declaration", plus Overview and See Also entries.
  States the three stop reasons, the exact state territory, that `off` is live and `batch` is
  declared but not implemented.
- `context/standards/orchestrator-runtime-files.md` — Class Table row for the batch record and a
  new "The batch record" section with its field table and the additive `isolation` object rule.
- `scripts/lib/batch-admission-lib.sh` — created. Declaration readers, the state-territory
  constant, the dirty-path listing, the predicate `batch_admission_evaluate`, the record writer.
- `scripts/lib/runtime-file-patterns.sh` — `runtime_batch_record_path` added.
- `scripts/orchestrate-cycle-plan.sh` — hard-sources the library; `cycle_plan_admission` runs
  after the plan-cache replay block and before `orchestrate_cycle_plan_main`.
- `scripts/tests/test-batch-admission-lib.sh` — created, 81 assertions over 19 cases, including
  doc-sync assertions against the schema document.
- `scripts/tests/test-orchestrate-cycle-plan.sh` — library list entry and Group 39 (28
  assertions) driving the real script in a temporary `git` repository.
- `scripts/tests/test-orchestrate-unwind-dispatch.sh`, `scripts/tests/test-force-phases.sh` —
  the new library staged in each suite's fixture.
- `manifest.json` — `provides.scripts` entries for the two new files.
- `index-entries.json` — `line_count` for the two documents (418 and 703).

## Decisions

- Both refusals (`off_integration_branch`, `dirty_primary_tree`) arm only when
  `integration_branch` is declared, following the amending record's "R5, amended" and
  "Isolation-off repositories (Option L1)" over the task description's unconditional wording.
  Undeclared gives one advisory on standard error on the first cycle.
- State territory is exactly `specs/`, `.claude-extensions.json`, `.memory/`. Only tracked
  changes count; untracked files never refuse.
- `worktree_isolation` is tested first and every cycle. `batch`, any other unrecognised value
  and any non-string refuse with `isolation_unimplemented`, naming the held work by slug. JSON
  `null` reads as undeclared.
- The branch test runs every cycle; the dirty test only while no batch record exists for the
  session. The record's existence is the first-cycle marker, which gives one record per
  invocation by construction.
- The record's `orchestration_id` is null: the cycle-plan script holds no orchestration id and
  no flag was added to obtain one.
- The record's `integration_branch` is null only when the key is undeclared and `HEAD` is
  detached. This was added to the field table during Phase 2.
- A project root that is not a `git` work tree skips silently, which is what keeps every
  pre-existing non-`git` suite sandbox unchanged.

## Plan Deviations

- **Task 3.6** altered: a third suite, `test-force-phases.sh`, also needed the library staged.
  It overlays source-store copies of individual libraries on a wholesale copy of the deployed
  `lib/` directory, and failed 7 assertions before the redeploy. The file is outside the task's
  declared `file_scope`; the phase commit dropped it and it landed in a scoped follow-up commit
  (`c20ae23c7`).
- **Phase 2 and Phase 3 verification** altered: the `verify-touched.sh` pass named in each
  Tier Justification was run once in Phase 4, after the redeploy, because the deployed suites
  exercise deployed copies. Per phase, the affected suites were run directly from the source
  store instead.
- **Phase 4** produced one extra green sub-step commit (`165ae4c1c`): the first redeploy landed
  with the shellcheck gate red on three SC2034 findings in the new library, and the new suite
  lacked its exec bit. Both were fixed and the redeploy repeated.
- The plan's instruction to run helpers from the source-store `scripts/` directory could not be
  followed for the guarded scripts, which refuse outside a deployed tree; the deployed copies
  were run against source-store paths.

## Verification

- Build: N/A
- Tests: Passed
  - `test-batch-admission-lib.sh`: 81 passed, 0 failed (source store, and through the deployed
    `run-all.sh`). Non-vacuity: dropping `.memory` from the constant fails 3 assertions.
  - `test-orchestrate-cycle-plan.sh`: 472 passed, 0 failed. Non-vacuity: with the admission call
    disabled, 13 assertions fail, all in Group 39.
  - `test-orchestrate-unwind-dispatch.sh` 21/0, `test-force-phases.sh` 36/0,
    `test-orchestrate-batch-gate.sh` 0 failed, `test-redeploy-checkpoint-promotion.sh` 17/0,
    `test-askuserquestion-rehome.sh` rc 0.
  - `verify-touched.sh` over the eleven touched paths against the redeployed tree: 75 suites
    selected; 73 passed in that run, 0 new failures. The other two did not give a real verdict
    there and were re-run individually after their causes were fixed, both green:
    `test-batch-admission-lib.sh` had been skipped for a missing exec bit (1 passed through
    `run-all.sh --only` after `chmod +x` and a redeploy), and `test-gate-cache-equivalence.sh`
    (a listed known load-sensitive suite) had timed out at 600 s and reported the shellcheck
    findings then still in `HEAD` (17 passed, 0 failed once the fix was committed).
  - Deploy: `deploy-headless.sh` result `landed_verify_clean` (fast gates).
  - Live `--dry-run` of the deployed cycle-plan script in this repository: one advisory naming
    `integration_branch`, `stop` null, no batch record written.
  - `sync-manifest-scripts.sh --check` rc 0; task-reference lint 0 findings; record-versioning
    lint 0 BLOCKING on every edited file.
  - `skills/skill-orchestrate/SKILL.md` 27,494 bytes and `commands/orchestrate.md` 21,496 bytes,
    both unchanged. `.claude-extensions.json` declares neither key.
- Files verified: Yes
- The complete gate set (`verify-deploy.sh` unflagged) was not run in this dispatch. Under the
  dispatch's Batch Gate Deferral it is deferred to the batch-level stage at the end of the
  invocation.

Where each owned criterion is pinned:

| Criterion | Pinned by |
|---|---|
| Off-branch or dirty primary tree refused at admission | library suite cases 4-8; cycle-plan suite Group 39 (c), (d), (e) |
| `worktree_isolation: batch` refused loudly, naming the held work | library suite cases 9-10; Group 39 (f) |
| Both schema rows present, live versus unimplemented stated | library suite case 19 (doc-sync); the two sections of `repo-level-declarations.md` |

## Impacts

- Every `/orchestrate` invocation in a repository that declares nothing now prints one advisory
  line on standard error per session and leaves one small untracked record under
  `specs/.orchestration/batch/`. Nothing is refused there.
- A repository that declares `integration_branch` is refused when another orchestration has
  uncommitted tracked work outside the state territory. The record rules this and no exemption
  was added.
- A refused invocation has already registered its session and queue entries; the skill's
  existing non-null `stop` handling releases them. That path was pinned at the script contract
  (non-null `stop`, zero dispatch rows), not observed end to end through the skill.
- Any future suite that sandboxes `orchestrate-cycle-plan.sh` with an explicit library list
  must stage `lib/batch-admission-lib.sh`.

## Follow-ups

- Task 669's stored `file_scope` still names `scripts/batch-worktree.sh` and
  `scripts/tests/test-batch-worktree.sh`, which belong to the held task 686, and does not name
  `scripts/tests/test-force-phases.sh` (proposed through `proposed_file_scope`).
- The two existing inline `integration_branch` readers in `milestone-ref-land.sh` and
  `milestone-review-handoff.sh` still use `git rev-parse --abbrev-ref HEAD`, which prints the
  literal `HEAD` when detached. Migrating them to the shared reader is in task 673's scope.
- `git-workflow-narrative.md` still describes the admission check as a consumer-owned concern;
  that sentence is task 675's to rewrite.
- `sync-manifest-scripts.sh --write` cannot see an untracked new script (it enumerates with
  `git ls-files`); `git add -N` on the path is needed first.

## References

- specs/669_integration_branch_admission_and_batch_worktree/plans/01_integration-branch-admission.md
- specs/669_integration_branch_admission_and_batch_worktree/reports/01_integration-branch-admission.md
- specs/decisions/batch-worktree-isolation-and-task-squash-landing.md ("R1, amended", "R5, amended", "Isolation-off repositories (Option L1)")
- specs/decisions/branch-topology-and-landing-strategy.md (ruling R4)
