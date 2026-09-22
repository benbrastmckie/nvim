# Long Lean Builds: Detach and Guard, Together

**Purpose**: Prevent foreground `lake build` livelock and the memory pressure that an uncoordinated
fix for it would create.

---

## Overview

A long Lean build livelocks under a plain foreground Bash call: the call is killed at the tool's
hard timeout before the build finishes, the killed build caches no progress for the module it was
mid-elaboration on, and the next attempt restarts at the identical module and dies the same way.
The fix requires two obligations to land together at every `lake build` call site — detach the
invocation so it survives past any single tool call, and route it through the shared build guard
so detaching does not itself create a new failure mode (redundant concurrent builds exhausting
memory). Adopting either obligation alone is a regression; both are mandatory together.

## The foreground cap

The Bash tool's hard timeout is 600000ms (10 minutes); its default timeout, when no explicit value
is passed, is 120000ms (2 minutes). A plain foreground `lake build` call is killed the instant it
crosses whichever cap applies, with no way to raise that cap past 10 minutes for a single
synchronous call.

## Why this is a livelock, not a slowdown

Lean's build cache is per-module: a completed module writes a `.olean` file, and a subsequent
build skips any module whose `.olean` is up to date. A build killed mid-module writes no `.olean`
for the module it was working on — the work is not partially banked, it is entirely lost. The next
`lake build` invocation starts over from the same point, hits the same cap, and dies the same way.
Without a structural fix, this repeats indefinitely.

## The normative statement

**Any single module may exceed the foreground cap.** This must be treated as a standing
possibility across the source store's roughly ten deployed repositories, not as an assumption tied
to one project's measured size.

> *Illustrative note (one large repository, not a general bound): a single module was observed to
> take roughly 11 minutes to elaborate, already past the 10-minute hard cap on its own.*

## The trigger is ordinary

Lean hashes whole files for cache invalidation, so even a comment- or docstring-only edit to an
upstream module invalidates the `.olean` of every module that imports it, directly or
transitively. A routine docstring pass is enough to re-arm this trap; it does not require a
substantive code change, and it is not an exotic failure mode.

## Obligation 1: detach

Invoke the build via `Bash(run_in_background: true)`. A detached call runs outside the foreground
tool-call lifecycle, survives across conversation turns, and re-invokes the agent with a
completion notification when the underlying process exits — regardless of how long the build
actually takes.

## Obligation 2: route through the guard

Detachment alone is not sufficient. The foreground cap was, incidentally, the only thing bounding
how long a redundant concurrent build could survive: today, several sessions each hitting a
10-minute wall on the same package limits how much simultaneous elaboration work piles up. Remove
that bound without adding a substitute and memory pressure gets strictly worse, not better — this
was measured directly on one large repository, where roughly 10 simultaneous builds re-elaborating
the same modules produced 16 concurrent `lean` processes at 29.9 GB RSS on a 30 GB machine, with
swap already in use. The build guard (`lake-build-guard.sh`) serializes concurrent invocations
against the same project and lets a waiting session consume an already-completed build's result
instead of launching a redundant one. Detaching without guarding trades a visible livelock for an
invisible, worse one; the two obligations must be adopted together.

## The canonical invocation

Every contract site in this extension copies this invocation shape verbatim, run under
`Bash(run_in_background: true)`:

```bash
bash .claude/scripts/lake-build-guard.sh build --timeout 1800 -- <lake-subcommand> [args]
# e.g. -- build Module.Name
```

`--timeout` bounds how long the guard waits to acquire the per-project build lock before giving
up — it is a *lock-wait* budget, not a build-duration limit, and it has no effect on how long the
underlying `lake build` itself is allowed to run. The guard's own default is 600 seconds, the same
value as the foreground cap this mandate replaces; relying on that default would let a second
session, waiting behind a legitimately long first build, time out at exit 75 for exactly the
reason this mandate exists to prevent. Every invocation in this extension therefore passes an
explicit, larger value (`--timeout 1800`) rather than the default.

## Scoped builds are covered too

A single module can already exceed the foreground cap on its own, and the guard's lock is
project-granular regardless of whether the wrapped `lake build` is scoped to one module or run
against the whole project. "Scoped is safe" is therefore false, and no contract site may frame a
scoped build as exempt from either obligation.

This has a real, deliberate cost: previously, a phase-end scoped build from one session and a
phase-end scoped build from a concurrent session on the same package — targeting different
modules — could run in parallel. Under the guard, both invocations serialize project-wide,
regardless of scope. This is the accepted price of closing the memory-pressure gap in the previous
section, not a hidden regression. Scoped invocation remains preferable to a full build wherever
it applies — it is simply doing less work — but it is never a basis for skipping either the
detachment or the guard obligation.

## Passive progress checks

While a detached build runs, an agent can check on it without terminating it or racing its own
completion notification. Each check below needs a `<PID>`: get it from the guard's own
`holder_pid` result-record field, or from `lake-build-guard.sh status --verbose` — never by
inventing a process scan to fill the gap.

- **Fresh `.olean` mtime frontier** — `find .lake/build -name '*.olean' -newer <marker> | wc -l`
  (or similar) shows how many modules have completed since the build started.
- **Live `lean` PID's command line** — `cat /proc/<PID>/cmdline | tr '\0' ' '` names the module
  currently being elaborated.
- **Accumulated CPU time** — `ps -o times= -p <PID>` or fields 14/15 of `/proc/<PID>/stat`
  (utime/stime in clock ticks) is the tiebreaker when the `.olean` list looks frozen because the
  process is stuck inside one unusually long module.
- **`VmRSS` trend** — `grep VmRSS /proc/<PID>/status`, sampled over time, is both a progress signal
  (steady growth is normal during elaboration) and an early OOM warning (a sudden spike toward the
  machine's available memory).

**Never `pgrep -f` for the guard, the watcher, or the wrapper script itself.** Any such pattern
matches the polling shell's own argv (the pattern text appears in the command line of the shell
running the wait) and can therefore never return empty while the watcher lives — see
`context/patterns/bounded-build-waiter.md` and the guard's own header for the same self-match
pitfall and the `kill -0 "$holder_pid"` idiom that avoids it. Where a real-worker match is
genuinely needed, use a non-self-matching bracket-trick pattern instead, e.g.
`pgrep -f '[b]in/lake build'` or `pgrep -f '[c]heck-module-invariants'`.

### The liveness caveat

All four checks prove **liveness**, never **termination**. A process burning CPU with steadily
growing RSS can still be stuck in a divergent tactic search that will never finish on its own.
These checks are for interim observability between the start of a detached build and its
completion notification — they are not a substitute for waiting on that notification, and they
must never be used to declare a build "probably done" in its absence. A process count is never
evidence of a build's OUTCOME, and a count that cannot go to zero — as a self-matching `pgrep -f`
never can — is not evidence of anything at all. See "Reading the build's verdict" below for how a
finished build's outcome is actually determined, and "Blocking on a detached build" for the
distinct, bounded case where the dispatch must actually block rather than merely observe.

## Reading the build's verdict

Once a build has finished (or a consumer needs to determine whether it already has), its verdict
— pass or fail — is read from evidence, strongest last, never from a process count:

1. **The guard's own exit code, captured un-piped**, or the guard's `result` subcommand. See the
   guard's own "READING THE VERDICT" header block and `--help` for the exit-code bands; this
   anchor does not restate them.
2. **The explicit `Build completed successfully (N jobs)` line in the guard's captured output**
   together with `grep -c 'error:'` returning 0 over both captured stdout and captured stderr. See
   the guard's own documented capture paths (`build-guard.stdout` / `.stderr`) rather than
   restating them here.
3. **Strongest: an `.olean`-newer-than-source check per touched module.** This proves the
   module's PRESENCE in the build, not merely the absence of a complaint, and is therefore
   stronger evidence than either tier above.

**Never pipe the guard invocation into `tail`/`head`/`grep` and then read `$?`** — that is the
pipe's exit code, not the guard's. Redirect to a log file and capture `GUARD_EXIT=$?` instead
(e.g. `... > <log> 2>&1; GUARD_EXIT=$?`), or use the guard's `result` subcommand.

## Blocking on a detached build

When a dispatch must block on a detached build within the same turn, rather than merely observe
it, the sanctioned bounded, PID-liveness, one-waiter-per-log idiom is defined once, canonically,
in core's `context/patterns/bounded-build-waiter.md`. Consult that file instead of improvising a
poll loop or ending the turn.

## Completion discipline

Detaching a build changes how it runs, not when the dispatch is allowed to end. The dispatch is
not complete, and final metadata must not be written, until the harness's own completion
notification for that background job has arrived. Fire-and-forget — detaching a build and then
proceeding as if it had already finished — is prohibited; see the wrap-up contract's teardown
rule for the general form of this requirement.

## Known gaps

- **`mcp__lean-lsp__lean_build`** is a second build path, invoked as an MCP tool call rather than a
  Bash command. `Bash(run_in_background: true)` cannot wrap an MCP tool call, and this path's own
  timeout behavior is outside this anchor's visibility. It is deliberately not covered by this
  mandate; callers should prefer the guarded Bash invocation above when a choice is available.
- **`skill-lake-repair`**'s repair loop calls the guard via command substitution
  (`build_output=$(... )`), which is incompatible with `run_in_background` (a detached call
  returns no stdout to a shell variable). That loop is carved out of the *detachment* obligation
  only — it still adopts the guard — with the residual cap exposure documented at its own call
  site.

## Cross-reference

`operations/multi-instance-optimization.md` covers the complementary concern of running multiple
concurrent Claude Code sessions against Lean-LSP MCP tools generally (pre-building, environment
tuning, session throttling). This anchor owns one interaction between the two topics that the
sibling file predates: detaching builds means more of them can be in flight across sessions at
once, which is exactly the concurrency multi-instance-optimization.md's soft-throttling guidance
is meant to bound. Consult that anchor for session-level setup; this one is authoritative for the
per-invocation detach-plus-guard contract.
