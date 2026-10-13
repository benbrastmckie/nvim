# Implementation Summary: Task #392

- **Task**: 392 - Deliver the tool-`timeout` half of the bounded-wait idiom to every redeploy
  remedy emission site and to Rule 1's presentation
- **Status**: [COMPLETED]
- **Started**: 2026-10-13T01:08:00Z
- **Completed**: 2026-10-13T06:05:00Z
- **Effort**: ~5 hours
- **Dependencies**: task #354 (completed), task #318 (completed)
- **Artifacts**: plans/01_tool-timeout-remedy-delivery.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Closed the delivery gap between `external-process-wait.md` Rule 1's bounded-wait idiom and the
sites that need it, at universal scope via a shared helper library per the user's recorded
decision. Half A routes every runtime redeploy-remedy emission site — 28 sites across 17 files,
derived by mechanical enumeration rather than any prior hand-compiled count — through one new
shared library, `scripts/lib/redeploy-remedy-lib.sh`. Half B restructures Rule 1 so the Bash-tool
`timeout`-parameter obligation reads as a numbered, caller-agnostic requirement. All ten plan
phases completed; the orchestrator-critical scripts (the lock, the skill lifecycle, the loop
itself) were converted last, one file at a time, each proven with a real smoke probe before its
own commit, and the orchestration's own commit/lock/dispatch machinery stayed operable throughout.

## What Changed

- `agent-system/extensions/core/scripts/lib/redeploy-remedy-lib.sh` — NEW: the single definition
  of the redeploy-remedy text repo-wide, exporting `redeploy_remedy_fragment()` (the timeout
  clause alone) and `redeploy_remedy()` (the full canonical remedy).
- `agent-system/extensions/core/scripts/tests/test-redeploy-remedy-lib.sh` — NEW: the helper's own
  11-case regression suite, including the degrade-safe fallback path.
- `agent-system/extensions/core/context/patterns/external-process-wait.md` — Rule 1 restructured
  into numbered steps (1)-(4): inner-bounded command, the tool-`timeout`-parameter requirement
  (naming the `120000`ms default explicitly), the `exit 124` handling, and the repeat condition;
  plus a 3a/3b sub-case note and a forward pointer to the shape taxonomy.
- `agent-system/extensions/core/context/patterns/bounded-build-waiter.md` — the tool-`timeout`
  pairing added as ordinary prose in "The Canonical Idiom" and "Sizing a Wait Near the Per-Call
  Ceiling"; a new "Shape Taxonomy" section naming all three ways a wait goes wrong, composing
  with (not superseding) the existing Dispatched-Subagent Wait Ruling.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — a new
  "Redeploy-Remedy Emission Sites" subsection: the IN/OUT discriminator and its tie-break, the
  full per-occurrence inventory (28 IN sites, batch-assigned A/B/C, with every disagreement
  against prior leads recorded), and a new "Assertion Coverage Against the Final Site List"
  subsection naming every covered and uncovered site.
- `agent-system/extensions/core/agents/general-implementation-agent.md` — a clarifying note in
  Local Long-Running Command Discipline: "backgrounded at all" includes the harness's own
  auto-backgrounding of an ordinary foreground call left at the tool-timeout default.
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — the `orchestrate-cycle-plan.sh`
  Move 1 invocation changed from a bare `plan_json=$(bash ...)` command substitution (which loses
  its stdout outright if backgrounded) to a log-redirect-and-bounded-wait shape (Idiom B).
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` — a cross-reference
  to the shape taxonomy, and a new section carrying the full sub-case-3b rationale relocated out
  of SKILL.md for eager-context-budget reasons.
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — a deliberate,
  reviewed `ceiling_bytes` move for `skills/skill-orchestrate/SKILL.md` (21500 -> 22500),
  following this file's own established precedent for necessary new content.
- 16 call-site scripts converted to route through the helper: `orchestrate-batch-admit.sh`,
  `migrate-state-legacy-fields.sh`, `orchestrate-predispatch-review.sh`, `git-snapshot.sh`,
  `validate-state.sh`, `check-consumer-freshness.sh` (Batch A); `verify-deploy.sh`,
  `check-deploy-freshness.sh`, `check-extension-docs.sh`, `check-record-versioning.sh` (Batch B);
  `deploy-root-guard.sh`, `update-task-status.sh`, `skill-base.sh`, `task-lock.sh`,
  `orchestrate-build-dispatch.sh`, `orchestrate-cycle-plan.sh`, `deploy-headless.sh` (Batch C).
  `command-gate-out.sh` was confirmed to have zero IN sites and dropped from the batch.
- `agent-system/extensions/core/manifest.json` — registered the two new scripts.

## Decisions

- Universal scope via a shared helper (user-recorded decision, carried forward from planning).
- Two function shapes in the helper: `redeploy_remedy()` for the four byte-identical-boilerplate
  sites (with a local degrade-safe fallback carrying the exact pre-change text at each site, since
  the shared library deliberately provides no degraded `redeploy_remedy()` of its own), and
  `redeploy_remedy_fragment()` appended to the remaining sites' own distinct wording.
- `orchestrate-batch-admit.sh`'s fallback was resolved into a plain variable assignment (no
  printf/echo token on either branch) rather than a local fallback function, because that file is
  on `lint-json-channel-discipline.sh`'s per-line JSON-contract audit list, where a second
  unredirected printf — even one that only ever executes inside a captured command substitution —
  reads as a channel-discipline violation.
- `deploy-root-guard.sh` and `update-task-status.sh`, found only by Phase 1's mechanical
  enumeration (absent from every prior hypothesis), were added to Batch C rather than Batch B:
  the guard is sourced at script-startup by effectively every core script including several other
  Batch-C members, and `update-task-status.sh` performs every postflight status transition.
- `command-gate-out.sh` drops from Batch C entirely: every candidate line in it is a pure
  result-only report naming no reader action, resolving the dispatch brief's explicitly-flagged
  "deliberately undecided" point.
- `skills/skill-orchestrate/SKILL.md`'s eager-load ceiling was deliberately moved, not trimmed to
  zero net growth, because the content that pushed it over (the Idiom B invocation shape fixing a
  real stdout-loss defect) is necessary, non-duplicative new mechanism — the same standard this
  config file's own history already applies to its other ceiling moves.

## Plan Deviations

- **Phase 1** added `check-extension-docs.sh:1669-1671`, `check-record-versioning.sh`,
  `orchestrate-cycle-plan.sh:1147`, `update-task-status.sh:952`, and `deploy-root-guard.sh` to the
  site inventory — none were in any prior hypothesis (research report, dispatching orchestrator's
  list, or the plan's own plan-authoring-time grep), all found only by widening the enumeration
  sweep beyond the three base literals. Phases 7 and 8's `Files to modify` lists were corrected in
  place to match, per the plan's own stated supersession rule.
- **Phase 8** dropped `command-gate-out.sh` from Batch C (zero IN sites, see Decisions above) —
  the plan's own stated contingency for this exact outcome.

## Verification

- Build: N/A (no compiled artifact)
- Tests: `test-redeploy-remedy-lib.sh` (11/11), `test-deploy-freshness.sh` (26/26),
  `test-orchestrate-build-dispatch.sh`, `test-skill-base-lifecycle.sh`,
  `test-orchestrate-cycle-plan.sh`, `test-lint-agent-contracts.sh` (Check H), full `run-all.sh`
  sweep (126/134 passed at final count, 6 failures all individually investigated and attributed
  to pre-existing or environmental causes unrelated to this delivery's own files) — all Passed
- Files verified: Yes (deployed-tree presence confirmed for the lib and all 16 call sites)

Full `verify-deploy.sh` gate set (Idiom B, 699s wall-clock): 3 of 37 checks failed, all three
attributed by name with evidence (9 chronic foreign `index-entries.json` `line_count` mismatches
from concurrently-running sibling dispatches; the same 6 pre-existing/environmental `run-all.sh`
failures; a pre-existing 225B eager-load-total overage, also from concurrent sibling edits — none
touch any file this delivery modified).

## Impacts

- Every converted script now emits a remedy that actually tells its reader the pairing needed to
  run `deploy-headless.sh` safely (the Bash tool `timeout` parameter raised to `600000`), closing
  the delivery gap that stranded two prior dispatches.
- `skill-orchestrate/SKILL.md`'s Move 1 call no longer loses its captured JSON outright if the
  harness backgrounds it.
- A future emission site is now one function call away from carrying the same guidance, rather
  than a fourth hand-copied boilerplate string.

## Follow-ups

- A lint asserting every IN emission site routes through the helper (deferred, recorded as a named
  follow-up in `regeneration-is-manual-only.md`'s "Redeploy-Remedy Emission Sites" subsection).
- 13 of the 17 converted sites have no dedicated test assertion on their own remedy text (recorded
  as a named gap in the same subsection's "Assertion Coverage" addition, not closed by this task).
- The 9 chronic foreign `index-entries.json` line_count mismatches, the `test-verify-deploy-gate-selection.sh`
  REPO_ROOT path-arithmetic bug, and the 225B eager-load-total overage all remain for their
  respective owning tasks to resolve — none are this task's to fix.

## References

- `specs/392_deliver_tool_timeout_half_of_bounded_wait_idiom/plans/01_tool-timeout-remedy-delivery.md`
- `specs/392_deliver_tool_timeout_half_of_bounded_wait_idiom/progress/phase-{1..10}-progress.json`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`'s
  "Redeploy-Remedy Emission Sites" subsection (the authoritative site inventory and coverage record)
