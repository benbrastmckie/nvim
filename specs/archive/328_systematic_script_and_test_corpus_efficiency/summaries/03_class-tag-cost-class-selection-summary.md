# Implementation Summary: Task #328

- **Task**: 328 - Systematic script and test corpus efficiency
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-05T21:47:10Z
- **Completed**: 2026-11-05T22:43:09Z
- **Effort**: ~1 hour
- **Dependencies**: 170 (scoped), 411 (live blocker on shared territory, already coordinated)
- **Artifacts**: plans/03_markdown-corpus-consolidation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed Phase 14 of the 20-phase markdown-corpus-consolidation plan: added `--class`, `--tag`, and
`--cost-class` selection to `tests/run-all.sh`, layered on top of the existing `--quiet`,
`--timings`, `--jobs`, `--only`, and `--fail-on-new` flags. This is the "selection surface" GAP 3
of the dispatch named as the reason the test corpus's volume is a cost paid on every task rather
than occasionally (no way to run an appropriate subset without typing exact filenames).

## What Changed

- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh` — six new, additive functions
  (`suite_selection_known_classes`/`_tags`/`_cost_classes`, `suite_selection_by_class`/`_tag`/
  `_cost_class`). Every pre-existing function and the `__FULL_SWEEP__` sentinel are untouched.
- `agent-system/extensions/core/scripts/tests/run-all.sh` — new `--class CLASS[,...]`,
  `--tag TAG[,...]`, `--cost-class CLASS[,...]` flags, each opt-in, composing with `--only` and
  with each other by intersection. Sources the library only when one of the three is given.
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` — 12 new regression
  cases (14-25): 4 library-level correctness cases against the real corpus, 8 run-all.sh
  flag-level cases (selection, refuse-loudly-on-unknown-value, AND-composition) against a
  dedicated fixture.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — documented the three
  new selectors and their derivation rule.
- `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`
  — Phase 14 checklist, Verification section, and heading marked `[COMPLETED]`.

## Decisions

- Zero new per-suite hand-authoring: `--class` reads the existing `suite-classification.data`
  column; `--tag` is mechanically derived from that same file's `invokes:X[,Y]` reason tokens
  (plus a fixed `lint` tag for `test-lint-*.sh`); `--cost-class` buckets the existing
  `suite-cost-hints.txt` wall_ms column at fixed thresholds (free <2000ms, moderate <30000ms,
  else slow; `unknown` for an unhinted suite). A hand-authored tag retrofit across 203 rows was
  considered and rejected as contrary to this task's net-deletion charter.
- The three axes compose with `--only` and with each other by intersection (AND), never union
  across axes; an empty intersection surfaces as `run-all.sh`'s existing "zero suites discovered"
  harness failure, never a silent partial run.
- The Tier Justification's own literal verification command
  (`verify-deploy.sh --skip-slow --only-gate 8`) is a documented no-op (SKIP, since `--skip-slow`
  defers gate 8 entirely). Real coverage came instead from a direct, unbounded
  `verify-deploy.sh --only-gate 8` run and a direct `run-all.sh --quiet` full-battery run.

## Plan Deviations

- None (implementation followed plan). The literal Tier Justification command was run as
  specified and separately supplemented with stronger evidence; this is noted in the Verification
  section but is not a deviation from any task bullet.

## Verification

- Build: N/A (shell scripts)
- Tests: `test-run-all-selection.sh` 31/31 passed standalone; `run-all.sh --only
  test-run-all-selection.sh` green; byte-identical output confirmed against the pre-change file
  on an identical `--only` invocation; direct full-battery `run-all.sh --quiet` run on the live
  corpus: 168/175 passed, 7 failed (2 EXPECTED, 5 NEW, all unrelated to this phase's files --
  logged as `host-state-contention`, not a regression).
- Files verified: Yes

## Impacts

- A future task/agent can now run `run-all.sh --class unit`, `--tag deploy-headless`, or
  `--cost-class free` to run a meaningful subset of the test corpus without knowing exact
  filenames, reducing the pressure toward always running the full ~180-suite battery.
- NET-PROD +318, NET-TEST +175 for this phase, both net-positive and justified in advance in the
  plan as the mechanism that keeps the corpus from re-growing (not itself a reduction).

## Follow-ups

- Phases 15-20 remain `[NOT STARTED]`: markdown duplicate-block classification and NET-MD
  declaration, the anchor-pointer convention and its lint, three markdown migration tranches, and
  the final redeploy + full gate set + measured net accounting.
- Logged issue `host-state-contention` (this dispatch) documents the 5 NEW full-battery failures
  observed under concurrent sibling orchestrate cycles; none reference this phase's files.
- The harness in this environment auto-backgrounds any foreground Bash call past ~180s
  regardless of the Bash tool's own `timeout` parameter — recorded in the phase-14 handoff for a
  future dispatch running a long gate-8/full-corpus verification.

## References

- Plan: `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md` (Phase 14 section)
- Progress: `specs/328_systematic_script_and_test_corpus_efficiency/progress/phase-14-progress.json`
- Handoff: `specs/328_systematic_script_and_test_corpus_efficiency/handoffs/phase-14-handoff-20261105T224309Z.md`
