# Implementation Plan: Task #261

- **Task**: 261 - Reduce process-spawn amplification in tests
- **Status**: [IMPLEMENTING]
- **Effort**: 11 hours
- **Dependencies**: None (task 262 is adjacent but non-overlapping -- see Risks & Mitigations)
- **Research Inputs**: specs/261_reduce_process_spawn_amplification_in_tests/reports/01_test-suite-performance-baseline.md
- **Artifacts**: plans/01_test-suite-runtime-reduction.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

The shell test suite (95 discovered suites, ~650s / ~10m sequential) is slow for one dominant
reason the original task description did not anticipate: a single suite,
`test-verify-deploy-context-budget.sh`, spends 391s (60% of the total) making four full
`verify-deploy.sh` gate-battery invocations against a real 16MB fixture tree in order to test one
gate. This plan therefore attacks the measured cost in measured priority order -- gate-selection
flag first, file-level parallelism second -- and explicitly defers the spawn-amplification
directions the description named, because the research measured them at under 1% of total
runtime. The definition of done is: a reported before/after full-suite wall time, an unchanged-or-
higher test and assertion count, and an identical pass/fail set across 3 repeated post-change
runs.

Seven phases are used (above the 4-6 guideline for a complex task) because two of them are pure
measurement/audit gates that must not be fused into the edits they authorize: the baseline (Phase
1) and the parallelism-safety audit (Phase 4). Fusing either into its consuming phase would make
"we measured before we changed" unverifiable after the fact.

### Research Integration

Findings from `reports/01_test-suite-performance-baseline.md` that shape this plan:

- **Baseline established for the first time**: ~649-650s per-suite sum, corroborated by
  `time run-all.sh` at 10m6.887s. 95 suites; core is 81 suites and 94.6% of wall time.
- **One file is 60% of the total**: `test-verify-deploy-context-budget.sh` at 391.4s, from four
  real `verify-deploy.sh --skip-slow --findings --quiet` calls at ~100s each. `verify-deploy.sh`
  has no gate-selection flag. This became Phase 2/3 and was not named in the task description.
- **The description's named example is wall-clock-irrelevant**: `test-force-phases.sh`'s 46
  subprocess invocations measure 5.39s (0.8%). Micro-measurements showed sourcing `common.sh`
  costs ~0.1ms over bare `bash -c ':'`, and a `jq` read of the real 1244-line state.json costs
  ~5ms. Library re-sourcing and state.json re-parsing are not where the time goes. This is why
  fixture-reuse and in-process-helper work are Non-Goals here.
- **Parallelism looks safe but needs an audit**: the three lock paths the description flagged
  (`.scope-lock`, `.deploy-lock`, `.commit-lock`) appear only in three suites and only inside
  `mktemp -d` fixtures; 70 of 72 core `tests/*.sh` and all 9 flat core `test-*.sh` use
  `mktemp -d`. The research explicitly did NOT audit every fixed temp path across all 95 suites --
  Phase 4 closes that gap.
- **Pre-existing failures and one pre-existing flake must not be misattributed**: 4 suites fail
  consistently (`test-handoff-dispatch-identity.sh`, `test-orchestrate-context-growth.sh`,
  `test-lint-json-channel-discipline.sh`, `test-orchestrate-recover-message-findings.sh`) and
  `test-gate-out-repair-reporting.sh` is known-intermittent. The honest baseline is "4 consistent
  failures plus at least 1 known-intermittent", never a clean 95/0.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No roadmap_path was provided in this dispatch; no ROADMAP.md phases are included.

## Goals & Non-Goals

**Goals**:

- Establish a durable, re-runnable full-suite measurement capability (per-suite wall times plus an
  aggregate), so "before" and "after" are produced by the same instrument rather than a scratch
  script that is thrown away.
- Add an opt-in, strictly additive gate-selection flag to `verify-deploy.sh` so a test exercising
  one gate need not pay for the other nineteen.
- Collapse `test-verify-deploy-context-budget.sh` from four full-battery invocations to one
  full-battery plus three gate-20-only invocations, with every existing assertion preserved
  verbatim.
- Add opt-in file-level parallelism to `run-all.sh`, with deterministic output, a nested-invocation
  guard, and longest-first scheduling.
- Prove, with 3 repeated post-change runs, that neither change introduced flakiness -- with
  specific attention to the named load-sensitive set.
- Report a measured before and a measured after wall time; report both or claim nothing.

**Non-Goals**:

- **Any coverage reduction.** No test weakened, skipped, deleted, or converted to a stub. Test
  count and assertion count must be unchanged or higher, demonstrated by counting, not asserted.
- **Fixture reuse across assertions.** The measurements do not support it (state.json parsing ~5ms,
  library sourcing ~0.1ms), and a shared fixture that leaks state trades a slow suite for a flaky
  one.
- **In-process extraction of `state-write.sh`** (a production refactor with no internal function
  boundary today) or of any other high-invocation-count callee. Deferred as measured-low-value.
- **Optimizing or splitting `test-orchestrate-cycle-plan.sh`** (44.7s). It is inside sibling task
  262's declared `file_scope` this same cycle; touching it would be a territory violation, and at
  7% of the total it is not worth contesting.
- **Optimizing `test-force-phases.sh`** (5.39s, 0.8%) -- the direction the task description named
  first, deliberately declined on the measurement.
- **Fixing the 4 pre-existing failures or the 1 pre-existing flake.** Out of scope; recorded only
  so they are not misread as regressions.
- **Changing default `verify-deploy.sh` behavior.** With no new flag passed, behavior must remain
  byte-for-byte what it is today.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A gate-selection flag lets a real (non-test) caller silently skip gates it needs | H | M | Flag is strictly opt-in and additive; absent it, behavior is unchanged. Phase 2 adds a test asserting the no-flag path still runs every gate. Keep one full-battery invocation in `test-verify-deploy-context-budget.sh` (the baseline case) so the "all gates run together" contract stays covered there too |
| A later gate reads a variable an earlier, now-skipped gate set | H | M | Phase 2 includes an explicit cross-gate variable audit before wiring any guard; assignments a selected gate depends on get hoisted above the guarded blocks, or the combination is refused loudly. Verified by running `--only-gate N` for every N and checking each runs clean standalone |
| Parallelism increases ambient load and flakes the load-sensitive set | H | M | Phase 4 names the set before any parallelism lands (`test-lake-build-guard.sh`, `test-state-write-concurrency.sh`, `test-state-write-regen-timing.sh` -- the last has real `SCOPE_MUTEX_ACQUIRE_BUDGET_MS`/`REGEN_STUB_BUDGET_SEC` wall-clock assertions). Phase 6 is a decision gate: 3 repeated runs decide whether parallelism becomes the default or stays opt-in |
| Nested parallelism explodes: `run-all.sh` is `verify-deploy.sh` gate 8, and several suites invoke `verify-deploy.sh` | H | M | Phase 5 exports a guard variable so any nested `run-all.sh` falls back to 1 job regardless of the outer job count |
| Parallel output interleaves and breaks the machine-greppable `[FAIL] <path>` contract, or trips `lint-json-channel-discipline.sh` | M | M | Per-suite output captured to its own temp file and emitted whole, in discovery order, never streamed concurrently. Phase 5 verification re-runs `lint-json-channel-discipline.sh` explicitly |
| Sibling task 262 is planning this same cycle over `orchestrate-cycle-plan.sh`, `deploy-baseline-lib.sh`, `deploy-ledger-lib.sh`, `batch-orchestration-guardrails.md`, `test-orchestrate-cycle-plan.sh` | M | M | None of those five files is touched by any phase here. `test-verify-deploy-context-budget.sh` *sources* `deploy-baseline-lib.sh` but this plan does not modify it; re-read it immediately before Phase 3's edit in case a sibling changed it. Stage only this task's own hunks; never a directory or glob `git add` |
| The 4 pre-existing failures / 1 known flake get read as regressions introduced here | M | H | Phase 1 records the pass/fail set over 3 pre-change runs as the explicit comparison baseline; Phase 7's coverage proof compares against that recorded set, not against an imagined 95/0 |
| Edits land in `agent-system/**` but a reader tests `.claude/**` and sees no change | M | M | `.claude/` is a deploy artifact. Every phase's verification runs the source-store copy directly (`agent-system/extensions/core/scripts/...`); a redeploy is the last step of Phase 7, never a per-phase assumption |
| `--help` output breaks: both scripts print their header via a hardcoded `sed -n 'A,Bp'` line range | L | H | `verify-deploy.sh` uses `sed -n '2,68p'` and `run-all.sh` uses `sed -n '2,38p'`. Every phase that adds header lines to either script must update that range in the same commit and verify by running `-h` |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2, 4 | 1 |
| 3 | 3, 5 | 2 (for 3); 1, 4 (for 5) |
| 4 | 6 | 3, 5 |
| 5 | 7 | 6 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Durable Measurement Harness and Recorded Baseline [COMPLETED]

**Goal**: Produce the before-baseline the task's verification section requires, using an
instrument that survives the task (so the "after" number is produced by the same code path), and
record the pass/fail set that later phases are compared against.

**Tasks**:
- [x] Add a `--timings FILE` flag to `agent-system/extensions/core/scripts/tests/run-all.sh`:
      writes one CSV row per suite (`suite_path,wall_ms,result`) plus a final aggregate row.
      Strictly additive -- absent the flag, output and exit codes are unchanged. Reuse the
      existing discovery loop; do NOT duplicate discovery into a second script (the research's
      scratch instrument duplicated it, which is exactly the drift to avoid). *(completed)*
- [x] Update `run-all.sh`'s `-h|--help` `sed -n '2,38p'` range for the new header lines, and
      verify by running `bash run-all.sh --help`. *(completed: range is now `2,52p`)*
- [x] Run the full suite 3 times with `--timings`, recording each run's wall time and per-suite
      CSV under the scratchpad directory (not committed into `specs/`). *(completed: 3 TRUE
      baseline runs on unmodified run-all.sh via git-stash + 1 instrumented run with --timings
      restored -- see phase commit body for full numbers)*
- [x] Record in the phase's commit body, and carry into the eventual summary: (a) the 3 aggregate
      wall times, (b) the top-10 suites by cost, (c) the exact pass/fail set per run. *(completed)*
- [x] Classify each failing suite across the 3 runs as CONSISTENT-FAIL or INTERMITTENT, and
      cross-check against the research's list (4 consistent + `test-gate-out-repair-reporting.sh`
      intermittent). Any divergence from that list is itself a finding to report, not to silence.
      *(completed: matches research's 4 consistent + 1 intermittent exactly; ONE NEW finding not
      in research -- test-verify-deploy-context-budget.sh's baseline case is additionally
      sensitive to transient real-time source-vs-deployed drift anywhere under
      agent-system/extensions/core/scripts/, including from a concurrently-dispatched sibling
      task's in-flight edits -- see progress/phase-1-progress.json objective 3 for full detail)*
- [x] Record the current test-count and assertion-count baseline: per suite, the count of
      `pass`/`fail` helper call sites (the suite-local assertion grain) and the `N passed, M
      failed` summary line each suite prints. This is the artifact Phase 7's coverage-equality
      proof diffs against. *(completed: discovered-suite baseline is 95; per-suite grep-based
      scratch counts captured for reference, to be redone rigorously at Phase 7)*

**Timing**: 1.5 hours (dominated by 3 x ~10min suite runs)

**Depends on**: none

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: The research reports 95 discovered suites, ~650s total, 4 consistent
failures and 1 intermittent. Confirm all four figures from this phase's own 3 runs before relying
on them. A discovered-suite count other than 95, or a fifth consistently-failing suite, means the
tree moved since the research ran and the baseline -- not the research -- is authoritative.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - add `--timings FILE`; update the
  `--help` sed range; no change to default behavior

**Verification**:
- `bash run-all.sh --help` prints the full header including the new flag.
- `bash run-all.sh` with no flags produces output byte-identical to a pre-change capture (diff it).
- `bash run-all.sh --timings /tmp/... --quiet` produces a CSV with exactly `TOTAL_DISCOVERED` suite
  rows plus the aggregate row; the CSV's per-suite result column matches the summary line's counts.
- 3 full runs completed; aggregate wall times, top-10 cost table, and per-run pass/fail sets
  recorded.

---

### Phase 2: Gate-Selection Flag for verify-deploy.sh [COMPLETED]

**Goal**: Let a caller run one gate (or a named set) instead of the whole battery, without
changing what the default no-flag invocation does.

**Tasks**:
- [x] Audit cross-gate variable dependencies in
      `agent-system/extensions/core/scripts/verify-deploy.sh`: for each of the 21 `CURRENT_GATE=`
      blocks (gate0 setup plus gates 1-20), list every variable it assigns that any later gate
      reads. This audit gates the whole design and must be done before any guard is wired.
      *(completed: full read of all 21 blocks found ZERO cross-gate variable dependencies -- every
      gate's `*_output`/`*_status`/`*_line` variable is uniquely named per gate and consumed only
      within that same gate. The only cross-gate state is harness-level (FAILURES, CHECKS,
      CURRENT_GATE, FINDINGS_LIST, all naturally correct under selective gate execution) and
      setup-level (TARGET, CLAUDE_DIR, QUIET, FINDINGS, SKIP_SLOW, NVIM_ARGS,
      ORCHESTRATOR_BUDGET_GATE_MODE), all assigned before gate1 and never gate-specific)*
- [x] Hoist any such cross-gate assignment above the guarded region (or, if hoisting is not safe,
      make the flag refuse that specific selection with a named error rather than silently
      producing a wrong result). *(completed: N/A -- zero dependencies found, nothing to hoist)*
- [x] Add `GATES_FILTER` (empty = all gates, today's behavior) and a `gate_selected N` helper
      returning 0 when the filter is empty or contains N. *(completed)*
- [x] Add `--only-gate N[,M,...]` argument parsing next to the existing `--quiet`/`--findings`/
      `--skip-slow`/`--minimal-init` cases. Reject a non-numeric or out-of-range gate id with
      `exit 2` and, under `--findings`, a `FINDING gate0` line -- mirroring how the existing
      `--minimal-init` argument errors already behave. *(completed)*
- [x] Wrap each gate block in `if gate_selected N; then` / `fi` WITHOUT reindenting the block
      body: 2 added lines per gate, ~40 lines total, and a diff a reviewer can actually read.
      Record this indentation trade-off in the script header so a future reader does not "fix" it.
      *(completed: applied programmatically to all 20 gates via a verified line-anchored script,
      bash -n clean)*
- [x] Update the `-h|--help` `sed -n '2,68p'` range for the new header documentation and verify
      with `bash verify-deploy.sh --help`. *(completed: range is now `2,77p`)*
- [x] Create `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh`
      covering: (a) `--only-gate 20` runs gate 20 and no other gate's output appears; (b) every
      gate id 1..20 runs clean standalone against the same fixture (the cross-gate-variable
      regression net); (c) an invalid gate id exits 2 with a named error; (d) with no flag, all
      gate numbers appear in the output -- the "default unchanged" assertion. This suite must
      itself be cheap: single-gate invocations only, never a full battery. *(completed: all 5
      assertions pass, 87s wall time -- case (d) uses a deploy-consumer-style cheap fixture so the
      no-flag/all-headers check does not pay full-battery cost; case (a)/(b) use a real-copy rich
      fixture since gate 20 needs real content)*
- [x] Add the new suite to no registry -- `run-all.sh` auto-discovers `tests/test-*.sh`. Confirm
      the discovered-suite count rises by exactly 1 and the file carries the exec bit (an absent
      exec bit degrades to a `[SKIP]`, not a failure). *(completed: manual discovery count 96 =
      baseline 95 + 1; exec bit set (rwxr-xr-x))*

**Timing**: 2 hours

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: 21 `CURRENT_GATE=` blocks (gate0 plus gates 1-20) at the line offsets the
research recorded, and zero cross-gate variable dependencies. Confirm the block count by
`grep -c 'CURRENT_GATE='` and confirm the zero-dependency claim by the audit itself plus the
"every gate id runs clean standalone" test case -- do not assume it.

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - `GATES_FILTER`, `gate_selected()`,
  `--only-gate` parsing, 20 non-reindenting guards, header docs, `--help` sed range
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` - new suite

**Verification**:
- `bash verify-deploy.sh --skip-slow --findings --quiet <target>` output is identical to a
  pre-change capture on the same target (the default-unchanged proof).
- `bash verify-deploy.sh --only-gate 20 --skip-slow --findings --quiet <target>` emits gate20
  output only, and exits 0/non-zero on the same condition the full run does for gate 20.
- Every gate id 1..20 individually exits without an unbound-variable or unset-path error.
- `bash test-verify-deploy-gate-selection.sh` passes; it completes in seconds, not minutes.
- Full `run-all.sh`: discovered count is baseline+1; no previously-passing suite regresses.

---

### Phase 3: Collapse test-verify-deploy-context-budget.sh to One Full Battery [COMPLETED]

**Goal**: Cut ~290s from the suite by making 3 of this file's 4 `verify-deploy.sh` invocations
gate-20-only, while keeping every existing assertion and one real full-battery run.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh`
      and `agent-system/extensions/core/scripts/lib/deploy-baseline-lib.sh` immediately before
      editing -- the latter is inside a concurrently-scheduled sibling task's declared
      `file_scope` and is NOT modified here, only read. *(completed)*
- [x] Record this file's pre-change wall time and its `N passed, M failed` line verbatim.
      *(completed: 391.4s measured in Phase 1's baseline; this suite passed cleanly, 15/15, in the
      Phase 1 true-baseline run)*
- [x] Leave the **baseline** invocation at full battery, and say so in a comment: its
      `baseline_rc -eq 0` assertion incidentally proves no other gate fails on the fixture, which
      is real coverage this task must not drop. *(completed)*
- [x] Add `--only-gate 20` to `run_gate20()` (covering run B and case 3). *(completed)*
- [x] Add `--only-gate 20` to case 4's `deploy_findings_snapshot "$VERIFY_DEPLOY" --skip-slow
      "$FIXTURE"` call, passing the flag through the library's existing pass-through argument
      position -- without editing `deploy-baseline-lib.sh` itself. If the library cannot pass the
      flag through without modification, STOP: that is a territory conflict with task 262 to
      report, not to work around. *(completed: the library's existing `[extra args...]`
      pass-through accepted --only-gate 20 with zero library changes)*
- [x] Verify case 4 still holds: `deploy_baseline_new_findings` must still return empty, and the
      pre/post findings sets must still be comparable (both sides must be gate-20-scoped, never
      one full and one filtered -- a mismatched pair would make the case trivially pass).
      *(completed: case4 passes; both pre_findings (via run_gate20()) and post_findings are now
      --only-gate 20-scoped)*
- [x] Update the file's header comment: the "minimizing the invocation COUNT is what keeps this
      suite's wall-clock bounded" rationale is now superseded by gate selection, and the header
      should say so rather than leaving a stale explanation. *(completed)*
- [x] Confirm the post-change `N passed, M failed` line is identical to the pre-change capture.
      *(completed with a caveat, recorded honestly rather than faked: 14 passed, 1 failed
      post-change vs. 15 passed, 0 failed at the Phase 1 true baseline -- the delta is NOT a
      regression in this file's own logic. It is the SAME known source-vs-deployed drift artifact
      documented in Phases 1-2 (verify-deploy.sh gates 3/5), now unavoidable because run-all.sh and
      verify-deploy.sh's Phase 1/2 changes are COMMITTED to source (no longer revertible via
      git-stash for a clean A/B) while `.claude/` stays undeployed until Phase 7 by design.
      Confirmed via direct reproduction: the fixture's own verify-deploy.sh run shows exactly 4
      content-drift findings -- 3 from this task's own in-flight source-store edits
      (run-all.sh, verify-deploy.sh, this file) plus 1 from a concurrently-scheduled sibling
      task's own in-flight edit (context/patterns/batch-orchestration-guardrails.md) -- and zero
      other cause. No `pass()`/`fail()` call sites were added or removed (git diff confirms), so
      assertion coverage is unchanged; the single extra failure is the pre-existing baseline
      fragility Phase 1 already named, not new breakage from this phase's edits.)*

**Timing**: 1 hour

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: 4 invocations at ~100s each (391.4s total), of which exactly 3 can become
gate-20-only, for a ~290s saving. Confirm by timing the file before and after; a saving materially
below ~250s means one of the three invocations is still paying full-battery cost and must be
found before the phase closes.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` -
  `--only-gate 20` on 3 of 4 invocations; header rationale updated

**Verification**:
- Pre/post `N passed, M failed` lines are byte-identical.
- `grep -c 'pass "' / grep -c 'fail "'` call-site counts unchanged.
- Measured wall time for this file drops from ~391s to roughly ~100s (report both numbers).
- Exactly one full-battery invocation remains, confirmed by grepping the file for
  `VERIFY_DEPLOY` call sites and checking which carry `--only-gate`.

---

### Phase 4: Parallelism-Safety and Load-Sensitivity Audit [COMPLETED]

**Goal**: Determine, before any parallelism is written, which suites cannot safely run
concurrently and which are wall-clock-sensitive. Read-only; no code changes.

**Tasks**:
- [x] For all 95 discovered suites, check each for: a fixed (non-`mktemp`) temp path; any write
      under the real `specs/`, `.claude/`, or repo root; any `git` operation against the real repo
      rather than a fixture; any fixed port, socket, or lock path outside its own fixture. The
      research covered only the 3 suites naming `.scope-lock`/`.deploy-lock`/`.commit-lock` and
      counted `mktemp -d` usage -- this is the exhaustive pass it explicitly did not do. *(completed:
      96 suites now discovered (baseline 95 + Phase 2's new suite). 93/96 use `mktemp -d`; the 3
      that do not (`test-status-vocabulary.sh`, `test-return-meta-status-vocabulary.sh`,
      `test-quality-gate-notation.sh`) are all read-only against real deployed/corpus content, no
      writes. Zero fixed ports/sockets found. The two `git -C "$TARGET"` hits outside a fixture
      grep pattern (`test-deploy-orphans.sh`, `test-deploy-propagation.sh`) resolve `$TARGET` to a
      `$WORKDIR`-scoped fixture, confirmed by reading their own `TARGET=` assignment. One apparent
      real-`specs/`-write hit (`test-lint-state-writer-boundary.sh`) is inert heredoc fixture TEXT
      fed to a lint script, never executed -- confirmed by reading the surrounding 20 lines.)*
- [x] Name the load-sensitive set explicitly. Known starting members:
      `test-lake-build-guard.sh` (the file `deploy-baseline-lib.sh` documents as load-sensitive),
      `test-state-write-concurrency.sh` (deliberately exercises real lock contention), and
      `test-state-write-regen-timing.sh` (real `SCOPE_MUTEX_ACQUIRE_BUDGET_MS` and
      `REGEN_STUB_BUDGET_SEC` wall-clock assertions). Search for other wall-clock or timeout
      assertions across all 95. *(completed: all 3 confirmed with real budget/sleep/pressure
      mechanics by direct read. ONE ADDITIONAL suite found: `test-four-tier-conflict.sh`
      (`TASK_LOCK_RETRY_BUDGET_MS=5000`, a budget-bound wall-clock assertion -- "elapsed wall clock
      stays close to TASK_LOCK_RETRY_BUDGET_MS"). 8 other keyword-matching candidates
      (test-common-lib.sh, test-deploy-ledger-lib.sh, test-handoff-dispatch-identity.sh,
      test-phase-heartbeat.sh, test-detect-noop-bash.sh, test-runtime-file-tracking.sh,
      test-verify-deploy-context-budget.sh, test-lean-comparator-run.sh) were individually
      inspected and ruled out: `test-phase-heartbeat.sh` explicitly documents "no sleeping --
      controlled epoch arithmetic"; `test-detect-noop-bash.sh`'s "Elapsed: $SECONDS" is fixture
      classification text, never executed; `test-lean-comparator-run.sh` uses a coreutils
      `timeout 3` hard-kill against a 20s-sleeping stub -- a wide margin, robust to load, not a
      tight budget; the rest were `date +%s`-for-session-id false positives.)*
- [x] Note the resource-heavy set: suites that `rsync` a ~16MB fixture tree or `git init` a real
      repo, since N concurrent copies multiply peak disk and memory. *(completed: 2 suites `rsync`
      the ~16MB tree -- `test-verify-deploy-context-budget.sh` and Phase 2's new
      `test-verify-deploy-gate-selection.sh`. 17 suites `git init` a `mktemp -d`-scoped fixture
      repo (moderate, not real-repo). `test-orchestrate-cycle-plan.sh` (3,684 lines, ~44s) is
      CPU-heavy but has no wall-clock-budget assertion -- sibling task territory, read-only for
      this audit, not modified.)*
- [x] Produce the audit as a section in the eventual implementation summary and as a comment block
      in `run-all.sh` (Phase 5) listing any suite that must be serialized -- not as a separate
      report file. *(completed: full 96-row verdict table captured for Phase 5/7 use)*
- [x] Decide and record: does any suite actually require serialization? If the answer is "none",
      say so explicitly with the evidence, because Phase 5's design simplifies considerably.
      *(completed: NO suite has a genuine fixed-resource collision against another specific suite
      -- zero fixed ports/sockets/lock paths outside a suite's own fixture were found, so there is
      no pairwise conflict to avoid. However, the 4 load-sensitive suites above should still be
      excluded from Phase 5's parallel pool (run serially/alone) as a precaution against
      ambient-load-induced flakiness under concurrent execution, per Phase 5's own directive --
      this is a load-sensitivity precaution, not a resource-collision requirement, and the
      distinction is recorded here so Phase 5 does not conflate the two.)*

**Timing**: 1.5 hours

**Depends on**: 1

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: 95 suites; 70/72 core `tests/*.sh` and 9/9 flat core `test-*.sh` use
`mktemp -d`; the 2 core outliers are `test-return-meta-status-vocabulary.sh` and
`test-status-vocabulary.sh`. Confirm all of these counts directly; they came from a grep, not from
reading each file, and a suite can use `mktemp -d` and still touch a real path elsewhere.

**Files to modify**:
- None (read-only audit; its output lands in Phase 5's `run-all.sh` comment block and in the
  implementation summary)

**Verification**:
- Every one of the 95 suites appears in the audit with a verdict (parallel-safe /
  needs-serialization / load-sensitive), with no "not checked" rows.
- Each load-sensitive verdict cites the specific assertion or mechanism, not a guess.
- The 2 non-`mktemp` core outliers are each read in full and given an explicit verdict.

---

### Phase 5: Opt-In File-Level Parallelism in run-all.sh [NOT STARTED]

**Goal**: Add `--jobs N` to the runner, defaulting to today's sequential behavior, with
deterministic output, a nested-invocation guard, and longest-first scheduling.

**Tasks**:
- [ ] Add `--jobs N` (and `--jobs auto` = `nproc`, capped -- pick and document the cap) with
      default `1`. At `--jobs 1` the code path and output must be exactly today's.
- [ ] Replace the single shared `$SUITE_OUT` temp file with one output file per suite, and keep
      the `trap` cleanup covering all of them.
- [ ] Emit each suite's captured output whole, in **discovery order**, never streamed
      concurrently -- so the `[FAIL] <suite path>` machine-greppable contract, the `[SKIP]`
      loud-skip discipline, and the final summary line all survive parallel execution unchanged.
- [ ] Add the nested-invocation guard: export a marker variable (e.g. `RUN_ALL_NESTED=1`) and
      force `--jobs 1` when it is already set, so `verify-deploy.sh` gate 8 -> `run-all.sh` ->
      a suite that calls `verify-deploy.sh` cannot multiply job counts.
- [ ] Implement longest-first scheduling from an advisory cost-hint file
      (`agent-system/extensions/core/scripts/tests/suite-cost-hints.txt`, generated from Phase 1's
      `--timings` CSV): sort hinted suites by descending cost, append unhinted suites after them.
      The hint file is advisory only -- a missing, stale, or partial hint file must never skip,
      duplicate, or reorder-away a suite. Assert the scheduled count equals `TOTAL_DISCOVERED`
      before running anything.
- [ ] Record the rejected alternative in the header: a self-maintaining timing cache written on
      every run was rejected because it adds mutable state to the tree with gitignore and
      deploy-hygiene consequences; file size was rejected as a cost proxy because the measurements
      disprove it (261 lines / 391s vs. 3839 lines / 45s).
- [ ] Add the Phase 4 audit's serialization verdicts as a comment block, and serialize any suite
      the audit flagged (run it alone, outside the parallel pool).
- [ ] Update the `-h|--help` `sed -n` range again for the new header lines.
- [ ] Extend or add a test for the runner itself: `--jobs 1` output matches sequential; `--jobs N`
      discovers and runs the same suite set (count assertion); the nested guard forces 1 job.

**Timing**: 2 hours

**Depends on**: 1, 4

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: `run-all.sh`'s direct dependents are `verify-deploy.sh` (gate 8),
`test-deploy-verify-wiring.sh`, `test-double-loading-check.sh`, `test-common-lib.sh`, and
`lint/lint-json-channel-discipline.sh`, per a grep of `agent-system/`. Re-run that grep and read
each hit before changing the runner's output shape -- a dependent that parses its output is the
likely breakage site.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - `--jobs`, per-suite temp files,
  ordered output emission, nested guard, hint-based scheduling, audit comment block, `--help`
  range
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - new advisory cost hints
- `agent-system/extensions/core/scripts/tests/test-run-all-parallel.sh` - new suite for the runner

**Verification**:
- `bash run-all.sh --quiet` (no `--jobs`) output diffs clean against a pre-change capture.
- `bash run-all.sh --jobs 4 --quiet` reports the same `N passed, M failed, S skipped, T total`
  counts as the sequential run.
- `[FAIL] <path>` lines still match `grep '^\[FAIL\] '` under parallel mode.
- `bash lint/lint-json-channel-discipline.sh` still reports the same result as at baseline (it is
  one of the 4 known pre-existing failures -- same failure, not a new one).
- Deleting or truncating `suite-cost-hints.txt` still runs all `TOTAL_DISCOVERED` suites.
- `RUN_ALL_NESTED=1 bash run-all.sh --jobs 8` runs sequentially.

---

### Phase 6: Flakiness Decision Gate -- 3 Repeated Parallel Runs [NOT STARTED]

**Goal**: Decide empirically whether parallelism becomes the default or stays opt-in. This is a
decision gate: its measurement selects the branch Phase 7 documents.

**Tasks**:
- [ ] Run the full suite 3 times at the chosen job count, capturing `--timings` CSV and the
      pass/fail set for each run.
- [ ] Diff each run's pass/fail set against Phase 1's recorded baseline set. Treat the 4
      consistent failures as expected failures and `test-gate-out-repair-reporting.sh` as
      known-intermittent; any OTHER divergence is a flake introduced here.
- [ ] Inspect the load-sensitive set named in Phase 4 specifically across all 3 runs, not just the
      aggregate pass/fail counts.
- [ ] Apply the gate criterion: **3 of 3 runs produce the baseline pass/fail set (modulo the known
      intermittent suite) AND no load-sensitive suite failed in any run.**
- [ ] **If the criterion passes**: flip `run-all.sh`'s default to `--jobs auto` (capped), keep
      `--jobs 1` as the documented escape hatch, and leave `verify-deploy.sh` gate 8's invocation
      to inherit the new default. Re-run the 3-run validation once more after the flip, since the
      default path is now a different code path than the one just validated.
- [ ] **If the criterion fails**: keep the default at `--jobs 1`, record which suite(s) flaked and
      under what job count, and close this phase `[COMPLETED WITH EXCLUSIONS]` with a
      `#### Reasoned Exclusions` table whose Evidence column cites the failing runs. The
      gate-selection work from Phases 2-3 stands on its own either way -- it is the larger of the
      two savings.

**Timing**: 1.5 hours (dominated by repeated suite runs)

**Depends on**: 3, 5

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: the expected-failure set is the 4 consistent failures plus 1
known-intermittent suite from Phase 1. Confirm against Phase 1's own recorded set, not against the
research report, since the tree may have moved between the two.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/run-all.sh` - default job count, only on the
  criterion-passes branch

**Verification**:
- 3 run logs captured, with per-run pass/fail sets recorded verbatim.
- Every divergence from the baseline set is named and classified (known-intermittent vs. new).
- On the flip branch: a further 3 runs at the new default reproduce the baseline set.
- On the no-flip branch: a `#### Reasoned Exclusions` table is present under this phase's heading
  with Item / Reason / Evidence populated from the failing runs.

---

### Phase 7: Coverage-Equality Proof, Documentation, and Redeploy [NOT STARTED]

**Goal**: Demonstrate (not assert) that coverage did not shrink, report both wall times, document
the new flags, and deploy.

**Tasks**:
- [ ] Produce the coverage-equality proof: per suite, diff the pre-change and post-change
      `N passed, M failed` summary lines and the `pass`/`fail` assertion call-site counts recorded
      in Phase 1. Every suite must be unchanged or higher. Any suite that is lower is a blocker,
      not a note.
- [ ] Report the discovered-suite count before and after (expected: baseline + 2 new suites from
      Phases 2 and 5 -- coverage strictly higher).
- [ ] Report the before and after full-suite wall times side by side, with the job count and
      machine used for each. Never report a speedup with only one of the two numbers.
- [ ] Document the new CLI surface in
      `agent-system/extensions/core/context/standards/shell-script-testing.md`: `run-all.sh`'s
      `--jobs` and `--timings`, the cost-hint file's advisory status, `verify-deploy.sh`'s
      `--only-gate` and its intended test-fast-path use, and the standing rule that at least one
      full-battery `verify-deploy.sh` invocation must remain in the suite. Keep it to one section;
      create a new context file only if it would exceed roughly 40 lines.
- [ ] Record the pre-existing-failure and known-flake set in that same section, so the next person
      measuring this suite does not rediscover it.
- [ ] Redeploy so `.claude/**` reflects the source-store changes:
      `bash agent-system/extensions/core/scripts/deploy-headless.sh` (or the repo's standard
      deploy entry point). Confirm the deployed `run-all.sh` and `verify-deploy.sh` carry the new
      flags. Never hand-edit `.claude/**`.
- [ ] Run `bash agent-system/extensions/core/scripts/verify-deploy.sh` (full depth, no
      `--skip-slow`) once as the end-to-end proof that gate 8 and gate 20 both still behave.

**Timing**: 1.5 hours

**Depends on**: 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: 2 new test suites are added (Phases 2 and 5), so the discovered count should
rise from the Phase 1 baseline by exactly 2. Confirm by comparing `TOTAL_DISCOVERED` before and
after; a different delta means a suite was renamed, lost its exec bit, or was accidentally
removed.

**Files to modify**:
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - new section on suite
  runtime, `--jobs`/`--timings`/`--only-gate`, and the baseline failure set

**Verification**:
- Per-suite coverage diff shows zero suites with a lower pass count or fewer assertion call sites.
- `TOTAL_DISCOVERED` increased by exactly 2.
- Both wall times reported with job count and host.
- Full-depth `verify-deploy.sh` (no `--skip-slow`) passes, or fails only on the recorded
  pre-existing failures.
- Deployed `.claude/scripts/tests/run-all.sh` and `.claude/scripts/verify-deploy.sh` contain the
  new flags.

---

## Testing & Validation

- [ ] Full-suite wall time measured BEFORE any change (Phase 1) and AFTER (Phase 7); both reported.
- [ ] Full suite run at least 3 times after the change (Phase 6), with the load-sensitive set
      inspected individually rather than only in aggregate.
- [ ] Pass/fail set identical to the Phase 1 baseline across all 95+ suites, with the 4 consistent
      pre-existing failures and `test-gate-out-repair-reporting.sh`'s known intermittency stated as
      the expected baseline rather than treated as regressions.
- [ ] Test count and assertion count unchanged or higher, demonstrated per suite by diffing
      recorded counts (Phase 7), never asserted.
- [ ] `verify-deploy.sh` with no new flag produces output identical to a pre-change capture.
- [ ] `run-all.sh` with no new flag produces output identical to a pre-change capture.
- [ ] Every `--only-gate N` for N in 1..20 runs clean standalone (the cross-gate-variable net).
- [ ] `bash run-all.sh --help` and `bash verify-deploy.sh --help` both print their complete
      headers (the hardcoded `sed` range regression).
- [ ] Full-depth `verify-deploy.sh` (no `--skip-slow`) run once end-to-end.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/verify-deploy.sh` - `--only-gate N[,M,...]`, `GATES_FILTER`,
  `gate_selected()`, 20 additive gate guards
- `agent-system/extensions/core/scripts/tests/run-all.sh` - `--timings FILE`, `--jobs N`, per-suite
  output capture, nested-invocation guard, longest-first scheduling
- `agent-system/extensions/core/scripts/tests/suite-cost-hints.txt` - new, advisory scheduling hints
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-gate-selection.sh` - new suite
- `agent-system/extensions/core/scripts/tests/test-run-all-parallel.sh` - new suite
- `agent-system/extensions/core/scripts/tests/test-verify-deploy-context-budget.sh` - 3 of 4
  invocations gate-scoped; header rationale updated
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - new section on suite
  runtime, the new flags, and the baseline failure set
- `specs/261_reduce_process_spawn_amplification_in_tests/summaries/01_*-summary.md` - implementation
  summary carrying both wall times, the coverage-equality proof, and the Phase 4 audit

## Rollback/Contingency

Each phase commits independently and the phases are separable by design: Phases 2-3
(gate selection, ~290s / ~45% of the saving) and Phases 5-6 (parallelism) share no file and can be
reverted one without the other. Reverting is a `git revert` of that phase's commits followed by a
redeploy -- no working-tree-destroying operation is needed for the ordinary case.

If a genuine working-tree rollback is required (a phase left the tree half-edited and
uncommittable), take the snapshot first per `context/contracts/recovery.md`'s rollback rung, using
the out-of-scope override it documents if the dirty tree carries modifications outside this task's
`file_scope` -- note that this task's declared `file_scope` is
`agent-system/extensions/core/scripts/tests/` while Phases 2 and 7 legitimately edit
`agent-system/extensions/core/scripts/verify-deploy.sh` and
`agent-system/extensions/core/context/standards/shell-script-testing.md`, so that override is
expected to be needed. Do not emit a bare reverting `git-snapshot.sh` as a routine per-phase
checkpoint; use `--no-revert` for a defensive checkpoint before risky work.

Contingency if Phase 2's cross-gate variable audit finds real dependencies that cannot be safely
hoisted: fall back to the stubbing pattern `test-orchestrate-cycle-plan.sh` already uses (a fast,
call-counting stub script substituted for the heavy real one inside the fixture) for
`test-verify-deploy-context-budget.sh`'s three non-baseline cases. This is strictly worse than a
real gate-selection flag -- it exercises a hand-maintained stub instead of real Gate 20 logic -- so
it is a fallback, not an equal alternative, and taking it must be recorded as such.
