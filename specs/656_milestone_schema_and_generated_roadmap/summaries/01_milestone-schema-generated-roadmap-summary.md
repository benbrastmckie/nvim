# Implementation Summary: Task #656

- **Task**: 656 - Milestone schema in state.json and a wholly generated ROADMAP.md
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-20T09:45:00Z
- **Completed**: 2026-11-20T11:08:23Z
- **Effort**: about 2.2 hours across two dispatches (7 of 9 phases)
- **Dependencies**: 654 (completed)
- **Artifacts**: plans/01_milestone-schema-generated-roadmap.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Phases 1-7 of nine are complete and committed. The state schema and validator carry the
milestone layer; `roadmap-integration.sh` renders the whole file from state in the three-part
order (intro, one dashboard section per milestone, rules and context last) and refuses any file
it did not generate; a one-time migration moves a flat store and a hand-authored file to the
milestone shape behind a hard losslessness gate; the advisory lint reads state; and the agent,
skill and command text describe the generated-only file. Not done: the format, contract and
reference documents with the recorded pruning ledger and lint disposition (Phase 8), and the
redeploy, this repository's own migration and the sf1-engine acceptance render (Phase 9). The
task's acceptance criteria are therefore NOT yet met: this repository's `specs/ROADMAP.md` is
still the hand-authored classic file and its store is still flat, because the change exists only
in the source store. The dispatch stopped at a clean phase boundary under context pressure.

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
- `agent-system/extensions/core/scripts/tests/test-orchestrate-conclusion-roadmap.sh` — sandbox completed so the lint actually runs; fixtures moved to a generated stale file; a refused-classic degrade case and a resolved-output-path case added (26 cases)
- `agent-system/extensions/core/scripts/lib/roadmap-preflight-lib.sh` — the generated sentinel constant; `generated` verdict tested first; the scaffold writes the sentinel line alone onto an absent path and refuses every existing file
- `agent-system/extensions/core/scripts/roadmap-integration.sh` — rewritten (1,064 to 542 lines): one whole-file render for every store shape; overwrites only a generated file, creates one only when a milestone exists, refuses hand-authored files naming the migration; output path through the accessor; `--max-tasks`, the classic and stage round-trips, the coverage appendix and the `generate-task-order.sh` call removed
- `agent-system/extensions/core/scripts/tests/test-roadmap-generation.sh` — rewritten against the sentinel model (79 cases)
- `agent-system/extensions/core/scripts/migrate-roadmap-to-milestones.sh` — Created: one-time migration with a multiset losslessness gate that runs before any write
- `agent-system/extensions/core/scripts/tests/test-migrate-roadmap-to-milestones.sh` — Created: 20-case suite
- `agent-system/extensions/core/scripts/orchestrate-conclusion-roadmap.sh` — regenerates and commits only on `generated`, at the accessor-resolved path; every other verdict degrades and a hand-authored file's summary names the migration
- `agent-system/extensions/core/agents/roadmap-agent.md` — milestone decisions, field bounds, completed members kept while a milestone is open, `review` written only on explicit instruction, `rationale` a working note that is not rendered; `roadmap_notes` removed
- `agent-system/extensions/core/skills/skill-roadmap/SKILL.md`, `commands/roadmap.md`, `commands/todo.md`, `commands/review.md` — the generated three-part file; on a hand-authored file the migration's dry run, one approval question, then the migration; resolved output path and retained-prose file staged
- `agent-system/extensions/core/agents/planner-agent.md` — the roadmap-flag closing phase regenerates instead of ticking items in the file

## Decisions

- The flat keys stay in the schema and Check 13 names the migration whenever one is present (plan Decision 1).
- Check 13 owns member integrity; the lint no longer reports terminal or missing members.
- Suites are verified from the source store with `CORE_TEST_SUBJECT_MODE=source-store`, because `verify-touched.sh` executes the stale deployed copies.
- One render path for every store shape: a store with no milestone renders the intro, an empty-table note and the open-task list, rather than keeping a second code path.
- The migration invents no milestone boundary: every flat batch goes, unchanged, under one neutral milestone `M1`; dividing the work is left to `/roadmap`.
- The losslessness gate is a multiset equality over lines (source lines against retained lines plus the recorded lines of each state item), so both a dropped and a duplicated line fail. An existing retained-prose file is never overwritten, even with `--force`.
- The conclusion step never migrates and never creates the file; a hand-authored file degrades loudly and names the migration.

## Plan Deviations

- **Task 2.x** altered: Phase 2's commit also fixed two lint defects in Phase 1's `test-validate-state.sh` (a task-reference-shaped comment and an unused local) that surfaced only in Phase 2's wider suite selection.
- **Phase 3** altered: the old lint suite's real-corpus default-resolution case was not carried over.
- **Task 4.4** altered: a member absent from `active_projects` counts as done when it appears in any archive list, not only `completed_projects`; an active entry wins over an archive entry with the same number.
- **Task 4.3** altered: an open milestone with no batches renders `no batches yet` instead of 0/0 counts, and a done batch renders as one line with no member lines.
- **Task 5.6** altered: the retained-prose file is written before state, not after, so no prose exists only in memory once state has changed.
- **Task 5.8** altered: the gate-failure case injects its unaccounted line through a header-shaped `roadmap_notes` string, not a test-only hook in the script.
- **Task 6.1** altered: `render_open_work`, `topic_title` and the `--max-tasks` flag were removed as dead code; two context documents still mention the flag until Phase 8.
- **Task 6.3** altered: the scaffold writes only onto an absent path and refuses an unrecognised file, routing it to the migration.
- **Task 7.2** altered: an absent roadmap always proceeds without a question, because the generator itself writes nothing until a milestone exists.
- Phases 8-9 not executed (context pressure); see the handoff.

## Verification

- Build: N/A
- Tests: Passed for phases 1-7, all run from the source store, never from the deployed tree. Phase 4: 7 suites, 7 passed. Phase 5: 38 selected suites, 37 passed, 1 EXPECTED failure (`test-gate-cache-equivalence.sh`, a `known-failures.txt` entry), 0 new. Phase 6: 10 suites, 10 passed. Phase 7: 30 selected suites, 29 passed, 1 EXPECTED failure (`test-verify-deploy-context-budget.sh`, whose findings were deployed-tree drift), 0 new. Phases 1-3 as recorded in their progress files.
- The complete gate set was NOT run: Phases 2, 5 and 7 were discharged against the scoped tier under the batch gate deferral and the full set is owed at the batch stage. `commands/review.md` resolved to no suite and is owed to that gate.
- `verify-deploy.sh --only-gate 4` (task-reference lint) passes. Gate 3 (doc lint) was not run to green and cannot be before the redeploy: it reports deployed-script drift and a `line_count` mismatch.
- The migration was exercised only on fixtures and, as a dry run, on a scratch copy of this repository's roadmap and state (gate passed: 257 source lines = 217 retained + 40 in state; 30 batches nested; 11 over-bound items retained whole). It has NOT been run for real on this repository.
- Files verified: Yes (phases 1-7)
- Not verified: Phases 8-9; the deployed tree; the five named suites run from the deployed tree; the sf1-engine acceptance render, which has not been attempted.

## Impacts

- Until a redeploy, `/orchestrate` and `/roadmap` in this repository keep running the deployed pre-change scripts against the classic file; the source store and the deployed tree differ for `core`.
- After a redeploy, any repository whose roadmap file is hand-authored stops regenerating it until the migration runs: `/orchestrate`'s conclusion step degrades loudly on every run and names the migration; `/roadmap`, `/todo` and `/review` offer it behind one approval. Redeploy and migrate back to back.
- `roadmap-integration.sh --max-tasks` is gone; no script or command passed it.
- After migration, prose with no state field (gate state, unfiled observations, `roadmap_notes`, items over their bound) lives only in the retained-prose file and is no longer rendered.

## Follow-ups

- Resume at Phase 8 via the handoff; Phases 8-9 remain.
- The pruning ledger and the lint disposition are implemented but not yet RECORDED in the source store documents (Phase 8), which the task names as deliverables.
- `merge-sources/claudemd.md` still describes `/roadmap` in terms of the flat keys and is outside the plan's Phase 8 file list; the handoff asks the successor to add it.
- Eleven of this repository's items exceed their field bound and will sit in the retained-prose file after migration until rewritten by hand or by a `/roadmap` pass.

## References

- specs/656_milestone_schema_and_generated_roadmap/plans/01_milestone-schema-generated-roadmap.md
- specs/656_milestone_schema_and_generated_roadmap/reports/01_milestone-schema-generated-roadmap.md
- specs/656_milestone_schema_and_generated_roadmap/handoffs/phase-8-handoff-20261120T110738Z.md
