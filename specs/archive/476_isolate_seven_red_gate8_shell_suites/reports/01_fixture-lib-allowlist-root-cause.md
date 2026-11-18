# Research Report: Fixture Library-Allowlist Root Cause for the Gate 8 Red Suites

- **Task**: 476 - Make the seven untracked red Gate 8 shell suites green or declared-expected
- **Started**: 2026-11-05T18:40:00Z
- **Completed**: 2026-11-05T19:05:00Z
- **Effort**: ~25 minutes
- **Dependencies**: None
- **Sources/Inputs**:
  - `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh`
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh`
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh`
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh`
  - `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh`
  - `agent-system/extensions/core/scripts/tests/test-gate-lock.sh`
  - `agent-system/extensions/core/scripts/tests/known-failures.txt`
  - `agent-system/extensions/core/scripts/state-write.sh`
  - `agent-system/extensions/core/scripts/lib/project-number-inuse.sh`
  - `specs/476_isolate_seven_red_gate8_shell_suites/issues.jsonl`
  - `git log --diff-filter=A` for `lib/project-number-inuse.sh`
  - Direct isolated execution of five suites and a minimal manual fixture reproduction
- **Artifacts**: this report
- **Standards**: status-markers.md, artifact-management.md, tasks.md, report-format.md

## Executive Summary

- Five of record 476's seven named suites fail for one shared, verified reason: their fixture
  builders copy `state-write.sh` into an isolated fixture repo but omit
  `lib/project-number-inuse.sh` from their hardcoded library allowlist. `state-write.sh` sources
  that library unconditionally; inside the fixture the `source` fails with "No such file or
  directory", the under-test transition never completes, and the suite's cases report cascading
  mismatches (`expected exit 0, got 2`, `expected status 'completed', got 'implementing'`, and
  related downstream assertion failures).
- This is a class (a)/(b) fixture-completeness defect in each suite's own setup code — not a
  defect in the code under test, and not host-state or timing noise. It reproduces
  deterministically, confirmed independently in this dispatch for all five suites.
- `lib/project-number-inuse.sh` was introduced by commit `ab6aaf8c8` ("scripts: add shared
  project-number in-use definition library"), dated 2026-11-03T12:11:58-08:00 — after each
  affected suite's allowlist was last written, which is why the gap exists.
- The remaining two of the seven are NOT explained by this root cause:
  - `test-gate-cache-equivalence.sh` is already declared `load-sensitive` in
    `known-failures.txt`, with a timeout-vs-host-load explanation unrelated to any fixture
    allowlist.
  - `test-gate-lock.sh` passed 16/16 standalone in this dispatch; its Gate 8 failure is not a
    fixture-completeness defect. A separate `issues.jsonl` entry for this task records that its
    underlying cause (a `specs/.gate-lock` mutex leak on signal kill) was already fixed by an
    earlier, unrelated conclusion-stage commit in this task's history, which is consistent with
    a standalone pass and points to nesting/concurrency/signal-timing as the real original
    failure mode rather than fixture completeness.
- Suggested remedy (not applied): add `project-number-inuse.sh` to each affected suite's
  library allowlist. The durable weakness worth fixing is structural: a hardcoded lib allowlist
  silently rots every time a copied script gains a new `source` line; deriving the closure of
  needed libraries, or asserting the fixture's copied library set is complete, would prevent
  recurrence.

## Context & Scope

Record 476 asks its implementer, as required outcome 1, to classify each of its seven named
failing Gate 8 shell suites into one of four failure classes with evidence. This report supplies
that classification for five of the seven (shared fixture-completeness defect) and reports
findings for the remaining two (neither of which shares that cause). No code, test, or script
was modified in this dispatch; every claim below was independently verified by reading the named
source files and by direct execution, as recorded per finding.

## Findings

### 1. The shared mechanism (verified against `test-postflight-deploy-gate.sh`)

`agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` builds an isolated
fixture repo via `build_fixture_repo()` (line 101), which copies a hardcoded set of scripts and
libraries from the real deployed `.claude/scripts/` tree:

- `REQUIRED_SCRIPTS` (line 75): `state-write.sh task-lock.sh generate-todo.sh
  generate-task-order.sh update-plan-status.sh update-phase-status.sh deploy-root-guard.sh`
- `REQUIRED_LIBS` (line 83): `common.sh phase-heading-patterns.sh status-vocabulary.sh
  file-scope-overlap.sh task-lookup-lib.sh`

`agent-system/extensions/core/scripts/state-write.sh` sources `lib/project-number-inuse.sh`
unconditionally at line 214:

```
source "${SCRIPT_DIR}/lib/project-number-inuse.sh"
```

`project-number-inuse.sh` is not in `REQUIRED_LIBS`, so the fixture copies `state-write.sh`
without a library it needs at runtime.

**Reproduction (this dispatch)**: running
`bash agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` in isolation
produced `Results: 17 passed, 12 failed`, with failures of exactly the described shape:

```
[FAIL] overlap+fresh expected exit 0, got 2 (see /tmp/.../c2.err)
[FAIL] overlap+fresh expected status 'completed', got 'implementing'
```

A minimal manual reproduction (copying only `state-write.sh` and `lib/common.sh` into a fresh
scratch directory and invoking the script directly) isolated the mechanism precisely:

```
.../state-write.sh: line 214: .../lib/project-number-inuse.sh: No such file or directory
```

exiting 1. `update-task-status.sh`'s own wrapping of this failure produces the suite's observed
exit 2.

**Origin**: `git log --diff-filter=A -- agent-system/extensions/core/scripts/lib/project-number-inuse.sh`
shows exactly one commit adding the file: `ab6aaf8c8ef0270f79cf003d4b020ec0a1c394e6`, "scripts:
add shared project-number in-use definition library", 2026-11-03T12:11:58-08:00. Each affected
suite's allowlist predates this commit and was never updated afterward.

### 2. Per-suite verification of the shared mechanism

Each of the following was read directly and, where its fixture mechanism matched, re-run
standalone in this dispatch to confirm the failure signature actually reproduces (not merely
that the allowlist is theoretically missing an entry).

| Suite | Shares the mechanism? | Evidence |
|---|---|---|
| `test-postflight-deploy-gate.sh` | Yes | `REQUIRED_SCRIPTS` includes `state-write.sh`; `REQUIRED_LIBS` (byte-identical list of 5 libs quoted above) omits `project-number-inuse.sh`. Reproduced: 17 passed, 12 failed, with the exact `No such file or directory` / `expected exit 0, got 2` signature. |
| `test-redeploy-checkpoint-promotion.sh` | Yes | Lines 98/106 declare the identical `REQUIRED_SCRIPTS`/`REQUIRED_LIBS` arrays as `test-postflight-deploy-gate.sh` (same 5-library list, same omission). Its fixture copies `UTS_SRC` (`update-task-status.sh`) into the fixture, which in turn invokes `state-write.sh`. Reproduced standalone: 10 passed, 7 failed, with `expected status 'completed' for project 1, got 'implementing'` and `expected deploy_pending=false ..., got 'true'` — the same stuck-at-intermediate-status signature produced when `state-write.sh`'s sourcing fails partway through a transition. |
| `test-orchestrate-cycle-postflight.sh` | Yes | Its `setup_sandbox()` copies `state-write.sh` into the fixture (listed explicitly among the required scripts) and copies a 12-entry library set (`common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh phase-heading-patterns.sh status-vocabulary.sh task-lookup-lib.sh deploy-freshness-lib.sh derived-artifact-probe-lib.sh engine-written-state-paths-lib.sh return-meta-status-vocabulary.sh return-meta-artifacts-lib.sh`) that does not include `project-number-inuse.sh` anywhere in the file (confirmed by `grep -n project-number-inuse`: no match). Reproduced standalone: 279 passed, 25 failed; stderr captured the literal line `.../state-write.sh: line 214: .../lib/project-number-inuse.sh: No such file or directory`, and multiple failures show the same stuck-at-intermediate-status shape (e.g. `expected state.json status=planned, got: planning`, `expected persisted_status='completed', got: ... "persisted_status":"implementing"`). |
| `test-orchestrate-predispatch-review.sh` | Yes | Copies `state-write.sh` (and `task-lock.sh`) into the fixture but only copies 3 libraries (`common.sh`, `task-lookup-lib.sh`, `file-scope-overlap.sh`) — `project-number-inuse.sh` is not among them. Reproduced standalone: 32 passed, 2 failed; the failing case's own captured stderr reads `.../state-write.sh: line 214: .../lib/project-number-inuse.sh: No such file or directory`, verbatim. |
| `test-orchestrate-unwind-dispatch.sh` | Yes | Declares `REQUIRED_CORE_SCRIPTS` (includes `state-write.sh`) and `REQUIRED_LIB_SCRIPTS` (13 libraries: `common.sh file-scope-overlap.sh continuation-pointer-lib.sh manifest-routing-lib.sh phase-heading-patterns.sh deploy-baseline-lib.sh task-lookup-lib.sh status-vocabulary.sh deploy-ledger-lib.sh runtime-file-patterns.sh territory-contention-lib.sh task-classification-lib.sh redeploy-checkpoint-lib.sh`), again omitting `project-number-inuse.sh`. Reproduced standalone: 10 passed, 11 failed; Case 1's failure message embeds the identical `.../state-write.sh: line 214: .../lib/project-number-inuse.sh: No such file or directory` line, and the suite's later cases (4, 5) cascade-fail because Case 1's setup never completed. |

All five suites were independently confirmed to fail with this mechanism in this dispatch, not
merely inferred from reading the allowlists.

### 3. The two suites NOT explained by this root cause

- **`test-gate-cache-equivalence.sh`**: already declared in
  `agent-system/extensions/core/scripts/tests/known-failures.txt` with category
  `load-sensitive`. The recorded explanation there is that Part 0's cold-baseline case invokes
  gate10 (`validate-state.sh --deep`) inside a fresh `git worktree` fixture against the real
  repo's `specs/state.json`, and gate10's 30s timeout was observed exceeded independent of other
  concurrent dispatches — attributed to a harness-level timeout-vs-load interaction, not a
  suite-code or fixture-completeness defect, and not related to `state-write.sh` or
  `project-number-inuse.sh` at all. This suite is out of scope for the fixture-allowlist fix.
- **`test-gate-lock.sh`**: re-run standalone in this dispatch —
  `bash agent-system/extensions/core/scripts/tests/test-gate-lock.sh` — produced `Results: 16
  passed, 0 failed`, exit 0. It does not reproduce as a standalone failure, so its appearance as
  red under Gate 8's aggregate run is not a fixture-completeness defect of this kind; it points
  instead to a nesting, concurrency, or signal-timing artifact specific to the aggregate
  run context. This task's own `issues.jsonl` (entry `iss_1793834898116_52vQ3B`) separately
  records that the suite's true root cause — a `specs/.gate-lock` mutex left held when a holder
  is killed by a signal mid-run — had already been fixed by an unrelated conclusion-stage
  commit, `7421bdceb` ("meta: release specs/.gate-lock on signal, thread withheld gate findings
  into re-dispatch"), confirmed to exist via `git show --stat 7421bdceb`. That commit predates
  this report and is independent of the fixture-library-allowlist issue described above.

### 4. Additional context: the eight-finding Gate 8 set

The dispatch instructions for this report state that these seven suites, plus
`test-verify-deploy-context-budget.sh`, were re-confirmed as the complete Gate 8 finding set by
a full `verify-deploy.sh` run at 2026-11-05T18:24:04Z, in which all 26 gates passed individually
and Gate 8's aggregate `run-all.sh` exit was the sole failure.

- 2026-11-05T18:24:04Z verify-deploy.sh run, "all 26 gates passed individually, Gate 8 aggregate
  sole failure" [CARRIED-UNVERIFIED: this report's own dispatch instructions; no corresponding
  entry was found in `specs/events.jsonl` or elsewhere in the repository by this dispatch's own
  search]. This report could not independently verify the specific run or timestamp and records
  it only as reported context, not as a self-verified finding.
- `test-verify-deploy-context-budget.sh` is owned by a separate open record and is outside 476's
  declared scope; it is mentioned here only as the already-excluded eighth member of that set,
  per the dispatching instructions. This report did not investigate it further.
- This task's own `issues.jsonl` (entry `iss_1793834898116_52vQ3B`, timestamp
  2026-11-04T23:28:18Z, phase `conclusion`) independently corroborates most of the above: it
  records that, prior to this report, five suites (`test-orchestrate-cycle-postflight.sh`,
  `test-orchestrate-predispatch-review.sh`, `test-orchestrate-unwind-dispatch.sh`,
  `test-postflight-deploy-gate.sh`, `test-redeploy-checkpoint-promotion.sh`) were "proven to fail
  identically on unmodified master via `git stash push`", and that `test-gate-cache-equivalence.sh`
  plus `test-verify-deploy-context-budget.sh` are "already EXPECTED-baselined by `run-all.sh`
  itself." It also records that `test-gate-lock.sh` had already been fixed and verified green
  (16 passed, 0 failed) by an earlier dispatch in this task's own history — consistent with this
  report's own independent 16/16 re-run above — and that the task's true remaining red count is
  therefore six, not seven, though `test-gate-lock.sh` is deliberately retained in the task's
  `file_scope` for serialization-safety reasons unrelated to classification.

## Decisions

- None. This dispatch is record-only; no remedy was applied.

## Recommendations

1. For the five suites in Finding 2, add `project-number-inuse.sh` to each suite's hardcoded
   library allowlist (`REQUIRED_LIBS`, `REQUIRED_LIB_SCRIPTS`, or the suite's equivalent
   inline-copied library list) so the fixture's copy of `state-write.sh` has every library it
   sources. This is a suggestion for 476's implementer, not applied in this dispatch.
2. Consider a structural fix beyond the immediate five-suite patch: derive each fixture's
   required-library set mechanically from `state-write.sh`'s (and any other copied script's)
   actual `source` lines, or add a fixture self-check that fails loudly if a copied script's
   `source` targets are not all present in the fixture, rather than relying on a hand-maintained
   allowlist that silently rots on every new `source` line added to a copied script.
3. Treat `test-gate-cache-equivalence.sh` and `test-gate-lock.sh` separately from the five above:
   neither is fixed by the `project-number-inuse.sh` addition. `test-gate-cache-equivalence.sh`'s
   `load-sensitive` classification already stands; `test-gate-lock.sh`'s Gate 8 failure, given it
   passes standalone and its known underlying cause was already fixed separately, likely warrants
   re-confirming against a fresh full `verify-deploy.sh`/Gate 8 run before further investigation,
   since it may no longer reproduce at all.

## Risks & Mitigations

- **Risk**: applying the suggested remedy (adding one library name to five allowlists) without
  also addressing the structural weakness in Recommendation 2 leaves the same class of defect
  free to recur the next time a copied script gains a new `source` line. **Mitigation**:
  Recommendation 2 is offered specifically to close this recurrence path; it is a suggestion, not
  applied here.
- **Risk**: the carried claim in Finding 4 (the 2026-11-05T18:24:04Z full `verify-deploy.sh` run)
  is unverified by this report and could be inaccurate or stale. **Mitigation**: marked
  `CARRIED-UNVERIFIED` above; 476's implementer should re-run `verify-deploy.sh` directly before
  relying on that specific run's figures.

## Appendix

- References:
  - `agent-system/extensions/core/scripts/tests/test-postflight-deploy-gate.sh` (lines 75, 83, 101)
  - `agent-system/extensions/core/scripts/tests/test-redeploy-checkpoint-promotion.sh` (lines 98, 106)
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-cycle-postflight.sh` (lines 34-44)
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-predispatch-review.sh` (lines 38-66)
  - `agent-system/extensions/core/scripts/tests/test-orchestrate-unwind-dispatch.sh` (lines 31-43)
  - `agent-system/extensions/core/scripts/tests/test-gate-lock.sh`
  - `agent-system/extensions/core/scripts/tests/known-failures.txt`
  - `agent-system/extensions/core/scripts/state-write.sh` (line 214)
  - `agent-system/extensions/core/scripts/lib/project-number-inuse.sh`
  - `specs/476_isolate_seven_red_gate8_shell_suites/issues.jsonl` (entry `iss_1793834898116_52vQ3B`)
  - Commits: `ab6aaf8c8ef0270f79cf003d4b020ec0a1c394e6` (adds `project-number-inuse.sh`),
    `7421bdceb65c8323606e816a72bdb4f98f9b47d1` (unrelated prior fix for `test-gate-lock.sh`'s
    mutex-leak-on-signal cause)
