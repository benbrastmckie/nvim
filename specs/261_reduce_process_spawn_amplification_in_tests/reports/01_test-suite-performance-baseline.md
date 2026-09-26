# Research Report: Task #261

**Task**: 261 - Reduce process-spawn amplification in tests
**Started**: 2026-09-26T00:30:00Z
**Completed**: 2026-09-26T01:01:00Z
**Effort**: Research (measurement-first, as the dispatch required)
**Dependencies**: None (independent of, but adjacent to, task 262 "reduce redundant verify-deploy
passes" — see Risks & Mitigations for the boundary between the two)
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/`, `.../tests/`), two
full-suite timed executions of `run-all.sh` and an instrumented per-suite variant, direct file
reads of the top-cost suites
**Artifacts**: This report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- **The full suite was measured for the first time.** Sequential wall time across all 95 shell
  test suites discovered by `run-all.sh` (core + lean + literature + typst extensions) is
  **~649-650 seconds (~10m50s)**, corroborated by an independent `time run-all.sh` run at
  **10m6.887s** real time. Both numbers agree to within measurement noise; treat **~10 minutes**
  as the baseline.
- **One file dominates: `core/scripts/tests/test-verify-deploy-context-budget.sh` costs 391.4
  seconds — 60% of the entire suite's sequential wall time — by itself.** It runs the real
  `verify-deploy.sh` (all ~19 non-slow gates, not just the Gate 20 it is testing) four times
  against a real 16MB rsync'd fixture tree, at roughly 100s per invocation. This is **the single
  largest lever available**, and it was **not named anywhere in the dispatch's "directions to
  evaluate."**
- **The dispatch's hypothesized culprit (`test-force-phases.sh`'s 46 subprocess invocations) is
  real but wall-clock-irrelevant**: that file costs 5.39s of the suite's ~650s (0.8%). Eliminating
  every one of its subprocess calls entirely would save well under 1% of total runtime.
  Fixture-reuse and in-process-helper work aimed at this file specifically is not where the time
  is.
- A short list of other files carry real, non-trivial cost from genuine subprocess/git work:
  `test-orchestrate-cycle-plan.sh` (44.7s, 32 real self-invocations plus a genuinely-stubbed
  `verify-deploy.sh` — a pattern worth reusing elsewhere), `test-git-commit-scoped.sh` (20.1s, real
  git init/commit fixtures), `test-roadmap-argv-ceiling.sh` (17.0s), `test-orchestrate-cycle-postflight.sh`
  (16.9s, real `state-write.sh`/`orchestrate-cycle-postflight.sh` calls), `test-state-write-concurrency.sh`
  (12.2s, deliberately exercises lock contention). Together with the dominant file, **7 files (of
  95) account for ~510s of ~614s of core's own total (83%)**; the other 74 core suites average
  ~1.4s each and are already fast.
- A genuine, pre-existing flake was caught incidentally: `test-gate-out-repair-reporting.sh`
  failed in one full-suite run and passed cleanly (19/19) on immediate re-run and in the other
  full-suite run, with no code changes in between. This is **baseline noise unrelated to this
  task** and must not be misattributed to any future change here.
- **Recommended priority order for the plan phase**: (1) give `verify-deploy.sh` a way to run a
  single gate (or narrow gate range) so `test-verify-deploy-context-budget.sh`'s four full-battery
  calls collapse from ~100s to a few seconds each; (2) file-level parallelism across the suite
  (the coarse, safe grain the dispatch already favored), scheduling the long tail first; (3)
  targeted in-process extraction for the moderate offenders that do real repeated subprocess work
  (`test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh`); (4) fixture-reuse
  and file-splitting are lowest priority — the measurements do not support them as high-value on
  their own.

## Context & Scope

This is a research-only dispatch. The dispatch explicitly reframed the task after an earlier
mis-attribution: the observed `/orchestrate 257-259` stall was NOT caused by this test suite
(it runs under `--skip-slow` on the orchestrate critical path, per `deploy-headless.sh:402`).
This task is a standalone developer-experience improvement for anyone running the suite directly
or running a full-depth verify. The dispatch required, as the **first** piece of work, an actual
measurement of the full suite (not just the two sample files it named) before any optimization
direction is chosen. That measurement is the substance of this report.

**Hard constraint carried forward unchanged**: no test may be weakened, skipped, or deleted to
make the suite faster; coverage (test count, assertion count) must be demonstrably identical or
higher after any change; a test found genuinely redundant must be justified as its own decision,
never folded into a performance change.

## Findings

### Measured Baseline (the deliverable Stage "first piece of work" required)

Two full-suite runs were executed against the unmodified working tree, via
`agent-system/extensions/core/scripts/tests/run-all.sh` (source-store mode; it auto-discovers
every extension's `scripts/tests/test-*.sh` and flat `scripts/test-*.sh`, not just core's):

| Run | Method | Wall time | Result |
|---|---|---|---|
| 1 | `time bash run-all.sh --quiet` (single aggregate timer) | **10m6.887s** real (6m25.0s user, 4m36.4s sys) | 91 passed, 4 failed, 95 total |
| 2 | Custom per-suite timer (same discovery logic, `date +%s%N` around each `bash "$suite"`) | **649.437s** (~10m49s) sum of per-suite times | 90 passed, 5 failed, 95 total (+1 flake, see below) |

Discovery breakdown (95 suites total, matches both runs):

| Extension | `scripts/tests/*.sh` | flat `scripts/test-*.sh` | Total suites | Total wall (run 2) |
|---|---|---|---|---|
| core | 72 | 9 | 81 | 614.15s (94.6%) |
| literature | 5 | 1 | 6 | 22.61s |
| lean | 6 | 0 | 6 | 10.89s |
| typst | 2 | 0 | 2 | 1.79s |
| email, memory, nix, nvim | 0 | 0 | 0 | 0s |

Core alone is 85% of suites and 94.6% of wall time — confirms the task's territory (core-only
`agent-system/extensions/core/**`) is the right place to act.

### The dominant cost: one file, 60% of total time

`core/scripts/tests/test-verify-deploy-context-budget.sh` (261 lines) costs **391.44s alone**.
Reading it explains why: it is a fixture-driven regression suite for `verify-deploy.sh`'s Gate 20
(the orchestrator context-budget lock). Its own header comment already documents an earlier
optimization — combining what could have been three separate `verify-deploy.sh` invocations into
one ("this suite's runtime is dominated by verify-deploy.sh's OTHER 19 gates re-scanning the
fixture tree on every call, not by Gate 20 itself, so minimizing the invocation COUNT ... is what
keeps this suite's wall-clock bounded") — but it still makes **four** full invocations of the real
`verify-deploy.sh --skip-slow --findings --quiet` against a real, rsync-copied ~16MB fixture tree
(baseline, combined run B covering 3 cases, case 3 under `hard` mode, and case 4 via
`deploy_findings_snapshot`), each taking roughly 100s because every one of `verify-deploy.sh`'s
~19 non-slow gates re-scans the whole fixture tree, even though only Gate 20 is under test.

`verify-deploy.sh` has no flag to run a single gate or a narrow gate range — only `--skip-slow`
(defers gate 8 specifically), `--findings`, `--quiet`, and `--minimal-init`. There is no
`--only-gate` / `--gates` selector.

This is, by a wide margin, the single biggest lever in the entire suite: eliminating even three of
the four full-battery calls (by adding a way to run only Gate 20) would cut roughly 290s off the
~650s total — a ~45% reduction in one change, before touching anything the dispatch's own
"directions to evaluate" named.

### The dispatch's named example, measured

`test-force-phases.sh` (530 lines, 46 subprocess invocations of `state-write.sh` (14x),
`orchestrate-cycle-plan.sh` (10x), `orchestrate-stage5-postflight.sh` (10x), plus
`skill-base.sh`/`task-lock.sh`/`parse-command-args.sh`) measured at **5.39s** — matching the
dispatch's own pre-measured 5.0s figure closely. At 0.8% of the ~650s total, this file's
subprocess amplification, while real and structurally as described, is **not a meaningful
wall-clock target on its own**.

Two supporting micro-measurements explain why subprocess amplification here is cheap in absolute
terms:
- Bare `bash -c ':'` vs. `bash -c 'source lib/common.sh'`, 50 iterations each: **0.115s vs.
  0.119s** — sourcing `common.sh` adds essentially nothing over bash's own process-startup cost.
  The "re-sources 5+ libraries" cost the dispatch flagged is real as a code-structure observation
  but is not where the milliseconds go.
- `jq '.active_projects | length' specs/state.json` (1244-line real state.json), 14 iterations:
  **0.067s total** (~5ms each). Re-parsing state.json from scratch, per the dispatch's concern, is
  cheap.

The actual per-call cost in heavier scripts (`state-write.sh`: mutex acquire/release plus a full
transform/validate/mv sequence; `orchestrate-cycle-plan.sh`: 2437 lines of real orchestration
logic) is dominated by what those scripts *do*, not by shell/library-sourcing startup overhead.

### Other real, non-trivial offenders (core, sorted by cost)

| Suite | Wall (run 2) | Why (from reading the file) |
|---|---|---|
| test-verify-deploy-context-budget.sh | 391.44s | 4x real `verify-deploy.sh` full-gate-battery calls (above) |
| test-orchestrate-cycle-plan.sh | 44.71s | 3839 lines; 32 real self-invocations of `orchestrate-cycle-plan.sh`, but **already stubs `verify-deploy.sh`** with a fast fixture replacement (writes a stub script + a call-counting marker) rather than calling the real one — a pattern worth generalizing |
| test-git-commit-scoped.sh | 20.11s | 4 separate `mktemp -d` fixtures, each with real `git init`+commit sequences |
| test-roadmap-argv-ceiling.sh | 17.03s | real `mktemp -d`/git fixture + `state-write.sh` |
| test-orchestrate-cycle-postflight.sh | 16.87s | 1902 lines; 10 real `orchestrate-cycle-postflight.sh` invocations, 3 real `state-write.sh` calls, 3 real `git commit`s |
| test-state-write-concurrency.sh | 12.22s | deliberately exercises real lock contention on `state-write.sh` — cost is closer to inherent than incidental |
| test-routing-resolution.sh | 8.00s | — |

These 7 files sum to 510.4s of core's 614.2s total (83%); the remaining 74 core suites average
~1.4s each.

### Existing patterns worth reusing

`test-orchestrate-cycle-plan.sh` already demonstrates the in-process/stubbing direction the
dispatch asked to evaluate, but applied to `verify-deploy.sh` rather than `state-write.sh`: it
writes a small, fast, call-counting stub script into the fixture's `.claude/scripts/` in place of
the real (heavy) `verify-deploy.sh`, and asserts on stub-call counts (e.g. "verify-deploy.sh
called exactly once"). This is precedent for doing something similar for
`test-verify-deploy-context-budget.sh`'s Gate-20-only cases, IF a gate-selection flag is not
pursued — though a real gate-selection flag is strictly better since it exercises real Gate 20
logic against a real fixture rather than a hand-maintained stub.

`state-write.sh` (498 lines) has **no internal function boundary** between its CLI/argument
parsing, mutex acquire/release, and the core jq-transform/validate/mv sequence — everything past
argument parsing is inline in the script body (only `check_spill_name_unique`, `usage`,
`acquire_mutex`, `release_mutex`, and `cleanup` are factored into named functions). Extracting a
`state_write_apply()`-shaped function that a test could `source` and call directly (bypassing
mutex + CLI parsing for callers that only need the transform) is feasible but is a refactor of
production code, not a test-only change — and per the dispatch's own caution, doing so changes
what is under test; at least one CLI-level e2e invocation of `state-write.sh` must remain per
call site currently exercised end-to-end.

### Shared mutable state / parallelism safety

Only 3 files reference the lock directory names the dispatch flagged as serialization risks
(`specs/.scope-lock`, `specs/.deploy-lock`, `specs/.commit-lock`): `test-init-specs.sh`,
`test-runtime-file-tracking.sh`, `test-orchestrate-unwind-dispatch.sh`. In all three, these paths
are created and manipulated **only inside an isolated `mktemp -d` fixture repo**
(`build_fixture_repo`, `$WORKDIR/repro-repo`), never the real `specs/` tree. 70 of the 72 core
`scripts/tests/*.sh` files use `mktemp -d` for their own isolated working directory. This is
strong evidence that **file-level parallelism is safe with respect to these specific lock names**
— no cross-file serialization hazard was found from them. (A full audit of every fixed temp path
across all 81 core suites was not performed; this finding covers the three files the dispatch
specifically named as a starting point, not an exhaustive scan.)

`test-lake-build-guard.sh` (1330 lines, 7.22s in this run) is the file
`deploy-baseline-lib.sh:77-83` names as "known load-sensitive." Reading its own header clarifies
the mechanism: it is not sensitive to *other tests running concurrently* per se — its own Case 22
uses a synthetic, path-overridden meminfo fixture (`LAKE_BUILD_GUARD_MEMINFO_PATH`) rather than
reading real ambient memory pressure. The load-sensitivity `deploy-baseline-lib.sh` documents is
specific to the **production redeploy-checkpoint context** (a full deploy + the entire shell test
suite immediately before a findings snapshot, self-inflicting enough memory pressure to flake a
*different* invocation path). Running this suite's own fixture-based cases in parallel with many
other test files would still increase ambient CPU/memory load on the host, which is the generic
risk the dispatch asked to flag — worth explicit verification (3+ repeated parallel runs) in the
implementation phase, but the mechanism is host-level resource contention, not a design flaw
specific to this one file.

### Baseline flakiness (pre-existing, unrelated to this task)

`test-gate-out-repair-reporting.sh` **failed** in the second full-suite run (one of the 5 FAIL
suites) but was not among the first run's 4 FAIL suites. An immediate standalone re-run passed
cleanly (19 passed, 0 failed). No code changed between these three executions. This is a
pre-existing, intermittent flake, independent of anything in this task's scope. It must be
recorded now so a future implementation's "identical pass/fail across all 95 files" verification
step is not confused by it — the honest baseline is "4 consistently-failing suites plus at least 1
known-intermittent suite," not a clean deterministic 91/4 or 90/5 split.

The 4 consistently-failing suites (both runs) are unrelated to this task and pre-exist it:
- `test-handoff-dispatch-identity.sh`, `test-orchestrate-context-growth.sh`: both fail with
  `ERROR: orchestrate-cycle-postflight.sh: shared library return-meta-status-vocabulary.sh not
  found` inside their own fixture — a fixture/deploy-path wiring defect unrelated to test speed.
- `test-lint-json-channel-discipline.sh`: fails on a **real, currently-present** JSON-channel
  violation in `agent-system/extensions/typst/scripts/chapter-quality-check.sh` (unrelated repo
  content, not a test-harness issue).
- `test-orchestrate-recover-message-findings.sh`: 2 of 23 assertions fail on an end-to-end
  acceptance case (`report_missing=true` / `detected_defects` count), unrelated to test speed.

None of these are in this task's scope to fix; they are named here only so the plan/implementation
phases don't misread them as newly introduced by a performance change.

### Recommendations

1. **Highest priority: add a gate-selection mechanism to `verify-deploy.sh`** (e.g. `--only-gate
   N` or `--gates N[,N,...]`), so `test-verify-deploy-context-budget.sh`'s four full-battery calls
   can run Gate 20 alone. This is a change to production code (`verify-deploy.sh`), not test-only,
   so it needs its own design: it must not remove or weaken the full multi-gate contract that
   other suites (e.g. `test-deploy-verify-wiring.sh`) already exercise end-to-end; keep at least
   one real, full-battery invocation somewhere in the suite so the "all gates actually run
   together" contract stays covered. Expected impact: up to ~290s off the ~650s baseline (~45%)
   from this one file alone.
2. **File-level parallelism** across the suite (the grain the dispatch already favored). Confirmed
   safe with respect to the three named lock directories. Schedule the long tail
   (`test-verify-deploy-context-budget.sh` and the other 6 heavy files) first/eagerly in whatever
   scheduler is built, since a naive round-robin or alphabetical dispatch would leave these as
   stragglers holding up the whole parallel run's makespan. Verify `test-lake-build-guard.sh`
   specifically across 3+ repeated parallel runs per the dispatch's flakiness-surfacing
   requirement.
3. **Targeted in-process extraction**, scoped to files with real, repeated, heavy subprocess work
   after (1) and (2) land: `test-orchestrate-cycle-plan.sh` (32 real self-invocations) and
   `test-orchestrate-cycle-postflight.sh` (10 real self-invocations + `state-write.sh` calls) are
   the remaining candidates. `test-orchestrate-cycle-plan.sh`'s existing `verify-deploy.sh`-stub
   pattern is worth reading as a template before inventing a new one.
4. **Lowest priority, evaluate only if still needed after 1-3**: fixture-reuse (the measurements
   show state.json re-parsing and library re-sourcing are both cheap — a few ms each — so
   fixture-reuse's expected payoff is small relative to 1-3) and splitting
   `test-orchestrate-cycle-plan.sh` (helps parallel scheduling only if it remains a straggler
   after (1) and (2); at 44.7s it is a distant second to the dominant file, not obviously worth
   the churn on its own).

## Decisions

- The baseline used for all "before/after" comparisons in the eventual plan/implementation should
  be **the full 95-suite `run-all.sh` run (~650s / ~10m)**, not a core-only subset, since
  `run-all.sh` is the actual gate-8 entry point and the actual command a developer runs. Core-only
  breakdowns in this report are diagnostic, not the comparison baseline.
- `test-verify-deploy-context-budget.sh` is promoted to the primary target for the plan phase,
  ahead of every direction named in the dispatch, on the strength of the 60%-of-total-time
  measurement. The dispatch's four "directions to evaluate" remain valid secondary/tertiary
  directions but should not be pursued first.
- The pre-existing flake (`test-gate-out-repair-reporting.sh`) and the 4 pre-existing failures are
  explicitly out of scope for this task's fix, but must be carried into the plan's verification
  section so they are not misattributed.

## Risks & Mitigations

- **Risk**: A `verify-deploy.sh` gate-selection flag could accidentally let a real caller (not
  just this test) skip gates it shouldn't. **Mitigation**: default behavior (no flag) must stay
  "run everything except slow-gated items," identical to today; the new flag must be strictly
  opt-in and additive.
- **Risk**: Task 262 ("reduce redundant verify-deploy passes," lower-priority-than but independent
  of this task) touches `orchestrate-cycle-plan.sh`, `deploy-baseline-lib.sh`,
  `deploy-ledger-lib.sh`, `batch-orchestration-guardrails.md`, and
  `test-orchestrate-cycle-plan.sh` — a different redundancy (how many times *production*
  orchestration code calls `verify-deploy.sh` per cycle) from this task's finding (how expensive
  *each* `verify-deploy.sh` call is when a test exercises all gates to test one). The two are
  adjacent but non-overlapping: this task's recommended gate-selection flag lives in
  `verify-deploy.sh` itself, outside task 262's declared file_scope. No file-scope conflict, but
  the plan phase should be aware both tasks touch the verify-deploy/orchestrate-cycle-plan
  neighborhood and check task 262's current state before dispatch.
- **Risk**: Parallelizing increases ambient load, which `deploy-baseline-lib.sh` documents as
  capable of flaking `test-lake-build-guard.sh` in the production redeploy-checkpoint context.
  **Mitigation**: the dispatch's own verification requirement (run 3+ times after change, watch
  the load-sensitive set) is the right check; no evidence here suggests avoiding parallelism
  entirely, only that it must be verified empirically post-change.
- **Risk**: A future implementer might read "95 passed of 95" as achievable and treat any
  deviation as a regression. **Mitigation**: this report's flakiness/pre-existing-failure findings
  above should be copied into the plan's verification section as the true baseline expectation
  (91/4 or 90/5, with `test-gate-out-repair-reporting.sh` known-intermittent).

## Context Extension Recommendations

- **Topic**: Shell-test-suite performance / `verify-deploy.sh` gate-selection.
- **Gap**: No existing context file documents `verify-deploy.sh`'s gate list, its `--skip-slow`
  semantics beyond gate 8, or a per-gate cost profile. `context/patterns/bounded-build-waiter.md`
  and `context/standards/shell-script-testing.md` are the closest existing references but neither
  covers gate-selection or suite-wide timing.
- **Recommendation**: once the plan/implementation phases land a gate-selection mechanism, add a
  short section to whatever context file documents `verify-deploy.sh`'s CLI surface (or create
  one under `context/patterns/` if none exists) naming the new flag and its intended use
  (test-only fast paths vs. the full default battery).

## Appendix

### Commands run

```
bash agent-system/extensions/core/scripts/tests/run-all.sh --quiet   # timed with `time`, run 1
# custom per-suite instrumented variant of run-all.sh's own discovery loop, run 2 (see below)
```

Instrumented per-suite timer (mirrors `run-all.sh`'s exact discovery logic, adds a `date +%s%N`
wall-clock measurement around each `bash "$suite"` invocation): iterates every extension under
`agent-system/extensions/*/`, discovering `scripts/tests/test-*.sh` and flat `scripts/test-*.sh`
per extension, identical to `run-all.sh`'s own source-store-mode discovery.

### Full per-suite timing data (run 2, core suites only, sorted by cost)

Top offenders already tabulated above under "Other real, non-trivial offenders." Full CSV data
(95 rows: extension, suite path, wall_ms, PASS/FAIL) was captured to a scratch file during this
research session and is not preserved as a task artifact; the tables in this report reproduce
every figure referenced above and are sufficient for the plan phase. Re-running the instrumented
timer (trivial to reconstruct: wrap `run-all.sh`'s own discovery loop with `date +%s%N` before/
after each `bash "$suite"` call) will reproduce these numbers for verification.

### References

- `agent-system/extensions/core/scripts/tests/run-all.sh` — suite discovery + runner
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` — dominant
  cost, lines 1-261 read in full
- `agent-system/extensions/core/scripts/tests/test-force-phases.sh` — dispatch's named example,
  measured at 5.39s (0.8% of total)
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — 3839 lines, 44.71s,
  existing `verify-deploy.sh`-stub pattern (lines ~1126-1900)
- `agent-system/extensions/core/scripts/state-write.sh` — 498 lines, no internal function
  boundary between CLI parsing and the core transform sequence
- `agent-system/extensions/core/scripts/verify-deploy.sh` — gate 1-20 structure, no gate-selection
  flag today (only `--quiet`, `--findings`, `--skip-slow`, `--minimal-init`)
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh:60-90` — load-sensitivity
  motivation and `test-lake-build-guard.sh` mechanism
- `agent-system/extensions/core/scripts/tests/test-init-specs.sh`,
  `test-runtime-file-tracking.sh`, `test-orchestrate-unwind-dispatch.sh` — the three files
  referencing `.scope-lock`/`.deploy-lock`/`.commit-lock`, all confirmed fixture-isolated
