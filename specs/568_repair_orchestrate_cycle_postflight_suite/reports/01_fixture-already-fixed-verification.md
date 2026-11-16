# Research Report: Repair `test-orchestrate-cycle-postflight.sh`

- **Task**: 568 - Fix test-orchestrate-cycle-postflight.sh, which fails 25 of 304 assertions
- **Started**: 2026-11-15T23:30:00Z
- **Completed**: 2026-11-15T23:55:00Z
- **Effort**: ~25 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - Direct execution: `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
  - `git log` / `git show` on the suite file, `orchestrator-postflight.sh`, `update-task-status.sh`
  - `git show a4e32ff9e` (the commit that already patched the suite's fixture)
  - `specs/476_isolate_seven_red_gate8_shell_suites/reports/01_fixture-lib-allowlist-root-cause.md`
    (prior independent root-cause investigation naming this exact suite)
  - `agent-system/extensions/core/scripts/state-write.sh`,
    `agent-system/extensions/core/scripts/lib/project-number-inuse.sh`
- **Artifacts**: this report
- **Standards**: report-format.md, subagent-return.md, return-metadata-file.md

## Executive Summary

- The defect this task was dispatched to fix **no longer exists**. Direct execution of
  `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` in this
  dispatch produced `Results: 312 passed, 0 failed`, exit 0 — not 25 of 304 failing as the
  dispatch description states.
- The suite was already repaired by commit `a4e32ff9e` ("core: clear batch-gate findings (gate8
  suites, gate10 timeout, gate29 lint)"), committed 2026-11-15 23:22:04 -0800, which added
  `lib/project-number-inuse.sh` to this suite's `setup_sandbox()` library-copy list.
- Neither the suite's expectations nor the target scripts' behaviour (`orchestrator-postflight.sh`,
  `update-task-status.sh`) were wrong, per this task's own disposition instruction. The real
  defect was a **fixture-completeness gap in the test's own sandbox setup**: `state-write.sh` (a
  hard dependency the sandbox copies) unconditionally sources `lib/project-number-inuse.sh`, which
  the sandbox's library-copy list omitted. Every status write inside the fixture silently failed
  (`source: No such file or directory`, propagating to a non-zero exit), so the fixture's state.json
  never advanced past its prior status — producing exactly the status-name mismatches (expected
  `planning`, got `researching`) and `persisted_status` drift the dispatch description names.
- This root cause was independently discovered and documented by a prior, unrelated task's
  research report (`specs/476_.../reports/01_fixture-lib-allowlist-root-cause.md`, 2026-11-05),
  which named this exact suite among five sharing the identical mechanism and reproduced the
  identical 25-failure count with the identical stderr line. That report's Recommendation 1 (add
  `project-number-inuse.sh` to each affected suite's allowlist) is what commit `a4e32ff9e` applied.
- Recommendation: close this task with no further plan/implement phase. No code change is needed;
  the fix already landed on `master` through an unrelated task's conclusion-stage work.

## Context & Scope

This task's description asked the researcher to determine whether the suite's own expectations
(25 of 304 assertions, expecting `planning`/`researching` status values and `persisted_status`)
were wrong, or whether the real production scripts under test
(`orchestrator-postflight.sh`, `update-task-status.sh`) were behaving incorrectly, before any fix
is applied to either. The addendum further corroborated the 25-failure count via an independent
re-observation on 2026-11-10, and flagged a `cleanup: command not found` shell error worth
checking against the drift.

Scope for this dispatch: run the suite as it exists on `master` right now, trace why it was
reported red, and determine the correct classification (suite wrong vs. scripts wrong vs. neither)
before recommending or making any change.

## Findings

### 1. The suite currently passes in full

```
timeout 300 bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh
=> Results: 312 passed, 0 failed
=> exit 0
```

No `FAIL` lines, no `cleanup: command not found` shell error, and the suite's own trailing
byte-identity invariant (the real source-store `orchestrate-cycle-postflight.sh` is never written
by the fixture) and `*.anchor-bak` cleanliness invariant both passed. The addendum's
"cleanup: command not found" detail did not reproduce; it was most likely itself a downstream
symptom of the same sourcing failure (a function or variable defined inside the failed
`state-write.sh` sourcing never became available, so a later `cleanup` call in that failure path
was undefined) rather than an independent defect — consistent with report 476's description of
"cascading mismatches" from one shared failure point.

### 2. Root cause: a fixture-completeness gap, not a production-code or suite-expectation bug

`agent-system/extensions/core/scripts/state-write.sh` unconditionally sources
`lib/project-number-inuse.sh` (line 214: `source "${SCRIPT_DIR}/lib/project-number-inuse.sh"`).
This suite's `setup_sandbox()` copies `state-write.sh` into an isolated fixture repo (per the
suite's own header comment, it copies every real collaborator unmodified so the suite exercises
the real call graph) but, before commit `a4e32ff9e`, its library-copy list omitted
`project-number-inuse.sh`:

```
for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh \
         phase-heading-patterns.sh status-vocabulary.sh task-lookup-lib.sh deploy-freshness-lib.sh \
         derived-artifact-probe-lib.sh engine-written-state-paths-lib.sh \
         return-meta-status-vocabulary.sh runtime-file-patterns.sh return-meta-artifacts-lib.sh; do
```

Inside the fixture, `state-write.sh`'s `source` line failed with `No such file or directory`
(bash's own `set -e`/plain-`source` failure mode), so every status transition inside the fixture
silently did not persist: the fixture's state.json stayed at its prior status while the dispatch's
own return/verdict logic still reported success upstream of the write. This exactly reproduces
both symptom classes the dispatch description names:
- **status-name mismatches** — a case asserting the fixture reached `planning` instead observed
  the fixture's prior status, `researching` (the write that should have advanced it never landed).
- **`persisted_status` drift** — assertions reading `persisted_status` out of the written
  state file saw the stale, pre-transition value for the same reason.

`project-number-inuse.sh` is a *recently added* library: `git log --diff-filter=A` on that file
shows it was introduced by a single commit, `ab6aaf8c8`, dated 2026-11-03 — after this suite's
own library-copy list was last written, which is why the gap existed and why it is a staleness
gap in the fixture, not a defect anyone wrote deliberately.

### 3. Independent corroboration from a prior, unrelated task

`specs/476_isolate_seven_red_gate8_shell_suites/reports/01_fixture-lib-allowlist-root-cause.md`
(2026-11-05), dispatched for an unrelated purpose (classifying seven red Gate 8 shell suites),
independently reproduced this exact suite standalone and reported the **identical count**: "279
passed, 25 failed" with the **identical stderr line**
(`.../state-write.sh: line 214: .../lib/project-number-inuse.sh: No such file or directory`) and
the **identical symptom shape** (`expected state.json status=planned, got: planning`; `expected
persisted_status='completed', got: ... "implementing"`). That report's total (279+25=304) matches
this task's own dispatch description's denominator (304) exactly, confirming both records
describe the same suite state at the same assertion count, from two independent investigations.

Report 476 explicitly classified this as a **fixture-completeness defect in the suite's own setup
code — not a defect in the code under test** (its Executive Summary, verbatim), and offered,
as its unapplied Recommendation 1, adding `project-number-inuse.sh` to the suite's library
allowlist.

### 4. The fix already landed, via a different task's conclusion-stage work

Commit `a4e32ff9e` ("core: clear batch-gate findings (gate8 suites, gate10 timeout, gate29 lint)"),
committed 2026-11-15 23:22:04 -0800 — this session's own `git status` "Recent commits" already
lists it — applied exactly report 476's Recommendation 1 to this suite:

```diff
+  # project-number-inuse.sh is a HARD dependency of state-write.sh (a plain `source` under
+  # `set -e`): omitting it makes every state write exit non-zero, so a status transition silently
+  # fails to persist while the dispatch verdict still reads ok.
   for f in common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh \
            phase-heading-patterns.sh status-vocabulary.sh task-lookup-lib.sh deploy-freshness-lib.sh \
            derived-artifact-probe-lib.sh engine-written-state-paths-lib.sh \
-           return-meta-status-vocabulary.sh runtime-file-patterns.sh return-meta-artifacts-lib.sh; do
+           return-meta-status-vocabulary.sh runtime-file-patterns.sh return-meta-artifacts-lib.sh \
+           project-number-inuse.sh; do
```

That commit's own inline comment states the same mechanism this report independently confirmed
by direct execution: the hard-dependency sourcing failure under `set -e`, silently swallowed by
the dispatch verdict logic. This task's own `git log -- .../test-orchestrate-cycle-postflight.sh`
confirms `a4e32ff9e` is the most recent commit touching the file, and no other pending change
exists.

### 5. Deploy-store consistency

The source-store copy (`agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`)
and the deployed copy (`.claude/scripts/tests/test-orchestrate-cycle-postflight.sh`) are
byte-identical (`diff -q` exit 0), as are the two copies of the script under test
(`orchestrate-cycle-postflight.sh`). The dispatch's deploy-freshness warning for the `core`
extension does not implicate either file for this task's purposes.

## Decisions

- **Classification**: neither the suite's expectations nor the target scripts'
  (`orchestrator-postflight.sh`, `update-task-status.sh`) behaviour was wrong. The defect was a
  **fixture setup omission** (a missing library copy in the suite's own `setup_sandbox()`),
  already fixed and verified green by direct execution in this dispatch.
- **No plan or implementation phase is warranted.** The code change this task would otherwise
  have produced already exists on `master`, applied by an unrelated task's conclusion-stage
  commit. Re-applying it would be a no-op; re-deriving a different fix risks diverging from the
  now-landed, verified-correct one.

## Recommendations

1. Close this task directly from research, with no plan/implement dispatch, citing the verified
   312-passed/0-failed re-run and commit `a4e32ff9e` as the closing evidence.
2. No code, test, or configuration change is recommended — none is needed.

## Risks & Mitigations

- **Risk**: a future `source` line added to a script this (or any) sandbox-copying suite mirrors
  could reintroduce the same class of silent-failure fixture gap (report 476's own
  Recommendation 2 named this as the durable structural weakness: a hand-maintained library
  allowlist rots every time a copied script gains a new `source` line). **Mitigation**: out of
  this task's scope (this task's scope is the specific suite named in its description, now
  verified green); report 476's Recommendation 2 (deriving each fixture's required-library set
  mechanically, or adding a fixture self-check) remains open and un-owned if a future task wants
  to pick it up.
- **Risk**: this report's finding depends on a single direct execution in this dispatch's own
  sandboxed environment. **Mitigation**: the result is corroborated by an independent,
  differently-motivated investigation (report 476) that reproduced the identical failure
  signature and count before the fix, and by the fix commit's own explicit before/after diff,
  so the finding rests on two independent observations plus the literal patch, not one run alone.

## Context Extension Recommendations

None. This is a verification-only finding about a specific test suite's current (already-fixed)
state; no new durable documentation gap was identified.

## Appendix

- Search/verification commands:
  - `timeout 300 bash agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
  - `git log --oneline -10 -- agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
  - `git show a4e32ff9e -- agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
  - `diff -q` between source-store and deployed copies of the suite and the script under test
- References:
  - Commit `a4e32ff9eeac8a12d62d1784a185c489655afc4f` — the landed fix
  - Commit `ab6aaf8c8ef0270f79cf003d4b020ec0a1c394e6` — introduced `lib/project-number-inuse.sh`
  - `specs/476_isolate_seven_red_gate8_shell_suites/reports/01_fixture-lib-allowlist-root-cause.md`
    — independent prior root-cause corroboration naming this exact suite, same mechanism, same
    25-failure count
  - `agent-system/extensions/core/scripts/state-write.sh` (line 214)
  - `agent-system/extensions/core/scripts/lib/project-number-inuse.sh`
