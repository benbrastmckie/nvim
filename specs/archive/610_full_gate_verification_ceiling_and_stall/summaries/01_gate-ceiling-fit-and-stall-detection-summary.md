# Implementation Summary: Task #610

- **Task**: 610 - Full gate verification ceiling and stall
- **Status**: [COMPLETED]
- **Started**: 2026-11-18T23:20:00Z
- **Completed**: 2026-11-19T04:15:00Z
- **Effort**: ~5 hours (8 phases)
- **Dependencies**: None blocking. Territory edges 454, 476, 452, 650, 651, `host_scoped_gate_mutex`
- **Artifacts**: plans/01_gate-ceiling-fit-and-stall-detection.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Made full-gate verification fit under the harness's 600s foreground ceiling and stop silently
stalling dispatches. Relocated the 9-suite slow cost-class bucket onto its own serialized gate
(gate 31), replaced the advisory batch-gate-deferral directive with a staleness-bounded marker
plus mechanical entry guards in `verify-deploy.sh`/`run-all.sh`, generalized Gate 8's own
contention-tagging to every gate's timeout-kill path, and wired the pre-existing heartbeat
strand probe into a watchdog the orchestrator launches beside its dispatches rather than after
them. Redeployed and verified against the complete gate set.

## What Changed

- `agent-system/extensions/core/scripts/gate-registry.data` — new gate 31 row (slow-bucket, serialized, timeout_s=900)
- `agent-system/extensions/core/scripts/verify-deploy.sh` — Gate 8 narrowed to an explicit, coverage-safe `--only` list (never `--cost-class`, which has a core-only blind spot against the real cross-extension corpus); new `gate31_run()`; the batch-gate entry guard (exit 3, `--override-batch-gate-deferral`); generalized `[CONTENTION]` tagging on the sequential kill path
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` — `_greg_load_1min()`; entry/kill-time load sampling in `_greg_pool_job` for the concurrent-pool kill path
- `agent-system/extensions/core/scripts/lib/batch-gate-marker-lib.sh` — new: marker path convention, staleness window (`BATCH_GATE_MARKER_STALE_SEC`, default 3600s), fail-open helpers
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — writes the batch-gate-pending marker whenever `.implement_agents` is non-empty (never gated on task count); drops the `-gt 1` gate on `--batch-gate-deferral`
- `agent-system/extensions/core/scripts/orchestrate-batch-gate.sh` — removes the marker at discharge
- `agent-system/extensions/core/scripts/tests/run-all.sh` — parallel entry guard; `--override-batch-gate-deferral`
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` — `deploy_findings_snapshot` unconditionally overrides the guard for every infrastructure-level snapshot caller
- `agent-system/extensions/core/scripts/deploy-headless.sh` — its own inline `--skip-slow` check overrides the guard too
- `agent-system/extensions/core/scripts/orchestrate-dispatch-watchdog.sh` — new: bounded watchdog over `dispatch-strand-probe.sh`, launched beside Move 2, never awaited
- `agent-system/extensions/core/skills/skill-orchestrate/SKILL.md` — Move 2 watchdog launch; Move 3 alert-file fold-in; Move 4 non-blocking reap
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md`, `context/standards/shell-script-testing.md` — mechanism documentation, the `.gate-lock` posture ruling, the deferred-baseline record
- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — reviewed SKILL.md ceiling move (26,500 B → 27,500 B) following this file's own established convention
- New test suites: `test-gate-slow-bucket-split.sh`, `test-orchestrate-dispatch-watchdog.sh`, `test-batch-gate-pending-marker.sh`, `test-gate-contention-tagging.sh`
- `manifest.json`, `scripts/tests/suite-classification.data` — declarations for all new scripts/suites

## Decisions

- Gate 8's own `--cost-class` narrowing was tried and rejected: `suite_selection_by_cost_class`'s `unknown` bucket is core-extension-scoped, silently dropping 8 real cross-extension suites that are both outside core AND absent from the hints file. Replaced with an explicit `--only` list built from a direct hints-file parse plus a replica of `run-all.sh`'s own cross-extension discovery algorithm — closing the gap by construction.
- `run-all.sh --cost-class slow` for gate 31 was also rejected: a missing hints file makes it match zero suites, tripping `run-all.sh`'s own "zero discovered" harness-failure exit (2) instead of the documented no-op. Replaced with an explicit slow-set `--only` list and an up-front empty-set skip branch.
- The mutex-wait half of Gate 8's own contention signal was deliberately NOT generalized (Phase 6): it is intrinsic to Gate 8's own `specs/.gate-lock` acquire, which most gates never touch. Only the load-threshold signal generalized, reusing `GATE8_CONTENTION_LOAD_THRESHOLD` verbatim.
- `deploy_findings_snapshot` now unconditionally passes `--override-batch-gate-deferral`: every real caller (the Inter-Cycle Redeploy Checkpoint, `command-gate-out.sh`, `orchestrate-cycle-plan.sh`'s own pre/post snapshots, `orchestrate-batch-gate.sh`) is infrastructure-level drift detection around a redeploy, categorically distinct from the dispatched-agent-shells-out-directly incident this guard targets.

## Plan Deviations

- **Phase 1**: idle-branch measurement skipped (host non-idle: loadavg 3.42 >= 2.0, concurrent sibling sessions live) — deferred branch taken, recorded in `records/baseline-deferred.md`.
- **Phase 2**: `--cost-class`-based narrowing for both gates replaced with explicit `--only` lists (see Decisions above) — a coverage-safety fix, not a scope reduction.
- **Phase 6**: the mutex-wait contention signal was not generalized (see Decisions above); load-threshold-only, stated explicitly.
- **Phase 8**: marked `[COMPLETED WITH EXCLUSIONS]` — three residual full-gate-set findings (Gate 27's pre-existing subject-resolution violations, `test-mcp-merge-target.sh`'s pre-existing unrelated bug, `test-gate-lock.sh`'s pre-existing nested-inheritance vulnerability) are Reasoned-Excluded in the plan's own Phase 8 section; none are caused by this task.

## Verification

- Build: N/A (shell/markdown)
- Tests: All new test suites pass standalone (test-gate-slow-bucket-split.sh 9/9, test-orchestrate-dispatch-watchdog.sh 10/10, test-batch-gate-pending-marker.sh 20/20, test-gate-contention-tagging.sh 8/8); `lint-agent-contracts.sh` 394 passed/0 failed (Check K unaffected); `lint-gate-registry.sh` 7/7; `check-task-references.sh`/`check-record-versioning.sh` report 0 new/blocking occurrences under `agent-system/**`
- Files verified: Yes
- **Gate 8 wall-clock**: measured twice independently at 349s (5m49s–5m50s), nproc=24, loadavg 4.15 and 7.22 respectively — under the 600s ceiling with ~42% (251s) headroom, under real non-idle host load (no idle control was available this dispatch; see Phase 1's deferred baseline)
- Full gate set: 2 of 43 checks failed across the final two runs, fully accounted for in Phase 8's own Reasoned Exclusions table (none attributable to this task)

## Impacts

- Gate 8 no longer risks exceeding the harness's 600s foreground ceiling, removing the structural cause of the original 8-hour stall incident.
- A nested unfiltered battery now mechanically refuses itself (exit 3, DEFERRED) rather than merely being asked not to run — covering a batch of one identically to a multi-task batch.
- A load-induced gate timeout kill is now mechanically distinguishable (`[CONTENTION]` WARN-FINDING) from a real failure, for every gate, not only Gate 8 — confirmed firing live on every full-battery run this dispatch.
- A silent dispatch is now detectable on the watchdog's own poll clock rather than only after every Move 2 Agent call returns (exact guarantee depends on harness notification timing, declared moot by construction since Move 3 reads the alert file, never the process).

## Follow-ups

- Re-run Phase 1's and Phase 8's measurements under a confirmed-idle host (none was available throughout this entire dispatch) to record a clean control baseline.
- `test-gate-lock.sh` carries the same nested-env-inheritance vulnerability this task found and fixed in its own `test-batch-gate-pending-marker.sh` (RUN_ALL_NESTED/VERIFY_DEPLOY_NESTED/GATE_MUTEX_HELD silently inherited from gate 8's own outer `run-all.sh`). Out of this task's `file_scope`; recommend a small follow-up task.
- `test-mcp-merge-target.sh`'s pre-existing Assertion C/E failures (hand-written `.mcp.json` entries not surviving a regenerate/unload cycle) are unrelated to this task and still open.
- Gate 27's 3 pre-existing unmigrated `common_test_resolve_candidate` call sites (`test-suite-resolver-lib.sh`, `test-unmapped-fallback-lib.sh`, `test-verification-scope-lib.sh`) remain open, unrelated to this task.
- Several suites in Gate 8's non-slow bucket are unhinted (`unknown` cost class) and surfaced `[COST-DRIFT]` advisories this dispatch; `tests/suite-cost-hints.txt` could use a refresh pass.

## References

- `specs/610_full_gate_verification_ceiling_and_stall/plans/01_gate-ceiling-fit-and-stall-detection.md`
- `specs/610_full_gate_verification_ceiling_and_stall/reports/01_gate-verification-ceiling-and-stall.md`
- `specs/610_full_gate_verification_ceiling_and_stall/records/baseline-deferred.md`
- `specs/610_full_gate_verification_ceiling_and_stall/progress/phase-{1-8}-progress.json`
