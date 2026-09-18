# Implementation Summary: Task #200

- **Task**: 200 - Close the consumer-repo deploy propagation gap that leaves fixed defects live in deployed trees
- **Status**: [COMPLETED]
- **Started**: 2026-09-18T07:13:52Z
- **Completed**: 2026-09-18T10:55:00Z
- **Effort**: ~4 hours
- **Dependencies**: None
- **Artifacts**: plans/01_per-dispatch-freshness-surface.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Research established that the consumer-deploy-propagation gap was not a missing detector: a
pull-side, per-extension, path-scoped freshness comparison (`check-deploy-freshness.sh` +
`scripts/lib/deploy-freshness-lib.sh`) already existed and already fired non-blockingly from
`command-gate-in.sh`. The gap was granularity and placement — that check ran once per top-level
command, onto the orchestrating session's own stderr, never reaching the context of a spawned
agent that actually reads a stale deployed file. This implementation closes that gap by re-firing
the same unchanged comparison once per skill/agent dispatch (`skill_preflight_update` in
`core/scripts/skill-base.sh`) and injecting the result into the generated dispatch file
(`orchestrate-build-dispatch.sh`'s `<deploy-freshness-context>` block), following the existing
optional-block precedent used for `<memory-context>` and `<literature-briefing>`. No new
comparison algorithm or fingerprint scheme was added, and nothing was added to any blocking gate
path.

## What Changed

- `agent-system/extensions/core/scripts/skill-base.sh` — sources `deploy-freshness-lib.sh` via
  the existing two-candidate resolution order; adds `skill_deploy_freshness_stale_names`, a
  thin, always-safe wrapper; calls it unconditionally inside `skill_preflight_update` and emits a
  named, loud WARN block to stderr when the result is non-empty. Every failure mode (missing
  library, missing `jq`/`git`, absent/unparseable `.claude-extensions.json`) degrades to silence;
  `skill_preflight_update` always still returns 0 and still runs its extension hook and lifecycle
  event. Never touches `specs/.freshness-warn-streak.json`. Stays Class C (no `set` line added).
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — new Stage 3.5 output
  reusing the same helper; emits a `<deploy-freshness-context>` block into the generated dispatch
  file when the stale-extension list is non-empty, alongside the existing optional blocks. A
  build with nothing stale is byte-identical to a pre-change build.
- `agent-system/extensions/core/scripts/tests/test-deploy-freshness.sh` — new partial-staleness
  fixture: a two-file extension with only one file changed (reads `STALE`) alongside a second,
  wholly-untouched extension in the same consumer tree (reads `FRESH`), reproducing the observed
  incident shape directly and pinning that the existing per-extension comparison already catches
  it.
- `agent-system/extensions/core/scripts/tests/test-skill-base-lifecycle.sh` — new Group 4b: WARN
  emission on a stale fixture (with parity checks that the status write and the trailing
  lifecycle-event call still run), silence on a fixture with no `.claude-extensions.json`, and a
  no-abort case for a missing library, all under `set -e`. Also asserts the streak-counter file
  is never written by this surface.
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` — new Group 12:
  `<deploy-freshness-context>` present and correctly worded for a stale fixture, absent for a
  clean one, and the two builds differ by exactly the injected block.
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` — new "Tier 1,
  refined" subsection documenting the per-dispatch surface, the dispatch-brief injection as an
  orchestrate-mode-only enhancement layered on top, the partial-staleness trap, and three
  explicitly rejected alternatives (a new whole-tree fingerprint, hard-blocking on `STALE`,
  restoring the fleet walk to a blocking path).
- `specs/200_consumer_deploy_propagation_gap/measurements.md` — cost baseline (Phase 1: lean
  call-site confirmation, single-invocation timing, extension/consumer counts) and per-dispatch
  cost measurement (Phase 6: ~106ms added per dispatch, session-level totals of 0.32-1.38s,
  contrasted against the ~10-minute fleet walk).

## Decisions

- Placed the per-dispatch surface at `skill_preflight_update` (confirmed as the single
  per-dispatch call site reached by both orchestrate's live-dispatch loop and every
  direct/non-orchestrate skill call site), not at a second new entry point.
- Rejected a new whole-tree content-hash/fingerprint mechanism: the existing per-extension,
  path-scoped comparison already catches partial staleness, pinned directly by a fixture rather
  than argued.
- Rejected hard-blocking a dispatch on `STALE`: would recreate the same
  cost/unactionability class of problem the fleet-walk removal solved.
- Kept the dispatch-brief injection as an orchestrate-mode-only enhancement layered on the
  per-dispatch base layer, not a replacement — a directly-invoked skill run still gets the
  stderr WARN but not the injected block, and this asymmetry is documented explicitly.
- Redeployed both this repo and `~/Projects/BimodalLogic` mid-implementation (after the Phase 3-4
  source-store edits) rather than only at the end, so the deployed-tree-first-resolution
  regression suites (Phase 5) exercised the real new code instead of a stale copy — this was
  necessary because the suites resolve their subject-under-test from the deployed tree first,
  by design.

## Plan Deviations

- None (implementation followed plan). Three implementation-detail corrections surfaced and were
  resolved during Phase 5 test authoring (documented in that phase's progress file
  `approaches_tried`): an `SKILL_REPO_ROOT` override omission that caused early test runs to
  accidentally check the real repo instead of the fixture, a one-time-per-process stderr-warning
  assumption that needed a different observable proxy, and a reused dispatch-file path across two
  fixture runs in the same test group. None of these changed the plan's scope or files-to-modify
  list.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests: Passed — `test-deploy-freshness.sh` 26/26, `test-skill-base-lifecycle.sh` 35/35,
  `test-orchestrate-build-dispatch.sh` 79/79, full `run-all.sh` 84/84 (0 failed, 0 skipped;
  strictly better than the Phase 3 mid-implementation baseline of 83/1, whose one pre-existing
  failure was unrelated to this task and did not reproduce in the final run)
- Files verified: Yes — all touched files diffed byte-for-byte between source store and deployed
  tree in both this repo and `~/Projects/BimodalLogic` after redeploy

## Impacts

- Any consuming repo's deployed `.claude/` tree is now checked for staleness once per
  skill/agent dispatch, not only once per top-level command, and the result reaches the spawned
  agent's own dispatch-file context when driven via `/orchestrate`.
- No change to any blocking gate path; the opt-in fleet-wide `--consumer-report` walk is
  untouched.
- The four previously-cited lean call sites in `~/Projects/BimodalLogic` are now confirmed
  byte-identical to source (they already were, independently, before this task started — this
  work re-confirms rather than re-fixes them).

## Follow-ups

- The pre-existing `commands/orchestrate.md` context-budget-ceiling WARN (observed during both
  redeploys in this session) is unrelated to this task's scope and was left untouched.
- If the per-dispatch WARN proves insufficiently actionable over time, the existing tier-1
  consecutive-ignore streak escalation remains the documented model for a louder default; no
  second escalation mechanism was introduced here.

## References

- `specs/200_consumer_deploy_propagation_gap/reports/01_consumer-deploy-propagation-gap.md`
- `specs/200_consumer_deploy_propagation_gap/plans/01_per-dispatch-freshness-surface.md`
- `specs/200_consumer_deploy_propagation_gap/measurements.md`
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md`
