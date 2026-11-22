# Implementation Summary: Task #668

- **Task**: 668 - Measure Claude Code harness behaviour for a worktree outside the project directory
- **Status**: [COMPLETED]
- **Started**: 2026-11-22
- **Completed**: 2026-11-22
- **Effort**: ~0.3 hours (closure only; the four measurements were already taken during the
  research dispatch)
- **Dependencies**: 667
- **Artifacts**: plans/01_external-worktree-harness-measurement.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

This task's four harness measurements were already taken live during the research dispatch, and
the measurement record (`specs/decisions/external-worktree-harness-behaviour.md`) already existed
with a verdict that none of the four results refutes the amending record's R2 siting. This
implementation closed, rather than re-measured: it discharged the amending record's "Measured
precondition" with a dated note, closed the measurement record against its own stated criterion
(an exact-call appendix, explicit agent-measured/user-supplied attribution, and a named
"Residuals" section), and committed both decision records.

## What Changed

- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md` — R2's closing sentence
  replaced (no longer states the siting rests on unmeasured behaviour; now cites
  `external-worktree-harness-behaviour.md` and states the precondition was measured and is
  unrefuted); one dated `**Discharged by** external-worktree-harness-behaviour.md, 2026-11-22:`
  note added under "Measured precondition", naming both residuals. The existing conditional
  sentence ("If a measurement refutes the siting...") was kept verbatim; no `**Amended by**`
  marker was added anywhere in the file.
- `specs/decisions/external-worktree-harness-behaviour.md` — extended "Attribution" section
  labelling all four measurements agent-measured (none user-supplied); new "Residuals" section
  naming both residuals (the non-`bypassPermissions` file-tool question; the hook subprocess's
  raw OS `pwd`) with the one-sentence reason the verdict does not turn on either; new "Appendix:
  exact commands and tool calls per measurement" section attributing each of the four
  measurements to its literal command or tool call. "Verdict" and "Provenance" left unchanged.
  This file was untracked before Phase 2's commit and is now tracked.

## Decisions

- Used a distinct `**Discharged by**` marker, never `**Amended by**`, since no measurement
  refuted the siting — an amendment marker would misstate what happened.
- Ran this dispatch's own Batch Gate Deferral directive's no-argument `verify-touched.sh` form
  (derives touched paths from the whole working tree plus committed diff) rather than the plan's
  hand-assembled two-path invocation, since the dispatch file is authoritative over the plan's
  literal text for the verification tier.

## Plan Deviations

- **Task 1.verification**: `grep -c "Discharged by"` returns 2, not the plan's expected 1,
  because the file already carried one pre-existing, unrelated plain-text occurrence of the
  phrase in a coverage table unconnected to the marker convention. Verified instead via `git diff`
  that exactly one new `**Discharged by**` marker was added and no `**Amended by**` marker was
  added.
- **Task 3.5**: ran `verify-touched.sh` with no arguments (per the dispatch's Batch Gate Deferral
  section) instead of the plan's two-path invocation; result: 98 passed, 0 failed, 36 suites
  selected, 5 owed, 0 no-suite-by-class, across 16 touched paths, run as a bounded background
  wait (twice auto-backgrounded past the harness's 180s foreground-display threshold; resolved
  both times with a `kill -0` wait on the real OS PID, never a retry).

## Verification

- Build: N/A (prose-only decision records; no build)
- Tests: `verify-touched.sh` (no args) — 98 passed, 0 failed
- Files verified: Yes — both decision records read in full after editing; grep checks for
  `has not been measured` (absent), `Amended by` (only pre-existing, unrelated occurrences),
  and repo-agnostic leakage (`/home/|nvim|dotfiles` — none found) all passed.

## Impacts

- Every two-root successor task (669–675) can now read the amending record's R2 and "Measured
  precondition" sections without being told the siting rests on unmeasured behaviour; the
  discharge note points them at the measurement record directly.
- The measurement record is now a complete, self-contained, committed reference: each result is
  attributed to its exact producing command or tool call, and the two residuals are named in one
  place with the reason neither changes the verdict.

## Follow-ups

- The one open question (whether `/orchestrate` or any agent dispatch ever runs from a session
  not started with `--dangerously-skip-permissions`, and if so what a dispatched subagent's
  file-tool calls do for an external path under that mode) is still unanswered as of this
  dispatch. It is re-relayed as a non-blocking `user_decision` in `.return-meta.json` rather than
  guessed; no successor needs to change its approach while it stays open, since every measured
  dispatch ran under `bypassPermissions`.
- The hooks successor (671) still owns folding measurement 3 (hook cwd/payload mechanics) into a
  two-root hook context file, and fixing `guard-destructive-git.sh`'s primary-tree anchoring in
  both directions — neither was in this task's scope.

## References

- `specs/668_measure_harness_behaviour_for_external_worktree/plans/01_external-worktree-harness-measurement.md`
- `specs/668_measure_harness_behaviour_for_external_worktree/reports/01_external-worktree-harness-measurement.md`
- `specs/decisions/external-worktree-harness-behaviour.md`
- `specs/decisions/batch-worktree-isolation-and-task-squash-landing.md`
