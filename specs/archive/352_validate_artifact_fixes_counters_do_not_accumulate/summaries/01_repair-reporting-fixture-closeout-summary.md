# Implementation Summary: Task #352

- **Task**: 352 - validate-artifact.sh fixes counters do not accumulate
- **Status**: [COMPLETED]
- **Started**: 2026-10-08T02:37:57Z
- **Completed**: 2026-10-08T04:00:00Z
- **Effort**: ~1.5 hours
- **Dependencies**: None (the group's dependency edge is a territory serialization on
  `known-failures.txt`, not a work dependency)
- **Artifacts**: plans/01_repair-reporting-fixture-closeout.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-strict-mode.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Re-confirmed from live evidence that `SKILL_VALIDATE_FIXES`/`SKILL_VALIDATE_FIXED_FILES` already
accumulate correctly across a multi-file sweep and already reset unconditionally at function
entry — no production defect exists in `skill-base.sh`, `command-gate-out.sh`, or
`validate-artifact.sh`. The dispatch's literal framing (and the `known-failures.txt` row it was
seeded from) was stale: the row described a symptom already fixed before it was seeded, while
the suite's one live failure (Case 1) traced to an unrelated fixture choice tripping a later,
by-design Status-line grammar check. Repaired that fixture, added the two acceptance-mandated
pinning fixtures (genuine cross-subdirectory accumulation; repairing-then-repairing cross-call
reset), proved both pins fail against a one-directional partial fix, deleted the task's owned
`known-failures.txt` row, recorded the registry-triage discipline as process guidance, and
redeployed.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-gate-out-repair-reporting.sh` — swapped
  `write_repairable_plan`'s omitted field from `**Status**` to `**Effort**` (removing a spurious
  second error from the plan-level Status-line grammar check); refreshed that helper's header
  comment and added a cross-reference comment at `write_repair_plus_errors_plan`; added a new
  `write_repairable_report` helper; strengthened Case 3 to a genuine 3-file/2-subdirectory
  accumulation case (two plans + one report) and corrected its stale "two subdirectories"
  comment; added Case 6b, pinning the repairing-then-repairing cross-call reset shape Case 6 does
  not cover. Suite grew from 18/19 passing to 21/21 passing.
- `agent-system/extensions/core/scripts/tests/known-failures.txt` — deleted the single owned
  `test-gate-out-repair-reporting.sh|real-defect|...|needs-owner` row (ON FIX branch: the suite
  is green, so the exception is removed outright rather than reassigned).
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — added a
  "Re-validate a row's claimed symptom against live output before scoping work from it"
  subsection, with a worked example anchored to commit SHAs/dates (never task numbers), recording
  the generalisable lesson this task is an instance of.
- Regenerated the deployed `.claude/**` tree via `deploy-headless.sh`; the deployed copies of all
  three edited files are byte-identical to their source-store originals.

## Decisions

- **Deletion, not formal acceptance, for the registry row.** The suite is now genuinely green via
  a real fixture repair, not a tolerated gap, so the row is removed per the registry's own
  "a fixed suite must not keep a known-failing exception" rule.
- **Globals retained, not converted to return values.** Bash function returns are exit codes
  only; four pieces of structured state cannot ride them, and every sibling caller-visible
  channel in `skill-base.sh` (e.g. `SKILL_HOOK_LAST_*`) already uses the same global-plus-
  entry-reset pattern.
- **Partial-fix resistance probe, direction two, used an only-if-unset init rather than literal
  line deletion.** A literal deletion of the four entry-reset lines crashes the whole suite via
  `set -u`'s "unbound variable" at the first direct-function-call case (Case 3), before the new
  cross-call case (6b) is ever reached. An only-if-unset init (`: "${VAR:=0}"`) — the literal
  shape of the dispatch's fault #2 (stale state surviving across calls) — avoids the crash and
  does fail Case 6b exactly as intended.

## Plan Deviations

- **Task 3.7** (partial-fix resistance probe, direction two) altered: implemented via
  only-if-unset init rather than literal line deletion, for the reason recorded above and in
  `progress/phase-3-progress.json`'s `deviations` array. Same fault direction verified; Case 6b
  confirmed to fail.

## Verification

- Build: N/A (shell scripts; shellcheck used instead — see below)
- Tests: Passed. `test-gate-out-repair-reporting.sh` reports 21 passed, 0 failed, both from the
  source-store copy and from the deployed `.claude/scripts/` copy. Confirmed also green under
  the full `tests/run-all.sh` harness (run via `--jobs auto` under a bounded foreground waiter,
  since the full harness exceeds the default per-call timeout).
- Files verified: Yes (byte-identical diff of deployed vs. source-store copies for all three
  edited files).
- Shellcheck: clean — one pre-existing SC2329 info-level finding on `cleanup()`, confirmed
  present verbatim in the file's original commit (`acb984656`), predating this task's edits.
  Zero new findings.
- Task-reference lint: 0 occurrences under `agent-system/**`.

## Impacts

- Gate-out repair reporting (`SKILL_VALIDATE_FIXES`/`SKILL_VALIDATE_FIXED_FILES`, consumed by
  `command-gate-out.sh`'s console report and `events.jsonl` row) is now pinned against both
  failure directions named in the dispatch: under-reporting within a multi-file sweep, and
  over-reporting via stale cross-call state. Both directions were already correctly implemented
  in production code; the new fixtures exist so a future regression in either direction is
  caught immediately rather than resurfacing as a silent audit-trail corruption.
- The registry-triage discipline subsection gives future task authors a concrete, anchored
  example of why a `known-failures.txt` row's claimed symptom must be re-validated against live
  output before being accepted as a task's scope.

## Follow-ups

- Observed, not fixed (out of this task's `file_scope`): `deploy-headless.sh`'s verify-deploy
  fast-gate run reported 3 pre-existing orphan-detection findings —
  `.claude/scripts/roadmap-integration.sh`,
  `.claude/scripts/tests/test-roadmap-argv-ceiling.sh`, and
  `.claude/scripts/tests/test-roadmap-items-producer.sh` — stale deployed copies (mtime
  predating this dispatch) of files the source store already moved to `scripts/deprecated/`.
  Recorded via `issue-record.sh` (class `foreign-defect-observed`, severity minor) rather than
  fixed, since it is unrelated to this task's subject and not in scope.
- `tests/run-all.sh`'s own full-harness run (unrelated to this task) separately showed 2 NEW,
  unowned failures (`test-verify-deploy-context-budget.sh`,
  `test-four-tier-conflict.sh`) alongside 2 pre-existing EXPECTED ones. Neither is owned by this
  task and neither was touched.

## References

- Plan: `specs/352_validate_artifact_fixes_counters_do_not_accumulate/plans/01_repair-reporting-fixture-closeout.md`
- Research: `specs/352_validate_artifact_fixes_counters_do_not_accumulate/reports/01_known-failures-row-misdiagnosis.md`
- Progress files: `specs/352_validate_artifact_fixes_counters_do_not_accumulate/progress/phase-{1..6}-progress.json`
