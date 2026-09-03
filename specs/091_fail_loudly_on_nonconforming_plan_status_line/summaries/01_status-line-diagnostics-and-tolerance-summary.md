# Implementation Summary: Task #91

- **Task**: 91 - Fail loudly on nonconforming plan status line
- **Status**: [COMPLETED]
- **Started**: 2026-09-03T19:05:39Z
- **Completed**: 2026-09-03T20:56:00Z
- **Effort**: ~3.5 hours (matches plan estimate)
- **Dependencies**: None
- **Artifacts**: plans/01_status-line-diagnostics-and-tolerance.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`update-plan-status.sh` used to fold every non-conforming plan-level `- **Status**:` line into
one byte-identical, undiagnosable failure, and its mutating `sed` could never stamp a plan whose
Status line carried a trailing resume annotation. This task replaced the single generic failure
with three classified, line-numbered, content-quoting diagnostics; made the script accept and
preserve trailing text after the closing `]`; corrected the idempotent no-op path to echo the
plan path (matching the script's own documented stdout contract); documented the accepted shape
in `plan-format.md`; enriched (without changing the fatality of) the preflight warning in
`update-task-status.sh`; added a dedicated 28-case fixture-driven regression suite; and redeployed
to confirm the fix survives regeneration.

## What Changed

- `agent-system/extensions/core/scripts/update-plan-status.sh` — shared line-lookup/extraction
  helpers; three classified pre-idempotency diagnostics (M1 missing prefix, M2 no bracket pair,
  M3 text before the bracket); mutating `sed` now preserves trailing text after `]`; the
  already-at-target no-op and a successful stamp both echo the plan path; verification block and
  header Outputs contract rewritten to match.
- `agent-system/extensions/core/scripts/tests/test-update-plan-status.sh` (new) — 28-assertion
  fixture-driven suite covering M1/M2/M3, trailing-annotation preservation, two-bracket-pairs,
  well-formed transition, already-at-target no-op, unknown-status rejection, and missing
  dir/file, plus a mechanical pairwise-distinctness assertion on the three diagnostics.
- `agent-system/extensions/core/manifest.json` — registered the new test file in
  `provides.scripts` (required for `deploy-headless.sh`/`run-all.sh` to see it at all).
- `agent-system/extensions/core/context/formats/plan-format.md` — documented the
  trailing-annotation tolerance policy under "Plan-level vs. phase-level markers" with an
  accepted and a rejected example, named `update-plan-status.sh` as the enforcing consumer, and
  added a forward pointer from the phase-heading "Consumers of this heading contract" paragraph.
- `agent-system/extensions/core/scripts/update-task-status.sh` — `update_plan_file()`'s
  non-fatal preflight `else` branch got 4 additive stderr lines naming the plan file and warning
  that the same failure hard-fails (`exit 3`) at postflight if left unresolved; the fatal
  postflight branch and its rationale comment are byte-identical.
- `agent-system/extensions/core/index-entries.json` — corrected the `formats/plan-format.md`
  entry's `line_count` (431 -> 453) after the new documentation content was added, so this
  task's own edit did not leave doc-lint drift behind.
- `.claude/**` — regenerated via `deploy-headless.sh` (disposable deploy artifact; not
  hand-edited).

## Decisions

- Trailing-text policy resolved as **accept and preserve** (per the task description's own
  framing and the research report's recommendation), narrowed by the M3 classification so text
  *before* the bracket (e.g. `- **Status**: see [NOTE]`) is still rejected loudly.
- The task description's "three distinct diagnostics" acceptance criterion was reinterpreted
  under the accept policy as covering the shapes that remain malformed (M1/M2/M3), since the
  trailing-annotation shape is by construction a success case under accept, not a diagnostic
  case — recorded explicitly in the plan's "Decisions Adopted" section.
- The plan-creation-time Status-line lint (`ALSO EVALUATE` item) was deferred as an independent
  enhancement, per the research report's recommendation — out of this task's scope.

## Plan Deviations

- **Task 5.6** (`verify-deploy.sh` green): altered. 27/30 gates pass; the 3 remaining failures
  are pre-existing and confirmed unrelated to any of this task's five modified/created files —
  closed via Phase 5's `Reasoned Exclusions` record (`[COMPLETED WITH EXCLUSIONS]`) rather than
  left as unresolved residual work. See the plan's Phase 5 Reasoned Exclusions table for the
  per-finding reason and evidence.

## Verification

- Build: N/A (shell scripts).
- Tests: `test-update-plan-status.sh` 28/28 passed (deployed copy); `run-all.sh` 67/67 passed, 0
  failed, 0 skipped (deployed tree); `test-update-task-status.sh` (29/29, from Phase 4's own
  verification) included in that full run.
- Files verified: Yes — all four Phase 1-4 source-store files are byte-identical to their
  deployed copies (`diff` empty); the acceptance walk (M1/M2/M3 diagnostics, trailing-annotation
  preservation, well-formed transition, already-at-target no-op) was independently re-run live
  against the deployed script in Phase 5, not just inferred from the test suite.
- `verify-deploy.sh`: 27/30 checks pass. The 3 remaining failures are pre-existing and
  unrelated to this task (see Plan Deviations above and the plan's Reasoned Exclusions table).

## Impacts

- Any future plan carrying a resumed Status line with a trailing annotation (e.g.
  `- **Status**: [IMPLEMENTING] (resumed; Phases 1R-10R closed)`) can now be stamped by
  `update-plan-status.sh` instead of permanently failing.
- Operators debugging a malformed plan-level Status line now get a line-numbered, verbatim-quoted
  diagnostic naming exactly which of three conditions failed, both at preflight (as an enriched
  non-fatal warning) and at postflight (as the pre-existing fatal `exit 3` path, whose fatality
  was left untouched).
- `update-plan-status.sh`'s stdout now reliably signals "the plan file is now at the requested
  status" on both a fresh stamp and an already-at-target no-op, matching its documented Outputs
  contract for any future stdout-consuming caller.

## Follow-ups

- None from this task's own scope. Three verify-deploy findings remain open in the wider repo
  but belong to other in-flight tasks (`formats/return-metadata-file.md` and
  `contracts/return-meta-artifacts-template.md` doc-lint line_count drift; four
  `test-force-phases.sh` state-writer-boundary violations); a stale root-level
  `.claude/index-entries.json` orphan file predates this session and was not created by this
  task's redeploy. None require action from this task.

## References

- Plan: `specs/091_fail_loudly_on_nonconforming_plan_status_line/plans/01_status-line-diagnostics-and-tolerance.md`
- Research: `specs/091_fail_loudly_on_nonconforming_plan_status_line/reports/01_diagnostic-opacity-and-anchor-fix.md`
- Progress: `specs/091_fail_loudly_on_nonconforming_plan_status_line/progress/phase-{1,2,3,4,5}-progress.json`
- Handoffs: `specs/091_fail_loudly_on_nonconforming_plan_status_line/handoffs/phase-1-handoff-20260903T190749Z.md`, `specs/091_fail_loudly_on_nonconforming_plan_status_line/handoffs/phase-4-handoff-20260903T193212Z.md`
