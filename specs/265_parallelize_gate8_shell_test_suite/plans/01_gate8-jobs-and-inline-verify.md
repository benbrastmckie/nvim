# Implementation Plan: Task #265

- **Task**: 265 - Run Gate 8 in parallel inside verify-deploy.sh via run-all.sh --jobs (absorbing the deploy-headless.sh inline-verify redundancy)
- **Status**: [IMPLEMENTING]
- **Effort**: 7 hours
- **Dependencies**: None blocking. Task 266 (deploy-pending/identical-dispatch guard) is COMPLETED and archived; task 261 (run-all.sh `--jobs`) is COMPLETED WITH EXCLUSIONS and archived. Both prerequisites are discharged.
- **Research Inputs**: specs/265_parallelize_gate8_shell_test_suite/reports/01_gate8-parallel-and-inline-verify.md
- **Artifacts**: plans/01_gate8-jobs-and-inline-verify.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Gate 8 of `verify-deploy.sh` runs the ~97-suite shell battery fully sequentially because its call
site passes no `--jobs`, costing ~9m21s of an ~11m03s full run. This plan (Part A) makes Gate 8
request the opt-in parallelism `run-all.sh` already provides, defaulting to `--jobs auto` with a
new `VERIFY_DEPLOY_GATE8_JOBS` escape hatch, and (Part B, absorbed from the abandoned
suppress-inline-verify task) removes `deploy-headless.sh`'s wholly-redundant inline
`verify-deploy.sh --skip-slow` pass on the two call paths that already take their own full-depth
pre/post findings snapshots — via an opt-in `--skip-verify` flag returning a new, distinct exit
code 4 with `RESULT=landed_verify_skipped`. Definition of done: a full `verify-deploy.sh` run
produces an identical `[FAIL]` set to its sequential baseline at materially lower wall time; every
`deploy-headless.sh` caller that does not pass the new flag behaves byte-identically; and
`scripts/tests/` passes with no test weakened, skipped, or deleted.

The edit target throughout is the source store `agent-system/extensions/core/` — never
`.claude/**`, which is a regenerated deploy artifact.

### Research Integration

The research report settles every "ALSO SETTLE" and "CRITICAL DEPENDENCY" item in the task
description, and this plan adopts its findings:

- **The dependency fork is already resolved as option (b).** Task 261's Phase 6 flakiness gate did
  run: three `--jobs 4` full-battery runs (211.9s / 219.3s / 211.9s vs. 507.9s at `--jobs 1`) with
  an identical pass/fail set on every suite except an already-classified load-sensitive set, closed
  COMPLETED WITH EXCLUSIONS without flipping `run-all.sh`'s serial default. The task description's
  oldest paragraphs call that task PARTIAL; its own later PATH REVIEW paragraph supersedes that and
  is correct. **No phase of this plan re-runs a 3-run validation gate from scratch** — the recorded
  sets are cited instead.
- **Carried forward, not rediscovered — `run-all.sh`'s `LOAD_SENSITIVE_BASENAMES`** (verified at
  `scripts/tests/run-all.sh:299-305`): `test-lake-build-guard.sh`,
  `test-state-write-concurrency.sh`, `test-state-write-regen-timing.sh`,
  `test-four-tier-conflict.sh`, `test-run-all-parallel.sh`. These five always run alone and
  serially *before* the parallel pool regardless of `--jobs`, so Gate 8 requesting `--jobs N` does
  not place any of them in contention.
- **New finding this plan acts on**: `test-run-all-parallel.sh`'s case3 ratio assertion fails
  **deterministically**, not flakily, whenever the suite runs nested inside any `run-all.sh` — it
  inherits the exported `RUN_ALL_NESTED=1` (set unconditionally at `run-all.sh:142`) into its own
  "unguarded" baseline measurement at line 142 of the test, so that measurement is also forced
  sequential and `parallel_ms ≈ nested_ms`. Reproduced live in research (`env -u RUN_ALL_NESTED` →
  718ms vs 1908ms, PASS; `RUN_ALL_NESTED=1` → 1902ms vs 1906ms, FAIL). This is a defect in the
  test's environment isolation, not in the ratio design, and Phase 1 fixes it *before* any
  baseline is taken so the Verification #1 comparison is not confounded by a suite whose status
  flips for an unrelated reason.
- **Exactly two files genuinely execute `deploy-headless.sh`** (`scripts/command-gate-out.sh:192`
  and `scripts/orchestrate-cycle-plan.sh:892`); the other ~16 files in the description's inherited
  list only print a remedy string naming it. Both real callers already branch on
  `-eq 1 || -eq 2` (not landed) versus an unconditional `else`, and both derive their real
  clean/red signal from their own independent `deploy_findings_snapshot` pair — so a new exit code
  4 lands in their existing "landed" branch with **zero control-flow edits**, which is the
  structural guarantee the description asked for rather than an assertion.
- **`--only-gate`-narrowed inline verify was weighed and rejected** in favor of outright opt-in
  suppression: on these two paths *every* gate the inline pass checks is re-checked by the
  caller's own full-depth post-redeploy snapshot, so narrowing still pays real cost for zero
  information, and it does not remove the need for a distinct exit code. Phase 8 records this
  comparison durably.

### Prior Plan Reference

No prior plan. This is artifact round 1 for this task.

### Roadmap Alignment

No `specs/ROADMAP.md` exists in this repository and no `roadmap_path` was supplied in the
dispatch context; no roadmap consultation applies.

## Goals & Non-Goals

**Goals**:
- Gate 8 requests parallelism explicitly (`--jobs auto` by default) with a documented
  `VERIFY_DEPLOY_GATE8_JOBS` override for CI and low-memory or heavily-loaded hosts.
- The `[FAIL]` set under the new invocation is identical to the recorded sequential baseline set,
  with both sets reported in full, not as counts.
- Before/after wall times for a full (`no --skip-slow`) `verify-deploy.sh` run, measured on the
  same host.
- `deploy-headless.sh` gains an opt-in `--skip-verify` returning exit 4 /
  `RESULT=landed_verify_skipped`, threaded only by the two genuine callers.
- Every caller not passing `--skip-verify` observes byte-identical behavior and exit codes,
  including exit 3 — demonstrated, not asserted.
- `scripts/tests/` passes, including `test-deploy-verify-wiring.sh`,
  `test-verify-deploy-gate-selection.sh`, `test-run-all-parallel.sh`,
  `test-lint-deploy-caller-wrap.sh`, and `test-orchestrate-cycle-plan.sh`.
- `test-run-all-parallel.sh`'s deterministic nested-inheritance defect is fixed so Gate 8 can go
  fully green instead of perpetually reporting a mischaracterized failure.

**Non-Goals**:
- Flipping `run-all.sh`'s own `JOBS=1` default. Task 261 declined that deliberately; this plan
  changes one caller's request, not the library default.
- Re-running or re-deriving task 261's Phase 6 flakiness gate.
- Weakening, skipping, or deleting any test, or regressing `test-run-all-parallel.sh`'s
  ratio-based timing assertions back to absolute thresholds. A ratio assertion is not a weakened
  assertion.
- Any snapshot-sharing design that presumes Gate 8 is invariant across a `deploy-headless.sh`
  call. That premise is false (41 of 73 suites under `scripts/tests/` prefer the DEPLOYED copy of
  their subject) and is exactly why the sibling redundant-verify-passes design was rejected; see
  `context/patterns/batch-orchestration-guardrails.md`.
- Raising `run-all.sh`'s `JOBS_CAP` (4), altering its nested-invocation guard, or touching its
  longest-first scheduler.
- Changing `--skip-slow`'s behavior (`verify-deploy.sh:551`) or the deploy-consumer /
  missing-`run-all.sh` branches (`:553-556`).
- Editing anything under `.claude/**`.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| A suite fails under `--jobs` that passed sequentially (real contention, not the known set) | H | L | Phase 2 records the full sequential `[FAIL]` set as a named baseline *before* line 558 is touched; Phase 4 is an explicit decision gate — a set difference stops the plan and reports rather than proceeding to Part B. The five load-sensitive suites already run serially before the pool. |
| Fixing `test-run-all-parallel.sh` in the same task makes the before/after comparison unreadable (a suite flips FAIL→PASS for an unrelated reason) | M | H if unsequenced | Phase 1 lands and separately verifies the fix first; both the baseline (Phase 2) and the post-change measurement (Phase 4) are taken with the fix already in place. |
| Measurements taken under ambient agent load are not comparable | M | H on this host | Both measurement phases record `nproc`, load average, and concurrent-session count alongside the wall time, and are taken back-to-back on the same host. A measurement taken under materially different load is discarded and retaken, not reconciled by arithmetic. |
| `auto` resolves differently per host, changing Gate 8's timing characteristics | L | M | Inherent to `auto` and already documented by `run-all.sh`; `VERIFY_DEPLOY_GATE8_JOBS` is the escape hatch (force `1` on a `nproc=1` or memory-pressured container). |
| An invalid `VERIFY_DEPLOY_GATE8_JOBS` value silently degrades instead of failing loudly | M | L | The value is passed through verbatim to `run-all.sh`, whose existing validation exits 2; Gate 8's failure message names the override variable when the status is 2, so the cause is legible. No silent fallback to `1` or `auto`. |
| A future third automated `deploy-headless.sh` caller mishandles exit 4 | M | L | `test-lint-deploy-caller-wrap.sh` re-derives the genuine-caller set from file contents every run (never a hardcoded list), so a new caller is structurally caught; Phase 5 additionally adds an explicit contract test for the exit-4 / `RESULT=landed_verify_skipped` pair. |
| Extending `deploy-headless.sh`'s header shifts lines past its `--help` range (`sed -n '2,101p' "$0"`), truncating help output — which `test-deploy-verify-wiring.sh` case 6 asserts on | M | H if overlooked | Phase 5 updates the `sed` range in the same edit as the header additions and re-runs that suite; the same hazard exists for `run-all.sh`'s `sed -n '2,84p'` if its header is touched (it is not, in this plan). |
| Exit 4 cannot be exercised end-to-end by a fixture test (no non-dry-run deploy is safe inside the suite) | M | H | Phase 5's automated test asserts the contract structurally and documentarily; Phase 7 records one live, non-dry-run invocation pair (with and without the flag) capturing both exit codes and both `RESULT=` lines. The limitation is stated in the summary rather than papered over. |
| Sibling tasks are dispatched into this same working tree this cycle | M | M | Re-read each file immediately before editing; stage only this task's own hunks with an explicit file list (never a directory or glob pathspec); never run `git-snapshot.sh` in its reverting default mode; treat a failure outside this plan's file list as possibly a sibling's in-flight edit and report rather than "fix" it. |

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |
| 5 | 5 | 4 |
| 6 | 6 | 5 |
| 7 | 7 | 6 |
| 8 | 8 | 4, 6, 7 |

Phases within the same wave can execute in parallel. Every wave here holds exactly one phase, and
that is deliberate rather than an oversight: Phases 2, 4, and 7 are whole-tree measurements whose
numbers are invalid if any source file changes mid-run, so no editing phase may overlap them, and
each editing phase's own verification re-runs the battery this plan is measuring.

---

### Phase 1: Fix `test-run-all-parallel.sh`'s nested-inheritance defect [COMPLETED]

**Goal**: Make case3's "unguarded" baseline measurement genuinely unguarded, so the suite passes
both standalone and when discovered nested by an outer `run-all.sh`, and correct the
documentation that mis-attributes this failure to ambient load.

**Tasks**:
- [x] Re-read `scripts/tests/test-run-all-parallel.sh` in full (sibling tasks share this tree). *(completed)*
- [x] Clear the inherited `RUN_ALL_NESTED` for every fixture invocation that is *not* the
      deliberately-nested comparison: the parallel measurement at line 142, and the case1/case2/
      `auto`/hint-file invocations (lines 84, 85, 96, 171, 198) which must also exercise the
      unnested code path. Prefer one documented `unset RUN_ALL_NESTED; export -n RUN_ALL_NESTED`
      (or equivalent) in the suite's setup block over an `env -u` prefix repeated at six call
      sites, and keep the explicit `RUN_ALL_NESTED=1` prefix on the case4 comparison at line 147.
      *(completed: single `unset RUN_ALL_NESTED` added to the setup block right after the
      WORKDIR/trap lines, with a comment; the case4 `RUN_ALL_NESTED=1` prefix at line 147 untouched)*
- [x] Add a short comment recording *why* the isolation is needed (the parent `run-all.sh` exports
      `RUN_ALL_NESTED=1` at `run-all.sh:142` into every suite it launches), so the next reader does
      not delete it as redundant. *(completed)*
- [x] Leave the ratio-based assertion (`parallel_ms <= 75% of nested_ms`) and the case4 assertion
      exactly as they are. Do not reintroduce absolute thresholds. *(completed: untouched)*
- [x] Update `context/standards/shell-script-testing.md`'s "Known pre-existing failures and
      flakes" section: remove `test-run-all-parallel.sh` from the load-sensitive failure list and
      add a note distinguishing "genuinely load-sensitive" from "was a nested-environment
      inheritance bug, now fixed", so a future similar failure is not re-attributed to load
      without checking. Leave the basename in `run-all.sh`'s `LOAD_SENSITIVE_BASENAMES` array —
      serial scheduling remains legitimate for its own measurement stability.
      *(completed: altered — this doc no longer carries a prose failure list at all (migrated to
      `scripts/tests/known-failures.txt` as sole source of truth, confirmed by re-reading the file);
      added the genuinely-load-sensitive-vs-nested-inheritance-bug distinction to the `intermittent`
      category definition in shell-script-testing.md instead, and updated the
      `test-run-all-parallel.sh` row's reason text in known-failures.txt itself to record the fix
      and the distinction, since that file is the actual list this task's premise referred to)*

**Timing**: 0.75 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: The failure mechanism is asserted to be inherited `RUN_ALL_NESTED=1`, and
the invocation sites needing isolation are asserted to be lines 84, 85, 96, 142, 171, 198 with 147
deliberately excluded. Confirm at implementation time by re-reading the file (line numbers may
have drifted) and by the two-command reproduction below, which must flip from FAIL to PASS.

**Files to modify**:
- `agent-system/extensions/core/scripts/tests/test-run-all-parallel.sh` - isolate `RUN_ALL_NESTED` for the unguarded measurements; add the explanatory comment
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - correct the known-failures attribution

**Verification**:
- `bash -n scripts/tests/test-run-all-parallel.sh` clean.
- `env -u RUN_ALL_NESTED bash scripts/tests/test-run-all-parallel.sh` → all cases PASS.
- `RUN_ALL_NESTED=1 bash scripts/tests/test-run-all-parallel.sh` → all cases PASS (this is the
  case that fails today; it simulates being discovered by an outer `run-all.sh`).
- Record both outputs verbatim — this pair is the evidence that the defect was deterministic.

---

### Phase 2: Record the sequential Gate 8 baseline [COMPLETED]

**Goal**: Capture the authoritative pre-change baseline — the complete `[FAIL]` set and the wall
time of a full `verify-deploy.sh` run — with Phase 1's fix already landed, so Verification #1's
comparison is apples-to-apples.

**Tasks**:
- [x] Confirm the tree is otherwise quiet: record `nproc`, `uptime` load averages, and the number
      of concurrent agent sessions. If ambient load is heavy, wait or note it prominently; do not
      silently normalize the number afterwards. *(completed: nproc=24, load avg 1.54/1.95/1.79 at
      start; NOT quiet — a sibling task (265's dispatch context named task 165 as an active
      serialization peer) was observed actively dispatched and writing shared state/lock files
      during the run, plus an uncommitted in-flight edit to
      agent-system/extensions/typst/scripts/typst-element-lint.sh from another task. Noted
      prominently rather than normalized — see phase-2-progress.json's confound_analysis)*
- [x] Time a full run with no `--skip-slow`: `time bash agent-system/extensions/core/scripts/verify-deploy.sh --findings` (capture stdout+stderr to a scratch log under the session scratchpad, not the repo). *(completed: real 14m1.512s, logged to session scratchpad, not the repo)*
- [x] Extract and record the complete `[FAIL]` line set from Gate 8's own output plus every
      `FINDING gate8 ...` line — the full sets, verbatim, not counts. *(completed: recorded verbatim in phase-2-progress.json's baseline_record; 4 failing suites: test-four-tier-conflict.sh, test-gate-out-repair-reporting.sh, test-lint-json-channel-discipline.sh, test-typst-element-lint.sh — 3 of 4 already pre-documented in known-failures.txt or explained by a concurrent sibling's uncommitted edit; test-four-tier-conflict.sh is new and attributed to ambient load-sensitive timing (LOAD_SENSITIVE_BASENAMES), carried forward to Phase 4)*
- [x] Record Gate 8's own share of the wall time if the output makes it separable; otherwise
      record the total and say so. *(completed: not separable from --quiet --findings output; total 14m1.512s recorded, materially above the task description's prior ~11m03s expectation, attributed to the same ambient concurrent-session load)*
- [x] Do not edit any file in this phase. *(completed: no source file edited; only progress/plan-checklist bookkeeping)*

**Timing**: 0.5 hours (including a ~11 minute run)

**Depends on**: 1

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: The description's measured facts (~9m21s of an ~11m03s run) are treated as a
prior expectation, not a fact to reuse — this phase re-measures on the current host and current
tree. A material divergence from ~11m is itself a finding to report, not something to reconcile
silently.

**Files to modify**:
- none planned (measurement only; results are recorded in the execution summary and carried into Phase 4's comparison)

**Verification**:
- A baseline record exists containing: host facts (`nproc`, load), total wall time, the complete
  Gate 8 `[FAIL]` set, and the complete `FINDING gate8` set.
- `test-run-all-parallel.sh` appears as PASS in this baseline (confirming Phase 1 landed before
  the baseline was taken).

---

### Phase 3: Wire Gate 8 to request `--jobs`, with a `VERIFY_DEPLOY_GATE8_JOBS` override [COMPLETED]

**Goal**: Gate 8 asks `run-all.sh` for parallelism, defaulting to `auto`, overridable by one
documented environment variable, with `--skip-slow`, the deploy-consumer branch, the
missing-`run-all.sh` branch, and the nested-invocation guard all provably untouched.

**Tasks**:
- [x] Re-read `scripts/verify-deploy.sh` around the gate 8 block (currently `:544-574`) and around
      the existing env-default block (`ORCHESTRATOR_BUDGET_GATE_MODE` at `:190`) immediately before
      editing. *(completed: re-read; drift from task description's cited line numbers noted --
      gate 8 block was at :551-578 and the env-default block at :197 by implementation time)*
- [x] Add `GATE8_JOBS="${VERIFY_DEPLOY_GATE8_JOBS:-auto}"` beside the existing
      `ORCHESTRATOR_BUDGET_GATE_MODE` default, following that variable's `${VAR:-default}`
      convention. Do not invent a central env-var registry; there is none. *(completed)*
- [x] Append `--jobs "$GATE8_JOBS"` to the existing `run-all.sh --quiet` invocation inside the
      `else` branch only. Leave the `--skip-slow` branch, the deploy-consumer branch, and the
      `run-all.sh`-not-found branch byte-identical. *(completed: `git diff` confirms only the
      `else` branch's invocation line and its preceding comment block changed)*
- [x] Decide and record the precedence in a comment at the call site: an explicit
      `VERIFY_DEPLOY_GATE8_JOBS` wins over the `auto` default; the value is passed through
      verbatim and validated by `run-all.sh` alone (single source of validation truth); there is no
      silent fallback. *(completed)*
- [x] Extend Gate 8's `fail` remedy text so that when `run_all_status` is 2 (`run-all.sh`'s
      usage/validation exit) the message names `VERIFY_DEPLOY_GATE8_JOBS` as the likely cause, and
      so the re-run remedy string it already prints stays copy-pasteable. *(completed: verified
      live with `VERIFY_DEPLOY_GATE8_JOBS=banana bash verify-deploy.sh --only-gate 8`, which
      printed "...exit 2 may indicate an invalid VERIFY_DEPLOY_GATE8_JOBS value: 'banana'")*
- [x] Document the new variable in `verify-deploy.sh`'s header (a short block beside the existing
      minimal-init hatch note): name, default `auto`, meaning of `1`, and when to use it (CI,
      `nproc=1`, memory-pressured, or heavily-loaded interactive hosts). *(completed)*
- [x] Record the rejected alternatives in that header block or the call-site comment, so they are
      not re-proposed: a bare hardcoded `4` (not host-adaptive; identical to `auto` only on hosts
      with `nproc >= 4`); a conservative fixed `2` (leaves measured headroom unused and still needs
      the same override); reusing a generic `JOBS` env name (too broad, collides with unrelated
      tooling); and gating parallelism on TTY-ness (implicit, untestable, surprising).
      *(completed: recorded in the call-site comment block)*

**Timing**: 0.75 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserted — one call site to change (`scripts/verify-deploy.sh:558`) and one
new env default. Confirm by `grep -n 'tests/run-all.sh' scripts/verify-deploy.sh` returning exactly
the gate 8 invocation plus the remedy/mention strings, and by re-reading the gate block before
editing (line numbers will drift once the header block is added).

**Files to modify**:
- `agent-system/extensions/core/scripts/verify-deploy.sh` - `GATE8_JOBS` default beside the other env default; `--jobs "$GATE8_JOBS"` on the gate 8 invocation; status-2 remedy text; header documentation of the override and the rejected alternatives

**Verification**:
- `bash -n scripts/verify-deploy.sh` clean.
- `bash scripts/verify-deploy.sh --skip-slow --findings --quiet` still prints the Gate 8 SKIP line
  and emits **no** `FINDING gate8` line (the `--skip-slow` contract, Verification #3).
- `git diff` confirms the deploy-consumer and missing-`run-all.sh` branches are unchanged
  (Verification #4).
- `VERIFY_DEPLOY_GATE8_JOBS=1 ...` reaches `run-all.sh` as `--jobs 1`, and an invalid value (e.g.
  `banana`) produces `run-all.sh`'s own exit-2 validation error surfaced through Gate 8's remedy
  text naming the variable — verify by inspecting the printed `run-all.sh` invocation or with a
  short throwaway trace, not by weakening validation.
- Nested-guard confirmation: `run-all.sh`'s guard (`run-all.sh:139-142`) is reached identically
  whether or not `--jobs` was passed, so a `verify-deploy.sh` invoked from inside a suite still
  gets `JOBS=1`. Demonstrate with `RUN_ALL_NESTED=1 bash scripts/tests/run-all.sh --quiet --jobs 4`
  on the synthetic fixture path (or the real battery if time allows) showing forced-sequential
  behavior, and confirm no edit was made to `run-all.sh`.
- `bash scripts/tests/test-deploy-verify-wiring.sh` and
  `bash scripts/tests/test-verify-deploy-gate-selection.sh` both pass.

---

### Phase 4: Measure the parallel Gate 8 and compare against the baseline (decision gate) [COMPLETED]

**Goal**: Establish Verification #1 and #2 — an identical `[FAIL]` set and a reported before/after
wall time on the same host — and stop the plan if the sets differ.

**Tasks**:
- [x] Record host facts again (`nproc`, load, concurrent sessions) and confirm they are comparable
      to Phase 2's; retake rather than reconcile if they are not. *(completed: nproc=24, load avg
      1.51/2.05/2.08 (auto run) and 1.47/2.92/2.61 (jobs=1 rerun) vs. Phase 2's 1.54/1.95/1.79 --
      comparable magnitude, same sibling-dispatch confound (task 165 still active, same
      typst-element-lint.sh uncommitted edit still present))*
- [x] Time a full run: `time bash agent-system/extensions/core/scripts/verify-deploy.sh --findings`
      (no `--skip-slow`), capturing output to the scratchpad. *(completed: real 6m47.357s under
      the new `--jobs auto` default)*
- [x] Diff the complete `[FAIL]` set and the complete `FINDING gate8` set against Phase 2's
      baseline. Report **both sets in full**, as the task's Verification #1 requires — never only a
      count or a "same as before". *(completed, recorded verbatim in phase-4-progress.json:
      auto-run FAIL set = {test-gate-out-repair-reporting.sh, test-lint-json-channel-discipline.sh,
      test-typst-element-lint.sh} -- a PROPER SUBSET of the baseline's 4-suite set, missing only
      test-four-tier-conflict.sh. See decision-gate analysis below.)*
- [x] Also run once with `VERIFY_DEPLOY_GATE8_JOBS=1` and confirm that run reproduces the Phase 2
      baseline set exactly (this isolates "the change is correct" from "this host is quiet").
      *(completed: real 13m51.562s, FAIL set = exactly the Phase 2 baseline's 4 suites, including
      test-four-tier-conflict.sh -- an exact reproduction)*
- [x] **Decision gate**: if the sets are identical, proceed to Phase 5. If any suite differs,
      STOP: do not proceed to Part B, do not adjust the default to hide the difference, and do not
      weaken or skip the differing suite. Record the difference, name the suite, and report it as a
      blocker for a user decision (a genuinely load-sensitive suite outside the known five would be
      new information that changes the default choice). *(completed -- PROCEED, with full
      disclosure: the one differing suite, test-four-tier-conflict.sh, is NOT outside the known
      five -- it IS one of run-all.sh's five LOAD_SENSITIVE_BASENAMES, which always run serially
      before the parallel pool regardless of --jobs, so this task's change cannot have placed it
      in new resource contention. The Risks & Mitigations table's own framing of this exact risk
      ("real contention, NOT the known set") and the VERIFY_DEPLOY_GATE8_JOBS=1 rerun exactly
      reproducing the baseline (including this suite failing again, under forced-sequential
      execution identical to the baseline's own conditions) together show this is ambient-load
      timing variance intrinsic to an already-documented load-sensitive suite, not a defect this
      --jobs change introduced. This is disclosed prominently in the implementation summary rather
      than silently normalized, per this task's own standing instruction not to hide a difference
      -- but is not escalated as a blocking user decision, since it falls inside, not outside, the
      known five the gate's own parenthetical names as the actual trigger condition.)*
- [x] Record the measured reduction (baseline seconds → parallel seconds, and the percentage)
      alongside task 261's recorded 507.9s → ~212s battery numbers for context. *(completed:
      14m1.512s (841.512s) -> 6m47.357s (407.357s), a 51.6% reduction for the full verify-deploy.sh
      run; task 261's own battery-only numbers were 507.9s -> ~212s (58%) for run-all.sh in
      isolation, so this run's slightly lower percentage is consistent with the fixed ~2-3 min of
      non-gate8 gates and ambient ammortized load diluting the parallel speedup fraction.)*
- [x] Do not edit any file in this phase. *(completed: no source file edited; only progress/plan-checklist bookkeeping)*

**Timing**: 0.5 hours (including two runs)

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserted — that the `[FAIL]` sets will match, on the strength of task 261's
recorded parity across 97 suites and of Gate 8's two automated call sites both firing at
documented zero-dispatch-concurrency points. This is a hypothesis this phase exists to test, not a
premise; the decision gate above is what happens if it is false.

**Files to modify**:
- none planned (measurement and comparison only)

**Verification**:
- Both complete `[FAIL]` sets are recorded and shown to be identical (or the difference is
  escalated per the decision gate).
- Before/after wall times are recorded for the same host with comparable load.
- The `VERIFY_DEPLOY_GATE8_JOBS=1` run reproduces the baseline set.

---

### Phase 5: Add `--skip-verify` / exit 4 / `RESULT=landed_verify_skipped` to `deploy-headless.sh` [COMPLETED]

**Goal**: An opt-in suppression flag exists and is fully documented and tested, while **no caller
passes it yet** — so this phase alone demonstrates that every existing caller's behavior, including
exit 3, is byte-identical.

**Tasks**:
- [x] Re-read `scripts/deploy-headless.sh` (header exit-code block `:91-101`, `RESULT=` vocabulary
      `:103-108`, arg loop `:173-201`, inline verify block `:394-417`, final exit `:451-455`)
      immediately before editing. *(completed: re-read; drift from cited line numbers noted --
      the exit-code block was at :98-108, arg loop :178-206, inline verify block :393-423, final
      exit :456-460 by implementation time)*
- [x] Add `--skip-verify` to the arg loop (a plain boolean `SKIP_VERIFY=true`, beside
      `--consumer-report`) and to the usage string in the unknown-flag error message. *(completed)*
- [x] Guard the inline verify block: when `SKIP_VERIFY` is true, skip the
      `verify-deploy.sh --skip-slow` invocation entirely, print one explicit line saying
      verification was suppressed by request (not that it passed), and set the outcome to the new
      skipped state. Keep the existing announcement text byte-identical on the unsuppressed path.
      *(completed: verified live -- `--skip-verify` prints the suppression line and
      `RESULT=landed_verify_skipped` exit 4; no-flag path unchanged, prints "Verifying deploy..."
      and `RESULT=landed_verify_clean` exit 0)*
- [x] Route the final exit: `_dh_result_and_exit landed_verify_skipped 4` for the suppressed path,
      leaving `landed_verify_clean 0` and `landed_verify_red 3` reachable exactly as today. Choose
      4 because 0/1/2/3 are taken and because neither 0 (which would misrepresent "verified clean"
      to a human reading a log, or to a future caller that does distinguish) nor 3 (which means
      "verify ran and found something", false here) is honest about a suppressed verify.
      *(completed: `if verify_rc==0 / elif verify_rc==4 / else (3)` -- a distinct elif arm, not a
      reuse of the 0 or 3 arms)*
- [x] Ensure the post-deploy consumer-report block still runs on the suppressed path exactly as it
      does on the 0 and 3 paths (the tree WAS modified in all three cases) and that it still cannot
      influence `RESULT=` or the exit code. *(completed: the consumer-report block is gated only
      on `$CONSUMER_REPORT`/checker-existence, never on `$verify_rc`'s value, so it runs
      identically regardless of which of the three verify_rc values precedes it)*
- [x] Extend the header: the `# Exit codes:` block gains 4; the `RESULT=` vocabulary block gains
      `landed_verify_skipped`; the `# Usage:` lines gain `--skip-verify` with a one-line statement
      that it is for callers that take their own independent full-depth verification snapshot, and
      an explicit "a suppressed verify is not a passed verify" note. *(completed)*
- [x] **Update the `--help` range** (`sed -n '2,101p' "$0"`) to cover the lengthened header —
      `test-deploy-verify-wiring.sh` case 6 asserts on help *content*, so a stale range silently
      truncates the new flag out of the help output. *(completed: range bumped to `2,149p`
      (header grew from ending at line 101 to ending at line 149); verified live that
      `--help` output contains --skip-verify, landed_verify_skipped, and exit code 4)*
- [x] Add cases to `scripts/tests/test-deploy-verify-wiring.sh`, following that suite's existing
      structure and its deliberate "no non-dry-run deploy" rule: (a) `--help` output contains
      `--skip-verify`; (b) `--help` output documents exit 4 and `landed_verify_skipped`;
      (c) `--skip-verify --dry-run` still exits 0, prints `DRY RUN`, and prints no verification
      announcement (the dry-run carve-out is unchanged); (d) a structural assertion that
      `landed_verify_skipped 4` is reachable only under the suppression guard and that
      `landed_verify_clean 0` is not reachable when suppression is active — this is the Verification
      #4 "distinguishable in a test" requirement, satisfied structurally because a non-dry-run
      deploy inside the suite is not safe. State that limitation in the test's own comment rather
      than implying end-to-end coverage; Phase 7 supplies the live pair. *(completed: Cases
      10-12 added; the live, non-dry-run, with/without-flag exit-code pair was ALSO captured
      directly during this phase's own verification -- real `bash deploy-headless.sh --skip-verify`
      -> exit 4 / RESULT=landed_verify_skipped, and real `bash deploy-headless.sh` (no flag) ->
      exit 0 / RESULT=landed_verify_clean -- recorded in phase-5-progress.json; Phase 7 records
      this pair again on the actual redeploy-checkpoint caller path, as the plan specifies)*
- [x] Do not add the flag to any caller in this phase. *(completed: git diff --name-only for this
      phase's commit touches only deploy-headless.sh and test-deploy-verify-wiring.sh; neither
      command-gate-out.sh nor orchestrate-cycle-plan.sh was touched)*

**Timing**: 1.5 hours

**Depends on**: 4

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserted — exit codes 0, 1, 2, 3 are taken and 4 is free; the `RESULT=`
vocabulary is exactly three tokens today. Confirm by re-reading the header's exit-code block and
`grep -rn 'RESULT=' scripts/ context/ docs/` before choosing 4, since another code or token may
have been added since research.

**Files to modify**:
- `agent-system/extensions/core/scripts/deploy-headless.sh` - `--skip-verify` arg, suppression guard on the inline verify, exit 4 / `RESULT=landed_verify_skipped`, header exit-code + RESULT + usage documentation, `--help` sed range bump
- `agent-system/extensions/core/scripts/tests/test-deploy-verify-wiring.sh` - new cases for the flag, the help documentation, the dry-run interaction, and the exit-4 contract

**Verification**:
- `bash -n scripts/deploy-headless.sh` clean; `bash scripts/deploy-headless.sh --help` prints the
  full header including `--skip-verify`, exit 4, and `landed_verify_skipped` (proving the sed range
  was updated).
- `bash scripts/tests/test-deploy-verify-wiring.sh` passes, including its pre-existing exit-3 and
  dry-run cases.
- `bash scripts/tests/test-lint-deploy-caller-wrap.sh` passes (the structural wrap of
  `deploy-headless.sh` itself is unchanged; only its argument handling grew).
- `git diff` shows no caller file touched — this is the byte-identical-for-every-other-caller
  demonstration (Part B Verification #1, first half).

---

### Phase 6: Thread `--skip-verify` from the two genuine callers [COMPLETED]

**Goal**: The two real callers opt in, with zero control-flow change, and the claim "no other
caller changes" is shown structurally rather than asserted.

**Tasks**:
- [x] Re-derive the genuine-caller set rather than trusting the plan:
      `grep -rn 'deploy-headless\.sh' agent-system/extensions/*/scripts` and classify each hit as a
      genuine invocation (command position) or a mention (comment, remedy string, assignment).
      `test-lint-deploy-caller-wrap.sh`'s own classifier is the reference for the distinction.
      Expect exactly two genuine callers plus `deploy-headless.sh` itself. *(completed:
      `test-lint-deploy-caller-wrap.sh` itself re-derives and confirms exactly 2 genuine callers --
      command-gate-out.sh and orchestrate-cycle-plan.sh -- out of ~200 scanned .sh files, 17
      mention-only; used as the authoritative classifier rather than a manual grep re-triage)*
- [x] Re-read `scripts/command-gate-out.sh` around `:185-200` and
      `scripts/orchestrate-cycle-plan.sh` around `:885-900` immediately before editing (a sibling
      task shares `orchestrate-cycle-plan.sh`). *(completed: re-read; drift from cited line
      numbers noted -- actual call sites were at command-gate-out.sh:~196-211 and
      orchestrate-cycle-plan.sh:~917-933 by implementation time. IMPORTANT PREMISE CORRECTION
      found on re-read, recorded in full in phase-6-progress.json: the dispatch's framing
      ("checkpoint takes its pre/post/confirm snapshots at FULL depth, never --skip-slow") is
      STALE. A prior, already-completed task (task 283, "stop redeploy-checkpoint gate 8
      amplification") already switched BOTH callers' own independent snapshot pairs to
      `--skip-slow`, matching deploy-headless.sh's own inline verify depth exactly -- confirmed by
      `git log -S "this task's Phase 5 exists to remove" -- orchestrate-cycle-plan.sh` and by
      context/patterns/batch-orchestration-guardrails.md's "Superseded by a LATER task's
      wall-clock fix" paragraph, which explicitly names "Suppressing deploy-headless.sh's own
      internal --skip-slow verify" as an alternative task 283 itself considered and "decided OUT,
      not implemented... Recorded as a genuine, scoped follow-up for a future task, not folded
      into this one." This task's Phase 6 IS that scoped follow-up, now with the caller-contract
      audit task 283 explicitly flagged as missing (Verification #1 below). The underlying
      mechanism (suppress the now-genuinely-redundant inline pass; both callers' own snapshots
      already check the identical --skip-slow gate set deploy-headless.sh's inline verify checks)
      remains valid and is NOT invalidated by this correction -- only the MAGNITUDE of the saving
      changes: eliminating one ~50-70s --skip-slow pass per checkpoint fire, not a ~9min gate8
      pass (gate8 was already removed from this path entirely by task 283, independent of this
      task). Phase 7's measurement and Phase 8's documentation account for this correction; see
      their own task annotations.)*
- [x] Append `--skip-verify` to each of the two invocation lines only. Add a one-line comment at
      each site stating why suppression is safe *there* specifically: this caller takes its own
      independent full-depth `deploy_findings_snapshot` pair around the call and derives the real
      clean/red signal from that comparison, never from `deploy-headless.sh`'s exit code.
      *(completed, WORDING CORRECTED per the premise correction above: the comment at each site
      says "independent pre/post (and, for orchestrate-cycle-plan.sh, confirm) verify-deploy.sh
      --skip-slow findings snapshot pair", not "full-depth" -- an inaccurate claim would have
      been load-bearing prose a future reader could trust)*
- [x] Demonstrate — do not assert — that exit 4 needs no branch edit: show that each caller's
      not-landed predicate is `-eq 1 || -eq 2` followed by an unconditional `else`, so 4 partitions
      into the existing landed branch alongside 0 and 3. Record the two predicates verbatim in the
      summary. *(completed: both predicates verbatim --
      command-gate-out.sh:213 `if [ "$gate_out_deploy_rc" -eq 1 ] || [ "$gate_out_deploy_rc" -eq 2 ]`;
      orchestrate-cycle-plan.sh:935 `if [ "$deploy_exit" -eq 1 ] || [ "$deploy_exit" -eq 2 ]` --
      both followed by an unconditional `else`, confirmed unedited by `git diff`)*
- [x] Confirm the `deploy_pending` / ledger bookkeeping in `orchestrate-cycle-plan.sh` keys off the
      landed/not-landed distinction (and its own snapshot comparison), not off exit 0 specifically;
      if any site does compare against 0, widen it explicitly and say so rather than leaving it.
      *(completed: found exactly one site comparing `$deploy_exit -eq 0` specifically --
      orchestrate-cycle-plan.sh's Defect A "depth_disagreement" diagnostic field (decision-
      independent; branch (b) already defers unconditionally regardless of its value). NOT
      widened to `-eq 0 || -eq 4`, because 4 means "suppressed" and 0 means "ran and passed" --
      conflating them would report a false "depth agreement" for a verify that never ran.
      Documented explicitly in place instead (why it's now effectively dead in real operation,
      why it's intentionally retained for the test fixture and for the --skip-verify rollback
      path) -- "say so rather than leaving it" satisfied by explanation rather than by widening,
      which is the honest answer here. test-orchestrate-cycle-plan.sh's checkpoint (k) -- the one
      test exercising this exact field -- still passes unchanged, because its fixture stub
      ignores all arguments including --skip-verify and returns its configured exit code
      directly.)*

**Timing**: 1 hour

**Depends on**: 5

**Verification Tier**: interface

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserted — exactly two files genuinely execute `deploy-headless.sh`
(`command-gate-out.sh:192`, `orchestrate-cycle-plan.sh:892`), and roughly sixteen others only
mention it. Confirm by the re-derivation in the first task above; a third genuine caller found at
implementation time changes this phase's file list and must be reported, not quietly absorbed.

**Files to modify**:
- `agent-system/extensions/core/scripts/command-gate-out.sh` - append `--skip-verify` to the deploy invocation; add the why-safe-here comment
- `agent-system/extensions/core/scripts/orchestrate-cycle-plan.sh` - append `--skip-verify` to the redeploy-checkpoint invocation; add the why-safe-here comment

**Verification**:
- `bash -n` clean on both files.
- `bash scripts/tests/test-lint-deploy-caller-wrap.sh` passes — the lint polices structural
  wrapping, not the argument list, so an already-wrapped call with a new flag must remain clean. If
  it does trip, extend the lint deliberately with reasoning; never relax it.
- `bash scripts/tests/test-orchestrate-cycle-plan.sh` and
  `bash scripts/tests/test-deploy-verify-wiring.sh` pass.
- The mention-only files are confirmed unchanged (`git diff --name-only` lists exactly the two
  caller files).

---

### Phase 7: Measure the redeploy checkpoint and prove a red tree is still caught [COMPLETED]

**Goal**: Establish Part B's Verification #2 and #3 — before/after checkpoint wall time on a
checkpoint that actually fires, and evidence that suppression creates no path where a red tree
reads as green.

**Tasks**:
- [x] Record the checkpoint's total wall time on a fire that genuinely happens (a cycle whose
      `cycle_modified_files` touches `agent-system/**` — this task's own commits qualify), both
      before and after Phase 6's change. If a natural fire is not available in the window, trigger
      the checkpoint path deliberately and say which it was; do not report a synthetic number as an
      observed one. *(completed WITH A SCOPE NOTE: a full live `/orchestrate` cycle fire was not
      triggered from inside this implement dispatch -- the orchestrator engine, not a dispatched
      sub-agent, owns cycle boundaries, and self-triggering one would be well outside this phase's
      scope. Instead, the checkpoint's total wall-time delta was measured at the ONE component
      that changed: deploy-headless.sh's own call, isolated and timed directly, both with and
      without `--skip-verify`. This fully accounts for the checkpoint's total delta because
      nothing else in the call chain (ledger consult, pre_findings, post_findings,
      confirm_findings) was touched by Phase 6 -- confirmed by `git diff` showing only the one
      invocation line changed at each caller. Measured: without `--skip-verify`,
      `time bash deploy-headless.sh` = real 2m17.574s (includes the resync copy AND its own
      inline `verify-deploy.sh --skip-slow` pass); with `--skip-verify` = real 0m8.425s (resync
      copy only, no inline verify at all). Delta: ~2m9s (129s) removed per checkpoint fire -- this
      is MATERIALLY LARGER than this plan's own earlier estimate ("a ~50-70s pass", carried from
      `verify-deploy.sh`'s header, written under quieter ambient load) and larger than the
      correction's "modest" framing anticipated; both numbers are reported as measured on this
      host under its current heavy concurrent-session load (same confound recorded in Phase 2/4),
      not reconciled to the header's static estimate.)*
- [x] Capture the live exit-code pair the fixture test cannot: one non-dry-run
      `deploy-headless.sh` invocation **without** the flag (expect 0 or 3 with
      `RESULT=landed_verify_clean` / `landed_verify_red`) and one **with** it (expect 4 with
      `RESULT=landed_verify_skipped`). Record both exit codes and both `RESULT=` lines verbatim.
      *(completed: without flag -> exit=0, `[deploy-headless] RESULT=landed_verify_clean`; with
      `--skip-verify` -> exit=4, `[deploy-headless] RESULT=landed_verify_skipped`, and the
      explicit suppression line "Verification SUPPRESSED by --skip-verify (caller takes its own
      independent verification snapshot; this is NOT the same as a passed verify)." Both captured
      directly against this repo, same pair already captured once in Phase 5's own verification;
      recaptured here per this phase's own instruction.)*
- [x] Red-tree detectability: with `--skip-verify` active, confirm the caller's own full-depth
      post-redeploy `deploy_findings_snapshot` still surfaces a genuine new finding — e.g. by
      introducing a deliberate, immediately-reverted source-store defect that the fast gates would
      have caught, and confirming the caller's new-findings branch fires. Revert the deliberate
      defect the moment the observation is recorded; never leave it staged or committed.
      *(completed, WORDING NOTE: "full-depth" in this task's own wording is the same stale
      premise corrected in Phase 6 -- read as "skip-slow-depth". Demonstrated directly with
      `deploy_findings_snapshot`/`deploy_baseline_new_findings` from lib/deploy-baseline-lib.sh
      (the exact functions both callers use), independent of deploy-headless.sh entirely: PRE
      (clean tree) = 1 finding (gate16, pre-existing). Injected a deliberate, throwaway
      task-reference-lint violation (an HTML comment naming "task 999999") appended to
      context/patterns/batch-orchestration-guardrails.md. POST = 4 findings (gate16 + gate3
      deploy-drift + gate4 THE INJECTED VIOLATION + gate5 deploy-drift). `deploy_baseline_new_findings`
      correctly reports gate3/gate4/gate5 as new vs. the gate16-only baseline, with gate4 being
      the substantive catch (gate3/gate5 are incidental source-vs-deployed drift from editing
      without an intervening redeploy, not defects). Reverted via Edit (not `git checkout --`,
      which the destructive-git guard correctly blocked on the dirty tree) and confirmed
      `git diff --quiet` clean immediately after the observation; `bash deploy-headless.sh`
      re-run afterward to resync. This proves the catching mechanism is entirely independent of
      deploy-headless.sh's own exit code -- it is, and remains, the caller's OWN pre/post
      comparison -- so suppressing the inline pass cannot create a path where a red tree reads as
      green.)*
- [x] Confirm the checkpoint's own branch contract is unaffected: exit 4 routes into the landed
      branch and the not-landed branch (1/2) is still reachable and still defers. *(completed: via
      Phase 6's own verification, re-cited rather than re-derived -- both predicates
      (`-eq 1 || -eq 2`, unconditional `else`) confirmed unedited by `git diff`, and
      test-orchestrate-cycle-plan.sh's full 344-case run (including Arm E's not-landed-branch
      coverage and checkpoint (k)'s landed-branch-with-findings coverage) passes unchanged.)*

**Timing**: 1 hour

**Depends on**: 6

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserted — that the inline pass costs ~1m35s and is wholly redundant on both
real call paths. Confirm by the measured before/after checkpoint numbers; a saving materially
below ~1.5 min per checkpoint fire means the premise needs re-examination and should be reported
rather than rounded up.

**Files to modify**:
- none planned (measurement and a deliberately-reverted probe only; the probe must leave the tree exactly as it found it)

**Verification**:
- Before/after checkpoint wall times recorded, with the fire condition named.
- The live with-flag / without-flag exit-code and `RESULT=` pair recorded.
- A genuinely red tree is shown to still be caught by the caller's own snapshot comparison with
  suppression active.
- `git status --porcelain` shows no residue from the deliberate probe.

---

### Phase 8: Documentation and durable rationale record [COMPLETED]

**Goal**: Record the decisions, the measured numbers, and the rejected alternatives where a future
reader will find them, so neither the snapshot-sharing design nor a narrowed-inline-verify design
is re-proposed from scratch.

**Tasks**:
- [x] `context/patterns/regeneration-is-manual-only.md`, `### deploy-headless.sh's Inline
      Verification and Exit Code 3` subsection: document the `--skip-verify` path, exit 4, and
      `RESULT=landed_verify_skipped`, including the "a suppressed verify is not a passed verify"
      statement and the two-caller opt-in scope. Extend the `RESULT=` vocabulary list there with
      the new token. *(completed: new "`--skip-verify`: an opt-in suppression for callers with
      their own baseline" paragraph added; `RESULT=landed_verify_skipped` bullet added to the
      vocabulary list; exit-code-contract paragraph cross-references the new paragraph)*
- [x] `context/standards/shell-script-testing.md`, "Suite runtime" section: note that
      `verify-deploy.sh`'s Gate 8 is now one of the callers that opts into `--jobs`, name
      `VERIFY_DEPLOY_GATE8_JOBS` and its default, and record the measured before/after Gate 8 wall
      times from Phase 4 beside task 261's recorded battery numbers. *(completed WITH A WORDING
      CORRECTION: "task 261's recorded battery numbers" cannot be cited by task number in a
      deliverable file outside specs/** (no-task-references-in-deliverables.md) -- the hook
      blocked the first attempt. Added the 211.9s/219.3s/211.9s vs 507.9s (58%) battery numbers
      directly into the existing `--jobs` bullet instead of citing them by task number, then
      referenced that bullet descriptively ("the run-all.sh --jobs flakiness-gate measurement
      recorded a few bullets above") from the new Gate 8 bullet -- same comparative content, a
      durable in-file anchor instead of an ephemeral task number)*
- [x] `context/patterns/batch-orchestration-guardrails.md`: add the rationale this task exists to
      preserve — making each Gate 8 run faster needs no invariance premise, which is precisely why
      it sidesteps the reason the snapshot-sharing design was rejected (41 of 73 suites prefer the
      deployed copy of their subject) — plus the explicit `--only-gate`-narrowed-inline-verify vs.
      outright-suppression comparison and why suppression won on this path. *(completed: two new
      paragraphs added after the single-capture rejection -- "Why a separate, later task made
      verify-deploy.sh's Gate 8 itself faster instead of extending this rejection" and
      "`--only-gate`-narrowed inline verify vs. outright `--skip-verify` suppression"; ALSO closed
      out the pre-existing "decided OUT, not implemented... a genuine, scoped follow-up for a
      future task" paragraph -- this task IS that follow-up, now landed, with the caller-contract
      audit it deferred actually done via test-lint-deploy-caller-wrap.sh's own mechanical
      re-derivation)*
- [x] `docs/architecture/orchestrate-state-machine.md`: one or two lines noting that the
      Inter-Cycle Redeploy Checkpoint passes `--skip-verify` and that exit 4 is a landed outcome
      (the file documents no exit codes today, so this is an addition, not a correction).
      *(completed: added to the `deferred_deploy_checkpoint`/`defer_ledger` field-contract
      paragraphs; ALSO corrected the pre-existing `depth_disagreement` description's stale
      "full-depth comparison" wording and noted it is now effectively dead in real operation on
      this path, consistent with the code comment added in Phase 6)*
- [x] Follow the documentation policy and encoding/emoji standards; use durable anchors
      (filenames, section headings) in any deliverable text outside `specs/**`, never task numbers.
      *(completed: `grep -n "task [0-9]"` across all four edited files returns nothing after the
      wording correction above; `bash check-extension-docs.sh` -- the deployed copy, via a
      redeploy -- reports no failures, and a full `verify-deploy.sh` run (no `--skip-slow`) is
      planned as this phase's own closing verification)*

**Timing**: 0.75 hours

**Depends on**: 4, 6, 7

**Verification Tier**: prose

**Commit Mode**: per-substep

**Scope Hypothesis**: Asserted — four documentation files need edits, and
`docs/architecture/orchestrate-state-machine.md` currently documents no `deploy-headless.sh` exit
codes. Confirm with `grep -n 'exit 3\|RESULT=' docs/architecture/orchestrate-state-machine.md`
before editing; a pre-existing exit-code narrative there would make this a correction rather than
an addition.

**Files to modify**:
- `agent-system/extensions/core/context/patterns/regeneration-is-manual-only.md` - `--skip-verify`, exit 4, `landed_verify_skipped`
- `agent-system/extensions/core/context/standards/shell-script-testing.md` - Gate 8 as a `--jobs` opt-in caller; the override; measured numbers
- `agent-system/extensions/core/context/patterns/batch-orchestration-guardrails.md` - why-this-mechanism rationale; the `--only-gate` vs. suppression comparison
- `agent-system/extensions/core/docs/architecture/orchestrate-state-machine.md` - checkpoint passes `--skip-verify`; exit 4 is a landed outcome

**Verification**:
- Every changed hunk lies inside prose (diff read-through); no code, no link left dangling.
- `bash scripts/check-extension-docs.sh` (and any documentation lint the repo runs as part of
  `verify-deploy.sh`) passes.
- A final full `bash scripts/tests/run-all.sh --quiet` passes with the same `[FAIL]` set recorded
  in Phase 4 — no test weakened, skipped, or deleted anywhere in this plan.

---

## Testing & Validation

- [ ] `bash scripts/tests/run-all.sh --quiet` — full battery; `[FAIL]` set identical to Phase 2's
      recorded baseline, with `test-run-all-parallel.sh` now passing on both the standalone and
      nested paths.
- [ ] `bash scripts/tests/test-run-all-parallel.sh` passes standalone AND under
      `RUN_ALL_NESTED=1`; its ratio-based assertions are unchanged.
- [ ] `bash scripts/tests/test-deploy-verify-wiring.sh` passes, including its pre-existing exit-3,
      dry-run, `--skip-slow`-no-`FINDING gate8`, and `--help`-content cases plus the new
      `--skip-verify` cases.
- [ ] `bash scripts/tests/test-verify-deploy-gate-selection.sh` passes.
- [ ] `bash scripts/tests/test-lint-deploy-caller-wrap.sh` passes without being relaxed.
- [ ] `bash scripts/tests/test-orchestrate-cycle-plan.sh` passes.
- [ ] `bash scripts/verify-deploy.sh --skip-slow --findings --quiet` still SKIPs Gate 8 and emits
      no `FINDING gate8` line.
- [ ] `VERIFY_DEPLOY_GATE8_JOBS=1 bash scripts/verify-deploy.sh --findings` reproduces the
      sequential baseline `[FAIL]` set.
- [ ] A full `bash scripts/verify-deploy.sh --findings` run (no `--skip-slow`) with both wall times
      and both complete `[FAIL]` sets reported.
- [ ] Live `deploy-headless.sh` exit-code pair recorded: without `--skip-verify` (0 or 3) and with
      it (4 / `RESULT=landed_verify_skipped`).

## Artifacts & Outputs

- `specs/265_parallelize_gate8_shell_test_suite/plans/01_gate8-jobs-and-inline-verify.md` (this plan)
- `specs/265_parallelize_gate8_shell_test_suite/summaries/01_gate8-jobs-and-inline-verify-summary.md` — must carry, verbatim: both complete `[FAIL]` sets, both full-run wall times with host facts, the before/after checkpoint wall times, the live exit-code / `RESULT=` pair, and the two callers' branch predicates
- Source-store edits: `scripts/verify-deploy.sh`, `scripts/deploy-headless.sh`,
  `scripts/command-gate-out.sh`, `scripts/orchestrate-cycle-plan.sh`,
  `scripts/tests/test-run-all-parallel.sh`, `scripts/tests/test-deploy-verify-wiring.sh`
- Documentation edits: `context/patterns/regeneration-is-manual-only.md`,
  `context/standards/shell-script-testing.md`,
  `context/patterns/batch-orchestration-guardrails.md`,
  `docs/architecture/orchestrate-state-machine.md`
- Measurement logs under the session scratchpad (not committed to the repository)

## Rollback/Contingency

Every phase is independently revertible and every edit is a small, additive change to one file, so
the normal contingency is a targeted `git revert` of that phase's own commit — the
commit-per-green-substep discipline is what makes this possible, and it is why no phase batches
unrelated files.

- **Phase 3 (Gate 8 `--jobs`)**: the cheapest rollback is operational, not a code revert — set
  `VERIFY_DEPLOY_GATE8_JOBS=1` to restore fully sequential Gate 8 behavior with no edit at all.
  That escape hatch existing *is* the contingency. A code revert of the one-line `--jobs` addition
  is the permanent form.
- **Phase 6 (caller opt-in)**: remove `--skip-verify` from the two invocation lines; because the
  flag is opt-in, this alone restores the previous behavior exactly, with Phase 5's flag left
  harmlessly unused.
- **Phase 5 (flag + exit 4)**: revert that phase's commit. No caller depends on exit 4 once
  Phase 6 is reverted, so the order is Phase 6 then Phase 5.
- **Phase 1 (test fix)**: revert that phase's commit; the suite returns to failing deterministically
  when nested, which is the pre-existing state, not a new defect.
- **If a phase leaves uncommitted work that must be discarded**, take a durable checkpoint first
  rather than reverting blind — see `context/contracts/recovery.md`'s rollback rung for the exact
  snapshot-then-rollback invocation shape, including its out-of-scope override flag for the
  deliberate whole-tree case. A bare precautionary checkpoint before risky work uses
  `git-snapshot.sh --no-revert` (durable, non-reverting), never the default reverting mode.
- **If Phase 4's decision gate fails** (a `[FAIL]` set difference outside the known five
  load-sensitive suites), nothing is rolled back: Part A stops at Phase 3 with
  `VERIFY_DEPLOY_GATE8_JOBS=1` documented as the safe default-in-practice, the difference is
  reported with the named suite, and the choice of default becomes a user decision.
- **Shared-tree caution**: `orchestrate-cycle-plan.sh` and `test-deploy-verify-wiring.sh` are also
  in sibling tasks' declared scopes this cycle. Never revert by pathspec-discarding those files;
  revert this task's own commit so a sibling's landed work is preserved.
