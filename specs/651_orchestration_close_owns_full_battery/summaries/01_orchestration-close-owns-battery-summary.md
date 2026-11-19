# Implementation Summary: Task #651

- **Task**: 651 - Make the orchestration, not the task, the unit that closes on the full gate battery, for every invocation shape including a batch of one
- **Status**: [COMPLETED]
- **Started**: 2026-11-19
- **Completed**: 2026-11-19
- **Effort**: ~8 hours (7 phases)
- **Dependencies**: 610 (COMPLETED), 650 (COMPLETED)
- **Artifacts**: plans/01_orchestration-close-owns-battery.md, reports/01_orchestration-close-owns-battery.md
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Relocated the complete-gate-battery discharge obligation from each task's own final phase to the
orchestration's own once-per-invocation Move 4 close, across every surface still describing the
pre-amendment design, and closed the five gaps left behind by the mechanism's own earlier,
narrower shipment: a red close battery now binds to the tasks it implicates, an interrupted
orchestration leaves a reported open obligation, and a consumer repository's own declared closing
gate is what Move 4 actually runs.

## What Changed

- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` — rewrote the "Single-task
  invariance" paragraph to state the current design only (no version-relative phrasing); added the
  "Red-Close Per-Task Record" and "Open Close Obligations" sections; amended the Evidence Base and
  Executable Stage Body to describe the closing-gate consumption and the close-status-bind
  invocation (step 3b).
- `agent-system/extensions/core/context/formats/plan-format.md` — amended the `full` tier's
  "Does NOT cover" cell, the Tier-Justification subsection, and the non-negotiable invariant
  paragraph: the complete gate set is owed once per invocation, discharged at the orchestration
  close under `/orchestrate`, or run directly by a standalone final phase with no Move 4.
- `agent-system/extensions/core/rules/plan-format-enforcement.md`, `agents/planner-agent.md`,
  `agents/general-implementation-agent.md`, `docs/guides/user-guide.md` — amended final-phase
  authoring instructions to match; de-scoped the Batch Gate Deferral directive's "(final phase
  only)" framing, since the directive names every qualifying phase.
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` — added the per-task red-close
  record writer (`records/close-battery-red.jsonl`, idempotent per session), the stale-marker and
  red-row discharge on a clean close, and consumption of a repository-declared `closing_gate`
  command for both Capture and Confirm snapshots (with a loud, never-silent failure path for a
  declared-but-unusable command).
- `agent-system/extensions/core/scripts/orchestrate-close-status-bind.sh` (new) — binds a red
  close's verdict to its attributed, completed task via the sanctioned status writer, demoting to
  `[PARTIAL]`; the second sanctioned exception to the `[COMPLETED]` terminal state.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — records every stale foreign
  batch-gate-pending marker into the multi-task state file's `close_battery_obligations` key at
  cycle start.
- `agent-system/extensions/core/scripts/lib/batch-gate-marker-lib.sh` — added
  `batch_gate_marker_roster`, a roster reader split by the existing staleness window.
- `agent-system/extensions/core/scripts/lib/verification-scope-lib.sh` — added
  `verification_scope_closing_gate`, the field's first reader.
- `agent-system/extensions/core/context/standards/status-markers.md` — recorded the second
  sanctioned `[COMPLETED]` exception and its rejected alternative.
- `agent-system/extensions/core/context/standards/repo-level-declarations.md` — documented the
  `closing_gate` field, added the previously-missing "Decisions Settled" heading.
- `agent-system/extensions/core/context/patterns/orchestrate-batch-results-template.md` — added
  the red-close and open-close-obligations sub-results.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 4 now also invokes
  `orchestrate-close-status-bind.sh` (documented via `batch-gate-stage.md`'s Executable Stage Body
  step 3b to respect the file's own zero-headroom eager-load budget).
- `agent-system/extensions/core/manifest.json` — registered the new script and suite.
- Five test suites extended (`test-orchestrate-batch-gate.sh` +11 cases, new
  `test-orchestrate-close-status-bind.sh`, `test-batch-gate-pending-marker.sh` +3 cases,
  `test-verification-scope-lib.sh` +6 cases) plus three pre-existing suites fixed forward
  (`test-suite-resolver-lib.sh`, `test-unmapped-fallback-lib.sh`, `test-verification-scope-lib.sh`
  migrated off the legacy `common_test_resolve_candidate` to `common_test_resolve_subject` +
  `common_test_declare_subject`).

## Decisions

- Vocabulary: `full` stays the single top tier token; its meaning is amended (discharge relocates,
  the ceiling does not move) rather than adding a fifth tier value.
- Red-close binding reads only `batch_gate.close_red_roster` (not `.attributed` separately), since
  the roster already carries exactly the information the four-way demotion gate needs.
- The close-status-bind script is a sibling script invoked from Move 4, never a prose instruction
  inside the batch gate script itself — advisory prose is not a mechanism, per this task's own
  OWNER RULING.
- Rejected alternative (recorded in `batch-gate-stage.md` and `status-markers.md`): holding every
  implicated task's completion open pending a green close. Rejected because it couples one task's
  completion to unrelated siblings' files under concurrency.

## Plan Deviations

- Phase 2's Scope Hypothesis named 5 stale-framing surfaces; a 6th (`docs/guides/user-guide.md`)
  was found and widened into, per the hypothesis's own instruction.
- Phase 4's script reads `batch_gate.close_red_roster` only, not `.attributed` separately (see
  Decisions above).
- Phase 7: `skills/skill-orchestrate/SKILL.md` was already at its `measure-eager-context.sh` byte
  ceiling with zero headroom (a prior task had trimmed it to exactly fit). The Move-4 invocation
  content was moved into `batch-gate-stage.md`'s own Executable Stage Body instead of living in
  SKILL.md's prose, keeping SKILL.md byte-identical to its pre-task baseline.
- Phase 7: fixed forward three pre-existing defects the redeploy's own fast-gate battery surfaced
  (none attributable to this plan's own earlier-phase edits): one shellcheck SC2034 finding in the
  new test suite, and a `lint-subject-resolution-declaration.sh` violation shared by two unrelated
  pre-existing suites plus this plan's own `test-verification-scope-lib.sh` (all three had never
  been caught before because no orchestration had closed on the full gate set since the commit
  that introduced them — itself a direct illustration of the defect this task fixes).

## Verification

- Build: N/A (bash/markdown only)
- Tests: `test-orchestrate-batch-gate.sh` 49/0, `test-orchestrate-close-status-bind.sh` 12/0,
  `test-batch-gate-pending-marker.sh` 25/0, `test-verification-scope-lib.sh` 30/0,
  `test-validate-artifact.sh` 146/0 — all against the deployed tree post-redeploy.
- `lint-agent-contracts.sh`: 0 failed (12 pre-existing warnings).
- `check-extension-docs.sh`: PASS, all extensions OK, zero drift.
- `deploy-headless.sh`: `RESULT=landed_verify_clean`, 41 checks, 0 failures.
- The complete, unnarrowed gate set (including Gate 8's full slow suite battery) was deliberately
  NOT run by this dispatch — this dispatch's own Batch Gate Deferral directive names this plan's
  final phase as deferring to the orchestration's Move 4 close, exactly the policy this task
  implements. The scoped touched-path check plus `deploy-headless.sh`'s own `--skip-slow` fast
  gate discharge this phase's own in-dispatch obligation.
- Files verified: yes (15 amended surfaces confirmed byte-identical between source store and
  deployed tree).

## Impacts

- Every invocation shape, including a batch of one, now defers the complete gate battery to the
  orchestration close rather than running it inside a task's own final phase.
- A red close battery now leaves a durable, attributed, operator-actionable record and, when the
  cause is a task already marked `[COMPLETED]` this invocation, demotes that task to `[PARTIAL]`.
- An orchestration that never reaches Move 4 (crash, interrupt, stop verdict) leaves a reported,
  durable open obligation that the next clean close discharges.
- A consumer repository can now declare its own closing gate and have Move 4 run it instead of
  `verify-deploy.sh`.
- Two pre-existing, previously-undetected defects in sibling test suites were fixed forward.

## Follow-ups

- The full, unnarrowed gate set (Gate 8's slow suite battery included) is still owed once, at this
  orchestration's own Move 4 close — not discharged by this implementer dispatch, by design.
- `project_gates` remains reserved and unresolved on `verification_scope`; owned by a separate,
  adjacent record (project-sources narrowing).

## References

- `specs/651_orchestration_close_owns_full_battery/reports/01_orchestration-close-owns-battery.md`
- `specs/651_orchestration_close_owns_full_battery/plans/01_orchestration-close-owns-battery.md`
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md`
- `agent-system/extensions/core/context/formats/plan-format.md`
