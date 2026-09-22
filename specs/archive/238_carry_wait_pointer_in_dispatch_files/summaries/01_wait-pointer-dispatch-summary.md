# Implementation Summary: Task #238

- **Task**: 238 - Carry an external-process wait-discipline pointer in every orchestrate dispatch file
- **Status**: [COMPLETED]
- **Started**: 2026-09-18
- **Completed**: 2026-09-18
- **Effort**: ~1 hour
- **Dependencies**: 236 (authored `context/patterns/external-process-wait.md`; complete)
- **Artifacts**: plans/01_wait-pointer-dispatch-plan.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, shell-strict-mode.md

## Overview

`agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` now unconditionally emits a
`## Wait Discipline` section — a pointer to `context/patterns/external-process-wait.md` plus a
one-line behavioral summary — into every `/orchestrate` dispatch file it composes, for all three
phases (research, plan, implement) and both base and `--hard` modes. This closes the gap the
motivating incident exposed: a dispatched agent that had to wait on a ~25-minute CI run had no
pointer to the wait-discipline pattern unless it happened to load an agent contract or
`hard_contracts` routing entry that mentioned it. A new test group (Group 14) in
`scripts/tests/test-orchestrate-build-dispatch.sh` asserts the pointer's presence, single
occurrence, and ordering across the full phase x mode matrix.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — added an unconditional
  `echo "## Wait Discipline"` block (pointer + one-line summary) immediately before
  `echo "## User-Decision Contract"` in the script's single `{ ... } > "$dispatch_file"` write
  block, outside every `if`. Added a header comment documenting this as a deliberate, permanent
  exception to the byte-identical-when-inactive invariant, alongside `## User-Decision Contract`.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — added
  `Group 14: wait-discipline pointer present in every dispatch`, with six cases (base and
  `--hard` x research/plan/implement) asserting the pointer's presence, a single-occurrence
  guard on the hard-implement case (guards against a future double-emit via
  `hard_contracts_block`), and an ordering assertion that `## Wait Discipline` precedes
  `## User-Decision Contract`.

## Decisions

- Followed the plan's exact placement and wording; did not route the pointer through
  `routing_lookup_flat "hard_contracts"` (that mechanism is hard-mode-only and task-type-scoped,
  which would have contradicted the "base mode as well as `--hard`" requirement).
- Kept the summary free of numeric constants so it will not drift when
  `context/patterns/external-process-wait.md` is tuned.

## Plan Deviations

- None (implementation followed plan)

## Verification

- Build: N/A
- Tests: Passed — `test-orchestrate-build-dispatch.sh` reports `Passed: 106, Failed: 0`
  (all pre-existing groups, including the exact-diff Groups 9, 10, 12, still pass; new Group 14
  passes; a manual negative control — temporarily reverting the Phase 1 echo lines — made Group 14
  fail with 14 failures, confirming the test actually detects absence, then the file was restored
  to its committed state).
- Files verified: Yes
- shellcheck: clean on both modified files (only pre-existing, unrelated info-level findings:
  SC2153/SC2012 in the script, SC2329 in the test file).
- `check-task-references.sh --quiet agent-system/extensions/core/scripts`: 0 unexempted
  occurrences.

## Impacts

- Every future `/orchestrate` dispatch (research, plan, implement; base or `--hard`) now carries
  the external-process wait-discipline pointer regardless of which agent contract or
  `hard_contracts` routing entry it loads, closing the gap that let a dispatched agent burn ~130
  no-op Bash calls waiting on a long-running CI run.

## Follow-ups

- None

## References

- Plan: specs/238_carry_wait_pointer_in_dispatch_files/plans/01_wait-pointer-dispatch-plan.md
- Research: specs/238_carry_wait_pointer_in_dispatch_files/reports/01_wait-discipline-dispatch-pointer.md
- Pattern referenced: agent-system/extensions/core/context/patterns/external-process-wait.md
