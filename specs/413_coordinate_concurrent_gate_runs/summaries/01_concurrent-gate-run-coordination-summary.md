# Implementation Summary: Task #413

- **Task**: 413 - Coordinate full gate-set runs across concurrent sessions in one repository, so sibling /orchestrate sessions stop contending for the same cores
- **Status**: [COMPLETED]
- **Started**: 2026-10-18T09:36:00Z
- **Completed**: 2026-10-18T12:55:00Z
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_concurrent-gate-run-coordination.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, shell-script-testing.md

## Overview

Added a repository-scoped `.gate-lock` named mutex to `task-lock.sh` (a third independent
critical section alongside `.scope-lock`/`.commit-lock`, built on the existing
`acquire_named_mutex`/`release_named_mutex` primitive) and bracketed the two places a full,
unfiltered gate-set battery actually runs — `tests/run-all.sh`'s top level and
`verify-deploy.sh`'s `gate8_run()` — so two concurrent sessions in one checkout serialize their
batteries instead of contending for the same cores. The mechanism is a bounded-wait lease that
fails open: a waiter blocks for a budget (default 600000ms, strictly below the 1800s staleness
window) while printing a holder-identifying progress line every 15 seconds, then proceeds
unserialized with a loud named `WARNING:` line rather than ever refusing verification. All seven
plan phases closed `[COMPLETED]`: the five required fixtures (serialization, non-vacuousness,
stale-holder reclaim, nested invocation, fail-open) pass against the real mechanism in an
isolated temp root; the contract is documented in
`context/patterns/batch-orchestration-guardrails.md`; the deploy is regenerated and confirmed
byte-identical to the source store; and the complete gate set passes 37/38 against the explicit
source-store target, with the sole failure fully attributed to evidence rather than assumed.

## What Changed

- `agent-system/extensions/core/scripts/task-lock.sh` — `.gate-lock` mutex family
  (`GATE_MUTEX_STALE_SEC`/`GATE_MUTEX_ACQUIRE_BUDGET_MS`/`GATE_MUTEX_PROGRESS_INTERVAL_S`,
  `acquire_gate_mutex`/`release_gate_mutex`, `cmd_gate_acquire`/`cmd_gate_release`, dispatch case
  and usage text, top-of-file contract comment); `acquire_named_mutex` gained an optional,
  backward-compatible fifth `progress_label` parameter for holder-identifying wait-progress
  reporting, byte-equivalent to prior behavior when omitted.
- `agent-system/extensions/core/scripts/tests/run-all.sh` — top-level `.gate-lock` bracket around
  a full, unfiltered, non-nested, non-guest battery: one composed `run_all_exit_cleanup` EXIT
  handler (replacing two prior branch-local traps that would otherwise clobber a release), four
  skip conditions each with a named `Note:` line, fail-open `WARNING:` line, deployed
  `task-lock.sh` resolution in both discovery modes.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `gate8_run()` brackets only its own
  `run-all.sh` invocation; skips on nested/guest/absent-deployed-copy; exports `GATE_MUTEX_HELD=1`
  on real acquisition so the child `run-all.sh` runs as a guest; releases explicitly on every
  exit path.
- `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` — new fixture suite (15 cases):
  serialization, serialization non-vacuousness, stale/killed-holder reclaim, nested invocation
  (both `RUN_ALL_NESTED=1` and inherited `GATE_MUTEX_HELD=1`), no-leak on `--jobs 1`/`--jobs 2`,
  fail-open at both call sites, and verdict identity via the repository's own anchored
  verdict-extraction contract.
- `agent-system/extensions/core/scripts/tests/test-run-all-parallel.sh` — case10's byte-identity
  comparison now filters the new gate-lock `Note:`/`WARNING:` lines before comparing (see
  Decisions below).
- `agent-system/extensions/core/manifest.json` — registered `tests/test-gate-lock.sh`.
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` — new
  "Cross-Session Gate-Run Coordination (`.gate-lock`)" section: the lease-vs-advisory decision,
  the mechanism, the two call sites and why only Gate 8, the four skip conditions, the fail-open
  posture, repo scoping, the never-kill invariant, composability, a Blocking-vs-Advisory
  classification of NEITHER, a Gate Catalogue row, and the two rejected alternatives.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — one cross-reference
  sentence in the measurement-discipline section, confirmed to be the only change (5-line diff).
- `agent-system/extensions/core/index-entries.json` — two `line_count` corrections caused by this
  task's own prose edits.
- Regenerated `.claude/` deploy tree.

## Decisions

- **Progress label as the generic primitive's own bracket tag.** `acquire_named_mutex`'s new
  `progress_label` parameter is used verbatim as the stderr line's bracketed prefix (e.g.
  `[gate-lock] waiting 30s ...`), keeping the primitive genuinely generic rather than hardcoding
  `"gate-lock"` into shared code; every pre-existing caller (`.scope-lock`, `.commit-lock`,
  `.contention-claims`) passes no label and is byte-equivalent to before.
- **`VERIFY_DEPLOY_WAS_NESTED_AT_ENTRY` capture — a genuine integration defect found and fixed.**
  `VERIFY_DEPLOY_NESTED` is exported unconditionally near the top of `verify-deploy.sh` (its own
  pre-existing self-nesting guard), so a naive check of that live variable inside `gate8_run()`
  always read `"1"` regardless of the invocation's true entry state. Confirmed live: a real
  `--only-gate 8` run against the deployed tree showed `tests/run-all.sh` itself, not
  `verify-deploy.sh`, as the `.gate-lock` owner — proof the bracket's own acquire was always
  silently skipped. Fixed by capturing `VERIFY_DEPLOY_WAS_NESTED_AT_ENTRY` before that
  pre-existing export and testing the captured value instead, mirroring `tests/run-all.sh`'s own
  `RUN_ALL_WAS_NESTED_AT_ENTRY` pattern from Phase 2. Re-verified live after the fix: the owner
  file then correctly showed `verify-deploy-gate8-$$`. **This is a general hazard for wiring a
  gate-lock-shaped bracket into any script carrying its own unconditional nested-guard export,
  not specific to this one call site** — the next integrator of this pattern should expect the
  same trap.
- **Fixture-depth precision fix.** `test-gate-lock.sh` nests its fixture's extensions root two
  levels under `$WORKDIR` (`$WORKDIR/agent-system/extensions/core`), not the shallower
  `$WORKDIR/exts/core` an earlier, unrelated fixture (`test-run-all-parallel.sh`) uses for its own
  purpose — required because `tests/run-all.sh`'s deployed-`task-lock.sh` resolution walks
  exactly two levels up from `EXTENSIONS_ROOT`, and only the real repository's own depth makes
  that arithmetic land the mutex at `$WORKDIR/specs/.gate-lock` as intended.
- **Contended measurement labeling, corrected during review.** The
  `GATE_MUTEX_ACQUIRE_BUDGET_MS=0` measurement window is fail-open evidence for an ACTIVE
  bracket (the race's winner still legitimately held the mutex; only the loser's zero-length
  wait budget was defeated) — it is NOT the "coordination disabled" baseline. That baseline (true
  non-vacuousness: coordination genuinely absent) is established separately by Phase 4's fixture
  case, which removes the deployed `task-lock.sh` entirely. The two are valid, distinct pieces of
  evidence and are not interchangeable; the plan body's "Contended Measurement" subsection states
  this explicitly, and scratchpad artifacts were renamed from `measure-lockdisabled-*` to
  `measure-failopen-budget0-*` to match.

## Plan Deviations

- **Task 2.x** (`tests/test-run-all-parallel.sh`): case10's full-output byte-identity comparison
  needed to filter the new gate-lock `Note:`/`WARNING:` lines before comparing, since the two
  invocations under test legitimately take different skip branches (nested vs.
  deployed-task-lock-absent) for a reason orthogonal to the job-scheduling invariant the case
  actually tests. Altered, not skipped; see Phase 2's own plan body for the full record.
- **Task 4.1** (`test-gate-lock.sh`): the plan's literal `$WORKDIR/exts/core` fixture-depth
  shorthand was corrected to `$WORKDIR/agent-system/extensions/core` (two levels under
  `$WORKDIR`) — a precision fix required for the plan's own stated outcome
  (`$WORKDIR/specs/.gate-lock`) to actually hold; see Phase 4's own plan body.

## Verification

- Build: N/A (shell scripts; `bash -n` and `shellcheck -S warning` clean on all touched files)
- Tests: `test-gate-lock.sh` 15/15 PASS against the real mechanism in an isolated temp root;
  every phase's own `--only`-narrowed covering suite passed with no new failures; complete gate
  set 37/38 against the explicit source-store target (see below)
- Files verified: Yes — deployed tree confirmed byte-identical to source store for every touched
  script (`task-lock.sh`, `verify-deploy.sh`, `tests/run-all.sh`,
  `tests/test-run-all-parallel.sh`, `tests/test-gate-lock.sh`)

### Contended Measurement (Phase 5)

Host: 24 cores.

- **Gate lock active**: 1-min load before 0.90, after 2.64 (band 2.4-5.5 throughout). Two
  concurrent real `verify-deploy.sh --only-gate 8` invocations did NOT overlap — the waiting
  invocation's own log carried the live progress line
  `[gate-lock] waiting <N>s for session=<holder> pid=<pid> (mutex=specs/.gate-lock)` at the
  documented 15-second cadence from 15s through 465s before acquiring. Total wall time for both:
  approximately 22 minutes.
- **`GATE_MUTEX_ACQUIRE_BUDGET_MS=0` (forced fail-open, NOT a disabled-coordination baseline —
  see Decisions)**: 1-min load before 1.18, after 6.16, peaking at 16.75 during genuine overlap.
  The race's loser printed the named `ERROR:`/`WARNING:` fail-open lines naming the winning
  holder, then ran its own battery anyway, completing within the same second as the winner.
  Total wall time for both: approximately 15m48s (vs. ~22m serialized).
- Both windows' exit-1 results are attributable solely to Gate 8's own pre-existing
  failing-suite set, never to the coordination mechanism, which produced no WARNING in the
  serialized window and the EXPECTED, designed WARNING in the forced-fail-open window.
- These figures are deliberately taken under self-generated contention (an idle-host figure is
  not evidence for this task) and measure this host, at this moment, with exactly two writers —
  not a general throughput claim.

### Phase 7 Full Gate-Set Result

`bash .claude/scripts/verify-deploy.sh /home/benjamin/.config/nvim`: **37 of 38 checks passed**,
1-min load 1.69-2.06 throughout, no `FINDING` lines. Sole failure: Gate 8's own suite-level
`[FAIL]`. A direct `tests/run-all.sh --jobs 1` breakdown in the same quiet window resolved it:
`157 passed, 2 failed (1 expected, 1 NEW), 0 skipped, 159 total`.

- `test-gate-cache-equivalence.sh` — EXPECTED (the dispatch's own enumerated known-unrelated
  baseline).
- `test-orchestrate-cycle-postflight.sh` — NEW, but **not attributable to this task**: traced to
  an uncommitted foreign working-tree mutation in
  `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`'s
  `cycle_modified_files`/`invocation_modified_files` accumulator loops (`while IFS= read -r f; do`
  changed to `while false && IFS= read -r f; do` at two sites) — that suite's own documented
  deliberate-break regression-anchor technique, left un-reverted by whichever other task exercised
  it. `orchestrate-cycle-postflight.sh` is not in this task's declared `file_scope`, its recent
  commits belong to other tasks, and a `while false &&` guard is never legitimate production
  code. Left untouched; outside this task's scope to fix.

`test-lake-build-guard.sh` and `test-verify-deploy-context-budget.sh`, both anomalous in earlier
measurement windows of this same development session, passed clean in this quiet sequential run —
confirming those earlier results were load artifacts, not regressions.

Gate 8's own section of the full gate-set run printed neither a skip `Note:` nor a fail-open
`WARNING:` line (none of the four skip conditions applied, and the mutex was not contended),
meaning the acquire-and-release round-trip completed silently via the happy path exactly as
designed; `specs/.gate-lock` was confirmed absent immediately after the run completed — the
mechanism verifying itself under its own final gate.

This is a reasoned exclusion, not a silent drop: the one deviation from a clean 38/38 is fully
attributed to evidence gathered during this phase, and no suite was re-run chasing a green
result the evidence already explains.

## Impacts

- Every future full gate-set run (`tests/run-all.sh` with no `--only`, or `verify-deploy.sh`'s
  Gate 8 without `--skip-slow`/an excluding `--only-gate`) across concurrent sessions in one
  repository now serializes instead of contending for the same cores, with a bounded,
  observable wait and a mandatory fail-open escape — directly addressing the 650-second,
  two-retry Gate 8 stall and the 39.91-load/18-process contention episode that motivated this
  task, without ever risking the machine-wide `pkill` anti-pattern those incidents produced.
- `orchestrate-batch-gate.sh`'s batch-level deferral and `verify-deploy.sh`'s existing
  `--skip-slow`/`--only-gate`/cost-class selection surface are unchanged and compose cleanly with
  this mechanism (either one simply never reaches the bracket).

## Follow-ups

- The foreign `orchestrate-cycle-postflight.sh` mutation identified during Phase 7 (see above) is
  outside this task's scope; it needs reverting by whoever owns that file, not by this task.
- Cross-session reuse of a sibling's gate verdict, and auto-degrading to a narrower gate
  selection on contention, were both deliberately rejected (see
  `context/patterns/batch-orchestration-guardrails.md`'s new section) and remain open future
  work only if a future need justifies the additional machinery they would require.

## References

- Plan: `specs/413_coordinate_concurrent_gate_runs/plans/01_concurrent-gate-run-coordination.md`
  (all seven phases `[COMPLETED]`, including this phase's own "Phase 7 Gate-Set Result",
  "Commit-Containment Catch-Up", and "Integration Defect, Restated for the Final Record"
  subsections)
- Research report: `specs/413_coordinate_concurrent_gate_runs/reports/01_concurrent_gate_run_coordination.md`
- New contract documentation: `context/patterns/batch-orchestration-guardrails.md`'s
  "Cross-Session Gate-Run Coordination (`.gate-lock`)" section
- Progress files: `specs/413_coordinate_concurrent_gate_runs/progress/phase-{1..7}-progress.json`
