# Implementation Summary: Task #150

- **Task**: 150 - Research on demand: planner-first lifecycle with research only when the planner asks or --research forces it
- **Status**: [COMPLETED]
- **Started**: 2026-09-08
- **Completed**: 2026-09-08
- **Effort**: ~5 hours
- **Dependencies**: Task 88 (completed - four-move engine is the only engine)
- **Artifacts**: plans/01_research-on-demand-lifecycle.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Flipped the default `/orchestrate` lifecycle from `research -> plan -> implement` to
`plan -> implement`, and gave the planner authority to send a task back for research by
returning a `needs_research` verdict carrying a focused question list. All 6 plan phases
completed: vocabulary admission across every upstream gate, status-write/write-back plumbing,
dedicated postflight handling for the new verdict, the routing flip itself (with `--focus`
wiring), planner-agent contract changes, and a fixture-test/full-gate closeout.

## What Changed

- `agent-system/extensions/core/context/formats/return-metadata-file.md` — added `needs_research`
  to the status enum plus dedicated field notes for it and the new `research_questions` field.
- `agent-system/extensions/core/scripts/orchestrate-recover-outcome.sh` — new `needs_research`
  case arm (recovered=true, evidence_suspect=false, no artifacts-evidence logic).
- `agent-system/extensions/core/scripts/validate-return-meta.sh`,
  `agent-system/extensions/core/scripts/validate-handoff.sh` — extended `valid_statuses`.
- `agent-system/extensions/core/scripts/reconcile-task-status.sh` — recorded (as a comment, not a
  code change) the finding that `needs_research` is unreachable via a handoff, since
  `planner-agent` never writes one.
- `agent-system/extensions/core/context/patterns/metadata-file-return.md`,
  `context/architecture/system-overview.md`, `context/patterns/system-defect-discrimination.md`,
  `context/formats/subagent-return.md` — doc mirrors of the vocabulary string.
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`,
  `orchestrate-stage5-postflight.sh` — off-schema message strings updated.
- `agent-system/extensions/core/scripts/update-task-status.sh` — new
  `postflight:needs_research) STATE_STATUS="researching"` map_status() arm and a
  `--research-questions=<json-array>` flag (overwrite-on-write, structurally mirroring
  `--file-scope-add`'s additive union-merge but replacing rather than merging).
- `agent-system/extensions/core/scripts/skill-base.sh` — `skill_postflight_update()` gained a
  `needs_research)` case arm forwarding `research_questions`, plus a documented decision that the
  monotonic-max clamp can never block a `needs_research` write (the value is deliberately absent
  from the ranked lifecycle subset).
- `agent-system/extensions/core/context/reference/state-management-schema.md`,
  `context/schemas/state-schema.json` — documented and schema-admitted the new
  `research_questions` task-record field (the schema addition was a necessary correctness fix not
  named in the plan's file list; see Plan Deviations).
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — flipped the live jq
  classifier's `not_started` row and the blocked-discharge re-routing table's equivalent row to
  `plan`; extended the header's "one code path" discipline note to name the degraded fallback
  table as a fourth site.
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — flipped the degraded
  fallback table (splitting the combined `not_started|researching)` case), and wired
  `research_questions` into `--focus` at the research-dispatch build call.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — updated the
  Complete State Table, the ASCII diagram, added a "The `needs_research` Fork" subsection and two
  worked-example flows.
- `agent-system/extensions/core/agents/planner-agent.md` — new Stage 1.5 (opening assessment,
  narrow bar for requesting research, negative examples), new Stage 6c (`needs_research` return
  shape), and updated Error Handling / Critical Requirements.
- `agent-system/extensions/core/agents/general-research-agent.md` — acknowledged that
  `focus_prompt` may now carry a planner's forwarded `research_questions`.
- `agent-system/extensions/core/context/standards/status-markers.md` — documented
  `[RESEARCHING]`'s second producer and the two-phase default, cross-referencing
  `orchestrate-state-machine.md`.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-triage-classify.sh`,
  `test-orchestrate-cycle-plan.sh`, `test-orchestrate-cycle-postflight.sh` — fixture coverage for
  every new behavior (see Verification).

## Decisions

- `researching` (not a new state value) is the resting state for a `needs_research` verdict,
  reusing the existing `researching -> research` classifier row.
- `research_questions` uses overwrite-on-write semantics (full replacement), not the additive
  union-merge `file_scope`/`--file-scope-add` use — a second `needs_research` round should not
  accumulate stale questions from the first.
- The monotonic-max clamp is made inert for `needs_research` by construction (the value is simply
  never added to the ranked lifecycle subset), rather than by adding an explicit exemption
  branch — the simpler of the two options Phase 2 considered, and verified by fixture.
- `reconcile-task-status.sh`'s on-enum refusal set was left unchanged rather than extended,
  after confirming (via `docs/architecture/handoff-schema.md`'s Handoff Writers table) that
  `needs_research` can never reach it: `planner-agent` never writes a handoff.

## Plan Deviations

- **Phase 2** added `research_questions` to `context/schemas/state-schema.json`'s
  `active_projects` entry shape (`additionalProperties: false`), which was not named in the
  plan's Phase 2 file list. Required for correctness: without it, any task carrying
  `research_questions` would fail `validate-state.sh --deep` schema validation.

## Verification

- Build: N/A (no compiled artifacts)
- Tests: Passed — `test-orchestrate-triage-classify.sh` 38/38, `test-orchestrate-cycle-plan.sh`
  96/96, `test-orchestrate-cycle-postflight.sh` 57/57. `test-update-task-status.sh` 29/29
  (regression check on Phase 2's edited script). `lint-agent-contracts.sh` 101/101.
  `check-task-references.sh` 0 unexempted occurrences across `agent-system/extensions`.
  8 additional `scripts/lint/*.sh` scripts all green.
- Files verified: Yes — `validate-artifact.sh` passes on this task's own plan file.

## Impacts

- A fresh, specification-shaped task now reaches `[PLANNED]` in a single dispatch instead of two
  (research then plan), cutting one full agent run plus a cycle for the common case.
- A task whose planner genuinely needs research still gets it, on demand, with a focused question
  list carried into the dispatch file rather than a generic "please research this" instruction.
- `--research` and every existing research-forcing behavior is unchanged and independently
  verified.

## Follow-ups

- None.

## References

- `specs/150_research_on_demand/plans/01_research-on-demand-lifecycle.md`
- `specs/150_research_on_demand/reports/01_research-on-demand-lifecycle.md`
- `specs/PATH.md`, Stage A.8
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`, "The `needs_research` Fork"
