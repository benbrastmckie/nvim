# Implementation Summary: Task #169

- **Task**: 169 - Add a positive-direction memory-pressure case to test-lake-build-guard.sh
- **Status**: [COMPLETED]
- **Started**: 2026-09-07T00:00:00Z
- **Completed**: 2026-09-07T00:50:00Z
- **Effort**: ~1 hour
- **Dependencies**: None (builds on already-landed commit `878043472`)
- **Artifacts**: plans/01_pressure-detection-case.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Commit `878043472` isolated `test-lake-build-guard.sh` from ambient host memory state by
exporting `LAKE_BUILD_GUARD_PSI_PATH`/`LAKE_BUILD_GUARD_MEMINFO_PATH` suite-wide to clean fixture
files. That left a regression-masking gap: no case asserted that pressure detection actually
fires, so a regression disabling `check_memory_pressure()` entirely would leave every case green.
This task added case 22 (positive direction), Mutation F (scripted non-vacuousness proof), and an
ambient-pressure robustness check, plus reconciled the suite's header comments. Only
`agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` was modified;
`lake-build-guard.sh` is byte-identical to its pre-task state.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh` — Added case 22 (writes a
  pressured meminfo fixture derived from the guard's own `MEM_AVAILABLE_RATIO_THRESHOLD`/
  `SWAP_USED_RATIO_THRESHOLD` constants read at run time, overrides
  `LAKE_BUILD_GUARD_MEMINFO_PATH` on a single invocation per case 11's local-override idiom,
  asserts `preflight` exits 11 with both the MemAvailable and swap-in-use reasons on stderr).
  Added Mutation F (function-shadows `check_memory_pressure()` to always report no pressure,
  reusing case 22's pressured fixture, asserting the opposite outcome). Updated the top-of-file
  case-count comment and the ambient-host-isolation comment block's now-stale closing statement.

## Decisions

- Derived pressured fixture values from the guard's own threshold constants
  (`MEM_AVAILABLE_RATIO_THRESHOLD=10`, `SWAP_USED_RATIO_THRESHOLD=50`, both read via `grep -oE
  '^NAME=[0-9]+'` at run time) rather than hardcoding numbers, so the case survives a deliberate
  threshold retune. Target ratios (5% availability, 75% swap-used) use `MemTotal`/`SwapTotal =
  32000000` (a multiple of 100), landing on exact integer division results well clear of either
  boundary.
- Left `LAKE_BUILD_GUARD_PSI_PATH` at the suite-wide clean fixture for case 22, since only the
  meminfo pair is needed to reproduce the dispatch's reference behavior (rc=11 with both
  meminfo-derived reasons, no PSI reason) — matches the plan's explicit non-goal of adding
  PSI-derived assertions.
- Mutation F reuses case 22's exact fixture rather than building a new one, keeping the
  before/after comparison a true minimal pair (same fixture, only `check_memory_pressure()`
  itself is neutered).

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: Passed (29/29, up from the 27/27 baseline)
- Files verified: Yes

### Ground truth read from `lake-build-guard.sh` (Phase 1)

- `check_memory_pressure()`: `MEM_AVAILABLE_RATIO_THRESHOLD=10`, `SWAP_USED_RATIO_THRESHOLD=50`
  (both anchored `^NAME=` assignments); meminfo keys read: `MemTotal`, `MemAvailable`,
  `SwapTotal`, `SwapFree`; reason templates:
  `MemAvailable/MemTotal = ${avail_ratio}% is below threshold ${MEM_AVAILABLE_RATIO_THRESHOLD}%`
  and `swap-in-use = ${swap_used_ratio}% of SwapTotal exceeds threshold ${SWAP_USED_RATIO_THRESHOLD}%`.
- `cmd_preflight()`: exits `11` on pressure, printing `lake-build-guard: memory pressure detected:`
  to stderr followed by one `  - {reason}` line per triggered reason.

### Pass-count progression

| Stage | Passed | Failed |
|-------|--------|--------|
| Baseline (Phase 1, before any edit) | 27 | 0 |
| After case 22 (Phase 2) | 28 | 0 |
| After Mutation F (Phase 3) | 29 | 0 |
| Final (Phase 5) | 29 | 0 |

29 = 23 case-level `[PASS]` lines (22 numbered cases, with case 12 emitting two passes, 12a/12b)
+ 6 mutation checks (A-F).

### Non-vacuousness demonstration (Phase 3)

Backed up `lake-build-guard.sh`, applied Mutation F's exact `sed` pattern to the real file in
place (`check_memory_pressure() { PRESSURE_REASONS=(); return 1; } ; _disabled_check_memory_pressure() {`),
ran the FULL suite against the neutered guard, then restored the original file and confirmed the
restore was byte-identical (`diff` empty) and `git diff --stat` showed the guard untouched.
Result — exactly one failure, and it is case 22:

```
[FAIL] case 22: expected preflight exit 11 with both the MemAvailable and swap-in-use reasons; got rc=0 err=[]

Passed: 28
Failed: 1
```

No other case regressed under the neutered guard, confirming case 22 is the only case that
depends on `check_memory_pressure()` actually detecting pressure.

### Ambient-pressure robustness (Phase 4)

Ran the suite twice: once normally, once with `LAKE_BUILD_GUARD_MEMINFO_PATH` and
`LAKE_BUILD_GUARD_PSI_PATH` pre-set in the invoking environment to a pressured pair (avail_ratio
5%, swap_used_ratio 75%, PSI `some avg10=25.00`/`full avg10=15.00`, both over threshold) written
to the session scratchpad (never the repo). Both runs reported identical `Passed: 29 / Failed: 0`
— the suite's own suite-wide `export`s (lines 104-105) unconditionally override the inherited
ambient environment, confirming the isolation from commit `878043472` survives this addition.

## Impacts

- Closes the regression-masking gap: a future change that disables `check_memory_pressure()`
  will now be caught by case 22 going red, rather than passing silently.
- No behavioral change to `lake-build-guard.sh` itself — this is a test-only addition.

## Follow-ups

- None

## References

- Plan: `specs/169_lake_guard_pressure_detection_case/plans/01_pressure-detection-case.md`
- Modified: `agent-system/extensions/core/scripts/tests/test-lake-build-guard.sh`
- Reference (unmodified): `agent-system/extensions/core/scripts/lake-build-guard.sh`
