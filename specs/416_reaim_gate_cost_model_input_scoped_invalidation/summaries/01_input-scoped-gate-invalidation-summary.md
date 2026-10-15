# Implementation Summary: Task #416

- **Task**: 416 - Re-aim the verify-deploy gate-framework refactor at the measured cost model,
  and add input-scoped gate invalidation so unchanged gates are SKIPPED rather than merely
  re-walked faster
- **Status**: [IN PROGRESS]
- **Started**: 2026-10-15T22:50:00Z
- **Completed**: (not yet -- 3 of 13 phases done; see Follow-ups)
- **Effort**: ~2.5 hours (phases 1-3 of a 25.5-hour, 13-phase plan)
- **Dependencies**: 411 (completed -- delivered the declarative registry and runner library this
  work extends)
- **Artifacts**: plans/01_input-scoped-gate-invalidation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This dispatch implemented the first three phases of a 13-phase plan: hardening the measurement
harness against mid-run contention (Phase 1), declaring every gate's input corpus in the
registry (Phase 2), and building the content-addressed corpus + implementation digest library
that input-scoped invalidation is built on (Phase 3). All three phases are `[COMPLETED]`, each
committed separately, each verified green via its own regression suite plus `lint-shellcheck.sh`.
Ten phases remain, including the opt-in `--skip-unchanged` skip decision itself (Phase 5), the
attestation-integrity hardening (Phase 7), the per-gate seeded-violation equivalence proof
(Phase 9), and the gate-8 root-cause diagnostic (Phase 4) plus several evidence-gated efficiency
phases (10-12).

## What Changed

- `agent-system/extensions/core/scripts/measure-gate-costs.sh` — per-run (not only per-pass) load
  capture for both the gate-cost CSV and `--regen-hints`; a per-row `valid` column and a
  file-level `# ALL_VALID=` header flag; overwrite protection that refuses to let a contaminated
  run silently replace a previously-clean artifact (diverting it to a sibling
  `.contaminated-<timestamp>` file instead); a new `MEASURE_GATE_COSTS_LOADAVG_SEQUENCE`/
  `_SEQFILE` test-only seam to simulate a mid-run load rise.
- `agent-system/extensions/core/scripts/tests/test-measure-gate-costs.sh` — 6 new cases (9-12)
  for the above; fixed case 7's column indices for the new interleaved `run_ms`/`run_load` layout.
- `agent-system/extensions/core/scripts/gate-registry.data` — new 9th `input_corpus` field,
  populated for all 23 gates from their actual `verify-deploy.sh` reads (not descriptions); new
  grammar documented in the field's own header comment (`@extensions`/`@repo` named views,
  paths, globs, `!`-exclusions).
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` — loader array, `read` line,
  and accessor case for `input_corpus`.
- `agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` — two new checks: F
  (exactly 9 TAB-separated fields) and G (corpus grammar conformance).
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` — 6 new cases
  (26-31) for the round-trip, the `-` normalization, and the three rejection paths.
- `agent-system/extensions/core/scripts/lib/gate-cache-lib.sh` — new library: corpus resolution
  (filesystem-based for paths/directories/globs, git-based only for the two named views),
  content-addressed corpus digest, five-component implementation digest, composite key, and
  distinguishable fail-open sentinels.
- `agent-system/extensions/core/scripts/tests/test-gate-cache-lib.sh` — new suite, 16 cases.
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` — hinted the new suite.
- `specs/416_.../progress/phase-2-corpus-declarations.md` — per-gate corpus declaration
  rationale for all 23 gates, including which were considered and excluded.

## Decisions

- **Risk-calibrated corpus declaration confidence** (Phase 2): gates whose cost class makes
  skip-caching actually matter got a confident declaration from reading the gate function body
  directly; gate 14 (`free` class, genuine read-set uncertainty) was declared `-` (never
  skippable) rather than guessed, since skipping an already-near-free gate buys nothing.
- **One code path for content addressing, not a tracked/untracked conditional** (Phase 3):
  `git hash-object <path>` against current working-tree bytes covers tracked, modified, and
  untracked files identically, simplifying the plan's own two-branch framing without weakening
  the no-mtime-dependence property.
- **Filesystem-based resolution for literal paths/bare directories/globs; git-based only for the
  two named views** (Phase 3): `.claude/**` is gitignored, so `git ls-files` can never see it,
  and several real corpus declarations point there (gates 1, 2, 9, 13, 16). This correction was
  found live during implementation (see Follow-ups' pointer to the phase's own
  `approaches_tried` record) and is a load-bearing design choice for any future gate's corpus
  declaration.
- **Bounded sourced-library closure = the whole `scripts/lib/*.sh` directory**, not a precise
  per-script static trace (Phase 3): every sourced-library line in this codebase sources via a
  variable, not a literal path, making a reliable per-script trace unsafe to attempt without
  either executing the script or a real bash parser. Over-inclusion is the safe direction.

## Plan Deviations

- None (implementation followed the plan's own task lists for phases 1-3). Several real
  implementation defects were found and corrected DURING implementation (not shipped) -- see
  each phase's own `progress/phase-N-progress.json` `approaches_tried` array for the full list
  (a regex-escaping bug in the corpus-grammar lint, a `git stash` safety refusal under
  concurrent sessions, a `git ls-files`-vs-gitignored-tree resolution gap, a command-substitution
  subshell variable-scoping bug, and a test-harness path-arithmetic error).

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: `run-all.sh --only test-measure-gate-costs.sh,test-gate-registry-resolution.sh,test-gate-cache-lib.sh`
  — all three pass (12, 32, and 16 cases respectively, 60 total, 0 failed)
- `lint-shellcheck.sh --quiet` on every touched/new file: 0 findings
- `lint-gate-registry.sh`: all 7 checks pass on the real, populated registry
- Files verified: Yes

## Impacts

- `gate-registry.data` now carries a 9th field that every future gate addition must populate
  (or explicitly declare `-`), checked by `lint-gate-registry.sh`'s new Checks F/G.
- `gate-cache-lib.sh` has no caller yet -- Phase 5 is the first real consumer. Nothing in
  `verify-deploy.sh`'s behavior, exit code, or output shape has changed as of this summary.
- `measure-gate-costs.sh`'s CSV and hints-file output shape changed (new columns, new header
  lines) -- any external consumer of those files' exact column layout would need to account for
  the new `run{N}_load`/`valid` columns and the `# ALL_VALID=` header line. No such consumer was
  found in this codebase as of this phase.

## Follow-ups

- 10 phases remain: Phase 4 (root-cause gate 8's 457s-vs-103s discrepancy -- requires a
  genuinely idle host, which was NOT available for most of this dispatch's duration but became
  available near its end), Phase 5 (the opt-in `--skip-unchanged` skip decision -- the first
  real caller of `gate-cache-lib.sh`), Phase 6 (shellcheck acceptance suite + hint coverage),
  Phase 7 (attestation integrity), Phase 8 (cut the two verify-deploy-testing stragglers),
  Phase 9 (per-gate equivalence proof), Phase 10 (re-derive `JOBS_CAP`), and the two
  evidence-gated derived phases 11-12 (gate 3, gate 8 serialization). Phase 13 (redeploy and
  final correctness/measurement) closes the task.
- See `.orchestrator-handoff.json` and the Phase 3 handoff artifact
  (`handoffs/phase-3-handoff-20261016T004800Z.md`) for the concrete resume point and the critical
  context a successor dispatch needs before starting Phase 4 or Phase 5.

## References

- Plan: `specs/416_reaim_gate_cost_model_input_scoped_invalidation/plans/01_input-scoped-gate-invalidation.md`
- Progress files: `specs/416_.../progress/phase-{1,2,3}-progress.json`,
  `specs/416_.../progress/phase-2-corpus-declarations.md`
- Handoffs: `specs/416_.../handoffs/phase-{1,2,3}-handoff-*.md`
