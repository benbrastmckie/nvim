# Research Report: Premise Refresh and a New Concurrency-Dependent Flake (Task #476)

- **Task**: 476 - Make the seven untracked red Gate 8 shell suites green or declared-expected
- **Started**: 2026-11-16T08:20:00Z
- **Completed**: 2026-11-16T09:10:00Z
- **Effort**: ~50 minutes
- **Dependencies**: Task 423 (CLOSED), Task 445 (CLOSED), Task 568 (CLOSED) -- all three
  dependency edges this task declared are now satisfied; see Findings 2 and 3.
- **Sources/Inputs**:
  - Direct execution (standalone and via `run-all.sh --only`) of all seven in-scope suites, the
    excluded eighth suite, and `test-lint-unit-integration-boundary.sh`
  - `agent-system/extensions/core/scripts/tests/known-failures.txt` (live content)
  - `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` (lines 246-300, 340-382)
  - `agent-system/extensions/core/scripts/tests/run-all.sh` (arg parsing, `--jobs auto`
    resolution, discovery/scheduling exit-2 sites)
  - `agent-system/extensions/core/scripts/verify-deploy.sh` (`GATE8_JOBS` default, line 1390-1391)
  - `agent-system/extensions/core/context/standards/shell-script-testing.md`'s
    "## Ambient-host-state isolation" section (the task-170 convention)
  - `specs/state.json` (task 476's own record: status, `file_scope`, `dependencies`, empty
    `artifacts`), `specs/archive/{415,423,428,445,448}_*/summaries/*.md`,
    `specs/archive/170_isolate_shell_suites_from_host_state/{plans,reports}/*.md`,
    `specs/568_*/summaries/*.md`
  - `specs/476_isolate_seven_red_gate8_shell_suites/issues.jsonl` (two prior entries),
    `reports/01_fixture-lib-allowlist-root-cause.md` (prior artifact)
  - `git log`/`git show` on commit `a4e32ff9e`
- **Artifacts**: this report
- **Standards**: report-format.md, status-markers.md, artifact-management.md, tasks.md,
  source-store-deploy-boundary.md, shell-script-testing.md

## Executive Summary

- **The premise has moved substantially since report 01 and since this dispatch's own
  description was written.** All seven of the suites named in this task's scope now pass with
  ZERO failures when run **standalone**: `test-gate-cache-equivalence.sh` (17/0, ~20 min),
  `test-gate-lock.sh` (16/0), `test-orchestrate-cycle-postflight.sh` (312/0),
  `test-orchestrate-predispatch-review.sh` (37/0), `test-orchestrate-unwind-dispatch.sh` (21/0),
  `test-postflight-deploy-gate.sh` (29/0), `test-redeploy-checkpoint-promotion.sh` (17/0). This
  supersedes report 01's 12/17/etc. failure counts and this dispatch's own carried "5 failed" /
  "3 failed" figures (Description lines 75-77) -- all now 0.
- **Both declared blocking dependencies (423, 445) are CLOSED**, and a third task (568) already
  independently fixed and closed one of the five shared-cause suites
  (`test-orchestrate-cycle-postflight.sh`). None of these closures were reflected in this
  dispatch's own carried description text, which still frames 423/445 as open blockers.
- **A genuinely NEW, reproducible, concurrency-dependent flake was found in this dispatch**:
  `test-gate-lock.sh` passes standalone (16/0) but fails with 2 failures (14/2) when run inside
  `run-all.sh`'s own aggregate battery alongside its six file-scope siblings, even using only a
  7-suite `--only` subset. This is exactly the order/concurrency-dependent failure mode this
  task's own outcome 5 anticipated ("a suite that passes alone may still fail in a parallel
  run"), and it is NOT in `known-failures.txt` -- `run-all.sh --fail-on-new` classifies it `NEW`.
  Both failing cases are timing/host-load-coupled in the precise sense
  `shell-script-testing.md`'s "## Ambient-host-state isolation" section defines; see Finding 4.
- **The excluded eighth suite's "hand this to 423" instruction can no longer be literally
  discharged**: task 423 closed on 2026-11-10 with a different root-cause attribution (a gate-24
  `/ide`-finding residual) than the "baseline fixture is not clean (rc=1, gate20 finding
  lines=0)" symptom this dispatch's addendum describes. This report re-ran
  `test-verify-deploy-context-budget.sh` directly: the symptom reproduces VERBATIM right now,
  after 423's closure and after a later commit (`a4e32ff9e`) that specifically touched this
  suite's fixture ("fixture carries the hook identity module") without resolving it. Since 423 is
  archived, this needs a fresh follow-up task, not a hand-off to a closed record; see Finding 5.
- **`test-lint-unit-integration-boundary.sh`** (in `file_scope` but not in the Description's
  seven-suite list) is also now green (15/0); its `known-failures.txt` row is stale and should be
  removed as a low-priority cleanup, same as the stale row still present for
  `test-orchestrate-cycle-postflight.sh` (see Finding 6).
- **Net effect on this task's remaining work**: the fixture-completeness root cause report 01
  identified (and this dispatch's own addendum extended) has already been fixed upstream, for all
  seven suites, by commits this task did not author (`a4e32ff9e` plus task 568's own closure).
  The remaining concrete work in `file_scope` is: (a) diagnose and fix (or declare-expected)
  `test-gate-lock.sh`'s new aggregate-only flake, (b) run the full, unscoped Gate 8 battery twice
  per outcome 5's literal acceptance bar (not yet done in this research dispatch -- see Risks),
  and (c) hand off the excluded-eighth-suite regression as a new task rather than to closed 423.

## Context & Scope

This is task 476's second research dispatch. A prior artifact
(`reports/01_fixture-lib-allowlist-root-cause.md`) already classified five of the seven suites
as sharing one fixture-completeness defect (a hardcoded library allowlist in each suite's own
fixture-builder omitting `lib/project-number-inuse.sh`, a hard dependency of `state-write.sh`
introduced by commit `ab6aaf8c8`) and left two suites (`test-gate-cache-equivalence.sh`,
`test-gate-lock.sh`) unexplained by that mechanism. This dispatch's own description additionally
carries several numeric/pass-fail claims (per the Premise Re-Validation block) that needed
checking against live state before being acted on. This report performs that check, re-measures
every suite directly, and reports what has changed since report 01 and since the description was
written -- it does not apply any fix (research phase; no file in `file_scope` was modified).

## Findings

### 1. Premise re-validation of the dispatch description's carried figures

Per the Premise Re-Validation block, each flagged line was checked against live state:

| Description claim | Current status |
|---|---|
| "AN EIGHTH SUITE IS DELIBERATELY EXCLUDED... owned by open record 423" | **Stale.** Record 423 is CLOSED (archived to `specs/archive/423_fix_verify_deploy_context_budget_byte_count_drift/`, `[COMPLETED]`, 2026-11-10). See Finding 5. |
| "HAND THIS OBSERVATION TO RECORD 423... baseline fixture is not clean (rc=1, gate20 finding lines=0)" | **Re-confirmed as still reproducing, independently of 423's now-closed state.** See Finding 5. |
| "open record 445... is building the mechanism this outcome consumes... serialize behind it" | **Stale as a blocker.** Record 445 is CLOSED (archived, `[COMPLETED]`, 2026-11-10). The mechanism it built (Gate 8's three-way EXPECTED/NEW/clean verdict, `run-all.sh --fail-on-new`, `known-failures.txt`) is live now and was used directly in this report's own verification (Finding 4). |
| "expected exit 0 on the second (fresh) call, got 2" / "deploy_pending_reason='postflight completion-deploy gate refused...'" (postflight-deploy-gate survivors) | **Refuted by direct re-run.** `test-postflight-deploy-gate.sh` now reports 29 passed, 0 failed, standalone. The named cases pass. |

No other carried figure in the description was found to still hold without qualification; see
Findings 2-6 for the full picture.

### 2. All seven suites now pass standalone, with zero failures

Each suite was re-run directly in this dispatch (not inferred from any artifact):

| Suite | This dispatch's result | Report 01 / description's prior figure |
|---|---|---|
| `test-gate-cache-equivalence.sh` | 17 passed, 0 failed (~1190s wall, exceeds `run-all.sh`'s 600s per-suite bound -- see Finding 4) | Not explained by report 01's shared cause; previously `TIMEOUT`-prone per `known-failures.txt`'s `load-sensitive` row |
| `test-gate-lock.sh` | 16 passed, 0 failed (standalone) | Report 01: 16/0 (unchanged standalone; see Finding 4 for its NEW aggregate-only failure) |
| `test-orchestrate-cycle-postflight.sh` | 312 passed, 0 failed | Report 01: 279 passed, 25 failed. Task 568 independently confirmed 312/0 on 2026-11-16 via the same fix commit this report also found, `a4e32ff9e` |
| `test-orchestrate-predispatch-review.sh` | 37 passed, 0 failed | Report 01: 32 passed, 2 failed |
| `test-orchestrate-unwind-dispatch.sh` | 21 passed, 0 failed | Report 01: 10 passed, 11 failed |
| `test-postflight-deploy-gate.sh` | 29 passed, 0 failed | Report 01: 17 passed, 12 failed. Description's own later addendum: 5 failed |
| `test-redeploy-checkpoint-promotion.sh` | 17 passed, 0 failed | Report 01: 10 passed, 7 failed. Description's own later addendum: 3 failed |

Every suite's own `REQUIRED_LIBS`/`REQUIRED_LIB_SCRIPTS`/inline-copy list was also read directly
and confirmed to now include `project-number-inuse.sh` (`test-postflight-deploy-gate.sh` line
65, `test-redeploy-checkpoint-promotion.sh` line 88, `test-orchestrate-cycle-postflight.sh` lines
95-102, `test-orchestrate-predispatch-review.sh` lines 50-70,
`test-orchestrate-unwind-dispatch.sh` line 42) -- report 01's suggested remedy (Recommendation 1)
has already been applied to all five suites it named, by someone/something other than this
task's own dispatch history.

### 3. Who fixed it, and why this task's own dependency edges are now moot

- Commit `a4e32ff9e` ("core: clear batch-gate findings (gate8 suites, gate10 timeout, gate29
  lint)", 2026-11-15T23:22:04-08:00, session `sess_1794813716_d3a8cc`) is an `/orchestrate`
  conclusion-stage batch-fix commit, authored independently of this task. Its own message and
  `git show --stat` confirm it touched: `validate-state.sh` (the `--deep` artifact-loss check,
  59s -> 3s -- directly relevant to `test-gate-cache-equivalence.sh`'s `load-sensitive`
  classification, see Finding 4), `test-orchestrate-cycle-postflight.sh` (adds
  `project-number-inuse.sh` to its sandbox copy -- this is the same fix task 568 independently
  verified), `test-double-loading-check.sh`, `test-verify-deploy-context-budget.sh` ("fixture
  carries the hook identity module" -- see Finding 5 for why this did not fully resolve that
  suite), `suite-classification.data`, and `test-typescript-verify.sh`. It does **not** touch
  `test-orchestrate-predispatch-review.sh`, `test-orchestrate-unwind-dispatch.sh`,
  `test-postflight-deploy-gate.sh`, or `test-redeploy-checkpoint-promotion.sh` directly, yet all
  four now pass with the `project-number-inuse.sh` entry already present in their own
  allowlists -- meaning some other, not-yet-identified commit applied report 01's suggested
  remedy to those four suites between report 01 (2026-11-05) and now. This report did not
  chase that commit down further; it is not necessary for 476's own remaining obligations, and
  the fix's correctness is independently confirmed by this report's own direct re-run of all
  four suites at 0 failures.
- Task 568 ("Fix test-orchestrate-cycle-postflight.sh, which fails 25 of 304 assertions"),
  `[COMPLETED]` 2026-11-16, independently discovered the same `a4e32ff9e` fix already landed,
  re-verified 312/0, and closed with **no production change** of its own.
- Task 423 ("Fix verify-deploy context budget byte-count drift"), `[COMPLETED]` 2026-11-10,
  resolved the *eighth, excluded* suite's eager-load/baseline-drift case via a dated
  `orchestrator-context-budget.json` baseline move -- unrelated to, and not overlapping with,
  this task's own seven suites.
- Task 445 ("Give verify-deploy.sh's Gate 8 an expected-versus-NEW failure distinction"),
  `[COMPLETED]` 2026-11-10, is the mechanism outcome 4 named. Its own Follow-ups section
  explicitly lists all seven of this task's suites (plus `test-double-loading-check.sh` and
  `test-lint-unit-integration-boundary.sh`) as "7 NEW failures observed live in the corpus...
  outside this task's scope... left to... a future task" -- directly corroborating that 476 is
  the correct, and now only remaining, owner of this cluster.

**Conclusion for the plan phase**: neither declared dependency (423, 445) blocks this task any
longer. Both are closed, and the mechanism 445 built is directly usable now (demonstrated in
Finding 4's own use of `run-all.sh --fail-on-new`'s EXPECTED/NEW output).

### 4. A new, reproducible, concurrency-dependent flake in `test-gate-lock.sh`

Running the seven in-scope suites together via
`run-all.sh --only <the 7 basenames> --fail-on-new` (this report's own invocation, not inferred)
produced:

```
[run-all] Failing suites (2):
    .../test-gate-cache-equivalence.sh (EXPECTED)
    .../test-gate-lock.sh (NEW)
[run-all] 5 passed, 2 failed (1 expected, 1 NEW), 0 skipped, 7 total
```

- `test-gate-cache-equivalence.sh` was killed by `run-all.sh`'s own 600s per-suite
  `RUN_ALL_SUITE_TIMEOUT_S` bound inside this aggregate run (`TIMEOUT: ... exceeded the 600s
  per-suite bound and was killed`) -- correctly reported `EXPECTED`, matching its existing
  `known-failures.txt` row (`load-sensitive`, `needs-owner`). This is unchanged from report 01's
  own classification and requires no action from this task; its standalone 17/0 result (Finding
  2) at ~1190s wall time confirms the suite is genuinely slow by construction, not broken, and
  that the existing 600s bound is simply tighter than its true cost under any load.
- `test-gate-lock.sh` failed with **14 passed, 2 failed** in this exact aggregate run, despite
  16/0 standalone (Finding 2) -- i.e. it only fails when run concurrently with its file-scope
  siblings. This is a direct reproduction of outcome 5's own warning ("a suite fixed for host
  state may still be fighting a sibling") and is **not** declared anywhere in
  `known-failures.txt` (confirmed by reading the live file: no row for `test-gate-lock.sh`
  exists), so `run-all.sh --fail-on-new` correctly reports it `NEW`.

Both failing cases, read directly from `test-gate-lock.sh`'s own source (lines 248-297 and
340-382), are timing/host-load-coupled in the precise sense
`shell-script-testing.md`'s "## Ambient-host-state isolation" section names (a timing-axis
defect: "a suite passes on a quiet machine and fails on a busy one, and a busy machine is
exactly what this corpus's own `--jobs auto` parallel pool produces" -- that section's own
words, and an exact match for this reproduction):

1. **Case "killed holder (process-group teardown)"** (lines 248-283): launches a nested
   `verify-deploy.sh --only-gate 8 "$WORKDIR"` under `setsid`, then polls up to 3000ms (50ms
   increments) for BOTH the child's self-reported PID file and `$GATE_LOCK_DIR` to appear before
   it can send the `SIGTERM` that exercises the signal-scoped cleanup trap. Failure text
   observed: `could not observe both a self-reported pid and .../specs/.gate-lock held within
   the poll window; cannot exercise the signal path`. The 3000ms budget is plausible for a
   nested `verify-deploy.sh --only-gate 8` startup on an idle host but not necessarily under
   concurrent CPU contention from the other suites `run-all.sh`'s own parallel pool is running
   at the same time (this host measures `nproc` = 24, `JOBS_CAP` = 4, so up to 3 *other*
   suites' own subprocesses compete for CPU while this case's nested subprocess starts up).
2. **Case "fail-open (verify-deploy.sh Gate 8)"** (lines 373-381): runs the same nested
   `verify-deploy.sh --only-gate 8 "$WORKDIR"` in the foreground (no `setsid`) with a stubbed,
   always-failing `gate-acquire`, and expects `rc=0` plus a real `[PASS] run-all.sh: all
   discovered suites passed` line. Observed instead: `rc=1`, with
   `verify-deploy.sh`'s own Gate 8 reporting `run-all.sh reported failing or undiscoverable
   suites (exit 2)`. Exit 2 from `run-all.sh` (as opposed to exit 1, used for an ordinary suite
   failure) is a harness-level condition -- this report read `run-all.sh`'s own exit-2 call
   sites and the two plausible matches for an unfiltered run against this suite's own trivial
   fixture corpus are "zero test suites discovered" (line ~518) and the internal
   `TOTAL_ACCOUNTED != TOTAL_DISCOVERED` scheduling-safety assertion (line ~871). `VERIFY_DEPLOY_GATE8_JOBS`
   (the env seam `verify-deploy.sh` line 648 already documents, `GATE8_JOBS="${VERIFY_DEPLOY_GATE8_JOBS:-auto}"`)
   defaults to `auto`, which on this host resolves to a fixed `nproc`-capped value of 4
   (`nproc` = 24 > `JOBS_CAP` = 4) regardless of momentary load -- so the exit-2 trigger is not
   "auto resolves differently under load" but more likely a filesystem-visibility race in the
   fixture under contention, or cross-case pollution from the immediately-preceding
   process-group-teardown case's own backgrounded subprocess still winding down when this case
   starts. **This report did not fully isolate which of these two candidate mechanisms is the
   actual cause** -- that disambiguation is plan/implementation work, not something this
   research dispatch resolved.

Per the established convention's own decision order (seam-first for readable-input axes; for the
timing axis specifically: inject the clock/intercept the delay, then assert ordering/causality,
then widen the window only as a last resort with explicit justification): Case 1's 3000ms poll
window is the clearest candidate for the convention's rung-3 bounded-widening treatment (there is
no clock to inject and no alternative causal signal -- the test genuinely needs the lock held
before it can exercise the signal path), while Case 2 needs root-cause disambiguation first,
since "widen a window" is not an available remedy for a harness-level `exit 2` that is not itself
a poll/timeout.

**Classification (outcome 1 terms)**: class (a), ambient-host-state/timing leak into the
suite's own fixture/poll design -- ammunition for the plan phase, not a closed finding. Evidence:
reproduced directly in this dispatch (14/2 in the aggregate run vs. 16/0 standalone, with
`run-all.sh --fail-on-new` independently confirming `NEW`); not resolvable by the project-number
fixture-library fix (unrelated mechanism); matches the task-170 convention's own named defect
shape verbatim.

### 5. The excluded eighth suite's regression cannot be handed to 423 -- 423 is closed

Task 423 is `[COMPLETED]` (archived 2026-11-10) and its own summary states the suite's one
remaining residual failure is attributed to a **gate-24** `/ide`-recommendation finding against
`memory-setup.md`/`memory-troubleshooting.md` -- a documented, different cause from the
"fixture is not clean" symptom this dispatch's addendum reports. This report re-ran
`test-verify-deploy-context-budget.sh` directly, after 423's closure and after commit
`a4e32ff9e`'s own touch to this exact suite ("fixture carries the hook identity module"):

```
[FAIL] baseline fixture is not clean (rc=1, gate20 finding lines=0) -- fixture setup is broken; later cases are unreliable
  [FAIL] doc-lint reported failures
  [FAIL] manifest-driven verification reported 1 finding(s)
...
14 passed, 1 failed
```

This is the **same symptom**, reproducing verbatim, right now -- confirming the dispatch
addendum's own characterization was accurate and is not resolved by 423's closure or by
`a4e32ff9e`. Since `test-verify-deploy-context-budget.sh` is explicitly outside this task's
`file_scope` (by this task's own deliberate design, per the Description), this report does not
attempt a fix. Unlike the dispatch's own instruction ("HAND THIS OBSERVATION TO RECORD 423"),
423 cannot receive new findings -- it is archived. **This needs a new follow-up task**, not a
hand-off to a closed record; the plan/implementation phase (or the next `/orchestrate`
conclusion-stage proposal-audit pass, per the precedent this task's own `issues.jsonl` already
describes for a structurally identical situation involving task 418) should create one, naming
the "fixture setup is broken" / "gate20 finding lines=0" symptom and the fact that it survived
both 423's closure and `a4e32ff9e`'s targeted fix attempt.

### 6. A smaller, lower-priority finding: two stale `known-failures.txt` rows

`known-failures.txt` still carries a `real-defect`/`needs-owner` row for
`test-orchestrate-cycle-postflight.sh` describing the exact symptom task 568 and this report both
independently confirmed fixed (312/0, 0/0 relevant to that row's described cases). It also
carried an equivalent stale row for `test-lint-unit-integration-boundary.sh` (in this task's
`file_scope` though not in the Description's seven-suite list), which this report also re-ran
directly: 15 passed, 0 failed -- also green, also stale. Neither stale row causes Gate 8 to
report a false `[FAIL]` today (a declared-expected row that no longer fails is harmless to the
binary pass/fail signal), but a stale "already-known" row for a suite that has regressed again
in the future would mask a genuine new regression as an old, already-attributed one -- exactly
the failure mode this task's own motivation names. Removing both rows is in `file_scope`
(`run-all.sh`'s own territory covers its data file) and is a low-cost cleanup worth doing
alongside the `test-gate-lock.sh` fix.

## Decisions

- None. This dispatch is research-only; no file in `file_scope` was modified.

## Recommendations

1. Treat the five-suite fixture-completeness defect (report 01's finding) and the seven-suite
   remediation this task's Description still frames as outstanding as **already resolved**
   upstream -- do not re-apply report 01's suggested remedy; it is already present in all five
   suites (Finding 2). The plan phase should re-scope outcome 2 away from "fix the fixture
   allowlists" and toward verification + the two items below.
2. Diagnose and resolve `test-gate-lock.sh`'s aggregate-only flake (Finding 4) before closing
   this task: reproduce it again via `run-all.sh --only <the 7 suites> --fail-on-new` (this
   report's own command), then disambiguate Case 2's exact exit-2 cause (filesystem-visibility
   race vs. cross-case pollution vs. a genuine `run-all.sh` scheduling edge case) before choosing
   between a fix (widen Case 1's poll window per the established convention's rung-3, with
   explicit justification per that section's own requirement; isolate or serialize Case 2's
   fixture lifecycle) and a declared-expected `known-failures.txt` row. An undeclared,
   intermittent `NEW` failure in this exact suite is the condition this task exists to end.
3. Remove the two stale `known-failures.txt` rows named in Finding 6
   (`test-orchestrate-cycle-postflight.sh`, `test-lint-unit-integration-boundary.sh`) as part of
   this task's own `run-all.sh`-territory cleanup -- both suites are confirmed 0-failure by this
   report's own direct re-run, independent of the `test-gate-lock.sh` work in Recommendation 2.
4. Do not act on the excluded eighth suite's regression within this task (it remains correctly
   outside `file_scope`), but ensure a new task is created to own it rather than silently
   dropping the "hand this to 423" instruction now that 423 is closed (Finding 5). This report
   records the evidence; task creation itself is plan/postflight work, not research.
5. Before closing this task, run the **full, unscoped** Gate 8 battery
   (`scripts/tests/run-all.sh` with no `--only`, or `verify-deploy.sh --only-gate 8`) twice from
   a clean tree, per outcome 5's literal acceptance bar -- this report's own verification used a
   7-suite `--only` subset as a cheap concurrency smoke test (which is how Finding 4 was found)
   and `run-all.sh`'s own header comment is explicit that "a selected-subset pass is NOT evidence
   of a clean full run." The full run was not performed in this research dispatch; it is
   properly the implementation/verification phase's acceptance step, and a single full run of
   `test-gate-cache-equivalence.sh` alone costs roughly 20 minutes wall time, so budget
   accordingly (two full runs, run serially, is a substantial wall-clock cost worth planning for
   explicitly rather than discovering at verification time).

## Risks & Mitigations

- **Risk**: this report's own 7-suite `--only` aggregate run is itself not the full, unscoped
  Gate 8 battery outcome 5 requires, so a different concurrency interaction involving one of the
  ~140 other suites in the full corpus could still surface at full-battery verification time,
  beyond the `test-gate-lock.sh` flake already found. **Mitigation**: Recommendation 5 names this
  explicitly; the plan/implementation phase should not treat this report's partial aggregate run
  as a substitute for the full, twice-run acceptance check outcome 5 requires.
- **Risk**: this report could not fully isolate `test-gate-lock.sh` Case 2's exact root cause
  (filesystem-visibility race vs. cross-case pollution vs. a `run-all.sh` scheduling edge case)
  within this research dispatch's own time budget. **Mitigation**: Finding 4 names both candidate
  mechanisms and the exact log line/exit code to reproduce against, so the next dispatch does not
  need to re-derive the reproduction from scratch.
- **Risk**: the not-yet-identified commit that applied report 01's remedy to
  `test-orchestrate-predispatch-review.sh`, `test-orchestrate-unwind-dispatch.sh`,
  `test-postflight-deploy-gate.sh`, and `test-redeploy-checkpoint-promotion.sh` (Finding 3) was
  not traced to a specific `git log` entry in this report. **Mitigation**: this does not block
  any of this task's own outcomes -- the fix's correctness is independently confirmed by this
  report's own direct 0-failure re-run of all four suites, which is the evidence that matters,
  not the provenance of who applied it.

## Context Extension Recommendations

None -- this task's `task_type` is `meta` and the relevant convention
(`shell-script-testing.md`'s "## Ambient-host-state isolation" section) already documents the
timing-axis technique this report's Finding 4 applies; no gap in existing context documentation
was found.

## Appendix

### Search queries / commands used

- Direct suite execution: `bash <suite>.sh` for all seven in-scope suites, the excluded eighth
  suite, and `test-lint-unit-integration-boundary.sh` (standalone, sequential, this dispatch's
  own invocations)
- Aggregate concurrency smoke test: `bash agent-system/extensions/core/scripts/tests/run-all.sh --only test-gate-cache-equivalence.sh,test-gate-lock.sh,test-orchestrate-cycle-postflight.sh,test-orchestrate-predispatch-review.sh,test-orchestrate-unwind-dispatch.sh,test-postflight-deploy-gate.sh,test-redeploy-checkpoint-promotion.sh --fail-on-new`
- `jq`/`python3 -c` queries against `specs/state.json` for task 476's own record and for tasks
  423, 445, 428, 448, 415, 452, 568
- `find specs -maxdepth 1 -type d -iname "{423,445,428,448,415}_*"` (resolved to
  `specs/archive/...`), confirming vault archival rather than non-existence
- `git show --stat a4e32ff9e`, `git log -1 --format="%H %cI %s" a4e32ff9e`
- `grep -n "^## Ambient-host-state isolation" .../shell-script-testing.md` and the full section
  read (lines 429-571)

### References

- `specs/476_isolate_seven_red_gate8_shell_suites/reports/01_fixture-lib-allowlist-root-cause.md`
  (prior artifact; superseded in part by Finding 2)
- `specs/archive/423_fix_verify_deploy_context_budget_byte_count_drift/summaries/01_eager-baseline-move-and-row-rewrite-summary.md`
- `specs/archive/445_gate8_expected_vs_new_failure_distinction/summaries/01_gate8-expected-new-distinction-summary.md`
- `specs/archive/170_isolate_shell_suites_from_host_state/plans/01_ambient-host-state-isolation.md`,
  `reports/02_corpus-triage-ledger.md`
- `specs/568_repair_orchestrate_cycle_postflight_suite/summaries/01_*.md` (exact path: this
  task's own summary file under its `summaries/` directory)
- `specs/476_isolate_seven_red_gate8_shell_suites/issues.jsonl` entries `iss_1793834898116_52vQ3B`,
  `iss_1794024530957_554zlN`
- Commit `a4e32ff9eeac8a12d62d1784a185c489655afc4f`
- `agent-system/extensions/core/scripts/tests/test-gate-lock.sh` (lines 246-300, 340-382)
- `agent-system/extensions/core/scripts/tests/run-all.sh` (`--jobs auto` resolution,
  `RUN_ALL_SUITE_TIMEOUT_S`, exit-2 sites)
- `agent-system/extensions/core/scripts/verify-deploy.sh` (lines 645-648, 1247-1248, 1390-1391)
- `agent-system/extensions/core/context/standards/shell-script-testing.md` (lines 429-571,
  "## Ambient-host-state isolation")
