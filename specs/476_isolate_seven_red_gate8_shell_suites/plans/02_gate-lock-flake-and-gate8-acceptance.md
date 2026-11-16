# Implementation Plan: Task #476

- **Task**: 476 - Make the seven untracked red Gate 8 shell suites green or declared-expected
- **Status**: [IMPLEMENTING]
- **Effort**: 5 hours
- **Dependencies**: 423 (CLOSED), 445 (CLOSED), 568 (CLOSED) -- all three declared edges are
  satisfied; none blocks this plan. See report 02 Finding 3.
- **Research Inputs**: specs/476_isolate_seven_red_gate8_shell_suites/reports/02_premise-refresh-and-gate-lock-concurrency-flake.md
  (primary), specs/476_isolate_seven_red_gate8_shell_suites/reports/01_fixture-lib-allowlist-root-cause.md
  (superseded in part by report 02 Finding 2)
- **Artifacts**: plans/02_gate-lock-flake-and-gate8-acceptance.md (this file)
- **Standards**: plan-format.md, status-markers.md, artifact-management.md, tasks.md,
  shell-script-testing.md, source-store-deploy-boundary.md,
  no-task-references-in-deliverables.md, no-record-versioning-in-deliverables.md
- **Type**: meta
- **Lean Intent**: false

## Overview

Why this task exists, in its own terms: a standing red Gate 8 destroys the signal value of the
full gate for every future task. Every subsequent dispatch running a full `verify-deploy.sh` must
either hand-diff its failures against an unwritten mental baseline or ignore Gate 8 entirely, and
both outcomes mean a real regression introduced later passes unnoticed. This task restores Gate 8
as a usable binary signal.

The work that remains is much smaller than this task's original framing, because the premise has
moved. All seven in-scope suites now pass **standalone** with zero failures (report 02 Finding 2),
the five-suite fixture-completeness defect report 01 identified has already been fixed upstream by
commits this task did not author, and both mechanisms this task was told to wait for (the
expected-versus-NEW failure distinction; the excluded eighth suite's byte-count baseline) are
delivered and closed. What is left is three things: one genuinely new, reproducible,
**aggregate-only** concurrency flake in `test-gate-lock.sh` (passes 16/0 alone, fails 14/2 inside
`run-all.sh`'s own parallel battery, classified `NEW` by `--fail-on-new`); two stale
`known-failures.txt` rows for suites that are now green; and the literal acceptance bar this task
set for itself -- a full, unscoped Gate 8 run reporting zero *unexpected* failures, performed
twice from a clean tree to catch order- and concurrency-dependent flakes.

### Research Integration

Key findings from report 02 that shape this plan:

- **Finding 2 re-scopes outcome 2 away from fixture-allowlist repair.** Every suite's own
  `REQUIRED_LIBS`/sandbox copy-list was read directly and already contains
  `project-number-inuse.sh`. Report 01's Recommendation 1 is already applied to all five suites it
  named. This plan must not re-apply it.
- **Finding 4 is the one piece of genuinely new, unresolved work.** `test-gate-lock.sh` fails two
  cases only when run concurrently with its file-scope siblings: the "killed holder (process-group
  teardown)" case (a 3000ms poll window for a nested `verify-deploy.sh --only-gate 8` startup) and
  the "fail-open (verify-deploy.sh Gate 8)" case (nested run exits `rc=1` with run-all.sh reporting
  harness-level exit 2). The research deliberately did **not** settle whether these share one cause
  or have two, and did not isolate the exit-2 trigger. That disambiguation is this plan's Phase 1.
- **Finding 6**: two `known-failures.txt` rows (`test-orchestrate-cycle-postflight.sh`,
  `test-lint-unit-integration-boundary.sh`) describe symptoms both now confirmed fixed by direct
  re-run. Neither causes a false `[FAIL]` today, but a stale already-known row for a suite that
  regresses later would mask a genuine new regression as an old attributed one -- the exact failure
  mode this task's motivation names.
- **Finding 5**: the excluded eighth suite's "hand this to record 423" instruction cannot be
  discharged literally, because 423 is archived and cannot receive findings. The symptom
  reproduces verbatim today. This plan hands the observation forward as a follow-up rather than
  dropping it, and does **not** widen scope to fix it.
- **Recommendation 5 / Risk 1**: report 02's own verification used a seven-suite `--only` subset,
  which `run-all.sh`'s header is explicit is not evidence of a clean full run. The full battery is
  wall-clock expensive (`test-gate-cache-equivalence.sh` alone costs ~1190s standalone and is
  killed at the 600s per-suite bound inside an aggregate run, correctly reported EXPECTED). Phase 3
  budgets for this explicitly instead of discovering it at verification time.

### Prior Plan Reference

No prior plan. This is this task's first plan artifact.

### Roadmap Alignment

No roadmap context was provided to this dispatch (`roadmap_path` absent; `roadmap_flag` not set),
so no roadmap phases are included and no roadmap item alignment is asserted.

## Goals & Non-Goals

**Goals**:

- Classify `test-gate-lock.sh`'s two aggregate-only failing cases into exactly one of the four
  classes outcome 1 names (ambient-host-state leak / repo-state leak / genuine defect in the code
  under test / legitimately-expected), **with recorded evidence a future reader can check**, and
  remedy each per its class.
- Remove the two stale `known-failures.txt` rows, so every surviving row in that file describes a
  failure that actually still reproduces.
- Reach and demonstrate the literal acceptance bar: two full, unscoped Gate 8 runs from a clean
  tree, each reporting zero NEW (unexpected) failures, with every remaining failure matched to a
  declared baseline row.
- Redeploy the source store to `RESULT=landed_verify_clean` so the deployed tree matches.
- Hand the excluded eighth suite's still-reproducing regression forward as a follow-up rather than
  silently dropping the now-undischargeable "hand this to record 423" instruction.

**Non-Goals**:

- Re-running the stash experiment that proved these failures predate this task's parent work. That
  provenance is established; re-deriving it is wasted effort.
- Re-applying report 01's fixture-allowlist remedy. Already present in all five suites it named.
- Fixing `test-verify-deploy-context-budget.sh`. It is deliberately outside `file_scope` and stays
  outside it. Its regression is handed off, not acted on.
- Fixing production code under test that lies outside `file_scope` if Phase 1 classifies a failure
  as class (c). Record it and hand it off; a scope excursion stranding uncommitted files while
  fixing the test corpus would be self-defeating.
- Recalibrating `test-gate-cache-equivalence.sh`'s cost or `run-all.sh`'s 600s per-suite bound.
  That suite's slowness is already declared, attributed, and owned by an existing
  `known-failures.txt` row; it is EXPECTED, not a failure this task must clear.

## Risks & Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| The full battery surfaces NEW failures beyond `test-gate-lock.sh`, in suites outside `file_scope` (report 02 Risk 1: ~140 other suites were never run together in the research dispatch) | H | M | Phase 3 has an explicit triage branch: an in-scope NEW failure is fixed or declared in that phase; an out-of-scope one is recorded and handed off under outcome 3, never fixed by widening scope. The acceptance bar is zero *unexpected* failures, which a declared-and-attributed handoff row can satisfy without a scope excursion. |
| Phase 1's diagnosis cannot isolate the exit-2 cause within its own budget | M | M | The phase's decision step is explicitly two-branch: a confirmed mechanism gets a fix; an unisolated one gets a declared `known-failures.txt` row with an honest `intermittent` category and a reason naming exactly what was and was not established. A declared, attributed expected failure satisfies outcome 1 class (d) and the acceptance bar; an undeclared intermittent one does not. |
| Widening a timing window masks a real defect rather than fixing one | M | M | The established convention's decision order is binding: seam-first for readable-input axes; for the timing axis, inject the clock or intercept the delay, then assert ordering/causality, and widen the window only as a last resort **with explicit justification**. Phase 1 records which rung it used and why cheaper rungs were unavailable. |
| A concurrent sibling's in-flight edits perturb the full battery or the redeploy | M | M | A sibling is scheduled this same cycle and declares `__WHOLE_TREE__` plus `verify-deploy.sh` and `orchestrate-build-dispatch.sh`. Re-read every file immediately before editing; stage only this task's own hunks with an explicit file list; treat a build failure outside this task's own `file_scope` as possibly a sibling's in-flight edit rather than this task's regression, and report rather than dismiss a foreign commit or modification. |
| Two full battery runs consume most of the implementation dispatch's wall clock | M | H | Phase 3 backgrounds each run and waits on it with a hard timeout and writer liveness via `kill -0` on the captured PID (one waiter per log), per the bounded-build-waiter pattern -- never `ps | grep`/`pgrep -f`, never an unbounded watch. |
| `known-failures.txt` edits collide with the sibling that also regenerates the whole tree | L | M | Phases 1 and 2 are serialized (Phase 2 depends on Phase 1) specifically so the two writes to that file never interleave, and each re-reads the live file immediately before editing. |

## Decisions

- **Phase 1 and Phase 2 are serialized rather than parallelized**, although their work is logically
  independent. Both can land in `known-failures.txt` (Phase 1 only on its declared-expected
  branch), and a wave table that advertised them as parallel would advertise a write conflict on
  that file. Serializing costs one wave and removes the hazard entirely.
- **Diagnosis and remedy live in the same phase (Phase 1) rather than in two.** The remedy's
  *target file* is a function of the diagnosis: a confirmed host-state coupling is fixed in the
  suite, an unisolable one is declared in the baseline manifest. Splitting them would force this
  plan to pre-commit to a branch the evidence has not yet selected.
- **The eighth suite's handoff is a recorded observation plus a summary Follow-up, not a task
  this plan creates.** Task creation is the `/orchestrate` conclusion-stage proposal audit's own
  surface, and that audit has already demonstrated the correct behavior for a structurally
  identical situation by returning duplicate-of-open rather than creating a redundant record.
  Phase 3 records the evidence where that audit will find it.

## Implementation Phases

**Dependency Analysis**:

| Wave | Phases | Blocked by |
|------|--------|------------|
| 1 | 1 | -- |
| 2 | 2 | 1 |
| 3 | 3 | 2 |

Phases within the same wave can execute in parallel.

---

### Phase 1: Reproduce, classify, and remedy `test-gate-lock.sh`'s aggregate-only flake [COMPLETED]

**Goal**: Turn report 02 Finding 4 from a reproduced symptom into a classified failure with
recorded evidence, and apply the remedy its class dictates -- either a sealed fixture in the suite
itself, or a declared, attributed baseline row.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` and
      `agent-system/extensions/core/scripts/tests/known-failures.txt` immediately before any edit,
      in case a sibling has already changed either. *(completed)*
- [x] Reproduce the flake cheaply, excluding the 20-minute suite that dominates the aggregate run's
      cost and is already declared EXPECTED:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-lock.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-predispatch-review.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-deploy-gate.sh,test-redeploy-checkpoint-promotion.sh --fail-on-new`.
      Confirm `test-gate-lock.sh` reports 14 passed / 2 failed and is classified `NEW`. If it does
      not reproduce on the first attempt, repeat up to three times before concluding the flake is
      load-threshold-dependent; record the observed hit rate either way. *(deviation: altered —
      hit rate was 0/3; did not reproduce under today's host load, zero failures each attempt)*
- [x] Capture the two failing cases' full output from the run's own per-suite output files rather
      than re-deriving the symptom from assertion text. Both cases already write diagnostic detail
      (`$WORKDIR/siggroup.out` for the teardown case; the captured `failopen_vd_out` for the
      fail-open case). *(deviation: altered — no failing-case output existed since the flake did
      not reproduce; used a diagnostic instrumented copy of the suite instead to measure real
      timing margins)*
- [x] **Case "killed holder (process-group teardown)"** (suite lines ~248-283): determine whether
      the failure is the 3000ms poll budget expiring before the nested
      `verify-deploy.sh --only-gate 8` startup self-reports its pid and creates
      `$GATE_LOCK_DIR` under CPU contention from the parallel pool (this host: `nproc` 24,
      `JOBS_CAP` 4, so up to three sibling suites compete). Evidence: whether
      `$WORKDIR/siggroup.pid` and `$GATE_LOCK_DIR` appear at all shortly *after* the window
      expires, versus never appearing. *(completed: live-code analysis of run-all.sh shows
      test-gate-lock.sh is in LOAD_SENSITIVE_BASENAMES and runs fully serially before the
      parallel pool starts, so it can never overlap with sibling suites within one run-all.sh
      invocation; a diagnostic instrumented copy measured 50ms pid/lockdir-appear and 500ms/0ms
      teardown against the 3000ms budgets, standalone, under today's load)*
- [x] **Case "fail-open (verify-deploy.sh Gate 8)"** (suite lines ~373-381): disambiguate which of
      `run-all.sh`'s two plausible exit-2 sites fires -- "zero test suites discovered" or the
      `TOTAL_ACCOUNTED != TOTAL_DISCOVERED` scheduling-safety assertion -- by reading the nested
      run's own captured stderr, not by inference. Then test the two candidate mechanisms the
      research named: a filesystem-visibility race in the fixture under contention, versus
      cross-case pollution from the immediately preceding teardown case's backgrounded `setsid`
      subprocess still winding down inside the **same** `$WORKDIR` when this case starts.
      *(deviation: altered — this case never failed in any reproduction attempt (rc=0 always),
      so the exit-2 site was not directly isolated; addressed the more plausible candidate
      mechanism, cross-case pollution, by making the teardown case confirm process death rather
      than inferring it)*
- [x] Explicitly settle whether the two cases share one cause or have two. The research left this
      unsettled and warned against assuming one; record the answer with its evidence. *(completed:
      judged ONE shared cause by mechanism inspection — the teardown case's unconfirmed process
      death could leave a lingering child polluting the fail-open case's reuse of the same
      $WORKDIR — not confirmed by a second live occurrence since the flake did not reproduce)*
- [x] Rule out the fixture itself as the defect before touching anything else: a fixture that does
      not construct the state it asserts over would produce exactly these symptoms with no defect
      in the code under test at all. *(completed: fixture constructs real state it asserts over —
      self-reported pid file, real GATE_LOCK_DIR — not itself the defect)*
- [x] Discard or confirm, against the committed tree, the carried speculation that a concurrent
      sibling writer's in-flight edit to `update-task-status.sh` or its dependency chain causes
      this. It is unverified and is not evidence until checked. *(completed: discarded —
      test-gate-lock.sh's own REQUIRED file list and fixture copy-list never reference
      update-task-status.sh or anything in its dependency chain, and verify-deploy.sh's
      gate8_run() path does not invoke it; no causal path exists)*
- [x] Classify each case into exactly one of outcome 1's four classes, and record the
      classification **with its evidence** via
      `bash .claude/scripts/issue-record.sh --task-dir "$TASK_DIR" --kind issue --class "..." --severity ... --what-happened "..."`
      (non-fatal; a recording failure must never fail the dispatch). A classification without
      evidence does not satisfy outcome 1. *(completed: both cases classified class (a)
      ambient-host-state fixture timing, recorded in issues.jsonl with full evidence)*
- [x] Apply the remedy the classification dictates: *(completed: class (a) branch — added a
      bounded `kill -0` liveness wait on the siggroup child's pid after SIGTERM, asserting
      ordering/causality instead of widening a poll window, per the established convention)*
      - **Class (a) or (b)** -- seal the fixture so the suite constructs what it asserts over. Follow
        the established convention's decision order, do not invent a second one: seam-first for
        readable-input axes; for the timing axis, inject the clock or intercept the delay, then
        assert ordering/causality, and widen a window only as a last resort with explicit
        justification recorded in the suite's own comment. For the teardown case specifically, a
        bounded `kill -0` liveness wait on the captured pid (never `ps | grep` or `pgrep -f`) is the
        sanctioned shape for confirming the backgrounded process-group child has actually died
        before the next case reuses the shared `$WORKDIR`.
      - **Class (c)** -- a genuine defect in code outside `file_scope`: do **not** widen this task.
        Record it and hand it off.
      - **Class (d)** -- add one row to `known-failures.txt` in its existing
        `basename|category|reason|owner` format, with an honest `category` (`intermittent` for a
        load-threshold-dependent flake, `load-sensitive` for a cost/bound mismatch) and a `reason`
        naming precisely what was established and what was not. The `owner` field MUST be a durable
        anchor or the literal `needs-owner` -- a bare task number is prohibited in this file, which
        lives under `agent-system/extensions/**`.
- [x] Verify: re-run the same `--only` reproduction command and confirm `test-gate-lock.sh` is
      either clean or correctly annotated EXPECTED rather than NEW. Then confirm the suite still
      passes standalone (16/0) -- a fix that greens the aggregate run while breaking the standalone
      run is not a fix. *(completed: standalone now 17 passed, 0 failed (new liveness case added
      one); --only aggregate run clean, 6 passed/0 failed/0 NEW after the fix)*
- [x] Commit this phase's green result with an explicit file list, never a directory or glob
      pathspec. *(completed)*

**Timing**: 2 hours

**Depends on**: none

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-lock.sh,test-gate8-expected-new-distinction.sh,test-orchestrate-cycle-plan.sh,test-run-all-failure-reporting.sh,test-run-all-selection.sh`
covers this phase's edits -- those are exactly the suites `suite_selection_select` returns for the
two paths in this phase's `Files to modify` block (`test-gate-lock.sh` -> `test-gate-lock.sh`;
`known-failures.txt` -> the other four), and the edits are confined to one test suite and one
advisory data file with no externally visible signature change.

**Scope Hypothesis**: This phase asserts exactly two failing cases in `test-gate-lock.sh` under
the aggregate run, and that the `known-failures.txt` edit is conditional (needed only on the class
(d) branch). Confirm both at implementation time from the reproduction run's own output: a
different failing-case count, or a third case, means the premise moved again and the
classification work must cover what is actually observed, not what is written here.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` - seal the fixture against the
  host-state/timing coupling the diagnosis confirms (class (a)/(b) branch); record the chosen
  convention rung and its justification in the suite's own comment
- `agent-system/extensions/core/scripts/tests/known-failures.txt` - conditional, class (d) branch
  only: one new row declaring the failure expected, with an attributed reason and a durable-anchor
  or `needs-owner` owner

**Verification**:

- The `--only` reproduction command above reports `test-gate-lock.sh` as passing, or as failing
  with an `EXPECTED` annotation matched to the row just added -- never `NEW`.
- `bash agent-system/extensions/core/scripts/tests/test-gate-lock.sh` standalone still reports
  16 passed, 0 failed (or a higher pass count if the fix adds a case).
- Each of the two cases has a recorded classification with evidence in this task's `issues.jsonl`.

---

### Phase 2: Remove the two stale `known-failures.txt` rows [COMPLETED]

**Goal**: Ensure every surviving row in the baseline manifest describes a failure that actually
still reproduces, so a future regression in either suite is reported `NEW` rather than masked as an
old, already-attributed failure.

**Tasks**:

- [x] Re-read `agent-system/extensions/core/scripts/tests/known-failures.txt` immediately before
      editing (Phase 1 may have added a row, and a sibling may have touched the file). *(completed)*
- [x] Re-confirm, by direct standalone re-run rather than by citing the research, that both suites
      are green now: `bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
      (expect 312 passed, 0 failed) and
      `bash agent-system/extensions/core/scripts/tests/test-lint-unit-integration-boundary.sh`
      (expect 15 passed, 0 failed). A row must not be removed on the strength of a prior dispatch's
      measurement alone. *(deviation: altered — test-orchestrate-cycle-postflight.sh confirmed
      312/0, but test-lint-unit-integration-boundary.sh was NOT green: 14 passed, 1 failed, for a
      different, newly-discovered coverage gap unrelated to the row's original description)*
- [x] Remove the `test-orchestrate-cycle-postflight.sh` row, whose described symptom (acceptance
      cases 6/7/8b expecting `researching`/`planned` and observing `planning`, plus an unlinked plan
      artifact) no longer reproduces. *(completed)*
- [ ] Remove the `test-lint-unit-integration-boundary.sh` row, whose described symptom (two suites
      with no row in `suite-classification.data`) no longer reproduces. *(deviation: altered — the
      ORIGINALLY-described symptom is confirmed fixed (both named suites now have rows), but the
      suite is still red for a DIFFERENT, newly-discovered gap: test-gate8-suite-selection.sh
      (added by an unrelated, already-committed change) has no classification row. Per this
      phase's own Scope Hypothesis, did not remove the row since the suite is still red; instead
      updated its reason/owner to describe the current gap and added the missing
      suite-classification.data row to the source store (test-gate8-suite-selection.sh,
      integration, invokes:verify-deploy.sh,run-all.sh). That fix only takes effect once Phase 3's
      redeploy propagates it to the deployed tree this suite's own resolution checks
      "deploy-tree-first" against; re-verify and remove the row then if it reports 0 failures*)
- [x] Leave every other row intact -- in particular the `test-gate-cache-equivalence.sh`
      `load-sensitive` row and the `test-run-all-parallel.sh` `intermittent` row, both of which
      still describe live, attributed, accepted conditions. *(completed)*
- [x] Preserve the file's comment block and format exactly; the header's own contract (advisory
      only; a stale or partial manifest must never change which suites run) is unaffected by a row
      removal. *(completed)*
- [x] Commit with an explicit file list. *(completed)*

**Timing**: 0.5 hours

**Depends on**: 1

**Verification Tier**: local

**Tier Justification**: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate8-expected-new-distinction.sh,test-orchestrate-cycle-plan.sh,test-run-all-failure-reporting.sh,test-run-all-selection.sh`
covers this phase's edit -- those four are exactly what `suite_selection_select` returns for
`agent-system/extensions/core/scripts/tests/known-failures.txt`, this phase's only touched path.

**Scope Hypothesis**: This phase asserts exactly two stale rows. Confirm at implementation time by
re-running both named suites standalone; if either is still red, that row is not stale and must
stay, and if a third row's suite has also gone green, the exclusion stated here was incomplete --
re-check the manifest against live results rather than against this count.

**Files to modify**:

- `agent-system/extensions/core/scripts/tests/known-failures.txt` - remove the two rows whose
  described symptoms no longer reproduce

**Verification**:

- Both named suites report 0 failures standalone, measured in this phase.
- The four suites named in the Tier Justification pass under the `--only` command above.
- `grep -c '^test-' known-failures.txt` returns a count two lower than before this phase (adjusted
  by one if Phase 1 took its class (d) branch).

---

### Phase 3: Full-battery acceptance, redeploy, and the eighth-suite handoff [COMPLETED]

**Goal**: Meet this task's literal acceptance criterion -- a full, unscoped Gate 8 run reporting
zero unexpected failures, performed twice from a clean tree -- land the deployed tree, and pass
the excluded eighth suite's still-reproducing regression forward rather than dropping it.

**Tasks**:

- [x] Confirm the working tree is clean of this task's own changes (all of Phases 1-2 committed)
      before the first full run. A selected-subset pass is explicitly not evidence of a clean full
      run, per `run-all.sh`'s own header, so neither of these runs may use `--only`. *(completed)*
- [x] Run the full, unscoped battery the first time:
      `bash agent-system/extensions/core/scripts/tests/run-all.sh --fail-on-new`. Background it and
      wait with a hard timeout and writer liveness via `kill -0` on the captured PID, one waiter per
      log -- never `ps | grep`, never `pgrep -f`, never an unbounded watch. Budget generously:
      `test-gate-cache-equivalence.sh` alone is killed at the 600s per-suite bound inside an
      aggregate run and is correctly reported EXPECTED when that happens. *(completed: 193
      passed, 3 failed (3 expected, 0 NEW), 196 total, pre-redeploy)*
- [x] Run it a second time, serially after the first completes, to catch order- and
      concurrency-dependent flakes that a single run would miss. *(completed: identical, 193
      passed/3 failed/0 NEW)*
- [x] Triage every failure in both runs against the `EXPECTED`/`NEW` annotation the manifest
      mechanism supplies:
      - A failure annotated `EXPECTED` and matched to a declared row satisfies the bar; no action.
      - A `NEW` failure in a suite inside this task's `file_scope`: fix it, or declare it with an
        attributed reason in `known-failures.txt`, then re-run the full battery.
      - A `NEW` failure in a suite **outside** `file_scope`: do not widen this task. Record it via
        `issue-record.sh` with the evidence, name it in the summary's Follow-ups, and -- if it
        prevents the zero-unexpected-failures bar from being met -- declare it in
        `known-failures.txt` with an honest `needs-owner` row rather than leaving it undeclared. An
        undeclared expected failure is indistinguishable from a regression, which is the condition
        this task exists to end. *(completed: all 3 pre-redeploy failures EXPECTED, no NEW failure
        in any run; a 4th, one-off full `verify-deploy.sh` invocation transiently showed gate8 NEW
        with no suite identity captured and did not reproduce on retry — recorded via
        issue-record.sh rather than chased further, since the acceptance bar's own two runs were
        both independently clean)*
- [x] Record the eighth-suite handoff so the conclusion-stage proposal audit can act on it: the
      `test-verify-deploy-context-budget.sh` symptom (`baseline fixture is not clean (rc=1, gate20
      finding lines=0)` -- fixture setup broken, later cases unreliable) still reproduces verbatim
      today, after both its owning record's closure and a later commit that specifically touched
      that suite's fixture. Capture it via `issue-record.sh` and name it in the summary's Follow-ups.
      Do **not** edit that suite -- it is deliberately outside `file_scope`. *(completed)*
- [x] Redeploy the source store with the bounded-wait idiom (`timeout 540`, Bash tool timeout raised
      to 600000): `bash agent-system/extensions/core/scripts/deploy-headless.sh`, waiting to
      `RESULT=landed_verify_clean`. Never hand-author under `.claude/**`; it is a gitignored,
      disposable deploy artifact regenerated from the source store. *(completed: two redeploys,
      both RESULT=landed_verify_clean; the second after removing the now-green
      test-lint-unit-integration-boundary.sh known-failures.txt row)*
- [x] Confirm no file landing under `agent-system/**` in this task carries a task-number reference
      or record-versioning language. Both are permitted in this task's own `specs/**` artifacts and
      in commit messages, and prohibited in the source store. *(completed: zero matches)*
- [x] Commit the phase's result with an explicit file list. *(completed)*

**Timing**: 2.5 hours (dominated by wall clock: two full batteries plus the redeploy)

**Depends on**: 2

**Verification Tier**: full

**Files to modify**:

- `__WHOLE_TREE__` - this phase invokes whole-tree regeneration via `deploy-headless.sh`
- `agent-system/extensions/core/scripts/tests/known-failures.txt` - conditional: a declared row for
  any NEW failure the full battery surfaces that cannot be fixed inside `file_scope`

**Verification**:

- The complete gate set runs green: `bash .claude/scripts/verify-deploy.sh` (source-store path:
  `agent-system/extensions/core/scripts/verify-deploy.sh`).
- Two full, unscoped `run-all.sh --fail-on-new` runs each report **zero NEW failures**, with every
  remaining failure annotated `EXPECTED` and matched to a declared `known-failures.txt` row.
- `deploy-headless.sh` reaches `RESULT=landed_verify_clean`.
- The eighth-suite observation is recorded in this task's `issues.jsonl` and named in the summary's
  Follow-ups.

---

## Testing & Validation

- [ ] `test-gate-lock.sh` passes standalone **and** inside an aggregate `run-all.sh` run with its
      file-scope siblings -- the two conditions that diverged and produced this task's remaining
      work.
- [ ] `test-orchestrate-cycle-postflight.sh` and `test-lint-unit-integration-boundary.sh` each
      report 0 failures standalone, re-measured in this task rather than cited from research.
- [ ] Two full, unscoped `run-all.sh --fail-on-new` runs report zero NEW failures.
- [ ] Every surviving `known-failures.txt` row describes a failure that still reproduces, and every
      remaining Gate 8 failure matches one.
- [ ] `verify-deploy.sh` passes in full, and `deploy-headless.sh` reaches
      `RESULT=landed_verify_clean`.
- [ ] No file under `agent-system/**` touched by this task contains a task-number reference or
      record-versioning language.

## Artifacts & Outputs

- Repaired or declared-expected `agent-system/extensions/core/scripts/tests/test-gate-lock.sh`.
- Reconciled `agent-system/extensions/core/scripts/tests/known-failures.txt`: two stale rows
  removed, any genuinely-expected new failure declared with an attributed reason.
- A regenerated deployed `.claude/` tree at `RESULT=landed_verify_clean`.
- Per-case classifications with evidence in this task's `issues.jsonl`.
- A completion summary naming the eighth-suite regression as a follow-up, plus any class (c)
  defects or out-of-scope NEW failures found and handed off.

## Rollback/Contingency

- **Phase 1's remedy makes things worse** (the aggregate run greens but the standalone run breaks,
  or a different case starts failing): revert that phase's commit for the suite file alone and fall
  back to the class (d) branch -- a declared, attributed `intermittent` row naming exactly what was
  established and what was not. A declared expected failure satisfies the acceptance bar; a
  speculative fix that shifts the failure does not.
- **The exit-2 case resists isolation entirely**: do not widen a window as a substitute for
  diagnosis -- "widen a window" is not an available remedy for a harness-level exit 2 that is not
  itself a poll or timeout. Declare it, with the reason stating plainly that the mechanism was not
  isolated and naming both candidate hypotheses for the next owner.
- **The full battery surfaces a large cluster of out-of-scope NEW failures**: do not attempt them.
  Declare each with a `needs-owner` row and an honest reason, record them, and name them in the
  summary's Follow-ups. The acceptance bar is zero *unexpected* failures, not zero failures.
- **The redeploy does not reach `landed_verify_clean`**: treat a failure in a file outside this
  task's own `file_scope` as possibly a concurrent sibling's in-flight edit rather than this task's
  own regression; check `git log` to confirm the work is not this task's, then stop and report
  rather than proceeding or dismissing it as noise.
- **General**: every commit in this plan stages an explicit file list. Reverting any single phase is
  therefore a scoped revert of its own commit, with no collateral to untangle.
