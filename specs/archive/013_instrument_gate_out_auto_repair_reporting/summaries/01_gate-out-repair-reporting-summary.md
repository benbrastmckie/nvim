# Implementation Summary: Instrument gate-out auto-repair reporting

- **Task**: 13 - Instrument gate-out auto-repair reporting; stop silent in-place artifact mutation
- **Status**: [COMPLETED]
- **Started**: 2026-09-03T17:44:00Z
- **Completed**: 2026-09-03T18:22:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_gate-out-repair-reporting.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`skill_validate_task_artifacts` (`skill-base.sh`) used to inspect only `validate-artifact.sh`'s
exit code and discard its stdout, so `command-gate-out.sh` had no numeric signal when `--fix`
silently rewrote an artifact in place. All six plan phases are complete: the function now
aggregates fix/error/warning counts into four caller-visible globals, `command-gate-out.sh`
reports them unconditionally (repaired and clean alike) plus a durable `specs/events.jsonl` row,
a new 19-assertion regression suite proves both acceptance directions and several edge cases, the
change is deployed and demonstrated live, and the reasoning is recorded durably in both the code
and `skill-lifecycle.md`.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — rewrote `skill_validate_task_artifacts`
  to reset and aggregate `SKILL_VALIDATE_FIXES`/`SKILL_VALIDATE_ERRORS`/`SKILL_VALIDATE_WARNINGS`/
  `SKILL_VALIDATE_FIXED_FILES` across the sweep, parsing `validate-artifact.sh`'s terminal summary
  line under exit-code discrimination (0/1/2 explicit, 3/4/5 and any unparseable shape default to
  one explicit error — never a silent zero). Added a durable comment block recording decisions
  D-A and D-B.
- `agent-system/extensions/core/scripts/command-gate-out.sh` — added an always-on
  `[gate-out] Artifact validation for task N: F field(s) auto-repaired, E error(s), W warning(s)
  remaining.` report line, a repaired-files line when nonzero, and an `artifact_auto_repair`
  `specs/events.jsonl` row via `_events_append_observable` (category `deviation` when fixes or
  errors are nonzero, `milestone` otherwise).
- `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` — new
  fixture-driven regression suite (19 assertions, 8 cases): repaired direction, clean direction
  (report line present and reads zero — not omitted), multi-file aggregation, errors-remaining-
  alongside-fixes, validation-could-not-run (exit 5, no silent zero), no-stale-globals-across-
  calls, summary-line format pinning (all three shapes), and the events.jsonl row.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — residuals footer
  corrected: `skill_validate_task_artifacts` is no longer listed as uncovered; points at the new
  suite.
- `agent-system/extensions/core/context/patterns/skill-lifecycle.md` — Stage 6a row updated to
  name the four globals; new "In-Place `--fix` Mutation on the Gate-Out Path (D-A)" subsection
  records the decision durably, plus a note on the sibling gap in `skill_validate_artifact`
  (singular).
- `agent-system/extensions/core/manifest.json` — registered the new test script in
  `provides.scripts` (required for `verify-deploy.sh` gate3 to pass post-deploy).
- `agent-system/extensions/core/index-entries.json` — corrected `skill-lifecycle.md`'s declared
  `line_count` (required for gate3).

## Decisions

- **D-A**: `--fix` remains in-place-mutating on the gate-out path. The mutation is narrow and
  self-flagging (a literal `- **Field**: TBD` placeholder for a missing metadata field only,
  never touching required sections or existing prose); every artifact under `specs/` is
  git-tracked so the mutation's content was always auditable, and what was missing was only the
  record that a repair happened at all — which this task supplies. Disabling `--fix` would
  convert a trivial omission into a hard stop with no offsetting benefit. Residual risk (exit 2
  conflates "fixed and clean" with "fixed but a required section is still missing") is mitigated
  by surfacing the errors-remaining count alongside the fix count.
- **D-B**: parse `validate-artifact.sh`'s existing summary line rather than modify that script.
  Keeps the change inside the two files the task names; the regression suite pins all three
  summary-line shapes verbatim so a future wording drift fails loudly instead of silently
  degrading counts to zero.
- **D-C**: the report is both console (always-on line) and durable (one `events.jsonl` row per
  gate-out run), since a stdout line alone is ephemeral in automated (non-interactive) runs.
- Extended D-B's "never silently zero" principle beyond the exit-3/4/5 default branch the plan
  named explicitly: the exit-0/1/2 branches now also fall back to `file_errors=1` when the
  summary line does not match the expected counted shape (discovered while writing the exit-5
  regression case — `validate-artifact.sh` also exits 1 for an uncounted "File is empty" message
  that the counted-shape regex does not match).

## Plan Deviations

- None (implementation followed plan). The manifest.json/index-entries.json registrations in
  Phase 5 and the exit-0/1/2 fallback hardening in Phase 1/4 are in-scope refinements explicitly
  reasoned about in the phase 5 and phase 4 handoffs, not skips or alterations of any planned
  item.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on both changed scripts)
- Tests: Passed — new suite 19/19; full `run-all.sh` 65/65 (up from 64 pre-task); reverting
  Phase 1's parsing in a scratch copy made 9/19 new cases fail (non-vacuous)
- Files verified: Yes — deployed copies byte-match source-store originals for all four
  changed/new files; `verify-deploy.sh --findings` introduces zero new findings post-deploy

## Impacts

- Any `--fix` auto-repair on the `command-gate-out.sh` path is now always reported, both to the
  console and durably in `specs/events.jsonl` — the silent-mutation hazard named in the task is
  closed.
- `skill_validate_task_artifacts` gains its first dedicated regression coverage, closing a
  zero-coverage gap flagged in `test-skill-base-lifecycle.sh`'s own residuals footer.
- The identical discard pattern in `skill_validate_artifact` (singular, off this task's path) is
  now a durably recorded, actionable follow-up rather than a pattern someone would have to
  rediscover from scratch.

## Follow-ups

- `skill_validate_artifact` (singular) can adopt this task's exit-code-discriminated-parsing
  approach directly — recorded in `skill-lifecycle.md`'s sibling-gap note, not implemented here
  (outside this task's `file_scope`).

## References

- Plan: specs/013_instrument_gate_out_auto_repair_reporting/plans/01_gate-out-repair-reporting.md
- Research: specs/013_instrument_gate_out_auto_repair_reporting/reports/01_gate-out-repair-reporting.md
- Phase handoffs: specs/013_instrument_gate_out_auto_repair_reporting/handoffs/
