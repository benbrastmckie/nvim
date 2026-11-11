# Seed Report: Stop Redundant Gate Runs — Binding Deferral and a Warm Cache

**Status**: seed, authored at task creation to orient the research phase. Observations are from a
live six-task `/orchestrate` batch on 2026-11-10 and MUST be re-derived (ROADMAP Settled
decision 5).

## The design is already right; adoption is the gap

`/orchestrate` already implements the intended two-mechanism design, documented in
`context/contracts/batch-gate-stage.md`:

- **Mechanism A** — `orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` section: a
  dispatch-time directive that narrows a final implement phase's own obligation to a scoped tier
  (`run-all.sh --only SUITE[,...]`, `verify-deploy.sh --only-gate N[,...]`).
- **Mechanism B** — `orchestrate-batch-gate.sh`: one run of the complete gate set per
  invocation, sited in Move 4, "rather than once inside every task's own final implement phase."

That contract even states the honest-attribution argument for it: "the shared run is not merely
cheaper than N per-task runs, it is also a MORE HONEST attribution than a per-task run under
concurrency, where every sibling's in-flight edits pollute every other sibling's own gate
result."

Two adoption gaps keep it from paying off.

## Gap 1: Mechanism A narrows the obligation, not the behavior

The directive's own description is "narrows what THIS dispatch must independently" verify
(`orchestrate-build-dispatch.sh` header, `--batch-gate-deferral`). Nothing forbids a dispatched
agent from *additionally* running the full sweep, and nothing detects it afterwards.

Observed across one six-task batch, from the agents' own completion reports:

| Task | Behavior |
|------|----------|
| #423 | honored — scoped 5-suite run |
| #483 | honored — scoped `--only-gate 3,4` |
| #461 | ran an additional "exploratory full `verify-deploy.sh`" |
| #499 | ran "`verify-deploy.sh` (full gate, no flags) ... to completion **twice**" |
| #554 | Phase 6 ran "the complete gate set" |

So three of five implement dispatches each paid a full gate set the batch stage was going to pay
once anyway. Measured concurrently during that batch: **9 live `run-all.sh` and 9 live
`verify-deploy.sh` processes**, 24 gate/test processes in total, against nproc 24.

That concurrency is not merely wasteful, it is self-throttling by design. A completed record
added the repo-scoped `.gate-lock` mutex and brackets "tests/run-all.sh's top level and
verify-deploy.sh's Gate 8 with it, so two concurrent sessions' full gate-set batteries serialize
instead of contending for the same cores." Gate 8 costs ~11 min (`gate-cost-model.csv`:
`gate8 = 662,462 ms`). Nine batteries therefore queue single-file behind an 11-minute gate. This
is the direct cause of the observed implement-phase wait loops in that batch: one dispatch waited
roughly 70 min and another roughly 100 min, both in bounded wait loops on a live, legitimately
running gate process.

## Gap 2: the gate cache has zero adoption in the lifecycle

A completed 13-phase record built input-scoped gate invalidation and reported that "a warm,
unchanged run cache-skips 17-20 of 24 real gates outright at near-zero cost." The cache is well
built: content-addressed via `git hash-object` rather than mtime, a composite key over both the
declared corpus *and* the gate's own implementation body, a `GATE_CACHE_FORMAT_VERSION` global
kill switch, and a fail-safe sentinel (`CANNOT_COMPUTE`) so an undeclared or unresolvable corpus
means the gate always runs rather than silently skipping.

Adoption check:

```
grep -rnE "skip-unchanged" agent-system/extensions/core/scripts/*.sh
```

returns exactly one hit — the flag's own parser in `verify-deploy.sh`. **No orchestrate caller
passes it.** `orchestrate-batch-gate.sh` is explicit that it captures at "full depth (no
--skip-slow)".

## Where the cache does and does not pay — the load-bearing distinction

**It does not pay at Move 4.** 17 of 28 gates declare `@extensions` (the whole extension tree) as
their `input_corpus`: gates 3, 5, 6, 7, 8, 11, 12, 13, 17, 18, 19, 20, 21, 23, 24, 26, 28. Every
task in the observed batch modified files under `agent-system/extensions/core/`, so all 17
invalidate unconditionally — Gate 8 among them. At the end of an implement batch the cache hit
rate for exactly the expensive gates is zero. The headline figure describes an *unchanged* tree.

**It does pay on repeat runs.** Two agents re-running the same gates minutes apart over a tree
nobody changed in between is precisely the warm-unchanged case. That is the shape of every
redundant run catalogued in Gap 1 above.

Therefore the remedy is asymmetric, and the research phase should not flatten it:

- Move 4's once-per-invocation run **keeps full depth**. Caching it is a no-op, and it is the
  batch's only unconditional signal.
- Per-dispatch scoped runs, and any exploratory or repeat sweep, **should default to
  `--skip-unchanged`**.

## Design questions for research

1. **How binding can Mechanism A be made?** Options span a stronger directive (prose only, no
   enforcement), a dispatch-time environment marker a wrapper honors, and a hard refusal. Note
   that an agent genuinely needs *some* cheap way to answer "am I green?" — a prohibition with no
   sanctioned substitute will be violated under pressure, which is arguably what the observed
   exploratory runs already demonstrate. Providing the cheap probe may matter more than tightening
   the prohibition.
2. **Is a scoped run even the right in-dispatch tier?** If covering-suite selection lands in Gate
   8 (its own record), the scoped tier and the narrowed gate converge, and Mechanism A may reduce
   to "run the gate, it is already narrow."
3. **Does `--skip-unchanged` interact safely with the `.gate-lock` mutex?** A cache hit should
   presumably not acquire the mutex at all, since it runs nothing — worth confirming, since the
   mutex bracket sits at `run-all.sh`'s top level and inside `gate8_run`.
4. **Corpus completeness is the cache's one unproven axis.** `test-gate-cache-equivalence.sh`
   mechanically proves that touching a *declared* corpus path forces a miss, for all 18
   cache-eligible gates. It does not prove each declaration is *complete*. An under-declared
   corpus would yield a stale PASS. Before defaulting the cache anywhere, decide whether that
   risk needs its own check — and note that the equivalence suite is itself the subject of a cost
   review in `specs/586_suite_gate_cost_standing_consumer/`, so the two records must not
   contradict each other on how much proof is enough.
5. **Batch admission.** ROADMAP Settled decision 14 states that "build contention is closed by
   refusing to co-schedule two build-heavy implement tasks" and — importantly — that "Cost was
   not the reason and must not be cited as it." The observed batch co-scheduled six implement
   tasks that each discharged a full gate tier, so either that refusal is not wired into
   admission, or gate-heavy does not count as build-heavy in its terms. Research should determine
   which, and must argue any admission change on contention grounds, never on cost grounds, to
   stay inside that decision.

## Explicitly out of scope

- Deleting, optimizing or demoting individual suites — `specs/586_suite_gate_cost_standing_consumer/`.
- Wiring the selector into Gate 8 — `specs/584_gate8_covering_suite_selection/`.
- Re-adjudicating the pre-postflight-sweep deploy trigger, which has its own open record against
  `batch-orchestration-guardrails.md`.
