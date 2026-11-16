# Research Report: Task #607

**Task**: 607 - Resolve the gate 20 orchestrator context-budget overage and the per-gate timeout sensitivity under concurrent load
**Started**: 2026-11-16T07:51:00Z
**Completed**: 2026-11-16T08:10:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (`agent-system/extensions/core/scripts/verify-deploy.sh`, `gate-registry.data`, `context/config/orchestrator-context-budget.json`, `scripts/lib/gate-registry-lib.sh`), live gate run, `specs/state.json`, `specs/*/issues.jsonl`, `specs/*/handoffs/*.md`, git log
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary
- Gate 20 (orchestrator context budget) currently PASSES cleanly: eager-load total is exactly at its 70400 B baseline, and both per-file ceilings (`commands/orchestrate.md` 21496/21500 B, `skills/skill-orchestrate/SKILL.md` 25692/26000 B) are within bound. The 71712 B overage cited in the task description is stale — it was already closed by intervening tasks 620 and 634 before this dispatch ran.
- The gate's own config history shows ~10 reactive ceiling-moves over two months, each landing with a 0-200 B margin that the very next ordinary edit re-trips. The remedy worth applying now is a deliberate, one-time headroom increase on all three figures while the gate is green, not a trim (no redistributable duplication was found; the config's own notes already say so for the most recent rounds).
- The task's "gates 8 and 10... killed by their own 60s per-gate timeout" claim is only half right: gate 8 (`tests/run-all.sh`) declares `timeout_s=1500`, not 60, and no incident of gate 8 itself being killed by a 60s bound was found anywhere in the logs. Gate 10 (`validate-state.sh --deep`, `timeout_s=60`) IS independently corroborated three times under concurrent load, consistently re-passing standalone in 61-66s.
- Task 607's "per-gate timeout should scale with observed concurrency" question substantially overlaps task 610's own research question 4 (not yet started), an undetected near-duplicate across the two tasks' duplicate-check passes. Recommend a narrow, config-only remedy here and leave the general load-adaptive mechanism to 610.

## Context & Scope

Two independent questions, scoped per the dispatch:
1. Gate 20 (orchestrator context-budget lock in `verify-deploy.sh`) reportedly over its eager-load baseline — decide trim vs. rebaseline, apply the remedy.
2. Gates 8 and 10 reportedly killed by their own 60s per-gate timeout under concurrent batch load — assess whether per-gate timeouts should scale with concurrency or simply be raised.

Explicitly out of scope: making gate 8's red shell suites green (owned by task 476). This research additionally surfaced a scope question against task 610 (see Risks & Mitigations).

## Findings

### Codebase Patterns

**Gate 20 mechanics** (`verify-deploy.sh` lines ~1748-1860): three independent sub-checks against `agent-system/extensions/core/context/config/orchestrator-context-budget.json`:
- Sub-check A: `measure-eager-context.sh --check` volatile-file hits — unconditional `fail()`.
- Sub-check B: live eager-load `TOTAL` vs. `eager_load.baseline_bytes` — `fail()` only when the live total *exceeds* baseline (equality passes).
- Sub-check C: per-file ceilings for `commands/orchestrate.md` and `skills/skill-orchestrate/SKILL.md` — `warn()`/`fail()` depending on `ORCHESTRATOR_BUDGET_GATE_MODE` (currently `hard`, i.e. `fail()`).

Live measurement taken during this dispatch (`bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 20 .`):

```
[PASS] measure-eager-context.sh --check: no volatile-file hits
[PASS] eager-load total (70400 B) within baseline (70400 B)
[PASS] commands/orchestrate.md (21496 B) within ceiling (21500 B)
[PASS] skills/skill-orchestrate/SKILL.md (25692 B) within ceiling (26000 B)
```

`orchestrator-context-budget.json`'s own `_comment`/derivation fields document the overage's resolution: the SKILL.md ceiling was moved to 26000 B and the file trimmed to 25692 B by tasks referenced in its own dated entries, matching commits `0984f635f` (task 620, "close outstanding gate20 finding (skill-orchestrate/SKILL.md ceiling)") and `c3f838fae` (task 634 phase 2, "SKILL.md context-budget ceiling move (gate 20 follow-up)") — both landed 2026-11-13/2026-11-15, **before** this dispatch's `dispatch_start_ts` (2026-11-15 23:51 local). The 71712 B figure in the task description reflects a transient batch-era measurement that predates those two fixes.

The config's own derivation history (dating back to 2026-10-01) records roughly ten separate reactive ceiling/baseline moves, each following the same pattern: a necessary, non-duplicative content addition breaches the current ceiling by 100-2000 B; 1-3 compaction passes recover most of it; the residual is closed by a "reviewed, dated ceiling move" rounded up to the next 100 or 500 B; margin left is typically 0-200 B. Several entries explicitly note "no further redistributable bloat found nearby" — i.e. the compaction well for these three hot files is close to dry under repeated prior rounds.

**Gate 10/timeout mechanics**: `gate-registry.data` declares, per gate, `requires_source_store timeout_s cost_class serialized`. Relevant rows:
- Gate 3 (doc-lint): `timeout_s=60`
- Gate 4 (task-ref lint): `timeout_s=60`
- Gate 8 (`tests/run-all.sh`): `timeout_s=1500`, `serialized=true` (always runs alone, before the concurrent pool)
- Gate 10 (`validate-state.sh --deep`): `timeout_s=60`

Enforcement is `gate_registry_exec_bounded` (`scripts/lib/gate-registry-lib.sh`), which forks a killably-bounded subshell per gate and reports `FINDING gate${id} TIMEOUT: ... exceeded its ${timeout_s}s timeout and was killed` on expiry. There is **no existing load-adaptive or env-var-overridable mechanism for per-gate `timeout_s`** (unlike Gate 8's own `VERIFY_DEPLOY_GATE8_JOBS`/`--jobs` concurrency knobs, which control intra-run parallelism, not cross-process host contention). `timeout_s` is a flat, static value in a data file; raising it is a one-line edit.

### External Resources

Not applicable — this is a pure codebase/process question with no external library involved.

### Corroborating evidence for the timeout claim

Searched `specs/*/issues.jsonl` and `specs/*/handoffs/*.md` for load-induced gate kills:
- `specs/562.../issues.jsonl` (2026-11-16T03:58:04Z): gate10 "exceeded its internal 60s timeout twice inside the full verify-deploy.sh/deploy-headless.sh fast-gate pass" under "load average ~11 on 24 cores"; standalone re-run with 180s budget passed in 66s (22 passed, 10 warnings).
- `specs/562.../handoffs/phase-3-handoff-20261116T040800Z.md`: same incident, standalone re-run passed in 66s.
- `specs/634.../issues.jsonl` (2026-11-16T04:53:43Z / T05:49:56Z): gate10 "timed out under concurrent load from overlapping verify-deploy.sh invocations (own plus unrelated repos)".
- Task 610's own description (a separate, broader record created 2026-11-12, one day after 607) names a *different* earlier batch where "three transient 60s-timeout gate kills (doc-lint, task-ref lint, validate-state --deep)" — i.e. gates 3, 4, and 10 — were all confirmed-false-positive under load.

No occurrence of gate 8 itself being killed by a 60s timeout was found anywhere; gate 8's declared bound is 1500s and it is always serialized (runs alone), so it is not subject to the same cross-process CPU-contention pattern that hits the 30-60s lint gates. The task description's "gates 8 and 10... 60s... timeout" is very likely a conflation of gate 8 (the subject of the *separate*, correctly-scoped-out concern about red shell suites) with the gates-3/4/10 60s-timeout pattern actually evidenced in the logs.

Current host state at measurement time: 24 cores, `uptime` load average 7.2/7.1/7.9 — multiple sibling research/implement dispatches (505, 568, 585, this one) were concurrently active in this same repository during this research pass, consistent with the "concurrent batch run" conditions the task describes.

## Recommendations

**Gate 20 (budget):**
1. No remedy is *required* to make the gate pass — it already passes. Apply a deliberate, reviewed headroom increase anyway, now, while green: move `eager_load.baseline_bytes` from 70400 to roughly 71000 B, `commands/orchestrate.md`'s `ceiling_bytes` from 21500 to roughly 22000 B, and `skills/skill-orchestrate/SKILL.md`'s `ceiling_bytes` from 26000 to roughly 26500 B — each a dated, justified entry in `orchestrator-context-budget.json`'s existing narrative style, explicitly framed as "preventive headroom" rather than "a trim was needed." This is the re-baseline branch of the task's own either/or framing, chosen over trimming because the config's own recent entries already report no further redistributable duplication nearby.
2. Do not attempt a compaction pass as the primary remedy — multiple entries already searched this ground down to "no further redistributable bloat found nearby," and spending effort re-searching for bytes that two recent tasks already failed to find is unlikely to be productive.

**Timeout sensitivity:**
3. Target gate 10 specifically (the only incident with three independent, this-week corroborations): raise `gate-registry.data`'s row 10 `timeout_s` from 60 to roughly 150-180s — comfortably above the observed 61-66s worst case with margin, matching the sizing convention already used for gate 8/22 (slow gates get a generously large fixed bound rather than a tight one). Consider the same for gates 3 and 4 (also `timeout_s=60`) given task 610's corroborating incident, if a conservative bump is judged low-risk.
4. Do NOT build a general load-adaptive (loadavg- or active-dispatch-count-scaled) timeout mechanism as part of this task. That is explicitly task 610's research question 4 territory, and 610 is the chartered, broader-scoped record for exactly this decision (it also covers gate 8's wall-clock and the `.gate-lock` fail-open posture, which a partial mechanism built here could not consider holistically). Keeping 607's remedy to a simple, static value bump avoids building something 610 may later supersede or contradict.
5. Coordinate the two tasks explicitly: add a one-line cross-reference in 610's `TERRITORY EDGES` (or in 607's own follow-up) noting that 607 already raised gate 10 (and possibly 3/4)'s static timeouts, so 610's eventual load-adaptive design treats those as the new floor rather than re-discovering the same evidence.

## Decisions
- Gate 20: re-baseline with deliberate headroom (not a trim) — content-search for further compaction is judged low-yield given the config's own exhausted-search notes.
- Timeout sensitivity: a targeted static-value raise on the empirically corroborated gates (10, and optionally 3/4), not a load-adaptive mechanism — the latter is task 610's charter.
- Gate 8 is excluded from the timeout remedy: no evidence it was ever killed by a 60s bound (its own declared bound is 1500s), and its red-suite concerns are task 476's separate scope.

## Risks & Mitigations
- **Risk**: re-baselining gate 20 without a real content change could be read as "weakening verification coverage." Mitigation: the gate's own `fail()`-always severity for the eager-load sub-check is unchanged; only the numeric ceiling moves, following the exact precedent and narrative convention the config already uses for every prior move — this is not a reduction in what is checked.
- **Risk**: raising gate 10's timeout masks a future *real* regression in `validate-state.sh --deep`'s own runtime. Mitigation: 150-180s still leaves a hard ceiling (unlike removing the bound entirely), and the config/registry's existing dated-derivation convention makes any future move auditable.
- **Risk**: task 607 and task 610 remain unreconciled, and a future implementer re-litigates the load-adaptive-timeout question from scratch. Mitigation: Recommendation 5 above; flagged as `kind: issue` via issue-record.sh during this phase for visibility in the conclusion-stage evidence base.

## Context Extension Recommendations
- **Topic**: cross-task duplicate detection for narrowly-worded follow-up tasks created from the same underlying incident class.
- **Gap**: `audit-task-proposals.sh`'s semantic duplicate check missed the 607/610 overlap in both directions (607 predates 610; 610's own later check didn't surface 607 despite near-identical subject matter), apparently because 607's gate-20-budget framing dilutes the semantic signal for its second, timeout-related question.
- **Recommendation**: no context file change proposed here (task-creation-time tooling behavior, out of this task's edit scope) — noted for awareness in case task 610's owner wants to revisit duplicate-detection sensitivity for compound-topic task descriptions.

## Appendix
- Search queries / commands used: `measure-eager-context.sh --check`; `verify-deploy.sh --only-gate 20 .`; `grep` over `gate-registry.data`, `specs/*/issues.jsonl`, `specs/*/handoffs/*.md`, `specs/central-errors.jsonl`; `git log --oneline` over `commands/orchestrate.md`, `skills/skill-orchestrate/SKILL.md`, `context/config/orchestrator-context-budget.json`; `python3 -I` queries against `specs/state.json` for tasks 532, 607, 610.
- Key files read: `agent-system/extensions/core/scripts/verify-deploy.sh` (gate20_run, gate-registry exec), `agent-system/extensions/core/scripts/gate-registry.data`, `agent-system/extensions/core/context/config/orchestrator-context-budget.json`, `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh`, `specs/562_conclusion_stage_drops_null_resolution_entries/issues.jsonl` and its phase-3 handoff, `specs/634_mechanize_orchestrate_conclusion_roadmap_regenerate/issues.jsonl`.
