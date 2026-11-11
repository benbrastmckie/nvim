# Research Report: Task #420

**Task**: 420 - Warn when plan size exceeds cycle budget
**Started**: 2026-11-07T22:15:07Z
**Completed**: 2026-11-07T22:45:00Z
**Effort**: research
**Dependencies**: None (sequenced-after a sibling task for file territory only, not a blocking dependency)
**Sources/Inputs**:
- Codebase: `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`,
  `orchestrate-build-dispatch.sh`, `update-task-status.sh`, `skill-base.sh`,
  `orchestrate-batch-admit.sh`, `validate-handoff.sh`, `lib/phase-heading-patterns.sh`
- Docs: `docs/architecture/orchestrate-state-machine.md`,
  `context/patterns/batch-orchestration-guardrails.md`, `docs/architecture/handoff-schema.md`
- Measured evidence: `specs/archive/411_refactor_verify_deploy_gate_framework/{metrics.jsonl,issues.jsonl}`,
  `specs/archive/328_systematic_script_and_test_corpus_efficiency/metrics.jsonl`, aggregate scan
  of all 138 `specs/**/metrics.jsonl` files in this repository
**Artifacts**: this report (`specs/420_warn_plan_size_exceeds_cycle_budget/reports/01_plan-size-cycle-budget-warning.md`)
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The gap is confirmed exactly as described: `orchestrate-cycle-plan.sh` contains **zero**
  occurrences of `phases_total` (verified by grep across the whole file) — it reads only
  `phases_completed` (from a handoff, hard-mode-only, in the H1 block). The remaining-budget
  facts it already tracks (`cycle_counts`, `batch_cycle_budget`) and the plan-size fact it never
  reads (`phases_total`, recoverable by grepping a plan file's `### Phase N:` headings — a
  mechanism that already exists in three other call sites) have simply never been compared.
- **Budget-remaining is a SHARED, batch-wide pool, not an isolated per-task counter.** The
  eligibility gate at `orchestrate-cycle-plan.sh`'s Eligibility section tests
  `sum(.cycle_counts[])` against `.batch_cycle_budget` (`= ntasks * per_task_max_cycles`), not any
  single task's own count. A plan-size notice must reference this same pool, not a naive
  `max_cycles_per_task[t] - cycle_counts[t]` difference — the dispatch's own single-task framing
  ("4 cycles left" / "1 cycle left") is the batch-of-one special case of this pool, not a separate
  mechanism.
- **Measured phases-per-cycle distribution** (not asserted): across every `metrics.jsonl` file in
  this repository, 127 tasks have at least one implement dispatch with `phases_total > 0`. 117 of
  127 (92%) complete their *entire* plan in a single implement dispatch, regardless of phase
  count — observed totals finishing in one dispatch range from 2 up to 10 phases. Only 10 tasks
  needed 2+ implement dispatches; across those, 31 individual cycle-to-cycle advances were
  positive, with values `{1×26, 2×2, 3×2, 5×1}` (mean 1.32, median 1, max 5) — this is the base-mode
  distribution. One task (328, a 20-phase plan) is clear hard-mode evidence: 18 consecutive
  implement dispatches advanced the phase counter by exactly +1 every single time, with zero
  deviation, confirming the architecture doc's "per-phase dispatch" claim as an observed near-exact
  1:1 ratio, not merely a documented intent.
- A plan-size notice is best classified **ADVISORY** by this repository's own existing
  Blocking-vs-Advisory criterion (`batch-orchestration-guardrails.md`): it is a heuristic estimate,
  not a hard structural fact, and the harm of a false "likely won't finish" is recoverable (an
  operator simply re-invokes), unlike the silent-corruption harm that justifies this repo's
  BLOCKING guardrails.
- **Admission time, not plan time, is the correct and sufficient site.** The "remaining budget"
  half of the comparison genuinely does not exist until a specific `/orchestrate` invocation
  starts (mode — base vs. `--hard` — is chosen per-invocation, not fixed at plan creation), so a
  plan-time notice would necessarily be mode-blind. Admission time is also provably "early": it
  runs before any dispatch of the cycle it decides, for every cycle of every invocation, including
  the very first one after planning finishes.
- A concrete insertion point already exists in the codebase: `orchestrate-cycle-plan.sh`'s
  existing H1 block (hard-mode-only today) already resolves the implement candidate's latest plan
  file via the same `task_lookup_dir` + `ls plans/*.md | sort -V | tail -1` chain
  `update-task-status.sh`'s `--phase-check` uses, and already sources
  `lib/phase-heading-patterns.sh`. Counting `phases_total` there is a mechanical port of logic
  that already exists at three other call sites (`update-task-status.sh`'s `count_plan_phases`,
  `skill-base.sh`'s `skill_corroborate_phase_counts`, and this same H1 block's own
  `phases_completed` read), not new design.

## Context & Scope

This task was raised by `/orchestrate`'s conclusion stage from
`specs/411_refactor_verify_deploy_gate_framework/issues.jsonl` (now archived), entry
`iss_1792069168800_KkTpLC`: an 11-phase base-mode plan hit `MAX_CYCLES` (5/5) with the operator
learning the plan would not finish in one invocation only by hitting the wall, not by any earlier
signal. The required direction (full text in the dispatch file,
`specs/420_warn_plan_size_exceeds_cycle_budget/.dispatch/12.md`) is an advisory, non-blocking,
mode-aware, budget-remaining-aware notice, documented in two named locations, with a mandatory
measured (not asserted) phases-per-cycle characterization. This report covers: (1) confirming the
gap and the existing adjacent machinery; (2) the shared-pool budget mechanism's exact shape; (3)
the measured phases-per-cycle distribution for both modes, with sources and sample sizes; (4) the
plan-time-vs-admission-time site decision; (5) a concrete, evidence-grounded threshold
recommendation and insertion point. It does not write any code — that is the plan/implement
phases' job.

## Findings

### Codebase Patterns

**The gap, confirmed precisely.** `grep -c phases_total agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh`
returns 0. The file's only phase-accounting read is `phases_completed`, from
`.orchestrator-handoff.json`, inside the H1 (hard-mode per-phase dispatch) block
(`orchestrate-cycle-plan.sh:2348`), used solely for a marker/handoff mismatch cross-check — never
compared against a plan size or a budget.

**`phases_total` is already a required, validated handoff field**
(`validate-handoff.sh:121`, `required_fields=("status" "phases_completed" "phases_total" "blockers")`),
and `orchestrate-build-dispatch.sh:329` already reads it from the handoff to compose the
`"PHASES COMPLETED: X of Y"` mission line (`orchestrate-build-dispatch.sh:617`). But a handoff
only exists *after* a dispatch has already run once — it cannot supply `phases_total` for a task
at phase 0 that has never been dispatched. The plan file itself is the fact that exists earlier:
three existing call sites already derive `phases_total` directly from a plan's
`### Phase N: {name} [STATUS]` headings, with no handoff involved:

- `update-task-status.sh`'s `count_plan_phases()` (`update-task-status.sh:724-738`), fed by
  `resolve_plan_file_for_phase_check()` (`update-task-status.sh:697-721`), which resolves the
  task's latest plan file via `project_name -> plan_dir -> ls plans/[0-9][0-9]_*.md | sort | tail -1`.
- `skill-base.sh`'s `skill_corroborate_phase_counts()` (`skill-base.sh:1507-1616`), which greps the
  SAME plan file for `PHASE_HEADING_ERE` (total) and `PHASE_HEADING_DONE_ERE` (done), gated behind
  a mandatory whole-file `has_nonconforming_phase_headings` check first.
- `orchestrate-cycle-plan.sh`'s own H1 block (`orchestrate-cycle-plan.sh:2325-2335`), which — for
  hard-mode implement candidates only — resolves `h1_plan_path` via
  `task_lookup_dir "$t" "$h1_project_name" "$PROJECT_ROOT"` then
  `ls -1 "${h1_task_dir_abs}/plans/"*.md | sort -V | tail -1`, and already sources
  `lib/phase-heading-patterns.sh` (`orchestrate-cycle-plan.sh:2325`).

All three use the single canonical grammar in `lib/phase-heading-patterns.sh`
(`PHASE_HEADING_ERE='^### Phase [0-9]+(\.[0-9]+)?:'`, with a `PHASE_HEADING_DONE_ERE` sibling for
the closed `[COMPLETED]`/`[COMPLETED WITH EXCLUSIONS]` subset), and all three observe the same
ordering contract: check `has_nonconforming_phase_headings` over the WHOLE file first, and take a
named inconclusive branch on a hit, before trusting any filtered count. **A fourth call site
inside `orchestrate-cycle-plan.sh` counting `phases_total` the same way is a mechanical port, not
new design** — and the H1 block is the natural site, since it already resolves the plan path and
already sources the library, just gated to `hard_mode = true` (`orchestrate-cycle-plan.sh:2324`:
`[ "$hard_mode" != "true" ] && continue`).

**The budget side is a shared batch-wide pool, not a per-task isolated counter.** Decision 1's
header comment (`orchestrate-cycle-plan.sh:92-105, 577-586`) documents the per-task
`cycle_counts[t]`/`max_cycles_per_task[t]` maps, but the actual eligibility gate
(`orchestrate-cycle-plan.sh:1745-1762`, "Decision (a) — per-RUN cycle budget, drawn from the
SHARED BATCH POOL") computes:

```
_pool_used=$(mt_get '[.cycle_counts[]? // 0] | add // 0')
_pool_budget=$(mt_get '.batch_cycle_budget // 0')   # = ntasks * per_task_max_cycles
if [ "$_pool_used" -ge "$_pool_budget" ]; then ... block every remaining task ...
```

A task may spend more than its own nominal contribution when a sibling needs fewer; the pool, not
any single task, is the bound. `per_task_max_cycles` is 5 in base mode and 13 under `--hard`
(`orchestrate-cycle-plan.sh:586-587`), re-derived fresh every invocation from the current `--hard`
flag — never persisted, never `//=`. **Any "remaining budget" used by a plan-size notice must
read `batch_cycle_budget - pool_used`, the same two already-computed values the eligibility gate
itself uses** — not a separate per-task subtraction, which would be wrong the instant more than
one task is in the batch. For the common `/orchestrate N` (batch of one) case this reduces
exactly to the dispatch's own framing (a single task's remaining cycles), so the pool-based
design is a strict generalization, not a departure.

**Advisory precedent and shape.** This repository's advisory signals are emitted as a *purely
additive* field merged onto a verdict object regardless of the decision it rides alongside,
paired with a human-readable `reason` string on stderr — never a separate rendering pass. The
closest in-shape precedent is `orchestrate-batch-admit.sh`'s `dirty_scope_advisory`
(`orchestrate-batch-admit.sh:932-955`): `{dirty_paths: [...], reason: "..."}`, "Never changes
decision, defer_reason, or exit code — purely informational" (comment at line 940). `--gate`
itself (`orchestrate-cycle-plan.sh:182-185`, forwarded at line 2616) is a different kind of
"advisory" — it only writes a `- gate_flag: true` hint into the dispatch file
(`orchestrate-build-dispatch.sh:545-546`) for the dispatched *agent* to interpret, not a
human-facing warning — so it is a weaker precedent for this task's purpose than
`dirty_scope_advisory`'s shape. The recommended design (see Recommendations) follows
`dirty_scope_advisory`'s shape: a sibling field on the per-task dispatch row, e.g.
`cycle_budget_advisory`, never altering `dispatch`/`deferred`/`blocked`/`stop`.

**The `phases_total == 0` pass-through convention already exists and must be mirrored, not
re-derived.** `skill-base.sh`'s `skill_gate_completion_claim()` (`skill-base.sh:1431-1460`) has
three cases: Case 1 (`phases_total > 0`, incomplete) refuses; Case 2 (`phases_total > 0`,
complete) allows; **Case 3 (`phases_total == 0`, i.e. absent or malformed) falls back to the
mode-specific default rather than asserting anything** — this is the precedent the dispatch's
"must not fire on a task with no plan... or phases_total absent/zero" requirement explicitly asks
to mirror (dispatch file, line 56).

**Dispatch-row shape, both modes identical.** The dry-run and live paths build byte-identical
dispatch row shapes (`{task, phase, agent, model, dispatch_file, force, focus}`,
`orchestrate-cycle-plan.sh:2435` and `:2879-2880`), with `model`/`dispatch_file` forced `null`
under dry-run — "byte-identical when absent" is already the convention for `--compare`/`--gate`
(header comment, line ~57). A new advisory field must follow the identical pattern: present with
the same content in both dry-run and live rows (it costs no side effect to compute), never a
divergent shape between the two.

### External Resources

Not applicable — this is a closed, internal orchestration-engine design question with no external
API or library surface; no web research was needed or performed.

### Measured Evidence (Phases-Per-Cycle Distribution)

**Method.** All `specs/**/metrics.jsonl` files in this repository (138 files, 451 total entries)
were concatenated and filtered to `phase == "implement"` rows with `phases_total > 0`, grouped by
task, sorted by `dispatch_seq`, and consecutive `phases_completed` deltas were computed per task.

**Headline numbers:**

| Metric | Value |
|---|---|
| Tasks with >=1 implement dispatch carrying `phases_total > 0` | 127 |
| Tasks whose entire plan completed in exactly 1 implement dispatch | 117 (92%) |
| Observed `phases_total` for single-dispatch completions | range 2-10 (sorted list spans 2,2,2,2,3,3,3,...,10) |
| Tasks needing 2+ implement dispatches | 10 |
| `phases_total` for multi-dispatch tasks | 4,4,5,5,6,7,8,11,13,20 |
| Positive cycle-to-cycle phase advances, across those 10 tasks | n=31: `{1×26, 2×2, 3×2, 5×1}` — mean 1.32, median 1, max 5 |

**The originating task (411) in full, reconstructed from its archived `metrics.jsonl` and
`issues.jsonl`** (`specs/archive/411_refactor_verify_deploy_gate_framework/`): base mode,
`per_task_max_cycles=5`. Invocation 1 (`sess_1792044449_7b6242`): research (cycle 1) + plan
(cycle 2) + implement dispatch_seq 3 (`0 -> 4`, cycle 3) + implement dispatch_seq 5 (`4 -> 5`,
cycle 4) + implement dispatch_seq 6 (`5 -> 6`, cycle 5) = exactly 5 cycles, at which point
`issues.jsonl` records, verbatim, the exact `MAX_CYCLES reached (5/5...)` entry this task was
raised from. Invocation 2 (`sess_1792078504_9a6b85`): implement dispatch_seq 7 (`6 -> 7`), 9
(`7 -> 8`), 10 (`8 -> 10`, delta +2) — reaching **phase 10 of 11, with budget remaining** (this
invocation's own commit message reads "orchestration paused (cycle 3, dispatch seq 10)" — a
voluntary pause, not a budget exhaustion; no second `MAX_CYCLES` issue-log entry exists for this
task). Invocation 3/4 then closed phase 11. **This is precisely the dispatch's required
counter-fixture, found as real history rather than constructed**: an 11-phase plan at phase 10,
with cycles left, must not fire the notice, and did not in reality hit the budget wall at that
point.

**Hard-mode evidence (task 328, archived `specs/archive/328_systematic_script_and_test_corpus_efficiency/metrics.jsonl`):**
a 20-phase plan, dispatched via `general-implementation-agent` (the per-phase behavior is a
dispatch-instruction difference under `--hard`, not a different agent). 18 implement dispatches
(`dispatch_seq` 8, 10, 11, 13, 15, 18, 20, 21, 22, 24, 26, 27, 28, 29, 30, 31, 32, 33, 34) carried
`phases_completed` 3, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 — **every
single advance from dispatch_seq 11 onward is exactly +1, with zero deviation across 15
consecutive cycles.** This task needed 18 implement cycles against a 13-cycles-per-run hard-mode
budget, meaning it genuinely required 2+ separate `/orchestrate` invocations — a second, real,
hard-mode instance of the exact problem this task addresses.

**Interpretation.** Raw phase *count* alone is a weak predictor of single- vs. multi-cycle
completion: the multi-dispatch totals (4,5,6,7,8) overlap substantially with totals that *did*
complete in a single dispatch elsewhere in the sample. What differs is the actual scope of work
each phase names, which `phases_total` cannot see — confirming the dispatch's own framing that
this is a heuristic signal, never a proof of impossibility, and ruling out any threshold design
that treats phase count as a precise predictor.

## Recommendations

1. **Site: admission time only, computed once per cycle in `orchestrate-cycle-plan.sh`'s shared
   decision section, for implement-phase candidates — extending the existing H1 block rather than
   adding a new one.** Change the H1 block's `[ "$hard_mode" != "true" ] && continue` guard
   (`orchestrate-cycle-plan.sh:2324`) so plan-path resolution and `phases_total` counting run
   unconditionally (base mode simply skips the rest of H1's hard-mode-only logic afterward), or add
   a sibling loop immediately alongside it that reuses the same `task_lookup_dir`/`ls plans/*.md`
   resolution and `phase-heading-patterns.sh` sourcing. This is the single point in the file that
   already has every fact the notice needs simultaneously available: `effective_group[$t] ==
   "implement"` (from classification), the plan path, and (by carrying forward or recomputing)
   `_pool_used`/`_pool_budget` from the Eligibility section. Do not add a plan-time emission site:
   mode (`base` vs `--hard`) is chosen per `/orchestrate` invocation, not fixed at plan creation,
   so a plan-time notice could not be mode-aware without guessing a future invocation's flags —
   the dispatch's own "must justify the choice" bar is better met by a single well-placed
   admission-time check than by a mode-blind plan-time supplement.
2. **Budget-remaining must use the shared pool**: `remaining = batch_cycle_budget - pool_used`
   (both values already computed at `orchestrate-cycle-plan.sh:1745-1746`), not a per-task
   subtraction. For a batch of one this is numerically identical to the per-task framing the
   dispatch describes.
3. **Threshold, grounded in the measured distribution, not asserted:**
   - Base mode: fire when `remaining_phases > remaining_cycles * 2`.
   - Hard mode: fire when `remaining_phases > remaining_cycles * 1`.
   Justification: hard mode's measured ratio is ~1:1 exactly (zero deviation across 15 consecutive
   cycles in the task-328 sample), so no slack is evidentially justified. Base mode's distribution
   is right-skewed with a strong single-cycle-catch-up effect (92% of all observed tasks finish in
   one dispatch regardless of phase count up to 10) — a multiplier of 1 would false-positive on
   the bulk of ordinary multi-phase plans (totals up to 10 are routinely absorbed by a single
   fresh 5-cycle budget in this sample), while a multiplier of 2 is the exact boundary the real
   data supports: a 10-phase plan against a fresh 5-cycle budget (`10 > 5*2=10` is false) does not
   fire, matching the observed single-dispatch completions at that size, while the real
   originating case (11 phases, fresh 5-cycle budget: `11 > 10` is true) does fire. Both of the
   dispatch's required fixtures (the 411 reproduction and its own phase-10-of-11 counter-fixture)
   are satisfied by this design without any special-casing — verify this arithmetic directly in
   the plan/implement phase rather than re-deriving it from scratch.
4. **Shape: a purely additive `cycle_budget_advisory` field on the per-task dispatch row**,
   mirroring `dirty_scope_advisory`'s shape (`orchestrate-batch-admit.sh:932-955`): e.g.
   `{phases_total, phases_remaining, remaining_cycles, mode, message}`. Never present when
   `phases_total == 0` or absent (mirrors `skill_gate_completion_claim`'s Case 3 pass-through,
   `skill-base.sh:1446-1460`), never altering `dispatch`/`deferred`/`blocked`/`stop`, identical in
   dry-run and live rows (both already build the same row shape at `orchestrate-cycle-plan.sh:2435`
   and `:2879-2880`), and always paired with a human-readable stderr line (this repo's advisory
   convention is "never silent even though non-blocking").
5. **Message content** must name the two concrete, already-sanctioned remedies the dispatch
   requires: re-invoking `/orchestrate` (the existing `MAX_CYCLES` message's own phrasing,
   `orchestrate-cycle-plan.sh:1762`, already does this) and, for a plan materially larger than one
   run's budget, considering task division — never propose a budget-override flag, which
   `docs/architecture/orchestrate-state-machine.md:231` documents as a deliberate absence.
6. **Documentation**: add a subsection to `docs/architecture/orchestrate-state-machine.md`'s
   `## MAX_CYCLES Enforcement` section (after line 253, before the `---` at line 255) describing
   the advisory notice, its threshold formula, and its relationship to the existing
   `MAX_CYCLES`/shared-pool mechanics already documented there. Add a corresponding entry to
   `context/patterns/batch-orchestration-guardrails.md`'s admission-layer material — confined to
   that file's admission-layer sections only (its own "Blocking vs. Advisory: The Criterion" and
   "Classification Table", `batch-orchestration-guardrails.md:269-303`, is the natural home for one
   new classification-table row), per this task's own sequencing note (a concurrent sibling task
   also edits this file; do not touch unrelated sections of it).
7. **Verification**: reuse this report's measured fixtures directly as test data —
   `scripts/tests/test-orchestrate-cycle-plan.sh` already has a seeding/assertion idiom for
   `cycle_counts`/`MAX_CYCLES` (e.g. lines 573-592, 657-711) that generalizes directly to seeding
   `phases_total`/a plan file with N phase headings and asserting a `cycle_budget_advisory` field's
   presence/absence. Build the byte-identical-dispatch fixture (notice firing vs. suppressed, same
   scenario) as a diff of the full emitted plan JSON with the advisory field stripped from both
   sides — the cheapest way to prove non-interference with `dispatch_file`/`agent`/`model`/etc.

## Decisions

- **Admission time is the sole emission site; no plan-time notice is added.** Justified by this
  repository's own "Admission-Time vs. Mid-Flight: A Knowability Test"
  (`batch-orchestration-guardrails.md:1678-1704`): both facts the notice needs (plan size via the
  plan file's phase headings, and remaining budget via the shared pool) are on-disk facts
  knowable before any agent runs — but the *budget* half only becomes knowable once a specific
  invocation's mode is chosen, which happens at `/orchestrate` command time, never at plan-write
  time. A plan-time notice would have to guess a future invocation's `--hard` flag or use a
  mode-blind worst case, which is a materially weaker signal than the exact admission-time
  computation costs nothing extra to obtain.
- **Budget-remaining is read from the shared batch pool
  (`batch_cycle_budget - sum(cycle_counts)`), never from a per-task-isolated subtraction.** This
  is the behavior the engine already implements for the blocking `MAX_CYCLES` check itself
  (`orchestrate-cycle-plan.sh:1745-1762`); a notice that disagreed with the mechanism that
  actually enforces the budget would be actively misleading.
- **Classification: ADVISORY**, per this repository's existing two-condition test
  (`batch-orchestration-guardrails.md:269-287`) — the signal is a heuristic derived estimate (fails
  condition 1 in spirit, as the drift-percentage row in the same table already establishes for an
  analogous heuristic), and the harm of a false positive is recoverable by the operator simply
  continuing, not a silent, undiscoverable corruption.
- **Threshold formula is `remaining_phases > remaining_cycles * K`, with `K=2` (base) / `K=1`
  (hard)**, chosen from this report's measured distribution rather than an arbitrary round number
  — see Recommendations item 3 for the full justification and the fixture arithmetic it is checked
  against.

## Risks & Mitigations

- **Risk: a future implementer treats raw `phases_total` as a precise predictor and tightens `K`
  without re-consulting the measured distribution.** Mitigation: this report's "Interpretation"
  paragraph under Measured Evidence explicitly documents that phase count alone is a weak signal
  (overlapping totals between single- and multi-cycle outcomes); the plan phase should cite this
  report's numbers rather than re-deriving a threshold from intuition.
- **Risk: the H1 block's hard-mode-only guard is widened carelessly, accidentally changing
  hard-mode dispatch behavior (not just adding a read).** Mitigation: the implementation plan
  should scope the H1 guard change to ONLY the plan-path-resolution and phase-count-read portion,
  leaving every existing hard-mode-only side effect (the disputed-heading downgrade, the
  marker/handoff mismatch block) under its existing `hard_mode == true` gate untouched.
- **Risk: the sequencing note names a concurrent sibling task editing
  `batch-orchestration-guardrails.md`.** This task's own documentation edit must re-read that file
  immediately before editing (per `context/contracts/territory.md`'s Cross-Task Territory
  section) and confine its edit strictly to the admission-layer sections named in Recommendations
  item 6, never touching unrelated sections the sibling task may also be mid-edit on.
- **Risk: a `cycle_budget_advisory` field added to the dispatch row breaks a consumer that
  iterates dispatch-row keys expecting the fixed set `{task, phase, agent, model, dispatch_file,
  force, focus}`.** Mitigation: follow the exact "byte-identical when absent" convention already
  used for `--compare`/`--gate` (verify no consumer in `orchestrate-cycle-postflight.sh` or
  `skill-orchestrate/SKILL.md` enumerates dispatch-row keys exhaustively before adding the field;
  this report did not audit every consumer and flags it as a plan-phase verification item).

## Context Extension Recommendations

- **Topic**: Shared batch-wide cycle-budget pool semantics.
- **Gap**: `docs/architecture/orchestrate-state-machine.md`'s `## MAX_CYCLES Enforcement` section
  documents `PER_TASK_CYCLES`/`BATCH_CYCLE_BUDGET` in its code block (lines 200-202) but the prose
  below it (lines 221-241) describes `cycle_count` almost entirely in single-task terms; a reader
  arriving at this section without also reading `orchestrate-cycle-plan.sh`'s own Eligibility
  section comments could easily mis-model the budget as per-task-isolated, exactly the mistake
  this report's Decisions section above had to correct for itself.
- **Recommendation**: when this task's own documentation edit (Recommendations item 6) lands,
  make the shared-pool framing explicit in the prose, not only the code block, so a future
  plan-size-notice-adjacent feature does not need to re-derive this from source again.

## Appendix

**Search queries / investigation steps used:**
- `grep -c phases_total orchestrate-cycle-plan.sh` (confirmed zero occurrences)
- `grep -n phases_total scripts/*.sh scripts/lib/*.sh docs/architecture/*.md context/patterns/*.md` (located every existing reader/writer)
- Read `orchestrate-cycle-plan.sh`'s Eligibility section (`:1622-1790`) and H1 block (`:2290-2360`)
  in full
- Read `update-task-status.sh`'s `--phase-check` backstop (`:679-760`) and `skill-base.sh`'s
  `skill_gate_completion_claim`/`skill_corroborate_phase_counts` (`:1395-1620`)
- Read `batch-orchestration-guardrails.md`'s "Three Existing Admission Layers", "Blocking vs.
  Advisory: The Criterion" and "Admission-Time vs. Mid-Flight: A Knowability Test" sections in full
- Read `docs/architecture/orchestrate-state-machine.md`'s `## MAX_CYCLES Enforcement` section in full
- `find specs -iname metrics.jsonl | xargs cat` -> 138 files, 451 entries; jq aggregation by task,
  `phase == "implement"`, consecutive `phases_completed` deltas
- Direct read of `specs/archive/411_refactor_verify_deploy_gate_framework/{metrics.jsonl,issues.jsonl,.orchestrator-loop-guard}`
  and `specs/archive/328_systematic_script_and_test_corpus_efficiency/metrics.jsonl`

**References**: dispatch file `specs/420_warn_plan_size_exceeds_cycle_budget/.dispatch/12.md`;
originating issue `iss_1792069168800_KkTpLC` in
`specs/archive/411_refactor_verify_deploy_gate_framework/issues.jsonl`.
