# Seed Report: Suite and Gate Wall-Clock Cost — Standing Consumer

**Status**: seed, authored at task creation to orient the research phase. Measured 2026-11-10 on
this host (nproc 24). Every figure below is CARRIED-UNVERIFIED and MUST be re-derived before it
is acted on (ROADMAP Settled decision 5, "Verify by execution, not by reading").

## Why this is a standing task, not a stream of point defects

ROADMAP Settled decision 16 governs the shape:

> A systemic cost is filed as one standing task against a probe's output, not a stream of point
> defects. Duplication, dead code and slow tests never break anything, so defect-driven intake
> cannot see them. `script-inventory.sh` has no standing consumer since its own landed
> (re-measured 2026-11-09) — file a new one before the next systemic cost needs somewhere to go.

This record is that standing consumer, on the cost axis rather than the inventory axis. Its
probes are already built and already mechanically generated:

- `agent-system/extensions/core/scripts/measure-gate-costs.sh` -> `gate-cost-model.csv`
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`

Neither has a consumer that acts on its output. Both are read today only for scheduling order
(longest-first dispatch) and for cost-class decisions inside the gate machinery.

## Measured cost distribution

149 suite files on disk; 157 rows in the hint file; **23.5 min total serial wall time**, mean 9.0 s.

| Wall | Suite |
|------|-------|
| 543.0 s | `test-gate-cache-equivalence.sh` |
| 148.6 s | `test-verify-deploy-gate-selection-crash-net.sh` |
| 106.6 s | `test-orchestrate-cycle-plan.sh` |
| 68.1 s | `test-orchestrate-cycle-postflight.sh` |
| 65.6 s | `test-git-commit-scoped.sh` |
| 39.9 s | `test-context-reachability.sh` |
| 38.1 s | `test-claude-refresh-matcher.sh` |
| 36.8 s | `test-verify-deploy-gate-selection.sh` |
| 31.0 s | `test-verify-deploy-context-budget.sh` |
| 23.7 s | `test-literature-convert.sh` |

**The top 10 are 78% of total serial time. One suite alone is 38%.**

Separately, `gate-cost-model.csv` records `gate8 = 662,462 ms` — the shell-suite runner gate is
~11 min by itself, and is the only gate marked cost class `slow`, with a 1500 s timeout.

## The 543 s suite is a knowingly-accepted trade that was never revisited

The archived summary for the input-scoped gate-invalidation work records, in its own words, that
it closed while "honestly reporting gate 8's own full-sweep cost increase (457,197ms ->
662,354ms) as an attributed trade-off from this task's own necessary new equivalence-proof test
coverage."

That equivalence proof is `test-gate-cache-equivalence.sh`, now the most expensive suite in the
battery. The trade bought a real capability — a gate cache trustworthy enough to rely on — and
was declared honestly at the time. What has never been re-examined is whether the proof needs to
cost 543 s. It runs `verify-deploy.sh` twice per case to compare cached against uncached
verdicts, so it inherits the gate cost twice over, across all 18 cache-eligible gates, plus a
per-gate corpus-violation re-run that appends a byte to each gate's last corpus path.

**Territory note**: this file is also declared in the `file_scope` of the record that makes red
Gate 8 suites green or declared-expected — a correctness aim, not a cost aim. This record
carries a `dependencies[]` edge on it so the correctness fix lands first and the cost work
rebases onto it rather than racing it.

## The recursive meta-suite class

**35 of 149 suites re-invoke the full `run-all.sh` or `verify-deploy.sh`** inside a throwaway
fixture copy of the repository:

```
grep -lE "(run-all\.sh|verify-deploy\.sh)" agent-system/extensions/core/scripts/tests/test-*.sh | wc -l
```

Observed live while measuring: `test-gate-cache-equivalence.sh` spawning `verify-deploy.sh
--skip-unchanged --only-gate 10` against `/tmp/tmp.*/fixture`, and `test-run-all-parallel.sh`
spawning a fixture-local `run-all.sh --quiet --jobs 3` that itself dispatched
`test-fixture-slow-b.sh`. Testing the deploy-gate machinery means running the deploy-gate
machinery, so one battery fans out into nested batteries.

### Adjudicated disposition rule for this class

The owner has ruled that this audit **may delete suites outright, not merely optimize or demote
them**, and has settled the discrimination rule:

- **DELETE** when a `verify-deploy.sh` gate already asserts the same property against the real
  tree. The fixture re-proof is redundant with the gate.
- **KEEP** when the fixture reaches a state no gate can: crash nets, stale-lock reclaim,
  nested-invocation behavior, fail-open degradation — states the real tree cannot be put into.

The research phase's primary deliverable is a per-suite verdict table over all 35, each row
citing the gate that covers it (for a DELETE) or naming the unreachable-by-gate state it holds
(for a KEEP).

## Secondary finding: fixture leakage

1,780 leftover `/tmp/tmp.*` directories totalling **1.1 GB**, oldest dated Nov 2 — eight days of
accumulation. Individual fixtures reach 208 MB (full extension-tree copies).

Mechanism: the sampled suites do install cleanup traps (`test-gate-cache-equivalence.sh`,
`test-run-all-parallel.sh`, `test-deploy-propagation.sh` each have one), but `run-all.sh`
dispatches each suite under `timeout -k 5 600`. On timeout that sends SIGTERM then **SIGKILL**,
and SIGKILL does not run an EXIT trap — so every timed-out suite leaks its fixture. `/refresh`
cleans `~/.claude/` and `specs/` but has no `/tmp/tmp.*` reaper, so nothing ever collects these.

This is a mechanical defect with a definite fix rather than a systemic cost. The research phase
should rule on whether it belongs in this record or its own.

## Open questions for research

1. Re-derive every figure above. The hint file is advisory and may be stale; `gate-cost-model.csv`
   carries a per-row `valid` column and an `ALL_VALID` marker that must be checked before any
   cost-class decision is trusted — its own header warns never to trust a non-true `ALL_VALID`.
2. Produce the 35-row DELETE/KEEP verdict table under the rule above.
3. For each of the top 10, decide optimize / demote / delete. For
   `test-gate-cache-equivalence.sh` specifically: can the cached-vs-uncached comparison reuse one
   gate run instead of two full passes, and can the mechanical arm cover a representative
   cross-section rather than all 18 cache-eligible gates (it already distinguishes a mechanical
   arm from a semantic cross-section arm — the semantic arm's own narrowing precedent may apply
   to the mechanical one)?
4. Is a demotion tier available at all? `known-failures.txt` is explicitly NOT it (Settled
   decision 13: advisory, never changes which suites run). An opt-in or periodic tier would be
   new machinery and must be justified, not assumed.
5. Does `--skip-slow` already supply the demotion path? Settled decision 15 records that the
   redeploy checkpoint runs `--skip-slow` and that Gate 8's deployed-tree coverage is knowingly
   reduced on wall-clock grounds, with 52 of 91 narrow core suites unverified against a fresh
   deploy (CARRIED-UNVERIFIED 2026-11-05) — re-measure that ratio before citing it.

## Explicitly out of scope

- Wiring covering-suite selection into Gate 8 — owned by its own record,
  `specs/584_gate8_covering_suite_selection/`.
- Making the batch-gate deferral binding and caching repeat gate runs — owned by its own record,
  `specs/585_redundant_gate_run_suppression/`.
- Making red Gate 8 suites green, which is the correctness record's aim, not this one's.

## The prior attempt, and precisely where it stopped short

The backlog audit matched this record against the archived
`328_systematic_script_and_test_corpus_efficiency` at 50% semantic similarity. That is the
recall-biased over-inclusion the matcher's own header warns about — but the record is genuinely
the closest prior attempt, and the discrimination is worth stating so a future reader does not
re-litigate it.

**What that record optimised for was corpus SIZE, not wall clock.** Its own phase summaries
track `NET-TEST` and `NET-MD` *deletion* deltas: duplicated-block inventories via 5-line
shingling, a 56-suite harness migration collapsing local `pass()/fail()/info()` onto
`lib/common.sh`, 29 occurrences of a `REPO_ROOT` fallback block collapsed to
`common_test_repo_root`, 39 `WORKDIR`/`cleanup()`/`trap` triplets collapsed to
`common_test_workdir_init`. All real, all landed — and none of it reduces runtime, because
deduplicating boilerplate does not make a suite execute less work.

**Its one runtime-touching phase excluded the expensive suites by construction.** Phase 13 built
a shared deployed-tree fixture, constructed once by `run-all.sh` and lent read-only to declared
consumers instead of each consumer rebuilding its own copy — exactly the right instinct. But it
then investigated the realistic consumer set, "found it to be exactly one core suite, not
corpus-wide," and recorded this discriminator:

> The consumer discriminator is "needs a plain deployed tree as inert scaffolding," not "mentions
> `deploy-headless.sh`." A suite whose own job is to verify
> `deploy-headless.sh`/`verify-deploy.sh`'s behavior across distinct invocations (fresh-vs-resync,
> a flag matrix, gate-cache equivalence) is excluded by construction: the variance across
> invocations is what it verifies, and a shared tree cannot substitute without changing that.

That reasoning is sound on its own terms and must not simply be overridden. It is also the exact
reason the expensive suites survived: `test-gate-cache-equivalence.sh` (543 s) and the
`verify-deploy-gate-selection` pair (148.6 s + 36.8 s) are named by that exclusion, and they are
three of the top four costs in the battery.

**So the gap this record addresses is a different question, not a repeat of that one.** Sharing a
fixture cannot help a suite whose purpose is invocation variance. What has never been asked is
whether such a suite needs to exist *at its current cost* — whether its proof can reuse one gate
run instead of two full passes, whether its mechanical arm needs all 18 cache-eligible gates
rather than a representative cross-section, and (the question the owner has now authorised)
whether a given fixture re-proof is redundant with a gate that already asserts the same property
against the real tree, in which case it is deleted rather than optimised.

That authority is the material difference. The prior record had a consolidation mandate; this one
has a deletion mandate.
