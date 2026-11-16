# Research Report: Task #584

**Task**: 584 - Wire covering-suite selection into Gate 8 so an extension change runs the affected suites, not all 149
**Started**: 2026-11-16T00:00:00Z
**Completed**: 2026-11-16T00:00:00Z
**Effort**: medium
**Dependencies**: Task 505 (completed — "Make covering-suite selection resolve a non-core extension's source-store scripts instead of escalating to a full sweep")
**Sources/Inputs**: Codebase (gate-registry.data, suite-selection-lib.sh, verify-deploy.sh, gate-cache-lib.sh, run-all.sh, orchestrate-batch-gate.sh, orchestrate-build-dispatch.sh, batch-gate-stage.md, validate-artifact.sh), state.json/TODO.md for sibling-task territory
**Artifacts**: specs/584_gate8_covering_suite_selection/reports/02_gate8-suite-selection.md
**Standards**: report-format.md, subagent-return.md

## Executive Summary

- Three carried figures re-verified live: the 17-gate `@extensions` set (3,5,6,7,8,11,12,13,17,18,19,20,21,23,24,26,28) is **unchanged and correct**; `grep -c suite_selection verify-deploy.sh` is still **0** (both source-store and deployed copies); gate8's own cost (662,462 ms) in `gate-cost-model.csv` is **unchanged**. One figure has **drifted**: the suite battery is no longer 149 — live discovery across all 23 extensions today counts **195** `test-*.sh` files (narrow + flat), confirmed two ways (manual `find` tally and a re-read of `run-all.sh`'s own discovery loop, which has no suite-count-affecting exclusions beyond excluding itself).
- The selector (`suite_selection_select`) is real, tested, per-extension-aware (task 505, its dependency, is complete), and already load-bearing in `validate-artifact.sh`'s Tier Justification check — confirming the seed report's "proven machinery" premise.
- **Gate 8's own full-depth invocation only ever matters in one place**: `orchestrate-batch-gate.sh`'s Move 4 call (no `--skip-slow`). The only other orchestrator-driven calls to `verify-deploy.sh` (`orchestrate-cycle-plan.sh`'s pre/post findings snapshots) pass `--skip-slow`, which makes `gate8_run()` skip itself entirely before touching `run-all.sh` — those calls get zero benefit from any narrowing inside Gate 8 and should not be a design target.
- **A load-bearing premise in the seed report's own design-question framing does not hold**: the gate cache (`gate-cache-lib.sh`) cannot supply a touched-path list. Its persisted cache entry (`gate_cache_entry_write`) stores only one opaque composite hash per gate, never a per-file hash map — there is nothing to diff against. The only real touched-path source already in this codebase is the orchestrator's `invocation_modified_files` (agent-self-reported `modified_files`, accumulated in `orchestrate-cycle-postflight.sh`), which lives **outside** this task's declared `file_scope`.
- **A concrete, previously-undetected correctness risk**: `verify-deploy.sh`'s generic `--skip-unchanged` cache-write path (around line 2251) writes a cache entry for a gate whenever it ran and reported clean, independent of whether that gate's own internal invocation was narrowed. If Gate 8 is wired to narrow its own `run-all.sh` call via selection, a narrowed-but-clean pass must not be allowed to write a cache entry keyed by the full `@extensions` corpus digest — doing so would make a later unrelated `--skip-unchanged` run skip Gate 8 *entirely*, silently certifying suites that have never actually executed.
- Recommended scope for the plan phase: deliver the selection-aware consumption logic **inside Gate 8 itself** (an opt-in touched-paths input to `gate8_run`, full-sweep fallback on absence/sentinel, and a forced cache-dirty marking whenever narrowing was used) — fully inside this task's declared `file_scope`. Treat *wiring the call site* (passing a touched-path list into `verify-deploy.sh` from `orchestrate-batch-gate.sh`'s Move 4, and/or updating Mechanism A's dispatch directive) as a closely-related but separate follow-on, because the only files where that plumbing lives are already claimed by concurrent sibling task 585 this cycle.

## Context & Scope

This research re-derives the seed report's premises against the live tree and settles the open
design questions it posed, in preparation for a plan that wires `suite_selection_select` into
Gate 8 (`gate8_run()` in `verify-deploy.sh`), which today runs the complete, unnarrowed shell
test battery via `tests/run-all.sh` every time any file under `agent-system/extensions/**`
changes. Scope is bounded to the task's own description and declared `file_scope`:
`gate-registry.data`, `lib/gate-cache-lib.sh`, `lib/suite-selection-lib.sh`,
`tests/run-all.sh`, `verify-deploy.sh`. The actual orchestrator call-site wiring
(`orchestrate-batch-gate.sh`, `orchestrate-build-dispatch.sh`) is explicitly outside that
declared scope and is addressed as a cross-task coordination finding, not implemented here.

## Findings

### Codebase Patterns

**Gate 8 today** (`verify-deploy.sh` `gate8_run()`, lines ~1181-1286): guarded by
`gate_selected 8`; skips if `SKIP_SLOW=true` or the target is a deploy consumer (no
`agent-system/extensions`); otherwise acquires the optional `specs/.gate-lock` mutex and calls

```
bash .../tests/run-all.sh --quiet --jobs "$GATE8_JOBS" --fail-on-new
```

with no `--only`. Discriminates "all passed" (`pass()`) from "all failures declared-expected"
(`warn_advisory()` — deliberately *not* `pass()`, because `pass()` would make the gate
cache-write-eligible under `--skip-unchanged` over a corpus that genuinely has failing suites)
from "NEW failure present" (`fail()`).

**The selector** (`lib/suite-selection-lib.sh`, 646 lines): `suite_selection_select PATH
[PATH...]` returns either the sorted union of covering suite basenames, or the sentinel
`__FULL_SWEEP__` the moment any one touched path is unmappable (fail-safe: never a silent
empty/zero-suite selection). Three mapping strata (self-identity, strict basename pairing,
grep-based reference lookup). Since task 505 (dependency, completed), a touched path naming a
literal `agent-system/extensions/<ext>/scripts/` segment resolves against *that extension's own*
`scripts/`+`scripts/tests/` tree (source-store mode only, detected via the `core/manifest.json`
marker); everything else falls through to the library's own default tree (core, when sourced
from the source store). This matters directly for Gate 8: `run-all.sh` discovers suites across
**all** extension directories (`for ext_dir in "$EXTENSIONS_ROOT"/*/`), not core alone, so a
batch touching files in several extensions needs — and gets, post-505 — correct per-extension
resolution before the union is taken.

**Already load-bearing**: `validate-artifact.sh` (lines 353-826) sources
`suite-selection-lib.sh` lazily and re-derives `suite_selection_select` against a plan phase's
own declared touched paths to check its `**Tier Justification**:` line. This independently
confirms the seed report's "proven machinery, not new invention" framing — directly verified by
reading the call site, not merely cited.

**Where Gate 8's full-depth cost is actually paid.** Three call sites invoke
`verify-deploy.sh`/`deploy_findings_snapshot`:

| Call site | Flags | Gate 8 behavior |
|---|---|---|
| `orchestrate-cycle-plan.sh` (pre/post findings, Inter-Cycle Redeploy Checkpoint) | `--skip-slow` | **Skipped entirely** — `gate8_run()`'s own first branch returns before `run-all.sh` is ever invoked |
| `orchestrate-batch-gate.sh` Move 4 (`deploy_findings_snapshot "$VERIFY_DEPLOY_PATH" "$PROJECT_ROOT"`, two captures) | none (full depth, by design — see `context/contracts/batch-gate-stage.md`) | **Runs the full battery**, unnarrowed |
| Mechanism A's per-dispatch directive (`orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral`) | prose-only; tells the agent to run either `run-all.sh --only SUITE[,...]` directly, or `verify-deploy.sh --only-gate N[,...]` | If the agent chooses `--only-gate 8`, `gate8_run()` still runs the **full, unnarrowed** battery — the directive narrows *which gates run*, never *which suites a selected gate 8 runs internally* |

So the task description's own framing ("the hit rate for precisely the expensive gates is zero
[at the end of an implement batch]") correctly targets Move 4's call in
`orchestrate-batch-gate.sh` as the one place the stated cost is actually paid at full depth with
zero cache benefit — `orchestrate-cycle-plan.sh`'s calls are a red herring (Gate 8 never runs
there) and Mechanism A's `--only-gate 8` option is currently *not* narrow at the suite level even
though its own prose implies a "scoped tier."

**The gate cache cannot supply a touched-path list — the seed report's design question 1 does
not resolve the way it hoped.** `gate_cache_resolve_corpus` (lines 236-322) expands a declared
corpus spec (`@extensions`, `@repo`, literal/glob) into the *current* full file list for that
spec — it says nothing about what changed. `gate_cache_corpus_digest` (lines 341-447) hashes
every one of those files (batched via `git hash-object --stdin-paths`, falling back per-file) and
folds the whole set into **one** aggregate hash. The persisted store
(`gate_cache_entry_write`/`gate_cache_entry_read`, lines 679-761) keeps only `{gate_id,
format_version, key, verdict, timestamp}` — `key` is that one opaque composite hash
(`gate_cache_composite_key`, combining the corpus digest with an implementation digest). There is
no per-path hash retained anywhere, in-memory or on disk, so there is nothing to diff a fresh
resolution against to recover "which paths actually changed." This rules out a self-contained,
gate-cache-only source of touched paths.

**The only real touched-path source already exists, but lives outside this task's file_scope.**
`invocation_modified_files` is a map (task number → array of paths) accumulated in
`orchestrate-cycle-postflight.sh` directly from each agent's own self-reported `modified_files` in
`.return-meta.json` — never reset mid-invocation (unlike `cycle_modified_files`, which the
redeploy checkpoint resets every cycle). It is already read, in full, by
`orchestrate-batch-gate.sh` (`mt_json="$(jq -c '.' "$state_file")"` at line 96, consumed per-task
at line 148) — specifically for attributing confirmed findings back to tasks, *after* the two
Gate 8-inclusive captures at lines 112 and 124. The data needed to narrow Gate 8's Move 4
invocation is therefore sitting in memory one line before the capture call that would benefit
from it; no new state needs to be invented. But `orchestrate-batch-gate.sh` is **not** in task
584's declared `file_scope`.

**Cross-task territory collision (concrete, not merely a Territory-block formality).** Task 585
("Make the batch-gate deferral binding and cache repeat gate runs...") is a concurrent sibling
this same `/orchestrate` cycle (plan phase) and its own declared `file_scope` *does* include
`orchestrate-batch-gate.sh`, `orchestrate-build-dispatch.sh`, and `verify-deploy.sh`. Its own seed
report's design question 2 explicitly anticipates this convergence: "If covering-suite selection
lands in Gate 8 (its own record), the scoped tier and the narrowed gate converge, and Mechanism A
may reduce to 'run the gate, it is already narrow.'" Task 585's seed report also states a settled
stance for Move 4 specifically — "Move 4's once-per-invocation run **keeps full depth**...it is
the batch's only unconditional signal" — but that stance is about *not* applying the
`--skip-unchanged` cache-skip to Move 4 (a different axis: whether the gate runs at all), not
about suite-level narrowing once it does run. The two tasks' aims are compatible but not
identical, and both name the same files.

**A concrete cache-correctness risk, mechanically traced, not hypothesized.** `verify-deploy.sh`'s
generic `--skip-unchanged` cache-write block (around line 2251) is gate-agnostic: for any
selected gate id, if it both ran this invocation (`GATE_RAN_LIST`) and stayed clean
(`GATE_DIRTY_LIST` excludes it), it computes `gate_cache_composite_key` from the gate's
*declared* corpus spec (`@extensions` for Gate 8 — the whole tree) and writes a cache entry. This
check has no knowledge of whether `gate8_run()` internally passed `--only` to `run-all.sh`. If
Gate 8 is wired to narrow and a narrowed run passes cleanly, this generic mechanism would still
write a cache entry claiming the *entire* `@extensions` corpus is verified-green — and a later,
unrelated `--skip-unchanged` invocation with an unchanged corpus would skip Gate 8 **entirely**,
trusting that narrow pass as equivalent to a full-battery pass. Suites outside every subsequent
narrow selection would then never run again until something invalidates the cache entry on an
unrelated basis. This directly answers the seed report's design question 3 ("does narrowing
break Gate 8's binary-signal property?") with a yes, mechanically, via this specific code path —
not merely as a theoretical hygiene concern.

**`--skip-slow` interaction (seed design question 4) is confirmed orthogonal, not composing.**
`gate8_run()`'s `SKIP_SLOW` check is the function's very first branch and returns before
`run-all.sh` is invoked at all. Suite-level narrowing (once wired) only ever matters on the
branch that actually reaches `run-all.sh`. The two reductions therefore cannot silently compose
into a third, undocumented reduction — they gate different, mutually exclusive code paths.

**No periodic/cadence full-sweep mechanism exists today** (seed design question 5). A search for
any nightly/cron/scheduled full-sweep infrastructure in the core scripts and context docs found
no such mechanism — only incidental mentions. If Gate 8's Move 4 invocation is narrowed, nothing
today independently guarantees the full 195-suite battery still runs on some cadence; this would
be new work, not a wiring of something that already exists.

## Recommendations

1. **Give `gate8_run()` an opt-in touched-paths input**, e.g. a new `--gate8-touched
   PATH[,PATH...]` flag (or equivalently-scoped env var, consistent with the
   `VERIFY_DEPLOY_GATE8_JOBS` precedent already in this function) parsed alongside the function's
   existing arg handling. When present and non-empty: source `lib/suite-selection-lib.sh`
   (mirroring `validate-artifact.sh`'s own lazy-source pattern), call `suite_selection_select` over
   the given paths, and if the result is not `SUITE_SELECTION_FULL_SWEEP_SENTINEL`, pass the
   resolved, comma-joined suite list to `run-all.sh --only <list>` (composed with the existing
   `--fail-on-new`). When absent, empty, or the sentinel is returned: invoke `run-all.sh` exactly
   as today, unscoped — byte-identical default behavior for every current caller. This keeps the
   entire change inside this task's declared `file_scope` (`verify-deploy.sh`,
   `suite-selection-lib.sh`; `gate-registry.data`/`gate-cache-lib.sh`/`run-all.sh` affected only by
   the next two recommendations).

2. **Close the cache-correctness gap before shipping any narrowing.** Whenever `gate8_run()`
   actually narrowed via `--only` this invocation (regardless of pass/fail outcome), force it onto
   `GATE_DIRTY_LIST` so the generic `--skip-unchanged` cache-write block at line ~2251 never writes
   a full-corpus-claiming cache entry for a narrowed run. A narrowed Gate 8 pass must never become
   the basis for a future invocation skipping Gate 8 entirely. This is a precondition, not a
   nice-to-have — recommendation 1 without this one reintroduces exactly the silent coverage
   erosion the seed report's design question 3 worried about, via a different and less obvious
   path than selection error (a code path already in production, not a hypothetical one).

3. **Scope narrowing to the call sites that benefit, and be explicit about which call site this
   task actually changes vs. which it only prepares for.** This task's own `file_scope` cannot
   reach `orchestrate-batch-gate.sh` or `orchestrate-build-dispatch.sh`. Recommend the plan phase
   deliver recommendations 1-2 as complete, independently useful, backward-compatible machinery
   (useful immediately for any manual/ad hoc `--gate8-touched` invocation, and for closing the
   "Mechanism A's `--only-gate 8` isn't actually narrow" gap once a caller passes the flag), and
   record an explicit `dependencies[]` edge between 584 and 585 for the plan phase to resolve
   ordering — per the territory block's own instruction ("on an unordered overlap, add the edge
   ... and run as a sequence, not a bare exclusion"). Task 585 already touches
   `orchestrate-batch-gate.sh` for its own purpose and its own seed report explicitly anticipates
   this convergence; it is the natural (though not exclusive) owner of the one-line change that
   actually computes the batch's touched-path union from `invocation_modified_files` and passes it
   through `deploy_findings_snapshot`'s pass-through args to the new flag.
4. **Do not silently narrow Move 4 without an explicit decision on the full-coverage trade-off.**
   Two coherent options exist for whoever wires the Move-4 call site (584+585 jointly, by
   recommendation 3): (a) narrow Move 4 using the whole batch's touched-path union (broader than
   any single dispatch, narrower than the full battery in the overwhelmingly common case, with the
   selector's own fail-safe sentinel still guaranteeing a full sweep whenever any touched path is
   unmappable) while accepting that full-battery coverage is no longer re-certified every batch
   unless a periodic full-sweep cadence is separately built (none exists today — see Finding
   above); or (b) leave Move 4's call unscoped exactly as today (preserving its existing status as
   "the batch's only unconditional signal" with zero coverage trade-off) and ship recommendations
   1-2 purely for Mechanism A / ad hoc use. Given no cadence mechanism exists yet, (b) is the
   lower-risk default for this record; (a) is the higher-payoff option but should be a deliberate,
   named decision in the plan, with the cadence mechanism either included or explicitly deferred
   to a new task — never defaulted into implicitly.
5. **Make a narrowed pass visibly distinguishable in Gate 8's own output.** `pass()`'s message
   ("run-all.sh: all discovered suites passed") should say something different when `--only` was
   used internally (e.g. naming the suite count selected vs. the total discovered), so a reader of
   verify-deploy.sh output is never misled into reading a narrowed pass as full-battery coverage.

## Decisions

- Re-verified and corrected one carried figure: the suite count is **195**, not the seed report's
  149, as of this research (2026-11-16); the 17-gate `@extensions` set and gate8's 662,462 ms cost
  are confirmed unchanged.
- Ruled out the gate cache (`gate-cache-lib.sh`) as a self-contained touched-path source — it
  persists only an opaque aggregate hash per gate, never a per-file breakdown.
- Established that `orchestrate-cycle-plan.sh`'s verify-deploy.sh calls are irrelevant to this
  task's goal (Gate 8 never runs there, due to `--skip-slow`), narrowing the real target to
  `orchestrate-batch-gate.sh`'s Move 4 call and to Mechanism A's `--only-gate 8` option.
- Determined that the consumption-side wiring (new input to `gate8_run()`, selection call,
  fallback, forced-dirty marking) is fully deliverable inside this task's declared `file_scope`,
  while the call-site wiring (actually supplying touched paths from the orchestrator) is not, and
  should be coordinated with task 585 via a `dependencies[]` edge rather than implemented here.

## Risks & Mitigations

- **Risk**: narrowing Gate 8 silently erodes the full-battery coverage guarantee via the generic
  `--skip-unchanged` cache-write path. **Mitigation**: Recommendation 2 (force dirty-list
  membership on any narrowed run, regardless of outcome) — must land in the same change as the
  narrowing itself, not as a follow-on.
- **Risk**: shipping the consumption machinery (recommendation 1) without ever wiring a call site
  to use it looks like "done" but delivers none of the task's stated cost benefit. **Mitigation**:
  state this explicitly in the plan's scope/non-goals, and land the `dependencies[]` edge to 585
  (or an equivalent explicit follow-on task) in the same planning pass, not as an implicit
  assumption.
- **Risk**: `--only`'s own validation (`run-all.sh` line ~432, "unknown suite basename") could
  reject a suite name resolved by `suite_selection_select` if the two scripts' discovery rules
  ever diverge. **Mitigation**: both already share the identical two-location discovery
  convention (`suite-selection-lib.sh`'s own header states it mirrors `run-all.sh`'s discovery
  exactly); no new divergence is introduced by this wiring, but the plan's verification step
  should include at least one multi-extension narrowed `--only` invocation as a smoke test.
- **Risk**: known-failures.txt / `--fail-on-new` semantics over a narrowed run (seed design
  question 3's other half). **Mitigation**: confirmed no interaction bug — `known-failures.txt`
  rows are basename-keyed and only ever consulted for suites that actually ran; a suite narrowed
  out of this run simply contributes nothing to the roster either way, exactly as it would if it
  had passed. The only real risk here is the cache one already covered above, not a
  known-failures/new-failure classification bug.

## Context Extension Recommendations

- **Topic**: Gate 8 / suite-selection convergence across tasks 584 and 585.
- **Gap**: `context/contracts/batch-gate-stage.md` documents Mechanism A/B as they exist today but
  does not yet describe the suite-selection convergence both tasks' seed reports anticipate.
- **Recommendation**: once a plan lands for either task, update `batch-gate-stage.md` with a
  subsection describing how (or whether) Move 4's call became selection-aware, so a future reader
  does not have to reconstruct this cross-task reasoning from two separate task directories.

## Appendix

Search/verification commands used:
```
awk -F'\t' '!/^#/ && NF>=9 {print $1, $9}' agent-system/extensions/core/scripts/gate-registry.data | grep -w '@extensions\|@extensions,'
grep -cE "suite_selection|suite-selection" agent-system/extensions/core/scripts/verify-deploy.sh   # -> 0
grep -cE "suite_selection|suite-selection" .claude/scripts/verify-deploy.sh                        # -> 0
grep -n "^gate8," agent-system/extensions/core/scripts/tests/gate-cost-model.csv                   # -> 662462
for d in agent-system/extensions/*/; do find per-extension test-*.sh via find -maxdepth 1; done    # -> 195 total
```

Files read in full or substantially: `agent-system/extensions/core/scripts/lib/suite-selection-lib.sh`,
`verify-deploy.sh` (gate8_run and the `--skip-unchanged` cache-write block),
`lib/gate-cache-lib.sh` (`gate_cache_resolve_corpus`, `gate_cache_corpus_digest`,
`gate_cache_entry_read/write`), `tests/run-all.sh` (discovery loop, `--only`),
`orchestrate-batch-gate.sh`, `context/contracts/batch-gate-stage.md`,
`orchestrate-build-dispatch.sh`'s `## Batch Gate Deferral` block, `validate-artifact.sh`'s
Tier Justification check, and both tasks' (584, 585) seed reports and `specs/TODO.md`/`state.json`
entries for territory/dependency context.
