# Research Report: Redundant Gate Run Suppression

**Task**: 585 - Make the batch-gate deferral binding and cache repeat gate runs, so the full set
runs once per batch
**Started**: 2026-11-16T07:51:06Z
**Completed**: 2026-11-16T08:10:00Z
**Effort**: medium
**Dependencies**: None
**Sources/Inputs**: - Codebase (agent-system/extensions/core/scripts/*.sh,
  context/contracts/batch-gate-stage.md, specs/decisions/worktree-isolation-removal-verdict.md,
  specs/ROADMAP.md, specs/state.json), seed report 01
**Artifacts**: - this report
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- The seed report's five design questions are now answerable from live code, not open-ended:
  (1) Mechanism A is still prose-only with zero technical enforcement and no cheap "am I green"
  probe wired in; (2) the covering-suite selector is still not wired into Gate 8 (task 584 is
  `[NOT STARTED]`), so the scoped tier cannot yet converge with the narrowed gate; (3) the
  `.gate-lock` mutex interaction is already safe on both axes that matter — a narrowed `--only`
  run never touches the mutex at all, and a cache-hit on gate 8 never even calls `gate8_run`
  (the function that acquires the mutex), so a warm `--skip-unchanged` run cannot contend for the
  lock; (4) corpus completeness is still unproven, correctly out of scope; (5) build-heavy
  co-scheduling admission (`task_is_build_heavy_implement()`) landed since the seed report but is
  gated on `task_type` ∈ `{lean4, cslib}` only — a `meta`/`general` gate-heavy implement task
  (every task in the observed batch) is never even a *candidate* for that refusal, resolving the
  seed's open ambiguity in favor of "gate-heavy does not count as build-heavy."
- The minimal, structurally safe remedy for Gap 2 is to make Mechanism A's own emitted directive
  append `--skip-unchanged` to the two narrowing invocations it already recommends
  (`orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` block). This requires no change to
  Move 4 (`orchestrate-batch-gate.sh`), which already cannot regress: `deploy_findings_snapshot`
  (`lib/deploy-baseline-lib.sh`) unconditionally strips `--skip-unchanged` from its passthrough
  args today, independent of any caller.
- Recommended approach for Gap 1 (bindingness): strengthen the directive's own text to name
  `--skip-unchanged` as the sanctioned cheap probe, but do not add a hard refusal/hook — no
  existing mechanism can distinguish a deliberate full sweep (a legitimate escalation when the
  scoped tier can't reach an unmappable criterion) from a wasteful one without reading dispatch
  prose, which is exactly the capability the orchestrator's own postflight review already has.

## Context & Scope

Researched: the current, post-seed-report (2026-11-10) state of (a) Mechanism A's dispatch
directive and whether it carries any enforcement beyond prose, (b) Mechanism B's structural
rejection of the cache fast path, (c) whether any orchestrate caller passes `--skip-unchanged`
today, (d) the `.gate-lock` mutex's interaction with both narrowed (`--only`) and cached
(`--skip-unchanged`) runs, (e) whether covering-suite selection (task 584) or build-heavy
admission (ROADMAP Settled decision 14) has since closed either open design question, and (f)
whether the seed report's carried figures still hold against live gate-registry state.
Out of scope, per the seed report and confirmed still true: deleting/optimizing individual
suites (`specs/586_...`), wiring the selector into Gate 8 (`specs/584_...`), and the
pre-postflight-sweep deploy trigger.

## Findings

### Premise re-validation (Carried-Figure Discipline)

- **Dispatch line 1** (2 of 5 honored, 3 ran full/exploratory, one twice; 9+9 live processes
  against nproc 24; ~70/~100 min wait loops): this is a verbatim restatement of seed report 01's
  own historical observation table and measurement from the 2026-11-10 batch. It matches that
  artifact exactly and is not independently re-derivable now — those dispatches are no longer
  live. Confirmed consistent with the cited source, not re-measured.
- **Dispatch line 5** ("17 of 28 gates declare `@extensions`"): the 17-gate *set* (ids 3, 5, 6, 7,
  8, 11, 12, 13, 17, 18, 19, 20, 21, 23, 24, 26, 28) is confirmed live and unchanged against
  `gate-registry.data`'s current `input_corpus` field. The denominator is now **stale by one**:
  `gate-registry.data` currently declares **29** gates total (not 28), so the live ratio is 17 of
  29. The substantive claim — these 17 gates all share `@extensions` (or `@extensions,.claude`)
  as their corpus and every implement batch touching `agent-system/extensions/core/` invalidates
  all of them unconditionally, making Move 4 caching a no-op — remains true regardless of the
  denominator.
- **Dispatch line 9** (source store is the edit target, never the deployed `.claude/**` mirror):
  confirmed current. `.claude-extensions.json` maps `core`'s `source_dir` to
  `agent-system/extensions/core`, and this repo's deployed `.claude/` tree is flagged stale for
  the `core` extension in this dispatch's own deploy-freshness-context — consistent with editing
  the source store and redeploying, never hand-patching the deployed mirror.

### Gap 1 — Mechanism A is prose-only, no enforcement exists

`orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` block (emitted only when
`phase=implement` and `--batch-gate-deferral` is set, itself gated on `.task_numbers | length > 1`
in `orchestrate-cycle-plan.sh`'s `build_args`) is pure markdown prose written into the dispatch
file: it names the two narrowing invocations, states the unmappable-criterion escape hatch, and
asks the dispatched agent to "record... that the full set was deferred... rather than
independently run." Nothing downstream reads or checks this. A repo-wide search for
`batch_gate_deferral`/`BATCH_GATE_DEFERRAL` returns only the composer itself, its own test file,
and the contract doc — no hook, no validator. `agent-system/extensions/core/hooks/` has no
gate-sweep detector; `detect-noop-bash.sh` is unrelated (filler-call detection). The seed's own
framing — "providing the cheap probe may matter more than tightening the prohibition" — is
corroborated: there is currently no cheap, sanctioned way for an agent under this directive to
answer "am I green" other than running something. `--skip-unchanged` already *is* that cheap
probe (a warm cache on the exact gates the directive already names returns `[SKIP-CACHED]`
immediately), it is simply never mentioned in the directive text.

### Gap 2 — zero lifecycle adoption of `--skip-unchanged`, re-confirmed live

A direct grep for callers of `verify-deploy.sh`/`run-all.sh` passing `--skip-unchanged` anywhere
under `agent-system/extensions/core/scripts/` returns **zero** orchestrate-side hits (only the
flag's own parser in `verify-deploy.sh` and two of the cache library's own unit tests). The seed
report's "exactly one hit" figure for a bare `skip-unchanged` substring grep is now stale — the
substring itself appears dozens of times, because the cache machinery
(`gate-cache-lib.sh`, `gate-registry-lib.sh`) has grown substantially since 2026-11-10 — but the
load-bearing claim, "no orchestrate caller passes it," is unchanged and reconfirmed against the
current tree. `orchestrate-batch-gate.sh` still captures Move 4 at full depth with no
`--skip-unchanged`.

Separately, and structurally (not by convention): `lib/deploy-baseline-lib.sh`'s
`deploy_findings_snapshot` — the function backing every pre/post findings comparison, including
Move 4's — now **unconditionally strips `--skip-unchanged`** from its passthrough args if a
caller ever passes it, emitting a stderr warning but completing normally. The function's own
header documents why: a pre/post baseline comparison where one side cache-skips a gate the other
side ran for real is a correctness hole (a regression introduced on a cache-skipped gate would
silently vanish from the new-findings diff), not a speedup. This means Move 4 cannot regress into
using the cache even by caller mistake — it is already future-proofed against exactly the error
the seed report worried about flattening into. No change to Move 4 is needed or possible here.

### Gap 3 — `.gate-lock` mutex interaction with narrowing and caching (design question 3, answered)

Two independent findings, both favorable, confirmed by direct code reading:

1. **A narrowed `--only` run never touches the mutex.** `tests/run-all.sh` explicitly skips the
   `specs/.gate-lock` bracket for a narrowed invocation: "`--only` narrowed this run to N
   suite(s); specs/.gate-lock is not touched for a narrowed run (suite narrowing already
   discharges a sub-full verification tier; it must not wait out a sibling's full battery)."
2. **A cache-hit on gate 8 specifically never acquires the mutex**, because the mutex-acquire
   code lives *inside* `gate8_run()`'s own body, and `verify-deploy.sh`'s pre-dispatch
   `--skip-unchanged` consult loop removes a cache-hit id from `gate_registry_ids()` entirely
   (via `gate_registry_exclude_ids`) *before* the dispatch loop that calls
   `"gate${_gate_id}_run"` even runs. A cache-hit gate 8 is therefore never invoked at all this
   run, and the lock it would have acquired is never requested.

So the mutex-contention problem the seed report identified (nine batteries queuing single-file
behind an ~11-minute Gate 8) is already structurally relieved for exactly the two usage patterns
Mechanism A and a warm `--skip-unchanged` run would produce, without any further change to the
lock itself.

### Gap 4 — corpus completeness (design question 4, status unchanged)

`test-gate-cache-equivalence.sh` still only proves that touching a *declared* corpus path forces a
miss for every cache-eligible gate; it does not and cannot prove a declared corpus is *complete*.
This remains correctly out of scope for this task (the seed's own note that it must not
contradict `specs/586_suite_gate_cost_standing_consumer/`'s cost review still holds — that task
is still open, unaffected by this research). Any plan built from this report should not weaken
this discipline: defaulting `--skip-unchanged` onto the per-dispatch scoped tier (which this
report recommends) inherits whatever residual under-declaration risk the cache already carries
today; it does not add new risk, because the scoped tier is exactly the invocation shape the cache
was built and tested against.

### Gap 5 — batch admission (design question 5, resolved)

Since the seed report, `orchestrate-cycle-plan.sh` gained a "Mode 2 build-heavy co-scheduling
admission" rule (`specs/decisions/worktree-isolation-removal-verdict.md`'s "Mode 2 Ruling":
"never dispatch two build-heavy implement tasks..."), implemented via
`task_is_build_heavy_implement()` in `lib/task-classification-lib.sh`. This directly answers the
seed's open question — "either that refusal is not wired into admission, or gate-heavy does not
count as build-heavy in its terms" — in favor of the **second** branch: the predicate's own
three-rung ladder starts with a hard `task_type` candidacy pre-filter,
`BUILD_HEAVY_CANDIDATE_TASK_TYPES=("lean4" "cslib")`. Every task in the observed six-task batch
(#423, #483, #461, #499, #554, and the batch's sixth task) is `task_type: meta` or `general`
against `agent-system/extensions/core/`, none of which is `lean4` or `cslib` — so none was ever a
*candidate* for Mode 2's refusal regardless of measured wall-clock weight. Mode 2 closes a real,
separate contention class (actual build systems: Lake, etc.) and is correctly out of scope for
this task's remedy, which is about gate-run redundancy, not build-system contention — but it does
not and structurally cannot address the gate-heavy-implement-task co-scheduling this task is
about. This is a genuine residual gap worth naming in a Context Extension Recommendation below,
not something to fold into this task's plan (changing `BUILD_HEAVY_CANDIDATE_TASK_TYPES` would be
a scheduling-policy change against ROADMAP Settled decision 14's explicit "Cost was not the
reason and must not be cited as it" constraint, and this task's whole remedy is a cost argument).

## Recommendations

1. **Make `--skip-unchanged` the sanctioned cheap probe inside Mechanism A's own directive.**
   Edit `orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` echo block
   (`agent-system/extensions/core/scripts/orchestrate-build-dispatch.sh`, the
   `resolved_run_all`/`resolved_verify_deploy` branch) so the two emitted invocations read
   `` `bash ${resolved_run_all} --only SUITE[,SUITE...] --skip-unchanged` `` and
   `` `bash ${resolved_verify_deploy} --only-gate N[,M...] --skip-unchanged` ``. This is additive
   prose only — no new enforcement surface, no behavior change to Move 4, and it directly answers
   the seed's "cheap probe may matter more than tightening the prohibition" framing by giving the
   dispatched agent a genuinely fast way to re-confirm green on a warm, unchanged scoped tier.
2. **Leave Move 4 (`orchestrate-batch-gate.sh` / `deploy_findings_snapshot`) untouched.** It is
   already structurally incapable of using the cache fast path, by design, independent of this
   task. No work item should target it.
3. **Do not add a hard refusal/hook for Mechanism A.** No mechanical signal in a dispatch's
   transcript distinguishes a deliberate full-sweep escalation (sanctioned via the directive's own
   unmappable-criterion carve-out) from a wasteful redundant one. The directive's existing
   require-recording-the-choice language, plus the new cheap-probe option above, is the right
   level of bindingness for this task; a plan should not propose a gate/hook enforcement surface
   that does not yet have a clear predicate.
4. **Do not touch `BUILD_HEAVY_CANDIDATE_TASK_TYPES` or Mode 2 admission from this task.** The
   gate-heavy-implement co-scheduling gap this task's own Gap 1 observations exposed is real but
   is a scheduling-policy question explicitly barred from a cost argument by ROADMAP Settled
   decision 14; this task's own remedy (binding deferral + cache) is itself the cost-side fix for
   the same symptom via a different, sanctioned mechanism. Flag as a Context Extension
   Recommendation instead (below) for a future, contention-argued record if the symptom recurs
   after this task's remedy lands.
5. **No change needed to the `.gate-lock` mutex.** Both narrowed (`--only`) and cached
   (`--skip-unchanged` on gate 8) runs already avoid contending for it, confirmed by direct code
   reading, not inference.

## Decisions

- Mechanism A's directive will gain `--skip-unchanged` on both narrowing invocations it emits;
  Mechanism B (Move 4) is unchanged and structurally cannot regress.
- No hook/validator will be added to enforce Mechanism A; the existing prose-plus-record
  obligation, now paired with a genuinely cheap probe, is judged sufficient for this task's scope.
- Design questions 2 (selector-into-Gate-8 convergence) and 4 (corpus completeness) remain
  correctly out of scope, owned by tasks 584 and 586 respectively; this task's plan must not
  duplicate or contradict either.
- Design question 5 (batch admission) is resolved as "gate-heavy does not count as build-heavy":
  no admission-side change belongs in this task's plan.

## Risks & Mitigations

- **Risk**: adding `--skip-unchanged` to the directive's emitted text could be read by a future
  editor as endorsing it for Move 4 too. **Mitigation**: the edit is scoped to the two
  per-dispatch narrowing invocations inside the `batch_gate_deferral_flag` block only;
  `deploy_findings_snapshot`'s own unconditional strip is an independent, structural safeguard
  that does not depend on this directive's wording staying correct.
- **Risk**: a stale cache entry (under-declared corpus, design question 4) returning a false
  `[SKIP-CACHED]` PASS on a per-dispatch scoped run. **Mitigation**: unchanged from today — this
  task does not increase exposure beyond the scoped-tier usage pattern the cache equivalence suite
  already targets, and resolving the completeness question itself stays with task 586 per the
  seed's own instruction not to contradict that record.
- **Risk**: an agent under schedule pressure ignores the strengthened directive and still runs a
  full exploratory sweep (exactly the Gap 1 observation that motivated this task). **Mitigation**:
  out of scope to fully close mechanically in this task; the cheap-probe addition reduces the
  *reason* to escalate (a fast, already-covered re-check no longer requires a full sweep), which
  is the leverage point the seed report itself identified as most promising.

## Context Extension Recommendations

- **Topic**: Mode 2 build-heavy co-scheduling admission's task-type scope.
- **Gap**: `context/patterns/batch-orchestration-guardrails.md`'s Mode 2 section and
  `specs/decisions/worktree-isolation-removal-verdict.md` do not currently cross-reference that
  `BUILD_HEAVY_CANDIDATE_TASK_TYPES` excludes every `meta`/`general` implement task by
  construction — a reader auditing "is gate-heavy covered by Mode 2" has to trace into
  `task-classification-lib.sh` to find this out, as this report had to.
- **Recommendation**: a future record (not this task) could add one sentence to the Mode 2
  section naming the candidacy pre-filter's current scope explicitly, so a later contention
  argument (if this task's deferral/cache remedy does not fully close the symptom) knows
  immediately that it needs its own admission-side record rather than re-discovering the
  pre-filter from scratch.

## Appendix

Search queries / checks used:
- `grep -rnE "skip-unchanged" agent-system/extensions/core/scripts/*.sh` and a scoped
  orchestrate-caller-only variant, to re-confirm zero adoption.
- `grep -n "gate-lock\|GATE_LOCK\|flock" tests/run-all.sh verify-deploy.sh`, read in full around
  the mutex-acquire sites in both files.
- `awk -F'\t' '$9 ~ /@extensions/'` over `gate-registry.data` to recount the 17-gate set and total
  gate count live.
- `grep -rn "build.heavy\|build_heavy"` across `orchestrate-cycle-plan.sh`,
  `lib/task-classification-lib.sh`, and `batch-orchestration-guardrails.md`, then read
  `task_is_build_heavy_implement()` and `BUILD_HEAVY_CANDIDATE_TASK_TYPES` directly.
- `specs/state.json` task 585 entry (status, file_scope, description) and TODO.md for task 584's
  current status.
- `specs/decisions/worktree-isolation-removal-verdict.md`'s "Mode 2 Ruling" section.
