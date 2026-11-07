# Implementation Summary: Task #328

- **Task**: 328 - systematic_script_and_test_corpus_efficiency (Phase 7: Harness Migration Tranche B)
- **Status**: [IN PROGRESS]
- **Started**: 2026-11-04T00:00:00Z
- **Completed**: 2026-11-05T01:30:00Z
- **Effort**: ~2.5 hours
- **Dependencies**: 170, 411, 429 (all discharged as of this dispatch's own description)
- **Artifacts**: plans/03_markdown-corpus-consolidation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed Phase 7 of the plan: migrated 48 mid-size test suites in
`agent-system/extensions/core/scripts/tests/` onto `lib/common.sh`'s shared test harness
(`common_test_pass`/`_fail`/`_info`, `common_test_repo_root`, `common_test_workdir_init`),
removing each suite's own hand-rolled boilerplate. This is one phase of a 20-phase plan; 12
phases remain ([NOT STARTED]).

## What Changed

- 48 files under `agent-system/extensions/core/scripts/tests/` — local `pass()`/`fail()`/`info()`
  single-line definitions removed, call sites renamed to `common_test_pass`/`_fail`/`_info`, a
  `source "$SCRIPT_DIR/../lib/common.sh"` line inserted where not already present.
- 25 of the 48 — the 4-line git-rev-parse-plus-fixed-depth-fallback `REPO_ROOT` block collapsed
  to one `common_test_repo_root "$SCRIPT_DIR"` call.
- 26 of the 48 — a second exact-shape `WORKDIR="$(mktemp -d)"` + local `cleanup()` wrapper +
  `trap cleanup EXIT` triplet (distinct from Phase 6's bare-trap shape) collapsed to one
  `common_test_workdir_init` call.
- `agent-system/extensions/core/scripts/lib/common.sh` — `common_test_fail()` extended with an
  optional `$2` diagnostic-detail argument (echoed verbatim after the `[FAIL]` line), absorbing 4
  suites' pre-existing two-argument `fail()` override without losing their diagnostic output.

## Decisions

- Selected Tranche B as the 48 smallest-by-line-count suites from a freshly enumerated 104-suite
  unmigrated pool, after excluding any suite with a `suite-cost-hints.txt` wall-time hint
  >=10 seconds (deferring both the known 148,607ms outlier and several newly-identified
  heavyweight suites to Phase 8), to keep this dispatch's mandatory before/after verification
  tractable.
- Extended `common_test_fail()`'s signature rather than leaving a local wrapper `fail()` in the
  four affected suites, which would have reintroduced the exact "suite still defines its own
  fail()" condition the migration exists to eliminate.
- Did not force `common_test_resolve_candidate` onto any suite this tranche; no suite presented
  an exact-shape match worth a mechanical extraction.

## Plan Deviations

- `lib/common.sh`'s `common_test_fail()` signature extended (optional `$2`) — explicitly
  anticipated by the plan's own Files-to-modify note for this phase ("only if a tranche suite
  needs a harness piece the Phase 4 surface does not yet cover... one would be recorded as a
  deviation").
- Migrated a second WORKDIR/cleanup/trap shape beyond the plan's literal task list (additive net
  deletion, not a deviation from the plan's intent).

## Verification

- Build: N/A (shell scripts)
- Tests: `run-all.sh --only <48 migrated suites>,test-common-lib.sh` — 49 passed, 0 failed.
  Per-suite before/after stdout diff: 40/48 byte-identical; the remaining 8 differ only in
  non-deterministic `mktemp` paths, timing-jitter milliseconds, or ANSI-color-code loss
  (established acceptable by Phase 6 precedent) — no assertion-count or PASS/FAIL case-name
  change in any of the 48.
- Files verified: Yes (`bash -n` syntax-clean on all 48; `grep -nE '^(pass|fail|info)\(\) \{'`
  returns zero hits across the tranche).

## Impacts

- NET-TEST for this phase: insertions=1449, deletions=1663, **net=-214** lines (git diff
  --numstat across the 48 touched test files plus `lib/common.sh`).
- Unmigrated core-suite pool reduced from 104 to roughly 56, including the two largest suites
  (`test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`) and the deliberately
  deferred runtime outliers, all left for Phase 8.

## Follow-ups

- Phase 8 ("Harness Migration Tranche C — Complete the Corpus") is next: migrate the remaining
  suites including the two largest, and the runtime outliers this phase deferred
  (`test-verify-deploy-gate-selection-crash-net.sh` 148,607ms; `test-git-snapshot.sh` 12,753ms;
  `test-verify-deploy-context-budget.sh` 30,962ms; `test-context-reachability.sh` 39,941ms;
  `test-verify-deploy-gate-selection.sh` 36,823ms; `test-gate-cache-equivalence.sh` 543,000ms —
  an extreme outlier worth isolating on its own before any full before/after capture).
- A commit-pipeline defect was found and recorded (not fixed, out of this task's file_scope):
  `git-commit-phase.sh`'s Phase-Commit Containment Self-Check mis-derives `"${entry}/*"` as a
  double-slash pattern when a `file_scope` entry already ends in `/`, silently dropping every
  touched path under that directory entry from the phase-closing commit. Recovered here via an
  explicit follow-up `git-commit-scoped.sh` commit of the dropped paths. This should be fixed in
  its own task before the next phase relies on the same wrapper.

## References

- Plan: `specs/328_systematic_script_and_test_corpus_efficiency/plans/03_markdown-corpus-consolidation.md`
- Progress: `specs/328_systematic_script_and_test_corpus_efficiency/progress/phase-7-progress.json`
- Handoff: `specs/328_systematic_script_and_test_corpus_efficiency/handoffs/phase-7-handoff-20261105T011855Z.md`
- Issue log: `specs/328_systematic_script_and_test_corpus_efficiency/issues.jsonl`
