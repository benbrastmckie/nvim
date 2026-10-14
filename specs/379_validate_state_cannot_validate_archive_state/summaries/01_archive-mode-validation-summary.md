# Implementation Summary: Task #379

- **Task**: 379 - Make specs/archive/state.json validatable by validate-state.sh
- **Status**: [COMPLETED]
- **Started**: 2026-10-14T15:24:01Z
- **Completed**: 2026-10-14T18:15:00Z
- **Effort**: 4.5 hours (estimated); implementation ran all 6 phases
- **Dependencies**: None
- **Artifacts**: plans/01_archive-mode-validation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`validate-state.sh` previously had no code path for `specs/archive/state.json`'s shape: Check 2
correctly FAILed on the two missing required top-level fields, but Checks 4-11 all silently
false-PASSed because their `jq` pipelines over `.active_projects[]` errored into zero output
lines, which the script's own counters read as "verified clean" rather than "could not check."
This implementation adds an explicit, opt-in `--archive` mode with its own parallel check set
(Checks A1-A6), closes the base-mode false-PASS structurally, and extends the test suite with
eight archive fixtures covering every real writer shape discovered.

## What Changed

- `agent-system/extensions/core/scripts/validate-state.sh` — added `ARCHIVE_MODE`/`--archive`
  flag, flag-combination posture (`--archive --fix` refuses exit 2; `--archive --deep` emits a
  no-op notice; `--archive --strict` works normally), the `Mode: --archive` banner, a structural
  `if ARCHIVE_MODE ... else <Checks 2-11> fi` routing wrapper, Checks A1-A6 (top-level shape,
  project_number numeric, project_name/task_type presence, widened status vocabulary, two
  per-array unknown-field allowlists, cross-array/within-array duplicate `project_number`), an
  archive-mode unknown-top-level-key check, the base-mode unvalidatable-shape FAIL-level guard
  (closing the false-PASS for Checks 4-11 and `--deep`), and extended header/`--help`
  documentation.
- `agent-system/extensions/core/scripts/tests/test-validate-state.sh` — added the
  `ARCHIVE_VALIDATOR` resolution block (grepping "Check A6") and fixtures (a)-(h): positive
  archive shape, the literal `/task --abandon` write, a non-numeric-`project_number` defect, the
  base-mode regression guard, a cross-array duplicate WARN (plain and `--strict`),
  `abandoned_projects` tolerance (three variants), flag-combination posture, and a fourth real
  writer shape (`skill-todo`'s "Archive TODO.md orphans" insert, `created_at` field).

## Decisions

- An explicit `--archive` flag was chosen over shape auto-detection, matching this script's own
  `--deep`/`--fix`/`--strict` idiom and avoiding the hazard of silently re-routing a genuinely
  corrupted live `specs/state.json` into the looser archive checks.
- The base-mode guard (closing the false PASS) covers Checks 4-11, not only 5-7 as the research
  report's visible-jq-error count suggested — live classification confirmed Checks 4 and 8-11
  also silently false-PASS via their own `2>/dev/null` stderr suppression, matching the Phase 2
  Goal text's own "Checks 4-11" framing.
- Every archive-scoped check that could collide with this repository's own live data
  (duplicate `project_number`, off-vocabulary status, `task_type` presence) starts WARN-level
  with a stated PROMOTION CRITERION or a deliberate permanent-WARN rationale, per the script's
  existing advisory-first idiom.
- Five real archive-insert writer shapes exist, not three: `/task --abandon`, `skill-todo`'s two
  bulk inserts, `commands/todo.md`'s orphan-recovery insert (`status=orphan_archived` — this is
  the actual source of the live archive's 24 cross-array duplicates and 24 missing-`task_type`
  entries), and `skill-todo`'s "Archive TODO.md orphans" insert (`created_at` field). All five
  validate under `--archive` with zero FAIL; the fourth exposed a genuine
  `KNOWN_COMPLETED_ENTRY_FIELDS` gap, corrected (added `created_at`) rather than left as an
  uninformative permanent WARN.

## Plan Deviations

- **Phase 2's Scope Hypothesis** (expected exactly Checks 5/6/7 to false-PASS): corrected to
  Checks 4-11 after live classification — recorded inline on the plan and in the issue log as a
  win (no rework required; the Phase 2 Goal text already said 4-11).
- **Phase 4's `ARCHIVE_VALIDATOR` grep anchor**: uses `"Check A6"` instead of the plan's stated
  `"Check A1"`, since "Check A1" alone would also substring-match the Phase 3 top-level-key
  check's own "Check A1b" label.
- **Phase 5's Scope Hypothesis** (expected exactly three live insert shapes): corrected to five
  after the mandated grep for a fourth site — two additional real writer shapes found, one of
  which drove a `validate-state.sh` correction (`created_at` allowlist gap), fixtured as (h).
- **Phase 6's verification criterion** (a fully clean `bash .claude/scripts/verify-deploy.sh`
  pass): not met end-to-end. Closed `[COMPLETED WITH EXCLUSIONS]` with a full Reasoned
  Exclusions record — see Follow-ups below.

## Verification

- Build: N/A (bash/jq script, no build step)
- Tests: `test-validate-state.sh` 63/63 PASS; `run-all.sh --only test-validate-state.sh` and
  `--only test-validate-state.sh,test-init-specs.sh` both green
- Files verified: Yes — source-store and deployed copies of both `file_scope` files confirmed
  byte-identical after redeploy; `--archive` against the live `specs/archive/state.json` exits 0
  (6 PASS / 2 WARN / 0 FAIL); base mode and `--deep` mode against the live `specs/state.json`
  byte-identical to pre-change baselines; `validate-state.sh --deep specs/state.json` (gate 10's
  exact check) exits 0 (20 PASS / 7 WARN / 0 FAIL)

## Impacts

- `/task --abandon`'s archive insert (and every other real archive-insert writer) now has a
  standard validation gate it can be checked against via `validate-state.sh --archive`, closing
  the dispatch's named defect. No existing caller's behavior changed (base mode and `--deep`
  mode against a live `specs/state.json` are byte-identical to pre-change output; no caller
  passes `--archive` today).
- Wiring a new caller (e.g. `/task --abandon` invoking `validate-state.sh --archive` against its
  own write) remains a follow-on, not part of this task — the dispatch required the gate to be
  *capable*, not that every writer invoke it.

## Follow-ups

- A fully clean, end-to-end `bash .claude/scripts/verify-deploy.sh` pass was not obtained within
  this dispatch (Phase 6's Reasoned Exclusions). Each of three full attempts ran into genuine
  multi-minute gate durations compounded by 3+ concurrently-running sibling
  `verify-deploy.sh`/`orchestrate` processes sharing the machine during this same cycle. This
  task's own two in-scope gates (gate 10, and `test-validate-state.sh`/`test-init-specs.sh`
  within gate 8) were independently confirmed green by direct, complete, standalone runs. A
  clean whole-repo gate confirmation remains a repo-wide concern for whichever dispatch runs
  once the current cycle's sibling tasks have all landed and settled — not an action this task
  itself owes, since every observed out-of-scope finding (lean4 doc-index gaps, an already-filed
  test-fixture defect at `specs/389_verify_deploy_context_budget_fixture_missing_git_add/`, a
  context-budget growth from unrelated sibling additions, and timing/concurrency-sensitive shell
  test flakiness) was independently verified unrelated to this task's two-file `file_scope`.
- `state-schema.json`'s stale header comment (naming `researching_2`/`plan_metadata`, neither
  live in the archive) remains unrefreshed — flagged by research as a follow-up, out of this
  task's `file_scope`.
- Wiring a new caller to invoke `validate-state.sh --archive` after its own archive write
  (e.g. `/task --abandon`, `skill-todo`) remains optional future work, outside this task's scope.

## References

- Plan: specs/379_validate_state_cannot_validate_archive_state/plans/01_archive-mode-validation.md
- Research: specs/379_validate_state_cannot_validate_archive_state/reports/01_archive-state-validation-gate.md
- Progress files and phase-end handoffs: specs/379_validate_state_cannot_validate_archive_state/{progress,handoffs}/
