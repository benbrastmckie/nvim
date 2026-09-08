# Implementation Summary: Task #189

- **Task**: 189 - Fix three channel-confusion defects in the orchestrate cycle-plan pipeline
- **Status**: [COMPLETED]
- **Started**: 2026-09-08T04:20:00Z
- **Completed**: 2026-09-08T18:58:00Z
- **Effort**: ~10 hours across multiple dispatch cycles
- **Dependencies**: 150 (research-on-demand rewrite; landed and deployed first)
- **Artifacts**: plans/01_fix-channel-confusion-orchestrate.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Fixed three independently-reproduced channel-confusion defects in the `/orchestrate` cycle-plan
pipeline, all one bug class expressed three ways: (a) stdout carrying both prose logs and JSON
data, made structurally impossible via an entry-point `exec 3>&1 1>&2` redirect with the plan
JSON emitted to fd 3; (b) the per-task cycle budget being charged for a plan composition nothing
ever dispatched, fixed with an in-session plan cache (Phase 5) and a durable cross-invocation
`pending_dispatch` ledger (Phase 6); (c) `orchestrate-predispatch-review.sh` printing a false
"0 findings" negative for Classes C and D when the underlying verdict actually carried
`self_modifying: true` / `idle_overlap_advisory: true`, fixed by rendering admitted-with-hazard
verdicts as their own row and stating precisely what was filtered. This final cycle closed Phase
7: the maintained lint for the channel-discipline class, plus the end-to-end acceptance re-check.

## What Changed

- `agent-system/extensions/core/scripts/lint/lint-json-channel-discipline.sh` — new maintained
  lint detecting the class in both directions (INGEST: a `2>&1` capture consumed via `jq` pipe,
  `jq` here-string, or `while read` NDJSON loop; EMIT: an unredirected write outside a `$(...)`
  capture or fd-3 emit), with a named, commented allowlist entry for `verify-deploy.sh`'s
  `doc_lint_output` (intentional human-readable-text merge, not JSON — documented, not a bug).
  Deliberately NOT wired into `verify-deploy.sh` (that file's owner is a separate,
  cross-referenced task); it already runs inside the full gate set via `run-all.sh`'s Gate 8
  through its own test suite, and the numbered-gate wiring is recorded as a follow-up.
- `agent-system/extensions/core/scripts/tests/test-lint-json-channel-discipline.sh` — new fixture
  suite: three known-bad INGEST samples (jq pipe, jq here-string, while-read NDJSON) plus their
  negative controls, a known-bad EMIT sample (structural and per-line) plus its negative controls,
  and a real-corpus clean check exercising the documented allowlist entry. 11 passed, 0 failed.
- `specs/189_fix_channel_confusion_orchestrate_pipeline/plans/01_fix-channel-confusion-orchestrate.md`
  — Phase 7 checklist items checked off with completion/deviation annotations, phase heading
  closed to `[COMPLETED]`, and the plan's Testing & Validation checklist updated with actual
  suite results.
- `specs/189_fix_channel_confusion_orchestrate_pipeline/progress/phase-7-progress.json` — all
  seven objectives marked done with evidence notes and a recorded deviation for the withheld
  full-repo gate sweep.

Phases 1-6 (items (a)-(c), the structural fd-3 redirect, the ingest-direction
`run_capture_stdout` fix, the SKILL.md/`orchestrate.md` consumer-contract reconciliation, the
Class C/D false-negative fix, and both no-charge-for-a-read mechanisms) were implemented and
committed in earlier cycles of this task; this cycle's own changes are scoped to closing Phase 7.

## Decisions

- Phase 7's full `run-all.sh` gate sweep was withheld this cycle on explicit prior-cycle user
  direction: two consecutive sweeps wedged on `test-verify-deploy-context-budget.sh` (>6 min
  each, no completion) on a host already 16 GB into swap. Verified instead with every suite
  directly affected by this task, run individually and green (243 passed, 0 failed total:
  `test-orchestrate-cycle-plan.sh` 147, `test-orchestrate-cycle-postflight.sh` 65,
  `test-orchestrate-predispatch-review.sh` 14, `test-loop-guard-budget-override.sh` 8,
  `test-lint-json-channel-discipline.sh` 11).
- Re-ran the SKILL.md Move 1 snippet and `commands/orchestrate.md`'s `--dry-run` invocation
  (including its documented empty-`--session` fallback) directly against the source-store
  scripts, in a synthetic deployed-shaped tree built the same way the test harness's own sandbox
  is built (copy the collaborator scripts into a `$WORKDIR/.claude/scripts/` tree so
  `deploy-root-guard.sh`'s parent-directory check passes) — this avoided running a full
  `deploy-headless.sh` against the live `.claude/` tree (which is currently stale relative to
  the source store and out of scope for this task to sync) while still exercising the real,
  unmodified script logic end to end. Both invocations succeed: `jq -c '.stop'` parses
  `plan_json` with no preamble stripping, and the dry-run table lands entirely on stderr.
- The two untracked Phase 7 deliverables (lint script + its test suite), which already existed
  on disk and passed their 11 tests from a prior cycle, were committed directly in this cycle per
  the settled prior decision (re-dispatch a fresh implementation cycle rather than having the
  orchestrator commit them out-of-band) rather than re-derived from scratch.

## Plan Deviations

- **Phase 7's `run-all.sh` full-gate-sweep task** altered: ran the five directly-affected suites
  individually instead of the whole-repo sweep, per the explicit prior-cycle decision to avoid
  the `test-verify-deploy-context-budget.sh` wedge under host memory pressure. Recorded as a
  follow-up for a future cycle once that wedge (tracked separately by the redeploy-checkpoint-cost
  work) and host memory pressure are addressed.

## Verification

- Build: N/A (bash scripts, no build step)
- Tests: Passed — 243 passed, 0 failed across the five suites directly affected by this task's
  changes (whole-repo `run-all.sh` sweep withheld this cycle, see Plan Deviations)
- Files verified: Yes — both new Phase 7 files exist, are executable, and pass their fixture
  suite; `git status`/`git diff` confirm the final diff touches none of the forbidden paths
  (`verify-deploy.sh`, `deploy-headless.sh`, the redeploy-checkpoint block, Class A, or
  `orchestrate-batch-admit.sh`'s verdict logic)

## Impacts

- `/orchestrate` (and any external caller) can now capture `orchestrate-cycle-plan.sh`'s stdout
  and parse it directly as JSON with no preamble-stripping workaround, matching what SKILL.md has
  documented as the contract all along.
- A parse failure or other no-dispatch composition no longer silently burns a cycle from the
  per-task budget; only a composition that actually results in a dispatch (or aux-dispatch) costs
  one.
- A solo `self_modifying: true` candidate's pre-dispatch report now surfaces the hazard instead of
  reading as "0 findings", restoring the one signal that would have predicted the redeploy-gate
  outcome in the run that originally surfaced this defect class.
- The channel-confusion defect class (capture-with-`2>&1`-then-parse-as-JSON, and
  unredirected-write-into-a-JSON-channel) now has a maintained, tested lint guarding against
  regression, discoverable alongside the nine existing `scripts/lint/lint-*.sh` siblings.

## Follow-ups

- Wire `lint-json-channel-discipline.sh` into `verify-deploy.sh` as a numbered gate — deliberately
  not done here since `verify-deploy.sh` is owned by the cross-referenced redeploy-checkpoint
  task; the lint already runs via `run-all.sh`'s Gate 8 through its own test suite in the interim.
- Run a full `run-all.sh` whole-repo gate sweep once the `test-verify-deploy-context-budget.sh`
  wedge and host memory pressure are resolved (likely downstream of the redeploy-checkpoint-cost
  work tracked separately) — this cycle verified only the five suites directly affected by this
  task's own changes.
- The plan's original "Files to modify" list named
  `context/architecture/orchestrate-state-machine.md` as a possible doc-update target for the
  fd-3 emit contract; the actual doc landings during Phases 1-6 were the affected scripts' own
  header comments plus `context/standards/orchestrator-runtime-files.md` for the `pending_dispatch`
  ledger and in-session `plan_cache` schemas — a deliberate, already-recorded deviation from Phase
  6, not new to this cycle.

## References

- Plan: `specs/189_fix_channel_confusion_orchestrate_pipeline/plans/01_fix-channel-confusion-orchestrate.md`
- Dispatch: `specs/189_fix_channel_confusion_orchestrate_pipeline/.dispatch/1.md`
- Decisions: `specs/189_fix_channel_confusion_orchestrate_pipeline/.decisions.json`
- Prior-cycle handoffs: `specs/189_fix_channel_confusion_orchestrate_pipeline/handoffs/phase-{1..6}-handoff-*.md`
