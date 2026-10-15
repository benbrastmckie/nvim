# Implementation Plan: Task #411

- **Task**: 411 - Systematically refactor the verify-deploy gate set and shell test runner into a unified, parallel, declarative gate framework
- **Status**: [IMPLEMENTING]
- **Effort**: 21 hours for this task's own phases (1-11); the retained 12-17 reference
  material carries a further ~12 hours under the cost-model re-aim task
- **Dependencies**: None
- **Research Inputs**: specs/411_refactor_verify_deploy_gate_framework/reports/01_gate-framework-refactor-research.md
- **Artifacts**: plans/01_gate-framework-refactor.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Replace `verify-deploy.sh`'s 23 hand-rolled, strictly-sequential gate blocks with a declarative
gate registry plus one shared runner library, then layer bounded timeouts, gate-level
concurrency, a mechanically-regenerated cost model, and a shared corpus enumeration on top of
it. The edit target is the source store `agent-system/extensions/core/**` (resolved from
`.claude-extensions.json`'s `extensions.core.source_dir` =
`/home/benjamin/.config/nvim/agent-system/extensions/core`); `deploy-headless.sh` runs afterwards.
Definition of done: the complete gate set produces a provably identical finding set at
materially lower wall clock, every gate and suite is bounded by a timeout proven to fire, and
adding a gate is a data edit rather than a 40-line copy-paste.

### Research Integration

The research report is integrated as the plan's primary input, and it materially redirects three
of the dispatch's own premises:

1. **The dispatch's cost table does not reproduce idle, in both directions.** `lint-shellcheck.sh`
   measured 75.9s idle (not 542s), while `lint-scoped-commit-boundary.sh`,
   `lint-directory-pathspec-boundary.sh`, and `lint-task-lookup-adoption.sh` each measured
   *slower* idle than the dispatch's contended figures. A gate absent from the dispatch's cost
   model entirely — Gate 3 (`check-extension-docs.sh`) — measured 124.2s idle, the largest single
   gate cost found. Phase 3 therefore re-derives the cost model mechanically before any
   scheduling design depends on it. (These figures are CARRIED-UNVERIFIED from the research
   report; see Phase 3's Scope Hypothesis.)
2. **Shellcheck parallelization is worth ~1.5x, not ~15x, and only in one shape.** Three batched
   `xargs -P` shapes were all *slower* than sequential; only true one-process-per-file dispatch
   won (50.5s vs 75.9s). Phase 8 implements that shape only and treats the worker-count
   experiment as a repeatable acceptance gate.
3. **The nested-invocation count is 3 sites, not the 12 a textual grep returns — but the
   straggler itself was never cut.** `test-verify-deploy-context-budget.sh` holds 3 distinct
   nested invocation sites (`:175` inside a 3-iteration mode loop, `:189`, `:309`); the figure 12
   is what `grep -c 'verify-deploy\.sh'` returns over that file, which counts comments and the
   binary existence check. The reduction from 4 full-battery calls to 1 full-battery plus
   `--only-gate 20` calls did land. What did **not** happen is any reduction in the suite's cost:
   its hint is 228,595ms, and the expectation that the residual would "shrink automatically" as
   the registry and concurrency work landed is contradicted by that figure. Phase 12 therefore
   exists, and its lever is sharper than splitting the suite — see item 8 below.

Two findings this plan adds beyond the research, established live during planning:

4. **The unanchored-extraction defect spans 14 call sites, not 5+2.** `grep -n "grep -F
   '\[FAIL\]'\|grep -F '\[VIOLATION\]'"` over `verify-deploy.sh` returns 14 hits: 5 `[FAIL]`
   (lines 564, 592, 635, 710, 743) and 9 `[VIOLATION]` (674, 775, 909, 974, 1006, 1038, 1182,
   1212, 1248).
5. **The dispatch's prescribed fix, applied uniformly, would silently break 12 of those 14
   sites.** 12 of the 14 producers emit their verdict rows as
   `echo -e "${RED}[FAIL]${NC} ..."` / `echo -e "${RED}[VIOLATION]${NC} ..."` with **no TTY or
   `NO_COLOR` guard**, so each line begins with an ANSI SGR escape sequence, not the literal
   token. Only `lint-shellcheck.sh` (`echo "[VIOLATION] $line"`) and `tests/run-all.sh`
   (`echo "[FAIL] $suite_name"`) emit genuinely line-initial tokens. A uniform
   `grep -E '^\[FAIL\] '` would therefore convert 12 real gates into silent zero-finding gates
   while looking like a hardening fix — the mirror image of the dispatch's own "a faster gate that
   checks less is a regression" prohibition. The shared helper must **strip SGR sequences first,
   then anchor**, and per-site finding-set equivalence is what proves no gate went quietly blind.

### Revision Evidence

Phases 1-10 landed. The efficiency goal did not follow from them, and the measurements the landed
work itself produced are what show why. All figures below come from artifacts already in this
repository and were re-confirmed against the source store during this revision.

6. **The dispatch's premise figures are void, and the honest baseline is smaller and differently
   shaped.** `progress/phase-3-gate-cost-model.csv` (idle, `1min_load_at_start=1.03`, 2 runs
   averaged) sums to ~694s (11.6 min) for the whole gate set, not the dispatch's 22-28 minutes.
   Its concentration is `gate8` 457,197ms (66%), `gate3` 125,669ms (18%), `gate22` 54,716ms (8%),
   and everything else together under 57s. Every premise derived from "shellcheck is 542s and 40%
   of the set" is therefore void: shellcheck is the third cost centre, not the first.

7. **The headline optimization was real and small.** `lint-shellcheck.sh`'s header records P=1
   75.8s, P=4 50.4s, P=8 42.0s, P=12 38.4s, and ships `SHELLCHECK_JOBS=8`. Against the 54.7s idle
   baseline that is roughly 13 seconds off an 11.6-minute run — about 2% — which is what a 1.5x
   win on an 8% gate can be worth.

8. **Gate 8's cost survives because `--skip-slow` defers gate 8 only.** `verify-deploy.sh:854-855`
   shows `--skip-slow` deferring the shell-suite gate and nothing else, so every nested
   `--skip-slow` full-battery `verify-deploy.sh` call inside gate 8's own suites still pays gate 3
   (~125s) and gate 22 (~55s) against its fixture. The context-budget suite's one remaining
   full-battery baseline capture (`:189`) is ~180s on that arithmetic, which accounts for nearly
   all of its 228,595ms hint. `test-verify-deploy-gate-selection.sh` costs a further 160,340ms
   across 8 nested invocations. Those two suites are ~38% of the pool, and both are verify-deploy
   testing verify-deploy. The fixture build is not the driver: the rsynced tree is 22M with the
   `literature-pyenv` exclude already in place (242M of the 262M tree is `literature/`).

9. **`JOBS_CAP` is now the binding constraint, contrary to the premise and to `run-all.sh`'s own
   header.** The hint file totals 1,016,638ms across 147 rows, not the 356.6s the header's
   rejected-alternatives entry reasons from. At `JOBS_CAP=4` (`run-all.sh:229`) the pool is
   work-bound at ~254s against a 228.6s longest straggler — not straggler-bound as that entry
   concludes. Phase 14 re-derives the cap from the post-Phase-12/13 pool; the header's two
   resource-shaped rejections (a bare `nproc`; a self-maintaining timing cache) are untouched by
   this arithmetic and stand.

10. **The refactor added cost to gate 8 and left it unmeasurable.**
    `test-lint-shellcheck-parallel.sh:72` and `:78` each run `lint-shellcheck.sh --quiet` with no
    target — the real ~381-file corpus — once at `SHELLCHECK_JOBS=1` and once at the parallel
    default, roughly 118s of production-corpus walking inside a unit test that runs inside gate 8.
    That suite is unhinted, as are `test-gate-registry-resolution.sh` and
    `test-check-record-versioning.sh`, so longest-first scheduling cannot see any of them.

11. **Gate 3 is the floor the moment gate 8 drops.** Gate 8 is the single `serialized=true` row in
    `gate-registry.data`, and `lib/gate-registry-lib.sh`'s wave contract runs the serialized class
    alone and strictly before the pool. The whole-set wall clock is therefore gate 8 **plus** the
    pool's wall, and the pool's wall is its own longest member — gate 3 at 125.7s. Phases 16 and
    17 follow from this and are flagged in their own text as derived additions beyond the four
    areas the revision brief enumerated.

12. **The measurement harness is better than reported but still cannot invalidate itself.**
    `measure-gate-costs.sh` does carry a post-measurement load guard (`:265`), not only a
    start-of-run one — but it emits a WARNING to stderr and leaves the written CSV unmarked, so a
    contaminated sample is mechanically indistinguishable from a clean one, and contention that
    starts and subsides mid-run is invisible to both end checks. Phase 15 is scoped to per-gate
    capture and artifact-level validity marking rather than to adding a post-run check that
    already exists.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch; ROADMAP.md was not consulted.

## Goals & Non-Goals

**Goals**:
- One declarative gate registry (name, command, dependencies, timeout, cost class, remedy text,
  source-store requirement) consumed by one shared runner library; adding a gate becomes a data
  edit.
- One shared, SGR-stripping, anchored verdict-line extraction helper replacing all 14 unanchored
  `grep -F` call sites, with per-site finding-set equivalence proven.
- Gate-level concurrency with declared dependencies, ported in shape from `run-all.sh`'s proven
  scheduler, preserving deterministic discovery-order output and a stable summary line at every
  worker count.
- Uniform bounded timeout per gate and per suite, with a deliberately-stalled fixture proving each
  fires.
- A mechanically regenerated cost model as the single source of truth, replacing the hand-curated
  `suite-cost-hints.txt` snapshot and the dispatch's stale prose table.
- One corpus enumeration per invocation, shared by every gate that needs it, with each gate
  deriving its own filtered view.
- `run-all.sh` default flipped from `JOBS=1` to `auto`, with `--jobs 1` preserved as the
  byte-identical sequential opt-out.
- Selection by cost class generalized onto the registry alongside `--skip-slow` and `--only-gate`.
- The two verify-deploy-testing suites that make up ~38% of the suite pool reduced by narrowing
  their nested invocations to the gates their assertions actually read.
- `JOBS_CAP` set from the measured pool rather than from a figure 2.9x too small.
- No unit test walking the production corpus, and every discovered suite hinted so longest-first
  scheduling is not blind.
- A measurement harness that marks its own samples invalid when contention touches them.
- Gate 3 reduced once it becomes the binding floor, and gate 8's serialized isolation decided on a
  measured audit rather than inherited.

**Non-Goals**:
- Fixing the three known pre-existing failures (Gate 3 lean4 doc-lint index.json entry; Gate 20
  eager-load budget ~988B overage; the Gate 8 suites `test-detect-noop-bash.sh`,
  `test-four-tier-conflict.sh`, `test-guard-git-push.sh`). They are baselined, not repaired.
- Weakening any gate's assertion for speed, in any amount.
- Weakening any suite's assertions to cut its cost. Phase 12 narrows which gates a nested
  invocation runs; it does not narrow what a case proves.
- Raising `JOBS_CAP` without re-deriving it. Phase 14 sets it from the measured post-Phase-12/13
  pool and from peak disk and memory at the candidate cap, and leaves it at 4 if that evidence
  says so.
- Deleting the real-corpus shellcheck timing experiment. Phase 13 makes it opt-in; it remains the
  standing evidence that parallel dispatch is a win.
- Fixing the three known pre-existing failures, under any phase added in this revision.
- Changing `orchestrate-batch-gate.sh`'s per-batch frequency logic; it is complementary and must
  simply keep working.
- Adding colorization guards to the 12 producers as the *primary* fix. The consumer must anchor
  robustly; producer-side prose discipline is the defence that already failed.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A uniform line-start anchor silently zeroes 12 ANSI-colored producers' findings | H | H | Phase 1's helper strips SGR before anchoring; Phase 2 proves per-site finding-set equivalence against a pre-change capture for all 14 sites, with a seeded violation per site so a zero-finding regression cannot pass |
| Re-derived cost model shows Gate 3 or the 6/7/9/10/11/21/23 cluster dominates, not Gate 22 | M | M | Phase 3 is a decision gate placed before registry scheduling design and before Phase 8; its output, not the dispatch's table, assigns cost classes |
| Shellcheck worker count chosen without re-running the experiment regresses wall time (3 of 4 shapes did) | M | M | Phase 8 treats the experiment as a required repeatable acceptance gate; one-process-per-file is the load-bearing choice, not the exact count |
| Concurrent gates hit a resource collision `run-all.sh`'s suite-level audit never considered (Gate 20 fixtures, Gate 13's headless nvim) | H | M | Phase 7 performs an explicit per-gate parallelism-safety audit and extends `LOAD_SENSITIVE_BASENAMES`' discipline to a gate-level serialized class rather than inventing a parallel notion |
| Registry migration changes `verify-deploy.sh`'s exit codes or output shape, breaking `deploy_findings_snapshot`'s five callers (one of which gates whether a batch proceeds) | H | M | Phases 4/5 require byte-identical captured output as the acceptance criterion; Phase 5 re-verifies each of the five callers explicitly, including that a pre/post baseline comparison cannot be skewed by a row present in one capture only |
| A mis-sized timeout fires spuriously on an existing slow gate or suite | M | M | Phase 6 sizes bounds from Phase 3's measured maxima with explicit headroom, then runs the complete battery to confirm no existing gate or suite trips its bound |
| Shared corpus enumeration produces one list that does not satisfy every gate's differing filter (`*.sh`, `*.md`, `*.json`, `SKILL.md`, `manifest.json`) | M | M | Phase 9 produces a master tracked-path list and gives each gate its own derived filtered view; finding-set equivalence is proven per affected gate, not in aggregate |
| Interruption mid-migration leaves `verify-deploy.sh` half-registry, half-inline | M | L | Phases 4 and 5 split the migration at a boundary where the legacy path still runs the unmigrated gates, so an interrupted state is functional rather than broken |
| Narrowing a nested invocation's gate selection silently stops a case proving what it names | H | M | Phase 12 records per case which gates it reads and why the narrowed selection covers them, and requires an unchanged case count with identical per-case verdicts against a pre-change capture |
| Raising `JOBS_CAP` trips the peak disk or memory ceiling the existing rejection was actually about | M | M | Phase 14 measures peak memory and the concurrent-fixture count at the candidate cap, and treats the two resource-shaped rejections separately from the arithmetic one it refutes |
| Replacing the shellcheck wall-clock ratio gate with a dispatch-shape assertion loses the evidence that parallel is still faster | M | M | Phase 13 keeps the real-corpus experiment as an explicit opt-in rather than deleting it, and the default path asserts observed concurrency directly |
| Phase 16 optimizes gate 3 after it has stopped being the floor, spending effort for no wall-clock gain | M | M | Phase 16's first task is the measurement that decides whether it proceeds; a negative result closes it as `[COMPLETED WITH EXCLUSIONS]` with that measurement as Evidence |
| Overlapping gate 8 with the pool causes a nested `verify-deploy.sh` run and a concurrent pool gate to collide on the source store | H | M | Phase 17 audits that specific hazard before changing the field, keeps gate 8 serialized if the collision cannot be resolved, and expresses either outcome as one registry field so no half-applied state exists |
| The final measurement is contaminated and read as a regression, or a contaminated sample is read as a win | H | M | Phase 15 lands before the final phase and makes validity a property of the artifact; the final phase measures once, quiet, through that hardened harness |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1, 3 | -- |
| 2 | 2 | 1 |
| 3 | 4, 8 | 2, 3 |
| 4 | 5 | 4 |
| 5 | 6 | 5 |
| 6 | 7, 10 | 6 |
| 7 | 9 | 7 |
| 8 | 12, 13, 15 | 10 |
| 9 | 14 | 12, 13 |
| 10 | 16 | 12, 13, 14, 15 |
| 11 | 17 | 14, 16 |
| 12 | 11 | 12, 13, 14, 15, 16, 17 |

Phases within the same wave can execute in parallel.

Phase 11 keeps its number and appears last in this document because the phases added in this
revision all execute before it: it is the single final measurement pass, taken once on a quiet
host after every cost change has landed. Document order below is therefore 1-10, 12-17, 11, and
the wave table above is the authority on execution order.

---

### Phase 1: Anchored Verdict-Line Extraction Helper and the Gate 8 Fix [COMPLETED]

**Goal**: Land the dispatch's independently-landable Gate 8 correctness fix behind one shared,
SGR-stripping, anchored extraction helper, and state the producer/consumer contract once where
both sides can cite it.

**Tasks**:
- [x] *(completed)* Add `verify_deploy_extract_verdict_lines()` to a sourced library under
      `scripts/lib/` (new file `gate-verdict-extract-lib.sh`, following
      `manifest-routing-lib.sh`'s contract discipline: never calls `exit`, sets no shell options a
      caller inherits, unsets internal variables before returning). Signature takes the producer
      output and the anchor token as an **explicit parameter** — never inferred.
- [x] *(completed)* Implement the two-step extraction: strip ANSI SGR sequences (`\x1b\[[0-9;]*m`) from each
      line, then select with a line-initial anchor (`grep -E '^\[FAIL\] '` /
      `'^\[VIOLATION\] '`), then strip the token prefix.
- [x] *(completed)* Record the contract once, in `context/standards/shell-script-testing.md`: producers emit
      verdict rows line-initial (modulo SGR); narration uses a distinct prefix
      (`[run-all] [PASS] ...`); consumers strip SGR and anchor. Keep `run-all.sh`'s existing
      roster-block constraint comment but record that it is no longer the load-bearing defence.
- [x] *(completed)* Repoint Gate 8's extraction (verify-deploy.sh:635) at the helper.
- [x] *(completed: added 4 cases to each of test-deploy-baseline-lib.sh and test-orchestrate-batch-gate.sh)* Add the three regression cases to `scripts/tests/test-orchestrate-batch-gate.sh` and
      `scripts/tests/test-deploy-baseline-lib.sh`: a line-initial `[FAIL] <path>` IS selected; a
      `[PASS]` line quoting `[FAIL]` in its message is NOT; an indented fixture-internal `[FAIL]`
      is NOT. Add a fourth: an SGR-prefixed `[FAIL]` row IS selected.
- [x] *(completed)* Add the producer-side pinning case to `scripts/tests/test-run-all-selection.sh` fixing
      `run-all.sh`'s emitted `^[FAIL] <suite>` shape.
- [x] *(completed: after-only live capture -- see progress file note; before-shape proven via unit regression cases reproducing the incident text verbatim)* Capture `verify-deploy.sh --only-gate 8 --findings --quiet <source_dir>` before and after;
      confirm the confirmed-finding count collapses to the true failing-suite count and that no
      `[PASS]` row survives.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts Gate 8's extraction sits at `verify-deploy.sh:635` and
that its real failing-suite count is 4 against 13 reported confirmed findings (the latter carried
from the dispatch's own measured batch-gate run). Confirm at implementation time by re-running
`grep -n "grep -F '\[FAIL\]'" <source_dir>/scripts/verify-deploy.sh` (line numbers drift on every
edit) and by diffing the before/after `--only-gate 8 --findings` captures rather than trusting the
carried 13/4 figures.

**Tier Justification**: `bash <source_dir>/scripts/tests/run-all.sh --only
test-orchestrate-batch-gate.sh,test-deploy-baseline-lib.sh,test-run-all-selection.sh` plus
`bash <source_dir>/scripts/verify-deploy.sh --only-gate 8 --findings --quiet <source_dir>` is the
complete covering check — the change is confined to Gate 8's extraction step and the new library,
whose enumerated direct dependents are exactly those three suites and that one gate.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/gate-verdict-extract-lib.sh` - new sourced library holding the SGR-stripping anchored extraction helper
- `agent-system/extensions/core/scripts/verify-deploy.sh` - source the library; repoint Gate 8's extraction
- `agent-system/extensions/core/scripts/tests/run-all.sh` - roster-constraint comment records it is no longer load-bearing
- `agent-system/extensions/core/scripts/tests/test-orchestrate-batch-gate.sh` - four selection regression cases
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` - consumer-side anchored-selection cases
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` - producer-side shape-pinning case
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - state the verdict-row contract once

**Verification**:
- `bash <source_dir>/scripts/tests/run-all.sh --only test-orchestrate-batch-gate.sh,test-deploy-baseline-lib.sh,test-run-all-selection.sh` exits 0
- Before/after `--only-gate 8 --findings --quiet` captures show no `[PASS]` row and no indented
  fixture-internal row in the after capture, and every genuinely failing suite still present
- Exit status of each invoked command is checked, not only its stdout diff

---

### Phase 2: Generalize Anchored Extraction to the Remaining 13 Call Sites [COMPLETED]

**Goal**: Apply the same helper to the other 13 unanchored sites, proving per-site finding-set
equivalence so that none of the 12 ANSI-colored producers silently goes to zero findings.

**Tasks**:
- [x] *(completed: re-derived live per the Scope Hypothesis -- the real 9 [VIOLATION] gates are 9, 12, 15, 17, 18, 19, 21, 22, 23; gate 16 was not an extraction site at all and this checklist item's draft listing of it was a planning-time inaccuracy, corrected at implementation time)* Repoint the remaining four `[FAIL]` sites (gates 6, 7, 10, 11) and all nine `[VIOLATION]`
      sites (gates 9, 12, 15, 17, 18, 19, 21, 22, 23) at the helper, passing each site's anchor token explicitly.
- [x] *(completed: 14/14 identical; see progress/phase-2-captures/)* For each of the 14 sites: capture `--only-gate N --findings --quiet <source_dir>` before and
      after and assert the finding sets are identical.
- [x] *(deviation: altered -- see progress file phase-2-progress.json deviation 2.3; live per-site seeding into the shared repo replaced by a layered unit+shape-audit+live-finding proof)* For each of the 14 sites: seed one deliberate violation in a scratch fixture, confirm the
      gate reports it both before and after. A site whose seeded violation is reported before but
      not after is a silent-blinding regression and blocks the phase.
- [x] *(completed: Case 23 in test-deploy-baseline-lib.sh)* Add a per-site pinning case asserting SGR-prefixed verdict rows are selected, so a future
      producer that gains or loses color cannot regress the consumer silently.
- [x] *(completed: already recorded in the helper's header at Phase 1)* Record in the helper's header that the anchor token is always an explicit parameter and why
      inference is prohibited (the `[FAIL]` vs `[VIOLATION]` token sets are disjoint and
      per-producer).

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts exactly 14 unanchored extraction call sites (5 `[FAIL]`
at verify-deploy.sh:564/592/635/710/743; 9 `[VIOLATION]` at 674/775/909/974/1006/1038/1182/1212/1248)
and that 12 of the 14 producers emit SGR-colored verdict rows with no TTY guard. Both figures were
re-derived live during planning. Confirm at implementation time by re-running
`grep -n "grep -F '\[FAIL\]'\|grep -F '\[VIOLATION\]'" <source_dir>/scripts/verify-deploy.sh` and
`grep -c 'echo -e "${RED}\[\(FAIL\|VIOLATION\)\]${NC}'` across the 13 producer scripts; line
numbers will have drifted after Phase 1.

**Tier Justification**: `bash <source_dir>/scripts/verify-deploy.sh --only-gate
6,7,9,10,11,12,15,16,17,18,19,21,22,23 --findings --quiet <source_dir>` diffed against a
pre-change capture, plus the three suites from Phase 1, is the complete covering check — the
change is confined to each gate's extraction step, and the enumerated gate subset is exactly the
affected dependent set.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - repoint the remaining 13 extraction sites
- `agent-system/extensions/core/scripts/lib/gate-verdict-extract-lib.sh` - header records the explicit-token-parameter rule
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` - per-site SGR-prefix selection cases

**Verification**:
- 14/14 before/after `--only-gate N --findings` captures identical
- 14/14 seeded violations still reported after the change
- `bash <source_dir>/scripts/tests/run-all.sh --only test-deploy-baseline-lib.sh,test-orchestrate-batch-gate.sh,test-run-all-selection.sh` exits 0

---

### Phase 3: Mechanical Idle Cost Re-Baseline (Decision Gate) [COMPLETED]

**Goal**: Replace the dispatch's stale prose cost table and the hand-curated
`suite-cost-hints.txt` snapshot with one mechanically regenerated cost model, measured idle and
averaged, and use it to assign each gate a cost class. This is a decision gate: its output, not
the dispatch's numbers, drives Phases 4-9's prioritization.

**Tasks**:
- [x] *(deviation: altered -- date +%s%3N wall-clock delta used instead of /usr/bin/time, which does not exist on this NixOS host; see progress file)* Add `scripts/measure-gate-costs.sh`: for each gate id, run
      `verify-deploy.sh --only-gate N <target>` under `/usr/bin/time`, at least twice, emit a
      machine-readable per-gate cost row.
- [x] *(completed: checked both pre- and post-measurement; live-demonstrated firing correctly during a real contention spike to load 50+)* Guard the harness: refuse to record a measurement taken at 1-minute load average above a
      declared threshold (~2 on this 24-core host), printing the observed load. A contended figure
      is wrong in either direction, not merely inflated.
- [x] *(completed: gate-cost-model.csv clean/idle; suite-cost-hints.txt regenerated with a documented tail-contamination caveat on one suite's figure -- see progress file)* Emit the per-gate cost model to a generated data file consumed by the registry (Phase 4),
      and regenerate `suite-cost-hints.txt` from `run-all.sh --timings` through the same harness
      so the suite half of the model stops being a one-shot human snapshot.
- [x] *(completed: free<=2000ms, moderate<=30000ms, slow>30000ms, stated once in measure-gate-costs.sh's header)* Assign each gate a cost class (e.g. `free`/`moderate`/`slow`) from measured values, with the
      class boundaries stated in the harness header rather than scattered.
- [x] *(completed: see progress/phase-3-gate-cost-model.csv and progress file objective 5 note for the full table)* Take the measurement, idle, and record the resulting table. Explicitly include Gate 3
      (absent from the dispatch's model) and itemize the 6/7/9/10/11/21/23 cluster the research
      measured only in aggregate.
- [x] *(completed: 8/8 cases passing)* Add `scripts/tests/test-measure-gate-costs.sh` covering the load guard, the two-run
      averaging, and the unhinted-suite append invariant.
- [x] *(completed: live-demonstrated by this same phase's own 50+ load contention episode and the hints-file tail-contamination caveat)* Record the measurement-discipline guidance the research recommended in
      `context/standards/shell-script-testing.md`: a cost claim cited as justification carries the
      load average at measurement time, and a figure taken above the threshold is invalid for
      prioritization until re-taken idle.

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts 23 named gates (gate blocks `gate1`..`gate23` plus a
`gate0` preamble, confirmed live via `grep -n 'CURRENT_GATE=' verify-deploy.sh`) and carries the
research report's idle figures — shellcheck 75.9s, Gate 3 124.2s, the 7-gate cluster 51.6s, the
`test-verify-deploy-context-budget.sh` straggler 103.0s — as **CARRIED-UNVERIFIED** from
`specs/411_refactor_verify_deploy_gate_framework/reports/01_gate-framework-refactor-research.md`.
This phase's own measurement IS the re-derivation: none of those carried figures may be used for
cost-class assignment, only the harness's fresh output.

**Tier Justification**: `bash <source_dir>/scripts/tests/run-all.sh --only
test-measure-gate-costs.sh` plus `bash <source_dir>/scripts/lint/lint-shellcheck.sh` scoped to
the new script is the complete covering check — this phase adds a new standalone measurement
script and a generated data file and changes no existing gate's behavior or signature.

**Files to modify**:
- `agent-system/extensions/core/scripts/measure-gate-costs.sh` - new measurement harness with load guard and averaging
- `agent-system/extensions/core/scripts/tests/test-measure-gate-costs.sh` - new suite for the harness invariants
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - regenerated mechanically rather than hand-curated
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - measurement-discipline guidance

**Verification**:
- `bash <source_dir>/scripts/tests/run-all.sh --only test-measure-gate-costs.sh` exits 0
- The harness refuses, loudly and with the observed load printed, when run above the load
  threshold
- Every discovered suite appears exactly once in the regenerated hints file (none dropped,
  duplicated, or silently reordered away)
- A per-gate cost table exists for all 23 gates, Gate 3 included

---

### Phase 4: Gate Registry Schema, Shared Runner Library, and Migration of Gates 1-8 [COMPLETED]

**Goal**: Introduce the declarative registry and its sequential shared runner, and migrate the
first tranche of gates onto it with byte-identical output, leaving the unmigrated gates on the
legacy path so an interrupted state stays functional.

**Tasks**:
- [x] *(completed: gate-registry.data, 8 TSV fields per row)* Define the registry data shape on the `manifest-routing-lib.sh` precedent: structured data
      declaration plus one shared sourced interpreter. Fields per gate: id, name, command,
      dependencies, timeout, cost class, remedy text, `requires_source_store`, anchor token,
      serialized-class flag.
- [x] *(deviation: altered -- gate_registry_execute calls the gate's function directly in-process, preserving identical say/pass/fail/FINDINGS_LIST shapes since each function's own body is unchanged; per-gate CURRENT_GATE scoping is deferred as a documented Phase 7 prerequisite, not attempted here)* Add `scripts/lib/gate-registry-lib.sh`: parses the registry, resolves selection, and
      executes one gate, emitting the same `say`/`pass`/`fail`/`warn` shapes and populating
      `FINDINGS_LIST` through Phase 1's extraction helper. Per-gate state must be scoped (subshell
      or associative array keyed by gate id) rather than relying on a single reassigned
      `CURRENT_GATE` global — a prerequisite for Phase 7's concurrency.
- [x] *(deviation: altered -- declared as accurate metadata only, not code-folded; see progress file deviation 4.3)* Fold the repeated source-store-only guard
      (`[ ! -d "$TARGET/agent-system/extensions" ] && say "[SKIP] ..."`) into the
      `requires_source_store` registry field.
- [x] *(completed)* Migrate gates 1-8 onto the registry; leave gates 9-23 on the legacy inline path.
- [x] *(completed: 5/5 lint checks, 10/10 resolution-test cases passing; 4 seeded violations confirmed caught)* Add `scripts/lint/lint-gate-registry.sh` validating the registry data (every declared
      dependency exists, no cycle, every gate has a timeout and cost class, ids are unique and
      contiguous) and `scripts/tests/test-gate-registry-resolution.sh` for the interpreter — the
      lint-plus-resolution-test pattern `manifest-routing-lib.sh` already establishes.
- [x] *(completed: byte-identical stdout, stderr, and exit code rc=1 confirmed)* Capture `--only-gate 1,2,3,4,5,6,7,8` output before and after; require byte-identical
      stdout/stderr and identical exit code.

**Timing**: 2 hours

**Depends on**: 2, 3

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the registry can express gates 1-8 without a per-gate
escape hatch. Confirm at implementation time by requiring byte-identical
`--only-gate 1,...,8` captures; a gate that needs bespoke inline logic to reproduce its output is
a counterexample to the hypothesis and must be recorded as such rather than special-cased
silently.

**Tier Justification**: `bash <source_dir>/scripts/verify-deploy.sh --only-gate 1,2,3,4,5,6,7,8
<source_dir>` byte-diffed against a pre-change capture, plus `run-all.sh --only
test-gate-registry-resolution.sh,test-verify-deploy-context-budget.sh`, is the complete covering
check — gates 9-23 still run the untouched legacy path, so the changed surface is exactly the
enumerated eight gates plus the two new libraries.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` - new registry interpreter and single-gate runner
- `agent-system/extensions/core/scripts/gate-registry.data` - new declarative gate registry data file
- `agent-system/extensions/core/scripts/verify-deploy.sh` - source the registry; migrate gates 1-8; retire their inline blocks
- `agent-system/extensions/core/scripts/lint/lint-gate-registry.sh` - new registry-data lint
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - new interpreter resolution suite

**Verification**:
- `--only-gate 1,...,8` stdout, stderr, and exit code byte-identical before and after
- `bash <source_dir>/scripts/lint/lint-gate-registry.sh` exits 0 and rejects a seeded cyclic
  dependency, a missing timeout, and a duplicate id
- `bash <source_dir>/scripts/tests/run-all.sh --only test-gate-registry-resolution.sh` exits 0

---

### Phase 5: Migrate Gates 9-23 and Generalize the Selection Surface [COMPLETED]

**Goal**: Complete the migration so every gate runs through the registry, delete the remaining
copy-pasted blocks, and generalize selection to include cost class alongside `--skip-slow` and
`--only-gate`.

**Tasks**:
- [x] Migrate gates 9-23 onto the registry and delete their inline blocks. *(completed: each
      gate9_run..gate23_run wraps its original if/fi body verbatim, matching gates 1-8's Phase 4
      convention; the single `for _gate_id in $(gate_registry_ids); do "gate${_gate_id}_run"; done`
      loop moved to after all 23 function definitions, so one shared loop now drives the full
      battery in ascending id order, byte-identical to the pre-migration sequence)*
- [x] Preserve `--skip-slow` and `--only-gate` semantics exactly, including the
      zero-check-under-filter exit-2 condition documented in `verify-deploy.sh`'s header.
      *(completed: test-verify-deploy-gate-selection.sh's full 9-case suite, including the
      zero-check cases (f)/(g)/(h), still passes unmodified)*
- [x] Add selection by cost class (e.g. `--max-cost <class>`) resolved from Phase 3's generated
      cost model, so a caller can ask for "everything under N seconds" without naming gates.
      *(completed: `--max-cost {free|moderate|slow}` added, ordinal free<moderate<slow, resolved
      against gate-registry.data's cost_class field at parse time; intersects with --only-gate
      order-independently; an empty intersection drives the existing zero-check-under-filter exit
      path via a "0" sentinel id rather than silently falling back to "all gates")*
- [x] Keep the deployed-vs-source-store dual-mode discovery intact and covered by a test.
      *(completed: test-verify-deploy-gate-selection.sh's FIXTURE_RICH/FIXTURE_CHEAP/
      FIXTURE_CONSUMER cases (b)/(d)/(e) already exercise all 23 gates against both source-store
      and deploy-consumer shapes and still pass)*
- [x] Re-verify each of `deploy_findings_snapshot`'s five callers
      (`orchestrate-batch-gate.sh`, `orchestrate-cycle-plan.sh`, `command-gate-out.sh`,
      `verify-deploy.sh` itself, and the test harnesses) against the migrated aggregator.
      *(completed: test-orchestrate-batch-gate.sh 26/26, test-orchestrate-cycle-plan.sh 371/371,
      test-deploy-baseline-lib.sh 24/24, test-gate-out-self-attribution.sh 11/11,
      test-verify-deploy-gate-selection.sh 14/14, test-gate-registry-resolution.sh 10/10 — all
      green post-migration)*
- [x] Explicitly confirm a pre/post baseline comparison cannot be skewed by a noise row appearing
      in one capture and not the other — seed the scenario and assert the comparison's verdict.
      *(completed: already covered by test-deploy-baseline-lib.sh's existing seeded
      deploy_baseline_new_findings/unattributable/self_attributable cases, re-run green against
      the migrated verify-deploy.sh)*
- [x] Capture the complete battery's output before and after with an explicit source-store
      `TARGET`; require identical finding sets and identical exit code. Baseline the three known
      pre-existing failures explicitly so they are not attributed to this work. *(completed with a
      scope correction, recorded as a deviation below: a true full-battery before/after byte-diff
      against a PRE-TASK baseline is not meaningful mid-task, since gates 3/5 and several gate8
      suites report legitimate, accumulating pre-redeploy drift from every phase's new/modified
      files (1-4 included) — expected and explicitly deferred to Phase 11's deploy-headless.sh,
      not a regression. Used a scoped `--only-gate 9-23` before/after (unaffected by deploy drift,
      since gates 3/5 sit outside that range) for the clean proof of this phase's own
      transformation — byte-identical stdout and stderr, rc=1 both sides (gate20's known
      pre-existing failure) — plus one full-battery capture, root-causing every FAIL line: the
      three documented pre-existing failures (gate3 lean4 doc-lint, gate20 eager-load 988B over
      baseline, gate8's original 3 suites) are present, plus gate3/gate5 "content differs"/"not
      in provides.scripts" findings for every phase's undeployed new files (expected, Phase
      11's job), plus two additional gate8 suite failures
      (test-deploy-verify-wiring.sh, test-verify-deploy-context-budget.sh) both traced to the SAME
      two known causes (deploy-stale .claude/ copy; the known gate20 eager-load-over-baseline
      issue cascading into a fixture precondition), not new regressions.)*

**Scope Hypothesis Result**: `grep -c 'CURRENT_GATE=' verify-deploy.sh` = 24 (gate0 + gates 1-23),
confirming Phase 4's decision to reject a generic CURRENT_GATE-setting fold still holds for gates
9-23 — every gate function sets its own `CURRENT_GATE="gateN"` verbatim, exactly as gates 1-8
already did. `wc -l verify-deploy.sh`: 1350 -> 1473 lines (grew, did not shrink) — the file does
not shrink because no gate's own inline body was deleted (each is preserved verbatim inside its
`gateN_run()` wrapper, per Phase 4's non-generic-fold decision); only the per-gate loop
boilerplate was deduplicated into the one shared execution loop, plus the new `--max-cost` flag
and its header documentation added lines. This corrects the plan's original "materially fewer
lines" prediction with the actual measured figure, as the Scope Hypothesis instructed.

**Timing**: 2 hours

**Depends on**: 4

**Verification Tier**: full

**Scope Hypothesis**: This phase asserts 15 remaining gates (9-23) and that
`verify-deploy.sh` drops from 1,289 lines to materially fewer once all 23 inline blocks are
retired. Confirm at implementation time with `grep -c 'CURRENT_GATE=' verify-deploy.sh` (expect
only the registry's own single assignment site to remain) and `wc -l` before/after; record the
actual figures rather than asserting a predicted reduction.

**Tier Justification**: Every gate now runs through one shared runner, so the aggregate exit-code
and `FINDING` output contract that `deploy_findings_snapshot`'s five callers read — including
`orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy Checkpoint, whose pre/post comparison decides
whether an orchestration batch proceeds — is itself the changed surface; no gate subset or suite
subset observes that aggregate contract.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - migrate gates 9-23; delete inline blocks; add cost-class selection
- `agent-system/extensions/core/scripts/gate-registry.data` - entries for gates 9-23
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` - cost-class selection resolution
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - cost-class selection and dual-mode discovery cases
- `agent-system/extensions/core/scripts/tests/test-deploy-baseline-lib.sh` - pre/post comparison skew case

**Verification**:
- `bash <source_dir>/scripts/verify-deploy.sh <source_dir>` finding set and exit code identical to
  the pre-change capture, with the three known pre-existing failures present on both sides
- `--only-gate` with an all-SKIP selection still exits 2 (zero-check-under-filter preserved)
- `--max-cost` selection returns exactly the gates the cost model classes at or below the named
  class
- Deployed-tree and source-store invocations both resolve correctly, covered by test
- All five `deploy_findings_snapshot` callers re-verified green

---

### Phase 6: Uniform Bounded Timeouts Per Gate and Per Suite [COMPLETED]

**Goal**: Make a hang a loud, attributable failure instead of an indefinite stall, at both the
gate and the suite grain, and prove each bound actually fires.

**Tasks**:
- [x] Add a per-gate timeout, read from the registry's `timeout` field, applied by the shared
      runner. Size each bound from Phase 3's measured maximum with explicit, stated headroom.
      *(completed: timeout_s values were already populated with 3x/floor-30s headroom in Phase
      4/5; this phase added enforcement via the new `gate_registry_exec_bounded` in
      gate-registry-lib.sh, wired into verify-deploy.sh's gate loop)*
- [x] Add a per-suite timeout in `run-all.sh`, applied identically in the sequential and
      `run_one()` parallel paths (confirmed live: `run-all.sh` and `verify-deploy.sh` today
      contain zero `timeout` invocations). *(completed: `RUN_ALL_SUITE_TIMEOUT_S` (default 600s)
      wraps both paths via `timeout -k 5`)*
- [x] A timeout must produce a named, attributable failure identifying the gate or suite and the
      bound it exceeded — never a generic non-zero exit. *(completed: gate side emits `[FAIL]
      gate<N> (<invoke>) exceeded its <bound>s timeout`; suite side emits `[FAIL] <suite>` plus
      a `TIMEOUT: <suite> exceeded the <bound>s per-suite bound` detail line)*
- [x] Add a deliberately-stalled fixture (a suite that sleeps past its bound, and a registry
      entry pointing at a stalling command) and assert in test that each bound fires, that the
      failure names the right unit, and that the run continues to a stable summary rather than
      aborting. *(completed: suite-side `test-stalled-fixture.sh` (env-gated, instant-pass when
      not activated) plus 3 new cases in test-run-all-selection.sh covering sequential,
      parallel, and SIGTERM-ignoring/SIGKILL-escalation; gate-side 4 new cases in
      test-gate-registry-resolution.sh covering clean-finish reconciliation, the no-bound
      direct-call path, the timeout-and-process-group-kill path, and a pin that all 23 real
      gates carry an enforceable bound)*
- [x] Run the complete battery and confirm no existing gate or suite trips its bound.
      *(completed: a full `verify-deploy.sh --findings` run on this machine (load ~2.0/24 cores,
      effectively idle) produced zero TIMEOUT lines and the EXACT same 5-failing-suite set Phase
      5's handoff documented as pre-existing/deploy-lag (test-four-tier-conflict.sh,
      test-detect-noop-bash.sh, test-guard-git-push.sh, test-deploy-verify-wiring.sh,
      test-verify-deploy-context-budget.sh), plus gate3/gate5/gate20's own already-documented
      pre-existing findings -- no new failures, no bound trips. A deliberately-stalled fixture
      run during this verification caught one real flake in the new case13 (an overly-broad
      `pgrep -f "sleep 30"` leftover check collided with a concurrent sibling suite's own
      unrelated `sleep 30`); fixed to check the stalled descendant's own captured pid instead,
      and re-confirmed clean both standalone (with a deliberately-injected concurrent `sleep 30`)
      and inside a real `--only-gate 8` re-run)*

**Timing**: 1.5 hours

**Depends on**: 5

**Verification Tier**: full

**Tier Justification**: A timeout introduces a new failure class that can fire at any gate or any
suite, so only the complete battery observes whether any existing unit now trips its bound — a
gate or suite subset would exercise only the bounds it happens to contain, which is precisely the
blind spot this phase exists to close.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` - apply the per-gate timeout and emit the named timeout failure
- `agent-system/extensions/core/scripts/gate-registry.data` - per-gate timeout values sized from measured maxima
- `agent-system/extensions/core/scripts/tests/run-all.sh` - per-suite timeout in both the sequential and parallel paths
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - stalled-gate fixture asserting the gate bound fires
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` - stalled-suite fixture asserting the suite bound fires

**Verification**:
- The stalled-gate fixture fails with a message naming the gate and its bound, within the bound
  plus a small margin
- The stalled-suite fixture does the same for a suite, in both `--jobs 1` and parallel paths
- `bash <source_dir>/scripts/verify-deploy.sh <source_dir>` completes with no timeout failure and
  the same finding set as Phase 5's capture

---

### Phase 7: Gate-Level Concurrency Scheduler [COMPLETED]

**Goal**: Run independent gates concurrently with declared dependencies, ported in shape from
`run-all.sh`'s proven scheduler, with parallelism-safety established per gate rather than assumed.

**Tasks**:
- [x] *(completed)* Read `run-all.sh`'s rejected-alternatives header before writing any scheduler code, and
      respect both of its recorded rejections (a fixed cap rather than bare `nproc`; no
      self-maintaining timing cache). Do not re-propose either.
- [x] *(completed: gate_registry_exec_concurrent_batch in lib/gate-registry-lib.sh)* Port the scheduler shape: a `wait -n` worker-slot pool against a declared cap, per-gate
      output captured to its own file, and a final emission loop that walks gates in **declaration
      order** regardless of completion order.
- [x] *(completed: wave-barrier dependency honouring + cost-class-rank longest-first tie-broken by ascending id)* Schedule longest-first from Phase 3's cost model, and honour the registry's declared
      dependency edges so a dependent gate never starts before its prerequisites finish.
- [x] *(completed: see context/standards/shell-script-testing.md's "Gate-level parallelism-safety audit (Phase 7)" section -- no gate besides gate8 needs serialization; gates 5/13's headless nvim and gate20's file reads are all read-only/mktemp-scoped)* Perform an explicit per-gate parallelism-safety audit and record it alongside
      `run-all.sh`'s existing audit, extending that discipline rather than inventing a parallel
      notion of it. Give unsafe gates a serialized class run alone, mirroring
      `LOAD_SENSITIVE_BASENAMES`. Audit Gate 20's fixture files and Gate 13's headless nvim
      invocation specifically.
- [x] *(completed: VERIFY_DEPLOY_NESTED in verify-deploy.sh, mirrors RUN_ALL_NESTED)* Add a nested-invocation guard at the gate grain analogous to `RUN_ALL_NESTED`, so a gate
      that shells out to `verify-deploy.sh` cannot fan out recursively.
- [x] *(completed: proven live at worker counts 1/2/4/auto on the real registry, plus test-gate-registry-resolution.sh case19 on synthetic registries)* Prove determinism: identical gate verdicts and an identical summary line at several worker
      counts.

**Timing**: 2 hours

**Depends on**: 6

**Verification Tier**: full

**Tier Justification**: Concurrent execution can only be proven safe and deterministic by running
the complete battery — a gate subset never exercises cross-gate resource collision, which is the
specific cross-cutting surface (shared fixture paths, the headless-nvim invocation, the nested
`verify-deploy.sh` call in Gate 8's own suites) that no cheaper tier covers.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` - worker-slot pool, per-gate output capture, declaration-order emission, dependency honouring, nested guard
- `agent-system/extensions/core/scripts/gate-registry.data` - serialized-class flags from the parallelism-safety audit
- `agent-system/extensions/core/scripts/verify-deploy.sh` - worker-count flag and its default
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - determinism-across-worker-counts and dependency-ordering cases
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - gate-level parallelism-safety audit record

**Verification**:
- Identical finding set and identical summary line at worker counts 1, 2, 4, and the default
- A gate declared dependent never starts before its prerequisite completes (asserted in test)
- The serialized class runs alone, asserted in test
- `bash <source_dir>/scripts/verify-deploy.sh <source_dir>` finding set identical to Phase 6's
  capture

---

### Phase 8: One-Process-Per-File Shellcheck Parallelization [COMPLETED]

**Goal**: Parallelize `lint-shellcheck.sh` in the one shape the research measured as a win, with
the worker-count experiment as a repeatable acceptance gate rather than a one-off.

**Tasks**:
- [x] Implement one-process-per-file dispatch following `run-all.sh`'s `run_one()` shape: one
      file, one background job, output captured to its own file, `wait -n`-scheduled against a
      worker cap. Do **not** batch multiple files per `shellcheck` invocation. *(completed)*
- [x] Record in the script header why batched dispatch is prohibited: every batched shape measured
      (`-P24 -n20`, `-P4 -n96`, `-P8 -n48`) was *slower* than sequential; only `-n 1` won. *(completed)*
- [x] Choose the worker cap from a fresh run of the experiment, not a bare `nproc`. *(completed: fresh P=1/4/8/12 re-run on the real 387-file corpus; SHELLCHECK_JOBS defaults to 8, overridable via env var)*
- [x] Add the experiment to `scripts/tests/` as a repeatable acceptance check that fails if the
      parallel path is slower than the sequential path on the real corpus. *(completed: test-lint-shellcheck-parallel.sh, relative-ratio gate, 9/9 cases pass)*
- [x] Preserve deterministic, discovery-order finding output regardless of worker count. *(completed: verified byte-identical output at SHELLCHECK_JOBS=1,4,8 on a 5-file fixture)*
- [x] Prove finding-set equivalence: identical findings sequentially and in parallel on the real
      corpus, plus a seeded violation reported in both. *(completed: verified against the pre-change original script via a throwaway git worktree, real corpus and seeded SC2155 fixture both byte-identical)*

**Timing**: 1.5 hours

**Depends on**: 3

**Verification Tier**: local

**Scope Hypothesis**: This phase asserts a corpus of ~381 tracked `*.sh` files under
`agent-system/extensions/`, carried from both the dispatch and the research report. Confirm at
implementation time with `git ls-files -- 'agent-system/extensions/*.sh' | wc -l` — the corpus
grows, and the realistic speedup budget (~1.3-1.8x, carried from the research report's
50.5s-vs-75.9s measurement) must be re-derived against the actual current corpus rather than
assumed from the carried figure.

**Tier Justification**: `bash <source_dir>/scripts/verify-deploy.sh --only-gate 22 --findings
--quiet <source_dir>` finding-set-diffed against a pre-change capture, plus the new experiment
suite via `run-all.sh --only test-lint-shellcheck-parallel.sh`, is the complete covering check —
the change is confined to `lint-shellcheck.sh`'s internal dispatch loop and changes no
externally visible signature or output shape.

**Files to modify**:
- `agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` - one-process-per-file worker pool; header records the batched-dispatch prohibition
- `agent-system/extensions/core/scripts/tests/test-lint-shellcheck-parallel.sh` - new repeatable experiment and equivalence suite

**Verification**:
- Sequential and parallel finding sets identical on the real corpus, and a seeded violation
  reported by both
- Findings emitted in discovery order at every worker count
- The experiment suite fails if the parallel path is not faster than sequential
- `--only-gate 22` exit status checked, not only its stdout diff

---

### Phase 9: Shared Corpus Enumeration [COMPLETED]

**Goal**: Enumerate the tracked-file corpus once per invocation and let every gate derive its own
filtered view, eliminating the duplicated per-gate filesystem walk.

**Tasks**:
- [x] Produce one master tracked-path list per `verify-deploy.sh` invocation (a single
      `git ls-files` over the resolved source store) and expose it to gates through the registry
      runner. *(completed: gate_registry_shared_corpus_build in gate-registry-lib.sh; wired into
      verify-deploy.sh once per invocation, exported as GATE_SHARED_CORPUS_FILE/_ROOT)*
- [x] Give each gate a derived, in-memory filtered view by its own pattern. Do **not** assume one
      list satisfies every gate unmodified: today's lints use differing filters (`*.sh`, `*.md`,
      `*.sh`+`*.md`, `*.json`, `SKILL.md`, `manifest.json`) and only `lint-shellcheck.sh` uses
      `git ls-files` at all; the rest use `find`. *(completed: common_shared_corpus_files in
      common.sh; each of the 6 affected lints applies its own pattern -- see progress file)*
- [x] Preserve each lint's standalone invocability — a lint must still work when run directly,
      falling back to its own enumeration when no shared corpus is supplied. *(completed:
      verified via all 6 affected lints' own fixture suites passing unchanged)*
- [x] Preserve the `find`-based fallback `lint-shellcheck.sh` documents for fixture tests, where
      `git ls-files` cannot serve. *(completed: explicit-path branch untouched)*
- [x] Prove finding-set equivalence per affected gate, not in aggregate, with a seeded violation
      per gate. *(completed: test-gate-registry-resolution.sh cases 22-25, plus
      verify-deploy.sh --only-gate 12,17,18,21,22,23 clean against the real source store)*

**Timing**: 2 hours

**Depends on**: 7

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts a specific set of corpus-walking lints that can share one
enumeration. The dispatch claims "roughly six independent lints each separately resolve the repo
root and re-enumerate the same ~380 tracked `*.sh` files via `git ls-files`"; the research
contradicts this — only `lint-shellcheck.sh` uses `git ls-files`, the rest use `find` with
differing extension filters. Confirm at implementation time with
`grep -ln 'git ls-files\|find .* -name' <source_dir>/scripts/lint/*.sh` and enumerate the actual
per-lint filter set before designing the shared view; the "six lints, one list" framing is
confirmed wrong and must not be carried forward.

**Tier Justification**: `bash <source_dir>/scripts/verify-deploy.sh --only-gate <the enumerated
corpus-walking gate list> --findings --quiet <source_dir>` finding-set-diffed per gate against a
pre-change capture, plus each affected lint's own standalone invocation, is the complete covering
check — the shared enumeration changes only the input-set plumbing of the enumerated gates and no
other gate's behavior.

**Files to modify**:
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` - produce and expose the master corpus once per invocation
- `agent-system/extensions/core/scripts/lint/lint-shellcheck.sh` - accept the shared corpus; keep the find-based fixture fallback
- `agent-system/extensions/core/scripts/lint/lint-state-writer-boundary.sh` - accept the shared corpus; keep standalone fallback
- `agent-system/extensions/core/scripts/lint/lint-scoped-commit-boundary.sh` - accept the shared corpus; keep standalone fallback
- `agent-system/extensions/core/scripts/lint/lint-task-lookup-adoption.sh` - accept the shared corpus; keep standalone fallback
- `agent-system/extensions/core/scripts/lint/lint-directory-pathspec-boundary.sh` - accept the shared corpus; keep standalone fallback
- `agent-system/extensions/core/scripts/lint/lint-hook-registration-paths.sh` - accept the shared corpus; keep standalone fallback
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - shared-corpus plumbing and standalone-fallback cases

**Verification**:
- Per-gate finding sets identical before and after, with a seeded violation per affected gate
  reported on both sides
- Each affected lint still works invoked directly, with no shared corpus supplied
- `lint-shellcheck.sh`'s `find`-based fixture path still functions

---

### Phase 10: Flip run-all.sh's Default to Parallel [COMPLETED]

**Goal**: Stop a bare `run-all.sh` invocation from being several times slower than the same work
via Gate 8, while preserving the byte-identical sequential path its own header promises at
`--jobs 1`.

**Tasks**:
- [x] Change the `JOBS=1` default (run-all.sh:145) to `auto`. *(completed: line had drifted to
      180; `JOBS=auto` flows through the pre-existing auto-resolution branch unchanged)*
- [x] Preserve `--jobs 1` as the explicit opt-out routing to the existing, structurally separate
      sequential code path, unchanged. *(completed: untouched code; verified byte-identical to
      RUN_ALL_NESTED-forced-sequential via test-run-all-parallel.sh case10)*
- [x] Leave `JOBS_CAP=4` alone and record why in the header: the suite pool is work-bound at
      jobs<=2 and straggler-bound from jobs=4 onward, so raising the cap buys nothing. Note that
      an explicit `--jobs 12` already bypasses the cap entirely and already does nothing useful.
      *(completed: new "Rejected alternatives" bullet added)*
- [x] Confirm the `RUN_ALL_NESTED` guard still forces `JOBS=1` under nesting now that the
      un-nested default is parallel — this is the interaction most at risk from the flip.
      *(completed: confirmed by code reading + new cases 8/9)*
- [x] Confirm the `LOAD_SENSITIVE_BASENAMES` serialized set still runs alone, before the pool.
      *(completed: unchanged code, re-verified via full suite pass)*
- [x] Add test cases pinning the new default, the `--jobs 1` opt-out, and the nested override.
      *(completed: test-run-all-parallel.sh cases 8, 9, 10)*

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: interface

**Scope Hypothesis**: This phase asserts the `JOBS=1` default sits at `run-all.sh:145` and
`JOBS_CAP=4` at `run-all.sh:189` (both confirmed live during planning), and that the sequential
path is already structurally separate so the flip is near-data-only. Confirm at implementation
time with `grep -n '^JOBS=\|JOBS_CAP=' run-all.sh` — Phase 6 edits this file first, so the line
numbers will have drifted — and by reading the two paths before asserting the flip is low-risk.

**Tier Justification**: `bash <source_dir>/scripts/tests/run-all.sh --only
test-run-all-selection.sh,test-run-all-parallel.sh` plus
`bash <source_dir>/scripts/verify-deploy.sh --only-gate 8 <source_dir>` is the complete covering
check — the change alters `run-all.sh`'s default worker count, whose enumerated direct dependents
are its own two selection/parallel suites and Gate 8, the one caller that already requests
`--jobs auto` explicitly.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - default flipped to auto; header records the cap rationale
- `agent-system/extensions/core/scripts/tests/test-run-all-selection.sh` - default, opt-out, and nested-override cases
- `agent-system/extensions/core/scripts/tests/test-run-all-parallel.sh` - nested-guard and serialized-set cases under the new default

**Verification**:
- A bare `run-all.sh` runs parallel; `--jobs 1` runs the unchanged sequential path
- `RUN_ALL_NESTED=1` still forces `JOBS=1`, asserted in test
- Suite verdicts and the summary line identical between the bare invocation and `--jobs 1`
- `--only-gate 8` finding set unchanged

---

## Phases 12-17: Carried by the Cost-Model Re-Aim Task

The six phases below are NOT executed under this task and are not prerequisites for its closure.
They pursue gate-set EFFICIENCY, which is a different deliverable from the gate FRAMEWORK this
task delivers, and they are owned by the task chartered to re-aim the gate set at the measured
cost model and add input-scoped gate invalidation. They are retained here in full because their
evidence and task breakdown are the input that task should plan from rather than re-derive.

Why they moved: the efficiency premise this task was opened against turned out to be a
measurement artifact. The honest idle baseline (`progress/phase-3-gate-cost-model.csv`, load 1.03
at start, twice averaged) is ~694s for the whole set, concentrated as `gate8` 457,197ms (66%),
`gate3` 125,669ms (18%), `gate22` 54,716ms (8%) -- not the 22-28 minutes the dispatch cited, and
not the shellcheck-dominated shape it assumed. Pursuing the real concentration means skipping
unchanged gates rather than re-walking them faster, which is the re-aim task's own mandate.

Anything these phases assert about files this task owns stays true; nothing below has been
executed, and no file under `agent-system/**` reflects them.

---

### Phase 12: Attribute and Cut the Two Verify-Deploy-Testing Stragglers [NOT STARTED]

**Goal**: Drop the suite pool's two largest members — `test-verify-deploy-context-budget.sh` at
228,595ms and `test-verify-deploy-gate-selection.sh` at 160,340ms, together ~38% of the 1,016.6s
hinted pool — by stopping their nested `verify-deploy.sh` invocations from re-paying the two slow
gates their assertions do not read.

**Evidence**: `--skip-slow` defers gate 8 **only** (`verify-deploy.sh:854-855`), so every nested
`--skip-slow` full-battery call inside these suites still pays gate 3 (~125s) and gate 22 (~55s)
against its own fixture. The context-budget suite's one remaining full-battery baseline capture
(`tests/test-verify-deploy-context-budget.sh:189`) is therefore ~180s by itself, which accounts
for nearly all of that suite's hint. The fixture build is not the driver: with the
`--exclude='literature-pyenv'` already in place the rsynced tree is 22M (the unexcluded tree is
262M, and `literature/` alone is 242M of it).

**Tasks**:
- [ ] Attribute both suites' wall clock on a quiet host before changing anything: per-invocation
      timing for every nested `verify-deploy.sh` call plus the fixture construction (rsync,
      `git init`, `git add -A`, `commit`), written to `progress/`. Required because the two
      candidate remedies — narrowing gate selection versus splitting the suite — address
      different costs, and only measurement says which is present.
- [ ] Narrow each nested invocation to the gates its assertions actually read, using the
      selection surface Phase 5 generalized (`--only-gate`, `--max-cost`) instead of a bare
      `--skip-slow` full battery. For the context-budget baseline-sanity capture, establish
      whether its cleanliness claim needs gate 3's and gate 22's findings at all; if not, take
      the baseline with `--max-cost moderate` and scope the assertion's stated claim to the gates
      it actually covers, recording that scope in the suite header.
- [ ] Do not weaken what either suite asserts. Record per case which gates it reads and why the
      narrowed selection still covers them; a case that no longer exercises its named behaviour
      is a regression, not a speedup.
- [ ] If attribution leaves a residual invocation that genuinely needs the full battery, split
      that case into its own suite so the pool schedules it as a separate unit rather than
      serializing it behind the rest of its parent suite.
- [ ] Regenerate both suites' hints via `measure-gate-costs.sh --regen-hints`.
- [ ] Correct `tests/run-all.sh`'s rejected-alternatives header where it names this suite's cost
      as "~103s-228.6s depending on host load".

**Timing**: 3 hours

**Depends on**: 10

**Verification Tier**: local

**Scope Hypothesis**: Asserts that the context-budget suite holds 3 distinct nested invocation
sites (`:175` inside a 3-iteration mode loop, `:189`, `:309`) — not the 12 that a textual
`grep -c 'verify-deploy\.sh'` returns, which counts comments and the existence check — and that
the gate-selection suite holds 8 (`:114` helper, `:152`, `:166`, `:226`, `:280`, `:309`, `:322`).
Re-count at implementation time with `grep -n '"\$VERIFY_DEPLOY"' <suite>`: the remedy is
per-invocation, so an added site changes the work.

**Tier Justification**: The change is confined to two suites' own invocation flags plus the hint
file, with no library or interface surface touched, so
`run-all.sh --only test-verify-deploy-context-budget.sh,test-verify-deploy-gate-selection.sh`
diffed against a pre-change per-case capture is the complete covering check.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` - narrow nested invocations; record each case's gate coverage
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` - same
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - regenerated hints for both suites
- `agent-system/extensions/core/scripts/tests/run-all.sh` - header's stale straggler figure

**Verification**:
- Both suites pass with an unchanged case count and identical per-case verdicts against a
  pre-change capture, exit status checked directly
- Per-invocation attribution table recorded, each figure carrying its measurement-time load
  average
- Both suites' wall clock measured before and after on a quiet host
- `suite-cost-hints.txt` regenerated and both suites' new hints present
- Gate 8's own wall clock re-measured after the change

---

### Phase 13: Fixture-Corpus Shellcheck Acceptance Check and Complete Hint Coverage [NOT STARTED]

**Goal**: Stop the shellcheck acceptance suite from walking the full production corpus twice
inside gate 8, and close the hint gaps this work opened so longest-first scheduling is not blind
to its own new suites.

**Evidence**: `tests/test-lint-shellcheck-parallel.sh:72` and `:78` each invoke
`lint-shellcheck.sh --quiet` with no target — that is the real corpus — once forced to
`SHELLCHECK_JOBS=1` (~75.8s per the lint script's own header) and once at the parallel default
(~42s). That is roughly 118s of production-corpus walking inside a unit test that itself runs
inside gate 8, which has been observed four `verify-deploy.sh` levels deep. The suite is also
unhinted, as are `test-gate-registry-resolution.sh` and `test-check-record-versioning.sh`.

**Tasks**:
- [ ] Replace the real-corpus pair in the acceptance case with a fixture-corpus assertion: build
      a fixture large enough to make the dispatch shape observable and assert that shape — one
      process per file, the worker cap honoured, discovery-order output — plus finding-set
      equivalence on the fixture. Keep the existing 5-file determinism case and the
      seeded-violation case unchanged.
- [ ] Replace the 80%-of-sequential relative-ratio gate on the default path with an assertion
      that does not require two corpus walks: assert the dispatch shape directly (observed peak
      concurrent `shellcheck` processes, or per-file dispatch count) rather than a wall-clock
      ratio. A wall-clock ratio taken under gate 8's own concurrent pool is not a sound
      measurement in the first place.
- [ ] Keep the real-corpus timing experiment available but opt-in behind an explicit env var or
      flag that the default path skips, with a header note that it is the acceptance experiment
      established when the parallel dispatch landed and is run deliberately. Do not delete it:
      it is the standing evidence that parallel dispatch remains a win.
- [ ] Hint every suite this work added or left unhinted: `test-lint-shellcheck-parallel.sh`,
      `test-gate-registry-resolution.sh`, `test-check-record-versioning.sh`, and
      `test-measure-gate-costs.sh` if it is also missing.
- [ ] Add a hint-coverage check so a newly added suite cannot land unhinted silently. It must be
      **advisory** — `suite-cost-hints.txt`'s own header states hints are advisory-only and that
      deleting or truncating the file must never change which suites run — so this warns and
      names the gaps, and never refuses a run.

**Timing**: 1.5 hours

**Depends on**: 10

**Verification Tier**: local

**Scope Hypothesis**: Asserts exactly three unhinted discovered suites today
(`test-check-record-versioning.sh`, `test-gate-registry-resolution.sh`,
`test-lint-shellcheck-parallel.sh`) against 147 hinted rows totalling 1,016,638ms. The 118
`test-*.sh` files in core's own `tests/` directory are fewer than the 147 hinted rows, so the
discovery set spans more than that one directory: re-derive it from `run-all.sh`'s own discovery
at implementation time, never from `ls tests/test-*.sh`.

**Tier Justification**: The edits are confined to one suite's internal cases, the hint data file,
and one advisory check; no library, gate, or interface surface changes. The suite's own run plus
a hint-coverage report is the complete covering check.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-lint-shellcheck-parallel.sh` - fixture-corpus dispatch-shape assertion; opt-in real-corpus experiment
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - hint the unhinted suites
- `agent-system/extensions/core/scripts/tests/run-all.sh` - advisory hint-coverage report

**Verification**:
- The suite's default run performs no full-corpus walk, proven both by a wall-clock bound and by
  the absence of a no-target `lint-shellcheck.sh` invocation on the default path
- Case count does not drop; the seeded-violation and determinism cases still pass
- The opt-in real-corpus experiment still passes when explicitly requested
- Every discovered suite has a hint row, or the advisory names each that does not, and a
  truncated hint file still runs exactly the same suite set
- The suite's wall clock recorded before and after

---

### Phase 14: Re-Derive JOBS_CAP From the True Pool [NOT STARTED]

**Goal**: Set the suite pool's worker cap on current evidence, after phases 12 and 13 have
removed the costs that distort it.

**Evidence**: `tests/run-all.sh:82-95` rejects raising `JOBS_CAP` above 4 on the reasoning that
the pool is "WORK-BOUND at jobs<=2 ... and STRAGGLER-BOUND from jobs=4 onward", derived from a
356.6s aggregate. The hint file's current rows total 1,016.6s across 147 suites. At that figure
the pool is work-bound at jobs=4 (1016.6/4 = 254.2s against a 228.6s longest straggler), not
straggler-bound — so the header's conclusion does not follow from today's numbers. The rejection
is to be re-derived from evidence, neither inherited nor simply reversed.

**Tasks**:
- [ ] Recompute the pool arithmetic from the hint file regenerated by phases 12 and 13:
      aggregate sequential cost, longest straggler, and projected wall clock at 2, 4, 8 and 12
      workers. Record the table.
- [ ] Measure rather than only project: time a bare `run-all.sh` at 4, 8 and 12 workers on a
      quiet host and compare against the projection, so the decision rests on observation.
- [ ] Honour the header's two resource-shaped rejections on their own terms rather than refuting
      them with the arithmetic one. The fixture-rsync and headless-nvim concern is about peak
      disk and memory, not cores: measure peak memory and the concurrent-fixture count at the
      candidate cap before raising it. Restate the fixture-size figure accurately whichever way
      the decision goes — a fixture copy is ~22M with the `literature-pyenv` exclude, not the
      "~16MB" the header assumes and not the 262M the unexcluded tree would be.
- [ ] Set `JOBS_CAP` from that evidence and rewrite the header's rejected-alternatives entry to
      state the current derivation. Keep the two rejections this evidence does not touch (a bare
      `nproc` with no cap; a self-maintaining timing cache).
- [ ] Record that `--jobs N` already bypasses the cap entirely — it applies only inside the
      `auto` branch (`run-all.sh:236`) — so the cap governs the default path alone.

**Timing**: 2 hours

**Depends on**: 12, 13

**Verification Tier**: local

**Scope Hypothesis**: Asserts `JOBS_CAP=4` at `tests/run-all.sh:229`, applied only within the
`auto` branch at `:236`, a hinted pool of 1,016.6s over 147 rows, and a 24-core host. Re-read all
four at implementation time; the pool figure in particular changes by design in phases 12 and 13,
and the decision must use the post-12/13 figure, not the one recorded here.

**Tier Justification**: The change is one constant plus its header justification inside
`run-all.sh`, whose own suite and the determinism property Phase 10 established are the complete
covering check; the gate-level interface is untouched.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - `JOBS_CAP` and its rejected-alternatives derivation

**Verification**:
- Projected and measured wall clock at each candidate worker count recorded in one table, each
  figure carrying its measurement-time load average
- Peak memory and concurrent-fixture count recorded at the chosen cap
- `run-all.sh` verdicts and summary line identical at every worker count tested — the
  determinism property Phase 10 established must not regress
- `run-all.sh --only test-run-all-selection.sh` passes, exit status checked directly
- The header states the current derivation, and the two resource-shaped rejections remain

---

### Phase 15: Harden measure-gate-costs.sh Against Mid-Run Contention [NOT STARTED]

**Goal**: Make the measurement harness able to detect its own invalidation, so the before/after
proof the final phase produces can be trusted.

**Evidence**: the harness guards load once before the measurement (`measure-gate-costs.sh:228`)
and once after it (`:265`), and the post-check only emits a WARNING to stderr — the CSV it just
wrote stays on disk unmarked and machine-indistinguishable from a clean sample. There is no
per-gate capture, so contention that begins and subsides inside the run is invisible to both
checks. A run begun at load 1.46 was contaminated mid-flight by an unrelated sibling build (load
reaching ~27) and produced gate1 10ms -> 1235ms and gate3 125.7s -> 299.0s with its two runs
disagreeing 404s against 193s. That output is indistinguishable from a real regression.

**Tasks**:
- [ ] Capture the 1-minute load average per gate per run, not only at the run's two ends, and
      record it as a column alongside each figure.
- [ ] Mark a sample invalid in the artifact itself when its own capture exceeds the threshold — a
      per-row validity column plus a file-level header flag — so a consumer reads validity
      mechanically instead of from a stderr warning that has scrolled past.
- [ ] Make the post-run guard's outcome affect the artifact rather than only stderr: a run whose
      load rose mid-flight must leave the CSV marked contaminated, or refuse to overwrite a
      previously clean one. It must never silently replace a good sample with a bad one.
- [ ] Apply the same treatment to `--regen-hints`, which carries the identical pre/post-only
      shape (`:276`, `:329`) and writes the very file longest-first scheduling depends on.
- [ ] Extend `test-measure-gate-costs.sh` through the `mgc_load_1min` injection seam the script
      already provides for deterministic load-guard testing: a mid-run rise marks the sample
      invalid; a clean run does not; a contaminated run does not overwrite a clean artifact.
- [ ] Record in the script header that the per-gate capture is the load-bearing invalidation
      signal and that the two end-of-run guards are not sufficient alone.

**Timing**: 1.5 hours

**Depends on**: 10

**Verification Tier**: local

**Scope Hypothesis**: Asserts the harness is 335 lines with load guards at `:228`, `:265`,
`:276` and `:329`, and a test seam at `:155`-`:173`. Re-read before editing.

**Tier Justification**: The change is internal to one script and its own suite; the CSV gains
columns, and the one consumer of that shape is this task's own measurement step, re-run in the
final phase. No gate or library interface changes.

**Files to modify**:
- `agent-system/extensions/core/scripts/measure-gate-costs.sh` - per-gate load capture, validity marking, overwrite protection
- `agent-system/extensions/core/scripts/tests/test-measure-gate-costs.sh` - mid-run-rise cases via the existing injection seam

**Verification**:
- `run-all.sh --only test-measure-gate-costs.sh` passes, including the new mid-run-rise cases,
  exit status checked directly
- A deliberately contended sample is marked invalid in the written CSV and does not overwrite a
  clean one
- A clean sample is marked valid, and the CSV's existing columns still parse
- The hint-regeneration path carries the same marking

---

### Phase 16: Gate 3 — the Binding Floor Once Gate 8 Drops [NOT STARTED]

**Goal**: Cut gate 3 (`check-extension-docs.sh`), which phases 12-14 promote from a cost hidden
beneath gate 8 to the whole run's binding floor.

**Evidence, and why this phase exists**: the scheduler Phase 7 shipped runs gate 8 in the
serialized class — alone, and strictly before the concurrent pool starts (`gate-registry.data`
marks `gate8` `serialized=true`, the only such row; `lib/gate-registry-lib.sh`'s wave contract
runs serialized ids before the wave's own pool). The whole-set wall clock is therefore gate 8
**plus** the pool's wall, and the pool's wall is set by its own longest member: gate 3 at
125,669ms, against 54,716ms for gate 22 and under 14s for every other gate. So while gate 8 costs
457s, gate 3 is invisible; once phases 12-14 bring gate 8 down toward what its re-derived pool
arithmetic projects, gate 3 becomes roughly half of what remains. This phase is a derived
addition beyond the four areas the revision brief enumerated, included because the efficiency
goal cannot be reached with 18% of the measured cost untouched. It is independently droppable
without affecting phases 12-15.

**Tasks**:
- [ ] Confirm the premise before optimizing anything: re-measure the whole-set wall clock and
      gate 3's share of it after phases 12-14 land, using Phase 15's hardened harness. If gate 3
      is not then the pool's binding member, close this phase as
      `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record whose Evidence
      column cites that measurement — the same contingency shape this plan already provides for
      Phase 8.
- [ ] Attribute gate 3's cost across its rule checks before changing any of them. The script runs
      many per-extension sequential loops (over agents, skills, commands, rules, scripts and
      context entries) plus deployed-versus-source content-drift diffs; the work goes where the
      measurement says the time is, not where the structure suggests it might be.
- [ ] Parallelize across extensions if the attribution supports it: the top-level iteration is
      per-extension and the per-extension checks are read-only, the same shape that made the
      shellcheck parallelization safe. Follow the one-process-per-unit finding rather than
      batching — every batched shape measured for shellcheck was slower than sequential — and
      preserve deterministic discovery-order output.
- [ ] Reuse Phase 9's shared corpus enumeration instead of re-walking, if attribution shows
      enumeration is a material share of the cost.
- [ ] Prove finding-set equivalence on the real corpus and on a seeded violation per rule class
      touched, the same bar every other refactored gate met.
- [ ] Re-measure and record gate 3's cost and the whole-set wall clock after the change.

**Timing**: 3 hours

**Depends on**: 12, 13, 14, 15

**Verification Tier**: interface

**Scope Hypothesis**: Asserts `check-extension-docs.sh` is 1,707 lines, located at
`agent-system/extensions/core/scripts/check-extension-docs.sh` (the scripts root, not under
`lint/`), carries no existing parallelism, and iterates per-extension over at least six declared
categories. Re-read and re-attribute before editing; this phase's own first task is the
measurement that decides whether it proceeds at all.

**Tier Justification**: Gate 3's findings reach `deploy_findings_snapshot`'s five callers, one of
which gates whether an orchestration batch proceeds, so a local suite run is not a covering
check — the finding set must be diffed at the `verify-deploy.sh --findings` interface and the
consumers re-verified, as phases 2 and 5 required for the same reason.

**Files to modify**:
- `agent-system/extensions/core/scripts/check-extension-docs.sh` - per-extension concurrency and shared-enumeration reuse, as attribution supports
- `agent-system/extensions/core/scripts/gate-registry.data` - gate 3's `cost_class` and `timeout_s` if its measured cost changes class
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - re-hint any affected suite

**Verification**:
- `bash <source_dir>/scripts/verify-deploy.sh --only-gate 3 --findings --quiet <source_dir>`
  finding set identical to a pre-change capture, exit status checked directly
- A seeded violation per rule class touched is reported both before and after
- Findings emitted in deterministic order at every worker count
- `deploy_findings_snapshot`'s five callers re-verified, including that a pre/post baseline
  comparison cannot be skewed by a row appearing in one capture only
- Gate 3's cost and the whole-set wall clock recorded before and after via Phase 15's harness

---

### Phase 17: Re-Examine Gate 8's Serialized Isolation [NOT STARTED]

**Goal**: Decide on evidence whether gate 8 must keep running alone, since that choice makes the
whole-set wall clock additive (gate 8 plus the pool) rather than the maximum of the two.

**Evidence**: `gate-registry.data` marks gate 8 as the only `serialized=true` row, and
`lib/gate-registry-lib.sh`'s documented contract runs the serialized class one at a time strictly
before the wave's pool starts. Overlapping the two would remove the smaller of the pair from the
wall clock entirely. The serialized class exists for resource contention, not for correctness of
the gate's findings, so the question is measurable rather than a matter of principle. This phase,
like Phase 16, is a derived addition beyond the four enumerated areas, and is independently
droppable.

**Tasks**:
- [ ] State why gate 8 is serialized today from the code and its header rather than from
      assumption, and record it. Gate 8 runs `tests/run-all.sh`, which itself runs a worker pool
      whose suites rsync fixtures and launch headless nvim, and several of whose suites invoke
      `verify-deploy.sh` nested. Confirm which constraint the serialization actually defends:
      CPU oversubscription, peak disk or memory, fixture-path collision, or the
      `RUN_ALL_NESTED` nested-invocation guard.
- [ ] If the constraint is oversubscription, test overlapping gate 8 with the pool while reducing
      the pool's own worker budget so total concurrency is unchanged, rather than simply removing
      the serialization.
- [ ] Audit for the collision classes Phase 7's gate-level audit already enumerated, with the
      nested `verify-deploy.sh` invocations inside gate 8's own suites as the specific new
      hazard: a nested run and a concurrent pool gate both operating on the source store.
- [ ] If any collision cannot be resolved, keep gate 8 serialized and close this phase as
      `[COMPLETED WITH EXCLUSIONS]` with the audit as its Evidence. The registry expresses the
      decision as a single data field either way, so the outcome is a one-field change plus its
      justification — never a half-applied overlap.
- [ ] Prove determinism and finding-set equivalence at whichever setting ships, across repeated
      runs and several worker counts.

**Timing**: 2 hours

**Depends on**: 14, 16

**Verification Tier**: interface

**Scope Hypothesis**: Asserts gate 8 is the single `serialized=true` row in
`gate-registry.data`, and that the scheduler runs serialized ids strictly before the pool.
Re-read both before changing the field.

**Tier Justification**: Changing when gate 8 runs relative to every other gate can change the
output interleaving and the summary line that `deploy_findings_snapshot`'s callers read, so the
covering check is at the `verify-deploy.sh` interface across worker counts, not inside any one
gate.

**Files to modify**:
- `agent-system/extensions/core/scripts/gate-registry.data` - gate 8's `serialized` field, if the audit clears it
- `agent-system/extensions/core/scripts/lib/gate-registry-lib.sh` - worker-budget accounting if gate 8 overlaps the pool
- `agent-system/extensions/core/scripts/tests/test-gate-registry-resolution.sh` - cases for the chosen setting

**Verification**:
- The reason for gate 8's serialization recorded from code, not assumed
- Whole-set wall clock measured at both settings on a quiet host, each figure carrying its load
  average
- Identical gate verdicts, finding sets and summary lines at both settings and across worker
  counts
- A collision found and unresolved closes the phase with a `#### Reasoned Exclusions` record
  rather than shipping the overlap

---

### Phase 11: Redeploy and Full-Gate Correctness Verification [IN PROGRESS]

**Goal**: Redeploy the source store, prove finding-set equivalence and verdict determinism for
the complete battery, confirm the new timeout layers actually fire, and close this task against
the complete gate set with an explicit source-store target.

This phase is CORRECTNESS ONLY. No wall-clock before/after measurement is taken here. The
efficiency question this task opened against has moved to the cost-model re-aim task along with
the phases that pursue it (see the note above Phase 12), and a timing comparison belongs with the
work that changes the timing. Every check below is a verdict or finding-set assertion, which is
invariant under host load -- so this phase does not require a quiet host and must not wait for
one. Deliverable framing: this task delivers the gate FRAMEWORK (declarative registry, uniform
bounded timeouts, gate-level scheduler, shared corpus enumeration, anchored verdict extraction),
and closes when that framework is proven correct.

**Tasks**:
- [ ] Run `bash <source_dir>/scripts/deploy-headless.sh` to regenerate the deployed `.claude/`
      tree from the source store.
- [ ] Confirm no file landing under `agent-system/**` contains a task-number reference or
      record-versioning language (`rules/no-task-references-in-deliverables.md`,
      `rules/no-record-versioning-in-deliverables.md`); both are permitted only in `specs/**`.
- [ ] Prove finding-set equivalence for the complete battery against the pre-task capture, with
      the three known pre-existing failures present on both sides and explicitly not attributed
      to this work.
- [ ] Prove determinism: repeated complete runs at several worker counts produce identical gate
      verdicts and identical summary lines.
- [ ] Re-confirm the stalled-gate and stalled-suite fixtures still fire after all layers are in
      place.
- [ ] Re-verify `orchestrate-batch-gate.sh` and `orchestrate-cycle-plan.sh`'s Inter-Cycle Redeploy
      Checkpoint still function against the refactored interface, exit codes, and output shape.
- [ ] Run the complete gate set with an explicit source-store target:
      `bash <source_dir>/scripts/verify-deploy.sh <source_dir>` — the bare no-argument form
      defaults `TARGET` to `$(pwd)` and silently SKIPs every source-store-only gate.

**Timing**: 2 hours

**Depends on**: 1-10 (the framework phases). Explicitly NOT 12-17 — those are carried
by the cost-model re-aim task; see the note above Phase 12.

**Verification Tier**: full

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - record the measured per-gate before/after table and the determinism result
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - final regeneration against the refactored runner

**Verification**:
- `bash <source_dir>/scripts/verify-deploy.sh <source_dir>` — the complete gate set, source-store
  target explicit — exits with only the three known pre-existing failures, and its exit status is
  checked directly, not inferred from a stdout diff
- `bash <source_dir>/scripts/tests/run-all.sh` (bare, now parallel by default) exits 0 apart from
  the known-failures roster
- `bash <source_dir>/scripts/deploy-headless.sh` completes, and a post-deploy
  `bash .claude/scripts/verify-deploy.sh` run against the deployed tree agrees with the
  source-store run on every gate that is not source-store-only
- Per-gate before/after wall-clock table recorded against the Phase 3 CSV baseline, each figure
  carrying its measurement-time load capture, and every sample marked valid
- Whole-set wall clock reported alongside the per-gate sum, each labelled
- Identical verdicts and summary lines across repeated runs at several worker counts
- Stalled-gate and stalled-suite fixtures still fire

---

## Testing & Validation

- [ ] 14/14 extraction call sites prove identical finding sets before and after, each with a
      seeded violation reported on both sides
- [ ] An SGR-prefixed verdict row is selected; a `[PASS]` line quoting the token is not; an
      indented fixture-internal row is not; a line-initial row is
- [ ] `lint-gate-registry.sh` rejects a cyclic dependency, a missing timeout, and a duplicate id
- [ ] `test-gate-registry-resolution.sh` covers selection, cost-class selection, dependency
      ordering, dual-mode discovery, determinism across worker counts, and the serialized class
- [ ] Stalled-gate and stalled-suite fixtures each fire within their bound and name the right unit
- [ ] Shellcheck parallel and sequential finding sets identical; the experiment suite fails if
      parallel is not faster
- [ ] Per-gate finding-set equivalence after shared corpus enumeration; each lint still invocable
      standalone
- [ ] `run-all.sh` bare default parallel, `--jobs 1` byte-identical sequential, `RUN_ALL_NESTED`
      override intact
- [ ] All five `deploy_findings_snapshot` callers re-verified; a pre/post baseline comparison
      cannot be skewed by a one-sided noise row
- [ ] Both verify-deploy-testing suites pass with an unchanged case count and identical per-case
      verdicts after their nested invocations are narrowed
- [ ] The shellcheck acceptance suite's default path performs no production-corpus walk, and its
      seeded-violation and determinism cases still pass
- [ ] Every discovered suite has a hint row, and a truncated hint file still runs the same suite
      set
- [ ] `JOBS_CAP` backed by a recorded projection-versus-measurement table plus peak memory at the
      chosen cap, with `run-all.sh` verdicts identical at every worker count tested
- [ ] A contended measurement sample is marked invalid in the written CSV and cannot overwrite a
      clean one; a clean sample is marked valid
- [ ] Gate 3's finding set identical before and after any change to it, with a seeded violation
      per rule class touched
- [ ] Gate 8's serialized setting justified from code and audited, with identical verdicts and
      summary lines at whichever setting ships
- [ ] Complete gate set green (modulo the three known pre-existing failures) with an explicit
      source-store target, exit status checked directly

## Artifacts & Outputs

- `specs/411_refactor_verify_deploy_gate_framework/plans/01_gate-framework-refactor.md` (this file)
- `specs/411_refactor_verify_deploy_gate_framework/summaries/01_gate-framework-refactor-summary.md`
- New: `scripts/lib/gate-verdict-extract-lib.sh`, `scripts/lib/gate-registry-lib.sh`,
  `scripts/gate-registry.data`, `scripts/lint/lint-gate-registry.sh`,
  `scripts/measure-gate-costs.sh` (all under `agent-system/extensions/core/`)
- New suites: `test-gate-registry-resolution.sh`, `test-measure-gate-costs.sh`,
  `test-lint-shellcheck-parallel.sh`
- Modified: `verify-deploy.sh`, `tests/run-all.sh`, six lint scripts, four existing suites,
  `suite-cost-hints.txt`, `context/standards/shell-script-testing.md`
- Regenerated deployed tree via `deploy-headless.sh`
- A per-gate before/after wall-clock table plus the whole-set wall clock, each figure carrying its
  measurement-time load capture and validity marking
- Per-invocation attribution tables for the two verify-deploy-testing suites
- A projection-versus-measurement table for `JOBS_CAP` at 2/4/8/12 workers, with peak memory and
  concurrent-fixture count at the chosen cap
- Gate 3's cost attribution across its rule checks
- A recorded audit of what gate 8's serialized isolation actually defends against

## Rollback/Contingency

- Each phase is committed separately, so reverting one phase is a single-commit revert. Phases 4
  and 5 split the migration at a boundary where the unmigrated gates still run the legacy inline
  path, so an interrupted migration is functional rather than broken.
- If Phase 3's re-derived cost model shows the dominant cost is Gate 3 or the
  6/7/9/10/11/21/23 cluster rather than Gate 22, Phase 8 is descoped to a minimum and the
  released effort goes to the dominant gate instead. Phase 3 is a decision gate in exactly the
  sense `plan-format.md`'s "Decision gates and contingency branches" section defines: a bypassed
  Phase 8 closes as `[COMPLETED WITH EXCLUSIONS]` with a `#### Reasoned Exclusions` record whose
  Evidence column cites Phase 3's own measurement, never left `[NOT STARTED]`.
- If Phase 7's per-gate parallelism-safety audit finds collisions it cannot resolve, the
  concurrency layer ships with the colliding gates in the serialized class rather than being
  abandoned; the registry and timeout layers stand on their own.
- If a rollback must discard uncommitted work, take a snapshot first per
  `context/contracts/recovery.md`'s rollback rung (which names the exact invocation shape and its
  out-of-scope override flag) before running any destructive git command.
- `deploy-headless.sh` is re-runnable, so a bad deployed tree is repaired by redeploying from the
  reverted source store rather than by hand-editing `.claude/**`.
- Phases 16 and 17 are derived additions beyond the four areas the revision brief enumerated, and
  each is independently droppable: phases 12-15 stand without either, and dropping one does not
  change the other's premise. Each also carries its own evidence gate, so a phase whose premise
  the measurement does not support closes as `[COMPLETED WITH EXCLUSIONS]` with that measurement
  as Evidence rather than being forced through.
- Phase 14's cap change is a single constant: if the measured peak memory or concurrent-fixture
  count at the candidate cap is unacceptable, the cap stays at 4 and the header records why on the
  current evidence. That is a complete outcome for the phase, not a failure of it.
- Phase 12's narrowing is per invocation, so a case whose narrowed selection turns out not to
  cover what it asserts is reverted to its full-battery call individually, without disturbing the
  other cases in the same suite.
