# Implementation Summary: Task #411

- **Task**: 411 - Systematically refactor the verify-deploy gate set and shell test runner into a unified, parallel, declarative gate framework
- **Status**: [IN PROGRESS]
- **Started**: 2026-10-15T00:00:00Z
- **Completed**: N/A (partial -- phases 1-6 of 11 complete)
- **Effort**: ~10 hours (across dispatches)
- **Dependencies**: None
- **Artifacts**: plans/01_gate-framework-refactor.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Phases 1-5 of the 11-phase gate-framework refactor are complete and committed. Phases 1-2 landed
the independently-landable, correctness-critical Gate 8 finding-extraction fix (and its
generalization to all 14 previously-unanchored call sites) ahead of the larger registry work, per
the dispatch's own explicit priority. Phase 3 built a mechanical, idle-guarded cost-measurement
harness and captured a clean, fully-idle 23-gate cost table, replacing the dispatch's and
research's carried-forward figures with freshly re-derived ones. Phase 4 introduced the
declarative gate registry and migrated gates 1-8 onto it with proven byte-identical output.
Phase 5 completed the migration (gates 9-23 wrapped as `gateN_run()` functions, one shared
execution loop replacing all 15 remaining copy-pasted top-level blocks), added `--max-cost
{free|moderate|slow}` cost-class selection (intersecting with `--only-gate`, order-independent),
and re-verified all five `deploy_findings_snapshot` callers green. Phase 6 enforced both
previously-declared-but-unenforced timeout bounds: a new `gate_registry_exec_bounded` primitive
in `gate-registry-lib.sh` runs each migrated gate under its registry-declared `timeout_s`
(killing the whole process group, not just the immediate child, on expiry, via a `declare -p`
state-dump/reconcile protocol that survives the subshell a killable bound requires), and
`run-all.sh` gained a uniform `RUN_ALL_SUITE_TIMEOUT_S` (default 600s) applied identically in
its sequential and parallel paths via `timeout -k 5`. Both bounds are proven to fire (and name
the right unit) against deliberately-stalled synthetic fixtures, and a full, un-scoped
`verify-deploy.sh` run on an idle machine converged to exactly Phase 5's documented failure set
with zero new failures and zero bound trips. Phases 7-11 (concurrency, shellcheck
parallelization, corpus enumeration, run-all.sh default flip, final redeploy and measured
verification) remain.

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
- `agent-system/extensions/core/scripts/verify-deploy.sh` (Phase 5) — gates 9-23 wrapped as `gateN_run()` functions (bodies preserved verbatim); the single gate-execution loop moved to after all 23 definitions; new `--max-cost {free|moderate|slow}` selection flag added (resolves against `gate-registry.data`'s `cost_class` field, intersects with `--only-gate` order-independently, empty-intersection sentinel `"0"`).
- `agent-system/extensions/core/scripts/gate-registry.data` (Phase 5) — 15 new rows for gates 9-23 (timeout_s/cost_class derived from Phase 3's measured averages; `requires_source_store` read off each gate's own SKIP guard).
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` (Phase 5) — case1 updated to expect ids 1-23 (was 1-8).
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` (Phase 5) — 5 new `--max-cost` regression cases (i-m: exact free-class set, moderate superset, invalid class, order-independent intersection with `--only-gate`, zero-intersection naming both flags).
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` (Phase 6) — new `gate_registry_exec_bounded` function: runs a gate's invoke function under a real, killable bound (a `set -m` job-control subshell whose backgrounded job is killed by process GROUP, not just its immediate pid, on timeout), reconciling `CHECKS`/`FAILURES`/`FINDINGS_LIST`/`CURRENT_GATE` back via a `declare -p` dump/source roundtrip on a clean finish; an empty/zero `timeout_s` degrades to a direct same-process call.
- `agent-system/extensions/core/scripts/verify-deploy.sh` (Phase 6) — the gate-execution loop now calls `gate_registry_exec_bounded` per gate id instead of the bare `"gate${id}_run"`; a timeout (rc=124) is translated into a named `[FAIL] gate<N> (<invoke>) exceeded its <bound>s timeout` plus a `FINDING gate<N> TIMEOUT: ...` row, never aborting the battery.
- `agent-system/extensions/core/scripts/gate-registry.data` (Phase 6) — header updated: `timeout_s` is now documented as ENFORCED (was "NOT YET ENFORCED" through Phase 5); row data unchanged (values were already sized in Phase 4/5).
- `agent-system/extensions/core/scripts/tests/run-all.sh` (Phase 6) — new `RUN_ALL_SUITE_TIMEOUT_S` (default 600s), validated and applied via `timeout -k 5 "$BOUND" bash "$suite"` in both the sequential path and the parallel `run_one()` path; a new `SUITE_RC` array carries the real exit status (not collapsed to 0/1) so the emission loop can recognize `timeout`'s bimodal 124/137 exit-status contract and print a named `TIMEOUT: <suite> exceeded the <bound>s per-suite bound` detail line.
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` (Phase 6) — 4 new cases (11-14): clean-finish scalar+array reconciliation, the no-bound direct-call degrade path, the timeout-and-process-group-kill path (with an exact-pid leftover check, not a broad `pgrep -f` pattern), and a pin that all 23 real gates carry an enforceable bound.
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` (Phase 6) — 3 new cases (11-13) in a new PART 4: sequential per-suite timeout, parallel per-suite timeout isolating only the stalled suite, and a SIGTERM-ignoring fixture proving `-k 5`'s SIGKILL escalation actually fires.

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
- (Phase 6) The gate-level timeout/reconcile mechanism runs the gate function AND its `declare -p`
  state dump inside the SAME backgrounded job (`{ fn; declare -p ...; exit $rc; } &`), never a
  separate parent subshell that backgrounds-then-waits-then-dumps — the latter shape silently
  loses every mutation, since `&` always forks regardless of job-control mode, so a dump one
  level up reads a different process's memory than the one that actually ran the gate.
- (Phase 6) Process-group isolation for the gate-level kill uses bash's own `set -m` (job-control
  monitor mode), not the external `setsid` binary, to avoid a new binary dependency this
  codebase's existing portability bar does not otherwise require.
- (Phase 6) `timeout`'s own exit-status contract is bimodal (124 when SIGTERM alone sufficed, 137
  when `-k`'s SIGKILL escalation was needed) — both suite-level timeout detection sites in
  `run-all.sh` check both values, proven against a `trap '' TERM` fixture.
- (Phase 6) A real, corpus-discovered stalled fixture file (`test-stalled-fixture.sh`) was built
  and manually verified, then deleted before commit once the formal regression cases ended up
  using fully self-contained synthetic fixtures instead (safer, matches the existing pattern in
  both affected test files, and avoids a permanent tax on every future real `run-all.sh`
  discovery run plus an avoidable `file_scope` Containment Self-Check drop).

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
- **Task 5.1** confirmed, not altered: Phase 5 continued gates 9-23 on the SAME non-generic-fold
  convention gates 1-8 established in Phase 4 (each `gateN_run()` sets its own `CURRENT_GATE`
  verbatim) — the plan's Scope Hypothesis predicted this migration would shrink
  `verify-deploy.sh` to "materially fewer lines"; measured result is the opposite (1350 -> 1473
  lines, grew) because no gate's inline body was deleted, only the per-gate loop boilerplate was
  deduplicated. Recorded as the Scope Hypothesis's own actual-figures result, not a deviation.
- **Task 5.7** altered: the literal "capture the complete battery's output before and after...
  require identical finding sets" was satisfied via a scoped `--only-gate 9-23` before/after
  (byte-identical) plus one full-battery capture with every FAIL line root-caused, rather than a
  full-battery byte-diff against a pre-task baseline — see Phase 5's own plan completion note and
  `progress/phase-5-progress.json`'s `deviations[0]` for the full reasoning (a pre-task baseline
  diff is confounded by legitimate, accumulating pre-redeploy drift from every phase's files,
  expected and deferred to Phase 11).
- **Task 6.4** satisfied via self-contained synthetic fixtures (built fresh inside each test's
  own `mktemp -d` WORKDIR) rather than the literal "a suite that sleeps past its bound" read as a
  real, standalone, corpus-discovered file — see Decisions above for why the real file was
  built, verified, then deleted before commit. This is a mid-phase implementation correction,
  not a scope reduction: the deliberately-stalled-fixture coverage the task calls for is fully
  present (3 new cases in `test-run-all-selection.sh`, 2 of the 4 new cases in
  `test-gate-registry-resolution.sh`), just homed in the test files themselves rather than the
  real `scripts/tests/` corpus.

## Verification

- Build: N/A (shell scripts)
- Tests: All new/extended suites pass — `test-deploy-baseline-lib.sh` (24/24), `test-orchestrate-batch-gate.sh` (10/10), `test-run-all-selection.sh` (16/16), `test-measure-gate-costs.sh` (8/8), `test-gate-registry-resolution.sh` (10/10), `lint-gate-registry.sh` (5/5 checks, 4 seeded-violation shapes confirmed caught), `shellcheck` clean on every new/modified file.
- Files verified: Yes
- Byte-identical before/after: Gate 8's findings (Phase 1/2), the complete `--only-gate 1,...,8`
  stdout/stderr/exit-code capture (Phase 4), and the complete `--only-gate 9,...,23`
  stdout/stderr/exit-code capture (Phase 5) are all confirmed byte-identical pre/post change.
- Phase 5 additionally re-ran six existing consumer/registry test suites green post-migration:
  `test-gate-registry-resolution.sh` (10/10), `test-verify-deploy-gate-selection.sh` (14/14),
  `test-orchestrate-batch-gate.sh` (26/26), `test-orchestrate-cycle-plan.sh` (371/371),
  `test-deploy-baseline-lib.sh` (24/24), `test-gate-out-self-attribution.sh` (11/11).
- Phase 6: `test-gate-registry-resolution.sh` (14/14, 4 new cases) and `test-run-all-selection.sh`
  (19/19, 3 new cases) pass; the same six-suite Phase 5 regression net was re-confirmed green
  post-Phase-6 (`test-verify-deploy-gate-selection.sh` 14/14, `test-orchestrate-batch-gate.sh`
  26/26, `test-orchestrate-cycle-plan.sh` 371/371, `test-deploy-baseline-lib.sh` 24/24,
  `test-gate-out-self-attribution.sh` 11/11); `lint-gate-registry.sh --verbose` 5/5. A scoped
  `--only-gate 9-23` before/after byte-diff (stdout AND stderr) against the pre-Phase-6 code
  confirmed zero behavioral change for the non-timeout path. A full, un-scoped
  `verify-deploy.sh --findings` run on an effectively-idle machine (load ~2.0/24 cores) produced
  zero `TIMEOUT:` lines and exactly Phase 5's documented 5-suite failure set (3 pre-existing, 2
  deploy-lag) plus gate3/gate5/gate20's own already-documented pre-existing findings — no new
  failures, no bound trips. One real flake was caught and fixed during this phase's own
  verification: case13's original `pgrep -f "sleep 30"` leftover check collided with a
  concurrent sibling suite's own unrelated `sleep 30` inside a real `--only-gate 8` run; fixed to
  check the stalled descendant's exact captured pid instead, re-confirmed clean both standalone
  (with a deliberately injected concurrent `sleep 30`) and inside a real `--only-gate 8` re-run.
- One known-unrelated pre-existing failure observed during Phase 4's verification run (and
  confirmed still present, unchanged, in Phase 5's full-battery capture): `test-verify-deploy-context-budget.sh` fails due to Gate 20's eager-load budget being genuinely ~988B over baseline right now — this is the dispatch's own named, excluded pre-existing defect, confirmed unrelated to any file this work touched. Phase 5's full-battery capture additionally surfaced (and root-caused) two more gate8 suite failures tracing to the same pre-existing cause plus accumulated pre-redeploy deploy-lag — see Phase 5's plan completion note.

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

- Phase 7 (gate-level concurrency scheduler) is the next phase to dispatch. It should EXTEND
  Phase 6's `gate_registry_exec_bounded` subprocess/output-capture/state-reconcile primitive
  (the exact mechanism its own "per-gate output captured to its own file" requirement needs)
  rather than build a second, parallel notion of per-gate subprocess execution.
- Phase 7 must address the `CURRENT_GATE`-global-scoping gap Phase 4 explicitly deferred.
- Any future stalled-fixture test should capture and check an exact child pid for leftover-
  process detection, never a broad `pgrep -f <pattern>` match — see Phase 6's case13 flake.
- `suite-cost-hints.txt`'s `test-verify-deploy-context-budget.sh` row (228595ms) carries a
  documented tail-load-contamination caveat; a future idle re-run would tighten it, though the
  file's own advisory-only nature means this is not blocking.
- The pre-existing Gate 20 eager-load budget overage (~988B) remains open and unrelated to this task, per the dispatch's explicit exclusion.
- Phase 11's redeploy should be expected to clear the gate3/gate5 "content differs"/"not in
  provides.scripts" findings and the two extra gate8 suite failures Phase 5's full-battery
  capture surfaced (`test-deploy-verify-wiring.sh`, `test-verify-deploy-context-budget.sh`'s own
  fixture precondition) — re-check this specific list after that redeploy rather than assuming it
  cleared.

## References

- Plan: `specs/411_refactor_verify_deploy_gate_framework/plans/01_gate-framework-refactor.md`
- Progress files: `specs/411_refactor_verify_deploy_gate_framework/progress/phase-{1,2,3,4,5,6}-progress.json`
- Handoffs: `specs/411_refactor_verify_deploy_gate_framework/handoffs/phase-{1,2,3,4,5,6}-handoff-*.md`
