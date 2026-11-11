# Implementation Summary: Make a Settled Route's Obligation Recordable, Required, and Propagated

- **Task**: Require a settled user-decision route to name the obligation it discharges, and check that claim before a dispatch spends a cycle on it
- **Status**: [COMPLETED]
- **Started**: 2026-11-10T00:50:00Z
- **Completed**: 2026-11-10T05:00:00Z
- **Effort**: ~4 hours
- **Dependencies**: None blocking
- **Artifacts**: plans/01_validate-settled-route-before-dispatch.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md

## Overview

The `/orchestrate` user-decision pipeline recorded a settled answer to `.decisions.json` and
relayed it into the next dispatch with an instruction to treat it as settled, but nothing in the
chain recorded — or could record — what obligation the chosen route was supposed to discharge.
This implementation closes that gap by adding an optional `obligation` field to the decisions
schema, requiring it at proposal time for ROUTE decisions, propagating it inline into the
dispatch's existing `## Prior Decisions` section with a verify-before-you-start instruction, and
wiring the loop's batched relay to pass it through. All edits landed in the source store
(`agent-system/extensions/core/**`) and were redeployed.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-record-decision.sh` — optional
  `--obligation "..."` argument; the record build now generalizes the prior two-branch
  `description_fingerprint` pattern to a base object plus two independent conditional merges,
  so `obligation` is present only when supplied and never as an empty string.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — documents the `obligation`
  field in the Decisions File Schema section, with a second illustrative example entry.
- `agent-system/extensions/core/docs/reference/utility-scripts-inventory.md` — writer's usage
  line updated with the optional flag.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-record-decision.sh` — five new
  cases ((c3)-(c7)): legacy-call-still-validates, obligation round-trip, obligation omission,
  object-wrapper refusal with `--obligation` supplied, and no-sha256sum independence.
- `agent-system/extensions/core/context/standards/user-decision-contract.md` — `obligation`
  added to the Field Shape table (required for a ROUTE decision), a mirror-polarity proposal-time
  self-check added to "When NOT to Raise One" (an option set presented as open when its
  alternatives are already structurally excluded), and a paragraph distinguishing both additions
  from a license to re-litigate a settled question.
- `agent-system/extensions/core/context/formats/return-metadata-file.md` — `user_decision` shape
  line updated with the new optional key.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — every
  `prior_decisions_block` jq branch (fingerprint-aware and fingerprint-unavailable) renders an
  `Obligation: ...` line when the field is present; the `## Prior Decisions` emission block adds
  a conditional receiving-agent instruction (verify discharge before starting phase work; raise a
  NEW blocking question, never a re-ask, if it does not hold), emitted only when at least one
  rendered entry carries an obligation.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — new
  "Recording, Emitting, and Adjudicating a Route's Obligation" subsection recording the
  record/emit/adjudicate split across the writer, composer, and receiving agent.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — new "Group
  10b" fixture block: obligation rendering, obligation omission (byte-identical to the
  pre-feature case), coexistence with `POTENTIALLY SUPERSEDED`, and both regression polarities
  from the task description (a route that does not discharge its stated obligation; a structural
  assertion pinning the mirror-polarity self-check in the contract prose).
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 4's batched relay
  passes `.decision.obligation` to the writer's `--obligation` argument when present; a note
  records that postflight needs no change since it already relays `user_decision` verbatim.
- `agent-system/extensions/core/index-entries.json` — line-count entries for the two Phase 2
  markdown files resynced via `generate-context-line-counts.sh --write`, surgically isolated from
  three unrelated, pre-existing, uncommitted foreign entries already present in this file before
  this task began.
- Deployed `.claude/` tree redeployed via `deploy-headless.sh`; all ten touched source-store
  files confirmed byte-identical to their deployed counterparts.

## Decisions

- Adopted candidates (1) make-the-claim-recordable-and-require-it plus (3)
  propagate-to-the-implementer; rejected (2) central mechanical validation, per the plan's
  Mechanism Ruling (carried from research) — judging whether a route discharges an obligation is
  a semantic relation this codebase has already declined to mechanize for its structurally
  closest existing feature.
- The record-build's four field-presence combinations are implemented as a base object plus two
  independent conditional `+ {...}` merges rather than four explicit branches — functionally
  equivalent, strictly additive per field, and easier to extend with a third optional field later.
- The `Obligation:` line renders before the `POTENTIALLY SUPERSEDED` conditional in both
  composer branches — an arbitrary but now-fixed ordering, pinned by the Group 10b coexistence
  test.
- `skill-orchestrate/SKILL.md`'s Move 4 paragraph was compacted twice during implementation to
  stay under its 25,000 B context-budget ceiling, following the same trim-first convention the
  budget config's own derivation history documents for every prior addition to this file.

## Plan Deviations

- None in substance. Two verification-process nuances were recorded as issues during
  implementation (not substantive deviations): (1) the test suite's `common_test_resolve_subject`
  deploy-tree-first default requires `CORE_TEST_SUBJECT_MODE=source-store` to exercise
  source-store-only changes ahead of the Phase 5 redeploy — documented, not a defect; (2) an
  independent, un-scoped `verify-deploy.sh` run inside Phase 5 collided with this dispatch's own
  Batch Gate Deferral directive and with the plan's own "do not run while another session is
  active" instruction — corrected mid-phase by switching to the scoped narrowing the plan and
  directive both specify.

## Verification

- Build: N/A (shell scripts and markdown; no compiled build step)
- Tests: Passed — `test-orchestrate-record-decision.sh` 16/16 (11 pre-existing + 5 new);
  `test-orchestrate-build-dispatch.sh` 218/218 (201 pre-existing + 17 new); the scoped Tier
  Justification suite sets for all five phases passed cleanly (17-suite union re-run clean at
  Phase 5 close)
- Files verified: Yes — all ten touched files confirmed byte-identical between the source store
  and the deployed `.claude/` tree after redeploy
- Full gate set: Completed with exclusions — the scoped discharge (suite union plus
  `--only-gate 3,4`) is green; three pre-existing, unrelated findings (eager-load context-budget
  baseline drift, two unrelated shellcheck findings, two unrelated dead-command-recommendation
  findings) are excluded with evidence in Phase 5's `#### Reasoned Exclusions` record — none are
  in this task's declared scope and none were introduced by this task's edits. The complete,
  un-scoped gate set remains deferred to the once-per-invocation batch stage per the dispatch's
  own Batch Gate Deferral directive, never independently re-run by this dispatch.

## Impacts

- A future settled route recorded via the batched `AskUserQuestion` relay can now name the
  obligation it discharges; the receiving dispatch is instructed to verify that claim before
  starting phase work and to raise a new, specific blocking question — never a re-ask — if the
  route does not hold. This closes the mechanism gap the originating incident described: a
  settled decision reaching an implementer with the full authority of a user decision and none
  of the checkability.
- The mirror-polarity self-check (an option set presented as open when its alternatives are
  already structurally excluded) is now a proposal-time check any agent raising a `user_decision`
  must apply, independent of whether the chosen mechanism is used for the primary (route)
  incident shape.
- No existing `.decisions.json` entry, dispatch render, or `AskUserQuestion` relay behavior
  changes when the new field is absent — confirmed byte-identical across both the writer and
  composer test suites.

## Follow-ups

- The three pre-existing, unrelated gate findings recorded as Reasoned Exclusions in Phase 5
  (eager-load context-budget baseline overage, two shellcheck findings, two
  dead-command-recommendation findings) remain open and belong to separate maintenance, not to
  this task.
- The complete `verify-deploy.sh` gate set's result against this task's own `modified_files` is
  attributed at the batch level, per the Batch Gate Deferral directive — no further action is
  needed from this task to discharge it.

## References

- `specs/450_validate_settled_route_before_dispatch/plans/01_validate-settled-route-before-dispatch.md`
- `specs/450_validate_settled_route_before_dispatch/reports/01_validate-settled-route-before-dispatch.md`
- `specs/450_validate_settled_route_before_dispatch/handoffs/phase-1-handoff-20261110T010800Z.md`
- `specs/450_validate_settled_route_before_dispatch/handoffs/phase-2-handoff-20261110T012500Z.md`
- `specs/450_validate_settled_route_before_dispatch/handoffs/phase-3-handoff-20261110T015000Z.md`
- `specs/450_validate_settled_route_before_dispatch/handoffs/phase-4-handoff-20261110T022000Z.md`
- `specs/450_validate_settled_route_before_dispatch/handoffs/phase-5-handoff-20261110T050000Z.md`
