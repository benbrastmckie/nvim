# Implementation Summary: Task #656

- **Task**: 656 - Milestone schema in state.json and a wholly generated ROADMAP.md
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-20T09:45:00Z
- **Completed**: 2026-11-20T10:23:00Z
- **Effort**: 0.7 hours this dispatch (3 of 9 phases)
- **Dependencies**: 654 (completed)
- **Artifacts**: plans/01_milestone-schema-generated-roadmap.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Phases 1-3 of nine are complete and committed: the state schema and validator carry the
milestone layer, one sourced accessor answers the ordered batch list for both store shapes, and
the advisory batch lint reads state entries instead of the rendered file. The renderer, the
migration, the removal of the hand-authored render paths, the agent/command/format text, the
recorded pruning ledger, the redeploy, this repository's migration and the sf1-engine acceptance
render (Phases 4-9) are not started. The dispatch stopped at a clean phase boundary under
context pressure; no acceptance criterion of the task is met yet.

## What Changed

- `agent-system/extensions/core/context/schemas/state-schema.json` — added `primary_goals`, `roadmap_milestones`, `roadmap_context`, `definitions.roadmapMilestoneEntry`, a 140-character bound on `roadmap_annotation`; reworded the flat keys as the unmigrated-store shape
- `agent-system/extensions/core/scripts/validate-state.sh` — three new known top-level fields; Check 13 extended to the milestone shape (archive-aware member resolution, closed-milestone rules, id/title/aim checks, flat-key WARN naming the migration)
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — nested Check 13 fixtures (firing and clean per sub-condition), extended field-drift fixture
- `agent-system/extensions/core/scripts/lib/roadmap-entries-lib.sh` — Created: accessor for the ordered batch list, the store shape and the output path
- `agent-system/extensions/core/scripts/tests/test-roadmap-entries-lib.sh` — Created: 19-case unit suite
- `agent-system/extensions/core/scripts/orchestrate-suggest-next-batch.sh` — `read_roadmap_batches()` reads through the accessor; a nested batch is labelled with its milestone
- `agent-system/extensions/core/scripts/tests/test-orchestrate-suggest-next-batch.sh` — fixtures converted to the nested shape; flat-fallback and closed-milestone cases added
- `agent-system/extensions/core/manifest.json`, `agent-system/extensions/core/scripts/tests/suite-classification.data` — registered the new lib and suite
- `agent-system/extensions/core/scripts/lint/lint-roadmap-batch-proposals.sh` — reads state through the accessor; findings (a), (c) and a field-scoped (f) kept, the terminal-member finding removed, `--roadmap` removed
- `agent-system/extensions/core/scripts/tests/test-lint-roadmap-batch-proposals.sh` — rewritten against state fixtures
- `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh` — the lint runs on every verdict arm
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` — sandbox completed so the lint actually runs; two assertions pin it

## Decisions

- The flat keys stay in the schema and Check 13 names the migration whenever one is present (plan Decision 1).
- Check 13 owns member integrity; the lint no longer reports terminal or missing members.
- Suites are verified from the source store with `CORE_TEST_SUBJECT_MODE=source-store`, because `verify-touched.sh` executes the stale deployed copies.

## Plan Deviations

- **Task 2.x** altered: Phase 2's commit also fixed two lint defects in Phase 1's `test-validate-state.sh` (a task-reference-shaped comment and an unused local) that surfaced only in Phase 2's wider suite selection.
- **Phase 3** altered: the old lint suite's real-corpus default-resolution case was not carried over.
- Phases 4-9 not executed in this dispatch (context pressure); see the handoff.

## Verification

- Build: N/A
- Tests: Passed for phases 1-3 only. Phase 1: nine selected suites, 9 passed. Phase 2: 38 selected suites, 34 passed on the first run; three failures were resolved and re-run green (one was an artifact of the test-mode override, one needed the new files tracked, one was the Phase 1 wording defect); the fourth, `test-gate-cache-equivalence.sh`, is a `known-failures.txt` entry and was not re-run after its two named sub-causes were fixed. Phase 3: three suites, 3 passed. The full gate set was deferred to the batch stage for Phase 2 and was not run in this dispatch.
- Files verified: Yes (phases 1-3)
- Not verified: anything in Phases 4-9; the deployed tree, which has not been redeployed and still runs the pre-change scripts.

## Impacts

- Until a redeploy, `/orchestrate` and `/roadmap` in this repository keep running the deployed pre-change scripts; the source store and the deployed tree now differ for `core`.
- After a redeploy and before Phases 4-6 land, the renderer still emits the classic layout from the flat keys; the validator will WARN on this store's flat keys.
- The conclusion step's outcome block now prints the lint's findings on the degrade arm as well; on this store that is 396 advisory lines.

## Follow-ups

- Resume at Phase 4 via the handoff; Phases 4-9 remain.
- The sf1-engine acceptance render (the task's final acceptance check) has not been attempted.

## References

- specs/656_milestone_schema_and_generated_roadmap/plans/01_milestone-schema-generated-roadmap.md
- specs/656_milestone_schema_and_generated_roadmap/reports/01_milestone-schema-generated-roadmap.md
- specs/656_milestone_schema_and_generated_roadmap/handoffs/phase-4-handoff-20261120T102300Z.md
