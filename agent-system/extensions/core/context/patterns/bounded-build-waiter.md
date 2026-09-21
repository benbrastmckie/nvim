# Bounded-Build-Waiter Discipline

**Created**: 2026-09-21
**Purpose**: State, once and canonically, the defect class produced when a dispatched agent
blocks on a detached local command with no bounded, PID-keyed waiter, and define the sanctioned
waiter idiom that avoids it.
**Audience**: Any dispatched agent that detaches a local command (a build, a gate script, a test
run) and must block on it within the same dispatch. This is explicitly not Lean-only — the
defect and the fix generalize to any detached local process with a local log file or PID.
**Related**: `external-process-wait.md`, `dispatch-report-not-termination.md`,
`anti-stop-patterns.md`, `../contracts/wrap-up.md`,
`../../../lean/context/project/lean4/operations/long-builds.md`

---

## The Defect

A poll loop whose exit condition is a sentinel written by a process that may die first has no
bounded termination. A liveness test keyed on a process **name** is self-referential whenever the
polling shell's own argv contains the pattern being searched for — the search matches the search,
not the thing being searched for.

Three repositories hit this gap, in three different shapes:

1. **The sentinel poll.** A wrapper of the form `cmd > log 2>&1; echo "EXIT=$?" >> log` was
   watched by `until grep -q "^EXIT=" log; do sleep ...; done`. When the guarded command was
   cancelled or superseded by lock contention with a concurrent session, the `echo` never ran, so
   the sentinel became unwritable by construction. 22 such loops watched one log file (2 more
   watched a second), aged 24-55 minutes, at 0% CPU — background-shell-slot exhaustion and
   operator confusion, not throughput cost.
2. **The turn-ending stop.** Rather than spin a poll loop, a dispatch simply ended its turn,
   reporting reasons like "waiting for lake build" or "Monitor is already watching." Ending the
   turn ends the dispatch, so this costs a full re-dispatch cycle rather than a background-shell
   slot — see "Two Symptoms, One Missing Affordance" below.
3. **The name-match self-match.** A gate script was launched and awaited in one Bash call:
   `nohup timeout 3000 ... check.sh > log 2>&1 & disown; until ! ps aux | grep -q "[b]ash
   check.sh"; do sleep 8; done`. The `[b]` bracket trick only stops `grep` from matching itself —
   the waiting shell's own command line still contains the literal text `bash check.sh` (it is the
   shell that launched the gate), so the poll matched its own shell forever. The gate finished
   within seconds; the agent sat idle for roughly 13 minutes across five recurrences until an
   operator killed the waiter by hand.

## Two Symptoms, One Missing Affordance

Symptoms 1 and 2 above are the same missing affordance expressed two ways. An agent told to
detach a local command, with no sanctioned way to block on it, has exactly two bad options: poll
an unbounded, possibly-unwritable sentinel forever, or end the turn and hand the dispatch back
unfinished. This file is the missing affordance that removes both options. The explicit
prohibition against ending a turn on an unresolved background wait — and any postflight detection
of a stop lacking a handoff or `.return-meta.json` — belongs at the agent-contract layer, not
here; this file states only the waiter model both symptoms are missing.

## Required Rules

1. **Hard timeout.** Wrap the wait in `timeout N` so the waiter cannot outlive its writer. Size
   `N` to the command's expected run time, within whatever the calling tool allows. This is a
   *wait-duration* bound on the waiter itself — distinct from a lock-acquisition budget such as
   `lake-build-guard.sh --timeout`, which bounds how long the guard waits to acquire a lock, not
   how long the underlying command may run.
2. **Writer liveness by captured PID, never by name.** Capture the writer's PID at launch
   (`pid=$!`) and test liveness with `kill -0 "$pid"`. Never use `ps | grep`, `pgrep -f`, or any
   process-name-matching test — the polling shell's own argv can contain the same text as the
   command it is searching for, producing a self-match that never resolves (symptom 3 above).
   Never poll a sentinel file alone, with no liveness check backing it (symptom 1 above).
3. **A dead writer ends the wait immediately.** The instant `kill -0 "$pid"` fails, the wait is
   over — read the log or exit status at that point. Treat a missing sentinel as "the writer
   died," never as "keep waiting."
4. **One waiter per log.** Before starting a waiter, check whether one already exists for the
   same log or PID. A second would-be waiter either attaches — waiting on the same recorded PID,
   never spinning a second independent loop — or fails loudly, naming the existing waiter. It must
   never silently stop and hand the turn back (symptom 2 above). A superseded build's waiter is
   reaped before a replacement waiter is spawned.

## The Canonical Idiom

```bash
cmd >log 2>&1 & pid=$!
timeout 3000 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"
```

Prefer the simpler foreground form, `timeout 3000 cmd`, whenever the command fits within the
calling tool's own timeout limit — reach for the detach-plus-waiter shape only when it does not.

To read the outcome once the wait ends, either `wait "$pid"` in the same shell that captured
`pid` (if still live), or read an exit-status line the writer itself appended to the log — read
it *after* liveness ends, never polled for during the wait. This idiom's shape (a captured `pid`,
a `kill -0` loop, an outer `timeout`) is the recognizable process signature a reaper can match
against when cleaning up stale waiters.

## Conforming Examples

- **`lake-build-guard.sh`** already documents this idiom in its own header and `print_help()`:
  `while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done`, with an explicit prohibition
  against `pgrep -f "lake-build-guard.sh build"` for the same self-match reason as Rule 2 above.
  It is prior art for Rules 2 and 3, lacking only the outer `timeout` wrapper from Rule 1.
- **A generic gate script**: `nohup timeout 3000 bash gate.sh >log 2>&1 & pid=$!` followed by the
  canonical idiom above, in place of a `ps aux | grep` poll on the script's name.

## Local vs. Remote Waits

This file covers the case where there IS a local writer to probe: a detached command running on
the same host, with a PID the agent captured at launch and, usually, a local log file.
`external-process-wait.md` covers the complementary remote case — a process running somewhere the
agent cannot inspect directly, where the only observable signal is a polled status call (for
example `gh run watch`). Consult this file for a detached local build, gate, or test run; consult
that file for a remote or external job with no local writer.

## Related Documentation

- `external-process-wait.md` — the complementary remote-wait pattern; see "Local vs. Remote
  Waits" above.
- `dispatch-report-not-termination.md` — explains why a dispatch that ends its turn mid-wait
  loses the wait state entirely; supports the turn-ending symptom above.
- `anti-stop-patterns.md` — the forbidden-status-value backdrop to "ending the turn" as a bad
  outcome.
- `../contracts/wrap-up.md` — the general teardown-before-handoff obligation a background wait
  must respect if it cannot resolve within budget.
- `../../../lean/context/project/lean4/operations/long-builds.md` — the Lean-specific
  detach-and-guard mandate this waiter idiom complements; see its "Blocking on a detached build"
  section.
