# Implementation Summary: Task #416

- **Task**: 416 - Re-aim the verify-deploy gate-framework refactor at the measured cost model,
  and add input-scoped gate invalidation so unchanged gates are SKIPPED rather than merely
  re-walked faster
- **Status**: [IN PROGRESS]
- **Started**: 2026-10-15T22:50:00Z
- **Completed**: (not yet -- 5 of 13 phases done; see Follow-ups)
- **Effort**: ~9 hours across two dispatches (phases 1-5 of a 25.5-hour, 13-phase plan)
- **Dependencies**: 411 (completed -- delivered the declarative registry and runner library this
  work extends)
- **Artifacts**: plans/01_input-scoped-gate-invalidation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This dispatch round implemented the first five phases of a 13-phase plan: hardening the
measurement harness against mid-run contention (Phase 1), declaring every gate's input corpus
in the registry (Phase 2), building the content-addressed corpus + implementation digest library
(Phase 3), root-causing gate 8's measured-vs-projected wall-clock discrepancy (Phase 4), and
landing the opt-in `--skip-unchanged` skip decision itself (Phase 5) -- the actual input-scoped
invalidation feature the task exists to deliver. All five phases are `[COMPLETED]`, each
committed, each verified green. Phase 5 also absorbed a significant unplanned finding: a real
performance defect in Phase 3's own corpus-digest implementation (undiscovered until exercised
against the real 23-gate registry at scale) that would have made the skip-consult itself nearly
as costly as the sweep it exists to avoid. That defect is fixed; the consult loop now runs in
4.4s for the full registry. Eight phases remain (6-13), covering gate-set *efficiency* work on
individual gates now that gate-set *invalidation* is landed and cheap.

## What Changed

- `agent-system/extensions/core/scripts/measure-gate-costs.sh` — per-run (not only per-pass) load
  capture for both the gate-cost CSV and `--regen-hints`; a per-row `valid` column and a
  file-level `# ALL_VALID=` header flag; overwrite protection against a contaminated run
  clobbering a previously-clean artifact; a test-only load-sequence seam.
- `agent-system/extensions/core/scripts/tests/test-measure-gate-costs.sh` — 6 new cases for the
  above.
- `agent-system/extensions/core/scripts/gate-registry.data` — new 9th `input_corpus` field,
  populated for all 23 gates from their actual `verify-deploy.sh` reads.
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` — the `input_corpus` loader/
  accessor (Phase 2), and a new `gate_registry_exclude_ids` primitive (Phase 5, unplanned) that
  removes ids from the loaded set so a cache-hit gate is never dispatched at all, not merely
  silenced inside its own body.
- `agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` — two new checks (field
  count, corpus grammar).
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` — 6 new cases.
- `agent-system/extensions/core/scripts/lib/gate-cache-lib.sh` — the content-addressed digest
  library (Phase 3: corpus resolution, corpus digest, five-component implementation digest,
  composite key, fail-open sentinels) plus, in Phase 5, the cache STORE
  (`gate_cache_entry_read/write/invalidate`, atomic write-then-rename, `format_version` gating)
  and a significant performance rewrite: batched `git hash-object --stdin-paths` hashing instead
  of one subprocess per file, vectorized array-expansion/`paste` construction instead of bash
  string-concatenation loops, and per-process memoization of both the corpus digest (keyed by
  spec+root) and the implementation digest's `scripts/lib/` component (keyed by root).
- `agent-system/extensions/core/scripts/tests/test-gate-cache-lib.sh` — 16 cases from Phase 3,
  plus 12 new cache-store cases from Phase 5 (28 total).
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` — hinted/re-hinted as suites
  were added or sped up.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `--skip-unchanged` flag; a
  pre-dispatch cache-consult loop (filtered through the existing `gate_selected()` predicate so
  it never considers a gate `--only-gate`/`--max-cost` already excluded); `GATE_RAN_LIST`/
  `GATE_DIRTY_LIST` bookkeeping in `pass()`/`fail()`/`warn()` to determine per-gate cacheability
  without relying on the global `CHECKS`/`FAILURES` counters (which cannot be disaggregated per
  gate once several ran concurrently in one wave); a post-run per-gate write/invalidate step; a
  `SKIPPED_CACHED`-gated summary-line clause (byte-identical when zero); and a zero-check-under-
  filter exemption for the case where every selected gate was legitimately cache-skipped.
- `.gitignore` — the `**/.gate-cache/` ignore entry, with rejected-candidates rationale.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — Phase 4's gate-8
  root-cause verdict (a new section with the full candidate-by-candidate table and evidence).
- `specs/416_.../progress/phase-{1,2,3,4,5}-progress.json`, `phase-2-corpus-declarations.md`,
  and five `handoffs/phase-{1..5}-handoff-*.md` artifacts.

## Decisions

- **Risk-calibrated corpus declaration confidence** (Phase 2): see prior summary round; carried
  forward unchanged.
- **One code path for content addressing** (`git hash-object` against current working-tree
  bytes, tracked/modified/untracked alike) and **filesystem-based resolution for literal paths/
  directories/globs, git-based only for the two named views** (Phase 3, carried forward).
- **Gate 8's 4.4x discrepancy has a structural primary cause, not a scheduling one** (Phase 4): a
  synthetic, host-load-independent sleep-based concurrency probe conclusively refuted "the
  scheduler doesn't deliver requested concurrency" (it does, exactly, at every `--jobs` level
  tested) and confirmed `JOBS_CAP=4` genuinely binds, but the PRIMARY root cause is structural:
  one suite's one nested full-battery `verify-deploy.sh` call (inside gate 8, inside
  `verify-deploy.sh`) accounts for roughly a fifth of the entire 151-suite serial-cost sum by
  itself. No amount of worker-level tuning shrinks that single suite's own wall-clock floor.
- **Cacheability is tracked via two new plain indexed arrays, never via a diff of the global
  CHECKS/FAILURES counters or an associative map** (Phase 5): the existing concurrent-batch
  reconciliation protocol (`gate_registry_exec_concurrent_batch`'s snapshot-then-delta-apply)
  only correctly handles indexed arrays and scalars; reusing the exact mechanism `FINDINGS_LIST`
  already relies on was the only option that composes with concurrency correctly out of the box.
- **The consult loop must filter through `gate_selected()`** (Phase 5, found during this round's
  own end-to-end testing): without it, a gate excluded by `--only-gate`/`--max-cost` but carrying
  a stale cache entry from an earlier, differently-scoped run still announced `[SKIP-CACHED]` —
  confusing output for zero behavioral effect, and wasted consult-loop time.
- **A gate's corpus/implementation digest must be computed via batched git operations and
  memoized per (spec, root), never per-file subprocess forks or per-element string
  concatenation** (Phase 5): the single most consequential finding of this round. See Impacts.

## Plan Deviations

- **Unplanned (Phase 4, structural)**: a fourth root cause (recursive gate-tree self-invocation)
  not originally named among the dispatch's three candidates was investigated and confirmed as
  primary, exactly as the plan's own text anticipated as a live possibility.
- **Unplanned (Phase 5, performance)**: a real, previously-undiscovered performance defect in
  Phase 3's own corpus-digest implementation was found and fixed within this phase rather than
  deferred, since it directly threatened Phase 5's own closure criterion (a cache consult must
  be cheap, not merely cheaper-than-nothing). See `progress/phase-5-progress.json`'s
  `approaches_tried` for the full before/after measurements (75.6s -> 4.4s for the full 23-gate
  consult loop).
- **Unplanned (Phase 5, file scope)**: `gate_registry_exclude_ids` was added to
  `gate-registry-lib.sh`, a file Phase 5's own Files-to-modify list did not name — necessary
  because the existing dispatch mechanisms read the loaded gate-id set directly with no
  parameter of their own to narrow it.
- **Unplanned (Phase 5, process)**: two commit-attribution gaps were found and self-corrected
  during this round (a `--objective`-scoped commit correctly narrowing to one objective's own
  files, and a made-up objective id deriving an empty set) — both logged to `issues.jsonl` as
  process findings, neither affecting the shipped code's correctness, both caught before phase
  closure via routine `git diff` re-checks.
- Otherwise followed the plan's own task lists for phases 4-5 without skipping any task.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: `test-measure-gate-costs.sh`, `test-gate-registry-resolution.sh`,
  `test-gate-cache-lib.sh` (28 cases, up from 16) — all pass, 0 failed
- `lint-shellcheck.sh --quiet` on every touched/new file across both dispatch rounds: 0 findings
- `lint-gate-registry.sh`: all checks pass on the real, populated registry
- Phase 5 integration verification against the real 23-gate registry: cold `--skip-unchanged`
  run (0 skips, correct entries written, finding set identical to a flag-absent run of the
  identical gate selection); warm re-run (14/18 selected gates correctly `[SKIP-CACHED]`, the
  other 4 correctly excluded — 1 genuine failure, 1 genuine warning, 1 never-cache-eligible-by-
  design, 1 unrelated pre-existing finding); corrupted/version-mismatched/unreadable-store cases
  each degrade to a full real run; `--only-gate` scoping now correctly narrows the consult loop
  itself after the `gate_selected()` fix; byte-identity (flag absent) proven via diff against a
  pre-edit capture on both the PASS-branch and FAIL-branch summary-line shapes
- Files verified: Yes

## Impacts

- `gate-registry.data`'s 9th field is now consumed by a real caller (`--skip-unchanged`); any
  future gate addition must declare it correctly or it is permanently never cache-eligible.
- `verify-deploy.sh`'s default (flag-absent) behavior, output, and exit code are unchanged
  (proven byte-identical). `--skip-unchanged` is a new, opt-in, additive-only flag.
- A new gitignored, machine-local store (`specs/.gate-cache/`) now exists; it survives
  `deploy-headless.sh` by construction and does not affect gates 13/14's own checks.
- **The performance fix is the most consequential change in this round for anyone who touches
  `gate-cache-lib.sh` in the future**: any new corpus-scale or file-set operation added to that
  library must use the batched-git-operation + memoization pattern this round established, not
  a per-file loop — see that file's own header and `progress/phase-5-progress.json`'s
  `approaches_tried` for the measured cost of getting this wrong (up to 75s for one consult pass
  against the real registry, with a single gate alone costing 18-51s under contention).

## Follow-ups

- Eight phases remain: Phase 6 (shellcheck acceptance suite + hint coverage), Phase 7
  (attestation integrity), Phase 8 (cut the two verify-deploy-testing stragglers), Phase 9
  (per-gate equivalence proof against the now-landed skip path), Phase 10 (re-derive `JOBS_CAP`),
  Phases 11-12 (evidence-gated derived phases: gate 3's binding floor, gate 8's serialized
  isolation), and Phase 13 (redeploy and final correctness/measurement, which closes the task).
- **Worth a successor's explicit judgment call, not already decided here**: the plan's own text
  invites treating "invalidation first made several of phases 6-13 unnecessary" as a legitimate
  recorded outcome rather than a scope loss, now that Phase 5 has landed and is cheap (4.4s
  consult vs. up to 694s of full-sweep cost it can avoid paying on a typical incremental run).
  Re-assess phases 6-13's individual urgency against a POST-invalidation measurement before
  continuing to grind through them unconditionally.
- One unrelated, pre-existing issue was observed and logged (not fixed, out of this task's file
  scope): gate 10 (`specs/state.json` schema validation --deep) fails with "TODO.md is OUT OF
  SYNC with specs/state.json" against the current committed HEAD state. See `issues.jsonl`.
- See `.orchestrator-handoff.json` and the Phase 5 handoff artifact
  (`handoffs/phase-5-handoff-20261016T044359Z.md`) for the concrete resume point and the
  critical context a successor dispatch needs before starting Phase 6.

## References

- Plan: `specs/416_reaim_gate_cost_model_input_scoped_invalidation/plans/01_input-scoped-gate-invalidation.md`
- Progress files: `specs/416_.../progress/phase-{1,2,3,4,5}-progress.json`,
  `specs/416_.../progress/phase-2-corpus-declarations.md`
- Handoffs: `specs/416_.../handoffs/phase-{1,2,3,4,5}-handoff-*.md`
- Standards: `agent-system/extensions/core/context/standards/shell-script-testing.md` (gate-8
  root-cause verdict section)
