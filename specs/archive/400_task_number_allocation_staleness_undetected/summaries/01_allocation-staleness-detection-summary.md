# Implementation Summary: Task #400

- **Task**: 400 - Task-number allocation staleness undetected
- **Status**: [COMPLETED]
- **Started**: 2026-10-17T00:00:00Z
- **Completed**: 2026-10-17T03:00:00Z
- **Effort**: ~4.5 hours
- **Dependencies**: 379 (already landed; imposed no wait)
- **Artifacts**: plans/01_allocation-staleness-detection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Landed two complementary layers that make the task-number allocation counter impossible to
desynchronize silently. A new archive-aware base-mode Check 12 in `validate-state.sh` FAILs when
`next_project_number` is not strictly greater than every `project_number` in use (unioning
`active_projects` with the sibling archive's terminal arrays), and the previously `--deep`-only
`project_number` uniqueness check is promoted to base mode. A new `--allocate-into NAME` flag in
`state-write.sh` binds the counter inside the same `specs/.scope-lock` mutex that guards the
write, refusing to issue a stale number and refusing a transform that allocates without advancing
the counter. Both layers are covered by the suites that already own their subjects, the source
store is redeployed, and the full gate set is clean.

## What Changed

- `agent-system/extensions/core/scripts/validate-state.sh` — added base-mode Check 12
  (archive-aware `next_project_number` staleness, unioning `active_projects` with the sibling
  archive's `archived_projects`/`abandoned_projects`/`completed_projects`), and promoted the
  `project_number` uniqueness check from `--deep`-only to base mode (byte-identical `log_fail`
  text; a pointer comment left at the old `--deep` site). Header check inventory, the base-shape
  guard's "Checks 4-11" references, and the `--archive`-mode "Checks 2-11" replacement-scope
  references were all updated to "Checks 4-12" / "Checks 2-12".
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — added a source-store-first
  `C12_VALIDATOR` resolution (grepped for `"Check 12"`) and seven new fixtures: (a) positive
  (counter > active max, no archive), (b) the 2026-10-13 incident shape, (c) the archive-array
  bound (true max in `completed_projects`, `archived_projects` holding a lower number), (d) the
  same shape one past the bound, (e) non-numeric counter, (f) the base-mode uniqueness promotion's
  regression guard, (g) the layer-agreement drift guard against a deployed `state-write.sh`. Also
  fixed a pre-existing regression: the suite's shared D6 archive fixture
  (`completed_projects` max 999210) made two unrelated pre-existing D6 fixtures
  (`d6-clean-fixture.json`, `d6-archived-fixture.json`) newly stale under the new Check 12; both
  counters were bumped to 999211. Refreshed the suite's header comment.
- `agent-system/extensions/core/scripts/state-write.sh` — added `--allocate-into NAME`: usage
  validation (jq-identifier shape, reserved `__alloc_` namespace, NAME-collision check against
  every name already bound via `--arg`/`--argjson`/`--argjson-file`, `--init` combination
  refusal), an archive-aware allocation prefix appended to `EFFECTIVE_FILTER` (identical combined
  max to `validate-state.sh`'s Check 12; `error()`-based stale-counter refusal), and a
  mutex-scoped counter-advance assertion on both the main write path and the `--dry-run` preview
  path. Updated the usage string, header flag documentation, exit-code list, and added a worked
  caller example.
- `agent-system/extensions/core/scripts/test-state-write-concurrency.sh` — added cases 10-14:
  concurrent-allocation serialization and uniqueness, the stale-counter refusal, the
  archive-aware bound (extending the suite's existing archive fixture), the counter-advance
  assertion (main and `--dry-run` paths), and the four usage refusals. Updated the header comment
  and exit-code count.
- Source store redeployed to the `.claude/` tree (`deploy-headless.sh`, `RESULT=landed_verify_clean`).

## Decisions

- Both layers were adopted as planned: the validator detects staleness however it arose (hand
  edit, a caller that never migrates, a dropped increment), and the allocator is the only thing
  that can close the read-then-write race between two concurrent, individually-correct callers.
- Per-caller migration of the seven hand-rolled allocation sites was excluded, as planned (each
  carries non-terminal claimants requiring dependency edges this record did not add).
- Coverage landed in the two existing suites that own `validate-state.sh` and `state-write.sh`
  respectively, rather than a new test file (avoids a `manifest.json` registration requirement).

## Plan Deviations

- **Phase 3** (unplanned, but anticipated by the plan's own risk table): the pre-existing
  `d6-clean-fixture.json`/`d6-archived-fixture.json` fixtures in `test-validate-state.sh` shared an
  archive fixture (`completed_projects` max 999210) that made their own counters (999103, 999201)
  newly stale once Check 12 landed. Bumped both to 999211. See `progress/phase-3-progress.json`.
- **Phase 6**: the whole-corpus `bash agent-system/extensions/core/scripts/tests/run-all.sh` sweep
  (158 suites, no `--only` filter) was deferred to the batch-level stage per this dispatch's own
  Batch Gate Deferral directive, rather than run independently by this dispatch. Discharged
  instead via the complete 37-gate `deploy-headless.sh` self-verify (`RESULT=landed_verify_clean`)
  plus a scoped `run-all.sh --only` run covering this task's own two touched suites and four
  one-hop dependents (6/6 PASS). See `progress/phase-6-progress.json`'s `batch_gate_deferral_note`.

## Verification

- Build: N/A (bash scripts; `bash -n` syntax-checked after every edit)
- Tests: `test-validate-state.sh` 70/70 PASS; `test-state-write-concurrency.sh` 14/14 PASS
  (cases 1-9 unregressed); `test-init-specs.sh` 23/23 PASS; scoped `run-all.sh --only` (6 suites)
  6/6 PASS
- Negative controls: removing the staleness refusal from the Check 12/`--allocate-into` bound
  expression made the matching fixtures/cases FAIL as expected (then restored, byte-identical);
  removing the `state-write.sh` counter-advance assertion made case 13 FAIL as expected (then
  restored); restricting the archive union to a single array made the archive-array fixtures FAIL
  as expected (then restored)
- Live tree: `validate-state.sh specs/state.json` and `--deep` both exit 0 (counter 444 > active
  max 443 > archive max 392)
- Full gate: `deploy-headless.sh` → `RESULT=landed_verify_clean` (37/37 checks); `verify-deploy.sh
  --only-gate 10` → PASS
- Files verified: Yes

## Impacts

- Any future allocation via `state-write.sh --allocate-into` is serialized under the same mutex
  as the write and cannot issue a duplicate or already-stale number.
- A stale `next_project_number` is now a FAIL-level finding of an ordinary (base-mode)
  `validate-state.sh` run, and therefore of `verify-deploy.sh` gate 10 — detectable before the
  next allocation, not only after a collision already exists.
- An existing duplicate `project_number` in `active_projects` is now reported by a plain run, not
  only under `--deep`.
- No existing base-mode consumer newly blocks (see the Phase 6 consumer audit in
  `progress/phase-6-progress.json`): only `verify-deploy.sh` gate 10 and `test-init-specs.sh`
  actually consult the exit status, and both pass; every other enumerated caller either only
  mentions `validate-state.sh` in a comment or structurally discards the exit status before use.

## Follow-ups

- Migrate the seven hand-rolled per-caller allocation sites (`commands/task.md`,
  `commands/review.md`, `skills/skill-spawn/SKILL.md`, `skills/skill-fix-it/SKILL.md`,
  `skills/skill-project-overview/SKILL.md`, `agents/meta-builder-agent.md`,
  `context/contracts/conclusion-stage.md` Step 4c) to call `--allocate-into` instead of
  re-implementing read-then-increment. Each file's existing claimants and required dependency
  edges are recorded under the plan's Decisions section; a conclusion-stage-specific instance of
  this migration is already filed and dependency-linked as a separate record (see the dispatch
  description's "CAUSAL CHAIN" section).
- Document the allocation-under-mutex convention in `context/patterns/task-lock.md` (claimed by
  a separate, not-started record; adding it here would have been an unordered overlap).
- The whole-corpus `run-all.sh` sweep deferred at Phase 6 runs once at the batch level; no
  independent action needed from a future reader beyond checking that batch's own result.

## References

- `specs/400_task_number_allocation_staleness_undetected/plans/01_allocation-staleness-detection.md`
- `specs/400_task_number_allocation_staleness_undetected/reports/01_allocation-staleness-detection.md`
- `specs/400_task_number_allocation_staleness_undetected/progress/phase-{1..6}-progress.json`
