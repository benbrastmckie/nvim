# Phase 1 Measured Baseline: Deferred

## Decision

Phase 1's plan tasks require a confirmed-idle host before taking the control measurement with
`measure-gate-costs.sh`. At dispatch time (2026-11-18, dispatch_seq 20):

- `nproc`: 24
- `/proc/loadavg` (1-minute): 3.42 (5-minute 2.98, 15-minute 3.36)
- `measure-gate-costs.sh`'s own `MEASURE_GATE_COSTS_LOAD_THRESHOLD` default: 2.0

3.42 >= 2.0, so the idle-branch gate fails on load alone.

Independently, this session's own teammate roster (visible via `ListAgents`/the session's own
peer list at dispatch time) carried at least three other live peers: `main`, `impl-607`
(a concurrent implement dispatch for a different task), and `plan-610`/`res-610` (earlier-phase
dispatches for this same task's own lifecycle, left registered). `impl-607` in particular is
another implementation dispatch plausibly exercising the same gate machinery concurrently.

Both independent signals (measured load, live sibling sessions) agree: the host is not idle.
Per Phase 1's own decision gate, the **deferred branch** is taken. No measurement is recorded as
a control under this condition — a contaminated figure presented as a control would be worse
than no figure, since a future reader could not tell it apart from a real idle baseline.

## What Was Not Measured

- Gate 8 (`tests/run-all.sh`) idle wall-clock via `measure-gate-costs.sh`.
- A second, representative-concurrent-load measurement (moot without a control to compare it
  against).

## Gate-Lock Posture Ruling (not measurement-dependent)

This task's Decision 6 and research Q3 ruling — `.gate-lock` keeps its fail-open posture, no
change to `GATE_MUTEX_ACQUIRE_BUDGET_MS`/`GATE_MUTEX_STALE_SEC` — does not depend on the
deferred measurement and is recorded durably in
`context/standards/shell-script-testing.md`'s "Measured Before/After" section regardless of
this deferral.

## Follow-Up

A future idle-host window (no loadavg >= 2.0, no concurrent sibling dispatch) should re-run
`bash agent-system/extensions/core/scripts/measure-gate-costs.sh` and add both the idle and the
loaded rows to `context/standards/shell-script-testing.md`'s table, each carrying its own
`nproc`/loadavg per the existing convention. Phase 2's own `test-gate-slow-bucket-split.sh`
timed-run assertion is the mechanism-correctness check that does not require this deferred
control measurement — it only needs the split gate's own wall-clock to be under its bound,
measured whenever that phase's own verification runs.
