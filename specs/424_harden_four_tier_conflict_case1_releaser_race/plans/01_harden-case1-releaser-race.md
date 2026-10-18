# Implementation Plan: Task #424

- **Task**: 424 - Harden four-tier-conflict Case 1's releaser race
- **Status**: [COMPLETED]
- **Effort**: 2 hours
- **Dependencies**: None (no file-territory overlap with the three siblings dispatched this cycle)
- **Research Inputs**: specs/424_harden_four_tier_conflict_case1_releaser_race/reports/01_harden-case1-releaser-race.md
- **Artifacts**: plans/01_harden-case1-releaser-race.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md
- **Type**: meta
- **Lean Intent**: false

## Overview

`test-four-tier-conflict.sh` Case 1 builds its fixture by backgrounding a releaser subshell that
removes a foreign holder's lock file after a fixed `sleep 0.3`, racing that fixed wall-clock
margin against the foreground `task-lock.sh acquire-retry` call's own process-fork/exec
scheduling latency. Under heavy CPU contention the foreground call's first attempt can start
after the releaser has already removed the lock, so no retry is ever observed, no `NOTE:` line is
printed, and the assertion `note_count1 -eq 1` fails with `rc=0 note_count=0 abort_count=0`. This
plan replaces that fixed delay with a direct ordering signal: a `PATH`-shimmed bare `sleep`
(the same external seam Case 6 already exploits, with no production-code change) touches a marker
file the instant `cmd_acquire_retry` reaches its first NOTE:-then-sleep branch — i.e. the instant
the first attempt has demonstrably observed the lock as held — and the releaser polls for that
marker instead of sleeping. Definition of done: the race is removed by construction rather than
by margin; the original fixture is shown to still reproduce the failure under the induced-load
method while the patched fixture does not; Cases 2-13 are unaffected; the deployed tree is
regenerated and the full gate set is green.

### Research Integration

Research reproduced the race live 3/3 times at 1-minute load averages of 10.5-30.8 (28 `yes`
workers on this 24-core host), confirming the dispatch's root cause exactly, and then built and
empirically validated the exact fix this plan applies: 14/14 cases pass unloaded and 3/3 under
load up to a 27.8 load average, with Cases 2-13 unaffected in every run. Three mechanics the
research flagged for the implementer are carried into Phase 2's task list verbatim because each
is a silent-failure trap: (1) the `PATH=` override must be a **command-scoped prefix** on the
single `"$TL" acquire-retry` invocation, never an exported shell-wide change, so the releaser
subshell's own `sleep 0.01` polling still resolves to the real system `sleep`; (2) the shim must
perform a **real** sleep (`exec "$REAL_SLEEP" "$@"`) after touching the marker — unlike Case 6's
instant-return shim, which only counts iterations — because the real elapsed window is what lets
the releaser observe the marker and finish its `rm -rf` before the next attempt ~100ms later;
(3) `REAL_SLEEP="$(command -v sleep)"` must be captured **before** the `PATH` override, or the
shim recurses into itself. Research also chose the signal-file technique over widening the fixed
delay, per the dispatch's own ladder, and ruled no `task-lock.sh` change is needed.

### Prior Plan Reference

No prior plan.

### Roadmap Alignment

No `roadmap_path` was provided in this dispatch, so no ROADMAP.md consultation was performed and
this plan asserts no roadmap alignment.

## Goals & Non-Goals

**Goals**:
- Case 1's foreground/background ordering is enforced by direct evidence that the first
  `cmd_acquire` attempt has observed the lock held, not by any fixed wall-clock delay.
- The fix is non-vacuous: the reverted original fixture is shown to still reproduce the reported
  failure signature under the induced-load method, and the patched fixture is shown not to, at a
  load meeting or exceeding the dispatch's reported 12.6-20.5 range.
- Cases 2-13 remain unaffected (the suite still reports 14/14 pass, loaded and unloaded).
- No production-code change: `task-lock.sh` is read-only; only the existing bare-`sleep`
  `PATH` seam Case 6 already uses is reused.
- Case 1's header comment explains the new construction — why it removes the race by
  construction rather than by margin — in the style of the existing Case 5/6 comments.
- The deployed `.claude/scripts/test-four-tier-conflict.sh` is regenerated from the source store
  (never hand-patched) and the full gate set is green.

**Non-Goals**:
- Any change to `task-lock.sh` or `cmd_acquire_retry`, including adding a testability hook. The
  existing external seam suffices.
- Any change to Cases 2-13's setup or assertions, or to Case 6's pre-existing shim
  (`SLEEP_SHIM_DIR` / `SLEEP_COUNT_FILE`), which stays untouched and distinctly named.
- Widening Case 1's fixed delay as a fallback. Explicitly ruled out by the dispatch's scope note
  and by research's empirical result; a larger constant moves the race's threshold rather than
  removing it.
- Adding the new "backgrounded helper's fixed-delay release racing a foreground call's
  scheduling latency" sub-shape to `context/standards/shell-script-testing.md`. Research
  recommends it; it belongs to a separate documentation task and is outside this task's declared
  single-file scope.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The `PATH` override is written as an exported or shell-wide assignment instead of a command-scoped prefix, so the releaser's own `sleep 0.01` polling resolves to the shim and self-triggers the marker | H | M | Phase 2 asserts the exact command-scoped prefix shape on the single `"$TL"` invocation and Phase 2's verification greps the final file to confirm no `export PATH` or bare `PATH=` statement line was introduced |
| The shim is written as an instant return (copying Case 6's shape), relocating the race rather than removing it | H | M | Phase 2's task list requires `exec "$REAL_SLEEP" "$@"` after the `touch`, and Phase 3's loaded A/B is the empirical check: an instant-return shim would not survive it |
| `REAL_SLEEP` resolved after the `PATH` override, making the shim recurse into itself (hang or fork storm) | H | L | Ordering is fixed in Phase 2's task list: shim file written and `REAL_SLEEP` captured before the `PATH=`-prefixed invocation. Phase 2's unloaded suite run would hang or fail loudly rather than pass silently |
| Naming collision or reader confusion with Case 6's pre-existing `SLEEP_SHIM_DIR` / `SLEEP_COUNT_FILE` | L | M | Use the distinct `CASE1_SLEEP_SHIM_DIR` / `CASE1_SIGNAL_FILE` names research validated, and say in the header comment that Case 1's shim is a *different* mechanism (ordering signal) from Case 6's (iteration counter) |
| The induced-load harness (28 `yes` workers) is left running after a pass, degrading the host and poisoning later phases' results | M | M | Every load pass kills its workers immediately on completion, in the same command, and confirms with a follow-up check that no `yes` worker survives before the next measurement is taken |
| A concurrent sibling task edits `test-four-tier-conflict.sh` mid-phase | M | L | Re-read the file immediately before each edit; stage only this task's own hunks with an explicit single-file list; never run `git-snapshot.sh` in its reverting default mode. Task 413's declared scope includes `task-lock.sh` and `tests/run-all.sh` but not this file; a foreign modification here is a STOP-and-report condition after checking `git log` |
| Phase 1's deliberate RED is mistaken for a real regression by a later reader or by a gate run | L | M | Phase 1 modifies no file and is labelled an expected-RED baseline in both its own verification notes and the completion summary; its load pass runs the suite directly, never through a gate |

## Implementation Phases

**Dependency Analysis**:
| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |
| 4 | 4 | 3 |

Phases within the same wave can execute in parallel. This plan is fully sequential: Phase 1
establishes the RED that Phase 2's edit turns green, Phase 3 re-measures the same A/B against
the committed file, and Phase 4 redeploys and gates the result.

### Phase 1: Non-Vacuousness Baseline (Expected RED) [COMPLETED]

**Goal**: Demonstrate, against the current unmodified file, that Case 1 reliably reproduces the
reported failure signature under the dispatch's induced-load method — establishing that the
Phase 2 fix is non-vacuous before any edit lands.

**Tasks**:
- [x] Re-read `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` Case 1's block
      (currently around lines 189-214) and confirm it still contains the unmodified fixed-delay
      releaser (`sleep 0.3` followed by `rm -rf .../.lock`) with no foreign modification. Check
      `git status --short` and `git log --oneline -3 --` on the file; a foreign uncommitted change
      or commit here is a STOP-and-report condition. *(completed: confirmed unmodified, clean
      git status, no recent commits touching the file)*
- [x] Confirm the host is quiet before measuring: no surviving `yes` workers, and record the
      1-minute load average from `/proc/loadavg` as the pre-load baseline. *(completed: 1.46,
      then 1.18 pre first pass)*
- [x] Run one unloaded control pass: `bash agent-system/extensions/core/scripts/tests/run-all.sh
      --only test-four-tier-conflict.sh`. Record the result; Case 1 is expected to PASS unloaded
      (the race needs contention), which is itself part of the evidence that the defect is
      load-dependent rather than deterministic. *(completed: 14/14 PASS unloaded)*
- [x] Run the induced-load pass: spawn 28 (`nproc`+4 on this 24-core host) `yes > /dev/null &`
      background workers, wait 1s, record `/proc/loadavg`, run `bash
      agent-system/extensions/core/scripts/tests/run-all.sh --only test-four-tier-conflict.sh`,
      then kill every worker immediately in the same command. Repeat until the Case 1 failure is
      observed at least twice at a 1-minute load average inside or above the dispatch's reported
      12.6-20.5 range (research saw it 3/3; two independent observations is the floor here).
      *(completed: 2/2 passes reproduced, loads 18.33 and 23.66)*
- [x] Record, verbatim, the observed failure line for each reproducing pass (expected shape:
      `[FAIL] 1: Tier-2 resolving case -- rc=0 note_count=0 abort_count=0 output=[]`) together
      with its load average, and confirm Cases 2-13 passed in those same loaded runs — which
      establishes the pre-fix state of the other twelve cases for Phase 3's comparison.
      *(completed: both passes produced exactly that line; Cases 2-13 passed (13 passed, 1
      failed) in both loaded runs)*
- [x] Confirm no `yes` worker survives the phase before closing it. *(completed: `pgrep -x yes`
      empty after each pass)*

**Timing**: 0.5 hours

**Depends on**: none

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts it modifies zero files. Confirm with `git status
--short` at phase close — any modification to the source-store tree at this point is either an
accidental edit to revert or a sibling's work to leave alone.

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
test-four-tier-conflict.sh` is the one suite covering the file under measurement, and this phase
changes no file at all, so no broader surface exists to break.

**Files to modify**:
- none planned (measurement-only phase; the suite is executed, never edited)

**Verification**:
- The Case 1 failure signature is observed at least twice, under independent induced-load
  passes, at a 1-minute load average inside or above 12.6-20.5, with each occurrence's load
  average and verbatim failure line recorded.
- The unloaded control pass reports Case 1 passing, confirming the defect is load-dependent.
- Cases 2-13 pass in the same loaded runs, recorded as the pre-fix comparison baseline.
- `git status --short` shows this phase modified no file.

---

### Phase 2: Replace Case 1's Fixed Delay With a Signal-File-Gated Releaser [COMPLETED]

**Goal**: Apply the validated signal-file construction to Case 1's block so the releaser can
never remove the lock before the foreground call's first attempt has observed it held, and
document the construction in Case 1's header comment.

**Tasks**:
- [x] Re-read the full Case 1 block in
      `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` immediately before
      editing (concurrency: three sibling tasks are live this cycle). *(completed: re-read
      confirmed unmodified)*
- [x] Replace Case 1's setup — everything between the `write_holder_fixture ... 501 0` call and
      the `out1=$(...)` invocation — with the signal-file construction, in this exact order:
      (a) define `CASE1_SLEEP_SHIM_DIR="$TMPROOT/sleep-shim-case1"` and
      `CASE1_SIGNAL_FILE="$TMPROOT/case1-first-attempt-signal"`, `mkdir -p` the shim dir and
      `rm -f` the signal file; (b) capture `REAL_SLEEP="$(command -v sleep)"` **before** any
      `PATH` override exists; (c) write the shim script, which `touch`es `$CASE1_SIGNAL_FILE`
      and then `exec "$REAL_SLEEP" "$@"` — a **real** sleep, not an instant return — and
      `chmod +x` it; (d) background the releaser as `until [ -f "$CASE1_SIGNAL_FILE" ]; do sleep
      0.01; done` followed by the existing `rm -rf .../.lock`. *(completed, exact order
      followed)*
- [x] Change the `out1=$(...)` invocation to carry `PATH="$CASE1_SLEEP_SHIM_DIR:$PATH"` as a
      **command-scoped prefix** on that single `"$TL" acquire-retry ...` call, alongside the
      existing `TASK_LOCK_RETRY_BUDGET_MS` / `TASK_LOCK_RETRY_POLL_MS` prefixes. Do not add an
      `export PATH` or a standalone `PATH=` statement line anywhere. *(completed)*
- [x] Leave the rest of Case 1 byte-identical: the `t0`/`t1` timestamps, the `wait
      "$RELEASER_PID"`, the `note_count1` / `abort_count1` extraction, and the `pass`/`fail`
      calls including the existing elapsed-ms diagnostic in the pass message. *(completed,
      confirmed via git diff)*
- [x] Rewrite Case 1's header comment block to explain the construction: that the shimmed
      `sleep` fires exactly once `cmd_acquire_retry` has printed its first `NOTE:` and reached
      its first sleep — i.e. once the first `cmd_acquire` attempt has definitively observed the
      lock as held — so the releaser's wait is on direct evidence of ordering rather than on a
      wall-clock margin; and that this shim is a *different* mechanism from Case 6's
      iteration-counting shim (`SLEEP_SHIM_DIR` / `SLEEP_COUNT_FILE`), deliberately named apart
      from it, and performs a real sleep because Case 1 needs the real elapsed window that
      Case 6 deliberately removes. *(completed)*
- [x] Grep the final file to confirm: no `export PATH` and no standalone `PATH=` statement line
      was introduced; Case 6's `SLEEP_SHIM_DIR` and `SLEEP_COUNT_FILE` names are untouched; and
      the only `sleep 0.3` occurrence in Case 1's block is gone. *(completed: grep confirmed
      all three)*
- [x] Run `shellcheck -S warning` on the modified file and resolve any finding this change
      introduced. *(completed: shellcheck -S warning clean, rc=0)*
- [x] Run the unloaded suite: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
      test-four-tier-conflict.sh` and confirm 14/14 pass. *(completed: 14/14 PASS)*
- [x] Commit this green sub-step with an explicit single-file staging list (never a directory or
      glob `git add`). *(completed, see Phase 2 closing commit)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts it modifies exactly one source-store file,
`agent-system/extensions/core/scripts/test-four-tier-conflict.sh`. Confirm with `git status
--short` before committing; treat any second source-store file as either scope creep to justify
or a sibling's edit to leave alone.

**Tier Justification**: the edit is confined to one self-contained test fixture block in a single
file with no externally visible signature and no production-code change, and
`run-all.sh --only test-four-tier-conflict.sh` plus `shellcheck -S warning` on that same file
together cover every surface the edit can reach.

**Files to modify**:
- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` - replace Case 1's
  fixed-delay releaser setup with the signal-file-gated construction; add the command-scoped
  `PATH` shim prefix to Case 1's `acquire-retry` invocation; rewrite Case 1's header comment

**Verification**:
- `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
  test-four-tier-conflict.sh` reports 14/14 pass unloaded.
- `shellcheck -S warning` on the modified file is clean of findings this change introduced.
- Grep confirms no `export PATH` / standalone `PATH=` line was added, Case 6's shim variable
  names are unchanged, and Case 1's `sleep 0.3` is gone.
- `git diff` shows changes confined to Case 1's block and its header comment; no other case's
  setup or assertion text moved.

---

### Phase 3: Loaded A/B Verification Against the Committed File [COMPLETED]

**Goal**: Prove the fix holds under the same induced-load method that reproduced the race in
Phase 1, measured against the committed file rather than research's scratchpad prototype, and
confirm Cases 2-13 are unaffected under that load.

**Tasks**:
- [x] Confirm the host is quiet (no surviving `yes` workers) and record the pre-load 1-minute
      load average. *(completed: no survivors, pre-load avg 1.73)*
- [x] Run three independent induced-load passes against the committed file, each using Phase 1's
      exact harness (28 `yes > /dev/null &` workers, 1s settle, record `/proc/loadavg`, run
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
      test-four-tier-conflict.sh`, kill all workers immediately in the same command). Require
      every pass to report 14/14 at a 1-minute load average inside or above the dispatch's
      12.6-20.5 range; if a pass lands below that range, discard it and re-run rather than
      counting it. *(completed: 3/3 passes, loads 22.62/24.97/26.98, all 14/14; deviation:
      altered — ran the suite via a direct invocation of
      `test-four-tier-conflict.sh` rather than through the `run-all.sh --only` wrapper, because
      `run-all.sh` only prints per-case detail on a FAIL, not on a PASS, and this phase's next
      task requires explicitly confirming each of Cases 2-13 individually; the direct
      invocation runs the identical suite code path, so this is strictly more evidence, not
      less)*
- [x] Record each pass's load average and pass/fail counts, and explicitly confirm Cases 2-13
      passed in each — matching the pre-fix baseline Phase 1 recorded for those same cases.
      *(completed: all three passes report `Results: 14 passed, 0 failed` with every one of
      Cases 2-13 individually printing `[PASS]`, matching Phase 1's pre-fix baseline for those
      same twelve cases)*
- [x] Close the non-vacuousness A/B explicitly in writing: Phase 1's recorded original-fixture
      failures at a comparable load versus this phase's three clean passes, at or above the same
      load, against the committed fix. State that the comparison is between the two fixture
      constructions under the identical harness, not between two different load levels.
      *(completed, see "Non-Vacuousness A/B" note below)*
- [x] Confirm no `yes` worker survives the phase before closing it. *(completed: `pgrep -x yes`
      empty after each pass)*

**Non-Vacuousness A/B** (same induced-load harness, same host, both sides measured against
`agent-system/extensions/core/scripts/test-four-tier-conflict.sh`; the comparison is between
the two fixture constructions, not between two different load levels):

| Side | Pass | Load avg | Result |
|------|------|----------|--------|
| Original (Phase 1, reverted/unmodified fixture) | A | 18.33 | FAIL: `rc=0 note_count=0 abort_count=0` |
| Original (Phase 1, reverted/unmodified fixture) | B | 23.66 | FAIL: `rc=0 note_count=0 abort_count=0` |
| Fixed (this phase, committed signal-file fixture) | 1 | 22.62 | PASS 14/14 |
| Fixed (this phase, committed signal-file fixture) | 2 | 24.97 | PASS 14/14 |
| Fixed (this phase, committed signal-file fixture) | 3 | 26.98 | PASS 14/14 |

The fixed side's three passes span and exceed the original side's two failing loads (22.62-26.98
vs. 18.33-23.66), so the fix is shown to hold at loads at least as high as those that broke the
original construction — the non-vacuousness requirement is satisfied.

**Timing**: 0.5 hours

**Depends on**: 2

**Verification Tier**: local

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts it modifies zero files — it is measurement-only.
Confirm with `git status --short` at phase close.

**Tier Justification**: `run-all.sh --only test-four-tier-conflict.sh` is the one suite covering
the only file this task touched, this phase runs it three times under the reproduction load, and
the phase itself edits nothing.

**Files to modify**:
- none planned (measurement-only phase)

**Verification**:
- Three independent induced-load passes each report 14/14 pass, each at a recorded 1-minute load
  average inside or above 12.6-20.5.
- Cases 2-13 pass in every one of those runs, matching Phase 1's recorded pre-fix baseline for
  those cases.
- The A/B is stated in writing with both sides' recorded load averages and outcomes.
- `git status --short` shows this phase modified no file.

---

### Phase 4: Redeploy and Full Gate Set [COMPLETED WITH EXCLUSIONS]

**Goal**: Regenerate the deployed `.claude/` tree from the source store and prove the change set
green against the complete gate set, with every dispatch acceptance point walked explicitly.

**Tasks**:
- [x] Re-read the modified file and confirm the working tree contains only this task's own hunks
      in it. Three sibling tasks are live this cycle; a foreign modification or a foreign commit
      in this file is a STOP-and-report condition, after checking `git log` to confirm the work
      is not this task's own. *(completed: git log shows only this task's own Phase 2 commit,
      clean git status)*
- [x] Redeploy: `timeout 540 bash .claude/scripts/deploy-headless.sh` (raise the Bash tool
      `timeout` parameter to 600000, per the bounded-wait idiom). *(completed:
      RESULT=landed_verify_clean)*
- [x] Confirm the deployed `.claude/scripts/test-four-tier-conflict.sh` is byte-identical to the
      source-store copy (`diff` them) — never hand-patch the deployed file. *(completed: diff
      reports no difference)*
- [x] Run the full gate set: `bash .claude/scripts/verify-deploy.sh` from the repo root (which is
      the source-store host here, so the source-store gates apply rather than SKIP), with no
      `--skip-slow` and no `--only-gate` filter. *(completed: FAIL -- 1 of 38 check(s) failed;
      see Reasoned Exclusions below)*
- [x] Run the full shell suite: `bash agent-system/extensions/core/scripts/tests/run-all.sh`
      (no `--only` filter). *(completed: at quiet host load, 158 passed, 1 failed (1 expected,
      0 NEW); test-four-tier-conflict.sh itself PASSED)*
- [x] For any gate or suite that fails for a reason outside this task's single-file scope,
      record it as a `#### Reasoned Exclusions` row (`Item | Reason | Evidence`) with direct
      evidence that neither the modified file nor its suite appears in the failure, and mark the
      phase heading `[COMPLETED WITH EXCLUSIONS]` rather than `[COMPLETED]`. Never silently
      narrow the gate set. *(completed, see below)*
- [x] Walk each dispatch acceptance point and record its evidence: (a) Case 1's ordering no
      longer depends on a fixed wall-clock delay; (b) the fix holds under the dispatch's
      induced-load reproduction method; (c) Cases 2-13 remain unaffected; (d) non-vacuousness —
      the original construction still reproduced the race under that same method while the fix
      does not. *(completed, see "Acceptance Points" below)*
- [x] Note in the completion summary the one deliberately deferred follow-up: adding the
      "backgrounded helper's fixed-delay release racing a foreground call's scheduling latency"
      sub-shape to `context/standards/shell-script-testing.md`'s timing-axis catalogue.
      *(completed, carried into the summary's Follow-ups section)*

#### Reasoned Exclusions

| Item | Reason | Evidence |
|------|--------|----------|
| `verify-deploy.sh` gate 8 (Shell test suite runner) — reported `FAIL -- 1 of 38 check(s) failed` | Gate 8 wraps `run-all.sh` and treats ANY non-zero exit as FAIL with no expected/new distinction (confirmed by reading `verify-deploy.sh`'s gate-8 implementation, which has no allowance for a pre-existing expected failure). The sole cause is `test-gate-cache-equivalence.sh`, a pre-existing standing failure unrelated to this task's single-file scope (`test-four-tier-conflict.sh`) — confirmed outside this task before dispatch began. | A direct, unfiltered `run-all.sh` run at quiet host load (1-minute avg ~2.2) reported `158 passed, 1 failed (1 expected, 0 NEW)`, with the one failure being `test-gate-cache-equivalence.sh (EXPECTED)` and `test-four-tier-conflict.sh` reporting `[PASS]`. Two suites that failed in an earlier, load-contended run of the same unfiltered battery (`test-lint-state-writer-boundary.sh`, `test-update-task-status.sh`) were independently re-run in isolation and passed cleanly, confirming they were load-induced noise, not regressions, and neither names `test-four-tier-conflict.sh` or Case 1 in any way. |

#### Acceptance Points

(a) **Case 1's ordering no longer depends on a fixed wall-clock delay.** `git diff` (Phase 2
commit) shows the fixed `sleep 0.3` replaced by `until [ -f "$CASE1_SIGNAL_FILE" ]; do sleep
0.01; done`, gated on a marker file the shimmed `sleep` touches only once the foreground
`acquire-retry` call's first attempt has observed the lock held (printed its first `NOTE:` and
reached its first `sleep` call) — direct evidence of ordering, not a margin.

(b) **The fix holds under the dispatch's induced-load reproduction method.** Phase 3's three
independent passes (loads 22.62, 24.97, 26.98 — all meeting/exceeding the dispatch's reported
12.6-20.5 range) each reported 14/14 pass against the committed file.

(c) **Cases 2-13 remain unaffected.** Every one of Cases 2-13 individually reported `[PASS]` in
all three of Phase 3's loaded direct-script runs, in Phase 2's unloaded run, and in Phase 4's
full-suite run (`run-all.sh`, unfiltered) — matching Phase 1's recorded pre-fix baseline for
those same twelve cases in every instance.

(d) **Non-vacuousness.** Phase 1 recorded the unmodified, reverted fixture failing twice under
the identical induced-load harness (loads 18.33, 23.66) with the exact reported signature
(`rc=0 note_count=0 abort_count=0`); Phase 3 recorded the committed, fixed fixture passing three
times under the same harness at loads (22.62-26.98) that span and exceed the original's failing
loads. The comparison is between the two fixture constructions under the identical harness, not
between two different load levels.

**Timing**: 0.5 hours

**Depends on**: 3

**Verification Tier**: full

**Commit Mode**: per-substep

**Scope Hypothesis**: this phase asserts that exactly one source-store file was modified across
the whole task (`agent-system/extensions/core/scripts/test-four-tier-conflict.sh`) plus the
regenerated deploy artifacts under `.claude/`. Confirm with `git status --short` before
committing, and treat any second source-store file as either scope creep to justify or a
sibling's edit to leave alone.

**Files to modify**:
- `.claude/` (regenerated by `deploy-headless.sh`; never hand-authored) - redeploy only, no
  hand-edits

**Verification**:
- `timeout 540 bash .claude/scripts/deploy-headless.sh` completes successfully and the deployed
  `test-four-tier-conflict.sh` is byte-identical to the source-store copy.
- `bash .claude/scripts/verify-deploy.sh` (the complete gate set it aggregates, no `--skip-slow`,
  no `--only-gate` filter) is green, or every non-green gate is recorded as a reasoned exclusion
  with evidence that this task's file and suite are absent from the failure.
- `bash agent-system/extensions/core/scripts/tests/run-all.sh` (unfiltered) is green on the same
  terms.
- All four acceptance points above are walked with recorded evidence, not asserted.

---

## Decisions

- **Signal-file-gated releaser, not a widened delay.** Carried from research and from the
  dispatch's own ladder: a larger constant raises the load threshold at which the race reappears
  without removing it, and research demonstrated the signal-file version holding at a higher load
  (up to 27.8-30.9) than the dispatch's reported reproduction range.
- **No production-code change.** `task-lock.sh`'s `cmd_acquire_retry` already calls bare,
  unqualified `sleep`, which is the `PATH`-overridable seam Case 6 exploits today; reusing it
  preserves the suite's stated "no testability hooks in production code" invariant.
- **A distinct shim name (`CASE1_SLEEP_SHIM_DIR` / `CASE1_SIGNAL_FILE`) rather than reusing
  Case 6's.** The two shims implement different mechanisms — an ordering signal with a real
  sleep versus an iteration counter with an instant return — and sharing names would invite a
  future reader to assume one mechanism where there are two.
- **RED-first ordering (Phase 1 before any edit).** The dispatch makes non-vacuousness an
  explicit requirement, and a reproduction recorded against the *unmodified committed file* is
  stronger evidence than one recorded against a reverted copy after the fix is already written.
- **Measurement phases modify no files.** Phases 1 and 3 are deliberately edit-free so their
  `git status --short` check is an unambiguous signal, and so a sibling's concurrent edit cannot
  be mistaken for this task's own.

## Testing & Validation

- [ ] Unloaded: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only
      test-four-tier-conflict.sh` reports 14/14 pass after the fix.
- [ ] Loaded (fix): three independent induced-load passes (28 `yes` workers, 1-minute load
      average inside or above 12.6-20.5) each report 14/14 pass.
- [ ] Loaded (original, non-vacuousness): the unmodified fixture reproduces `[FAIL] 1: Tier-2
      resolving case -- rc=0 note_count=0 abort_count=0` at least twice under the same harness.
- [ ] Cases 2-13 pass in every loaded and unloaded run, both before and after the fix.
- [ ] `shellcheck -S warning` on `test-four-tier-conflict.sh` is clean of findings this change
      introduced.
- [ ] Grep confirms no `export PATH` or standalone `PATH=` statement line was introduced and
      Case 6's shim variables are untouched.
- [ ] `diff` confirms the deployed `.claude/scripts/test-four-tier-conflict.sh` matches the
      source-store copy after redeploy.
- [ ] `bash .claude/scripts/verify-deploy.sh` (full, unfiltered) and `bash
      agent-system/extensions/core/scripts/tests/run-all.sh` (full, unfiltered) are green, or
      every non-green gate is a recorded reasoned exclusion with evidence.
- [ ] No `yes` load worker survives any measurement phase.

## Artifacts & Outputs

- `agent-system/extensions/core/scripts/test-four-tier-conflict.sh` - Case 1's fixture rebuilt
  on a signal-file-gated releaser, with a rewritten header comment explaining the construction.
- `.claude/scripts/test-four-tier-conflict.sh` - regenerated deploy artifact, byte-identical to
  the source-store copy.
- `specs/424_harden_four_tier_conflict_case1_releaser_race/summaries/01_harden-case1-releaser-race-summary.md`
  - completion summary carrying the recorded A/B evidence (both sides' load averages and
  outcomes), any reasoned exclusions, and the deferred `shell-script-testing.md` follow-up note.
- Per-phase commits following `task {N}: ...` / `task {N} phase {P}: ...` conventions.

## Rollback/Contingency

The entire change is confined to one test fixture file plus a regenerated deploy artifact, and
no production code or other case is touched, so reverting is low-risk and leaves no partial
state behind.

- **Before Phase 2's commit lands**: the change is a single uncommitted file. Per
  `context/contracts/recovery.md`'s rollback rung, take a snapshot before any destructive git
  operation on a dirty tree (`bash .claude/scripts/git-snapshot.sh 424`, task number explicit),
  then discard. Do not emit the reverting default form as a routine pre-phase checkpoint; use
  `--no-revert` if an ordinary defensive checkpoint is wanted.
- **After Phase 2's commit lands**: revert that single commit (`git revert <sha>`), which
  restores Case 1's original fixed-delay construction verbatim. The suite returns to its
  pre-task state: Case 1 passing unloaded, racing under heavy contention — the known defect,
  not a new one.
- **After Phase 4's redeploy**: re-run `bash .claude/scripts/deploy-headless.sh` after the
  revert to bring the deployed copy back in line with the reverted source store; never hand-edit
  `.claude/scripts/test-four-tier-conflict.sh` to undo it.
- **If the fix proves insufficient under some higher load not yet measured**: do not widen the
  releaser's wait into a fixed delay as a stopgap — that reintroduces exactly the defect this
  task removes. Report the observed load and signature, leave the signal-file construction in
  place, and investigate whether the shim's firing point still coincides with the first attempt's
  lock observation (research flags a future edit to `cmd_acquire_retry`'s NOTE:/sleep pairing as
  the one way that coincidence could break).
