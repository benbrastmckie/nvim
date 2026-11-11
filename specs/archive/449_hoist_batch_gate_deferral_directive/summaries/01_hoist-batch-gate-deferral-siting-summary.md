# Implementation Summary: Task #449

- **Task**: 449 - Site the Batch Gate Deferral directive where it is read before the phase's verification is launched
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T08:02:05Z
- **Completed**: 2026-11-10T08:30:00Z
- **Effort**: ~3.25 hours (matches plan estimate)
- **Dependencies**: 328, 407, 445, 446, 447 (territory/serialization edges declared in the task description)
- **Artifacts**: plans/01_hoist-batch-gate-deferral-siting.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Hoisted the `## Batch Gate Deferral` dispatch-file section (Mechanism A of the batch-shared
verify-deploy-gate design) to be emitted immediately after `## Description`, ahead of the
`## Artifact Round`/`## Plan`/`## Continuation`/`## Phase Mission` group, so a dispatched agent
reading the file top-down meets the verification-scoping constraint before the plan body and
phase mission it narrows -- closing the exact read-too-late defect that caused one phase to run
the full `verify-deploy.sh` aggregator under contention instead of the scoped narrowing its own
dispatch directed. Added two missing clauses to the directive's text (a forward pointer to the
plan it constrains, and an unmappable-criterion rule), pinned the new emitted position and the
heading string in the composer's own test suite, recorded the decision and two rejected
alternatives in the durable contracts, and redeployed.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` -- relocated the entire
  `## Batch Gate Deferral` emission block (candidate-resolution preamble through the closing
  blank line) from its old position (nested inside `## Plan`'s `if [ "$phase" = "implement" ]`
  block, after `## Phase Mission`) to immediately after `## Description`'s emission, under an
  explicit `[ "$phase" = "implement" ] && [ "$batch_gate_deferral_flag" = "true" ]` guard
  conjunction. Added a forward-pointer clause (names that it constrains the plan's final phase)
  and an UNMAPPABLE CRITERION clause (a declared verification criterion naming a check neither
  narrowing invocation can express is run directly, scoped where possible, never waived) inside
  the resolved-candidate branch.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` -- Group 19
  extended with a position case (builds one `implement --hard --phase-number N
  --batch-gate-deferral` dispatch and asserts, by numeric line comparison, that
  `## Batch Gate Deferral` precedes both `## Plan` and `## Phase Mission` and follows
  `## Description`) and a heading-string case (asserts the exact literal heading is present in
  all five known prose consumers, resolved deploy-first with a source-store fallback). Updated
  Group 19's header comment and the research/plan absence-case comments from the retired
  "nested inside implement block" framing to the explicit-guard mechanism.
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` -- new
  "## Mechanism A's Dispatch-Time Siting" section recording the hoist rationale and the two
  rejected alternatives (restating inside `## Phase Mission`; making the aggregator itself
  batch-aware).
- `agent-system/extensions/core/context/formats/plan-format.md` -- new "Unmappable criterion"
  paragraph in the "Batch-aware deferral" subsection.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` -- corrected the
  batch-gate-stage description: the composer sets the flag on EVERY `implement`-phase dispatch
  of a genuine multi-task batch (confirmed against `orchestrate-cycle-plan.sh`'s actual gate,
  `[ "$g" = "implement" ] && [ "$_bgd_task_count" -gt 1 ]`), and the final-phase-only
  restriction on what the directive actually narrows is the consuming implementation agent's
  own obligation, not the composer's.
- Deployed `.claude/` tree regenerated to carry all five source-store changes live.

## Decisions

- Chose mechanism (1), hoisting the section, over the two other candidates offered in the task
  description: restating inside `## Phase Mission` cannot reach the ordinary, non-hard-mode
  dispatch shape that actually failed (that section is emitted only under hard mode's
  per-phase dispatch); making the aggregator itself batch-aware cannot be built fail-open today,
  since the nearest liveness signal (an `.orchestrator-multi-state-*.json` file's presence) has
  no cleanup path and so cannot be trusted as evidence a batch is still live.
- Confirmed the final-phase-only consumption scoping is not the defect (the cited miss's phase
  genuinely carried the obligation) and left it unwidened, per the task's own hard constraint.
- Placed the unmappable-criterion clause only inside the resolved-narrowing branch of the
  emitted directive, since the degraded branch already names the complete gate set and has no
  scoped tier that could fail to cover a named check.

## Plan Deviations

- **Task 3.1** (citation correction): the plan's citation of "Group 15's positioned-block case"
  for the `grep -n | head -1 | cut -d: -f1` ordering idiom had drifted; the idiom actually lives
  in the hard-mode-implement ordering guard immediately preceding the current Group 15. Reused
  it from its real location verbatim -- cosmetic, no functional change.
- **Task 5.1** (process deviation, self-referential): the first `deploy-headless.sh` call in
  Phase 5 omitted `--skip-verify`, so its default inline `verify-deploy.sh --skip-slow` ran the
  complete 42-check aggregator -- exactly the full-aggregator-under-contention risk this task's
  own subject matter exists to prevent. Caught and logged; corrected on the second deploy call
  (`--skip-verify`), followed by the dispatch's own named scoped narrowing instead of a third
  full-aggregator run.

## Verification

- Build: N/A (shell scripts; `bash -n` clean on both edited scripts)
- Tests: `test-orchestrate-build-dispatch.sh` -- 201 passed, 0 failed (run against both the
  source-store and the deployed copy). The named 9-suite scoped narrowing
  (`run-all.sh --only test-force-phases.sh,test-orchestrate-build-aux-dispatch.sh,
  test-orchestrate-build-dispatch.sh,test-orchestrate-context-growth.sh,
  test-orchestrate-cycle-plan.sh,test-orchestrate-record-decision.sh,
  test-orchestrate-recover-message-findings.sh,test-orchestrate-unwind-dispatch.sh,
  test-routing-resolution.sh`) showed two unrelated, pre-existing failures
  (`test-orchestrate-build-aux-dispatch.sh`'s model-resolution issue,
  `test-orchestrate-unwind-dispatch.sh`'s missing-lib-script sandbox defect), both logged and
  neither touching any file this task edited.
- Negative control: reverting the source-store composer to its pre-hoist (nested) content made
  the new position case FAIL exactly as expected; the composer was restored and byte-verified
  (`md5sum`) before the suite was confirmed green again.
- Lint: `check-task-references.sh` and `check-record-versioning.sh` both exit 0 clean on all
  three edited prose files.
- Files verified: Yes -- `diff -q` confirms all five edited files are byte-identical deployed
  vs source-store; a composed dispatch built from the DEPLOYED composer confirms
  `## Batch Gate Deferral` sits between `## Description` and `## Artifact Round`/`## Plan`.

## Impacts

- A future `implement`-phase dispatch inside a multi-task batch now encounters the
  verification-scoping directive before the plan body and phase mission it constrains, removing
  the structural ordering hazard that caused the cited contention incident.
- The directive now covers the previously-undocumented case of a declared verification
  criterion naming a check neither narrowing invocation can express.
- The batch-gate-stage contract, the plan-format spec, and the orchestrate-state-machine
  architecture doc are all now consistent with the actual composer behavior.

## Follow-ups

- None required by this task. Three pre-existing, unrelated issues were observed and logged
  during verification (a memory-extension dead-command-recommendation finding, pre-existing
  shellcheck findings in unrelated scripts, an eager-context-budget baseline drift, a
  manifest-routing model-resolution issue, and a test-sandbox missing-lib-script defect) --
  none are blocking and none are in this task's declared scope to fix.

## References

- Plan: `specs/449_hoist_batch_gate_deferral_directive/plans/01_hoist-batch-gate-deferral-siting.md`
- Research: `specs/449_hoist_batch_gate_deferral_directive/reports/01_batch-gate-deferral-siting.md`
- Progress files: `specs/449_hoist_batch_gate_deferral_directive/progress/phase-{1..5}-progress.json`
- Handoffs: `specs/449_hoist_batch_gate_deferral_directive/handoffs/`
