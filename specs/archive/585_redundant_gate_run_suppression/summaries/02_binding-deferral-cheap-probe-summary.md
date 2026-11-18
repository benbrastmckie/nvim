# Implementation Summary: Task #585

- **Task**: 585 - Make the batch-gate deferral binding and cache repeat gate runs, so the full set runs once per batch
- **Status**: [COMPLETED]
- **Started**: 2026-11-16T12:40:48Z
- **Completed**: 2026-11-16T13:12:00Z
- **Effort**: ~0.75 hours
- **Dependencies**: None
- **Artifacts**: plans/02_binding-deferral-cheap-probe.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Made Mechanism A's `## Batch Gate Deferral` directive (in `orchestrate-build-dispatch.sh`) name
`--skip-unchanged` on the `verify-deploy.sh --only-gate` form as the sanctioned cheap probe for
re-confirming an already-green scoped tier, and added a NO ADDITIONAL FULL SWEEP paragraph
naming the mutex-queueing cost a redundant sweep imposes on sibling dispatches, routing the only
sanctioned escalation through the existing UNMAPPABLE CRITERION carve-out. Synced the three
consumer documents that restate the directive's invocation shapes, corrected the two derived
`line_count` index entries this grew, and redeployed. `context/contracts/phase-closure.md` was
confirmed to need no edit (cross-reference only, no invocation shape restated).

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — the `## Batch Gate
  Deferral` block's resolved-candidate branch now emits `--skip-unchanged` on the
  `verify-deploy.sh --only-gate N[,M...]` line only (never on the `run-all.sh --only` line,
  which does not parse that flag), plus new `CHEAP PROBE:` and `NO ADDITIONAL FULL SWEEP:`
  paragraphs. The `CHEAP PROBE:` paragraph is gated on `resolved_verify_deploy` being set so it
  never references an `--only-gate` form that was not actually printed; the degradation branch
  (neither entry point resolves) stays byte-identical.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — Group 19
  extended: asserts the resolved `--only-gate N[,M...] --skip-unchanged` string, asserts the
  `run-all.sh --only SUITE` line carries no `--skip-unchanged`, and asserts both new paragraph
  markers present in the resolved-candidate dispatch and absent in the degradation branch.
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` — the two-invocation
  sentence now names the `--skip-unchanged` cheap probe and the `run-all.sh` flag-parser
  asymmetry.
- `agent-system/extensions/core/context/formats/plan-format.md` — "Batch-aware deferral"'s "What
  the override changes" paragraph updated to both invocation shapes (deploy-target and
  source-store forms), plus a sentence extending the existing "never a tier" reading to
  `--skip-unchanged`.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — added a "Cheap probe,
  and no additional full sweep" paragraph to the "Batch Gate Deferral (final phase only)"
  subsection, mirroring the directive's own wording including the unmappable-criterion
  escalation requirement.
- `agent-system/extensions/core/index-entries.json` — corrected `line_count` for the two context
  entries the edits above grew (`formats/plan-format.md`, `contracts/batch-gate-stage.md`), via
  `generate-context-line-counts.sh --write`.
- Deployed `.claude/` tree regenerated via `deploy-headless.sh` (gitignored deploy artifact, not
  itself a git-tracked change).

## Decisions

- Gated the `CHEAP PROBE:` paragraph on `resolved_verify_deploy` being set, narrower than simply
  "inside the outer resolved-candidate branch," because the paragraph specifically describes the
  `--only-gate` form's `--skip-unchanged` behavior and would dangle a reference if only
  `run-all.sh` resolved. `NO ADDITIONAL FULL SWEEP:` stays unconditional inside the outer branch.
- `context/standards/shell-script-testing.md` was surfaced by the Phase 2 scope-hypothesis grep
  (it mentions `--only SUITE`/`--only-gate N`) but documents those flags' general
  testing-infrastructure semantics, never Mechanism A's emitted directive text — left unedited.
- `context/contracts/phase-closure.md` left unedited: its no-promotion-without-evidence carve-out
  only cross-references `plan-format.md`/`batch-gate-stage.md` by name, restating no invocation
  shape or flag.

## Plan Deviations

- **Task 3.2** (run `deploy-headless.sh`) altered: ran the deployed copy
  (`bash .claude/scripts/deploy-headless.sh`) rather than the source-store copy, since the
  source-store script requires bootstrapping from an already-deployed tree — the same constraint
  `generate-context-line-counts.sh` enforced in Phase 2. Same effective action, correct entry
  point; result `RESULT=landed_verify_clean`.
- **Task 3.4** (run the complete gate set as an independent step) altered: this dispatch itself
  carries a `## Batch Gate Deferral` directive naming this plan's own final phase, so the
  complete, flagless `verify-deploy.sh` was not independently invoked as a separate step.
  Discharged instead against the scoped tier the directive names
  (`verify-deploy.sh --only-gate 3 --skip-unchanged` plus the Phase 1/2 suite sets), deferring
  the complete gate set's formal discharge to the once-per-invocation batch stage (Move 4) per
  `context/contracts/phase-closure.md`'s no-promotion-without-evidence carve-out.
  `deploy-headless.sh`'s own mandatory internal landing self-check incidentally ran and passed
  the complete set during the redeploy task, but that is its own unavoidable landing contract,
  not an independently-chosen additional full sweep by this dispatch.

## Verification

- Build: N/A (shell/markdown edits only)
- Tests: Passed — `test-orchestrate-build-dispatch.sh` standalone (223/223), the named 9-suite
  Phase 1 set, the named 14-suite Phase 2 set, and `test-orchestrate-build-dispatch.sh` re-run
  against the deployed tree post-redeploy (1/1), all green.
- Files verified: Yes — `generate-context-line-counts.sh --check` exits 0;
  `verify-deploy.sh --only-gate 3 --skip-unchanged` reports 0 failures post-deploy; the deployed
  `orchestrate-build-dispatch.sh` carries the new flag and both new paragraphs (grep-confirmed).

## Impacts

- Every future batched implement dispatch carrying `--batch-gate-deferral` now sees the cheap
  probe named explicitly and a concrete no-additional-full-sweep obligation, directly targeting
  the mutex-queueing wait loops the originating report measured.
- No change to Move 4, `run-all.sh`, `verify-deploy.sh`, `gate-cache-lib.sh`,
  `suite-selection-lib.sh`, or Mode 2 co-scheduling admission — this plan's Non-Goals held.

## Follow-ups

- None — this is prose-only adoption; the next report 01-identified gap (Move 4 remaining
  structurally cache-proof) is intentionally out of scope and already recorded as a Non-Goal.

## References

- Plan: `specs/585_redundant_gate_run_suppression/plans/02_binding-deferral-cheap-probe.md`
- Reports: `specs/585_redundant_gate_run_suppression/reports/01_redundant-gate-run-suppression.md`,
  `specs/585_redundant_gate_run_suppression/reports/02_binding-deferral-and-cache-adoption.md`
