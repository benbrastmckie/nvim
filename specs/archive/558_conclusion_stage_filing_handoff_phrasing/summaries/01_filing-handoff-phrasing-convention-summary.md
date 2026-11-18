# Implementation Summary: Task #558

- **Task**: 558 - Document the convention that a task description must request a PROPOSAL
  PACKET, never task FILING, from an autonomous dispatch
- **Status**: [COMPLETED]
- **Started**: 2026-11-17T00:00:00Z
- **Completed**: 2026-11-17T00:55:00Z
- **Effort**: ~1 hour
- **Dependencies**: None
- **Artifacts**: plans/01_filing-handoff-phrasing-convention.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Documentation-only change at two sites in the `core` extension's source store. A new
subsection, "Requesting a Proposal Packet, Not Filing, From an Autonomous Dispatch", was added
to `multi-task-creation-standard.md` immediately after Component 7's Foreground Requirement,
stating the forbidden shape (a dispatch instructed to itself file tasks), the required shape
(issue-log entries with `suggested_channel` plus a rendered candidate list), and the WHY by
citation. A pointer-only note was added to `conclusion-stage.md`'s Overview, telling a reader
reasoning from the conclusion stage's own vocabulary that naming the stage as the filer is
malformed, and sending them to the single statement. Both edits were redeployed via
`deploy-headless.sh` (`RESULT=landed_verify_clean`) and confirmed present in the deployed
mirror.

## What Changed

- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md` —
  added a new subsection after Component 7's Foreground Requirement, stating the convention
  once: scope, forbidden shape, required shape, WHY citations, and the accurate downstream
  chain.
- `agent-system/extensions/core/context/contracts/conclusion-stage.md` — added a two-sentence
  pointer in the Overview, after the "Only channel (a) executes anything" paragraph, citing the
  new subsection's heading verbatim and deferring to it rather than restating it.
- `agent-system/extensions/core/index-entries.json` — updated the `line_count` field for
  `contracts/conclusion-stage.md` from 500 to 506 to match the file's new length (required to
  clear Gate 3 doc-lint after the prose addition).
- Deployed `.claude/` tree — regenerated via `deploy-headless.sh`; both edits confirmed present
  at `.claude/docs/reference/standards/multi-task-creation-standard.md` and
  `.claude/context/contracts/conclusion-stage.md`.

## Decisions

- Sited the convention at the task-authoring standard (Component 7-adjacent), composed with a
  pointer-only note at the conclusion-stage contract, per the research report's siting
  diagnosis — rejecting a dispatch-composition-path site as treating the symptom rather than
  the phrasing.
- Described the downstream chain accurately (dispatch records evidence -> conclusion stage
  aggregates/classifies without creating anything -> a separate, deliberately-batched
  foreground invocation performs confirmed creation) rather than the task description's original
  "the conclusion stage files channel (c)" framing, per the plan's Carried-Figure correction.
- Pointed at the existing `suggested_channel` field (`context/formats/issue-log.md`) rather than
  specifying a new packet format — none existed, and none was warranted.

## Plan Deviations

- **Phase 2** (task 2.6, not an original plan task): Gate 3 doc-lint failed on an
  `index-entries.json` `line_count` mismatch for `contracts/conclusion-stage.md` after the prose
  addition (declared 500, actual 506). Fixed by hand-updating the field in
  `agent-system/extensions/core/index-entries.json`, since `generate-context-line-counts.sh
  --write` refuses to run from the source store.
- **Phase 3** (task 3.5): the plan's own verification bullet names an unflagged, full-depth
  `verify-deploy.sh` run. This dispatch carried a Batch Gate Deferral directive for this phase's
  declared `full` tier, instructing a scoped discharge instead of an independent full sweep
  (the complete gate set runs once at the end of the whole `/orchestrate` batch invocation).
  Discharged via `verify-deploy.sh --only-gate 3,4 --skip-unchanged` (PASS) plus
  `deploy-headless.sh`'s own internal `verify-deploy.sh --skip-slow` pass (41 checks, 0
  failures).

## Verification

- Build: N/A (documentation-only change)
- Tests: Passed — `test-orchestrate-conclusion-aggregate.sh`,
  `test-orchestrate-conclusion-backstop.sh`, `test-orchestrate-conclusion-roadmap.sh` all PASS
- Gates: Gate 3 (doc-lint) and Gate 4 (task-reference lint) PASS, both pre- and post-deploy
- Deploy: `RESULT=landed_verify_clean`
- Files verified: Yes — both edits confirmed present in the deployed mirror by grep

## Impacts

- A future task description or plan phase instructing an autonomous dispatch to file follow-up
  tasks or agent-system changes now has a single, citable, correctly-sited statement of why that
  instruction cannot be honored and what to ask for instead, reachable from both the
  task-authoring standard and the conclusion-stage contract.
- No change to Component 7's foreground requirement, the `AskUserQuestion` withholding, the
  conclusion stage's channel routing, or the skeleton-plan follow-up mechanism.

## Follow-ups

- None. No sweep of existing task descriptions carrying the offending phrasing was in scope (an
  explicit non-goal); if wanted, it is its own record.

## References

- `specs/558_conclusion_stage_filing_handoff_phrasing/plans/01_filing-handoff-phrasing-convention.md`
- `specs/558_conclusion_stage_filing_handoff_phrasing/reports/01_filing-handoff-phrasing-convention.md`
- `agent-system/extensions/core/docs/reference/standards/multi-task-creation-standard.md`
- `agent-system/extensions/core/context/contracts/conclusion-stage.md`
