# Implementation Summary: Task #416

- **Task**: 416 - Re-aim the verify-deploy gate-framework refactor at the measured cost model,
  and add input-scoped gate invalidation so unchanged gates are SKIPPED rather than merely
  re-walked faster
- **Status**: [COMPLETED]
- **Started**: 2026-10-15T22:50:00Z
- **Completed**: 2026-10-19T06:30:00Z
- **Effort**: ~20 hours across six dispatches (all 13 phases of a 25.5-hour plan)
- **Dependencies**: 411 (completed -- delivered the declarative registry and runner library this
  work extends)
- **Artifacts**: plans/01_input-scoped-gate-invalidation.md
- **Standards**: summary-format.md, status-markers.md, artifact-management.md, tasks.md

## Overview

Across four dispatch rounds, nine of this plan's thirteen phases are now `[COMPLETED]`. Phases
1-5 (prior rounds) landed the core input-scoped invalidation feature itself: a hardened
measurement harness, per-gate input-corpus declarations, a content-addressed digest library, the
gate-8 root-cause verdict, and the `--skip-unchanged` cache store and skip decision -- the
mechanism this task exists to deliver, now functioning end-to-end against the real 23-gate
registry at a 4.4s full-registry consult cost. Round three (phases 6-8) moved to the remaining
gate-set *efficiency* work: Phase 6 replaced a ~120s real-corpus-walking shellcheck acceptance
pair with a fast, deterministic fixture-based dispatch-shape proof and closed the hint-coverage
gap; Phase 7 made the `--skip-unchanged` fast path structurally unreachable from every pre/post
findings-baseline comparison in the codebase, closing the exact correctness hole ("a skip landing
on one side of a baseline diff") the dispatch named as the task's sharpest hazard; Phase 8
measured, then fixed, the two verify-deploy-testing suites' own cost by narrowing one (an 84% cut)
and splitting the other (a genuine, non-narrowable crash net moved to its own schedulable suite).
This round (Phase 9) proved the skip path's CORRECTNESS, not just its mechanism: a new
interface-level regression suite seeds a genuine violation per gate (or, where real execution is
infeasible on evidenced grounds, proves the same property at the composite-key level) across all
22 corpus-bearing gates, and its own development process surfaced and fixed two real,
independently confirmed defects -- a silent cache-wipe bug in `--skip-unchanged` itself (detailed
below) and an unrelated pre-existing lint false positive. Phase 10 re-derived
`JOBS_CAP` on current evidence and retained it at 4, informed by a real measured contention
finding (detailed below). The final three phases closed the task: Phase 11 cut gate 3's own
full-sweep cost ~7.9x (removing a redundant duplicate invocation and parallelizing its
per-extension loop across real child processes); Phase 12 decided, on evidence, to keep gate 8
serialized (`[COMPLETED WITH EXCLUSIONS]` -- an ambient-resource-pressure concern sharpened from
a theoretical CPU-oversubscription framing into a measured, currently-live memory-margin risk,
for a bounded ~14% maximum overlap upside); Phase 13 redeployed the source store, ran the
complete gate set directly (cold and warm `--skip-unchanged` passes), and recorded the task's
headline result: a warm, unchanged run cache-skips 17-20 of 24 real gates outright at near-zero
cost.

## What Changed

Phases 1-5 (prior rounds, carried forward from the previous summary round):
- `agent-system/extensions/core/scripts/measure-gate-costs.sh` — per-run load capture, a
  per-row `valid` column, overwrite protection, a test-only load-sequence seam.
- `agent-system/extensions/core/scripts/gate-registry.data` — the 9th `input_corpus` field,
  populated for all 23 gates.
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` — the `input_corpus`
  loader/accessor and `gate_registry_exclude_ids`.
- `agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` — field-count and
  corpus-grammar checks.
- `agent-system/extensions/core/scripts/lib/gate-cache-lib.sh` — the content-addressed digest
  library and the cache store (`gate_cache_entry_read/write/invalidate`), plus a batched-hashing/
  memoization performance rewrite.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `--skip-unchanged`, the pre-dispatch
  cache-consult loop, `GATE_RAN_LIST`/`GATE_DIRTY_LIST` bookkeeping, the skip-count summary
  clause, and the zero-check-under-filter exemption for an all-cache-skipped selection.
- `.gitignore` — the `**/.gate-cache/` ignore entry.
- Test suites: `test-measure-gate-costs.sh`, `test-gate-registry-resolution.sh` (new),
  `test-gate-cache-lib.sh` (28 cases).

Phase 6 (this round):
- `agent-system/extensions/core/scripts/tests/test-lint-shellcheck-parallel.sh` — the former
  real-corpus acceptance pair (~120s, two full corpus walks) replaced by a fixture-corpus
  dispatch-shape case (a PATH-substituted stub `shellcheck` proves worker-cap honoring and
  one-process-per-file dispatch deterministically, ~2s) plus a fixture-level finding-set
  equivalence case; the real-corpus comparison is preserved, gated behind
  `RUN_REAL_CORPUS_TIMING=1`.
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` — hinted the three
  previously-unhinted suites.
- `agent-system/extensions/core/scripts/tests/run-all.sh` — an advisory hint-coverage `[INFO]`
  line naming any unhinted executing suite.
- `agent-system/extensions/core/scripts/tests/test-check-record-versioning.sh` — a standalone,
  unrelated fix: this file's executable bit was never set when it was added (2026-10-12),
  meaning `run-all.sh` silently `[SKIP]`-ped it (never executed it) ever since. Discovered
  incidentally and fixed in its own commit.

Phase 7 (this round):
- `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` — `deploy_findings_snapshot`
  now filters `--skip-unchanged` out of its own extra-args passthrough unconditionally, with a
  documented header rationale and a non-fatal stderr warning on misuse.
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` — 4 new
  cases/sections: flag-rejection and full-run-despite-warm-cache (via behavior-switching fake
  scripts), and three interface-level fail-open cases (unreadable store, sentinel key,
  `format_version` mismatch) driven against the real `verify-deploy.sh` with an isolated scratch
  target, plus a control case.
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — a new
  "`verify-deploy.sh --skip-unchanged`: the Fast-Path Contract" section.

Phase 8 (this round):
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` — its one
  full-battery baseline capture now runs `--max-cost moderate` (159,191ms -> 25,222ms measured on
  an identical fixture, an 84% cut); header updated to document the new scope.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` — its
  23-gate standalone crash-net case (82% of the suite's cost, not narrowable) split out.
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection-crash-net.sh`
  (new) — the split-out crash net, now its own schedulable suite (~149s).
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` — the three affected rows
  updated from this phase's own direct measurements.
- `agent-system/extensions/core/scripts/tests/run-all.sh` — the stale "~103s-228.6s" straggler
  figure in the `--jobs` rejected-alternatives header corrected to name the current pool's
  longest suite, without pre-empting Phase 10's own `JOBS_CAP` re-derivation.

Phase 9 (this round):
- `agent-system/extensions/core/scripts/tests/test-gate-cache-equivalence.sh` (new) — 17-case
  interface-level regression suite proving `--skip-unchanged`'s real WIRING (not merely
  `gate-cache-lib.sh`'s own digest unit tests): negative case, mtime independence, determinism,
  per-gate mechanical corpus-violation re-run, six representative semantic seeded-violation
  cases spanning every corpus-declaration grammar shape, other-four-component sensitivity, a
  realistic-change-sequence finding-set equivalence proof, and a library-level-only
  composite-key proof for the 3 gates excluded from real execution. ~543s real wall time, 0
  shellcheck findings.
- `agent-system/extensions/core/scripts/verify-deploy.sh` — fixed a real, independently
  confirmed defect this suite's own development surfaced: `--skip-unchanged` combined with any
  `--only-gate`/`--max-cost` selection narrower than the full registry was silently invalidating
  (deleting) every OTHER gate's valid cache entry outside the selection, every single run.
  Reproduced directly (warm gate 1, run `--only-gate 4` alone, gate 1's entry vanished). Fixed by
  gating the post-run write/invalidate block on `gate_selected("$_gate_id")`.
- `agent-system/extensions/core/context/standards/task-reference-exemptions.md` — fixed an
  unrelated, pre-existing `check-task-references.sh` false positive: the file's own illustrative
  example for exemption category 7 was itself unexempted. One-line inline marker fix, same
  convention category 6's own example already used.
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` — hinted the new suite.

Phase 10 (this round):
- `agent-system/extensions/core/scripts/tests/run-all.sh` — header-only rewrite of the
  `JOBS_CAP`-above-4 rejected-alternatives entry to cite current evidence (the 153-row/1,402.17s
  aggregate, the new `test-gate-cache-equivalence.sh` straggler, and the real jobs=4 contention
  measurement), plus a corrected fixture-size figure in the `nproc`-with-no-cap rejection
  (23M excluded / 263M unexcluded, measured). `JOBS_CAP` itself is unchanged (4).

Phase 11:
- `agent-system/extensions/core/scripts/verify-deploy.sh` — `gate3_run`'s redundant second
  `STRICT_CORE_DEPLOY` invocation removed; reconstructed byte-exact from the single normal-mode
  pass's own unconditional `advisory()` echo instead (`advisory()` always echoes "  ADVISORY: "
  and only ADDITIONALLY calls `fail()` under strict mode, so a strict pass's output is always
  exactly the normal pass's output plus one extra "  FAIL: " line per matching advisory line).
- `agent-system/extensions/core/scripts/check-extension-docs.sh` — the per-extension loop now
  forks one real child process per extension (never batched), bounded by `CED_JOBS` (default 4,
  matching `JOBS_CAP`); the parent re-derives `FAILURES`/`EXTENSION_STATUS`/
  `DEPLOY_DRIFT_ADVISORIES`/`_LINES` from captured text (the exhaustive "  FAIL: "/"  ADVISORY: "
  markers), concatenated in discovery order via a zero-padded sequence number per capture file.
- New: `test-gate3-strict-equivalence.sh`, `test-gate3-parallel-equivalence.sh`.
- `suite-cost-hints.txt` — hint rows for both new suites.

Phase 12: no source file changed. Decided, on evidence, to keep gate 8 serialized
(`gate-registry.data` unchanged). See Decisions below.

Phase 13:
- `deploy-headless.sh` run twice (source-store edits redeployed; a manifest-registration gap for
  the two new gate-3 suites discovered and fixed in between).
- `agent-system/extensions/core/manifest.json` — the two new test suites added to
  `provides.scripts` (same gap class this task hit earlier for the gate-cache library).
- `agent-system/extensions/core/scripts/gate-registry.data` — gate 3's `cost_class`/`timeout_s`
  updated `slow`/400s -> `moderate`/60s, from this phase's own measured 16,003ms figure (deferred
  here from Phase 11 exactly as planned).
- `agent-system/extensions/core/context/standards/shell-script-testing.md` — new "Measured
  Before/After" section with the final per-gate table and the incremental-headline narrative.

Progress/handoff artifacts for all thirteen phases: `specs/416_.../progress/phase-{1..13}-progress.json`
(plus `phase-2-corpus-declarations.md`), and `handoffs/phase-{1,2,3,5,6,7,8,9,10,11,12,13}-handoff-*.md`.

## Decisions

Phases 1-5 (carried forward): risk-calibrated corpus declaration confidence; one code path for
content addressing (git-based for two named views, filesystem-based for literal
paths/directories/globs); gate 8's discrepancy has a structural primary cause (one suite's one
nested full-battery call, ~a fifth of the entire suite-pool serial-cost sum); cacheability tracked
via two new plain indexed arrays reconciled through the existing concurrent-batch protocol; the
consult loop must filter through `gate_selected()`; a gate's digest must be computed via batched
git operations and memoization, never per-file subprocess forks.

Phase 6: a PATH-substituted stub `shellcheck` binary (not live-process sampling, which this
repository's own bounded-waiter hook blocks regardless of intent) proves dispatch shape
deterministically without walking the real corpus.

Phase 7: `deploy_findings_snapshot`'s warm-cache-full-run property is provable only via a
behavior-switching fake script (the black-box FINDING-line interface cannot otherwise distinguish
"ran and found nothing" from "skipped and would have found nothing" on a currently-clean gate);
the three interface-level fail-open cases require symlinking the real `agent-system/` tree into
an isolated scratch target, since `gate_cache_implementation_digest` resolves `verify-deploy.sh`
relative to the TARGET root itself.

Phase 8: narrow vs. split, decided by measurement rather than assumption, per suite; the "replace
a remaining nested call with a direct script assertion" task was assessed and explicitly declined
(the remaining calls are dominated by wrapper overhead, and several deliberately test
`verify-deploy.sh`'s OWN mechanisms); a full `measure-gate-costs.sh --regen-hints` pass was
deferred to Phase 13 (it re-measures the entire ~150-suite pool, out of proportion to one phase),
substituted with direct manual updates to the three affected hint rows.

Phase 9: the test fixture is a `git worktree add --detach HEAD` checkout, not an rsync copy, so
the `@extensions`/`@repo` named-view corpus resolvers have real, git-tracked content to walk
(contrast `test-verify-deploy-gate-selection-crash-net.sh`'s deliberately untracked fixture,
which only needs "no crash", never real corpus content). `run_vd()` self-targets (invokes the
fixture's OWN copy of `verify-deploy.sh`, never the live repo's binary against a foreign target)
after discovering that `gate_cache_composite_key`'s "registry row" component is read from the
RUNNING script's own directory, never `$TARGET`'s -- a distinction invisible in real usage
(script and target are always the same tree) but load-bearing for a cross-wired test fixture.
Gate 8's `run-all.sh` is stubbed (Phase 6's own precedent for `lint-shellcheck.sh`, reused here)
so the cache wiring around gate 8 is proven without its real ~457s cost. Gate 22 is excluded
from the suite's two REPEATED mechanical loops (not its own dedicated semantic case) after a
first version measured 604s total, against run-all.sh's own 600s per-suite bound, with gate 22's
real ~54s cost repeated across four-plus invocations; gates 3, 16, and 20 are proven at the
composite-key level only, each for a distinct, evidenced, named reason (manifest-registration
drift this task's own earlier phases introduced; two dispatch-named pre-existing out-of-scope
failures) rather than forced clean in the fixture.

Phase 11: the duplicate-invocation removal and the per-extension parallelization are two
independent, separately-measured wins (dedup alone ~2.1x end-to-end; parallelization alone ~4.2x
further, standalone; combined effect only measurable post-redeploy, per Phase 13). `CED_JOBS`
defaults to 4 (matching `JOBS_CAP`) on direct measurement: jobs=1/2/4/8 measured 58.4s/25.6s/
13.8s/24.3s standalone -- jobs=4 is the wall-clock optimum, jobs=8 regresses from contention,
confirming `JOBS_CAP=4` generalizes beyond `run-all.sh`'s own scheduler.

Phase 12: the cache-store contention audit (atomic `mktemp`+`mv` writes, one disjoint file per
gate id, the one nested `--skip-unchanged` suite fixture-isolated) comes back CLEAR -- it is NOT
the blocking concern. The real blocking concern is ambient MEMORY pressure (this host: 24 cores,
not the constraint; Phase 10's own measured 21,952MB/30GiB peak for gate 8's internal pool alone,
against this phase's own live ~5.3GB-available/7.4GB-swapped host reading), for a measured,
bounded maximum overlap upside of ~14% (gate 8 alone 663s vs. rest-of-pool 107s). See the plan's
own `#### Reasoned Exclusions` record under Phase 12 for the full five-condition admission
argument.

Phase 13: two verification-scope deviations, both Batch-Gate-Deferral-sanctioned or
advisory-degrade-safe, not silent omissions -- a full `suite-cost-hints.txt --regen-hints` pass
(cost disproportionate to its marginal value, left as a follow-up) and repeated full-battery
runs at several worker counts purely to re-confirm determinism Phase 11 and the inherited
framework task already established generically.

## Plan Deviations

- **Unplanned (Phase 4, structural)**: a fourth root cause (recursive gate-tree self-invocation)
  confirmed as primary, as the plan's own text anticipated as a live possibility.
- **Unplanned (Phase 5, performance)**: a real performance defect in Phase 3's own corpus-digest
  implementation found and fixed within the phase (75.6s -> 4.4s for the full consult loop).
- **Unplanned (Phase 5, file scope)**: `gate_registry_exclude_ids` added to
  `gate-registry-lib.sh`, not in Phase 5's own declared file list.
- **Unplanned (Phase 6, out-of-band fix)**: `test-check-record-versioning.sh`'s missing
  executable bit (silently skipping it from every `run-all.sh` run since 2026-10-12) discovered
  and fixed in its own commit, outside Phase 6's declared file list.
- **Altered (Phase 8, hint regeneration)**: `measure-gate-costs.sh --regen-hints`'s full-pool
  pass substituted with direct manual updates to the three affected `suite-cost-hints.txt` rows;
  full regeneration deferred to Phase 13, which already lists that file in its own
  files-to-modify.
- Otherwise followed the plan's own task lists for phases 6-8 without skipping any task; several
  tasks (e.g. Phase 7's "separate the all-skipped-cached outcome" and Phase 8's "replace a
  remaining nested call with a direct assertion") were investigated and found either already
  satisfied by prior work or not applicable, with the reasoning recorded in the plan's own
  checklist annotations rather than silently marked done.
- **Altered (Phase 9, scope-narrowed with evidence)**: of 22 corpus-bearing gates, 18 get full
  real-interface treatment and 3 (gates 3, 16, 20) get composite-key-level-only treatment; gate
  22 is excluded from the two REPEATED mechanical loops (corpus-violation re-run, registry-row
  sensitivity) on measured cost grounds, with its own violation-detection semantics still proven
  for real via a dedicated case. See the plan's own checklist annotations for tasks 9.1 and 9.2,
  and `test-gate-cache-equivalence.sh`'s own header, for the full per-gate reasoning.
- **Unplanned (Phase 9, correctness fix)**: a real `--skip-unchanged` + `--only-gate`/
  `--max-cost` cache-wipe defect found and fixed during this phase's own testing (see What
  Changed above) -- not anticipated by the plan, surfaced only by building the interface-level
  equivalence suite the plan itself required.
- **Unplanned (Phase 9, out-of-band fix)**: an unrelated, pre-existing `check-task-references.sh`
  false positive (the exemption-taxonomy doc's own category-7 example was itself unexempted)
  found and fixed in its own commit, outside Phase 9's declared file list.
- **Altered (Phase 11, task 11.1 drop-condition only partially met)**: gate 3's measurement-first
  task proceeded past the exclusion gate (gate 3 is NOT rarely-executing: 77.5% of real
  implementation commits touch its corpus) rather than closing `[COMPLETED WITH EXCLUSIONS]`.
- **Found not applicable (Phase 11, task 11.4)**: "reuse the shared corpus enumeration" — no
  single re-walk was found to eliminate; the cost was subprocess-spawn overhead evenly spread
  across extensions, already addressed by parallelization.
- **Deferred (Phase 11 -> Phase 13, registry update)**: gate 3's `cost_class`/`timeout_s` update
  deferred to Phase 13's own authoritative post-redeploy measurement rather than set from a
  non-deployed estimate.
- **`[COMPLETED WITH EXCLUSIONS]` (Phase 12)**: gate 8 stays serialized; see this file's
  Decisions section and the plan's own `#### Reasoned Exclusions` record.
- **Unplanned (Phase 13, out-of-band fix)**: a second occurrence of the manifest-registration
  gap (the two new gate-3 test suites not declared in `core`'s `manifest.json`) found and fixed
  in-phase, same class as the earlier gate-cache-library occurrence this task hit before.
- **Deferred (Phase 13, verification-scope)**: `suite-cost-hints.txt` full regeneration, and
  repeated full-battery determinism runs at several worker counts — both per this dispatch's own
  Batch Gate Deferral directive / advisory-degrade-safe reasoning, recorded explicitly.

## Verification

- Build: N/A (shell scripts, no build step)
- Tests (phases 1-5): `test-measure-gate-costs.sh`, `test-gate-registry-resolution.sh`,
  `test-gate-cache-lib.sh` (28 cases) — all pass.
- Tests (Phase 6): `test-lint-shellcheck-parallel.sh` — 14/14 default-path cases pass (~2s, down
  from ~120s); 16/16 with the opt-in real-corpus experiment also run and reconfirmed.
- Tests (Phase 7): `test-deploy-baseline-lib.sh` — 30/30 cases pass, including the two new
  `deploy_findings_snapshot` cases and three new interface-level fail-open cases; the three real
  consumer-covering suites (`test-gate-out-self-attribution.sh`, `test-orchestrate-batch-gate.sh`,
  `test-orchestrate-cycle-plan.sh`) re-verified against the changed library: 3/3 pass, unchanged
  verdicts.
- Tests (Phase 8): `test-verify-deploy-context-budget.sh` — 11 passed, 2 failed, IDENTICAL before
  and after the narrowing (both pre-existing, task-416-unrelated: mid-task source/deploy drift
  and an unrelated eager-load baseline figure). `test-verify-deploy-gate-selection.sh` — 17/17
  pass after the split (down from 18 cases, case(b) moved out). New
  `test-verify-deploy-gate-selection-crash-net.sh` — 1/1 pass (~149s). `test-run-all-selection.sh`
  independently re-verified: 1/1 pass.
- Tests (Phase 9): `test-gate-cache-equivalence.sh` — 17/17 cases pass (~543s real wall time,
  three separate measured runs during development, final version well under run-all.sh's 600s
  per-suite bound). `test-gate-cache-lib.sh` — 28/28 cases still pass (unaffected by the
  verify-deploy.sh fix, since that fix is purely in the --only-gate-selection interaction, not
  the digest library). `lint-gate-registry.sh` — 7/7 pass. `run-all.sh --only` against this
  suite plus its three siblings — 3 passed, this suite's own earlier (pre-fix) run correctly
  reported its real TIMEOUT rather than a false pass, confirming run-all.sh's own per-suite
  bound is enforced, not merely advisory.
- `lint-shellcheck.sh -S warning`: 0 findings across every touched/new file this round.
- Tests (Phase 11): `test-gate3-strict-equivalence.sh` — 5/5 cases pass (0/1/2-violation
  reconstruction equivalence against a live oracle). `test-gate3-parallel-equivalence.sh` — 6/6
  cases pass (byte-identical output and verdict at CED_JOBS=1/2/3/4/8, discovery-order
  preserved, correct FAIL/ADVISORY aggregation). Real-corpus diff (original vs. parallel,
  same live tree): byte-identical. `gate_cache_composite_key 3` pre/post this phase's edit:
  confirmed to differ (`492160bc...` vs `d3e4284b...`), proving cache invalidation.
- Tests (Phase 12): no source change; `test-gate-registry-resolution.sh` re-run clean (32/32).
- Tests (Phase 13): cold full-24-gate `--skip-unchanged` run — 2 failures, both known/unrelated
  (gate 8 EXPECTED flake, gate 10 pre-existing timeout), 20 gates cached green. Warm
  `--skip-unchanged` run immediately after — 17 of those 20 skipped outright
  ("(17 gate(s) skipped -- cached, inputs unchanged)"). Full `run-all.sh` pass — "160 passed, 1
  failed (1 expected, 0 NEW), 0 skipped, 161 total". `lint-gate-registry.sh` — 7/7 pass.
  `lint-shellcheck.sh -S warning` — 0 findings. `check-task-references.sh agent-system` — PASS,
  0 unexempted occurrences. `check-record-versioning.sh agent-system` — 0 BLOCKING.
- Files verified: Yes

## Impacts

- `gate-registry.data`'s 9th field is consumed by a real caller; a future gate addition must
  declare it correctly or it is permanently never cache-eligible.
- `verify-deploy.sh`'s default (flag-absent) behavior is unchanged (byte-identical, proven).
- `deploy_findings_snapshot` is now a choke point that structurally cannot leak `--skip-unchanged`
  to any of its six call sites, present or future — any new findings-baseline comparison added
  later automatically inherits this guarantee without needing its own defense.
- Two of the suite pool's largest members dropped substantially in cost (context-budget: -84% on
  its one full-battery call; gate-selection: its 82%-of-cost case moved to its own suite rather
  than vanishing) — see `shell-script-testing.md`'s eventual Phase 13 per-gate before/after table
  for the whole-pool effect once all phases land.
- **The performance-fix lesson from Phase 5 remains the standing caution for `gate-cache-lib.sh`**:
  any new corpus-scale operation must use the batched-git-operation + memoization pattern, never
  a per-file loop.
- **New standing caution from Phase 8**: `guard-destructive-git.sh`'s over-staging predicate
  refuses `git add -A`/a bare directory pathspec in ANY git repository, including a disposable
  `/tmp` scratch repo unrelated to this project — use an explicit file list
  (`find -type f -print0 | xargs -0 git add --`) for any future scratch-fixture measurement work.
- **Phase 9's cache-wipe fix changes real behavior for every existing caller of `--skip-unchanged
  --only-gate`/`--max-cost`**: before this fix, such a call silently destroyed every other
  gate's warm cache entry; after it, those entries survive untouched. No existing caller in this
  codebase currently passes both flags together (confirmed during Phase 9), so this is a pure
  correctness improvement with no observed behavior change to migrate.
- **New standing caution from Phase 9**: a cache-key-sensitivity or `--skip-unchanged`-wiring
  test MUST self-target (invoke the fixture's own copy of `verify-deploy.sh` against itself),
  never the live repo's binary against a foreign fixture target — the composite key's
  registry-row component is read from the invoking script's own directory, not `$TARGET`'s.
- **Gate 8's own full-sweep cost increased (457,197ms -> 662,354ms), honestly attributed to this
  task's own Phase 9 adding a necessary 543,000ms equivalence-proof suite to the suite corpus
  `run-all.sh` discovers.** This is a measured trade-off, not an oversight, and it sharpens
  rather than undermines the task's value proposition: input-scoped invalidation is precisely
  what makes a full sweep's cost irrelevant on a typical unchanged run.
- **The `JOBS_CAP=4` finding generalizes beyond `tests/run-all.sh`**: Phase 11 found the same
  "raising worker count past 4 regresses from contention" shape for `check-extension-docs.sh`'s
  own new per-extension pool (jobs=8 measured worse than jobs=4), on the same host, for a
  structurally different (subprocess-spawn-heavy, not suite-fixture-heavy) workload.
- **The ambient-resource-pressure rationale for gate 8's serialization is now specifically
  attributed to MEMORY, not CPU cores** (this host has 24 cores; Phase 10 measured gate 8's own
  internal pool peaking at 21,952MB/30GiB) — a future reviewer revisiting this decision should
  re-check `free -h`'s available-memory margin before assuming the conclusion still holds.

## Follow-ups

- **`test-gate-cache-equivalence.sh`'s thin ~543s-vs-600s per-suite timeout margin remains a
  live contention risk on this host** — it was the one known/expected failure in every full
  `run-all.sh` pass this dispatch ran, each time under elevated concurrent-session load. Not
  fixed within this task's own scope (Phase 9's own suite, not re-opened here); a future task
  narrowing or splitting it, the same way Phase 8 handled the two prior stragglers, would reduce
  gate 8's own cost and this contention risk together.
- **`suite-cost-hints.txt` was not fully re-regenerated this task** (Phase 11 added hint rows
  for its own 2 new suites; Phase 13 deliberately deferred a full `--regen-hints` pass as
  disproportionately costly for its marginal value on an already-reasonably-current advisory
  file). A future `/orchestrate` cycle running `measure-gate-costs.sh --regen-hints` on an idle
  host would bring it fully current.
- **Gate 10's pre-existing `specs/state.json --deep` validation timeout** (30s bound, repeatedly
  exceeded during this task's own measurement work, most likely from the repo's own
  multi-session `state.json` growth) remains logged, not fixed, out of this task's `file_scope`.
  See `issues.jsonl`.
- **The `measurement-contention` and `resource contention` issues logged in Phases 10 and 12**
  (costly/minor severity) both describe host-contention-shaped findings, not correctness
  regressions from this task's own work; see `issues.jsonl` for the full detail a future
  reviewer of either decision should read first.
- `gate-registry.data`'s gate 8 `serialized` field is unchanged (`true`); a future revisit of
  Phase 12's decision should start from this file's own `#### Reasoned Exclusions` record under
  Phase 12, not re-derive the sizing analysis from scratch.

## References

- Plan: `specs/416_reaim_gate_cost_model_input_scoped_invalidation/plans/01_input-scoped-gate-invalidation.md`
  (all 13 phases `[COMPLETED]` or `[COMPLETED WITH EXCLUSIONS]`)
- Progress files: `specs/416_.../progress/phase-{1..13}-progress.json`,
  `specs/416_.../progress/phase-2-corpus-declarations.md`
- Handoffs: `specs/416_.../handoffs/phase-{1,2,3,5,6,7,8,9,10,11,12,13}-handoff-*.md`
- Standards: `agent-system/extensions/core/context/standards/shell-script-testing.md` (gate-8
  root-cause verdict section; the `--skip-unchanged` fast-path contract section; the "Measured
  Before/After" section with the final per-gate table)
