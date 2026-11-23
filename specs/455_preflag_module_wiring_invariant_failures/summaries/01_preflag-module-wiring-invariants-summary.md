# Implementation Summary: Task #455

- **Task**: 455 - Preflag module-wiring invariant failures in generated-surface appending
- **Status**: [COMPLETED]
- **Started**: 2026-11-22T00:00:00Z
- **Completed**: 2026-11-22T01:20:00Z
- **Effort**: ~1.25 hours
- **Dependencies**: 446 (landed); 435, 448, 328 (serialization-only, operator-liftable)
- **Artifacts**: plans/01_preflag-module-wiring-invariants.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Re-validated, at implementation time, the plan's premise that `plan-file-scope-harvest.sh`'s
generated-surface appending stage already correctly computes and persists both of the cited
missing surfaces for the real BimodalLogic incident, and that the dispatch-prompt channel is
still blind to a task's own `file_scope`. Both agreed exactly with the plan-time figures, so no
behavioural change was made. Recorded the part-(1) finding and the part-(2) NO ruling durably in
the harvester's own header comment, and pinned the cited module-wiring shape, the inert
(capability-gate-closed) case, and append-only behaviour with a new Case 30 in the existing
suite. Deployed the source-store edits and discharged the full verification tier via this
dispatch's Batch Gate Deferral directive.

## What Changed

- `agent-system/extensions/core/scripts/plan-file-scope-harvest.sh` — `Generated-surface
  appending:` header comment rewritten: states the stage's actual reach (appends forced surfaces
  into the harvested array; `--file-scope-add` persists the merged array into the task's
  `file_scope` at the `[PLANNING] -> [PLANNED]` transition), what it does NOT reach (no mid-phase
  cue to an implementer; a gate collision can still occur even when the append works correctly),
  names `context/formats/plan-format.md`'s "Coupled-generated-surface declaration obligation" as
  the channel that does reach an implementer, and adds a `Deliberately not appended:` paragraph
  recording the part-(2) ruling (NO) with its reasoning and two sanctioned alternatives.
  Comment-only; no executable line changed.
- `agent-system/extensions/core/scripts/tests/test-plan-file-scope-harvest.sh` — added Case 30:
  the cited module-wiring shape (a new-module `.lean` path declared in one phase, its own README
  plus a `docs/theorem-index.md` ledger update declared in a second phase) against a fake repo
  whose root README carries the real consumer-repository marker spelling (`dir=FormalSystem
  rows=totals desc=no`); asserts both claimed-missed surfaces are appended, that all three
  declared paths survive (append-only), and that the same fixture under a capability-gate-closed
  repo appends nothing (inert case). Suite: 51 passed, 0 failed.
- Deployed `.claude/` tree regenerated via `deploy-headless.sh` (gitignored, not committed).

## Decisions

- Part (1): both offered hypotheses in the original dispatch ("the wiring edit harvested no
  `.lean` path" and "the ancestor-chain walk missed the new module's READMEs") are falsified. The
  stage computes both claimed-missed surfaces correctly for the cited shape; the real residual
  is a pipeline-visibility gap in `orchestrate-build-dispatch.sh` (the implement-dispatch
  composer does not read the dispatching task's own `file_scope`), which is outside this record's
  two declared files.
- Part (2): ruling is NO for all four exemplars (lint-suppression allowlist entry, identifier
  rename, suppression-reason comment, per-ledger-row doc-comment obligation). The stage appends
  PATHS a mechanical regeneration overwrites; all four are CONTENT obligations whose required
  content cannot be computed from a plan's declared paths without running the lint, naming, or
  ledger check itself. Two sanctioned alternatives are named in the header: a repository's own
  `coupled_generated_surfaces` declaration for a genuine trigger-glob-to-path coupling, and the
  consumer repository's own human-facing wiring documentation for a content obligation.
- Part (3): no consumer-repository file was touched or proposed for edit.
- The recurrence count ("this has happened twice independently") was omitted from the rewritten
  header rather than restated, since it is not re-measurable from this repository.

## Plan Deviations

- None (implementation followed plan).

## Verification

- Build: N/A (bash scripts, no build step).
- Tests: Passed — `test-plan-file-scope-harvest.sh` 51/51 (including the three new Case 30
  assertions); `run-all.sh --only test-plan-file-scope-harvest.sh` green against the deployed
  tree; `deploy-headless.sh`'s own internal `verify-deploy.sh` pass green (41 checks, 0
  failures); the full tier discharged via this dispatch's Batch Gate Deferral directive using the
  canonical no-argument `verify-touched.sh` invocation (60 suites selected, 98 passed, 0 failed,
  5 OWED across 17 touched paths — the complete gate set is deferred to the once-per-batch close,
  not independently run here).
- Files verified: Yes — both deployed copies diff empty against the source store; the
  real-incident reproduction against the live BimodalLogic checkout is byte-identical before and
  after the edit, confirming no behaviour change.

## Impacts

- No consumer repository is affected: the harvester's output is unchanged for every input.
- Future readers of `plan-file-scope-harvest.sh` now have an accurate statement of what the
  generated-surface stage reaches, what it does not, and a recorded ruling against widening it
  for lint/naming/suppression/ledger-row obligations, closing this subject without manufacturing
  a fix where none was needed.

## Follow-ups

- The residual pipeline-visibility gap is real but out of this record's scope: a correctly
  appended surface in a task's `file_scope` is not itself surfaced to the implement-dispatch
  prompt (confirmed: `orchestrate-build-dispatch.sh` contains exactly one `file_scope` reference,
  a sibling-batch comment, not a read of the dispatching task's own `file_scope`). This is
  recommended as a candidate for a future, separately-scoped record against
  `orchestrate-build-dispatch.sh`'s dispatch-prompt composition — not filed autonomously here,
  per this record's own non-goals.

## References

- Plan: `specs/455_preflag_module_wiring_invariant_failures/plans/01_preflag-module-wiring-invariants.md`
- Report: `specs/455_preflag_module_wiring_invariant_failures/reports/01_preflag-module-wiring-invariants.md`
- Progress files: `specs/455_preflag_module_wiring_invariant_failures/progress/phase-{1,2,3}-progress.json`
