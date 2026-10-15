# Implementation Summary: Task #411

- **Task**: 411 - Systematically refactor the verify-deploy gate set and shell test runner into a unified, parallel, declarative gate framework
- **Status**: [IN PROGRESS]
- **Started**: 2026-10-15T00:00:00Z
- **Completed**: N/A (partial -- phases 1-7 of 11 complete)
- **Effort**: ~13 hours (across dispatches)
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
with zero new failures and zero bound trips. Phase 7 added gate-level concurrency: a new
`gate_registry_exec_concurrent_batch` scheduler (ported in shape from `run-all.sh`'s own proven
worker-slot pool) runs independent gates concurrently via a new `--jobs N|auto` flag (default
`auto`, nproc capped at 4; `--jobs 1` is the byte-identical sequential opt-out), honouring
declared dependency edges via a hard wave-barrier, running the registry's one `serialized=true`
gate (gate 8) alone, and scheduling longest-first by cost class. Output and the final PASS/FAIL
line are proven byte-identical across worker counts (CHECKS/FAILURES are pure sums,
FINDINGS_LIST is already sort-u'd downstream, narrative is always emitted in declaration order).
A nested-invocation guard (`VERIFY_DEPLOY_NESTED`) mirrors `RUN_ALL_NESTED` exactly. Two real
concurrency bugs were caught and fixed via the new test coverage during this phase's own
implementation (see Decisions). Measured real speedup: a 7-gate moderate-cost selection went
from ~70s (jobs=1) to ~43s (jobs=4, ~1.6x); a full unscoped battery run completed in 790s with a
finding set matching Phase 6's documented baseline (modulo expected, already-deferred
pre-redeploy drift for this phase's own touched files). Phases 8-11 (shellcheck parallelization,
corpus enumeration, run-all.sh default flip, final redeploy and measured verification) remain.

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
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` (Phase 7) — new `gate_registry_exec_concurrent_batch` function (worker-slot pool, wave-barrier dependency honouring, serialized-class isolation, longest-first cost-class scheduling) plus two new reconciliation helpers, `_greg_snapshot_vars`/`_greg_apply_delta` (shared-baseline-plus-delta accumulation across concurrently-forked gates — scalar sum, array union-append, last-write-wins for a non-numeric scalar).
- `agent-system/extensions/core/scripts/verify-deploy.sh` (Phase 7) — new `--jobs N|auto` flag (default `auto`); JOBS resolution (nproc capped at 4) and the `VERIFY_DEPLOY_NESTED` nested-invocation guard added after argument parsing; the gate-execution loop now dispatches to `gate_registry_exec_concurrent_batch` at `--jobs` > 1 (reading each gate's pre-computed out/err/state/rc files) or the unchanged sequential `gate_registry_exec_bounded` loop at `--jobs 1`; `-h`/`--help`'s `sed` range widened to cover the full header (it was silently truncating mid-section even before this phase).
- `agent-system/extensions/core/scripts/gate-registry.data` (Phase 7) — header comments updated: `dependencies` and `serialized` are now documented as CONSUMED by the new scheduler (row data unchanged).
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` (Phase 7) — 7 new cases (15-21): dependency wave-barrier ordering, serialized-class temporal isolation (flock-guarded), worker-cap enforcement (flock-guarded, after catching the mapfile/wait-n race described in Decisions), multi-id delta reconciliation, cross-worker-count determinism, the second-call associative-array-corruption regression pin, and 124-timeout exclusion from reconciliation.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` (Phase 7) — 5 new cases (n-r): `--jobs` invalid-value validation, `--jobs auto` sanity, byte-identical output at jobs 1/2/4 on the real registry, and the nested-guard relative-wall-clock-ratio proof.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (Phase 7) — new "Gate-level parallelism-safety audit (Phase 7)" section recording the live per-gate audit result (no gate besides gate 8 needs serialization) and the two real scheduler bugs this phase's own test coverage caught.

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
- (Phase 7) A naive "source each concurrently-forked id's dump in sequence" reconciliation is
  WRONG: every subshell's dump is "shared snapshot + own delta," not a running total, so
  sourcing them in sequence REPLACES rather than ACCUMULATES, silently dropping every
  contribution except the last one sourced. Fixed with a snapshot-once-per-dispatched-group,
  apply-each-id's-delta design.
- (Phase 7) `--jobs` defaults to `auto`, not `1` — the dispatch's own EFFICIENCY goal would not
  materialize for an ordinary caller if concurrency were opt-in only; `--jobs 1` remains the
  explicit, byte-identical sequential opt-out.
- (Phase 7) The nested-invocation guard is verified via a RELATIVE wall-clock ratio, not output
  equality — output is already proven byte-identical at every worker count, so equality alone
  cannot distinguish "ran sequentially" from "ran concurrently and produced the same text."
- (Phase 7) The Phase 4-deferred "`CURRENT_GATE` is a global reassigned by each gate function"
  concern is resolved STRUCTURALLY, not by restructuring the variable: every gate (concurrent or
  not) already runs inside its own forked subshell via Phase 6's `gate_registry_exec_bounded`,
  so concurrently-running gates never share a mutable `CURRENT_GATE` in the first place.

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
- Phase 7: `test-gate-registry-resolution.sh` (21/21, 7 new cases) and
  `test-verify-deploy-gate-selection.sh` (18/18, 5 new cases) pass, confirmed across 5 repeated
  runs each post-fix with zero flakes; the broader Phase 5/6 regression net (`test-deploy-
  baseline-lib.sh`, `test-orchestrate-batch-gate.sh`, `test-run-all-selection.sh`, `test-gate-
  out-self-attribution.sh`, plus the two suites above) re-confirmed green via one `run-all.sh
  --jobs auto` invocation (6/6), and `test-orchestrate-cycle-plan.sh` separately (1/1);
  `lint-gate-registry.sh --verbose` 5/5; `lint-shellcheck.sh` clean on every touched file. A
  7-gate `--only-gate` selection's output was confirmed byte-identical at `--jobs` 1, 2, and 4 on
  the real registry. A full, unscoped `verify-deploy.sh --findings` run (auto jobs, load ~4-6/24
  cores) completed in 790s (13.2 min), rc=1, 5 of 37 checks failed, ZERO `TIMEOUT:` lines: Gate
  8's 5-suite failure set is IDENTICAL to Phase 6's documented capture (the 3 dispatch-named
  pre-existing failures plus the 2 already-root-caused deploy-lag failures); Gate 20's eager-load
  finding (67088 B vs. 66100 B baseline = exactly 988 B over) matches the dispatch's own named
  exclusion verbatim; Gate 3/5's "content drift"/"differs from source" findings for this phase's
  own touched files are expected, already-documented pre-redeploy accumulation (deferred to Phase
  11), not a regression; Gate 4's and Gate 16's findings are confirmed unrelated to this task.
  Measured real speedup: a `--max-cost moderate` selection went from ~70s (`--jobs 1`) to ~43s
  (`--jobs 4`, auto-resolved default on this 24-core host), byte-identical output.

## Impacts

- The Gate 8 finding-extraction fix (Phases 1-2) is immediately load-bearing: it corrects the
  findings set five separate consumers read, including `orchestrate-cycle-plan.sh`'s Inter-Cycle
  Redeploy Checkpoint, which gates whether an orchestration batch proceeds.
- `scripts/measure-gate-costs.sh` and its clean idle cost table (`progress/phase-3-gate-cost-model.csv`) are the new single source of truth later phases (5+) must derive timeouts and
  scheduling priority from, superseding the dispatch's and research's carried-forward figures.
- Gates 1-8 now have a working declarative-registry migration path to follow for the remaining 15
  gates (Phase 5), with the mechanical patterns (function-wrap, TSV row, byte-identical capture)
  already proven.
- Gate-level concurrency (Phase 7) is immediately load-bearing for the dispatch's own EFFICIENCY
  goal: the default `--jobs auto` means an ordinary caller already gets the speedup without
  needing to discover or pass a flag.

## Follow-ups

- Phase 8 (one-process-per-file shellcheck parallelization) is the next phase to dispatch. It
  depends only on Phase 3 (already complete), not on Phase 7, so it can start cleanly.
- Any future `mapfile -t ARR < <(pipeline)`-then-`wait -n`-dispatch worker pool should drain the
  pipeline with a bare `wait` before its own cap-dispatch loop begins — see Phase 7's Decisions
  for the real, intermittent cap-violation bug this omission caused.
- Any future concurrency test asserting "worker cap N was never exceeded" should use a
  `flock`-guarded atomic counter (or real timestamp-overlap checking), never a bare,
  non-atomic read-modify-write counter file — see Phase 7's Decisions for why the naive form
  masked a real bug for several initial test runs.
- Any future function that resets a global associative array something else `unset`s between
  calls must reassert `declare -gA` explicitly on every reset, never a bare `NAME=()` — see
  Phase 7's Decisions for the exact crash this caused.
- Any future stalled-fixture test should capture and check an exact child pid for leftover-
  process detection, never a broad `pgrep -f <pattern>` match — see Phase 6's case13 flake.
- Phase 11's redeploy is expected to clear the gate3/gate5 drift findings for Phase 7's own
  touched files (`run-all.sh`, `test-run-all-selection.sh`, `test-verify-deploy-gate-selection.sh`,
  `verify-deploy.sh`, `shell-script-testing.md`), in addition to the Phase 5-documented list
  below — re-check the full combined list after that redeploy rather than assuming it cleared.
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
- Progress files: `specs/411_refactor_verify_deploy_gate_framework/progress/phase-{1,2,3,4,5,6,7}-progress.json`
- Handoffs: `specs/411_refactor_verify_deploy_gate_framework/handoffs/phase-{1,2,3,4,5,6,7}-handoff-*.md`
