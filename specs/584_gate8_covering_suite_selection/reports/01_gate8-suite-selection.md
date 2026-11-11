# Seed Report: Wire Covering-Suite Selection into Gate 8

**Status**: seed, authored at task creation to orient the research phase. Measured 2026-11-10.
Figures are CARRIED-UNVERIFIED and MUST be re-derived (ROADMAP Settled decision 5).

## The defect in one sentence

Gate 8 runs **all 149 shell suites** whenever anything under `@extensions` changes, while a
library that maps touched paths to exactly their covering suites already exists, is tested, and
is trusted enough that plan authoring depends on it — and is wired into Gate 8 **zero times**.

## Evidence

`gate-registry.data` field 9 (`input_corpus`) for Gate 8:

```
8  Shell test suite runner (tests/run-all.sh)  gate8_run  -  true  1500  slow  true  @extensions
```

`@extensions` is the whole extension tree. So a one-file edit anywhere under
`agent-system/extensions/**` invalidates Gate 8's cache entry and re-runs the entire battery.

The selector that could narrow it:

- `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`
- Public API: `suite_selection_select PATH [PATH...]` and `suite_selection_select_annotated`
- It "maps touched paths against ONE scripts tree" (its own header)

Wiring check:

```
grep -cE "suite_selection|suite-selection" .claude/scripts/verify-deploy.sh   # -> 0
```

The selector is already load-bearing elsewhere: plan `Tier Justification` lines are validated
against its output, and `validate-artifact.sh` warns when a declared tier names suites the
selector does not return for those paths. Planners in routine operation cite it directly (e.g.
a planning dispatch reporting that "`suite_selection_select` showed those two paths alone select
~157 suites"). So this is a wiring job against proven machinery, not new invention.

## Why this is the largest single lever

The suite battery is 23.5 min serial across 149 suites, and `gate-cost-model.csv` puts
`gate8 = 662,462 ms`. Gate 8 is the only gate in cost class `slow`, with a 1500 s timeout.

Critically, **the existing gate cache cannot help here**. 17 of 28 gates declare `@extensions`
as their corpus (3, 5, 6, 7, 8, 11, 12, 13, 17, 18, 19, 20, 21, 23, 24, 26, 28). Any implement
batch that touches a single extension file invalidates all 17, Gate 8 among them. The cache's
headline "a warm, unchanged run cache-skips 17-20 of 24 real gates outright at near-zero cost"
describes an *unchanged* tree — not the end of an implement batch, where the cache hit rate for
precisely the expensive gates is zero.

So narrowing *what Gate 8 runs* is the only lever that reduces its cost in the case that
actually occurs. Caching it is a no-op there.

## Design questions for research

1. **What is the right trigger set?** Gate 8's corpus is `@extensions`, but the selector wants
   *touched paths*. Candidate sources: the gate cache's own corpus-digest machinery already
   resolves and hashes per-path content (`gate_cache_resolve_corpus`,
   `gate_cache_corpus_digest` in `lib/gate-cache-lib.sh`), so a changed-path set may already be
   derivable there rather than needing a fresh git diff.
2. **What is the fallback when selection cannot be computed?** The gate cache's precedent is a
   fail-safe sentinel (`CANNOT_COMPUTE`): an undeclared or unresolvable corpus means the gate
   always runs. Gate 8's narrowing should adopt the same direction — if the covering set cannot
   be resolved, run the full battery, never a silently narrowed one.
3. **Does narrowing break Gate 8's binary-signal property?** `known-failures.txt` rows are
   basename-keyed and mode-insensitive (Settled decision 13). A narrowed run exercises a subset,
   so `--fail-on-new` semantics and the expected/new distinction must be re-derived for a partial
   battery — a suite that did not run is not a suite that passed.
4. **Interaction with the `--skip-slow` reduction.** Settled decision 15 records that the
   redeploy checkpoint already runs `--skip-slow`, leaving 52 of 91 narrow core suites unverified
   against a fresh deploy (CARRIED-UNVERIFIED 2026-11-05). Narrowing by selection and skipping by
   cost class are two different reductions and must not silently compose into a third.
5. **Is a periodic full sweep needed to retain the guarantee?** If Gate 8 normally runs a covering
   subset, something must still run the whole battery on a cadence, or coverage erodes invisibly.
   Where that belongs (the batch gate stage, a cron, an explicit flag) is an open question.

## Territory and ordering

Overlaps the record that makes covering-suite selection resolve a non-core extension's
source-store scripts instead of escalating to a full sweep — same library
(`suite-selection-lib.sh`), adjacent aim. That record fixes a *correctness* hole in the selector
(wrong answer for non-core extensions); this one makes Gate 8 *consume* the selector. A
narrowing built on a selector that still escalates to a full sweep for non-core extensions would
inherit that escalation, so this record takes a `dependencies[]` edge on it and rebases onto its
result.

Also note `run-all.sh` itself is in the declared `file_scope` of two other live records (the
external-source-store sweep record, and the red-Gate-8-suites correctness record). The research
phase must re-check those edges at dispatch time rather than trusting this paragraph.

## Explicitly out of scope

- Deleting, optimizing or demoting individual suites — owned by
  `specs/586_suite_gate_cost_standing_consumer/`.
- Making the batch-gate deferral binding and caching repeat gate runs — owned by
  `specs/585_redundant_gate_run_suppression/`.
- Changing the once-per-invocation batch gate stage's full depth. That stage should stay at full
  depth; see the cache analysis above for why narrowing it by cache is a no-op, and the
  redundant-run record for where caching does pay.
