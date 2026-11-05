# Implementation Summary: Task #328 — Phase 12

- **Task**: 328 - Systematic top-to-bottom consolidation of the shell script and test corpus under `agent-system/extensions/**`
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-05T20:00:00Z
- **Completed**: 2026-11-05T21:22:00Z
- **Effort**: ~80 minutes
- **Dependencies**: None (Phase 12 depends on Phases 1 and 8, both already completed)
- **Artifacts**: plans/03_markdown-corpus-consolidation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closes Phase 12 of the plan: every suite `tests/run-all.sh` discovers is now classified `unit` or
`integration` in a new declarative data file, and a new lint mechanically enforces that a
unit-class suite cannot spawn `deploy-headless.sh`, `verify-deploy.sh`, or (nested) `run-all.sh`.
The standing size probe also now reports a `cost_per_assertion_ms` figure. 8 of 20 plan phases now
remain `[NOT STARTED]` (Phase 13 next).

## What Changed

- `agent-system/extensions/core/scripts/script-inventory.sh` — `--size-line` now emits
  `cost_per_assertion_ms=X` (the hinted sequential wall-clock pool in `suite-cost-hints.txt`
  divided by a corpus-wide, command-position assertion-call count), or the literal `n/a` when no
  hints file is present or zero assertions are found.
- `agent-system/extensions/core/scripts/tests/test-script-inventory.sh` — 3 new/updated
  assertions covering the `n/a` case and a dedicated fixture proving the ratio is a real
  computation (1500ms / 4 assertions = 375.0).
- `agent-system/extensions/core/scripts/tests/suite-classification.data` — new. One row per
  suite (`basename<TAB>unit|integration<TAB>reason`), 157 rows (116 unit, 41 integration),
  covering the DEPLOYED/merged `tests/` directory (every extension's own `scripts/tests/*.sh`
  flattened into one shared directory at deploy time), not just core's own 139 source-store
  suites.
- `agent-system/extensions/core/scripts/lint/lint-unit-integration-boundary.sh` — new. Enforces
  three things against the classification file: (a) a unit-class suite's content must not
  literally reference `deploy-headless.sh`/`verify-deploy.sh`/`run-all.sh`; (b) every discovered
  suite must have a classification row (coverage-gap check); (c) an integration-class row must
  record a reason. Rides gate 8's existing full-battery discovery — no change to
  `gate-registry.data` or `verify-deploy.sh` at all, since the lint's own fixture suite is simply
  a discovered `test-*.sh` file.
- `agent-system/extensions/core/scripts/tests/test-lint-unit-integration-boundary.sh` — new.
  8 cases / 15 assertions: conforming fixture, the deliberately-violating fixture, coverage-gap,
  missing-reason, unrecognized-class, stale-row-is-INFO-only, two environment-error cases, and
  the live corpus itself asserted at zero violations.
- `agent-system/extensions/core/manifest.json` — registered the three new files.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — new section
  documenting the classification, the boundary lint, its scope note (deployed/merged corpus, not
  core-only), and the cost-per-assertion probe.

## Decisions

- Classification scope is the DEPLOYED/merged `tests/` directory (157 suites), not core's own
  source-store `tests/` directory (139 suites) — the deploy merge is what `tests/run-all.sh`
  (gate 8) actually discovers and runs in production. Discovered mid-phase: the first run of the
  new fixture suite against the deployed tree surfaced 18 unclassified suites merged in from the
  approvals, lean, and literature extensions. Both the data file's and the lint's own header now
  document this scope distinction explicitly.
- `lint-unit-integration-boundary.sh`'s own fixture suite is itself classified `integration` (not
  `unit`), because its fixtures plant the three heavyweight tool basenames as string literals to
  exercise the lint's own detection — matching the lint's documented policy of reclassifying a
  textual-reference false positive rather than suppressing it.
- No gate-registry.data row was added or extended for the new lint. It rides gate 8's
  pre-existing full-suite discovery instead, the same posture the corpus's own
  `lint-test-harness-adoption.sh` already uses — a stronger form of the plan's own "ride an
  existing gate row" constraint (zero gate-surface changes, not one more check folded into an
  existing numbered gate).

## Plan Deviations

- **Task 12.4** (ride an existing gate row) altered: extends gate 8's existing discovery
  mechanism with zero changes to `gate-registry.data`/`verify-deploy.sh`, rather than appending a
  second check inside an existing numbered `gateN_run` function as the plan's phrasing
  anticipated. Recorded inline in the plan's Phase 12 task annotation and in
  `progress/phase-12-progress.json`'s `deviations` array.

## Verification

- Build: N/A (shell scripts; `shellcheck -S warning` clean on both new scripts)
- Tests: `run-all.sh --only test-lint-unit-integration-boundary.sh,test-script-inventory.sh` →
  2 passed, 0 failed. `test-lint-unit-integration-boundary.sh` standalone → 15 passed, 0 failed.
  `test-script-inventory.sh` standalone → 32 passed, 0 failed.
- Full redeploy (`deploy-headless.sh`) + full `verify-deploy.sh` battery: 26/26 gates, 39 checks,
  0 failures — both before this phase's edits and after.
- Files verified: yes (all five new/modified production files exist, are non-empty, and are
  registered in `manifest.json`).

## Net Deltas

- NET-PROD: **+273** (`script-inventory.sh` +33 via `git diff --numstat`; new
  `lint/lint-unit-integration-boundary.sh` +240).
- NET-TEST: **+339** (`test-script-inventory.sh` +49; new
  `tests/test-lint-unit-integration-boundary.sh` +290).
- Both net-positive, matching the plan's own pre-declared advance justification: Phase 13's
  shared-fixture consolidation needs this classification to know which suites may legitimately
  build a deployed tree, and an unenforced classification drifts back within days (the
  dispatch's own "sixteen additive tasks against three reductive ones" ratio finding).
- Uncounted by either figure: the new `tests/suite-classification.data` (202 lines) is not a
  `*.sh` file, so neither of `script-inventory.sh`'s own `scripts=`/`test_suites=` metrics see
  it. `manifest.json`'s +3 registration lines are excluded from NET-PROD per Phase 9's
  established convention. `shell-script-testing.md`'s +45 lines belong to the markdown
  population, outside this phase's own scope either way.

## Impacts

- Phase 13 (the shared, once-per-run deployed-tree fixture) now has the classification it needs
  to know which suites may legitimately construct or consume a deployed tree.
- A future suite that spawns one of the three heavyweight tools while claiming `unit` class now
  fails loudly at lint time rather than silently inflating the integration-cost pool unnoticed.
- A future suite added to the corpus with no classification row now fails loudly (coverage-gap
  violation) rather than silently exempting itself from the boundary the lint enforces.

## Follow-ups

- Phase 13 should re-derive the integration-class suite set from
  `tests/suite-classification.data` directly rather than re-deriving it independently.
- A future suite removal will leave a stale row in `suite-classification.data`; the lint reports
  this as an INFO-only disclosure (never a violation) by design, but periodic manual pruning
  keeps the file's row count meaningful.

## References

- Plan: `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`
  (Phase 12 section)
- Progress: `specs/328_systematic_script_and_test_corpus_efficiency/progress/phase-12-progress.json`
- Handoff: `specs/328_systematic_script_and_test_corpus_efficiency/handoffs/phase-12-handoff-20261105T192141Z.md`
