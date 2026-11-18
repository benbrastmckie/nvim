# Implementation Summary: Task #650

- **Task**: 650 - Touched path verify entry and unmapped fallback
- **Status**: [COMPLETED]
- **Started**: 2026-11-18T19:55:14Z
- **Completed**: 2026-11-19T02:15:00Z
- **Effort**: ~6 hours (estimate: 13 hours)
- **Dependencies**: None (territory edges to 610, 599, 586, 579, 651)
- **Artifacts**: plans/01_touched-path-entry-and-fallback.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Added `scripts/verify-touched.sh`, the single entry point that turns a touched-path set into a
correct, parallel, timed, narrowed `run-all.sh` pass with a verdict that can never be mistaken
for a full-battery pass. Built the declarable resolver interface
(`scripts/lib/suite-resolver-lib.sh`), the classified unmapped fallback replacing
`__FULL_SWEEP__`'s collapse (`scripts/lib/unmapped-fallback-lib.sh`, NO-SUITE-BY-CLASS /
OWED-NOT-PAID), the repo-declared verification-topology reader
(`scripts/lib/verification-scope-lib.sh`), the owed-sweep discharge at the batch gate
(`scripts/orchestrate-batch-gate.sh`), the coverage convergence report
(`scripts/report-suite-coverage.sh`), and rewrote the authoring/dispatch surfaces
(`shell-script-testing.md`, `plan-format.md`, `orchestrate-build-dispatch.sh`'s `## Batch Gate
Deferral` directive) so "narrow" means naming one command.

## What Changed

- `agent-system/extensions/core/scripts/lib/verification-scope-lib.sh` — new reader for the
  `verification_scope` declaration (`tree_roots`, `project_suite_roots`, `resolver`).
- `agent-system/extensions/core/scripts/lib/suite-resolver-lib.sh` — new resolver wrapper:
  per-path default backend (no escalation), explicit map pre-pass, declared-backend invocation,
  union/replace composition, conformance check.
- `agent-system/extensions/core/scripts/lib/unmapped-fallback-lib.sh` — new classification
  (NO-SUITE-BY-CLASS / OWED-NOT-PAID) and the idempotent owed-record writer.
- `agent-system/extensions/core/scripts/verify-touched.sh` — new entry point: touched-path
  derivation, gate0-style preflight, dual-mode multi-root resolution, resolve+classify+run,
  `--full-sweep`, distinct verdict strings, `--timings`.
- `agent-system/extensions/core/scripts/report-suite-coverage.sh` — new advisory convergence
  report (`--strict` opt-in).
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` — owed-sweep discharge
  (`owed_discharged_count`/`owed_open_count`/`owed_open_roster` in the `batch_gate` record),
  gated on a clean, non-dry-run complete run.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — `## Batch Gate
  Deferral` directive now names the resolved `verify-touched.sh` path instead of a bare
  `run-all.sh --only` line.
- `agent-system/extensions/core/scripts/tests/{suite-selection-map.data,suite-selection-noclass.data}`
  — new checked-in data surfaces (repo-root-relative path convention, documented in both headers).
- `agent-system/extensions/core/scripts/tests/test-verify-touched.sh` — new coverage suite
  (24 assertions, Cases A-L), classified `integration`.
- `agent-system/extensions/core/context/standards/{shell-script-testing.md,repo-level-declarations.md}`,
  `context/formats/plan-format.md`, `context/contracts/batch-gate-stage.md`,
  `context/patterns/orchestrate-batch-results-template.md` — authority rule, resolver backend
  contract, `verification_scope` schema, narrowing-guidance rewrite, owed-sweep discharge
  contract and rendering.
- `agent-system/extensions/core/manifest.json`, `scripts/tests/suite-classification.data`,
  `index-entries.json` — registration and reconciliation.

## Decisions

- `verify-touched.sh` resolves suite NAMES once (against its own co-located tree) and re-resolves
  only the `run-all.sh` BINARY LOCATION per declared root — multiple roots are identical copies
  of the same corpus, per deliverable 5's own framing.
- The resolver's default backend is called PER PATH (never multi-path), so one unmappable
  touched file never escalates the whole call to `__FULL_SWEEP__`.
- `__FULL_SWEEP__` survives as an opt-in `--full-sweep` strict mode.
- A declared backend composes with the default backend via `"union"` (default) or `"replace"`.
- The OWED fallback set is selected exclusively through `run-all.sh --cost-class <class>`, never
  a hand-written suite list.
- `report-suite-coverage.sh` is read-only (never writes owed records) by design, to avoid
  spamming `records/full-sweep-owed.jsonl` for a whole-tree advisory scan.
- Selection's own guard suites (`test-run-all-selection.sh`, the `test-*-gate-selection*.sh`
  family) are authoritative only under the complete, unfiltered run; `verify-touched.sh`'s own
  preflight is a second, independent, pre-selection guard for the mechanical defect class it can
  catch — neither forces those suites into every scoped selection.

## Plan Deviations

- **Phase 5 correction**: `suite-selection-map.data`'s rows (seeded in Phase 2) used
  core-extension-scripts-relative paths instead of the repo-root-relative paths real touched-path
  derivation (`git diff --name-only`) always produces. Discovered via Phase 5's own coverage-
  report testing; fixed in Phase 5's commit, documented in both data files' headers going
  forward.
- **Phase 8**: a `lint-subject-resolution-declaration.sh` false positive (a header comment
  literally naming `common_test_resolve_subject`, inflating the resolve-count past the
  declare-count) was found and fixed while writing the new suite.
- No other deviations; every plan task was completed as specified.

## Verification

- Build: N/A (shell scripts; `bash -n` + `lint-shellcheck.sh` clean on every new/edited file).
- Tests: `test-verify-touched.sh` 24/24 PASS; every phase's own scoped suites PASS (Phases 1-7);
  `deploy-headless.sh` → `RESULT=landed_verify_clean` (41/41 fast checks).
- Complete gate set (`verify-deploy.sh`, no `--skip-slow`): **NOT clean** — `tests/run-all.sh`
  over the full 204-suite corpus: 200 passed, 4 failed. One EXPECTED
  (`test-gate-cache-equivalence.sh`, already in `known-failures.txt`). Two confirmed pre-existing,
  unrelated to this task (`test-gate-out-repair-reporting.sh`, `test-mcp-merge-target.sh` —
  reproducible in isolation; `git log` confirms neither suite nor its subjects were ever touched
  by any task-650 commit; logged via `issue-record.sh`, not fixed, out of this task's
  `file_scope`). One load-induced flake (`test-lint-state-writer-boundary.sh` — failed once under
  a `verify-deploy.sh` `[CONTENTION]` marker from unrelated concurrent processes on this machine;
  re-ran clean twice afterward; logged via `issue-record.sh`).
- Files verified: Yes — every new file confirmed present under the deployed `.claude/scripts/`
  tree and resolved (0 unconverged) by `report-suite-coverage.sh`.

## Impacts

- Any future `/orchestrate` batch's `## Batch Gate Deferral` directive now names
  `verify-touched.sh` directly, closing the originating incident (a serial full battery paid
  three times over for three deploy roots).
- `records/full-sweep-owed.jsonl` is a new per-task durable record kind; `orchestrate-batch-gate.sh`
  is now its sole discharger.
- `.claude-extensions.json`'s `verification_scope` key is a new declaration surface, reserving
  `project_gates`/`closing_gate` fields for tasks 599 and the orchestration-close record.
- The two pre-existing, confirmed-unrelated gate-8 failures
  (`test-gate-out-repair-reporting.sh`, `test-mcp-merge-target.sh`) remain open in the corpus,
  outside this task's remit.

## Follow-ups

- `test-gate-out-repair-reporting.sh` and `test-mcp-merge-target.sh` need separate attention
  (logged via `issue-record.sh` in this task's own `issues.jsonl`, not actioned here).
- Task 599 (project-sources narrowing) and the orchestration-close record should read this
  task's `verification_scope` schema and `## Batch Gate Deferral` rewrite before adding their own
  fields/edits to the same surfaces.
- A consumer repository's own non-shell (e.g. pytest) resolver backend is the first real test of
  deliverable 6's interface against a non-shell corpus — not built here by design (non-goal).

## References

- Plan: `specs/650_touched_path_verify_entry_and_unmapped_fallback/plans/01_touched-path-entry-and-fallback.md`
- Research report: `specs/650_touched_path_verify_entry_and_unmapped_fallback/reports/01_touched-path-entry-and-fallback.md`
- Phase handoffs: `specs/650_touched_path_verify_entry_and_unmapped_fallback/handoffs/phase-{1..8}-handoff-*.md`
