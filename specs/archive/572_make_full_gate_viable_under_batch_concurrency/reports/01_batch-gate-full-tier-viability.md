# Research Report: Task #572

**Task**: 572 - Make the full verification tier honorable under batch concurrency
**Started**: 2026-11-16
**Completed**: 2026-11-16
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: Codebase (agent-system/extensions/core/scripts, context/contracts,
context/patterns, context/standards), closed-task issue logs (archived task directories)
**Artifacts**: specs/572_make_full_gate_viable_under_batch_concurrency/reports/01_batch-gate-full-tier-viability.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The batch-shared gate design (Mechanism A/B: `orchestrate-build-dispatch.sh`'s `## Batch Gate
  Deferral` directive + `orchestrate-batch-gate.sh`'s Move-4 shared run) and the cross-session
  `specs/.gate-lock` lease already exist, are deployed, and work as designed for the cases they
  cover. This task is not a request to build either from scratch.
- The concrete, reproducible defect is narrower than the dispatch description's framing suggests:
  Mechanism A's directive text is **hardcoded to name only the plan's literal final phase**
  (`orchestrate-build-dispatch.sh` lines ~671-711: "The plan's final phase declares... This
  directive constrains the FINAL phase of the plan"). A plan that declares `Verification Tier:
  full` on an **intermediate** phase receives no narrowing instruction at all, even inside a
  batch dispatch where Mechanism B already guarantees one shared full run. The dispatched agent
  is then left to either honor the plan's literal `full` declaration (contend and abandon, as
  directly measured) or invent an unguided analogy to the final-phase directive on its own
  judgment — exactly the "agents routinely deviating from a tier the environment cannot deliver"
  pattern the task description names.
- This is directly evidenced, not inferred: `specs/archive/497_promote_telemetry_submodes_to_core/issues.jsonl`
  records two `gate-contention` entries (dispatch_seq 20) where Phases 2 and 4 — both declaring
  `Verification Tier: full`, neither the plan's final phase — each independently ran an unscoped
  `bash verify-deploy.sh`, contended with concurrent sibling batch tasks, and were abandoned
  (~10 min and ~18 min respectively) before the agent recognized, on its own, that the same
  deferral reasoning as the (correctly-directed) final phase should apply. A third entry in the
  same log (`iss_1794261827572_KLJ7MO`) states explicitly that the directive "literally names
  only" the final phase.
- A second, independent surface reaches the same symptom through explicit lock contention rather
  than load: `specs/archive/450_validate_settled_route_before_dispatch/issues.jsonl`
  (`iss_1794315150204_driCoz`) records Gate 8 failing after a 120s wait on `specs/.gate-lock`.
  That incident is already closed prior art (the Batch Gate Deferral directive worked correctly
  there, once read) — it sharpens rather than duplicates this task's question.
- Secondary, lower-confidence finding: the cited 120s figure is suspicious against
  `GATE_MUTEX_ACQUIRE_BUDGET_MS`'s actual default of 600000ms (10 minutes) and matches this
  harness's own default foreground Bash-tool timeout (120000ms) more closely than the mutex's own
  budget — worth a planning-phase check of whether ad hoc (non-`bounded-build-waiter.md`)
  foreground invocations of `verify-deploy.sh`/`run-all.sh` are being killed by the calling
  agent's own tool-call ceiling before the lease or the gate itself ever resolves.
- A real, smaller gap with existing precedent to extend: `measure-gate-costs.sh` already treats a
  load-contended **measurement** as invalid and refuses to record it (load-guard, exit 2, "a
  contended figure is wrong in EITHER direction"). No equivalent exists on the live
  **verification** path (`verify-deploy.sh`/`run-all.sh`): a contention-induced non-completion is
  currently indistinguishable from a genuine functional regression, forcing the manual triage the
  task description complains about. The task's own candidate direction ("a per-gate cost budget
  with an explicit contention-detected outcome distinct from FAIL") is a natural generalization of
  a pattern this codebase already trusts elsewhere, not a novel mechanism.

## Context & Scope

Researched what currently exists for running `verify-deploy.sh`'s full gate set inside a
multi-task `/orchestrate` batch, why a declared `Verification Tier: full` is still not reliably
deliverable despite that existing machinery, and what the task's four candidate directions
(shared lock/admission token, per-gate cost budgets with a contention outcome, parallelism caps,
contract-level tier downgrade) each already have built versus still missing. Scope explicitly
includes the tier-declaration contract per the dispatch, not just the runtime mechanics.

## Findings

### Codebase Patterns

**Mechanism A/B (batch-shared gate design) — built, deployed, working for what it covers.**
- `context/contracts/batch-gate-stage.md` + `scripts/orchestrate-batch-gate.sh`: a once-per-
  invocation, capture/confirm/attribute pipeline over `verify-deploy.sh --findings` at full
  depth, sited in Move 4 of `/orchestrate`'s loop, gated on at least one implement dispatch having
  occurred. Reuses `deploy-baseline-lib.sh` entirely — no new attribution logic.
- `scripts/orchestrate-build-dispatch.sh` (~line 646, `[ "$phase" = "implement" ] && [
  "$batch_gate_deferral_flag" = "true" ]`): emits the `## Batch Gate Deferral` directive ahead of
  the plan body specifically so a dispatched agent reads the constraint before reaching the work
  it constrains (the ordering fix for the motivating incident behind that siting decision,
  recorded in `batch-gate-stage.md`'s "Mechanism A's Dispatch-Time Siting" section).
- Both closed as prior art already: `specs/archive/449_hoist_batch_gate_deferral_directive/` and
  `specs/archive/403_share_one_verify_deploy_gate_run_per_batch/`.

**The scoping defect — directive text is hardcoded to the final phase only.**
`orchestrate-build-dispatch.sh` lines 671-711 render:
```
This task is one of several `implement`-phase dispatches inside one multi-task
/orchestrate batch invocation. The plan's final phase declares
`**Verification Tier**: full` ...
This directive constrains the FINAL phase of the plan named under `## Plan` below ...
```
Nothing in this text, or in the composer logic around it, scans the plan for *other* phases that
also declare `full`. A single implement dispatch ordinarily executes every remaining phase of a
plan in one agent session (hard mode's `--phase-number` per-phase dispatch is the exception, not
the default), so a plan with `full` on phases 2, 4, and 5 (final) has phases 2 and 4 running with
no narrowing instruction in scope at all — only phase 5 is covered.

**Direct, primary-source evidence this defect fires in practice**
(`specs/archive/497_promote_telemetry_submodes_to_core/issues.jsonl`, dispatch_seq 20):
- `iss_1794259168773_fjzYjI`: Phase 2 (`Verification Tier: full`, not final) — unscoped `bash
  verify-deploy.sh` abandoned after ~10 minutes of confirmed multi-sibling contention (`ps aux`
  showed concurrent `run-all.sh`/`verify-deploy.sh` processes from other batch tasks). Agent
  applied the final-phase directive's reasoning to this phase *by analogy*, on its own judgment.
- `iss_1794261372250_A7WfYB`: Phase 4 (`Verification Tier: full`, not final) — unscoped run
  abandoned after ~18 minutes; `test-gate-cache-equivalence.sh` alone ran 10+ minutes against a
  normal cost far below that; also hit and self-resolved a stale `specs/.gate-lock` left by the
  killed Phase-2 attempt (staleness reclaim at the 1800s threshold worked correctly).
- `iss_1794261827572_KLJ7MO`: explicitly states Phase 5's directive "literally names" only that
  phase, discovered only *after* the two unscoped runs above had already happened — and that
  running the full set unscoped during this discovery surfaced several foreign-task gate
  findings (gate 13 orphan cleanup, a gate 20 eager-context-budget overage only ~11% attributable
  to this task, a gate 22 shellcheck finding in an unrelated extension, two gate 24 findings in
  an unrelated extension) that then needed manual disambiguation — a second, independent cost of
  the same unscoped-run pattern beyond raw wall-clock.

This is the task's "gate timeouts... indistinguishable from real failures... manual triage"
complaint, directly sourced, and it traces to one narrow, fixable composer defect rather than to
an absence of batch-sharing machinery.

**Cross-session `.gate-lock` lease — already covers the dominant cost, already fail-open,
already bounded.** `context/patterns/batch-orchestration-guardrails.md`'s "Cross-Session
Gate-Run Coordination" section documents a deliberate bounded-wait lease (not pure advisory, not
unbounded) serializing exactly the two call sites that run the full shell-suite battery
(`run-all.sh`'s own top level; `verify-deploy.sh`'s `gate8_run()`), with `GATE_MUTEX_ACQUIRE_BUDGET_MS`
(default 600000ms) sized strictly below `GATE_MUTEX_STALE_SEC` (default 1800s) so a waiter's
budget can never outlive a holder's own staleness window. Four explicit skip conditions (narrowed
`--only`, nested invocation, inherited `GATE_MUTEX_HELD`, missing deployed `task-lock.sh`) and a
mandatory fail-open posture on acquire failure (never refuses verification, only drops
serialization with a named `WARNING:`). **Deliberately scoped to Gate 8 only** — "bracketing all
23 [gates] would tax gates that have nothing to do with the expensive shared resource" — so two
concurrent full `verify-deploy.sh` runs across different sessions still contend, unserialized, on
the other ~22 gates' own CPU, just not on the dominant Gate-8 cost.

**The task's own `test-gate-lock.sh` addendum sample is a second, more diagnosable surface of
the same root cause**, not a separate mechanism gap: the addendum's primary citation
(`iss_1794315150204_driCoz`, `specs/archive/450_validate_settled_route_before_dispatch/`) is
explicitly recorded as closed prior art — the Batch Gate Deferral directive worked as designed
there once the dispatching agent reached and read it. The addendum's own framing ("the deferral
makes the collision survivable but does not make a declared full tier honorable") matches this
report's framing exactly: collision-survival and tier-honorability are the two things the
existing mechanism and the found gap respectively address.

**Harness Bash-tool-timeout vs. mutex-budget mismatch (lower confidence, worth a planning-phase
check, not independently confirmed here).** `GATE_MUTEX_ACQUIRE_BUDGET_MS` defaults to 600000ms —
also this harness's own documented maximum raisable foreground Bash-tool timeout. The
`driCoz` incident's cited "120s" wait does not match either that 600000ms mutex budget or any
other documented constant in this codebase, but does match this harness's documented *default*
(unraised) foreground Bash timeout (120000ms) closely. `context/patterns/bounded-build-waiter.md`
exists precisely to prevent a dispatched agent's own foreground tool call from being killed
before a detached long-running writer finishes, and `skill-orchestrate/SKILL.md`'s own Move 4
call site already uses it correctly (chained `timeout 540`/`timeout 600000` kill-0 polls, with an
explicit "STILL RUNNING at deadline: repeat the bounded kill-0 wait" instruction covering
arbitrarily long underlying runs). It is not confirmed here whether the `driCoz` dispatch's own
`bash verify-deploy.sh` invocation used that idiom or a bare foreground call; if the latter, the
120s figure is this harness's own default timeout killing the call, misdiagnosed at the call site
as a `.gate-lock` timeout, rather than the mutex's own budget actually exhausting.

**Contention-vs-failure outcome: precedent exists for measurement, not for live verification.**
`scripts/measure-gate-costs.sh`'s LOAD GUARD refuses to record *any* measurement taken above a
load threshold (default 2.0), checked per-run (not just start/end, after a confirmed mid-run
contamination incident changed a gate's measured cost from 10ms to 1,235ms). `context/standards/shell-script-testing.md`'s
"Measurement discipline" section states the general principle ("a contended measurement is wrong
in BOTH directions") and cites a *live-during-this-codebase's-own-history* case of exactly this
task's contention mode contaminating a `verify-deploy.sh --only-gate 8` run. No equivalent guard
or alternate verdict exists on the live `verify-deploy.sh`/`run-all.sh` verification path itself —
every outcome there is binary pass/FINDING, with no contention-distinct third state, which is the
mechanical reason a contended timeout is indistinguishable from a real regression at the call
site today.

**Parallelism is configurable but not load-adaptive.** `gate8_run()` already supports an opt-in
`--jobs`/`VERIFY_DEPLOY_GATE8_JOBS` override (default `auto`) for `run-all.sh`'s own internal
parallel pool, explicitly with "override via `VERIFY_DEPLOY_GATE8_JOBS`, e.g. `1` on a ... heavily
-loaded host" — a manual lever, not an automatic one keyed to a measured ambient-load signal.

### External Resources

Not applicable — this is an internal agent-system mechanics question with no external
documentation surface; all research was codebase-internal per the routing table for `task_type:
meta`.

## Recommendations

1. **(Primary, narrowly scoped, directly evidenced) Widen `orchestrate-build-dispatch.sh`'s
   `## Batch Gate Deferral` emission to cover every phase in the composed implement dispatch that
   declares `Verification Tier: full`, not only the plan's literal final phase.** The composer
   already has the full plan body in hand when composing this directive; the fix is scanning for
   every `**Verification Tier**: full` phase heading rather than asserting the final one by
   construction, and rendering the narrowing instruction (and the UNMAPPABLE-CRITERION carve-out)
   against that full set. This closes the exact, measured defect in `issues.jsonl` entries
   `fjzYjI`/`A7WfYB`/`KLJ7MO` above with no new runtime mechanism — Mechanism B's shared Move-4
   run already covers every phase's obligation regardless of which phase declares `full`.
2. **(Secondary) Give the live gate path a contention-distinct outcome, generalizing
   `measure-gate-costs.sh`'s existing load-guard pattern rather than inventing a new one.** A
   candidate shape: when `gate8_run()`'s own `.gate-lock` acquire has to wait past some fraction of
   its budget, or when a 1-minute load average sampled at gate start exceeds a declared threshold,
   tag the resulting verdict (in `orchestrate-batch-gate.sh`'s attribution record and/or
   `verify-deploy.sh`'s own findings stream) as contention-affected rather than folding it into the
   ordinary FAIL/FINDING channel — consistent with the `WARN-FINDING`/`FINDING` severity split
   `batch-gate-stage.md` already documents for a different non-blocking case.
3. **(Lower priority, needs confirmation first) Audit whether ad hoc full-gate invocations use
   the `bounded-build-waiter.md` idiom.** If the `driCoz` 120s figure is this harness's own
   default foreground timeout rather than the mutex's budget, the fix is operational (consistently
   backgrounding + bounded-polling any unscoped `verify-deploy.sh`/`run-all.sh` call, as Move 4's
   own call site already does), not a new mechanism.
4. **(Optional, smallest leverage) Auto-lower `VERIFY_DEPLOY_GATE8_JOBS` from a measured ambient
   load signal** rather than relying solely on a manual override, mirroring
   `measure-gate-costs.sh`'s existing `/proc/loadavg` read. Lowest priority of the four: the
   `.gate-lock` lease already prevents two full Gate-8 batteries from running *concurrently*;
   this would only help the *other* 22 unserialized gates' own CPU footprint during one holder's
   run, a smaller remaining slice of the measured cost.

## Decisions

- Scoped this record away from re-litigating or rebuilding Mechanism A/B, `.gate-lock`, or the
  session-registry/`orchestrate-batch-admit.sh` admission layer — all three are built, deployed,
  and (per the evidence reviewed) working as designed for what they cover. Recommending only the
  one composer-text widening that the evidence directly implicates, plus the contention-outcome
  generalization the task description explicitly asked for.
- Treated the dispatch's "28 minutes at load average 10.4" batch-gate-stage figure as
  consistent with, not contradicting, the existing chained bounded-wait design (`skill-orchestrate/SKILL.md`
  Move 4 explicitly handles a still-running writer past one `timeout 540`/`timeout 600000` cycle by
  repeating the bounded wait) — did not find evidence this specific measured run failed outright,
  so did not recommend re-sizing those constants without a confirmed failure to size against.
- Did not independently reproduce or confirm the harness-Bash-timeout-vs-mutex-budget mismatch
  hypothesis (Recommendation 3) — flagged as lower-confidence and sequenced behind the primary
  finding, which has three corroborating primary-source issue-log entries.

## Risks & Mitigations

- **Risk**: widening the directive to name multiple phases could make the composed dispatch file
  noticeably longer for a plan with many full-tier phases. **Mitigation**: render one directive
  block naming the full set of qualifying phases (a list), not one repeated block per phase.
- **Risk**: a plan author could begin over-declaring `full` on phases that don't need it, now that
  every full-tier phase in a batch dispatch is "free" (deferred) rather than individually costly.
  **Mitigation**: this is unchanged from today's final-phase-only behavior and already governed by
  `plan-format.md`'s `Tier Justification` field requirement on every non-final phase; out of this
  record's scope to re-litigate tier-selection discipline itself.
- **Risk**: Recommendation 2's contention-outcome tagging could become a loophole for silently
  dropping real findings under a false "contention" label. **Mitigation**: mirror
  `measure-gate-costs.sh`'s own discipline — gate the tag on a measured signal (load average or
  lock-wait fraction), never on the caller's own say-so, and keep the confirm-pass
  (`deploy_baseline_confirm_new_findings`) that already drops non-reproducing candidates as flaky.

## Context Extension Recommendations

- **Topic**: intermediate-phase full-tier deferral.
- **Gap**: `context/contracts/batch-gate-stage.md`'s "Mechanism A's Dispatch-Time Siting" section
  documents the final-phase-only scoping as a readability-ordering decision but does not record
  that this scoping also excludes intermediate full-tier phases from any deferral coverage at all.
- **Recommendation**: once Recommendation 1 above is implemented, update that section (or add a
  sibling subsection) documenting the widened scan, so a future reader does not reintroduce the
  final-phase-only assumption.

## Appendix

- Search queries / investigation path: `batch-gate-stage.md`, `orchestrate-batch-gate.sh`,
  `task-lock.sh` (`.gate-lock` family), `verify-deploy.sh`'s `gate8_run()`,
  `bounded-build-waiter.md`, `batch-orchestration-guardrails.md`'s "Cross-Session Gate-Run
  Coordination" section, `shell-script-testing.md`'s "Measurement discipline" section,
  `measure-gate-costs.sh`, `orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` emission
  block, `specs/archive/497_promote_telemetry_submodes_to_core/issues.jsonl`,
  `specs/archive/450_validate_settled_route_before_dispatch/issues.jsonl`,
  `skill-orchestrate/SKILL.md` Move 3/Move 4 bounded-wait call sites.
- `specs/archive/449_hoist_batch_gate_deferral_directive/` and
  `specs/archive/403_share_one_verify_deploy_gate_run_per_batch/` — closed prior art for
  Mechanism A/B, confirmed not to be reopened by this record's recommendations.
