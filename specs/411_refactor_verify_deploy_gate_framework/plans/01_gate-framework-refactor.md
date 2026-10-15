# Implementation Plan: Task #411

- **Task**: 411 - Systematically refactor the verify-deploy gate set and shell test runner into a unified, parallel, declarative gate framework
- **Status**: [IMPLEMENTING]
- **Effort**: 20 hours
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
3. **The "12 nested verify-deploy.sh invocations" straggler lever was already pulled.**
   `test-verify-deploy-context-budget.sh` holds 4 invocations today, already reduced from 4
   full-battery to 1 full-battery + 3 `--only-gate 20` calls by a prior change. Its residual cost
   is the one necessary full-battery call, which shrinks automatically as this task's registry and
   concurrency work lands. No separate suite-splitting phase is planned.

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

**Non-Goals**:
- Fixing the three known pre-existing failures (Gate 3 lean4 doc-lint index.json entry; Gate 20
  eager-load budget ~988B overage; the Gate 8 suites `test-detect-noop-bash.sh`,
  `test-four-tier-conflict.sh`, `test-guard-git-push.sh`). They are baselined, not repaired.
- Weakening any gate's assertion for speed, in any amount.
- Splitting `test-verify-deploy-context-budget.sh` or further reducing its invocation count — that
  lever was already pulled (Research Integration item 3).
- Raising `JOBS_CAP` as a speed measure — the suite pool is straggler-bound from jobs=4 onward, so
  the cap is not the constraint.
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
| 8 | 11 | 8, 9, 10 |

Phases within the same wave can execute in parallel.

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

### Phase 4: Gate Registry Schema, Shared Runner Library, and Migration of Gates 1-8 [NOT STARTED]

**Goal**: Introduce the declarative registry and its sequential shared runner, and migrate the
first tranche of gates onto it with byte-identical output, leaving the unmigrated gates on the
legacy path so an interrupted state stays functional.

**Tasks**:
- [ ] Define the registry data shape on the `manifest-routing-lib.sh` precedent: structured data
      declaration plus one shared sourced interpreter. Fields per gate: id, name, command,
      dependencies, timeout, cost class, remedy text, `requires_source_store`, anchor token,
      serialized-class flag.
- [ ] Add `scripts/lib/gate-registry-lib.sh`: parses the registry, resolves selection, and
      executes one gate, emitting the same `say`/`pass`/`fail`/`warn` shapes and populating
      `FINDINGS_LIST` through Phase 1's extraction helper. Per-gate state must be scoped (subshell
      or associative array keyed by gate id) rather than relying on a single reassigned
      `CURRENT_GATE` global — a prerequisite for Phase 7's concurrency.
- [ ] Fold the repeated source-store-only guard
      (`[ ! -d "$TARGET/agent-system/extensions" ] && say "[SKIP] ..."`) into the
      `requires_source_store` registry field.
- [ ] Migrate gates 1-8 onto the registry; leave gates 9-23 on the legacy inline path.
- [ ] Add `scripts/lint/lint-gate-registry.sh` validating the registry data (every declared
      dependency exists, no cycle, every gate has a timeout and cost class, ids are unique and
      contiguous) and `scripts/tests/test-gate-registry-resolution.sh` for the interpreter — the
      lint-plus-resolution-test pattern `manifest-routing-lib.sh` already establishes.
- [ ] Capture `--only-gate 1,2,3,4,5,6,7,8` output before and after; require byte-identical
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

### Phase 5: Migrate Gates 9-23 and Generalize the Selection Surface [NOT STARTED]

**Goal**: Complete the migration so every gate runs through the registry, delete the remaining
copy-pasted blocks, and generalize selection to include cost class alongside `--skip-slow` and
`--only-gate`.

**Tasks**:
- [ ] Migrate gates 9-23 onto the registry and delete their inline blocks.
- [ ] Preserve `--skip-slow` and `--only-gate` semantics exactly, including the
      zero-check-under-filter exit-2 condition documented in `verify-deploy.sh`'s header.
- [ ] Add selection by cost class (e.g. `--max-cost <class>`) resolved from Phase 3's generated
      cost model, so a caller can ask for "everything under N seconds" without naming gates.
- [ ] Keep the deployed-vs-source-store dual-mode discovery intact and covered by a test.
- [ ] Re-verify each of `deploy_findings_snapshot`'s five callers
      (`orchestrate-batch-gate.sh`, `orchestrate-cycle-plan.sh`, `command-gate-out.sh`,
      `verify-deploy.sh` itself, and the test harnesses) against the migrated aggregator.
- [ ] Explicitly confirm a pre/post baseline comparison cannot be skewed by a noise row appearing
      in one capture and not the other — seed the scenario and assert the comparison's verdict.
- [ ] Capture the complete battery's output before and after with an explicit source-store
      `TARGET`; require identical finding sets and identical exit code. Baseline the three known
      pre-existing failures explicitly so they are not attributed to this work.

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

### Phase 6: Uniform Bounded Timeouts Per Gate and Per Suite [NOT STARTED]

**Goal**: Make a hang a loud, attributable failure instead of an indefinite stall, at both the
gate and the suite grain, and prove each bound actually fires.

**Tasks**:
- [ ] Add a per-gate timeout, read from the registry's `timeout` field, applied by the shared
      runner. Size each bound from Phase 3's measured maximum with explicit, stated headroom.
- [ ] Add a per-suite timeout in `run-all.sh`, applied identically in the sequential and
      `run_one()` parallel paths (confirmed live: `run-all.sh` and `verify-deploy.sh` today
      contain zero `timeout` invocations).
- [ ] A timeout must produce a named, attributable failure identifying the gate or suite and the
      bound it exceeded — never a generic non-zero exit.
- [ ] Add a deliberately-stalled fixture (a suite that sleeps past its bound, and a registry
      entry pointing at a stalling command) and assert in test that each bound fires, that the
      failure names the right unit, and that the run continues to a stable summary rather than
      aborting.
- [ ] Run the complete battery and confirm no existing gate or suite trips its bound.

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

### Phase 7: Gate-Level Concurrency Scheduler [NOT STARTED]

**Goal**: Run independent gates concurrently with declared dependencies, ported in shape from
`run-all.sh`'s proven scheduler, with parallelism-safety established per gate rather than assumed.

**Tasks**:
- [ ] Read `run-all.sh`'s rejected-alternatives header before writing any scheduler code, and
      respect both of its recorded rejections (a fixed cap rather than bare `nproc`; no
      self-maintaining timing cache). Do not re-propose either.
- [ ] Port the scheduler shape: a `wait -n` worker-slot pool against a declared cap, per-gate
      output captured to its own file, and a final emission loop that walks gates in **declaration
      order** regardless of completion order.
- [ ] Schedule longest-first from Phase 3's cost model, and honour the registry's declared
      dependency edges so a dependent gate never starts before its prerequisites finish.
- [ ] Perform an explicit per-gate parallelism-safety audit and record it alongside
      `run-all.sh`'s existing audit, extending that discipline rather than inventing a parallel
      notion of it. Give unsafe gates a serialized class run alone, mirroring
      `LOAD_SENSITIVE_BASENAMES`. Audit Gate 20's fixture files and Gate 13's headless nvim
      invocation specifically.
- [ ] Add a nested-invocation guard at the gate grain analogous to `RUN_ALL_NESTED`, so a gate
      that shells out to `verify-deploy.sh` cannot fan out recursively.
- [ ] Prove determinism: identical gate verdicts and an identical summary line at several worker
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

### Phase 8: One-Process-Per-File Shellcheck Parallelization [NOT STARTED]

**Goal**: Parallelize `lint-shellcheck.sh` in the one shape the research measured as a win, with
the worker-count experiment as a repeatable acceptance gate rather than a one-off.

**Tasks**:
- [ ] Implement one-process-per-file dispatch following `run-all.sh`'s `run_one()` shape: one
      file, one background job, output captured to its own file, `wait -n`-scheduled against a
      worker cap. Do **not** batch multiple files per `shellcheck` invocation.
- [ ] Record in the script header why batched dispatch is prohibited: every batched shape measured
      (`-P24 -n20`, `-P4 -n96`, `-P8 -n48`) was *slower* than sequential; only `-n 1` won.
- [ ] Choose the worker cap from a fresh run of the experiment, not a bare `nproc`.
- [ ] Add the experiment to `scripts/tests/` as a repeatable acceptance check that fails if the
      parallel path is slower than the sequential path on the real corpus.
- [ ] Preserve deterministic, discovery-order finding output regardless of worker count.
- [ ] Prove finding-set equivalence: identical findings sequentially and in parallel on the real
      corpus, plus a seeded violation reported in both.

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

### Phase 9: Shared Corpus Enumeration [NOT STARTED]

**Goal**: Enumerate the tracked-file corpus once per invocation and let every gate derive its own
filtered view, eliminating the duplicated per-gate filesystem walk.

**Tasks**:
- [ ] Produce one master tracked-path list per `verify-deploy.sh` invocation (a single
      `git ls-files` over the resolved source store) and expose it to gates through the registry
      runner.
- [ ] Give each gate a derived, in-memory filtered view by its own pattern. Do **not** assume one
      list satisfies every gate unmodified: today's lints use differing filters (`*.sh`, `*.md`,
      `*.sh`+`*.md`, `*.json`, `SKILL.md`, `manifest.json`) and only `lint-shellcheck.sh` uses
      `git ls-files` at all; the rest use `find`.
- [ ] Preserve each lint's standalone invocability — a lint must still work when run directly,
      falling back to its own enumeration when no shared corpus is supplied.
- [ ] Preserve the `find`-based fallback `lint-shellcheck.sh` documents for fixture tests, where
      `git ls-files` cannot serve.
- [ ] Prove finding-set equivalence per affected gate, not in aggregate, with a seeded violation
      per gate.

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

### Phase 10: Flip run-all.sh's Default to Parallel [NOT STARTED]

**Goal**: Stop a bare `run-all.sh` invocation from being several times slower than the same work
via Gate 8, while preserving the byte-identical sequential path its own header promises at
`--jobs 1`.

**Tasks**:
- [ ] Change the `JOBS=1` default (run-all.sh:145) to `auto`.
- [ ] Preserve `--jobs 1` as the explicit opt-out routing to the existing, structurally separate
      sequential code path, unchanged.
- [ ] Leave `JOBS_CAP=4` alone and record why in the header: the suite pool is work-bound at
      jobs<=2 and straggler-bound from jobs=4 onward, so raising the cap buys nothing. Note that
      an explicit `--jobs 12` already bypasses the cap entirely and already does nothing useful.
- [ ] Confirm the `RUN_ALL_NESTED` guard still forces `JOBS=1` under nesting now that the
      un-nested default is parallel — this is the interaction most at risk from the flip.
- [ ] Confirm the `LOAD_SENSITIVE_BASENAMES` serialized set still runs alone, before the pool.
- [ ] Add test cases pinning the new default, the `--jobs 1` opt-out, and the nested override.

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

### Phase 11: Redeploy, Measured Before/After, and Full-Gate Verification [NOT STARTED]

**Goal**: Redeploy the source store, take the mandated idle before/after measurement as a per-gate
table, prove determinism and finding-set equivalence end to end, and close the task against the
complete gate set with an explicit source-store target.

**Tasks**:
- [ ] Run `bash <source_dir>/scripts/deploy-headless.sh` to regenerate the deployed `.claude/`
      tree from the source store.
- [ ] Confirm no file landing under `agent-system/**` contains a task-number reference or
      record-versioning language (`rules/no-task-references-in-deliverables.md`,
      `rules/no-record-versioning-in-deliverables.md`); both are permitted only in `specs/**`.
- [ ] Take the before/after wall-clock measurement on an idle machine (1-minute load average
      below 2, recorded alongside each figure) via Phase 3's harness, reported as a **per-gate
      table**, not a single aggregate. Re-take the baseline quiet: the dispatch's original
      22-28 minute figures came from four concurrent gate runs and are invalid for comparison.
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

**Depends on**: 8, 9, 10

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
- Per-gate before/after wall-clock table recorded, each figure carrying its measurement-time load
  average
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
- A per-gate before/after wall-clock table, each figure carrying its measurement-time load average

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
