# Implementation Plan: Task #572

- **Task**: 572 - Make a declared `Verification Tier: full` honorable under batch concurrency
- **Status**: [COMPLETED]
- **Effort**: 4.75 hours
- **Dependencies**: None
- **Research Inputs**: specs/572_make_full_gate_viable_under_batch_concurrency/reports/01_batch-gate-full-tier-viability.md
- **Artifacts**: plans/01_full-gate-batch-concurrency.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

A plan phase that declares `**Verification Tier**: full` inside a multi-task `/orchestrate` batch
is currently unhonorable in two ways: the `## Batch Gate Deferral` directive that would narrow it
names only the plan's *literal final phase*, so an intermediate `full` phase receives no narrowing
instruction and the dispatched agent runs (and abandons) an unscoped aggregator sweep; and the
live gate path has no verdict distinct from FAIL for a run that was contended rather than broken,
so a contention-induced non-completion needs manual triage. This plan closes the first defect at
its single emission site, widens the matching contract prose so the tier-declaration contract says
what the mechanism now does, adds a contention-detected annotation (never a suppression) to the
Gate 8 lock/load path, and redeploys plus runs the complete gate set.

### Research Integration

The research report (`reports/01_batch-gate-full-tier-viability.md`) establishes that Mechanism
A/B (`orchestrate-build-dispatch.sh`'s directive + `orchestrate-batch-gate.sh`'s Move-4 shared
run) and the cross-session `specs/.gate-lock` lease are already built, deployed, and working for
what they cover — this plan rebuilds none of them. Its Recommendation 1 (widen the directive's
phase scan) is Phase 1 here; its Recommendation 3 (ad hoc unscoped runs should use the
`bounded-build-waiter.md` idiom) rides along in Phase 1 because it edits the same two sanctioned
unscoped paths in the same directive text; its Context Extension Recommendation and the
tier-declaration-contract half of the task description are Phase 2; its Recommendation 2
(contention-distinct outcome generalizing `measure-gate-costs.sh`'s load guard) is Phase 3.
Recommendation 4 (auto-lowering `VERIFY_DEPLOY_GATE8_JOBS` from measured load) is deliberately a
Non-Goal — see Decisions.

### Premise Re-Validation (Carried-Figure Discipline)

Every trigger-class line the dispatch flagged was checked against live state, not only against the
prior artifact. Result: **all confirmed, none stale.**

- "the directive is hardcoded to the final phase" — CONFIRMED live:
  `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` still emits "The plan's
  final phase declares `**Verification Tier**: full`" and "This directive constrains the FINAL
  phase of the plan" inside the `[ "$phase" = "implement" ] && [ "$batch_gate_deferral_flag" =
  "true" ]` block. Nothing in that block reads the plan body.
- Task 497's two abandoned unscoped runs (~10 min, ~18 min) and the third explanatory entry —
  CONFIRMED present as `iss_1794259168773_fjzYjI`, `iss_1794261372250_A7WfYB`,
  `iss_1794261827572_KLJ7MO` in `specs/archive/497_promote_telemetry_submodes_to_core/issues.jsonl`.
  The wall-clock figures and the load-average 10.4 batch-gate figure are carried from that log and
  from the dispatch description; they are not re-measured here and are used only as motivation,
  never as a threshold any phase below is calibrated against.
- The addendum's `iss_1794315150204_driCoz` 120s gate-8 lock-wait — CONFIRMED present in
  `specs/archive/450_validate_settled_route_before_dispatch/issues.jsonl`. The report's doubt about
  the figure also CONFIRMED: `scripts/task-lock.sh` sets `GATE_MUTEX_STALE_SEC=1800` and
  `GATE_MUTEX_ACQUIRE_BUDGET_MS=600000`, so 120s matches neither — consistent with the caller's own
  foreground tool-call ceiling, not the lease's budget. Phase 1 therefore treats the remedy as
  operational (bounded-waiter idiom), not as a constant to re-size.
- "`measure-gate-costs.sh` already refuses a contended measurement" — CONFIRMED live
  (`LOAD_THRESHOLD="${MEASURE_GATE_COSTS_LOAD_THRESHOLD:-2.0}"`, exit 2, per-run check).
- NEW, not in the description: `context/formats/plan-format.md`'s `### Batch-aware deferral`
  subsection carries the SAME final-phase-only scoping in prose ("the final phase's own in-dispatch
  obligation narrows…"). Fixing only the composer would leave the contract text contradicting it.
  Phase 2 exists because of this check.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch and no roadmap flag was set; roadmap consultation
was skipped and no roadmap phases are included.

## Goals & Non-Goals

**Goals**:
- Every phase of a plan that declares `**Verification Tier**: full` is covered by the
  `## Batch Gate Deferral` narrowing instruction when the dispatch is part of a multi-task batch,
  not only the plan's literal final phase.
- The two sanctioned *unscoped* paths that survive the directive (the no-candidate degrade branch
  and the UNMAPPABLE-CRITERION carve-out) instruct the reader to run the aggregator detached with
  a bounded `kill -0` wait, so an unscoped run is never abandoned by the caller's own tool-call
  ceiling.
- The tier-declaration contract (`plan-format.md`'s `### Batch-aware deferral`) and the mechanism
  contract (`batch-gate-stage.md`'s Mechanism A siting section) state the widened scoping, so a
  future reader cannot reintroduce the final-phase-only assumption from the prose.
- A Gate 8 run that was contended (long lock wait, or high ambient load at gate entry) is
  identifiable as such from its own output, distinctly from a functional FAIL.

**Non-Goals**:
- Rebuilding or re-litigating Mechanism A/B, the `specs/.gate-lock` lease, or the
  `orchestrate-batch-admit.sh` admission layer — all built, deployed, and working for what they
  cover.
- Re-sizing `GATE_MUTEX_ACQUIRE_BUDGET_MS` or `GATE_MUTEX_STALE_SEC` without a confirmed failure
  to size against.
- Making the aggregator itself batch-aware (auto-narrowing from a detected live batch) — already
  considered and rejected in `batch-gate-stage.md` for want of a trustworthy liveness signal.
- Auto-lowering `VERIFY_DEPLOY_GATE8_JOBS` from measured load (research Recommendation 4, lowest
  leverage: the lease already prevents two concurrent Gate-8 batteries).
- Suppressing, downgrading, or withholding any real FINDING because contention was detected.
- Re-litigating tier-selection discipline itself (when an author should declare `full` at all).

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Contention tag becomes a loophole for dropping real findings under a false "contention" label | H | M | Phase 3 annotates only: the tag is an additional `WARN-FINDING`-channel line plus stderr note; `fail()`/`warn()` call sites, exit status, and the `^FINDING ` stream are untouched. Phase 3 carries a non-vacuousness test asserting a real FAIL still FAILs while the tag is set. |
| New plan-derived content in the composed dispatch silently breaks the IDENTICAL DISPATCH HALT | H | M | `orchestrate-cycle-plan.sh`'s `cycle_plan_dispatch_hash()` comment block carries a STANDING OBLIGATION to record a decision for each such section. Phase 1 makes the scan status-marker-independent (stable across cycles while the plan is unchanged) and records the "DECIDED AND RECORDED" note in that same comment block, in the same phase. |
| Directive grows unreadably long for a plan with many `full` phases | M | M | Render ONE block naming the qualifying phases as a list, never one block per phase (the report's own mitigation). |
| Editing `context/**` files drifts `index-entries.json` line counts, tripping check-extension-docs.sh Rule R | M | H | Rule R is exact (no tolerance). Phases 2 and 3 each declare `index-entries.json` in their own `Files to modify` and run `generate-context-line-counts.sh --write` in the same phase. |
| Added prose pushes a context file past gate 20's eager-context-budget ceiling | M | L | Phases 2 and 3 edit in place and prefer replacing final-phase-only wording over appending new paragraphs; the final phase's full gate set surfaces any overage with the file named. |
| A plan with no `full`-tier phase, or an unreadable plan file, makes the scan assert something false | M | L | Phase 1's degrade branch emits set-wording with no phase numbers rather than asserting "the final phase declares full" as a fact. |
| This task's own implement dispatch runs inside a batch and so cannot independently run the full set | L | M | Expected and sanctioned: Phase 4 then discharges scoped per the directive and records the deferral in its verification notes; the complete set still runs once at the batch stage. |

## Decisions

- **Scan all `full`-declaring phases regardless of phase status marker**, rather than only the
  open/remaining ones. A status-derived scan would make the composed dispatch vary as phases
  complete; a content-derived one varies only when the plan itself changes, which is exactly the
  behavior `cycle_plan_dispatch_hash()`'s halt semantics want. Noise from naming an
  already-completed `full` phase is harmless; a weakened loop halt is not.
- **One directive block naming a phase list**, not a repeated block per phase — the report's own
  mitigation for directive length, and it keeps the heading string `## Batch Gate Deferral`
  (asserted by an existing test as a literal) singular.
- **The contention outcome annotates; it never reclassifies.** The task description asks for "an
  explicit contention-detected outcome distinct from FAIL". Distinct is satisfied by an additional
  signal on the same run, not by converting a FAIL into something weaker — that conversion is the
  loophole the report's own risk table names. Choosing the annotation reading also keeps
  `deploy-baseline-lib.sh`'s `grep '^FINDING '` consumer contract unchanged.
- **Recommendation 3 is treated as operational, not as a constant to re-size.** The 120s figure
  matches no live constant (verified above), so the remedy is to require the bounded-waiter idiom
  on the sanctioned unscoped paths rather than to adjust a lease budget against an unconfirmed
  failure mode.
- **Research Recommendation 4 is dropped to a Non-Goal** rather than deferred to a phase: the
  lease already serializes the dominant Gate-8 cost, leaving this change a small slice of the other
  gates' CPU, below the threshold that justifies touching the verification path again.

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is a strict chain: Phases 2 and 3
both edit `context/contracts/batch-gate-stage.md` and `index-entries.json`, so they are
deliberately serialized rather than placed in one wave.

### Phase 1: Widen the Batch Gate Deferral directive to every full-tier phase [COMPLETED]

**Goal**: The composed directive covers every phase of the plan that declares
`**Verification Tier**: full`, and the two unscoped paths it still sanctions instruct a detached,
bounded-wait invocation.

**Tasks**:
- [x] Confirm the emission site is singular before editing:
      `grep -rn "FINAL phase" agent-system/extensions/core/scripts/` — expect the one block in
      `orchestrate-build-dispatch.sh` (prose copies in `context/**` are Phase 2's, not this
      phase's). *(completed: confirmed singular, one hit at orchestrate-build-dispatch.sh:678)*
- [x] In `orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` block, scan `$plan_path`
      (already resolved for implement dispatches well before this block) for every phase heading
      whose section declares `**Verification Tier**: full`, collecting phase numbers in order.
      Accept both bold spellings already in live use for adjacent fields. The scan MUST ignore
      phase status markers so the rendered text is stable across cycles while the plan is
      unchanged. *(completed)*
- [x] Replace "The plan's final phase declares …" / "This directive constrains the FINAL phase of
      the plan …" with wording that names the collected set (e.g. "Phases 2, 4, 5 of the plan
      declare `**Verification Tier**: full`; this directive constrains each of them"). Keep ONE
      block with a list — never one block per phase — and keep the literal heading
      `## Batch Gate Deferral` unchanged. *(completed)*
- [x] Degrade honestly: when `$plan_path` is empty/unreadable or the scan finds no `full`
      declaration, emit the set-wording with no phase numbers ("every phase of the plan that
      declares `**Verification Tier**: full`") rather than asserting a final-phase fact that may
      be false. Leave the existing no-resolvable-candidate branch's own degrade text in place.
      *(completed)*
- [x] On the two paths that still sanction an UNSCOPED aggregator run — the no-resolvable-candidate
      degrade branch and the UNMAPPABLE CRITERION carve-out — add one instruction to run it
      detached with a bounded `kill -0` wait per `context/patterns/bounded-build-waiter.md`, never
      as a bare foreground call that the caller's own tool-call ceiling can kill mid-run.
      *(completed)*
- [x] Extend `scripts/tests/test-orchestrate-build-dispatch.sh` (Group 19's neighborhood) with
      cases: a plan declaring `full` on an intermediate phase names that phase; a plan declaring
      `full` on several phases names all of them in one block; a plan with no `full` declaration
      (and a missing plan file) renders the numberless degrade wording and asserts no false
      final-phase claim; the `## Batch Gate Deferral` heading literal and its position relative to
      `## Description`/`## Plan` are unchanged; and research/plan dispatches still emit no section.
      *(completed: 9 new cases added, confirmed failing against the pre-change composer, full
      suite 232/232 passing against the post-change composer)*
- [x] Extend `orchestrate-cycle-plan.sh`'s `cycle_plan_dispatch_hash()` comment block with a new
      "DECIDED AND RECORDED" note stating that this section's now plan-derived content remains
      deliberately UNSTRIPPED and why it is not per-cycle-varying (status-marker-independent
      scan), discharging that block's STANDING OBLIGATION in the same change that creates it.
      *(completed)*

**Timing**: 1.5 hours

**Depends on**: none

**Verification Tier**: interface

**Tier Justification**: The covering check is the complete suite set
`scripts/lib/suite-selection-lib.sh` resolves for this phase's three touched script paths, run as
`bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 8 --gate8-touched <those
paths>` — the selector's own closure over the orchestrate dispatch/cycle surface, not a hand-picked
subset of it.

**Scope Hypothesis**: The final-phase-only wording has exactly ONE emission site in
`scripts/**` (`orchestrate-build-dispatch.sh`'s directive block). Confirm with the `grep -rn
"FINAL phase" agent-system/extensions/core/scripts/` task above before editing; if a second
script-side site appears, fix it in this phase too rather than deferring it.

**Files to modify**:
- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` - scan the plan for every
  full-tier phase, render one set-naming directive block, honest numberless degrade, and the
  bounded-waiter instruction on the two sanctioned unscoped paths
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh` - cases for
  intermediate-phase coverage, multi-phase coverage, the degrade wording, and unchanged
  heading/position/phase-gating invariants
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - a "DECIDED AND RECORDED" note
  in `cycle_plan_dispatch_hash()`'s comment block for the now plan-derived directive content

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 8 --gate8-touched
  <this phase's three touched paths>` passes — the selector-derived covering set, which includes
  the two suites this phase authors cases in (`test-orchestrate-build-dispatch.sh` and
  `test-orchestrate-cycle-plan.sh`, whose Group 27 is the dispatch-hash normalizer).
- Each new case fails against the pre-change composer (non-vacuousness), checked before the
  composer edit lands.
- `bash -n` clean on all three edited scripts; shellcheck clean per the repo's gate 22 settings.
- A hand-composed dispatch against a fixture plan declaring `full` on phases 2 and 5 names both.

---

### Phase 2: Align the tier-declaration and mechanism contracts with the widened scoping [COMPLETED]

**Goal**: The prose contracts state the widened scoping, so neither `plan-format.md` nor
`batch-gate-stage.md` can reintroduce the final-phase-only assumption a future reader would
otherwise copy.

**Tasks**:
- [x] Enumerate the prose copies before editing:
      `grep -rn "final phase" agent-system/extensions/core/context/formats/plan-format.md
      agent-system/extensions/core/context/contracts/batch-gate-stage.md
      agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md`
      and treat each hit that is about the deferral override (not about the tier tie-break rule or
      the final-phase definition, both of which stay as they are) as in scope. *(completed: exactly
      one deferral-override hit found, at batch-gate-stage.md's own "Mechanism A's Dispatch-Time
      Siting" section; the two hits at batch-gate-stage.md lines 76/82 are about the tie-break
      invariant's "final phase mandated full" guarantee in the single-task-invariance case, not
      about deferral-override scoping, and were correctly left untouched)*
- [x] In `plan-format.md`'s `### Batch-aware deferral` subsection (confirmed present), change
      "the final phase's own in-dispatch obligation narrows…" to state that EVERY phase declaring
      `**Verification Tier**: full` has its in-dispatch obligation narrowed, and that the directive
      names the qualifying phases. Leave untouched: the non-negotiable invariant, the "never a
      tier" rulings, the unmappable-criterion paragraph's substance, and the `**Tier
      Justification**:` field rules. *(completed)*
- [x] In `batch-gate-stage.md`'s `## Mechanism A's Dispatch-Time Siting` section (confirmed
      present), replace the closing sentence's "the final-phase-only consumption scoping … [is]
      unchanged" with the widened scan, and record — per the research report's Context Extension
      Recommendation — that the previous scoping left intermediate `full` phases with NO deferral
      coverage at all, which is the defect this change closed. *(completed)*
- [x] If and only if the grep above shows `batch-orchestration-guardrails.md` restating the
      final-phase scoping, update that restatement the same way; otherwise record in the phase
      notes that it carries none (do not invent an edit). *(completed: confirmed zero hits for
      "final phase"/"Batch Gate Deferral"/"final-phase" in batch-orchestration-guardrails.md — no
      edit made, per the "do not invent an edit" instruction)*
- [x] Run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write` and
      stage the resulting `index-entries.json` change in this same phase (Rule R is exact, with no
      tolerance). *(completed: plan-format.md 1269->1275, batch-gate-stage.md 227->236; `grep
      "Rule R"` over check-extension-docs.sh's output returns no finding)*

**Timing**: 1 hour

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: The covering check is
`bash agent-system/extensions/core/scripts/check-extension-docs.sh` (Rule R: exact line_count
accuracy for every edited context file) together with the selector-derived suite set for this
phase's touched paths via `verify-deploy.sh --only-gate 8 --gate8-touched <those paths>`; no code
path changes behavior here, so nothing beyond the index-entry truth surface can break.

**Scope Hypothesis**: The deferral override's final-phase-only scoping appears in exactly TWO
context files (`plan-format.md`, `batch-gate-stage.md`), with
`batch-orchestration-guardrails.md` a possible third. The enumerating grep above confirms the
set; a hit outside these three is edited in this phase rather than deferred.

**Files to modify**:
- `agent-system/extensions/core/context/formats/plan-format.md` - `### Batch-aware deferral`:
  obligation narrows for every `full`-declaring phase, not only the final one
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - `## Mechanism A's
  Dispatch-Time Siting`: widened scan recorded, plus why the old scoping left intermediate `full`
  phases uncovered
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - conditional:
  only if the enumerating grep shows it restates the final-phase scoping
- `agent-system/extensions/core/index-entries.json` - regenerated `line_count` values for every
  context file this phase edits (coupled generated surface; Rule R is exact)

**Verification**:
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no Rule R finding.
- `bash agent-system/extensions/core/scripts/verify-deploy.sh --only-gate 8 --gate8-touched
  <this phase's touched paths>` passes (the selector-derived set includes the index-entries schema
  suite).
- `grep -rn "final phase" …` over the three files shows no remaining deferral-override hit (hits
  about the final-phase DEFINITION and the tier tie-break rule are expected to remain).

---

### Phase 3: Give the live Gate 8 path a contention-detected signal distinct from FAIL [COMPLETED]

**Goal**: A Gate 8 run that waited materially on `specs/.gate-lock`, or started under high ambient
load, says so in its own output through a non-blocking channel — without altering any verdict,
exit status, or `^FINDING ` line.

**Tasks**:
- [x] Confirm the lock-wait site is singular: `grep -n "gate-acquire" agent-system/extensions/core/scripts/verify-deploy.sh`
      — expect only `gate8_run()`'s acquire. *(completed: confirmed singular)*
- [x] In `gate8_run()`, time the `gate-acquire` call (wall-clock seconds around the existing
      invocation) and sample the 1-minute load average at gate entry, reusing
      `measure-gate-costs.sh`'s `/proc/loadavg` read shape, including an equivalent test-only
      override hook so the condition is drivable from a suite. *(completed: `_gate8_load_1min()`/
      `_gate8_now_ms()` added, with `GATE8_LOADAVG_OVERRIDE`/`GATE8_LOADAVG_SEQUENCE` test hooks)*
- [x] Define the trigger as a disjunction of two measured signals — acquire wait at or above a
      declared fraction of `GATE_MUTEX_ACQUIRE_BUDGET_MS`, or entry load average at or above a
      declared threshold — with both knobs env-overridable and their defaults justified in a header
      comment. Never trigger from a caller's assertion. *(completed: `GATE8_CONTENTION_WAIT_FRACTION`
      default 0.1, `GATE8_CONTENTION_LOAD_THRESHOLD` default 2.0, both measured locally)*
- [x] On trigger, emit a named `[CONTENTION]` stderr note and, in `--findings` mode, one
      `warn_advisory()`-channel line so it carries the `WARN-FINDING ` token the documented
      `grep '^FINDING '` consumer filter does not match. Verdicts, `CHECKS`, exit status, and every
      `fail()`/`warn()` call site stay exactly as they are. *(completed: emitted directly to
      FINDINGS_LIST rather than via an actual warn_advisory() call, to avoid that function's own
      CHECKS/GATE_DIRTY_LIST side effects)*
- [x] Add cases to `scripts/tests/test-gate-lock.sh` (which already drives the real
      `verify-deploy.sh` gate 8 against a fixture `$WORKDIR` with a stubbed `task-lock.sh`):
      the tag fires under a stubbed slow acquire; the tag fires under a stubbed high load average;
      the tag does NOT fire on a clean, unloaded fixture run; and — the non-vacuousness case — a
      genuinely failing fixture suite still produces its ordinary `FINDING `/FAIL result and
      non-zero outcome while the contention tag is set. *(completed: 10 new cases, confirmed 5
      failing against the pre-change verify-deploy.sh via a sibling-lib-symlinked scratch copy,
      removed before commit; full suite 27/27 passing against the post-change script)*
- [x] Document the new token in `batch-gate-stage.md`'s `## Finding Severity: FINDING vs.
      WARN-FINDING` section as a third `warn_advisory()` call site, stating explicitly that it
      annotates and never reclassifies. *(completed)*
- [x] Re-run `bash agent-system/extensions/core/scripts/generate-context-line-counts.sh --write`
      for the `batch-gate-stage.md` edit and stage `index-entries.json` in this same phase.
      *(completed: 236->249)*

**Timing**: 1.5 hours

**Depends on**: 2

**Verification Tier**: full

**Tier Justification**: The cross-cutting surface is `verify-deploy.sh` itself — the verification
aggregator that nearly every gate- and deploy-related suite resolves as its own subject-under-test
(the suite selector returns effectively the whole battery for this one path), and whose findings
stream feeds `deploy-baseline-lib.sh`'s snapshot and the batch gate stage — so no `--only` or
`--only-gate` subset covers this edit's blast radius.

**Scope Hypothesis**: `gate8_run()` holds the ONLY `.gate-lock` acquire in `verify-deploy.sh`, so
the instrumentation has exactly one insertion point. The confirming grep above runs before the
edit; a second acquire site would mean instrumenting both in this phase.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - `gate8_run()`: acquire-wait timing,
  entry load-average sample with a test override hook, two declared env-overridable thresholds, and
  the `[CONTENTION]` / `WARN-FINDING ` annotation
- `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` - fires-on-slow-acquire,
  fires-on-high-load, does-not-fire-when-clean, and the non-vacuous "a real FAIL still FAILs" case
- `agent-system/extensions/core/context/contracts/batch-gate-stage.md` - `## Finding Severity`:
  the contention tag as a third `warn_advisory()` call site, annotation-only
- `agent-system/extensions/core/index-entries.json` - regenerated line_count for the
  batch-gate-stage.md entry (coupled generated surface; Rule R is exact)

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` — the complete gate set — reports no
  finding attributable to this phase, with `test-gate-lock.sh`'s four new cases present and each
  failing before the `verify-deploy.sh` edit (non-vacuousness). Under a batch dispatch carrying the
  deferral directive, discharge scoped per that directive instead and record the deferral.
  *(DEFERRED per this dispatch's own Batch Gate Deferral directive: ran
  `bash agent-system/extensions/core/scripts/tests/run-all.sh --only <37-suite selector-derived
  union covering verify-deploy.sh, test-gate-lock.sh, batch-gate-stage.md, and index-entries.json>`
  — result: 35 passed, 2 failed (2 expected, 0 NEW), matching known-failures.txt's pre-existing
  test-gate-cache-equivalence.sh (load-sensitive, needs-owner) and
  test-verify-deploy-context-budget.sh (real-defect, owned elsewhere) rows, neither attributable to
  this phase's edits. The complete gate set still runs once at the batch stage per the directive.*)
- A clean fixture run's `--findings` output contains no contention line and is byte-identical in
  its `^FINDING ` set to the pre-change run. *(CONFIRMED via test-gate-lock.sh's new "clean run"
  case: no [CONTENTION]/WARN-FINDING line, and the fixture's own FINDING set stays empty in both
  the pre- and post-change script, as it was before this phase.)*
- `bash agent-system/extensions/core/scripts/check-extension-docs.sh` reports no Rule R finding.
  *(CONFIRMED: `grep -i "Rule R"` over its output returns nothing. The 3 pre-existing "deployed
  script content drift" FAILs for core are expected pre-redeploy drift, resolved in Phase 4.)*

---

### Phase 4: Redeploy and run the complete gate set [COMPLETED]

**Goal**: The deployed `.claude/**` tree matches the source store and the whole repository passes
the complete gate set with this task's changes in place.

**Tasks**:
- [x] Run the deploy so every edited source-store file is mirrored into `.claude/**`
      (`bash agent-system/extensions/core/scripts/deploy-headless.sh`, which also regenerates the
      context line counts and `.claude/context/index.json` as part of its own run). *(completed:
      `timeout 540 bash .claude/scripts/deploy-headless.sh`, deploy landed)*
- [x] Verify no source-vs-deployed drift remains for the files this task touched (compare each
      edited file against its deployed copy). *(completed: all 7 files this task's Phases 1-3
      touched confirmed byte-identical via direct `diff -q` against their deployed copies)*
- [x] Run the complete gate set: `bash agent-system/extensions/core/scripts/verify-deploy.sh`.
      If this dispatch carries a `## Batch Gate Deferral` directive, follow it instead — discharge
      scoped against the suites named in Phases 1-3's Tier Justifications plus the gates covering
      the edited context files, and record in this phase's verification notes that the full set was
      deferred to the batch stage rather than independently run. If an unscoped run IS the
      sanctioned path here, run it detached with a bounded `kill -0` wait per
      `context/patterns/bounded-build-waiter.md`, never as a bare foreground call. *(DEFERRED per
      the directive: re-ran the same 37-suite selector-derived union post-deploy -- 35 passed, 2
      failed (2 expected, 0 NEW), identical classification to Phase 3's own pre-deploy run. The
      complete gate set runs once at the batch stage per the directive.)*
- [x] Triage any finding by isolating this task's own edits before attributing it; a finding not
      reproducible from these changes is recorded, not fixed here. *(completed: deploy-headless.sh's
      own fast-gate pass (gates 1-7, 9-29, --skip-slow) surfaced exactly ONE non-expected finding --
      'core: Content differs from source: scripts/git-commit-scoped.sh' -- isolated and confirmed
      NOT attributable to this task: git-commit-scoped.sh was never touched by any of this task's
      edits, and specs/state.json shows task 476 (isolate_seven_red_gate8_shell_suites)
      concurrently status=implementing, a live sibling writer under this same batch invocation
      mid-edit on that exact file. Recorded via issue-record.sh, not fixed, not deployed over.)*

**Timing**: 0.75 hours

**Depends on**: 3

**Verification Tier**: full

**Files to modify**:
- `__WHOLE_TREE__` - this phase regenerates the entire deployed tree
- `agent-system/extensions/core/index-entries.json` - any residual line-count regeneration the
  deploy's own pre-pass produces

**Verification**:
- `bash agent-system/extensions/core/scripts/verify-deploy.sh` — the complete gate set (all gates,
  including gate 8's full shell-suite battery) reports no finding attributable to this task, or the
  sanctioned scoped discharge is recorded as such with the deferral stated in the phase notes.
  *(DEFERRED per the Batch Gate Deferral directive, as recorded in the task annotation above.)*
- Every file edited in Phases 1-3 is byte-identical to its deployed `.claude/**` counterpart.
  *(CONFIRMED via direct `diff -q`: orchestrate-build-dispatch.sh, orchestrate-cycle-plan.sh,
  test-orchestrate-build-dispatch.sh, plan-format.md, batch-gate-stage.md, verify-deploy.sh, and
  test-gate-lock.sh are all byte-identical source-vs-deployed.)*

## Testing & Validation

- [x] `verify-deploy.sh --only-gate 8 --gate8-touched <phase paths>` passes for Phase 1's three
      touched scripts (the selector-derived covering set). *(27 selected suites PASS)*
- [x] New composer cases fail against the pre-change composer (non-vacuousness), confirmed before
      the edit lands. *(confirmed via git diff showing the old "FINAL phase" literal, and the new
      assertions against it before the edit)*
- [x] `check-extension-docs.sh` Rule R clean after each context-file edit (Phases 2, 3). *(confirmed
      both times via `grep -i "Rule R"` over its output)*
- [x] `verify-deploy.sh --only-gate 8 --gate8-touched <phase paths>` passes for Phase 2's edited
      context files and regenerated index entries. *(10 selected suites PASS)*
- [x] The complete gate set passes for Phase 3, including `test-gate-lock.sh`'s "a real FAIL still
      FAILs under the contention tag" case. *(DEFERRED per the directive to the 37-suite scoped
      union; test-gate-lock.sh's new non-vacuousness case confirmed directly: 27/27 passing)*
- [x] A clean fixture gate-8 run emits no contention line and an unchanged `^FINDING ` set
      (Phase 3). *(confirmed via test-gate-lock.sh's "clean run" case)*
- [x] Complete gate set green, or scoped discharge recorded per the batch directive (Phase 4).
      *(scoped discharge recorded: 35/37 passed, 2 expected/0 NEW, post-deploy)*

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh` — directive widened to every
  `full`-tier phase, with bounded-waiter instructions on the sanctioned unscoped paths
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` — recorded hash-normalizer
  decision for the now plan-derived directive content
- `agent-system/extensions/core/scripts/verify-deploy.sh` — contention-detected annotation on the
  Gate 8 lock/load path
- `agent-system/extensions/core/scripts/tests/test-orchestrate-build-dispatch.sh`,
  `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` — new coverage
- `agent-system/extensions/core/context/formats/plan-format.md`,
  `agent-system/extensions/core/context/contracts/batch-gate-stage.md` (and conditionally
  `context/patterns/batch-orchestration-guardrails.md`) — contract prose aligned with the mechanism
- `agent-system/extensions/core/index-entries.json` — regenerated line counts
- Redeployed `.claude/**` tree
- `specs/572_make_full_gate_viable_under_batch_concurrency/summaries/01_*-summary.md` at completion

## Rollback/Contingency

Every phase is independently revertible and each lands as its own commit, so the ordinary
contingency is `git revert` of the offending phase commit — no working-tree discard is needed.

If an uncommitted working tree must be discarded mid-phase instead, that is a genuine rollback:
follow `context/contracts/recovery.md`'s rollback rung for the exact snapshot-then-revert
invocation shape (including its out-of-scope override flag) before running any destructive git
command. For an ordinary defensive checkpoint before a risky edit — not a rollback — use
`bash .claude/scripts/git-snapshot.sh --no-revert`, which is durable without reverting the tree.

Phase-specific contingencies:
- Phase 1: if the plan scan proves unreliable against real plan shapes, fall back to emitting the
  numberless set-wording unconditionally — it is still strictly better than today's false
  final-phase claim, and it keeps the dispatch hash stable.
- Phase 3: if the contention signal proves noisy in practice, raise the thresholds (both are
  env-overridable by construction) rather than removing the annotation; it never blocks anything,
  so a false positive costs a line of output, not a failed gate.
