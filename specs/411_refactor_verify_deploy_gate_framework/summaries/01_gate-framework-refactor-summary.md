# Implementation Summary: Task #411

- **Task**: 411 - Systematically refactor the verify-deploy gate set and shell test runner into a unified, parallel, declarative gate framework
- **Status**: [IN PROGRESS]
- **Started**: 2026-10-15T00:00:00Z
- **Completed**: N/A (partial -- phases 1-4 of 11 complete)
- **Effort**: ~6 hours (this dispatch)
- **Dependencies**: None
- **Artifacts**: plans/01_gate-framework-refactor.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Phases 1-4 of the 11-phase gate-framework refactor are complete and committed. Phases 1-2 landed
the independently-landable, correctness-critical Gate 8 finding-extraction fix (and its
generalization to all 14 previously-unanchored call sites) ahead of the larger registry work, per
the dispatch's own explicit priority. Phase 3 built a mechanical, idle-guarded cost-measurement
harness and captured a clean, fully-idle 23-gate cost table, replacing the dispatch's and
research's carried-forward figures with freshly re-derived ones. Phase 4 introduced the
declarative gate registry and migrated gates 1-8 onto it with proven byte-identical output.
Phases 5-11 (migrate gates 9-23, timeouts, concurrency, shellcheck parallelization, corpus
enumeration, run-all.sh default flip, final redeploy and measured verification) remain.

## What Changed

- `agent-system/extensions/core/scripts/lib/gate-verdict-extract-lib.sh` — new sourced library: the SGR-stripping, anchored verdict-line extraction helper (`verify_deploy_extract_verdict_lines`) replacing all 14 of verify-deploy.sh's previously-unanchored `grep -F '[FAIL]'`/`grep -F '[VIOLATION]'` sites.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — Gate 8 and the remaining 13 extraction sites repointed at the new helper; 8 gates (1-8) extracted into `gateN_run()` functions, dispatched via the new declarative registry; a new `_GREG_LIB`/`_GVEL_LIB` degrade-safe sourcing block added.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — two new sections: the verdict-line extraction producer/consumer contract, and the measurement-discipline guidance (a cost figure is invalid for prioritization unless taken idle, with both figures live-demonstrated during this dispatch).
- `agent-system/extensions/core/scripts/measure-gate-costs.sh` — new mechanical, idle-load-guarded, averaged per-gate (and, via `--regen-hints`, per-suite) cost-measurement harness.
- `agent-system/extensions/core/scripts/gate-registry.data` — new declarative gate registry (8 rows, gates 1-8).
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` — new thin registry interpreter (`gate_registry_load`/`_ids`/`_execute`/`_field`).
- `agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` — new registry-data lint (5 checks: invoke-function existence, dependency existence, cycle detection, well-formed timeout/cost_class/requires_source_store/serialized, contiguous unique ids).
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh`, `test-measure-gate-costs.sh` — new regression suites (10 and 8 cases respectively).
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh`, `test-orchestrate-batch-gate.sh`, `test-run-all-selection.sh` — extended with verdict-extraction regression cases (24, 10, and 16 total cases respectively, up from 16, 6, and 15).
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` — regenerated mechanically (147 suites) rather than hand-curated, via `measure-gate-costs.sh --regen-hints`.

## Decisions

- SGR sequences are stripped BEFORE anchoring (not instead of anchoring): 12 of the 14 real
  producers emit colored verdict rows with no TTY guard, so a bare `grep -E '^\[FAIL\] '` would
  have silently zeroed out 12 real gates while looking like a hardening fix.
- The gate registry interpreter is deliberately thin (look up a function name, call it) rather
  than attempting a fully generic guard/output-rendering fold, because the 8 migrated gates'
  SKIP-message shapes and check order are not uniform enough to fold losslessly without changing
  byte output (gate5's 2-line message; gate8's `--skip-slow`-before-source-store check order).
- `date +%s%3N` wall-clock delta replaces the plan's literal `/usr/bin/time` suggestion, since
  that binary does not exist at that literal path on this NixOS measurement host.
- A contaminated full-sweep cost measurement (1-minute load spiked to 50+ from concurrent sibling
  `/orchestrate` sessions) was discarded in full and re-taken once genuinely idle, rather than
  patched or averaged with the clean data.

## Plan Deviations

- **Task 3.1** altered: `/usr/bin/time` replaced with `date +%s%3N` (portability; see Decisions).
- **Task 2.3** altered: per-site live violation seeding into 13 different real files/fixtures was
  replaced by a layered proof (exhaustive unit-level mechanism tests + a per-site producer-source
  shape-pinning case + two real naturally-occurring findings already round-tripping correctly) to
  avoid destabilizing a shared, concurrently-used repository.
- **Task 4.3** altered: `requires_source_store` is declared as accurate registry metadata but the
  literal guard-folding (removing each gate's own inline source-store check) was judged unsafe for
  byte-identical output and deferred; see `gate-registry.data`'s own field documentation.
- Phase 4's "per-gate state scoped... rather than a single reassigned `CURRENT_GATE` global" item
  (a stated Phase 7 prerequisite) was deliberately NOT attempted in Phase 4 — each migrated
  function still sets the global `CURRENT_GATE`, unchanged from the pre-registry code. This is a
  recorded, tracked gap for Phase 7, not a silent omission.

## Verification

- Build: N/A (shell scripts)
- Tests: All new/extended suites pass — `test-deploy-baseline-lib.sh` (24/24), `test-orchestrate-batch-gate.sh` (10/10), `test-run-all-selection.sh` (16/16), `test-measure-gate-costs.sh` (8/8), `test-gate-registry-resolution.sh` (10/10), `lint-gate-registry.sh` (5/5 checks, 4 seeded-violation shapes confirmed caught), `shellcheck` clean on every new/modified file.
- Files verified: Yes
- Byte-identical before/after: Gate 8's findings (Phase 1/2) and the complete `--only-gate 1,...,8` stdout/stderr/exit-code capture (Phase 4) are confirmed byte-identical pre/post change.
- One known-unrelated pre-existing failure observed during Phase 4's verification run: `test-verify-deploy-context-budget.sh` fails due to Gate 20's eager-load budget being genuinely ~988B over baseline right now — this is the dispatch's own named, excluded pre-existing defect, confirmed unrelated to any file this work touched.

## Impacts

- The Gate 8 finding-extraction fix (Phases 1-2) is immediately load-bearing: it corrects the
  findings set five separate consumers read, including `orchestrate-cycle-plan.sh`'s Inter-Cycle
  Redeploy Checkpoint, which gates whether an orchestration batch proceeds.
- `scripts/measure-gate-costs.sh` and its clean idle cost table (`progress/phase-3-gate-cost-model.csv`) are the new single source of truth later phases (5+) must derive timeouts and
  scheduling priority from, superseding the dispatch's and research's carried-forward figures.
- Gates 1-8 now have a working declarative-registry migration path to follow for the remaining 15
  gates (Phase 5), with the mechanical patterns (function-wrap, TSV row, byte-identical capture)
  already proven.

## Follow-ups

- Phase 5 (migrate gates 9-23, add `--max-cost` selection, re-verify all 5 `deploy_findings_snapshot` callers, full-battery before/after capture) is the next phase to dispatch.
- Phase 7 must address the `CURRENT_GATE`-global-scoping gap Phase 4 explicitly deferred.
- `suite-cost-hints.txt`'s `test-verify-deploy-context-budget.sh` row (228595ms) carries a
  documented tail-load-contamination caveat; a future idle re-run would tighten it, though the
  file's own advisory-only nature means this is not blocking.
- The pre-existing Gate 20 eager-load budget overage (~988B) remains open and unrelated to this task, per the dispatch's explicit exclusion.

## References

- Plan: `specs/411_refactor_verify_deploy_gate_framework/plans/01_gate-framework-refactor.md`
- Progress files: `specs/411_refactor_verify_deploy_gate_framework/progress/phase-{1,2,3,4}-progress.json`
- Handoffs: `specs/411_refactor_verify_deploy_gate_framework/handoffs/phase-{1,2,3,4}-handoff-*.md`
