# External-Process-Wait Discipline

**Created**: 2026-09-18
**Purpose**: State, once and canonically, the defect class produced when a dispatched agent waits
on a long-running remote or external process, and define the sanctioned wait discipline that
avoids it.
**Audience**: Any dispatched subagent blocked on a long external process — GitHub Actions runs
first, but the discipline generalizes to any remote job polled through a CLI or API status call.
**Related**: `dispatch-report-not-termination.md`, `../contracts/wrap-up.md`,
`checkpoint-before-overflow.md`, `anti-stop-patterns.md`, `../formats/handoff-artifact.md`,
`bounded-build-waiter.md`

---

## The Defect

A general-implementation-agent dispatched under `/orchestrate` had to wait on a GitHub Actions
run of about 25 minutes. The wait went wrong in four concrete, compounding ways:

1. **The harness blocked a foreground `sleep`.** A plain `sleep N` intended to pace polling was
   not an available option.
2. **An unbounded `gh run watch` exceeded the 600s Bash-tool timeout.** With no inner timeout,
   the call ran past the harness's own ceiling and was auto-moved to the background rather than
   returning control in the foreground.
3. **A Monitor loop echoed status on every 20-90s poll.** Because the loop's own output changed
   on every tick (not only on a state change), every UNCHANGED poll woke the agent — the loop was
   armed correctly but tuned wrong.
4. **The agent filled the gaps with no-op work.** Because a subagent that ends its turn
   terminates, and the agent had nothing legitimate to do between polls, it issued roughly 130
   no-op Bash calls (`:`, `true`, `date -u`, `echo waiting`) plus status-only text turns to keep a
   turn alive, burning context until it had to be stopped manually.

None of the four steps is wrong in isolation — a bounded wait, a Monitor, and turn-ending are all
legitimate mechanisms elsewhere in this system. The defect is their combination without a bound:
an unbounded external wait, observed through a chatty watcher, inside a process that cannot
simply go idle and must therefore manufacture activity to survive.

## Required Rules

### 1. Bounded blocking wait

Use an inner-bounded, foreground, blocking command, not an unbounded watch:

```bash
timeout 540 gh run watch ID --interval 60 --exit-status >/dev/null; gh run view ID --json status,conclusion
```

Issue it with the Bash tool's own `timeout` parameter set to `600000` (600s, its ceiling).
Repeat the pair only while the reported `status` is `in_progress` or `queued`.

**Why 540 < 600**: the inner `timeout 540` (540s) must fire and return control to the agent
*before* the harness's own 600000ms (600s) Bash-tool ceiling is reached. If the inner command
runs uninterrupted past 600s, the harness auto-backgrounds the call instead of returning it to
the foreground — exactly the failure mode in step 2 of the defect above. The roughly 60-second
margin between 540 and 600 covers the trailing `gh run view` call and ordinary process overhead,
so the pair reliably completes and reports before the harness would otherwise intervene.

### 2. No no-op filler

Do not issue `:`, `true`, `date`, `echo waiting`-style Bash calls, or any other call whose sole
purpose is to keep a turn alive between polls. Do not send status-only text turns for the same
purpose. If there is nothing left to do until the next bounded wait iteration, run the next
iteration — do not manufacture intermediate activity.

### 3. No `run_in_background` and no Monitor for CI waits inside a subagent

Do not background the wait command and do not arm a Monitor to watch it from within a dispatched
subagent. A background completion or a Monitor event wakes an agent that, by definition, has
nothing else to do while waiting — and because a subagent that ends its turn terminates (see
`dispatch-report-not-termination.md`), the wake either arrives at a terminated agent (silently
lost) or forces the agent to stay alive with no legitimate work, reproducing step 4 of the defect.
The bounded blocking command in Rule 1 is the correct primitive precisely because it keeps the
agent in the foreground for the exact duration of one polling interval and no longer.

### 4. A legitimate Monitor emits only on a state change

Where Monitor IS legitimately used — for example by a top-level session, not a dispatched
subagent — its loop must emit ONLY when the observed state changes, never on every poll. The
incident's Monitor loop, which echoed on every 20-90s tick regardless of whether status had
changed, is the negative example: it was armed in a context where a watcher is reasonable, but
tuned to wake its listener on every unchanged observation instead of only on a transition.

### 5. Do independent local work first

Before entering any wait on an external result, finish every task step that does not depend on
that result. A wait should begin only once genuinely nothing else in the current dispatch can
proceed without the external outcome.

### 6. Total-wait cap of about 45 minutes

Cap the cumulative time spent waiting on one external process at about 45 minutes. On reaching
the cap, stop waiting, write a handoff following `../formats/handoff-artifact.md`, and return
`status: "partial"` rather than continuing to wait. The handoff must contain a concrete
continuation: the run ID (or equivalent job identifier), the exact resume command (the same
bounded pair from Rule 1), and what remains. Do not return a status of `"completed"` to signal
the wait is unresolved — `anti-stop-patterns.md` forbids that value outright, and it would also
misstate an unresolved wait as finished work.

## Generalizing Beyond GitHub Actions

The worked example above uses `gh run watch`/`gh run view`, but the discipline is not specific to
GitHub Actions. Any remote or external job that is polled through a CLI or API status call, and
that has no local process to probe directly, uses the same shape: a bounded inner timeout set
below the harness's tool-call ceiling, a status re-check issued once the inner timeout returns,
repetition gated on an in-progress status, and a total-wait cap enforced independently of the
per-iteration timeout.

## Local vs. Remote Waits

This file covers the case where there is no local writer to probe: the process being waited on
runs somewhere the agent cannot inspect directly, so the only observable signal is a polled
status. `bounded-build-waiter.md` covers the complementary local case — a detached build with a
local log file, where writer-liveness is checked via `kill -0` and a one-waiter-per-log
convention applies. Consult that file for a local detached build; consult this file for a remote
or external job with no local writer.

## Related Documentation

- `dispatch-report-not-termination.md` — explains why a watcher or Monitor left armed inside a
  subagent is dangerous; supports Rule 3 above.
- `../contracts/wrap-up.md` — see its "Teardown Precedes the Terminal Handoff Write" section for
  the general teardown-before-handoff obligation this file's Rule 3 instantiates for CI waits
  specifically.
- `checkpoint-before-overflow.md` — the structural template this file follows, and the pattern to
  consult for handoff mechanics under context pressure generally.
- `anti-stop-patterns.md` — forbids the `"completed"` status value referenced in Rule 6.
- `../formats/handoff-artifact.md` — the handoff document schema Rule 6's handoff must follow.
- `bounded-build-waiter.md` — the complementary local-detached-build pattern; see "Local vs.
  Remote Waits" above.
