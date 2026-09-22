# Implementation Summary: Task #242

- **Task**: 242 - orchestrate partial-with-blocker stops redispatch
- **Status**: [COMPLETED]
- **Started**: 2026-09-22
- **Completed**: 2026-09-22
- **Effort**: ~4.5 hours
- **Dependencies**: None
- **Artifacts**: plans/01_partial-blocker-stops-redispatch.md, summaries/01_partial-blocker-stops-redispatch-summary.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

An implementer that returned `.orchestrator-handoff.json` with `status: "partial"` and a
populated `blockers[]` entry was re-dispatched to `implement` every cycle until the run's budget
ran out, because `orchestrate-cycle-postflight.sh` never wrote state.json's `status` field for a
`partial` outcome. This left `orchestrate-triage-classify.sh`'s already-written
`partial + blockers, no continuation -> needs_human` row unreachable dead code. All five plan
phases are complete: the status write now fires (gated on a non-empty handoff `blockers[]`), the
blocker-research aux signal was widened to cover this case, the `blocked` vs. `partial`-with-
`blockers` decision rule is now documented in the shared H9 handoff contract, and both the
postflight-level and end-to-end no-redispatch behaviors are pinned by new regression tests.

## What Changed

- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh` — split the former
  `partial|failed|blocked)` case arm into a dedicated `partial)` arm (computes the handoff
  blocker count via jq with the same non-numeric guard `orchestrate-triage-classify.sh` uses;
  calls `skill_postflight_update` when the count is >0, leaves today's no-op behavior unchanged
  when it is 0) and a residual `failed|blocked)` arm (byte-identical body). Widened the
  `blocker-research` aux-signal gate (previously `verdict = "blocked"` only) to also admit a
  base-mode `partial` outcome with a non-empty `blockers[]`, deriving `blocker_desc` from the
  handoff's `blockers[0].target`/`why_it_failed` rather than the never-written
  `.active_projects[].blockers` state.json string. Both cross-referenced with
  `orchestrate-triage-classify.sh`'s table row via paired comments.
- `agent-system/extensions/core/scripts/skill-base.sh` — added a `partial)` case arm to
  `skill_postflight_update`, calling `update-task-status.sh postflight <N> partial <session>`.
  This file was not in the plan's original Phase 1 file list; it was a required deviation
  (documented below) because `skill_postflight_update`'s own status switch previously had no
  case for `"partial"` and silently skipped the write.
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh` — comment-only:
  reciprocal cross-reference on the `partial + blockers, no continuation` table row.
- `agent-system/extensions/core/context/contracts/wrap-up.md` — new
  "`blocked` vs. `partial`-with-`blockers`" subsection stating the decision rule and noting that
  a blocker-bearing `partial` now stops same-run redispatch and raises the aux signal.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — one-line pointer from
  the `.orchestrator-handoff.json` section to the new wrap-up.md subsection.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` — three new
  regression fixtures (candidates #830/#831/#832): partial+blockers writes status=partial and
  records a handoff-derived blocker-research aux signal; partial+empty-blockers leaves status
  unchanged and records no aux signal; partial+blockers+user_decision exercises both the status
  write and the ask_user verdict relay together.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh` — new Group 26
  (candidates #2701/#2702): an end-to-end demonstration that a task already at
  `status: "partial"` with a populated handoff `blockers[]` lands in `blocked[]` (visible,
  `needs_human`), never `dispatch[]`/`deferred[]`; companion negative case confirms an
  empty-blockers partial still dispatches to `implement`.

## Decisions

- Adopted the plan's **blockers-gated** status write (not the research report's originally
  recommended unconditional form) — confirmed correct per the plan's own evidence
  (`orchestrate-batch-admit.sh`'s `is_in_flight` predicate and `git-snapshot.sh`'s no-argument
  task inference both key off `status == "implementing"` and would have silently broken for
  ordinary in-progress partials under the unconditional form).
- Rejected `status = "blocked"` as the target status, per the research report: a task with empty
  `dependencies[]` routes to the silent `skip` bucket in the multi-task engine, which is worse
  than the original defect.
- Scoped the widened blocker-research aux gate to base mode only (`hard_mode != true`) — a
  deviation from the plan's literal task text, discovered when the existing hard-mode churn test
  suite failed after an unconditional widening. Hard mode already has its own escalation for a
  recurring blocker-bearing partial (the WORK (k) churn/divergence-audit three-strikes
  mechanism), which consumes the identical `dispatch_status=partial + blockers[]` shape; an
  unconditional widening fought that mechanism for the single-slot `aux_pending` write on every
  hard-mode cycle.

## Plan Deviations

- **Phase 1** (task 1.2 in the plan's own numbering): widened scope to
  `agent-system/extensions/core/scripts/skill-base.sh`, not listed in the plan's Phase 1 file
  list. `skill_postflight_update`'s own case switch had no `partial)` arm, so the Phase 1 call
  site (`skill_postflight_update ... "$dispatch_status" ...` with `dispatch_status="partial"`)
  was a silent no-op without it. Added a `partial)` arm mirroring the existing `needs_research)`
  arm's shape, calling `update-task-status.sh postflight <N> partial <session>` with the literal
  `"partial"` target-status token.
- **Phase 2** (task 2.2): gated the widened blocker-research admission on `hard_mode != true`
  (base-mode only), not stated explicitly in the plan's task text. Required to avoid the widened
  gate overwriting the existing hard-mode churn/divergence-audit aux signal for the identical
  `partial`+`blockers[]` shape; confirmed by the existing test suite failing 5/87 without the
  guard and passing 87/87 with it.
- No other deviations. Phases 3, 4, and 5 followed the plan as written.

## Verification

- Build: N/A (shell scripts and markdown)
- Tests: Passed — `test-orchestrate-cycle-postflight.sh` 99/99 (87 baseline + 12 new),
  `test-orchestrate-cycle-plan.sh` 243/243 (238 baseline + 5 new),
  `test-orchestrate-triage-classify.sh` 57/57 (unchanged, comment-only edit)
- Files verified: Yes — `bash -n` clean on all five edited shell scripts;
  `check-task-references.sh` reports 0 unexempted occurrences in every touched subtree; all
  edits confirmed under `agent-system/extensions/core/**`, none under `.claude/**`
- Load-bearing check: reverted `orchestrate-cycle-postflight.sh` to its pre-Phase-1 content and
  re-ran the postflight suite — the three new blocker-bearing fixtures (830/832) failed as
  expected (5 assertions), confirming the tests are load-bearing rather than vacuous; restored
  the fix and confirmed 99/99 again

## Impacts

- A blocker-bearing `partial` dispatch outcome (e.g. an external release-asset unavailability)
  now stops same-run redispatch for the affected task, visibly, instead of being retried every
  cycle until the run's budget is exhausted.
- The operator now also gets a `blocker-research` aux-dispatch signal for this case in base mode,
  with a description derived from the handoff rather than degrading to "Unspecified blocker".
- Implementer agents now have an explicit, single-source decision rule for `blocked` vs.
  `partial`-with-`blockers`, referenced from `general-implementation-agent.md` and (by existing
  pointer, unchanged) from roughly 60 other implementer/research agent files across every
  extension.

## Follow-ups

- None required by this task's scope. The research report flagged the single-task engine's
  Stage 4 handoff triage in `skills/skill-orchestrate/SKILL.md` as a related but explicitly
  out-of-scope follow-up concern (it does not currently reach
  `orchestrate-triage-classify.sh --engine single` in the live code path).

## References

- `specs/242_orchestrate_partial_with_blocker_stops_redispatch/reports/01_orchestrate_partial_blocker_stops_redispatch.md`
- `specs/242_orchestrate_partial_with_blocker_stops_redispatch/plans/01_partial-blocker-stops-redispatch.md`
- `agent-system/extensions/core/scripts/orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/scripts/orchestrate-triage-classify.sh`
- `agent-system/extensions/core/scripts/skill-base.sh`
- `agent-system/extensions/core/context/contracts/wrap-up.md`
- `agent-system/extensions/core/agents/general-implementation-agent.md`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
- `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-plan.sh`
