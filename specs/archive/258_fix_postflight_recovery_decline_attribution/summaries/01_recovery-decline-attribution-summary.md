# Implementation Summary: Task #258

- **Task**: 258 - Stop recording a declined return-meta recovery as HANDOFF_STALE_OR_ABSENT against skill-orchestrate
- **Status**: [COMPLETED]
- **Started**: 2026-09-25T21:00:00Z
- **Completed**: 2026-09-25T22:00:00Z
- **Effort**: ~1 hour
- **Dependencies**: Task 257 (return-meta status vocabulary library) — confirmed complete and reused
- **Artifacts**: plans/01_recovery-decline-attribution.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

`orchestrate-cycle-postflight.sh`'s WORK (d) branch previously recorded `HANDOFF_STALE_OR_ABSENT`
against `skill-orchestrate/SKILL.md` for every dispatch that wrote no handoff and whose
return-meta recovery declined, regardless of why. For a research dispatch (contractually
forbidden to write a handoff) whose `.return-meta.json` carried an out-of-vocabulary status
(e.g. `"completed"`), both the defect class and the attribution were wrong, and the message
("Skill did not write orchestrator handoff") was actively false. This task discriminates the
branch on `recover_json`'s `.reason` field, adds a new `RECOVERY_DECLINED` defect class attributed
to the dispatched agent's own file for the status-shaped sub-cases, and leaves the
"nothing usable was produced" sub-case (`META_MISSING`) on the original, unchanged behavior. A
predecessor regression in the fixture suite (a missing sandbox-copy of
`return-meta-status-vocabulary.sh`, silently causing 34 of 110 fixtures to fail) was discovered
and repaired first, as a prerequisite for using the suite as a regression guard.

## What Changed

- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — Phase 1
  added the missing `return-meta-status-vocabulary.sh` to both the `require_file` preflight list
  and the `setup_sandbox` copy list, restoring the suite from 76 passed/34 failed to 110/0. Phase
  4 added a `stub_agent_file` sandbox helper, two new fixtures (H: `STATUS_NOT_SUCCESS`, I:
  `STATUS_IN_PROGRESS`), and explicit zero-`RECOVERY_DECLINED`/unchanged-attribution assertions
  to fixtures (A), (C), and Acceptance (1), bringing the suite to 127 passed/0 failed.
- `agent-system/extensions/core/scripts/system-defect-record.sh` — added `RECOVERY_DECLINED` as
  the fifteenth value in the closed `--defect-class` enum; updated the validation error message
  and header/usage counts from "fourteen" to "fifteen".
- `agent-system/extensions/core/context/patterns/system-defect-discrimination.md` — added a
  Signal A table row and narrative paragraph defining `RECOVERY_DECLINED`; added a
  detection-point registry row naming `cycle-postflight-recovery-declined`; added a pointer from
  the Signal B / attribution discussion to `system-defect-record.sh`'s existing
  `--dispatched-agent` resolver (research had found this resolver already exists, correcting an
  earlier dispatch draft's premise that it needed to be built).
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — sourced
  `lib/return-meta-status-vocabulary.sh` (dual-candidate deploy/source-store resolution, hard
  dependency, mirroring `orchestrate-recover-outcome.sh`'s own copy of this block). Hoisted the
  `.status`/`.reason` reads above the WORK (d) record block. Split the
  `if [ "$handoff_expected" = "true" ]` body into a `case "$decline_reason"` with two arms: a new
  `RECOVERY_DECLINED` arm for `STATUS_IN_PROGRESS`/`STATUS_NOT_SUCCESS`/`META_DISPATCH_SEQ_MISMATCH`
  (message built from the vocabulary library, attributed to the dispatched agent's own file via a
  local agent-path glob mirroring the recorder's `--dispatched-agent` resolver), and the original,
  byte-identical `HANDOFF_STALE_OR_ABSENT` arm for every other reason (`META_MISSING`,
  `META_STALE`, `META_UNPARSEABLE`, and the `NONE`/USAGE fall-through).

## Decisions

- **Added a new `RECOVERY_DECLINED` class rather than reusing `HANDOFF_STALE_OR_ABSENT`** — the
  existing class's own definition is handoff-shaped ("a handoff whose mtime predates the dispatch
  window, or is otherwise absent when expected"); a `.return-meta.json` carrying
  `status: "completed"` is status-shaped, and no rewording would make the existing name accurate.
  Named `RECOVERY_DECLINED` rather than `STATUS_VOCABULARY_VIOLATION` because the branch also
  covers `STATUS_IN_PROGRESS`, and `in_progress` is a valid, non-terminal enum member, not a
  vocabulary violation.
- **Attribution boundary drawn at exactly one of six sites sharing the `attributed_path`
  constant** — the WORK (d) absent-handoff branch (this task's subject) changed; the stray-handoff
  sweep, the stale-handoff gate, the dispatch_seq-mismatch gate, the recovered-path
  `ARTIFACTS_SHAPE_MISMATCH` site, and the Tier C site are all deliberately left untouched (see
  the plan's Attribution Boundary table for the full per-site argument).
- **Two historical "fourteen" narrative mentions were kept, not globally replaced**, in
  `system-defect-discrimination.md` — they describe the pre-fifteenth-instance state using the
  document's own established idiom (the "thirteen pre-existing instances" phrasing survived
  unchanged when the fourteenth instance, `AMBIENT_BINDING_MISMATCH`, was added). Rewriting them
  would have broken both historical accuracy and the document's own convention.

## Plan Deviations

- Task 2.5 ("update any count-of-classes wording in the pattern doc that says fourteen") was
  altered, not applied literally: no live/current-count claim of "fourteen" existed to update; see
  the Decisions section above and `progress/phase-2-progress.json`'s `deviations` array for the
  full reasoning.

## Verification

- Build: N/A (bash scripts; `bash -n` syntax check passed on both edited scripts)
- Tests: `test-orchestrate-cycle-postflight.sh` 127 passed / 0 failed (up from a pre-existing-red
  76/34 baseline, repaired in Phase 1). `test-orchestrate-cycle-plan.sh` 274/0.
  `test-orchestrate-recover-outcome.sh` 7/0. `lint-agent-contracts.sh` 173 passed / 0 warnings / 0
  failed. `check-task-references.sh` 0 unexempted occurrences.
- Regression proof: temporarily reverting the Phase 3 production edit (restoring the
  pre-task `orchestrate-cycle-postflight.sh`) flips 9 of the new/extended fixtures red,
  confirming they genuinely exercise the change rather than passing tautologically; the fix was
  then restored byte-identical to the committed state.
- Manual end-to-end verification: four sandboxed invocations (forbidden status "completed",
  out-of-vocabulary status, `in_progress`, and `META_MISSING`) each produced the expected
  class/attribution/message; one live (non-dry-run) invocation confirmed a real
  `RECOVERY_DECLINED` event recorded to `events.jsonl` and the loop guard's `detected_defects[]`,
  attributed to `agent-system/extensions/core/agents/general-research-agent.md`, not
  `skill-orchestrate/SKILL.md`.
- Files verified: `git diff --stat` for the full task range shows exactly the four production
  files the plan named, all under `agent-system/extensions/core/`; no `.claude/**` path touched.

## Impacts

- A research dispatch whose agent reports an out-of-vocabulary or non-terminal `.return-meta.json`
  status will now be recorded as `RECOVERY_DECLINED`, attributed to that agent's own contract
  file, rather than as a false `HANDOFF_STALE_OR_ABSENT` claim against `skill-orchestrate/SKILL.md`.
  This corrects the diagnostic without silencing it — the branch still fires and still means
  something went wrong.
- The `system-defect-record.sh` `--defect-class` enum now accepts fifteen values instead of
  fourteen; any consumer that hardcodes the prior fourteen-value list (none currently known) would
  need updating separately.
- The `test-orchestrate-cycle-postflight.sh` regression baseline is restored to green, unblocking
  it as a reliable guard for future changes to this script.

## Follow-ups

- The same misattribution pattern exists at two other sites sharing the `attributed_path`
  constant: the recovered-path `ARTIFACTS_SHAPE_MISMATCH` site and the Tier C `OFF_SCHEMA_STATUS`
  site. Both are deliberately out of this task's scope (see the plan's Attribution Boundary
  table) and remain legitimate follow-up work.
- This task's own dispatch noted a self-modifying-candidate collision risk with a sibling task
  that also contemplated adding a value (`PHASE_ACCOUNTING_MISMATCH`) to the same closed enum in
  `system-defect-record.sh`. The batch-admission machinery serializes self-modifying candidates by
  design, so no manual coordination was needed here; a future implementer of that sibling task
  should re-verify the enum's current value count before adding to it.

## References

- Plan: `specs/258_fix_postflight_recovery_decline_attribution/plans/01_recovery-decline-attribution.md`
- Research report: `specs/258_fix_postflight_recovery_decline_attribution/reports/01_recovery-decline-attribution.md`
- Progress files: `specs/258_fix_postflight_recovery_decline_attribution/progress/phase-{1..5}-progress.json`
