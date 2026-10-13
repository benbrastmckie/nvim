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
5. **One writer per shared tree.** At most one writer may hold a shared fixture/build tree per
   dispatch. Before launching a writer against such a tree, acquire a `flock()`-held lock file
   scoped to the tree root and hold it for the writer's full duration. A second would-be writer
   against the same tree must detect the live lock and either wait on the existing writer or fail
   loudly, naming the holder — it must never launch a second overlapping invocation. A
   kernel-held `flock` is required rather than a sentinel file precisely because it is released
   automatically when the holding process exits, so a dead holder never leaves behind the
   stale-sentinel hazard already recorded as symptom 1 above.

   This is a writer-concurrency rule, distinct from Rule 4's waiter-attachment rule: Rule 4
   governs a second *waiter* observing an existing writer's PID; Rule 5 governs preventing a
   second *writer* from launching against the same tree in the first place. A measured failure
   shows why both are needed: one dispatch launched two overlapping invocations of one test
   suite into the same shared fixture tree with no liveness check on the prior invocation, then a
   third invocation after the collision was already suspected — the collision was found only by
   manual process-tree scanning, several stray processes were killed by hand, and one spurious
   test failure had to be diagnosed afterward. None of that cost was a real defect in the work;
   all of it was concurrency against a shared tree that Rule 5 prevents by construction.

## The Canonical Idiom

```bash
cmd >log 2>&1 & pid=$!
timeout 3000 bash -c 'while kill -0 "$1" 2>/dev/null; do sleep 10; done' _ "$pid"
```

Prefer the simpler foreground form, `timeout 3000 cmd`, whenever the command fits within the
calling tool's own timeout limit — reach for the detach-plus-waiter shape only when it does not.
**That "calling tool's own timeout limit" is itself a parameter the caller sets, not a fixed
property of the command**: the Bash tool's `timeout` parameter defaults to `120000`ms (120s), so
preferring the foreground form for anything longer than two minutes REQUIRES raising that
parameter to `600000` (600s, its ceiling) in the same call — otherwise the harness auto-
backgrounds the call before the inner `timeout` can ever return control, which is the identical
failure this file's own idiom exists to avoid, just reached through the foreground form instead
of an unbounded detached one. See `external-process-wait.md` Rule 1 for this pairing stated in
full, including its caller-agnostic framing and the `exit 124` handling.

To read the outcome once the wait ends, either `wait "$pid"` in the same shell that captured
`pid` (if still live), or read an exit-status line the writer itself appended to the log — read
it *after* liveness ends, never polled for during the wait. This idiom's shape (a captured `pid`,
a `kill -0` loop, an outer `timeout`) is the recognizable process signature a reaper can match
against when cleaning up stale waiters. `claude-refresh.sh`'s orphaned build-waiter poll-loop
pass (`run_build_waiter_pass`) is exactly such a reaper, matching this canonical idiom's signature
(its "Family A") as well as the legacy self-match shape it replaced (its "Family B") — see
`commands/refresh.md`'s "Orphaned Build Waiters" section for the full detection and
self-exclusion contract.

### Sizing a Wait Near the Per-Call Ceiling

A job whose expected duration approaches the Bash tool's own per-call ceiling must not be
awaited in one call sized to its full expected runtime — the whole call, inner wait loop
included, must still return control to the agent before the harness auto-backgrounds it,
reproducing `external-process-wait.md`'s 540-versus-600 margin problem (see that file's Rule 1)
for the identical reason. Instead: launch once, capturing `pid`, then issue a *sequence* of
separate bounded calls, each gated on `kill -0 "$pid"` and sized safely under the ceiling,
re-checking liveness between calls and reading the log or exit status once liveness ends — the
same repeated-bounded-iteration shape `external-process-wait.md` already prescribes for the
remote case, generalized to a local liveness check.

This sizing rule is consistent with, and does not re-open, the settled ruling on whether a local
verification/gate/build/test process may be backgrounded at all; it answers only how to size the
wait once backgrounding is already sanctioned. Sharding or shortening a job this close to the
ceiling is a consumer-repo concern, not a change to this file's idiom.

**The same tool-`timeout`-parameter pairing applies to each call in this sequence, for the plain-
foreground case this subsection does not otherwise cover**: every individual bounded call in the
sequence must ALSO raise the Bash tool's own `timeout` parameter to `600000` (from its `120000`ms
default), with its own inner `timeout` kept safely below that — the pairing is per-call, not a
one-time setup. Raising the parameter resolves a job that fits under the 600s ceiling once sized
correctly into this sequence (sub-case 3a in `external-process-wait.md` Rule 1's terms); it does
NOT, by itself, resolve a job whose single unsized attempt would exceed 600s even before this
subsection's own sharding is applied (sub-case 3b) — that is exactly why this subsection's
sequencing exists in the first place.

## Canonical Agent-Contract Bullet (Generated-Copy Source)

This section is the single authoritative source for the bounded-wait MUST / MUST NOT bullet pair
that every in-scope dispatchable implementation agent carries in its `## Critical Requirements`
list. It exists so the bullet pair has exactly one place to edit, instead of drifting
independently across the agent files that carry a literal copy.

### Generated-Copy Source, Not an `@`-Import

**This section is a generated-copy source, read by a human or a lint script — it is NOT
`@`-imported into agent bodies at spawn time.** `@`-references inside an agent body do not
auto-resolve when Claude Code spawns a subagent, so each in-scope agent body carries a **literal
copy** of the bullet text below; `lint-agent-contracts.sh` Check H keeps every copy in sync by
comparing it against this file, not against a string baked into the lint. This mirrors the
precedent already established twice in this same script, by `no-task-references-bullet.md` (its
own Check C) and `plan-status-ownership.md` (its own Check G).

### Item 1 Ruling: One Shared Home, Rejected Candidates Recorded

This section (an appended section of this already-existing pattern document) is the settled home
for the bullet pair, chosen over two other candidates evaluated and rejected:

- **(a) A shared always-load context pointer every implementation agent already includes** —
  rejected because no such universally-included file exists. The nearest candidates
  (`contracts/phase-closure.md`, `contracts/pre-edit-gate.md`) are each missing from at least two
  of the fourteen target agent files, so even the closest-to-universal pointer would still
  require a fresh addition in the hardest cases. A bare pointer would also not reach a spawned
  subagent in the first place: `@`-references inside an agent body do not auto-resolve when
  Claude Code spawns a subagent (see "Generated-Copy Source, Not an `@`-Import" above), so the
  behavioral MUST/MUST-NOT core must be literal text in each agent body regardless of which file
  states it canonically.
- **(c) Per-agent duplication with no single canonical source at all, as a last resort** —
  rejected because it is the anti-proliferation failure this change exists to close: fourteen
  independently-drifting copies of one prohibition is a maintenance defect in waiting, and a
  future agent addition would miss it again by the exact mechanism that produced the original
  gap. The chosen shape (this generated-copy section, propagated by literal text and verified by
  `lint-agent-contracts.sh` Check H) keeps exactly one edit point while still placing a literal,
  subagent-reachable copy in every carrying agent body.
- **(b) The agent template, `core/context/templates/agent-template.md`** — adopted, but as a
  **forward-looking complement only**, not a substitute for (a) or (c)'s rejection. A template
  change fixes no existing agent file; it only ensures a newly authored implementation agent
  inherits the bullet pair by construction. The fourteen already-existing agent files still
  require the direct literal-copy propagation this section's "Copy this exact text" block below
  describes, and that propagation — not the template edit — is what closes the measured gap.

### Copy this exact text

Copy both bullets below, verbatim and each on a single physical line, into the target agent's
`## Critical Requirements` MUST and MUST NOT lists respectively, as the next sequential item of
each. Do not renumber or reword any surrounding bullet.

MUST bullet:

```
Whenever a local verification/gate/build/test process is backgrounded at all, use bounded-build-waiter.md's canonical idiom VERBATIM: a captured `pid=$!`, a `kill -0 "$pid"` liveness loop, and an outer `timeout N`, all inside one Bash call that does not return control until the wait resolves -- and prefer the plain foreground form `timeout N cmd` whenever the command plausibly fits within the Bash tool's own ceiling
```

MUST NOT bullet:

```
Use `Bash(run_in_background: true)` or arm a `Monitor` to watch a local verification, gate, build, or test process from within this dispatched subagent, and never end the turn on an unresolved local background wait -- the harness's own asynchronous detach-then-await-notification path hands the dispatch back unfinished with nothing guaranteed to resume it
```

### Rule 5 Non-Propagation Ruling

Required Rule 5 (single-writer discipline, above) is **not** added to the bullet pair this
section propagates, and the "Copy this exact text" block above is unchanged. Adding it would
require a literal-copy pass across every carrying agent file plus an addition to
`lint-agent-contracts.sh`'s curated in-scope array — the standing ground of
`propagate_bounded_wait_contract_and_lint_coverage`, cited here by that project name, not treated
as a gap in this change. Rule 5 is reached the same way the rest of this file already is for
every dispatch: by the dispatch-level "Wait Discipline" pointer every dispatch file carries to
this file by path, not by a per-agent literal copy.

### Classification Rule

An agent MUST carry this bullet pair if and only if it is a dispatchable implementation agent
that can run a local verification, gate, build, or test command (every implementation agent
across core and every extension, hard-mode variants included — see the Item 3 ruling below).
Three files are recorded exclusions, each for a per-file reason rather than an oversight:

- `core/agents/general-implementation-agent.md` — the contract's authoritative home. This is the
  full prose block the bullet pair above is condensed from; it is deliberately not edited to
  carry the condensed copy of its own source text.
- `lean/agents/lean-implementation-agent.md` and `lean/agents/lean-implementation-hard-agent.md`
  — these carry a domain-adapted, sanctioned background-build path routed through the Lean build
  guard (`lake-build-guard.sh`), a different legitimate mechanism satisfying the same underlying
  rule rather than an unfixed gap.

A future agent addition must be classified by this rule and added to the lint's curated
in-scope array explicitly — the check does not infer scope from a filename glob.

### Item 3 Ruling: Hard Variants Do Not Inherit

Hard-mode agent files (e.g. `*-implementation-hard-agent.md`) do not inherit this bullet pair
from their non-hard sibling. A hard-mode file's "Extends `{sibling}-implementation-agent`"
language is prose documentation of intent, not a file-inclusion or generation mechanism — nothing
mechanically copies the sibling's `## Critical Requirements` list into the hard variant. The
evidence is direct: both measured hard variants (`books-implementation-hard-agent.md`,
`cslib-implementation-hard-agent.md`) are missing the bullet pair independently of their non-hard
sibling's own coverage state. Each hard-mode agent file therefore carries its own literal copy
and is listed independently in the lint's curated in-scope array.

### Item 4 Ruling: Research Agents Are Out of Scope Here, Not Dismissed

Research agents are plausibly exposed to the identical defect class: `general-research-agent.md`
already carries the external/remote-wait discipline (the `external-process-wait.md` idiom) but
neither half of this local-background bullet pair, and several domain research agents hold Bash
access explicitly for verification or build commands. The Lean research agents'
`run_in_background` occurrences are the separate, sanctioned Lean build-guard path, not partial
coverage of this contract, so they do not change this ruling.

This change rules research-agent propagation **out of its own scope**, not out of relevance: the
measured coverage gap and this change's acceptance surface are implementation-agent-scoped only.
Extending the identical fragment-and-lint-check mechanism to research agents is recorded as a
follow-up recommendation, reusing this same generated-copy section and the same lint shape against
a separately curated research-agent in-scope array.

### Brittleness Note

This section is the single edit point for the bullet pair's wording. A future wording change here
is expected to be followed by a mechanical re-propagation pass across every literal copy — the
same brittleness already accepted for the `no-task-references-bullet.md` and
`plan-status-ownership.md` fragments this section's shape mirrors.

## Conforming Examples

- **`lake-build-guard.sh`** already documents this idiom in its own header and `print_help()`:
  `while kill -0 "$holder_pid" 2>/dev/null; do sleep 1; done`, with an explicit prohibition
  against `pgrep -f "lake-build-guard.sh build"` for the same self-match reason as Rule 2 above.
  It is prior art for Rules 2 and 3, lacking only the outer `timeout` wrapper from Rule 1. It is
  also the prior art for Rule 5: it serializes concurrent builds against one tree via a
  `flock()`-held lock file scoped to the tree root (`<root>/.lake/build-guard.lock`), shares an
  already-completed result with a second invocation instead of launching a redundant build, and
  its own header names this explicitly as a reusable "FAMILY CONVENTION ... for a future
  ...-build-guard.sh or similar sibling" — the shape Rule 5 generalizes rather than reinvents.
- **A generic gate script**: `nohup timeout 3000 bash gate.sh >log 2>&1 & pid=$!` followed by the
  canonical idiom above, in place of a `ps aux | grep` poll on the script's name.

## Local vs. Remote Waits

This file covers the case where there IS a local writer to probe: a detached command running on
the same host, with a PID the agent captured at launch and, usually, a local log file.
`external-process-wait.md` covers the complementary remote case — a process running somewhere the
agent cannot inspect directly, where the only observable signal is a polled status call (for
example `gh run watch`). Consult this file for a detached local build, gate, or test run; consult
that file for a remote or external job with no local writer.

## Dispatched-Subagent Wait Ruling: A Third Case, Resolved in `general-implementation-agent.md`, Not Here

A third shape was evaluated against the two this file already covers: a dispatched agent itself
issuing a further `Agent`-tool call and waiting on the result. The middle position was adopted,
in refined form: an ordinary synchronous `Agent`-tool call that blocks in the same tool
invocation is outside this discipline entirely (it is not a background wait, and nothing here
restricts ordinary nested delegation). An async/backgrounded subagent dispatch awaited across a
turn boundary is prohibited outright, not bounded with a deadline the way Rule 1's `timeout N`
bounds a local gate.

The reason it is prohibited outright rather than bounded is mechanical, not a stricter policy
choice: this file's canonical idiom bounds a wait because a captured PID and `kill -0 "$pid"`
give the waiter a foreground-pollable liveness signal to bound. A backgrounded subagent dispatch
has no PID and no status call the dispatching agent can inspect from inside its own turn, so a
"bounded wait with a defined action at the deadline" describes a mechanism that does not exist
for this case; writing one here would misstate this file's own PID idiom as available where it
is not. The underlying capability for this case to matter is demonstrated — a dispatched agent
has already issued a nested `Agent` fork-probe call under an async/backgrounded harness mode —
but no confirmed stranding incident supports it, which is why the rule is a flat MUST NOT rather
than a mechanism-mandating bounded-wait clause like Rules 1-4 above.

**This file's own canonical bullet pair (`## Canonical Agent-Contract Bullet (Generated-Copy
Source)` above) is deliberately not the home for this case.** The full ruling and its wording
live in `agents/general-implementation-agent.md`'s "Dispatched-Subagent Wait Discipline"
subsection; see "Related Documentation" below.

## Shape Taxonomy: Three Ways a Wait Goes Wrong, Distinguished by Trigger

The ruling immediately above is one of three shapes evaluated for this general class of defect.
Recorded together, once, as the authoritative taxonomy — each of the other two documents
cross-references this section by name rather than re-deriving it:

1. **Agent-chosen local-gate backgrounding.** The agent itself decides to background a local
   verification/gate/build/test process. Backgrounding stays permitted, but only through this
   file's own canonical idiom (a captured `pid`, a `kill -0` loop, an outer `timeout`) — never
   `Bash(run_in_background: true)` and never an armed `Monitor`. This is the shape "The Canonical
   Idiom" and "Required Rules" above govern.
2. **Awaiting a dispatched subagent.** The agent issues a further `Agent`-tool call. Resolved
   immediately above: an ordinary synchronous call is outside this discipline entirely; an
   async/backgrounded dispatch awaited across a turn boundary is prohibited outright, because no
   PID or status call exists for the dispatching agent to bound a wait with.
3. **Harness-initiated backgrounding of an ordinary foreground call.** The agent chooses nothing
   — it issues a plain foreground Bash call, and the HARNESS backgrounds it because the Bash
   tool's own `timeout` parameter was left at its `120000`ms default while the command ran past
   that mark. This shape is distinguished from the other two by **trigger, not command category**:
   the same `deploy-headless.sh` invocation that shape 1 governs when the agent deliberately
   detaches it falls under shape 3 instead when the agent runs it in the foreground and simply
   forgets to raise the tool parameter. Two sub-cases, with different remedies (see
   `external-process-wait.md` Rule 1 for the full statement):
   - **3a** — the call fits under the 600s ceiling but the parameter was left at its default:
     raising the parameter to `600000` is sufficient on its own.
   - **3b** — the call cannot fit under the 600s ceiling at all even with the parameter raised:
     use this file's own "Sizing a Wait Near the Per-Call Ceiling" subsection instead — redirect
     to a log, launch with a captured PID, and resolve with a sequence of bounded foreground
     `kill -0` waits.

Shape 3 composes with shape 2's ruling rather than superseding it: they concern different trigger
surfaces (the harness backgrounding a call the agent did not choose to background, versus the
agent itself issuing an async subagent dispatch), and neither weakens the other. Shape 3 is also
a precondition on shape 1, not a fourth top-level discipline of its own — see
`agents/general-implementation-agent.md`'s Local Long-Running Command Discipline subsection for
where this precondition is noted inline.

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
- `agents/general-implementation-agent.md`'s "Dispatched-Subagent Wait Discipline" — the
  complementary nested-subagent-dispatch case; see "Dispatched-Subagent Wait Ruling" above for
  why this file's PID-liveness idiom does not apply to it.
