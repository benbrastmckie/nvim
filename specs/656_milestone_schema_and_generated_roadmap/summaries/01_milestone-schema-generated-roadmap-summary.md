# Implementation Summary: Task #656

- **Task**: 656 - Milestone schema in state.json and a wholly generated ROADMAP.md
- **Status**: [COMPLETED]
- **Started**: 2026-11-20T09:45:00Z
- **Completed**: 2026-11-20T12:03:51Z
- **Effort**: about 3.3 hours across three dispatches (9 of 9 phases)
- **Dependencies**: 654 (completed)
- **Artifacts**: plans/01_milestone-schema-generated-roadmap.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

All nine phases are complete and committed. `specs/ROADMAP.md` renders entirely from
`specs/state.json` in the three-part order (intro with the primary goals and a milestone status
table; one dashboard section per milestone with progress, review state and gate; rules,
conventions and repo context last), and no hand-authored section remains. The schema and
validator carry `primary_goals`, `roadmap_milestones[]` with nested batches, and
`roadmap_context`; a one-time migration with a hard losslessness gate moved this repository's
flat store and hand-authored file to the milestone shape; the advisory batch lint is retargeted
at state; and the pruning ledger and the lint's disposition are recorded in the source-store
documents. The sf1-engine acceptance render was produced on a copy and its judgment is mixed:
the first screen answers "what state are the milestones in", but a milestone whose work is held
reads empty and the review column has no writer (see Follow-ups).

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
- `agent-system/extensions/core/context/formats/roadmap-format.md` — rewritten as the generated design: three-part section order, field bounds, status tokens, the pruning ledger table, rejected alternatives, the sentinel-based refusal, the migration and its gate, parsing patterns
- `agent-system/extensions/core/context/formats/roadmap-entry-template.md` — milestone entry template with bounds added beside the nested batch template
- `agent-system/extensions/core/context/patterns/roadmap-update.md` — rewritten caller contract: five-verdict refusal predicate, preflight obligation, the four live callers and their arms, and the lint's single disposition (reads `roadmap_milestones[].batches[]`; call site the `LINT_SCRIPT` invocation in `orchestrate-conclusion-roadmap.sh`)
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — Step 5: `generated` arm, degrade on every other verdict, lint on both arms, resolved output path
- `agent-system/extensions/core/context/reference/state-management-schema.md` — the three keys, the nested batch shape, the flat keys as the unmigrated-store shape, the vault-renumbering residual
- `agent-system/extensions/core/context/standards/postflight-tool-restrictions.md`, `context/patterns/file-footprint-overlap.md` — verdict names and the lint's input corrected
- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`, `scripts/tests/run-all.sh`, `context/formats/plan-format.md` — numbered settled-decision citations re-anchored to `shell-script-testing.md`'s "Suite runtime" section
- `agent-system/extensions/core/scripts/lib/engine-written-state-paths-lib.sh` — comment describing the roadmap as user-maintained corrected
- `agent-system/extensions/core/index-entries.json` — `line_count` for nine context files, three summaries
- `agent-system/extensions/core/README.md`, `merge-sources/claudemd.md`, `docs/reference/utility-scripts-inventory.md`, `scripts/deprecated/README.md`, `context/patterns/orchestrate-batch-results-template.md`, `context/patterns/batch-orchestration-guardrails.md` — old-layout descriptions corrected; inventory row added for the migration (separate follow-up commit `b4683695a`)
- `specs/state.json` — migrated: flat `roadmap_batches`/`roadmap_notes` removed; one milestone `M1` holding the 30 batches; `primary_goals` (2), `roadmap_context.rules` (9), `.conventions` (19)
- `specs/ROADMAP.md` — generated (131,554 to 22,548 bytes), sentinel on line 1
- `specs/archive/roadmap-retained-prose.md` — Created: 288 lines of prose with no state field, verbatim
- `specs/656_milestone_schema_and_generated_roadmap/records/sf1-acceptance-{store.json,ROADMAP.md,judgment.md,retained-prose.md}`, `records/sf1-milestone-overlay.jq`, `records/archive/state.json` — Created: the sf1-engine acceptance copy, render and judgment
- `.claude/**` — redeployed from the source store (`deploy-headless.sh`, `RESULT=landed_verify_clean`)

## Decisions

- The flat keys stay in the schema and Check 13 names the migration whenever one is present (plan Decision 1).
- Check 13 owns member integrity; the lint no longer reports terminal or missing members.
- Suites are verified from the source store with `CORE_TEST_SUBJECT_MODE=source-store`, because `verify-touched.sh` executes the stale deployed copies.
- One render path for every store shape: a store with no milestone renders the intro, an empty-table note and the open-task list, rather than keeping a second code path.
- The migration invents no milestone boundary: every flat batch goes, unchanged, under one neutral milestone `M1`; dividing the work is left to `/roadmap`.
- The losslessness gate is a multiset equality over lines (source lines against retained lines plus the recorded lines of each state item), so both a dropped and a duplicated line fail. An existing retained-prose file is never overwritten, even with `--force`.
- The conclusion step never migrates and never creates the file; a hand-authored file degrades loudly and names the migration.

- The lint's disposition is retarget, not retire: only it reports an under-inclusive batch at authoring time, and that finding is as meaningful over state entries as over rendered lines.
- sf1-engine's batches were assigned M1 (four), M2 (one), M3 (two), M4 (none), following the report's overlay; no batch was invented for M4, because inventing one is roadmap-agent judgment.

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
- **Phase 8** altered: six files outside the plan's list were edited after the Scope Hypothesis search found old-layout text in them; `git-commit-phase.sh` dropped them as out of declared scope and they landed in a scoped follow-up commit.
- **Phase 8** altered: `verify-touched.sh` was not used (it runs the stale deployed suites before a redeploy); the resolver's selection was run from the source store. Gate 3 went green only after the Phase 9 redeploy.
- **Task 9.5** altered: the acceptance copy was built by running the real migration on the copy and then applying a jq milestone overlay; M0's closure date is inferred from the sf1-engine commit that first states it.
- **Task 9.7** altered: nine suites were run from the deployed tree instead of seven; `verify-touched.sh` exits 1 solely on one `known-failures.txt` EXPECTED suite.

## Verification

- Build: N/A
- Tests: Passed. From the deployed tree after the redeploy, 9 of 9: `test-roadmap-generation.sh`, `test-validate-state.sh`, `test-generate-task-order.sh`, `test-orchestrate-suggest-next-batch.sh`, `test-migrate-roadmap-next-to-state.sh` (the five named), `test-lint-roadmap-batch-proposals.sh`, `test-orchestrate-conclusion-roadmap.sh` (the two reached), `test-roadmap-entries-lib.sh`, `test-migrate-roadmap-to-milestones.sh` (the two new).
- Phase 8 scoped tier: 58 resolver-selected suites from the source store, 55 passed, 2 EXPECTED failures (`test-gate-cache-equivalence.sh`, `test-verify-deploy-context-budget.sh`, both `known-failures.txt` entries), 0 new; `test-common-lib.sh` 71/71.
- Phase 9 scoped tier: `verify-touched.sh` selected 110 suites, 108 passed, 1 skipped, 1 EXPECTED failure (`test-gate-cache-equivalence.sh`), 0 new; its fallback set passed 98/98. Its exit status is 1 because of that expected failure.
- `verify-deploy.sh --skip-slow --only-gate 3,4`: PASS after the redeploy. `check-task-references.sh`: PASS. `check-record-versioning.sh`: no finding on any line this task wrote (its 3 blocking findings are in `lua/neotex/plugins/tools/himalaya/docs/`).
- The complete gate set was NOT run in any dispatch: Phases 2, 5, 7, 8 and 9 were discharged against the scoped tier under the batch gate deferral and the full set is owed at the batch stage. Six documents resolved to no suite and are owed to that gate: `commands/review.md`, `context/patterns/file-footprint-overlap.md`, `context/patterns/orchestrate-batch-results-template.md`, `context/patterns/roadmap-update.md`, `context/standards/postflight-tool-restrictions.md`, `docs/reference/utility-scripts-inventory.md`.
- Migration on this repository: dry run twice, then real. 30 flat batches to 30 nested; `primary_goals` +2, `rules` +9, `conventions` +19; 11 over-bound items retained whole (3 checks, 7 settled decisions, 1 standing rule); losslessness gate PASSED (257 source lines = 217 retained + 40 in state; 18 `roadmap_notes` lines retained).
- Acceptance checks: `head -1 specs/ROADMAP.md` is the sentinel; the store has neither flat key and one milestone; a second `--regenerate --dry-run` reports `no content change`; `validate-state.sh` Check 13 passes with no flat-key warning.
- sf1-engine acceptance (on a copy; nothing written there): migration gate PASSED (30 source lines); render 41,618 to 9,133 bytes; judgment in `records/sf1-acceptance-judgment.md`.
- Files verified: Yes

## Impacts

- This repository's roadmap is one neutral milestone `M1` holding all 30 batches, so its dashboard table has a single row until a `/roadmap` pass divides the work into real milestones.
- Any other repository that receives this core extension and still holds a hand-authored roadmap stops regenerating it at `/orchestrate`'s conclusion step (loud degrade naming the migration) until `migrate-roadmap-to-milestones.sh` runs; `/roadmap`, `/todo` and `/review` offer it behind one approval. sf1-engine is in that position.
- Prose with no state field (gate state, unfiled observations, `roadmap_notes`, items over their bound) lives in `specs/archive/roadmap-retained-prose.md` and is not rendered.
- `roadmap-integration.sh --max-tasks` and the lint's `--roadmap` flag are gone; no script or command passed either.

## Follow-ups

- Run `/roadmap` here to divide `M1` into real milestones and to rewrite the eleven over-bound items (now only in the retained-prose file) as one-line conventions pointing at decision records.
- Design gap found by the acceptance render: a task joins a milestone only through a batch, and a batch is a dispatch proposal, so held or externally owned work cannot be shown under its milestone. In the sf1-engine render M4 reads `no batches yet` while its one task exists on hold, and M1's count omits the held task blocking its gate.
- Nothing writes `review` except a `/roadmap` judgment pass on explicit instruction; every review cell reads `none` until that is done. Whether a workflow step should record it is undecided.
- A `roadmap_annotation` suffix is appended after the 100-column title cut, so member lines can exceed 100 columns (16 do in the sf1-engine render).
- sf1-engine itself is not migrated; this task only rendered a copy.
- The root volume ran out of space once during this dispatch (457G, 98% used; `/tmp` holds about 38G in about 158,000 entries). Nothing was deleted. A parallel suite run was lost and rerun with three jobs.
- The lint emits one line per finding into every conclusion block; a per-batch count was suggested by the research report and not decided here.

## References

- specs/656_milestone_schema_and_generated_roadmap/plans/01_milestone-schema-generated-roadmap.md
- specs/656_milestone_schema_and_generated_roadmap/reports/01_milestone-schema-generated-roadmap.md
- specs/656_milestone_schema_and_generated_roadmap/handoffs/phase-8-handoff-20261120T110738Z.md
- specs/656_milestone_schema_and_generated_roadmap/records/sf1-acceptance-judgment.md
- agent-system/extensions/core/context/formats/roadmap-format.md (pruning ledger)
- agent-system/extensions/core/context/patterns/roadmap-update.md (lint disposition)
