# Phase 1 Probe Transcripts and Baseline

Recorded verbatim at implementation time, per Phase 1's own tasks. Cited as acceptance evidence
by the Phase 6 summary.

## Gate 6 Baseline

```
$ bash agent-system/extensions/core/scripts/lint/lint-agent-contracts.sh --verbose
...
========================================
Summary
========================================
Passed:   344
Warnings: 13
Failed:   0

AGENT CONTRACTS LINT PASSED WITH WARNINGS
```

Confirmed: Check K currently *skips* both lean implementation agents as a recorded exclusion
("domain-adapted lake-build-guard.sh background path") and *PASSes* both lean research agents
on merit ("no unguarded detach-then-await-a-notification pairing found"). Matches the plan's
expectation of 0 FAILs, ~13 warnings.

## Probe A: child survival across Bash call boundaries

Call 1 (launch):
```
$ sleep 90 >log 2>&1 & echo $! > pidfile
launched pid=1924959
```

Call 2 (separate Bash tool invocation, liveness check):
```
$ pid=$(cat pidfile); kill -0 "$pid" 2>/dev/null && echo alive || echo gone
PROBE A RESULT: bare '&' child SURVIVES across separate Bash tool calls (pid 1924959 still alive)
    PID    PPID CMD
1924959    2614 sleep 90
```

**Result**: a bare `&`-backgrounded child survives past the launching Bash tool call's own
return — no `nohup`/`setsid` substitution is required. This confirms `bounded-build-waiter.md`'s
idiom (`cmd >log 2>&1 & pid=$!`) is usable as written in this environment.

Cleaned up (`kill "$pid"`) rather than letting the full 90s elapse.

## Probe B: single-call bounded wait returns control

Case 1 — writer outlives the inner `timeout`:
```
$ sleep 20 >log 2>&1 & pid=$!
$ timeout 3 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 0.5; done' _ "$pid"
inner timeout exit code: 124
writer still alive after inner timeout (as expected)
```

Case 2 — writer finishes before the inner `timeout`:
```
$ ( sleep 2; echo done >donefile; exit 7 ) >log 2>&1 & pid=$!
$ timeout 10 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 0.3; done' _ "$pid"
$ wait "$pid"; writer_rc=$?
inner timeout exit code (liveness loop): 0
writer exit code (via wait): 7
done
```

**Result**: in both cases the single Bash call returns control to the agent — case 1 with
`exit 124` from the inner `timeout` (the writer is still alive; the dispatch would loop again or
decide per `bounded-build-waiter.md`'s deadline rules), case 2 with a clean `exit 0` from the
liveness loop and the writer's own exit status (`7`) correctly readable via `wait`. Neither case
hangs, and neither is silently auto-backgrounded by the harness (both returned within the same
tool call that launched them).

## Probe C: replayed guard invocation

Fixture reproduced standalone in the scratch directory (outside
`test-lake-build-guard.sh`'s own harness), confirming this plan's Scope Hypothesis — the
fixture's `build_fixture()` shape (`bin/lake` driven by `FAKE_LAKE_SLEEP`/`FAKE_LAKE_EXIT`/
`FAKE_LAKE_OUT`/`FAKE_LAKE_ERR`) is reproducible without the suite's own `pass()`/`fail()`
scaffolding.

Single-Bash-call guard invocation under the new idiom:
```
$ export PATH="$PWD/bin:$PATH" FAKE_LAKE_SLEEP=6 FAKE_LAKE_EXIT=0 FAKE_LAKE_OUT="build ok single-call"
$ bash .../lake-build-guard.sh build --dir "$PWD" --timeout 1800 -- build > guard.log 2>&1 &
$ pid=$!
$ timeout 20 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 0.5; done' _ "$pid"
$ wait "$pid"; GUARD_EXIT=$?
liveness-loop exit: 0
GUARD_EXIT (captured un-piped, same-call wait): 0
--- guard.log ---
lake-build-guard: REPLAY: sharing result from holder pid 1930355, age 15s, recorded exit status 0
build ok single-call
STDERR_MARKER
```

**Result**: the single Bash call returns control once the detached guard process exits; its exit
code is captured un-piped (`wait "$pid"; GUARD_EXIT=$?`, inside the same call that launched it —
`wait` across separate Bash tool calls does not work, since each call is a distinct shell and the
PID is not that shell's own child; this is itself evidence for why the idiom must be ONE call,
not a `wait` issued later), and the verdict is readable from the captured log stream
(`exit_status=0`). The guard's own result-sharing cache replayed the prior invocation's result
(consistent with `test-lake-build-guard.sh`'s documented behavior for a reused, unchanged
fixture) rather than re-invoking `lake` — a second, independent confirmation that
`lake-build-guard.sh build` already blocks synchronously in the invoking shell and needs no new
blocking-mode addition (Finding 4).

## Explicit non-test statement (lean's livelock rationale)

Lean's livelock rationale (a killed `lake build` caches no `.olean`, so a retried build restarts
at the same module and can livelock) is **upheld as written and not re-tested here** — no long
Lean build exists in this repository to test it against. The fix in this task is therefore
designed to **preserve detachment** (shell-level backgrounding of the guard invocation) rather
than remove it, replacing only the wait step with the bounded single-call idiom confirmed by
Probes A-C above.
