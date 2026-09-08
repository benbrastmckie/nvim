# Implementation Summary: Task #88

- **Task**: 88 - Delete the single-task engine and rewrite skill-orchestrate as the four-move loop
- **Status**: [COMPLETED]
- **Started**: 2026-09-08T04:25:00Z
- **Completed**: 2026-09-08T09:15:00Z
- **Effort**: ~5 hours
- **Dependencies**: 148 (completed and archived)
- **Artifacts**: plans/01_four-move-loop-rewrite.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md, source-store-deploy-boundary.md, no-task-references-in-deliverables.md

## Overview

Deleted the single-task `/orchestrate` engine (Stages 0-8, ~130,000 B) outright from
`skills/skill-orchestrate/SKILL.md`, relocated the narration it and the multi-task section carried
into `docs/architecture/`, and rewrote the remainder as the four-move loop (plan the cycle ->
dispatch -> postflight -> branch) — one engine for every batch size, including a batch of one.
Built the batched `AskUserQuestion` -> `.decisions.json` -> next-dispatch-file relay end to end,
retargeted or retired every test and lint coupled to the deleted structure, refreshed the
downstream registry and plan-of-record, and fixed a real defect in `commands/orchestrate.md`
(a dead pre-rewrite single-task fallthrough branch) discovered during acceptance verification.

## What Changed

- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — rewritten from 189,000 B
  (dual single-task/multi-task engine) to 15,666 B (the four-move loop only): Move 1 (plan the
  cycle via `orchestrate-cycle-plan.sh`, plus the hard-mode burnout gate), Move 2 (dispatch — one
  Agent call per `dispatch[]`/`aux_dispatch[]` row, all in one message), Move 3 (postflight via
  `orchestrate-cycle-postflight.sh`, one call per dispatched task), Move 4 (branch — exit-status
  resolution, the new batched `AskUserQuestion` relay, consolidated output, cleanup). Both
  `## MUST NOT` sections trimmed to a combined 1,369 B. `allowed-tools` frontmatter gained
  `AskUserQuestion`.
- `agent-system/extensions/core/commands/orchestrate.md` — removed the dead pre-rewrite
  `len(TASK_NUMBERS) == 1` fallthrough branch, the `ORCHESTRATE_BATCH_OF_ONE` experimental flag,
  and the now-unreachable CHECKPOINT 1 (GATE IN) / STAGE 2 (DELEGATE) / CHECKPOINT 2 (GATE OUT) /
  CHECKPOINT 3 (COMMIT) sequence; the dispatch block is now the single, unconditional path for
  every batch size. Also dropped the now-meaningless `multi_task_mode` delegation-context field.
  21,607 B -> 15,812 B. `allowed-tools` gained `AskUserQuestion`.
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — new `.decisions.json`
  read path emitting a `## Prior Decisions` section into the dispatch file when a task's
  `.decisions.json` exists and is non-empty; byte-identical output when absent (verified).
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — Group 10:
  three new cases (absent, present-and-empty, present-with-entries) proving the read path.
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — promoted the
  batch/MT design to be simply *the* design; added "Loop-Owned Runtime State" (the full
  `mt_state_file` field reference relocated from the deleted MT-1 prose) and "Consolidated Output
  and Exit-Status Resolution" (relocated from the deleted MT-5 prose) sections; corrected several
  citations left dangling by the deletion, including one factually-wrong claim about where
  `skill_preflight_update()` is called from.
- `agent-system/extensions/core/docs/architecture/handoff-schema.md` — new "Postflight Boundary"
  section (relocated from the deleted single-task MUST NOT section) and new "Decisions File Schema
  (.decisions.json)" section (the schema Phase 2's reader and Move 4's writer both target).
- `agent-system/extensions/core/context/reference/orchestrator-critical-paths.json` — label
  updated to describe the four-move loop; added `orchestrate-build-dispatch.sh` and
  `orchestrate-cycle-postflight.sh` entries alongside the already-present `orchestrate-cycle-plan.sh`.
- Retargeted or retired test/lint files (see Plan Deviations for the two capability-loss
  retirements): `test-loop-guard-budget-override.sh`, `test-routing-resolution.sh`,
  `test-resume-scan-nonconformance.sh`, `test-handoff-reader-parity.sh`,
  `test-session-runtime-files.sh`, `lint-contract-compliance.sh`, `lint-postflight-boundary.sh`
  (plus its new `test-lint-postflight-boundary.sh` Case 4), `agent-system/extensions/core/manifest.json`
  (removed the retired `test-loop-guard-staleness.sh` entry). `test-loop-guard-staleness.sh` itself
  deleted.
- `agent-system/extensions/core/context/guides/hard-mode-routing.md`,
  `context/guides/manifest-routing-schema.md`, `context/patterns/file-footprint-overlap.md`,
  `context/patterns/multi-task-operations.md`, `context/patterns/system-defect-discrimination.md`,
  `context/standards/git-staging-scope.md` — repointed citations that asserted current
  `skill-orchestrate/SKILL.md` structure onto the scripts that now own that behavior.
- `specs/PATH.md` — Progress table and "Chain progress" narrative refreshed: 143/148/88 all
  marked done (8/9 in Stage A), the stale 2026-09-03 snapshot superseded, and the A.4/A.5/A.6
  numbered-work-list rows updated with their measured results.

## Decisions

- Treated the REVISED + ADDENDUM description (engine deletion, four-move loop) as the sole scope,
  per the explicit supersession language in the dispatch and `state.json`'s own recorded title;
  the ORIGINAL mode-gating description was not implemented.
- Deleted Stages 0-8 as one atomic-batch commit (a single contiguous line range computed fresh
  immediately before deletion), rather than the plan's suggested per-stage bottom-up sequence —
  equally safe against line-number drift since the whole range was computed and removed in one
  pass, and simpler to verify.
- Collapsed the former `## MUST NOT (Context Flatness Constraint)` and
  `## MUST NOT (Postflight Boundary)` sections' narrative into pointers at the destination docs,
  but kept both headings (rather than merging into one) after discovering
  `lint-postflight-boundary.sh`'s `has_postflight_boundary_section()` check requires the literal
  `## MUST NOT (Postflight Boundary)` heading text.
- Extended `lint-postflight-boundary.sh`'s postflight-section-location heuristic to match any
  `##`-`####` heading containing "Postflight" (rather than only `### Stage [6-9]|### Stage 1[0-9]`),
  closing the fail-open gap the research report flagged, without hardcoding the loop's own
  "Move 3: Postflight" heading text as a special case.

## Plan Deviations

- **Phase 5, `test-loop-guard-staleness.sh`**: the hard-mode operational-staleness detector it
  tested (max_cycles drift / plan_version drift / mtime-age backstop, archive-aside-never-delete)
  lived exclusively in the deleted single-task Stage 2 and was never ported to the batch engine —
  task 148 explicitly scoped porting it as an out-of-scope, undecided question when it built
  `orchestrate-cycle-plan.sh`. Deleting Stage 2 removes the last reachable code path; there was
  nothing to retarget onto without new script authoring, which this task's Non-Goals put out of
  scope. The test file (and its manifest.json entry) were deleted rather than left broken. This is
  a genuine, pre-existing capability loss for `/orchestrate --hard`, now made permanent by
  deletion — recorded here, not silently dropped. **Recommend a follow-up task decide whether to
  port the detector into `orchestrate-cycle-plan.sh`.**
- **Phase 5, `test-handoff-reader-parity.sh`**: the `.skeleton` (`last_skeleton`)/`.sorry_inventory`
  (`follow_up_tasks`) hard-mode Lean/formal skeleton-plan-completion assertions tested a mechanism
  that lived exclusively in the deleted single-task Stage 4 H1 branch.
  `orchestrate-cycle-plan.sh`'s own H1 port (built before this task) explicitly recorded this
  branch as a known, out-of-scope gap when it ported H1 to the batch engine. This task's deletion
  of Stage 4 removes the last reachable copy. Same class of pre-existing, already-documented gap
  as above, now made permanent by deletion; the assertions were retired with a loud, recorded
  comment rather than silently deleted or left broken.
- **Phase 6**: the sweep for non-test files referencing `skill-orchestrate/SKILL.md` found 24
  files (matching the Scope Hypothesis's "roughly two dozen"), but 16 of those also cite specific
  deleted Stage/MT-stage names, totaling ~139 individual citations — far more than "most are
  expected to be plain path references needing no change." Fixed the 8 files whose citations
  assert current SKILL.md structure a reader would try to locate and fail to find. Left 9 heavier
  files unchanged after verifying "Stage N"/"Stage MT-N" as a historical/conceptual anchor is an
  already-established codebase pattern (the surviving scripts' own header comments use identical
  language, e.g. `orchestrate-build-dispatch.sh`'s "Stage 3.5 (Dispatch Prep)",
  `orchestrate-cycle-postflight.sh`'s own 6 remaining Stage references). A full mechanical rename
  of the ~120 remaining citations (`batch-orchestration-guardrails.md` alone carries 34) was
  judged disproportionate to this task's core scope. **Recommend a follow-up doc-sweep task.**
- **Phase 7**: `commands/orchestrate.md` still had a pre-rewrite `len(TASK_NUMBERS) == 1` branch
  falling through to the now-deleted single-task CHECKPOINT 1-3 sequence for the DEFAULT
  invocation shape (a bare `/orchestrate N` with no `ORCHESTRATE_BATCH_OF_ONE` set) — outside this
  task's originally-scoped Files to modify list, but a direct, load-bearing consequence of
  deleting the single-task engine. Fixed as part of Phase 7's own acceptance verification, which
  is exactly what surfaced it.
- **Phase 7**: the "live 5-task batch" and "live `AskUserQuestion` round-trip" acceptance
  demonstrations were performed via isolated, throwaway fixture repos exercising the real scripts,
  not a genuinely live `/orchestrate` invocation against real tasks in this repo. A genuinely live
  run would dispatch real Agent-tool calls against unrelated real tasks and mutate their real
  state — outside an implementation agent's own delegated scope. See Verification below for what
  each demonstration actually proved.

## Verification

- **Build**: N/A (no compiled artifact)
- **Tests**: `scripts/tests/run-all.sh` 73/73 passed (all extensions, both `scripts/tests/*.sh` and
  flat `scripts/test-*.sh` locations)
- **Full gate**: `verify-deploy.sh` 30/30 checks passed (`PASS -- 30 check(s), 0 failure(s)`);
  `deploy-headless.sh RESULT=landed_verify_clean`; `check-task-references.sh` clean (0 unexempted
  occurrences across 4 scanned trees)
- **Byte measurements**:
  | File | Before | After | Target |
  |---|---|---|---|
  | `skills/skill-orchestrate/SKILL.md` | 189,000 B | 15,666 B | `<= 20,000 B` ✓ |
  | Combined `## MUST NOT` sections | ~3,268 B (est.) | 1,369 B | `<= ~1,500 B` ✓ |
  | `commands/orchestrate.md` (bonus, Phase 7 fix) | 21,607 B | 15,812 B | — |
- **Context-growth measurement** (isolated fixture, 5 synthetic tasks spanning research/plan/
  implement/already-in-flight): Move 1 JSON 640 B (dry-run) / 818 B (live); combined with real
  Move 2 pointer-prompt/context shapes and Move 3's postflight-JSON contract, ~728 B/task/cycle —
  under the ~1 KB/task/cycle target.
- **Batch-of-one structural proof** (isolated fixture, 1 synthetic task): identical
  `{dispatch, aux_dispatch, deferred, blocked, stop}` JSON shape as the 5-task batch, one row —
  proving batch-of-one is the same code path, not a special case.
- **`.decisions.json` round trip**: `test-orchestrate-build-dispatch.sh` Group 10 (3/3 cases)
  proves a real `.decisions.json` entry produces a byte-faithful `## Prior Decisions` section in
  the next dispatch file.
- Files verified: Yes (all edited files re-read/re-tested after editing)

## Impacts

- Every `/orchestrate` invocation, single-task or multi-task, now runs through one engine — the
  four-move loop — eliminating the parity-drift defect class the dual-engine design was
  accumulating (per `specs/PATH.md`'s own decision record).
- ~70k tokens/invocation saved for what was previously the single-task hot path (per PATH.md's
  own estimate, now realized).
- The `AskUserQuestion`/`.decisions.json` mechanism is new infrastructure with no precedent in this
  codebase's autonomous multi-cycle loops; its mechanical correctness is proven, but its first live
  use (a real question surfaced and answered mid-batch) has not yet happened.
- Two hard-mode capabilities (the loop-guard operational-staleness detector; Lean/formal
  skeleton-plan completion routing) have no batch-engine equivalent as of this task — pre-existing
  gaps, now permanent rather than latent, and recorded as follow-ups.
- ~120 historical "Stage N"/"Stage MT-N" citations remain across 9 `context/`/`docs/` files,
  consistent with an already-established codebase terminology pattern but not mechanically
  updated to the "Move N" vocabulary — recorded as a follow-up doc sweep.

## Follow-ups

- Decide whether to port the hard-mode loop-guard operational-staleness detector into
  `orchestrate-cycle-plan.sh` (currently no batch-engine equivalent; was already an "undecided
  question" per task 148, now made permanent by this task's deletion of its only host).
- Decide whether to port Lean/formal skeleton-plan completion routing (pr_ready postflight,
  completion-summary propagation, `.dispatch/`/loop-guard cleanup) into `orchestrate-cycle-plan.sh`'s
  H1 section (same class of pre-existing gap as above).
- A follow-up doc-sweep task to mechanically retarget the ~120 remaining historical "Stage N"/
  "Stage MT-N" citations across `context/patterns/batch-orchestration-guardrails.md` (34 alone),
  `docs/architecture/handoff-schema.md`, `docs/architecture/orchestrate-cycle-postflight.md`,
  `docs/architecture/batch-admit-schema.md`, `context/patterns/orchestrate-batch-results-template.md`,
  `context/patterns/regeneration-is-manual-only.md`, `context/patterns/task-lock.md`,
  `context/standards/orchestrator-runtime-files.md`, and `docs/examples/research-flow-example.md`
  onto the "Move N" vocabulary — not urgent (verified non-misleading), but would complete the
  terminology migration this task started.
- The orchestrator/user should run a genuinely live `/orchestrate` batch (ideally including a
  task whose research/plan/implement agent surfaces a real `user_decision`) as the natural
  next-step live confirmation of the mechanical proofs this task's acceptance verification
  already established.
- Tasks 142 (orchestrator context budget: measure and lock) and 150 (research on demand) are now
  the only two tasks remaining in `specs/PATH.md`'s Stage A ("the thin lead").

## References

- `specs/088_mode_gate_skill_orchestrate_multi_task_section/plans/01_four-move-loop-rewrite.md`
- `specs/088_mode_gate_skill_orchestrate_multi_task_section/reports/01_delete-single-task-engine.md`
- `specs/088_mode_gate_skill_orchestrate_multi_task_section/progress/phase-{1..7}-progress.json`
- `specs/PATH.md` ("Target design: the thin lead")
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md`
- `agent-system/extensions/core/docs/architecture/handoff-schema.md`
