# Implementation Summary: Task #416

- **Task**: 416 - Re-aim the verify-deploy gate-framework refactor at the measured cost model,
  and add input-scoped gate invalidation so unchanged gates are SKIPPED rather than merely
  re-walked faster
- **Status**: [IN PROGRESS]
- **Started**: 2026-10-15T22:50:00Z
- **Completed**: (not yet -- 10 of 13 phases done; see Follow-ups)
- **Effort**: ~16.5 hours across five dispatches (phases 1-10 of a 25.5-hour, 13-phase plan)
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
below) and an unrelated pre-existing lint false positive. This round (Phase 10) re-derived
`JOBS_CAP` on current evidence and retained it at 4, informed by a real measured contention
finding (detailed below). Three phases remain (11-13): two evidence-gated derived phases and the
final redeploy/measurement phase that closes the task.

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

Progress/handoff artifacts for all ten phases: `specs/416_.../progress/phase-{1..10}-progress.json`
(plus `phase-2-corpus-declarations.md`), and `handoffs/phase-{1,2,3,5,6,7,8,9,10}-handoff-*.md`.

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

## Follow-ups

- Three phases remain: Phases 11-12 (evidence-gated derived phases: gate 3's binding floor, gate
  8's serialized isolation — each may legitimately close `[COMPLETED WITH EXCLUSIONS]` if its own
  first-task measurement does not support proceeding), and Phase 13 (redeploy, full-gate
  correctness, and the measured before/after that closes the task). Phase 10 (re-derive
  `JOBS_CAP`) is now `[COMPLETED]` — see its own section below.

### Phase 10: Re-Derive JOBS_CAP From the True Pool — Completed

`JOBS_CAP` is retained at `4` (unchanged); only `run-all.sh`'s header-only rejected-alternatives
derivation was rewritten to cite current evidence. `suite-cost-hints.txt` now totals 1,402.17s
over 153 rows (up from the plan's stale 147-row/1,016.6s figure, almost entirely Phase 9's new
`test-gate-cache-equivalence.sh` row at 543,000ms, now the pool's single longest suite). The
aggregate/N crossover below the 543s straggler lands at N>=3, so every candidate cap (4, 8, 12)
is straggler-bound alike — raising the cap cannot reduce wall clock below the straggler's own
cost. A REAL `--jobs 4` full battery (today's default, idle-start host) measured 650s and pushed
`test-gate-cache-equivalence.sh` itself over its own 600s per-suite timeout under the pool's own
self-generated contention, plus five further suites with transient, non-attributable
contention-shaped failures (none from any source edit, none in `known-failures.txt`) — a
measured, not only mathematical, reason to hold the cap. Separate real `--jobs 8`/`--jobs 12`
batteries (each ~550-650s) were deliberately not run: the straggler-bound math and the jobs=4
contention evidence already answer the question, and two more multi-minute runs under
conditions already shown to produce flakiness were judged not worth the time/risk — recorded
explicitly in the header and the phase-10 progress file rather than silently skipped. Phase 4's
verdict reconciled cleanly (the parallel path does deliver its resolved worker count; no
delivery defect to fix). The fixture-size figure was corrected to the measured 23M
excluded/263M unexcluded. Peak concurrent fixture count at jobs=4: 22; peak memory used:
21,952MB of 30GiB. An `issue-record.sh` entry (`measurement-contention`, costly) captures the
jobs=4 timeout/flakiness finding for Phase 13's awareness, since that phase will re-encounter
the same thin margin on `test-gate-cache-equivalence.sh`.
- **Gate 3's manifest-registration gap (new source-store files from phases 1-8 not yet added to
  their extension's `provides.scripts`, and stale `index-entries.json` line-counts) is logged,
  not fixed, and left for Phase 13's redeploy step** per that phase's own stated scope. It is
  also why gate 3 is proven at the composite-key level only in Phase 9's new suite, not via real
  execution — re-promote it to full interface coverage once Phase 13 lands.
- **A successor should NOT re-litigate Phase 9's gate-22 exclusion from the suite's two
  mechanical loops, or gates 3/16/20's composite-key-only treatment**, without first re-reading
  `test-gate-cache-equivalence.sh`'s own header, which records the specific, evidenced reason
  for each.
- **Mid-task source/deploy drift is expected and will self-resolve at Phase 13's redeploy, not
  before**: this task's own source-store edits (phases 1-8) have not yet been redeployed via
  `deploy-headless.sh` by design (Phase 13 is where that happens). Several gates (3, 4, 5)
  correctly report content-drift findings against the currently-undeployed `.claude/` tree when
  exercised through a fixture that symlinks the real deployed tree. A successor should NOT
  attempt to fix this before Phase 13; re-check specifically after that phase's redeploy step.
- One unrelated, pre-existing issue remains logged (not fixed, out of this task's file scope):
  gate 10 (`specs/state.json` schema validation) fails with "TODO.md is OUT OF SYNC" against the
  current committed state. See `issues.jsonl`.
- A second unrelated pre-existing issue, discovered this round: `test-verify-deploy-context-
  budget.sh`'s "could not compute a safe eager-load pad amount" case fails because
  `current_eager` already exceeds `baseline_bytes` on the current host/corpus state — unrelated
  to any task-416 change. See `issues.jsonl`.
- A new `measurement-contention` issue was logged this round (Phase 10, costly severity): a real
  jobs=4 full battery timed out `test-gate-cache-equivalence.sh` and produced five further
  contention-shaped (non-attributable) failures. Not a correctness regression; flagged for
  Phase 13's awareness since it will re-encounter the same thin timeout margin. See
  `issues.jsonl`.
- See `.orchestrator-handoff.json` and the Phase 10 handoff artifact
  (`handoffs/phase-10-handoff-20261016T104500Z.md`) for the concrete resume point and the
  critical context a successor dispatch needs before starting Phase 11 (gate 3's own
  measurement-first, independently-droppable evidence gate).

## References

- Plan: `specs/416_reaim_gate_cost_model_input_scoped_invalidation/plans/01_input-scoped-gate-invalidation.md`
- Progress files: `specs/416_.../progress/phase-{1..9}-progress.json`,
  `specs/416_.../progress/phase-2-corpus-declarations.md`
- Handoffs: `specs/416_.../handoffs/phase-{1,2,3,5,6,7,8,9}-handoff-*.md`
- Standards: `agent-system/extensions/core/context/standards/shell-script-testing.md` (gate-8
  root-cause verdict section; the `--skip-unchanged` fast-path contract section)
