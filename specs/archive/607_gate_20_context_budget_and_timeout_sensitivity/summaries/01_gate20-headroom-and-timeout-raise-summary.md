# Implementation Summary: Task #607

- **Task**: 607 - Resolve the gate 20 orchestrator context-budget overage and the per-gate
  timeout sensitivity under concurrent load
- **Status**: [COMPLETED]
- **Started**: 2026-11-18T14:16:00Z
- **Completed**: 2026-11-18T22:45:00Z
- **Effort**: ~0.75 hours
- **Dependencies**: None
- **Artifacts**: plans/01_gate20-headroom-and-timeout-raise.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Two config-only remedies landed in the source store (`agent-system/extensions/core/**`),
followed by a redeploy. Gate 20's three budget figures got a deliberate, dated headroom move
while the gate was green, breaking the recurring ~0-200 B reactive-margin pattern. Gates 3, 4,
and 10's `timeout_s` were raised from 60 to 180 to stop a loaded run from reporting resource
contention as a TIMEOUT finding.

## What Changed

- `agent-system/extensions/core/context/config/orchestrator-context-budget.json` — three
  budget figures moved to deliberate preventive headroom: `eager_load.baseline_bytes`
  70500 -> 71600 (recomputed from a live 70472 B measurement, not the plan's stale 70400 B
  assumption — see Plan Deviations); `commands/orchestrate.md` ceiling 21500 -> 22000;
  `skills/skill-orchestrate/SKILL.md` ceiling 26000 -> 26500. Each figure got a dated
  derivation entry stating the move was preventive, not reactive.
- `agent-system/extensions/core/scripts/gate-registry.data` — `timeout_s` raised 60 -> 180 for
  gates 3 (Doc-lint), 4 (Task-reference lint), and 10 (`validate-state.sh --deep`), with a
  dated note on the `timeout_s` field documentation recording the deviation from the
  idle-cost-model derivation rule (no clean `avg_ms` exists for these three gates in
  `gate-cost-model.csv`) and a cross-reference for a future load-adaptive timeout design.
- `agent-system/extensions/core/scripts/tests/known-failures.txt` — corrected the
  `test-gate-cache-equivalence.sh` row's stale `gate10`-timeout citation (was "30", two moves
  behind; now "180" with provenance), and updated its `needs-owner` note.
- Deployed `.claude/**` tree regenerated via `deploy-headless.sh`; all three edited files
  diff-confirmed content-hash equal between source and deployed copies.

## Decisions

- Re-baseline, not trim, for gate 20 (adopted from the research report): three prior
  compaction rounds already found no further redistributable bloat in the two near-ceiling
  files, so a fourth search was judged low-yield.
- Static timeout raise, not a load-adaptive mechanism: a general concurrency-scaled timeout
  design remains task 610's charter; building a partial version here risked being superseded.
- Gates 3 and 4 were added to the timeout raise alongside gate 10 (the plan's own judgment
  call, extending the research report's conditional recommendation): all three share the same
  60s bound and the same corroborated incident class.
- The 180s figure was derived from gate 10's own corroborated worst standalone runtime (66s)
  at the same ~3x headroom factor the registry's documented rule uses, since
  `gate-cost-model.csv` cannot supply a clean average for gates 3/4/10.

## Plan Deviations

- **Phase 1, task 1.1-1.2**: the plan's premise re-validation (authored 2026-11-16) assumed a
  live eager-load total of 70400 B. By implementation time, a same-day concurrent sibling task
  (644 phase 5, the `/recap` command row) had already moved the baseline to 70500 B, with a
  live measurement of 70472 B. Per the plan's own instruction to recompute rather than carry
  stale figures forward, the new baseline target was derived from the live figure
  (70472 + 1,100 B headroom, rounded to the next 100 B) = 71,600, not the plan's literal
  71,500. Per-file ceiling figures matched the plan's assumption exactly and were applied
  unchanged.
- **Phase 3, task 3.4**: the plan's literal "run the full gate sweep and confirm gate 5 is
  green" step was superseded by this dispatch's own Batch Gate Deferral directive (this task
  ran inside a multi-task `/orchestrate` batch). Discharged instead via
  `verify-deploy.sh --only-gate 5,10,20 --skip-unchanged`. Gate 5 still reports 4 findings, but
  all 4 are on files outside this task's `file_scope` (`context/standards/orchestrator-runtime-
  files.md`, `scripts/lib/runtime-file-patterns.sh`, `scripts/orchestrate-build-aux-
  dispatch.sh`, `scripts/tests/test-runtime-file-tracking.sh`), traced via `git log` timestamps
  to concurrent sibling commits landing in the same ~5-minute window as this task's own
  redeploy. This task's own three edited files are separately diff-confirmed content-hash
  equal. The full-sweep gate 5 return to green is deferred to the batch's own close sweep.

## Verification

- Build: N/A (config-only change)
- Tests:
  - `jq -e .` parses `orchestrator-context-budget.json`: PASS.
  - `verify-deploy.sh --only-gate 20`: 4/4 PASS with widened bounds (live 70472 B / baseline
    71600 B; 21496 B / 22000 B; 25692 B / 26500 B).
  - `run-all.sh --only test-verify-deploy-context-budget.sh`: 14 passed, 1 failed (EXPECTED —
    the declared baseline-fixture-clean row), 0 NEW.
  - `lint-gate-registry.sh`: 7/7 PASS.
  - Mechanically-selected suite set (10 suites) for Phase 2's touched paths: 9 passed, 1 failed
    (1 expected — `test-gate-cache-equivalence.sh`, the same declared row), 0 NEW.
  - Post-redeploy: `diff` silent for all three edited files (source == deployed) in both
    directions checked.
  - `verify-deploy.sh --only-gate 5,10,20 --skip-unchanged`: gate 10 and 20 PASS; gate 5 fails
    on 4 out-of-scope files attributed to concurrent sibling commits (see Plan Deviations).
- Files verified: Yes (all three edited files confirmed present, parseable, and
  content-hash-equal post-deploy).

## Impacts

- Gate 20 now carries durable headroom (1,128 B / 504 B / 808 B margins) instead of the
  recurring 0-200 B reactive pattern, reducing how often an unrelated eager-load or near-ceiling
  file addition re-fires the gate.
- Gates 3, 4, and 10 now tolerate up to 180s under load before reporting a TIMEOUT finding,
  addressing the corroborated resource-contention incident class; the bound remains hard and
  killable, so a genuine runtime regression still surfaces.
- `known-failures.txt`'s `test-gate-cache-equivalence.sh` row now cites the current `timeout_s`
  value and records that the raise may make its `needs-owner` recalibration question
  resolvable (not proven here).
- A durable cross-reference for task 610's eventual load-adaptive timeout design now lives in
  `gate-registry.data`'s own `timeout_s` field documentation, the file such a design would
  necessarily read.

## Follow-ups

- The gate 10 timeout raise's contention-case benefit was not directly exercised in this
  dispatch's own verification (host was not under triggering load at verification time);
  recorded honestly per the plan's own instruction rather than claimed as proven.
- Gate 5's 4 out-of-scope findings (concurrent sibling drift, not this task's regression) are
  expected to resolve at the batch's own full close sweep; not independently re-chased here per
  the Batch Gate Deferral directive and the "no additional full sweep" guidance.
- `gate-cost-model.csv` still carries only a `gate8` row; regenerating it (to supply a clean
  `avg_ms` for gates 3/4/10 matching the registry's documented derivation rule) remains
  excluded here as a multi-hour cost this task did not need to pay — explicitly out of scope
  per the plan's Non-Goals.

## References

- Plan: specs/607_gate_20_context_budget_and_timeout_sensitivity/plans/01_gate20-headroom-and-timeout-raise.md
- Report: specs/607_gate_20_context_budget_and_timeout_sensitivity/reports/01_gate20-budget-and-timeout-sensitivity.md
- Progress files: specs/607_gate_20_context_budget_and_timeout_sensitivity/progress/phase-{1,2,3}-progress.json
- Handoffs: specs/607_gate_20_context_budget_and_timeout_sensitivity/handoffs/phase-{1,2,3}-handoff-*.md
- Issues/wins log: specs/607_gate_20_context_budget_and_timeout_sensitivity/issues.jsonl
