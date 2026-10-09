# Implementation Summary: Task #299

- **Task**: 299 - Guarantee that an in-place plan revision landing concurrently with a live
  implement dispatch is DETECTED, by adopting two complementary remedies together
- **Status**: [COMPLETED]
- **Started**: 2026-10-09T05:07:32Z
- **Completed**: 2026-10-09T06:58:00Z
- **Effort**: ~2 hours
- **Dependencies**: None
- **Artifacts**: plans/01_detect-plan-revision-notification.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Landed both remedies the task named for the hazard where a `plan-revision` aux row and the same
task's `implement` row can be co-dispatched in one `/orchestrate` cycle, letting `reviser-agent`
rewrite the plan file in place while the implement agent is still reading it with nothing making
it aware. Remedy 1 makes the previously-discretionary landed-revision signal routine: an
unconditional `.plan-revised.json` sentinel write, contractual on both the `/orchestrate` aux path
and the `/revise` agent path. Remedy 2 adds a narrow, per-phase pre-write re-read obligation to
both implementation agents, reconciled explicitly with the existing successor "do NOT re-read the
full plan" line rather than contradicting it. All substantive contract prose lives in one new
`context/patterns/` file; every other site carries only a short pointer, keeping
`skills/skill-orchestrate/SKILL.md` byte-untouched against its now-hard budget gate.

## What Changed

- `agent-system/extensions/core/context/patterns/plan-revision-notification.md` — new file: the
  single contract defining the hazard, the `.plan-revised.json` sentinel's field list, the
  `revised_at >= dispatch_start_ts` freshness rule (and why no consume-and-clear step is needed),
  both the writer and reader obligations, which remedy carries which guarantee, the four adjacent
  mechanisms that are NOT coverage, and the design invariant against per-cycle-varying dispatch
  content.
- `agent-system/extensions/core/index-entries.json` — one new `entries[]` row registering the
  pattern file (`domain: core`, `subdomain: patterns`, scoped to all three consuming agents and
  `/orchestrate`).
- `agent-system/extensions/core/scripts/orchestrate-build-aux-dispatch.sh` — the `plan-revision)`
  prompt arm now appends one unconditional clause (after the blocker/drift `if/else`, shared by
  both branches) instructing `reviser-agent` to write the sentinel after writing the revised plan.
  No new flag; the usage block is unchanged.
- `agent-system/extensions/core/agents/reviser-agent.md` — new Stage 5c ("Signal the Landed
  Revision") stating the writer obligation, plus a `## Context References` entry for the pattern
  file.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — the implement-phase
  `## Plan` block now emits a static `- revision_sentinel: ${TASK_DIR_ABS}/.plan-revised.json`
  line plus fixed pointer prose, with an adjacent code comment pointing at the
  FORWARD-POINTER/`cycle_plan_dispatch_hash()` constraint. Nothing derived from the plan file's
  content, modification time, size, or hash.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — a standalone bolded
  "Pre-write re-read obligation" paragraph under Stage 4 (not a renumbered list item, preserving
  the live "see step 4 below" cross-reference), a carve-out sentence after the Successor
  Behavior's existing "Do NOT re-read the full plan unless necessary" line (left byte-identical),
  a one-line Stage 2 snapshot note, and a `## Context References` entry.
- `agent-system/extensions/lean/agents/lean-implementation-agent.md` — the same pre-write
  re-read obligation mirrored under "### Before Starting a Phase" (a pure addition — this agent
  has no successor/continuation language to reconcile with), plus a `## Context References`
  entry. `lean-implementation-hard-agent.md` deliberately untouched.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-aux-dispatch.sh` — 4 new
  assertions proving the sentinel clause for both `--revision-reason blocker` and `drift`, each
  naming the absolute task-dir path (suite: 22 passed, 0 failed).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — 3 new
  assertions (presence with the expected path and pointer; implement-only, absent from `plan` and
  `research`) plus a new Group 18 hash-stability test that byte-extracts the real
  `cycle_plan_dispatch_hash()` from `orchestrate-cycle-plan.sh` (the same idiom as that script's
  own Group 27 Case A) and proves the implement dispatch body hashes identically across a plan
  edit and differing `dispatch_seq`/`dispatch_start_ts` (suite: 148 passed, 0 failed).

## Decisions

- The OPEN DECISION from the task description is resolved as option (c) (recommended):
  unconditional emission in every `plan-revision` aux dispatch file, inert when no implement
  dispatch is live. `orchestrate-cycle-plan.sh` is not edited.
- The sentinel's freshness baseline is the reading agent's own first read
  (`dispatch_start_ts`), never a dispatch-build-time value — overriding the research report's
  "or the plan's mtime at dispatch-build time" suggestion, because a build-time value would be a
  new per-cycle-varying dispatch-file line that `cycle_plan_dispatch_hash()`'s strip pattern would
  need to absorb, silently defeating the IDENTICAL DISPATCH HALT exactly as happened once before.
- No consume-and-clear step exists for the sentinel: the freshness rule makes an older sentinel
  inert by construction, which is strictly simpler than the `aux_consume_blocker_file`/
  `aux_consume_drift_file` cross-cycle pattern research proposed adapting.

## Plan Deviations

- **Task 5.8** (run the complete gate set with no residual failure) altered: Gate 3 doc-lint
  FAILed on a file (`scripts/tests/test-lint-agent-contracts-handoff-section.sh`) added by a
  concurrently-dispatched sibling task's own commit (`3540a3194`, outside this task's `file_scope`
  and territory). Recorded as a Reasoned Exclusion in the plan's Phase 5 body; 34 of 35 gate-set
  checks pass.

## Verification

- Build: N/A (no compiled artifact)
- Tests: `test-orchestrate-build-aux-dispatch.sh` 22/22 passed; `test-orchestrate-build-dispatch.sh`
  148/148 passed; the 8 suites mapped to the touched scripts (including
  `test-orchestrate-cycle-plan.sh`'s Group 27 Case F, the IDENTICAL DISPATCH HALT regression
  fixture) all pass; `shellcheck -S error` exits 0 on all four touched shell files with full-
  severity counts identical to their pre-edit baselines.
- Files verified: Yes — the new pattern file and its index row are present in the redeployed
  `.claude/` tree; `git diff --stat` on `skills/skill-orchestrate/SKILL.md` is empty.
- Full gate set: `verify-deploy.sh` (no `--only-gate`, no `--skip-slow`) — 34 of 35 checks pass;
  the one residual failure is the Reasoned Exclusion above.

## Impacts

- A production race between a plan revision and a live implement dispatch is now both signaled
  (routine sentinel) and caught even if the signal lags (narrow pre-write re-read) — the two
  remedies cover each other's blind spot per the plan's own "which remedy carries which guarantee"
  framing.
- `skills/skill-orchestrate/SKILL.md` and `scripts/orchestrate-cycle-plan.sh` remain untouched;
  the orchestrator context budget gate (now hard) is unaffected (65,939 B against a 65,950 B
  baseline, unchanged by this task).
- Both implementation agents (core and lean) now carry parallel pre-write obligations; a future
  third implementation agent should follow the same pattern-file-pointer shape rather than
  inlining the contract a third time.

## Follow-ups

- Remedy 3 (defer the revision one cycle rather than co-dispatching) remains explicitly rejected,
  not deferred into a successor task.
- The header-only-correction-label finding (a correction label does not survive a line-range
  excerpt taken from below it) remains out of scope — a plan-authoring documentation-form finding,
  not an orchestrator defect, already fixed directly in the affected plan at the time it was
  observed.
- Gate 3's doc-lint finding (task 370's unregistered test file) is expected to self-resolve once
  task 370 completes its own remaining phases; no follow-up task is needed from this task.

## References

- `specs/299_detect_plan_revision_during_implement/reports/01_detect-plan-revision-notification.md`
- `specs/299_detect_plan_revision_during_implement/plans/01_detect-plan-revision-notification.md`
- `agent-system/extensions/core/context/patterns/plan-revision-notification.md`
