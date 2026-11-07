# Implementation Summary: Task #328

- **Task**: 328 - Systematic top-to-bottom consolidation of the shell script and test corpus under `agent-system/extensions/**`
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-05T01:25:00Z
- **Completed**: 2026-11-05T02:55:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: None live (170 and 411 both completed; 416 and 431 are coordination/downstream surfaces, not dependencies)
- **Artifacts**: plans/03_markdown-corpus-consolidation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed Phase 8 ("Harness Migration Tranche C — Complete the Corpus"), the final tranche of the
test-corpus harness migration begun in Phases 4/6/7. All 56 suites remaining in the core
extension's unmigrated pool — including the corpus's two largest suites — are now migrated onto
`lib/common.sh`'s shared test harness, closing that migration for the entire core
`scripts/tests/` corpus with zero reasoned exemptions needed.

## What Changed

- 52 suites under `agent-system/extensions/core/scripts/tests/` — migrated via one mechanical
  script: removed local `pass()/fail()/info()`, inserted `source "$SCRIPT_DIR/../lib/common.sh"`,
  renamed call sites to `common_test_pass/_fail/_info`.
- `test-gate-lock.sh`, `test-task-lock-queue.sh`, `test-orchestrate-batch-admit.sh` — hand-migrated
  (colored-ANSI pass/fail/info variant); also removed now-unused `RED`/`GREEN`/`YELLOW`/`NC`
  color-code variable definitions.
- `test-common-lib.sh` — migrated its own real top-level harness calls; left its `BAD_FIXTURE`
  heredoc's deliberate local pass/fail/info redefinition untouched (a later case in the same
  suite asserts that redefinition IS detected).
- 29 occurrences (two bracket-shape variants) of the git-aware `REPO_ROOT` fallback block
  collapsed to `common_test_repo_root "$SCRIPT_DIR"`.
- 39 occurrences (two bracket-shape variants) of the `WORKDIR`/`cleanup()`/`trap` triplet
  collapsed to `common_test_workdir_init`.
- `test-phase-heartbeat.sh`, `test-task-lock-liveness.sh` — opportunistic fix: removed dangling
  `RED`/`GREEN`/`YELLOW`/`NC` definitions left unused by an earlier phase's migration (an SC2034
  shellcheck regression, found via this phase's own redeploy-and-verify step).
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — "Existing suites"
  note rewritten to record the core-extension harness migration as closed, with no exemption
  list needed.
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`
  — Phase 8 checklist annotated complete; NET-TEST delta and cumulative figure recorded.

## Decisions

- Added a second mechanical pass (REPO_ROOT/WORKDIR boilerplate collapse) after the first pass's
  net (-39) came in far below Phase 6/7's per-suite average; traced the gap to this missing
  collapse step rather than accepting the smaller net.
- Fixed two pre-existing SC2034 shellcheck findings (from an earlier phase's migration) as an
  opportunistic deviation since they were blocking the deploy gate and trivial to fix.
- Verified per-suite output identity using each suite's own authoritative `Passed: N`/`Failed: N`
  tally line, not a naive per-line `[FAIL]`-substring count, after the latter produced a false
  positive traced to an already-known-broken diagnostic case's live-repo-scan sub-text varying
  with deploy freshness and concurrent-sibling-task untracked files.

## Plan Deviations

- **Task 8.1** altered: opportunistically removed two dangling color-variable definitions left
  behind by an earlier phase's migration (`test-phase-heartbeat.sh`, `test-task-lock-liveness.sh`)
  — unrelated to this phase's own 56-suite tranche, but within the task's file_scope, trivial, and
  blocking the deploy gate's shellcheck check.

## Verification

- Build: N/A
- Tests: `run-all.sh --only <56-suite tranche>` and full repo-wide `run-all.sh` (167 suites) both
  green except for the same 8 pre-existing failures (2 known-expected, 6 confirmed unrelated via
  a standalone pre-edit recheck). Every touched suite's own Passed/Failed tally is byte-identical
  across three separate before/after captures.
- Files verified: Yes (`bash -n` on all 56 touched files; deploy-headless.sh clean redeploy,
  `RESULT=landed_verify_clean`).

## Impacts

- The core extension's test-harness migration is now closed: a future new suite under
  `agent-system/extensions/core/scripts/tests/` that reimplements `pass()/fail()/info()` is a
  regression against this closure, not a holdout awaiting its turn.
- NET-TEST this phase: insertions=5365, deletions=5553, net=-188. Cumulative NET-TEST (phases
  3-8, each phase's own isolated `git diff --numstat` delta): -291 against the Phase 1 baseline —
  short of the -1,200 floor, consistent with the plan's own note that Phase 13 (shared deployed-
  tree fixture) is expected to carry the bulk of the test-corpus floor.
- A commit-pipeline defect (`git-commit-phase.sh`'s containment self-check dropping paths under a
  trailing-slash `file_scope` directory entry) recurred for the second time in this task; recorded
  as an issue with a recommendation for a follow-up task, not fixed here (outside this task's own
  file_scope).

## Follow-ups

- Phases 9-20 of this plan remain `[NOT STARTED]` — Phase 9 (install/uninstall pair dedup) is
  next.
- `git-commit-phase.sh`'s trailing-slash containment-glob defect (recurred twice now) should be
  fixed by a follow-up task outside this one's file_scope.
- Two untracked files observed throughout this phase (confirmed pre-existing, owned by other
  concurrent batch tasks, not touched): `agent-system/extensions/core/scripts/gate-cost-model.csv`,
  `agent-system/extensions/lean/scripts/tests/fixtures/challenge/plan_goals_preamble.md`.

## References

- Plan: `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`, Phase 8 and Phase 9 sections
- Progress: `specs/328_systematic_script_and_test_corpus_efficiency/progress/phase-8-progress.json`
- Handoff: `specs/328_systematic_script_and_test_corpus_efficiency/handoffs/phase-8-handoff-20261105T025305Z.md`
- Standards: `agent-system/extensions/core/context/standards/shell-script-testing.md`
